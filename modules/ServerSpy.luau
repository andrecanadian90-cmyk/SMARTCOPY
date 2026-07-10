--!optimize 2
-- ============================================================
-- NexusCopy — ServerSpy Module
-- Intercepts ALL Remote communication to reconstruct server
-- logic and captures server-spawned objects
-- ============================================================

local ServerSpy = {}
ServerSpy.__index = ServerSpy

local HttpService = game:GetService("HttpService")

--------------------------------------------------------------
-- State
--------------------------------------------------------------
local isRunning = false
local logs = {}          -- All intercepted calls
local remoteStats = {}   -- remotePath → {callCount, lastArgs, direction, argTypes}
local spawnedInstances = {} -- Instances that appeared after monitoring started
local connections = {}   -- Active event connections (for cleanup)
local existingDescendants = {} -- Snapshot of existing instances before monitoring

--------------------------------------------------------------
-- Safe argument serialization
--------------------------------------------------------------
local function safeSerializeArg(value, depth)
	depth = depth or 0
	if depth > 3 then return "..." end

	local t = typeof(value)
	if value == nil then return "nil"
	elseif t == "string" then
		if #value > 200 then return string.format("%q...(+%d chars)", string.sub(value, 1, 100), #value - 100) end
		return string.format("%q", value)
	elseif t == "number" or t == "boolean" then return tostring(value)
	elseif t == "Instance" then
		local ok, name = pcall(function() return value:GetFullName() end)
		return ok and ("Instance<" .. name .. ">") or "Instance<???>"
	elseif t == "Vector3" then return string.format("Vector3(%g,%g,%g)", value.X, value.Y, value.Z)
	elseif t == "CFrame" then
		local p = value.Position
		return string.format("CFrame(%g,%g,%g,...)", p.X, p.Y, p.Z)
	elseif t == "Color3" then return string.format("Color3(%g,%g,%g)", value.R, value.G, value.B)
	elseif t == "UDim2" then return string.format("UDim2(%g,%d,%g,%d)", value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset)
	elseif t == "EnumItem" then return tostring(value)
	elseif t == "table" then
		local parts = {}
		local count = 0
		for k, v in pairs(value) do
			count += 1
			if count > 10 then table.insert(parts, "...") break end
			table.insert(parts, safeSerializeArg(k, depth + 1) .. "=" .. safeSerializeArg(v, depth + 1))
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	else
		local ok, s = pcall(tostring, value)
		return ok and (t .. "<" .. s .. ">") or t
	end
end

local function serializeArgs(args)
	local result = {}
	for i, arg in ipairs(args) do
		table.insert(result, safeSerializeArg(arg))
	end
	return result
end

local function inferArgType(value)
	local t = typeof(value)
	if t == "Instance" then
		local ok, cn = pcall(function() return value.ClassName end)
		return ok and ("Instance<" .. cn .. ">") or "Instance"
	end
	return t
end

--------------------------------------------------------------
-- Log a remote call
--------------------------------------------------------------
local function logCall(remotePath, direction, args)
	local entry = {
		time = os.clock(),
		remote = remotePath,
		direction = direction, -- "C→S" or "S→C"
		args = serializeArgs(args),
		argTypes = {},
	}

	for _, arg in ipairs(args) do
		table.insert(entry.argTypes, inferArgType(arg))
	end

	table.insert(logs, entry)

	-- Update stats
	if not remoteStats[remotePath] then
		remoteStats[remotePath] = {
			callCount = 0,
			directions = {},
			argPatterns = {},
			firstSeen = os.clock(),
		}
	end

	local stat = remoteStats[remotePath]
	stat.callCount += 1
	stat.lastArgs = entry.args
	stat.directions[direction] = (stat.directions[direction] or 0) + 1

	-- Track argument type patterns
	local pattern = table.concat(entry.argTypes, ", ")
	stat.argPatterns[pattern] = (stat.argPatterns[pattern] or 0) + 1
end

--------------------------------------------------------------
-- Hook Remote Events & Functions
--------------------------------------------------------------
local function hookRemote(remote)
	local remotePath = ""
	pcall(function() remotePath = remote:GetFullName() end)

	if remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent") then
		-- Hook server → client (OnClientEvent)
		local conn = remote.OnClientEvent:Connect(function(...)
			logCall(remotePath, "S→C", { ... })
		end)
		table.insert(connections, conn)

		-- Hook client → server (FireServer)
		-- Need hookfunction from executor
		if hookfunction then
			pcall(function()
				local oldFire = remote.FireServer
				hookfunction(oldFire, function(self, ...)
					logCall(remotePath, "C→S", { ... })
					return oldFire(self, ...)
				end)
			end)
		end

	elseif remote:IsA("RemoteFunction") then
		-- Hook client → server (InvokeServer)
		if hookfunction then
			pcall(function()
				local oldInvoke = remote.InvokeServer
				hookfunction(oldInvoke, function(self, ...)
					logCall(remotePath, "C→S", { ... })
					return oldInvoke(self, ...)
				end)
			end)
		end

		-- Hook server → client (OnClientInvoke)
		local existingCallback = remote.OnClientInvoke
		if existingCallback then
			remote.OnClientInvoke = function(...)
				logCall(remotePath, "S→C", { ... })
				return existingCallback(...)
			end
		end
	end
end

--------------------------------------------------------------
-- Monitor for server-spawned instances
--------------------------------------------------------------
local function startInstanceMonitor()
	-- Take snapshot of existing instances
	for _, inst in ipairs(workspace:GetDescendants()) do
		existingDescendants[inst] = true
	end

	-- Watch for new instances
	local conn = workspace.DescendantAdded:Connect(function(descendant)
		if not existingDescendants[descendant] then
			-- This instance was created/cloned by the server after we started monitoring
			local data = {
				instance = descendant,
				time = os.clock(),
				className = "",
				fullName = "",
				parent = "",
			}

			pcall(function() data.className = descendant.ClassName end)
			pcall(function() data.fullName = descendant:GetFullName() end)
			pcall(function()
				if descendant.Parent then
					data.parent = descendant.Parent:GetFullName()
				end
			end)

			table.insert(spawnedInstances, data)
		end
	end)
	table.insert(connections, conn)
end

--------------------------------------------------------------
-- Public API
--------------------------------------------------------------

function ServerSpy:Start()
	if isRunning then return end
	isRunning = true

	-- Reset state
	logs = {}
	remoteStats = {}
	spawnedInstances = {}
	connections = {}
	existingDescendants = {}

	print("[NexusCopy/ServerSpy] Starting remote interception...")

	-- Find and hook all existing remotes
	local remoteCount = 0
	for _, instance in ipairs(game:GetDescendants()) do
		if instance:IsA("RemoteEvent") or instance:IsA("RemoteFunction") or instance:IsA("UnreliableRemoteEvent") then
			pcall(hookRemote, instance)
			remoteCount += 1
		end
	end

	-- Hook newly created remotes
	local conn = game.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction") or descendant:IsA("UnreliableRemoteEvent") then
			pcall(hookRemote, descendant)
		end
	end)
	table.insert(connections, conn)

	-- Start instance monitor
	startInstanceMonitor()

	print(string.format("[NexusCopy/ServerSpy] Hooked %d remotes. Monitoring active.", remoteCount))
end

function ServerSpy:Stop()
	if not isRunning then return end
	isRunning = false

	for _, conn in ipairs(connections) do
		pcall(function() conn:Disconnect() end)
	end
	connections = {}

	print(string.format("[NexusCopy/ServerSpy] Stopped. Captured %d calls across %d remotes.",
		#logs, self:_countRemotes()))
end

function ServerSpy:_countRemotes()
	local count = 0
	for _ in pairs(remoteStats) do count += 1 end
	return count
end

function ServerSpy:GetLogs()
	return logs
end

function ServerSpy:GetRemoteList()
	local list = {}
	for path, stat in pairs(remoteStats) do
		table.insert(list, {
			path = path,
			callCount = stat.callCount,
			directions = stat.directions,
			argPatterns = stat.argPatterns,
			firstSeen = stat.firstSeen,
		})
	end
	table.sort(list, function(a, b) return a.callCount > b.callCount end)
	return list
end

function ServerSpy:GetSpawnedInstances()
	return spawnedInstances
end

--------------------------------------------------------------
-- Generate server script stubs from observed patterns
--------------------------------------------------------------
function ServerSpy:GenerateServerStubs()
	local stubs = {}

	for remotePath, stat in pairs(remoteStats) do
		-- Only generate stubs for remotes that received FireServer (C→S) calls
		local clientToServer = stat.directions["C→S"]
		if clientToServer and clientToServer > 0 then
			local remoteName = string.match(remotePath, "([^%.]+)$") or remotePath
			local lines = {}

			table.insert(lines, "-- ============================================================")
			table.insert(lines, "-- NexusCopy — Auto-generated Server Script Stub")
			table.insert(lines, string.format("-- Remote: %s", remotePath))
			table.insert(lines, string.format("-- Total calls observed: %d (C→S: %d, S→C: %d)",
				stat.callCount,
				stat.directions["C→S"] or 0,
				stat.directions["S→C"] or 0))
			table.insert(lines, "-- ============================================================")
			table.insert(lines, "")

			-- Find the remote
			table.insert(lines, string.format('local remote = game:FindFirstChild("%s", true)', remoteName))
			table.insert(lines, 'if not remote then')
			table.insert(lines, string.format('\tremote = Instance.new("RemoteEvent")'))
			table.insert(lines, string.format('\tremote.Name = "%s"', remoteName))
			table.insert(lines, string.format('\tremote.Parent = game.ReplicatedStorage'))
			table.insert(lines, 'end')
			table.insert(lines, "")

			-- Generate handler based on observed arg patterns
			table.insert(lines, "-- Observed argument patterns:")
			for pattern, count in pairs(stat.argPatterns) do
				table.insert(lines, string.format("--   (%s) × %d calls", pattern, count))
			end
			table.insert(lines, "")

			-- Find most common pattern for the handler signature
			local bestPattern = ""
			local bestCount = 0
			for pattern, count in pairs(stat.argPatterns) do
				if count > bestCount then
					bestPattern = pattern
					bestCount = count
				end
			end

			-- Generate handler with typed args
			local argNames = {}
			local argIdx = 0
			for argType in string.gmatch(bestPattern, "([^,]+)") do
				argIdx += 1
				argType = string.match(argType, "^%s*(.-)%s*$") -- trim
				local name = "arg" .. argIdx
				if argType == "string" then name = "str" .. argIdx
				elseif argType == "number" then name = "num" .. argIdx
				elseif argType == "boolean" then name = "bool" .. argIdx
				elseif string.find(argType, "Instance", 1, true) then name = "inst" .. argIdx
				elseif argType == "Vector3" then name = "pos" .. argIdx
				elseif argType == "CFrame" then name = "cf" .. argIdx
				end
				table.insert(argNames, name)
			end

			local argsStr = #argNames > 0 and (", " .. table.concat(argNames, ", ")) or ""

			table.insert(lines, string.format("remote.OnServerEvent:Connect(function(player%s)", argsStr))
			table.insert(lines, string.format("\t-- TODO: Implement server logic"))
			table.insert(lines, string.format("\t-- This remote was called %d times during monitoring", clientToServer))

			-- Add last observed args as comment
			if stat.lastArgs then
				table.insert(lines, "\t-- Last observed args: " .. table.concat(stat.lastArgs, ", "))
			end

			table.insert(lines, "end)")
			table.insert(lines, "")

			table.insert(stubs, {
				path = "ServerScriptService/NexusCopy_" .. remoteName .. ".server.lua",
				remotePath = remotePath,
				sourceCode = table.concat(lines, "\n"),
				callCount = stat.callCount,
			})
		end
	end

	-- Sort by call count (most active remotes first)
	table.sort(stubs, function(a, b) return a.callCount > b.callCount end)

	return stubs
end

--------------------------------------------------------------
-- Export full report
--------------------------------------------------------------
function ServerSpy:ExportReport()
	local lines = {}

	table.insert(lines, "╔══════════════════════════════════════════════════════════╗")
	table.insert(lines, "║           NexusCopy — ServerSpy Report                  ║")
	table.insert(lines, "╚══════════════════════════════════════════════════════════╝")
	table.insert(lines, "")

	-- Summary
	table.insert(lines, string.format("Total calls logged: %d", #logs))
	table.insert(lines, string.format("Unique remotes: %d", self:_countRemotes()))
	table.insert(lines, string.format("Server-spawned instances: %d", #spawnedInstances))
	table.insert(lines, "")

	-- Remote list sorted by activity
	table.insert(lines, "═══ REMOTES (sorted by call count) ═══")
	table.insert(lines, "")

	local remoteList = self:GetRemoteList()
	for i, r in ipairs(remoteList) do
		table.insert(lines, string.format("%d. [%d calls] %s", i, r.callCount, r.path))
		for dir, count in pairs(r.directions) do
			table.insert(lines, string.format("   %s: %d", dir, count))
		end
		table.insert(lines, "   Arg patterns:")
		for pattern, count in pairs(r.argPatterns) do
			table.insert(lines, string.format("     (%s) × %d", pattern, count))
		end
		table.insert(lines, "")
	end

	-- Spawned instances
	if #spawnedInstances > 0 then
		table.insert(lines, "═══ SERVER-SPAWNED INSTANCES ═══")
		table.insert(lines, "")
		for i, data in ipairs(spawnedInstances) do
			if i > 200 then
				table.insert(lines, string.format("... and %d more", #spawnedInstances - 200))
				break
			end
			table.insert(lines, string.format("  [%.1fs] %s (%s) → parent: %s",
				data.time, data.fullName, data.className, data.parent))
		end
		table.insert(lines, "")
	end

	-- Generated stubs summary
	local stubs = self:GenerateServerStubs()
	if #stubs > 0 then
		table.insert(lines, string.format("═══ GENERATED %d SERVER SCRIPT STUBS ═══", #stubs))
		for _, stub in ipairs(stubs) do
			table.insert(lines, string.format("  %s (%d calls)", stub.path, stub.callCount))
		end
	end

	return table.concat(lines, "\n")
end

return ServerSpy
