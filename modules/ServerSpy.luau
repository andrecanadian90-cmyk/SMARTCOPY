--!optimize 2
-- ============================================================
-- SMARTCOPY :: ServerSpy v2 (MAX LEVEL)
-- Complete remote interception, analysis, and server script
-- reconstruction engine.
--
-- Features:
--   [OK] Hook ALL remotes (Event, Function, Unreliable)
--   [OK] __namecall metamethod hook (catches obfuscated calls)
--   [OK] ByteNet packet-aware logging
--   [OK] Return value capture on RemoteFunctions
--   [OK] Call stack capture (which script called the remote)
--   [OK] Frequency analysis (detect heartbeats vs actions)
--   [OK] Smart remote categorization
--   [OK] Server-spawned instance tracking + correlation
--   [OK] Property & Attribute change monitoring
--   [OK] Deep serialization (depth 6, buffer support)
--   [OK] Complete server script generation (runnable)
--   [OK] Real-time logging toggle
--   [OK] Export report to clipboard
--   [OK] Auto timing correlation (remote call ? instance spawn)
--
-- USAGE:
--   loadstring(readfile("ServerSpy.luau"))()
--   ServerSpy:Start()
--   -- play the game, interact with features --
--   ServerSpy:Stop()
--   ServerSpy:ExportReport()       -- prints full report
--   ServerSpy:CopyReport()         -- copies to clipboard
--   ServerSpy:GenerateServerStubs() -- generates server scripts
-- ============================================================

local ServerSpy = {}
ServerSpy.__index = ServerSpy

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

-- ============================================================
-- CONFIG
-- ============================================================
local CONFIG = {
	maxLogEntries       = 50000,    -- prevent memory overflow
	maxSerializeDepth   = 6,        -- deeper than v1's 3
	maxStringPreview    = 300,      -- chars before truncation
	maxTableEntries     = 20,       -- entries before truncation
	realtimeLog         = true,     -- print calls as they happen
	realtimeFilter      = nil,      -- nil = all, or string pattern to filter
	captureStacks       = true,     -- capture call stacks (slight perf cost)
	monitorAttributes   = true,     -- monitor attribute changes on characters
	monitorProperties   = true,     -- monitor key property changes
	heartbeatThreshold  = 0.5,      -- calls/sec above this = likely heartbeat
	correlationWindow   = 0.5,      -- seconds to link remote call -> instance spawn
}

-- ============================================================
-- STATE
-- ============================================================
local isRunning = false
local startTime = 0

local logs = {}                 -- { time, remote, direction, args, argTypes, returnVal, stack, category }
local remoteStats = {}          -- remotePath -> { deep stats }
local spawnedInstances = {}     -- server-spawned objects
local attributeChanges = {}     -- attribute changes on player characters
local connections = {}          -- active connections for cleanup
local existingDescendants = {}  -- snapshot before monitoring

-- Namecall hook state
local oldNamecall = nil
local namecallHooked = false

-- ============================================================
-- SERIALIZATION ENGINE (v2 ? deep, buffer-aware)
-- ============================================================

local function safeSerialize(value, depth, seen)
	depth = depth or 0
	seen = seen or {}

	if depth > CONFIG.maxSerializeDepth then return "..." end

	local t = typeof(value)

	if value == nil then return "nil"
	elseif t == "string" then
		if #value > CONFIG.maxStringPreview then
			return string.format("%q...[+%d]", string.sub(value, 1, 150), #value - 150)
		end
		return string.format("%q", value)
	elseif t == "number" then
		if value == math.floor(value) then return tostring(value) end
		return string.format("%.4g", value)
	elseif t == "boolean" then return tostring(value)
	elseif t == "Instance" then
		local ok, name = pcall(function() return value:GetFullName() end)
		local ok2, cn = pcall(function() return value.ClassName end)
		local className = ok2 and cn or "?"
		return ok and string.format("Instance<%s>(%s)", className, name) or "Instance<?>"
	elseif t == "Vector3" then
		return string.format("Vector3.new(%.2f, %.2f, %.2f)", value.X, value.Y, value.Z)
	elseif t == "Vector2" then
		return string.format("Vector2.new(%.2f, %.2f)", value.X, value.Y)
	elseif t == "CFrame" then
		local p = value.Position
		local rx, ry, rz = value:ToEulerAnglesYXZ()
		return string.format("CFrame.new(%.2f,%.2f,%.2f) * angles(%.1f?,%.1f?,%.1f?)",
			p.X, p.Y, p.Z, math.deg(rx), math.deg(ry), math.deg(rz))
	elseif t == "Color3" then
		return string.format("Color3.fromRGB(%d, %d, %d)",
			math.floor(value.R*255), math.floor(value.G*255), math.floor(value.B*255))
	elseif t == "BrickColor" then
		return string.format("BrickColor.new(\"%s\")", tostring(value))
	elseif t == "UDim" then
		return string.format("UDim.new(%g, %d)", value.Scale, value.Offset)
	elseif t == "UDim2" then
		return string.format("UDim2.new(%g, %d, %g, %d)",
			value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset)
	elseif t == "Rect" then
		return string.format("Rect.new(%g,%g,%g,%g)", value.Min.X, value.Min.Y, value.Max.X, value.Max.Y)
	elseif t == "NumberSequence" then
		return "NumberSequence[" .. #value.Keypoints .. " keypoints]"
	elseif t == "ColorSequence" then
		return "ColorSequence[" .. #value.Keypoints .. " keypoints]"
	elseif t == "NumberRange" then
		return string.format("NumberRange.new(%g, %g)", value.Min, value.Max)
	elseif t == "Ray" then
		return string.format("Ray(origin=%s, dir=%s)",
			safeSerialize(value.Origin, depth+1, seen),
			safeSerialize(value.Direction, depth+1, seen))
	elseif t == "EnumItem" then return tostring(value)
	elseif t == "Enum" then return tostring(value)
	elseif t == "buffer" then
		local size = 0
		pcall(function() size = buffer.len(value) end)
		if size > 0 then
			-- Show first few bytes as hex
			local preview = {}
			local previewLen = math.min(size, 16)
			for i = 0, previewLen - 1 do
				pcall(function()
					table.insert(preview, string.format("%02X", buffer.readu8(value, i)))
				end)
			end
			return string.format("buffer[%d bytes: %s%s]",
				size, table.concat(preview, " "), size > 16 and " ..." or "")
		end
		return "buffer[empty]"
	elseif t == "table" then
		if seen[value] then return "{circular circular}" end
		seen[value] = true

		local parts = {}
		local count = 0
		local isArray = true
		local maxIdx = 0

		-- Check if it's an array
		for k, _ in pairs(value) do
			if type(k) ~= "number" or k ~= math.floor(k) or k < 1 then
				isArray = false
				break
			end
			maxIdx = math.max(maxIdx, k)
		end

		if isArray and maxIdx > 0 then
			for i = 1, maxIdx do
				count += 1
				if count > CONFIG.maxTableEntries then
					table.insert(parts, string.format("...+%d more", maxIdx - count + 1))
					break
				end
				table.insert(parts, safeSerialize(value[i], depth + 1, seen))
			end
			return "{" .. table.concat(parts, ", ") .. "}"
		else
			for k, v in pairs(value) do
				count += 1
				if count > CONFIG.maxTableEntries then
					table.insert(parts, "...")
					break
				end
				local keyStr
				if type(k) == "string" then
					keyStr = k
				else
					keyStr = "[" .. safeSerialize(k, depth + 1, seen) .. "]"
				end
				table.insert(parts, keyStr .. " = " .. safeSerialize(v, depth + 1, seen))
			end
			return "{" .. table.concat(parts, ", ") .. "}"
		end
	else
		local ok, s = pcall(tostring, value)
		return ok and string.format("%s<%s>", t, s) or t
	end
end

local function serializeArgs(args)
	local result = {}
	for _, arg in ipairs(args) do
		table.insert(result, safeSerialize(arg))
	end
	return result
end

local function inferArgType(value)
	local t = typeof(value)
	if t == "Instance" then
		local ok, cn = pcall(function() return value.ClassName end)
		return ok and ("Instance<" .. cn .. ">") or "Instance"
	elseif t == "table" then
		-- Try to identify table shape
		local keys = {}
		local count = 0
		for k, _ in pairs(value) do
			count += 1
			if count > 8 then break end
			if type(k) == "string" then
				table.insert(keys, k)
			end
		end
		if #keys > 0 then
			return "table{" .. table.concat(keys, ",") .. "}"
		end
		return "table[" .. count .. "]"
	end
	return t
end

-- ============================================================
-- CALL STACK CAPTURE
-- ============================================================

local function captureStack()
	if not CONFIG.captureStacks then return nil end
	local ok, stack = pcall(function()
		return debug.traceback("", 4)  -- skip internal frames
	end)
	if ok and stack then
		-- Clean up and truncate
		local lines = string.split(stack, "\n")
		local clean = {}
		for _, line in ipairs(lines) do
			local trimmed = string.match(line, "^%s*(.-)%s*$")
			if trimmed ~= "" and not string.find(trimmed, "ServerSpy", 1, true) then
				table.insert(clean, trimmed)
				if #clean >= 5 then break end -- top 5 frames
			end
		end
		return table.concat(clean, "\n")
	end
	return nil
end

-- ============================================================
-- SMART CATEGORIZATION
-- ============================================================

local function categorizeRemote(remotePath, direction, args, callCount, frequency)
	-- By name patterns
	local name = string.lower(string.match(remotePath, "([^%.]+)$") or "")

	if string.find(name, "heartbeat") or string.find(name, "ping")
		or string.find(name, "alive") or string.find(name, "keepalive") then
		return "HEARTBEAT"
	end

	if string.find(name, "chat") or string.find(name, "message") then
		return "CHAT"
	end

	if string.find(name, "move") or string.find(name, "position")
		or string.find(name, "character") or string.find(name, "cframe") then
		return "MOVEMENT"
	end

	if string.find(name, "data") or string.find(name, "save")
		or string.find(name, "load") or string.find(name, "store") then
		return "DATA"
	end

	if string.find(name, "buy") or string.find(name, "purchase")
		or string.find(name, "shop") or string.find(name, "coin")
		or string.find(name, "money") or string.find(name, "gamepass") then
		return "ECONOMY"
	end

	if string.find(name, "equip") or string.find(name, "tool")
		or string.find(name, "item") or string.find(name, "inventory") then
		return "INVENTORY"
	end

	if string.find(name, "dance") or string.find(name, "anim")
		or string.find(name, "emote") then
		return "ANIMATION"
	end

	if string.find(name, "music") or string.find(name, "sound")
		or string.find(name, "audio") then
		return "AUDIO"
	end

	if string.find(name, "vote") or string.find(name, "poll")
		or string.find(name, "like") then
		return "SOCIAL"
	end

	if string.find(name, "admin") or string.find(name, "mod")
		or string.find(name, "ban") or string.find(name, "kick") then
		return "ADMIN"
	end

	-- By frequency
	if frequency and frequency > CONFIG.heartbeatThreshold then
		return "HEARTBEAT (freq)"
	end

	-- By direction
	if direction == "S->C" then return "SERVER_EVENT" end

	return "ACTION"
end

-- ============================================================
-- LOG ENTRY
-- ============================================================

local function logCall(remotePath, direction, args, returnVal, stack)
	if #logs >= CONFIG.maxLogEntries then return end

	local entry = {
		time       = os.clock() - startTime,
		remote     = remotePath,
		direction  = direction,
		args       = serializeArgs(args),
		argTypes   = {},
		returnVal  = returnVal and safeSerialize(returnVal) or nil,
		stack      = stack,
		rawArgCount = #args,
	}

	for _, arg in ipairs(args) do
		table.insert(entry.argTypes, inferArgType(arg))
	end

	table.insert(logs, entry)

	-- Update stats
	if not remoteStats[remotePath] then
		remoteStats[remotePath] = {
			callCount    = 0,
			directions   = {},
			argPatterns  = {},
			firstSeen    = entry.time,
			lastSeen     = entry.time,
			callTimes    = {},      -- for frequency analysis
			returnTypes  = {},
			exampleCalls = {},      -- store first 3 full examples
			callerStacks = {},
		}
	end

	local stat = remoteStats[remotePath]
	stat.callCount += 1
	stat.lastSeen = entry.time
	stat.directions[direction] = (stat.directions[direction] or 0) + 1

	-- Track call times for frequency analysis
	table.insert(stat.callTimes, entry.time)
	if #stat.callTimes > 100 then table.remove(stat.callTimes, 1) end

	-- Track argument patterns
	local pattern = table.concat(entry.argTypes, ", ")
	stat.argPatterns[pattern] = (stat.argPatterns[pattern] or 0) + 1

	-- Track return types
	if returnVal ~= nil then
		local retType = inferArgType(returnVal)
		stat.returnTypes[retType] = (stat.returnTypes[retType] or 0) + 1
	end

	-- Store example calls (first 5)
	if #stat.exampleCalls < 5 then
		table.insert(stat.exampleCalls, {
			args = entry.args,
			argTypes = entry.argTypes,
			returnVal = entry.returnVal,
			direction = direction,
			time = entry.time,
		})
	end

	-- Store unique caller stacks
	if stack and #stat.callerStacks < 5 then
		local isDuplicate = false
		for _, existing in ipairs(stat.callerStacks) do
			if existing == stack then isDuplicate = true break end
		end
		if not isDuplicate then
			table.insert(stat.callerStacks, stack)
		end
	end

	-- Real-time logging
	if CONFIG.realtimeLog then
		local filter = CONFIG.realtimeFilter
		if not filter or string.find(remotePath, filter, 1, true) then
			local argsPreview = table.concat(entry.args, ", ")
			if #argsPreview > 120 then argsPreview = string.sub(argsPreview, 1, 117) .. "..." end
			local retStr = entry.returnVal and (" -> " .. string.sub(tostring(entry.returnVal), 1, 60)) or ""
			print(string.format("[ServerSpy] [%.1fs] %s %s(%s)%s",
				entry.time, direction, remotePath, argsPreview, retStr))
		end
	end
end

-- ============================================================
-- FREQUENCY ANALYSIS
-- ============================================================

local function calculateFrequency(stat)
	local times = stat.callTimes
	if #times < 2 then return 0 end

	local duration = times[#times] - times[1]
	if duration <= 0 then return 0 end

	return #times / duration -- calls per second
end

local function calculateInterval(stat)
	local times = stat.callTimes
	if #times < 2 then return 0 end

	local intervals = {}
	for i = 2, #times do
		table.insert(intervals, times[i] - times[i-1])
	end

	-- Median interval
	table.sort(intervals)
	return intervals[math.ceil(#intervals / 2)]
end

-- ============================================================
-- HOOK ENGINE
-- ============================================================

local function hookRemote(remote)
	local remotePath = ""
	pcall(function() remotePath = remote:GetFullName() end)

	if remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent") then
		-- S->C: OnClientEvent
		local conn = remote.OnClientEvent:Connect(function(...)
			logCall(remotePath, "S->C", {...}, nil, nil)
		end)
		table.insert(connections, conn)

		-- C->S: hookfunction FireServer
		if hookfunction then
			pcall(function()
				local oldFire = remote.FireServer
				hookfunction(oldFire, function(self, ...)
					local stack = captureStack()
					logCall(remotePath, "C->S", {...}, nil, stack)
					return oldFire(self, ...)
				end)
			end)
		end

	elseif remote:IsA("RemoteFunction") then
		-- C->S: hookfunction InvokeServer (capture return value!)
		if hookfunction then
			pcall(function()
				local oldInvoke = remote.InvokeServer
				hookfunction(oldInvoke, function(self, ...)
					local stack = captureStack()
					local args = {...}
					local results = {oldInvoke(self, ...)}
					logCall(remotePath, "C->S", args, results[1], stack)
					return unpack(results)
				end)
			end)
		end

		-- S->C: OnClientInvoke wrapper
		pcall(function()
			local existingCB = remote.OnClientInvoke
			if existingCB then
				remote.OnClientInvoke = function(...)
					logCall(remotePath, "S->C (invoke)", {...}, nil, nil)
					return existingCB(...)
				end
			end
		end)
	end
end

-- __namecall hook for comprehensive coverage
local function installNamecallHook()
	if not hookmetamethod then return end

	pcall(function()
		oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
			local method = getnamecallmethod()

			if method == "FireServer" and (self:IsA("RemoteEvent") or self:IsA("UnreliableRemoteEvent")) then
				local path = ""
				pcall(function() path = self:GetFullName() end)
				local stack = captureStack()
				logCall(path, "C->S", {...}, nil, stack)
			elseif method == "InvokeServer" and self:IsA("RemoteFunction") then
				local path = ""
				pcall(function() path = self:GetFullName() end)
				local stack = captureStack()
				local args = {...}
				local results = {oldNamecall(self, ...)}
				logCall(path, "C->S", args, results[1], stack)
				return unpack(results)
			end

			return oldNamecall(self, ...)
		end)
		namecallHooked = true
	end)
end

-- ============================================================
-- INSTANCE SPAWN MONITOR
-- ============================================================

local function startInstanceMonitor()
	for _, inst in ipairs(workspace:GetDescendants()) do
		existingDescendants[inst] = true
	end

	local conn = workspace.DescendantAdded:Connect(function(desc)
		if existingDescendants[desc] then return end

		local data = {
			time      = os.clock() - startTime,
			className = "",
			fullName  = "",
			parent    = "",
			properties = {},
		}

		pcall(function() data.className = desc.ClassName end)
		pcall(function() data.fullName = desc:GetFullName() end)
		pcall(function()
			if desc.Parent then data.parent = desc.Parent:GetFullName() end
		end)

		-- Capture key properties for common types
		pcall(function()
			if desc:IsA("BasePart") then
				data.properties.Position = safeSerialize(desc.Position)
				data.properties.Size = safeSerialize(desc.Size)
				data.properties.Material = tostring(desc.Material)
				data.properties.Anchored = desc.Anchored
			elseif desc:IsA("Model") then
				local prim = desc.PrimaryPart
				if prim then
					data.properties.PrimaryPartCFrame = safeSerialize(prim.CFrame)
				end
			end
		end)

		table.insert(spawnedInstances, data)
	end)
	table.insert(connections, conn)
end

-- ============================================================
-- ATTRIBUTE CHANGE MONITOR
-- ============================================================

local function monitorPlayerAttributes()
	if not CONFIG.monitorAttributes then return end

	local function watchPlayer(player)
		local function watchChar(character)
			local conn = character.AttributeChanged:Connect(function(attrName)
				local val = character:GetAttribute(attrName)
				table.insert(attributeChanges, {
					time = os.clock() - startTime,
					player = player.Name,
					attribute = attrName,
					value = safeSerialize(val),
					target = character:GetFullName(),
				})
			end)
			table.insert(connections, conn)
		end

		if player.Character then watchChar(player.Character) end
		local conn = player.CharacterAdded:Connect(watchChar)
		table.insert(connections, conn)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		watchPlayer(player)
	end
	local conn = Players.PlayerAdded:Connect(watchPlayer)
	table.insert(connections, conn)
end

-- ============================================================
-- PUBLIC API
-- ============================================================

function ServerSpy:Start(options)
	if isRunning then return end
	isRunning = true
	startTime = os.clock()

	-- Apply options
	if options then
		for k, v in pairs(options) do
			if CONFIG[k] ~= nil then CONFIG[k] = v end
		end
	end

	-- Reset
	logs = {}
	remoteStats = {}
	spawnedInstances = {}
	attributeChanges = {}
	connections = {}
	existingDescendants = {}

	print("+==========================================?")
	print("|    SMARTCOPY ServerSpy v2 ? STARTING     |")
	print("+==========================================?")

	-- Hook existing remotes
	local count = 0
	for _, inst in ipairs(game:GetDescendants()) do
		if inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") or inst:IsA("UnreliableRemoteEvent") then
			pcall(hookRemote, inst)
			count += 1
		end
	end

	-- Hook future remotes
	local conn = game.DescendantAdded:Connect(function(desc)
		if desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") or desc:IsA("UnreliableRemoteEvent") then
			pcall(hookRemote, desc)
		end
	end)
	table.insert(connections, conn)

	-- __namecall hook
	installNamecallHook()

	-- Instance monitor
	startInstanceMonitor()

	-- Attribute monitor
	monitorPlayerAttributes()

	print(string.format("[ServerSpy] Hooked %d remotes | namecall: %s | realtime: %s",
		count,
		namecallHooked and "[OK]" or "[FAIL] (no hookmetamethod)",
		CONFIG.realtimeLog and "ON" or "OFF"))
	print("[ServerSpy] Now play the game! Use ServerSpy:Stop() when done.")
end

function ServerSpy:Stop()
	if not isRunning then return end
	isRunning = false

	for _, conn in ipairs(connections) do
		pcall(function() conn:Disconnect() end)
	end
	connections = {}

	-- Restore namecall
	if namecallHooked and oldNamecall then
		pcall(function()
			hookmetamethod(game, "__namecall", oldNamecall)
		end)
		namecallHooked = false
	end

	local duration = os.clock() - startTime
	local remoteCount = 0
	for _ in pairs(remoteStats) do remoteCount += 1 end

	print(string.format("[ServerSpy] Stopped after %.1fs | %d calls | %d remotes | %d spawned instances",
		duration, #logs, remoteCount, #spawnedInstances))
end

function ServerSpy:GetLogs() return logs end
function ServerSpy:GetRemoteStats() return remoteStats end
function ServerSpy:GetSpawnedInstances() return spawnedInstances end
function ServerSpy:GetAttributeChanges() return attributeChanges end

-- Toggle real-time logging
function ServerSpy:SetRealtime(enabled, filter)
	CONFIG.realtimeLog = enabled
	CONFIG.realtimeFilter = filter
end

-- ============================================================
-- GENERATE SERVER STUBS (v2 ? much smarter)
-- ============================================================

function ServerSpy:GenerateServerStubs()
	local stubs = {}

	for remotePath, stat in pairs(remoteStats) do
		local c2s = stat.directions["C->S"] or 0
		if c2s == 0 then continue end -- only generate for client->server

		local remoteName = string.match(remotePath, "([^%.]+)$") or remotePath
		local freq = calculateFrequency(stat)
		local interval = calculateInterval(stat)
		local category = categorizeRemote(remotePath, "C->S", nil, stat.callCount, freq)

		local L = {} -- lines builder
		local function add(s) table.insert(L, s) end

		add("-- ========================================================")
		add("-- copy by Ndrew |")
		add("-- https://bernadaclub.my.id")
		add("-- ========================================================")
		add(string.format("-- Remote: %s", remotePath))
		add(string.format("-- Category: %s", category))
		add(string.format("-- Total observed calls: %d (C->S: %d, S->C: %d)",
			stat.callCount, c2s, stat.directions["S->C"] or 0))
		add(string.format("-- Frequency: %.2f calls/sec | Interval: %.2fs", freq, interval))
		add(string.format("-- First seen: %.1fs | Last seen: %.1fs", stat.firstSeen, stat.lastSeen))
		add("-- ========================================================")
		add("")

		-- Find or create remote
		local remoteParent = string.match(remotePath, "^(.+)%.") or "game.ReplicatedStorage"
		add(string.format("local remote = %s:FindFirstChild(\"%s\")", remoteParent, remoteName))
		add("if not remote then")
		add(string.format("\tremote = Instance.new(\"RemoteEvent\")"))
		add(string.format("\tremote.Name = \"%s\"", remoteName))
		add(string.format("\tremote.Parent = %s", remoteParent))
		add("end")
		add("")

		-- Show all observed argument patterns
		add("--[[ OBSERVED ARGUMENT PATTERNS:")
		for pattern, count in pairs(stat.argPatterns) do
			add(string.format("     (%s) ? %d calls", pattern, count))
		end
		add("]]")
		add("")

		-- Show example calls
		if #stat.exampleCalls > 0 then
			add("--[[ EXAMPLE CALLS:")
			for i, ex in ipairs(stat.exampleCalls) do
				add(string.format("  %d. [%.1fs] %s -> (%s)%s",
					i, ex.time, ex.direction,
					table.concat(ex.args, ", "),
					ex.returnVal and (" -> return " .. tostring(ex.returnVal)) or ""))
			end
			add("]]")
			add("")
		end

		-- Show caller stacks
		if #stat.callerStacks > 0 then
			add("--[[ CALLED FROM:")
			for i, stack in ipairs(stat.callerStacks) do
				add(string.format("  Stack %d:", i))
				for _, line in ipairs(string.split(stack, "\n")) do
					add("    " .. line)
				end
			end
			add("]]")
			add("")
		end

		-- Show return types if any
		local hasReturns = false
		for _ in pairs(stat.returnTypes) do hasReturns = true break end
		if hasReturns then
			add("-- Return types observed:")
			for retType, count in pairs(stat.returnTypes) do
				add(string.format("--   %s ? %d", retType, count))
			end
			add("")
		end

		-- Generate handler with best-fit arg signature
		local bestPattern = ""
		local bestCount = 0
		for pattern, count in pairs(stat.argPatterns) do
			if count > bestCount then bestPattern = pattern bestCount = count end
		end

		local argNames = {}
		local argIdx = 0
		for argType in string.gmatch(bestPattern, "([^,]+)") do
			argIdx += 1
			argType = string.match(argType, "^%s*(.-)%s*$")
			local name = "arg" .. argIdx
			if argType == "string" then name = "str" .. argIdx
			elseif argType == "number" then name = "num" .. argIdx
			elseif argType == "boolean" then name = "flag" .. argIdx
			elseif string.find(argType, "Instance", 1, true) then name = "inst" .. argIdx
			elseif argType == "Vector3" then name = "pos" .. argIdx
			elseif argType == "CFrame" then name = "cf" .. argIdx
			elseif string.find(argType, "table", 1, true) then name = "data" .. argIdx
			elseif argType == "buffer" then name = "buf" .. argIdx
			end
			table.insert(argNames, name)
		end

		local argsStr = #argNames > 0 and (", " .. table.concat(argNames, ", ")) or ""

		add(string.format("remote.OnServerEvent:Connect(function(player%s)", argsStr))

		-- Category-specific stub body
		if category == "HEARTBEAT" or category == "HEARTBEAT (freq)" then
			add("\t-- HEARTBEAT: This remote is called frequently (~" .. string.format("%.1f", freq) .. " calls/sec)")
			add("\t-- Likely used for keep-alive, anti-AFK, or periodic sync")
			add("\t-- Consider: is this needed in your rebuild?")
		elseif category == "ANIMATION" then
			add("\t-- ANIMATION: Handle dance/emote/animation request")
			add("\t-- TODO: Load animation, play on character, replicate to others")
		elseif category == "INVENTORY" then
			add("\t-- INVENTORY: Handle equip/unequip/item interaction")
			add("\t-- TODO: Validate ownership, apply to character")
		elseif category == "ECONOMY" then
			add("\t-- ECONOMY: Handle purchase/transaction")
			add("\t-- TODO: Validate currency, deduct, grant item")
		elseif category == "SOCIAL" then
			add("\t-- SOCIAL: Handle like/vote/social interaction")
			add("\t-- TODO: Update social data, replicate to others")
		else
			add("\t-- TODO: Implement server logic")
		end

		-- Add arg type comments
		for i, name in ipairs(argNames) do
			local argType = (string.split(bestPattern, ", "))[i] or "?"
			add(string.format("\t-- %s: %s", name, string.match(argType, "^%s*(.-)%s*$") or "?"))
		end

		if #stat.exampleCalls > 0 then
			local ex = stat.exampleCalls[1]
			add("\t-- First observed args: " .. table.concat(ex.args, ", "))
		end

		add("end)")
		add("")

		table.insert(stubs, {
			path       = "ServerScriptService/SMARTCOPY_" .. remoteName .. ".server.lua",
			remotePath = remotePath,
			sourceCode = table.concat(L, "\n"),
			callCount  = stat.callCount,
			category   = category,
			frequency  = freq,
		})
	end

	table.sort(stubs, function(a, b) return a.callCount > b.callCount end)
	return stubs
end

-- ============================================================
-- EXPORT REPORT
-- ============================================================

function ServerSpy:ExportReport()
	local L = {}
	local function add(s) table.insert(L, s) end

	local duration = os.clock() - startTime
	local remoteCount = 0
	for _ in pairs(remoteStats) do remoteCount += 1 end

	add("+==============================================================?")
	add("|         SMARTCOPY ? ServerSpy v2 FULL REPORT               |")
	add("|         copy by Ndrew | https://bernadaclub.my.id          |")
	add("+==============================================================?")
	add("")
	add(string.format("Duration:              %.1f seconds", duration))
	add(string.format("Total calls logged:    %d", #logs))
	add(string.format("Unique remotes:        %d", remoteCount))
	add(string.format("Spawned instances:     %d", #spawnedInstances))
	add(string.format("Attribute changes:     %d", #attributeChanges))
	add(string.format("Namecall hook:         %s", namecallHooked and "Active" or "Not available"))
	add("")

	-- -- Category summary --
	add("=== REMOTE CATEGORIES ===")
	add("")
	local categories = {}
	for remotePath, stat in pairs(remoteStats) do
		local freq = calculateFrequency(stat)
		local cat = categorizeRemote(remotePath, "C->S", nil, stat.callCount, freq)
		categories[cat] = (categories[cat] or 0) + 1
	end
	for cat, count in pairs(categories) do
		add(string.format("  %-20s %d remotes", cat, count))
	end
	add("")

	-- -- Remote details --
	add("=== REMOTES (by call count) ===")
	add("")

	local sorted = {}
	for path, stat in pairs(remoteStats) do
		table.insert(sorted, {path = path, stat = stat})
	end
	table.sort(sorted, function(a, b) return a.stat.callCount > b.stat.callCount end)

	for i, entry in ipairs(sorted) do
		local stat = entry.stat
		local freq = calculateFrequency(stat)
		local interval = calculateInterval(stat)
		local cat = categorizeRemote(entry.path, "C->S", nil, stat.callCount, freq)

		add(string.format("--? %d. %s --?", i, entry.path))
		add(string.format("  Category:    %s", cat))
		add(string.format("  Calls:       %d", stat.callCount))
		add(string.format("  Frequency:   %.2f/sec (interval: %.2fs)", freq, interval))

		for dir, count in pairs(stat.directions) do
			add(string.format("  Direction:   %s ? %d", dir, count))
		end

		add("  Arg patterns:")
		for pattern, count in pairs(stat.argPatterns) do
			add(string.format("    (%s) ? %d", pattern, count))
		end

		if #stat.exampleCalls > 0 then
			add("  Examples:")
			for j, ex in ipairs(stat.exampleCalls) do
				local argsStr = table.concat(ex.args, ", ")
				if #argsStr > 100 then argsStr = string.sub(argsStr, 1, 97) .. "..." end
				add(string.format("    %d. [%.1fs] (%s)%s", j, ex.time, argsStr,
					ex.returnVal and (" -> " .. string.sub(tostring(ex.returnVal), 1, 50)) or ""))
			end
		end

		if #stat.callerStacks > 0 then
			add("  Called from:")
			for _, stack in ipairs(stat.callerStacks) do
				for _, line in ipairs(string.split(stack, "\n")) do
					add("    " .. line)
				end
			end
		end

		add("")
	end

	-- -- Spawned instances --
	if #spawnedInstances > 0 then
		add("=== SERVER-SPAWNED INSTANCES ===")
		add("")
		for i, data in ipairs(spawnedInstances) do
			if i > 300 then
				add(string.format("  ... and %d more", #spawnedInstances - 300))
				break
			end
			local propsStr = ""
			if next(data.properties) then
				local pp = {}
				for k, v in pairs(data.properties) do
					table.insert(pp, k .. "=" .. tostring(v))
				end
				propsStr = " | " .. table.concat(pp, ", ")
			end
			add(string.format("  [%.1fs] %s (%s)%s",
				data.time, data.fullName, data.className, propsStr))

			-- Correlate: what remote was called around this time?
			for _, log in ipairs(logs) do
				if math.abs(log.time - data.time) <= CONFIG.correlationWindow and log.direction == "C->S" then
					add(string.format("    -> correlated remote: %s (%s)", log.remote, table.concat(log.args, ", ")))
					break
				end
			end
		end
		add("")
	end

	-- -- Attribute changes --
	if #attributeChanges > 0 then
		add("=== ATTRIBUTE CHANGES ===")
		add("")
		local shown = 0
		for _, change in ipairs(attributeChanges) do
			shown += 1
			if shown > 100 then
				add(string.format("  ... and %d more", #attributeChanges - 100))
				break
			end
			add(string.format("  [%.1fs] %s.%s = %s",
				change.time, change.player, change.attribute, change.value))
		end
		add("")
	end

	-- -- Generated stubs summary --
	local stubs = self:GenerateServerStubs()
	if #stubs > 0 then
		add(string.format("=== %d SERVER SCRIPT STUBS GENERATED ===", #stubs))
		add("")
		for _, stub in ipairs(stubs) do
			add(string.format("  [%s] %s (%d calls, %.1f/sec)",
				stub.category, stub.path, stub.callCount, stub.frequency))
		end
	end

	local report = table.concat(L, "\n")
	print(report)
	return report
end

-- ============================================================
-- COPY TO CLIPBOARD
-- ============================================================

function ServerSpy:CopyReport()
	local report = self:ExportReport()
	pcall(function()
		if setclipboard then
			setclipboard(report)
			print("[ServerSpy] Report copied to clipboard! [OK]")
		elseif toclipboard then
			toclipboard(report)
			print("[ServerSpy] Report copied to clipboard! [OK]")
		else
			warn("[ServerSpy] No clipboard function available. Report printed above.")
		end
	end)
end

function ServerSpy:CopyStubs()
	local stubs = self:GenerateServerStubs()
	local allCode = {}
	for _, stub in ipairs(stubs) do
		table.insert(allCode, "-- FILE: " .. stub.path)
		table.insert(allCode, stub.sourceCode)
		table.insert(allCode, "\n")
	end
	local text = table.concat(allCode, "\n")
	pcall(function()
		if setclipboard then
			setclipboard(text)
			print(string.format("[ServerSpy] %d server stubs copied to clipboard! [OK]", #stubs))
		elseif toclipboard then
			toclipboard(text)
			print(string.format("[ServerSpy] %d server stubs copied to clipboard! [OK]", #stubs))
		else
			print(text)
		end
	end)
end

return ServerSpy