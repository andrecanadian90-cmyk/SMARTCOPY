--!optimize 2
-- NexusCopy Utilities Module
-- Shared helpers for all NexusCopy modules
-- https://github.com/nexuscopy

local Utilities = {}

--------------------------------------------------------------
-- Safe Property Access
--------------------------------------------------------------

--- Safely read a property from an instance, returns (success, value)
function Utilities.safeGet(instance, propertyName)
	local ok, val = pcall(function()
		return instance[propertyName]
	end)
	return ok, val
end

--- Safely call a method on an instance
function Utilities.safeCall(instance, methodName, ...)
	local args = { ... }
	local ok, result = pcall(function()
		return instance[methodName](instance, unpack(args))
	end)
	return ok, result
end

--------------------------------------------------------------
-- Argument Serialization (safe for logging)
--------------------------------------------------------------

--- Safely serialize a value to a readable string (for logging Remote args, etc.)
--- Handles: Instance, CFrame, Vector3, Color3, Enum, tables, primitives
--- Does NOT error on userdata — returns a safe placeholder instead
function Utilities.safeSerialize(value, depth)
	depth = depth or 0
	if depth > 5 then return "..." end -- prevent infinite recursion

	local t = typeof(value)

	if t == "nil" then
		return "nil"
	elseif t == "string" then
		return string.format("%q", value)
	elseif t == "number" then
		if value ~= value then return "NaN"
		elseif value == math.huge then return "math.huge"
		elseif value == -math.huge then return "-math.huge"
		end
		return tostring(value)
	elseif t == "boolean" then
		return tostring(value)
	elseif t == "Instance" then
		local ok, fullName = pcall(function() return value:GetFullName() end)
		return ok and ("Instance<" .. fullName .. ">") or "Instance<destroyed>"
	elseif t == "CFrame" then
		local x, y, z = value.Position.X, value.Position.Y, value.Position.Z
		return string.format("CFrame(%g, %g, %g, ...)", x, y, z)
	elseif t == "Vector3" then
		return string.format("Vector3(%g, %g, %g)", value.X, value.Y, value.Z)
	elseif t == "Vector2" then
		return string.format("Vector2(%g, %g)", value.X, value.Y)
	elseif t == "Color3" then
		return string.format("Color3(%g, %g, %g)", value.R, value.G, value.B)
	elseif t == "BrickColor" then
		return "BrickColor(\"" .. tostring(value) .. "\")"
	elseif t == "UDim2" then
		return string.format("UDim2(%g, %d, %g, %d)", value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset)
	elseif t == "EnumItem" then
		return tostring(value)
	elseif t == "table" then
		local parts = {}
		local count = 0
		for k, v in pairs(value) do
			count += 1
			if count > 20 then
				table.insert(parts, "... +" .. (Utilities.tableCount(value) - 20) .. " more")
				break
			end
			local keyStr = type(k) == "number" and "" or ("[" .. Utilities.safeSerialize(k, depth + 1) .. "] = ")
			table.insert(parts, keyStr .. Utilities.safeSerialize(v, depth + 1))
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	elseif t == "function" then
		return "function(...)"
	elseif t == "buffer" then
		return "buffer(" .. buffer.len(value) .. " bytes)"
	else
		-- Fallback for any userdata type
		local ok, str = pcall(tostring, value)
		return ok and (t .. "<" .. str .. ">") or (t .. "<?>")
	end
end

--- Count items in a table (including non-numeric keys)
function Utilities.tableCount(t)
	local count = 0
	for _ in pairs(t) do count += 1 end
	return count
end

--------------------------------------------------------------
-- Asset ID Extraction
--------------------------------------------------------------

--- Extract numeric asset ID from various Roblox URL formats
--- Handles: rbxassetid://12345, http(s)://roblox.com/asset/?id=12345, etc.
function Utilities.extractAssetId(url)
	if not url or url == "" then return nil end
	url = tostring(url)

	-- rbxassetid://12345
	local id = string.match(url, "rbxassetid://(%d+)")
	if id then return tonumber(id) end

	-- http(s)://www.roblox.com/asset/?id=12345
	id = string.match(url, "[?&]id=(%d+)")
	if id then return tonumber(id) end

	-- rbxasset:// (local engine asset, skip)
	if string.find(url, "rbxasset://", 1, true) then return nil end

	-- rbxthumb:// (thumbnail, skip)
	if string.find(url, "rbxthumb://", 1, true) then return nil end

	-- Plain number
	id = string.match(url, "^(%d+)$")
	if id then return tonumber(id) end

	return nil
end

--- Convert asset ID to download URL
function Utilities.assetIdToUrl(id)
	return "https://assetdelivery.roblox.com/v1/asset/?id=" .. tostring(id)
end

--------------------------------------------------------------
-- Logging
--------------------------------------------------------------

local logBuffer = {}

function Utilities.log(level, module, message)
	local entry = {
		time = os.clock(),
		level = level,
		module = module,
		message = message,
	}
	table.insert(logBuffer, entry)

	-- Also print to console
	local prefix = string.format("[NexusCopy/%s] [%s]", module, level)
	print(prefix, message)
end

function Utilities.info(module, message) Utilities.log("INFO", module, message) end
function Utilities.warn(module, message) Utilities.log("WARN", module, message) end
function Utilities.error(module, message) Utilities.log("ERROR", module, message) end
function Utilities.debug(module, message) Utilities.log("DEBUG", module, message) end

function Utilities.getLogs()
	return logBuffer
end

--------------------------------------------------------------
-- Status UI
--------------------------------------------------------------

local statusGui = nil

function Utilities.createStatusUI()
	-- Create a simple status overlay
	local ok, gui = pcall(function()
		local screenGui = Instance.new("ScreenGui")
		screenGui.Name = "NexusCopyStatus"
		screenGui.DisplayOrder = 999999
		screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		screenGui.ResetOnSpawn = false

		local frame = Instance.new("Frame")
		frame.Name = "StatusFrame"
		frame.Size = UDim2.new(0, 350, 0, 120)
		frame.Position = UDim2.new(1, -370, 0, 20)
		frame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
		frame.BackgroundTransparency = 0.15
		frame.BorderSizePixel = 0
		frame.Parent = screenGui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = frame

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(100, 60, 255)
		stroke.Thickness = 2
		stroke.Transparency = 0.3
		stroke.Parent = frame

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.new(1, -20, 0, 25)
		title.Position = UDim2.new(0, 10, 0, 8)
		title.BackgroundTransparency = 1
		title.Text = "⚡ NexusCopy"
		title.TextColor3 = Color3.fromRGB(140, 100, 255)
		title.TextSize = 16
		title.Font = Enum.Font.GothamBold
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Parent = frame

		local status = Instance.new("TextLabel")
		status.Name = "Status"
		status.Size = UDim2.new(1, -20, 0, 20)
		status.Position = UDim2.new(0, 10, 0, 35)
		status.BackgroundTransparency = 1
		status.Text = "Initializing..."
		status.TextColor3 = Color3.fromRGB(200, 200, 220)
		status.TextSize = 13
		status.Font = Enum.Font.Gotham
		status.TextXAlignment = Enum.TextXAlignment.Left
		status.TextTruncate = Enum.TextTruncate.AtEnd
		status.Parent = frame

		local progressBg = Instance.new("Frame")
		progressBg.Name = "ProgressBg"
		progressBg.Size = UDim2.new(1, -20, 0, 8)
		progressBg.Position = UDim2.new(0, 10, 0, 62)
		progressBg.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
		progressBg.BorderSizePixel = 0
		progressBg.Parent = frame

		local progressCorner = Instance.new("UICorner")
		progressCorner.CornerRadius = UDim.new(0, 4)
		progressCorner.Parent = progressBg

		local progressFill = Instance.new("Frame")
		progressFill.Name = "ProgressFill"
		progressFill.Size = UDim2.new(0, 0, 1, 0)
		progressFill.BackgroundColor3 = Color3.fromRGB(100, 60, 255)
		progressFill.BorderSizePixel = 0
		progressFill.Parent = progressBg

		local progressFillCorner = Instance.new("UICorner")
		progressFillCorner.CornerRadius = UDim.new(0, 4)
		progressFillCorner.Parent = progressFill

		local detail = Instance.new("TextLabel")
		detail.Name = "Detail"
		detail.Size = UDim2.new(1, -20, 0, 18)
		detail.Position = UDim2.new(0, 10, 0, 78)
		detail.BackgroundTransparency = 1
		detail.Text = ""
		detail.TextColor3 = Color3.fromRGB(140, 140, 160)
		detail.TextSize = 11
		detail.Font = Enum.Font.Gotham
		detail.TextXAlignment = Enum.TextXAlignment.Left
		detail.TextTruncate = Enum.TextTruncate.AtEnd
		detail.Parent = frame

		-- Try to parent to protected GUI
		local protectgui = protectgui or (syn and syn.protect_gui)
		if protectgui then
			pcall(protectgui, screenGui)
		end

		local gethui = gethui or get_hidden_gui
		local parent = (gethui and gethui()) or game:GetService("CoreGui")
		screenGui.Parent = parent

		return screenGui
	end)

	if ok then
		statusGui = gui
	end
	return gui
end

function Utilities.updateStatus(statusText, progress, detailText)
	if not statusGui then return end

	pcall(function()
		local frame = statusGui:FindFirstChild("StatusFrame")
		if not frame then return end

		if statusText then
			frame.Status.Text = statusText
		end

		if progress then
			local fill = frame.ProgressBg.ProgressFill
			fill.Size = UDim2.new(math.clamp(progress, 0, 1), 0, 1, 0)
		end

		if detailText then
			frame.Detail.Text = detailText
		end
	end)
end

function Utilities.destroyStatusUI()
	if statusGui then
		pcall(function() statusGui:Destroy() end)
		statusGui = nil
	end
end

--------------------------------------------------------------
-- File Writing (chunked, safe)
--------------------------------------------------------------

--- Write large content to file using chunked appendfile to avoid crashes
function Utilities.writeFileSafe(filePath, content, chunkSize)
	chunkSize = chunkSize or 1024 * 512 -- 512KB chunks

	if #content <= chunkSize then
		-- Small enough for direct write
		writefile(filePath, content)
		return true
	end

	-- Chunked write using appendfile
	writefile(filePath, "") -- create/clear file
	for i = 1, #content, chunkSize do
		local chunk = string.sub(content, i, i + chunkSize - 1)
		appendfile(filePath, chunk)
	end
	return true
end

--------------------------------------------------------------
-- Time Formatting
--------------------------------------------------------------

function Utilities.formatTime(seconds)
	if seconds < 60 then
		return string.format("%.1fs", seconds)
	elseif seconds < 3600 then
		return string.format("%dm %ds", math.floor(seconds / 60), math.floor(seconds % 60))
	else
		return string.format("%dh %dm", math.floor(seconds / 3600), math.floor((seconds % 3600) / 60))
	end
end

function Utilities.formatSize(bytes)
	if bytes < 1024 then
		return bytes .. " B"
	elseif bytes < 1024 * 1024 then
		return string.format("%.1f KB", bytes / 1024)
	else
		return string.format("%.1f MB", bytes / (1024 * 1024))
	end
end

return Utilities
