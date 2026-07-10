--!optimize 2
-- ╔══════════════════════════════════════════════════════════════╗
-- ║              SMARTCOPY by Ndrew — Executor Loader            ║
-- ║              https://bernadaclub.my.id                       ║
-- ╚══════════════════════════════════════════════════════════════╝
--
-- CARA PAKAI:
--   Copy-paste SELURUH script ini ke executor, lalu execute.
--   Menu akan muncul di layar, pilih module yang mau dijalankan.
--
-- ATAU jalankan langsung per-module:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/andrecanadian90-cmyk/SMARTCOPY/main/loader.luau"))()
-- ════════════════════════════════════════════════════════════════

local REPO = "https://raw.githubusercontent.com/andrecanadian90-cmyk/SMARTCOPY/main/"

-- ============================================================
-- Module loader dari GitHub
-- ============================================================
local function loadModule(name)
	local url = REPO .. "modules/" .. name .. ".luau"
	local ok, result = pcall(function()
		return loadstring(game:HttpGet(url, true), "SMARTCOPY/" .. name)()
	end)
	if ok and result then
		print("[SMARTCOPY] ✅ Loaded: " .. name)
		return result
	else
		warn("[SMARTCOPY] ❌ Failed to load: " .. name .. " — " .. tostring(result))
		return nil
	end
end

-- ============================================================
-- UI MENU
-- ============================================================
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Destroy old GUI if exists
local old = player.PlayerGui:FindFirstChild("SMARTCOPY_Menu")
if old then old:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "SMARTCOPY_Menu"
gui.DisplayOrder = 999999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.ResetOnSpawn = false

-- Protect GUI from detection
pcall(function()
	if protectgui then protectgui(gui)
	elseif syn and syn.protect_gui then syn.protect_gui(gui) end
end)

-- Parent to hidden GUI or CoreGui
pcall(function()
	local parent = (gethui and gethui()) or game:GetService("CoreGui")
	gui.Parent = parent
end)
if not gui.Parent then gui.Parent = player.PlayerGui end

-- Main frame
local frame = Instance.new("Frame")
frame.Name = "Main"
frame.Size = UDim2.new(0, 320, 0, 460)
frame.Position = UDim2.new(0.5, -160, 0.5, -230)
frame.BackgroundColor3 = Color3.fromRGB(12, 12, 20)
frame.BackgroundTransparency = 0.05
frame.BorderSizePixel = 0
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(80, 120, 255)
stroke.Thickness = 2
stroke.Transparency = 0.3
stroke.Parent = frame

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 0, 35)
title.Position = UDim2.new(0, 10, 0, 10)
title.BackgroundTransparency = 1
title.Text = "⚡ SMARTCOPY by Ndrew"
title.TextColor3 = Color3.fromRGB(100, 160, 255)
title.TextSize = 18
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, -20, 0, 18)
subtitle.Position = UDim2.new(0, 10, 0, 42)
subtitle.BackgroundTransparency = 1
subtitle.Text = "bernadaclub.my.id | Game Copier & Reconstructor"
subtitle.TextColor3 = Color3.fromRGB(100, 100, 130)
subtitle.TextSize = 11
subtitle.Font = Enum.Font.Gotham
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = frame

-- Divider
local divider = Instance.new("Frame")
divider.Size = UDim2.new(1, -20, 0, 1)
divider.Position = UDim2.new(0, 10, 0, 65)
divider.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
divider.BorderSizePixel = 0
divider.Parent = frame

-- Status label
local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.Size = UDim2.new(1, -20, 0, 20)
statusLabel.Position = UDim2.new(0, 10, 1, -30)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Ready — pilih module untuk dijalankan"
statusLabel.TextColor3 = Color3.fromRGB(80, 200, 120)
statusLabel.TextSize = 11
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = frame

-- ============================================================
-- BUTTONS
-- ============================================================

local MODULES = {
	{
		name = "🔧 UnionFixer",
		desc = "Convert Union → MeshPart (jalankan SEBELUM save)",
		module = "UnionFixer",
		action = function(mod) mod:Run({workspace}) end,
	},
	{
		name = "💾 SaveInstance (USSI)",
		desc = "Save game ke .rbxl file",
		module = nil, -- special case
		action = function()
			statusLabel.Text = "Loading USSI..."
			local ok, err = pcall(function()
				local ussi = loadstring(game:HttpGet(
					"https://raw.githubusercontent.com/luau/UniversalSynSaveInstance/main/ussi.luau", true
				))()
				ussi({
					ShowWatermark = false,
					DecompileTimeout = 60,
					FilePath = "SMARTCOPY_" .. game.PlaceId .. ".rbxl",
				})
			end)
			if not ok then
				warn("[SMARTCOPY] USSI Error: " .. tostring(err))
				statusLabel.Text = "❌ USSI gagal: " .. tostring(err)
			end
		end,
	},
	{
		name = "🔄 DecompileChecker",
		desc = "Retry script yang gagal decompile (dynamic timeout)",
		module = "DecompileChecker",
		action = function(mod) mod:Run() end,
	},
	{
		name = "🕵️ ServerSpy",
		desc = "Intercept semua Remote — START monitoring",
		module = "ServerSpy",
		action = function(mod)
			mod:Start()
			statusLabel.Text = "🕵️ ServerSpy ACTIVE — mainkan game!"

			-- Add stop button
			task.delay(1, function()
				local stopBtn = frame:FindFirstChild("StopSpy")
				if stopBtn then stopBtn:Destroy() end

				stopBtn = Instance.new("TextButton")
				stopBtn.Name = "StopSpy"
				stopBtn.Size = UDim2.new(1, -20, 0, 30)
				stopBtn.Position = UDim2.new(0, 10, 1, -65)
				stopBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
				stopBtn.Text = "⏹ STOP ServerSpy & Copy Report"
				stopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
				stopBtn.TextSize = 12
				stopBtn.Font = Enum.Font.GothamBold
				stopBtn.BorderSizePixel = 0
				stopBtn.Parent = frame

				local c = Instance.new("UICorner")
				c.CornerRadius = UDim.new(0, 8)
				c.Parent = stopBtn

				stopBtn.MouseButton1Click:Connect(function()
					mod:Stop()
					mod:CopyReport()
					statusLabel.Text = "✅ Report copied to clipboard!"
					stopBtn:Destroy()
				end)
			end)
		end,
	},
	{
		name = "🎨 AssetRipper",
		desc = "Scan & extract semua asset IDs",
		module = "AssetRipper",
		action = function(mod)
			mod:Scan({workspace}, function(pct)
				statusLabel.Text = string.format("Scanning... %.0f%%", pct * 100)
			end)
			mod:CopyReport()
			statusLabel.Text = "✅ Asset report copied to clipboard!"
		end,
	},
	{
		name = "🏔️ TerrainExtractor",
		desc = "Extract terrain voxel data",
		module = "TerrainExtractor",
		action = function(mod)
			mod:Extract({
				onProgress = function(pct)
					statusLabel.Text = string.format("Extracting terrain... %.0f%%", pct * 100)
				end,
			})
			mod:CopyRestoreScript()
			statusLabel.Text = "✅ Terrain restore script copied!"
		end,
	},
	{
		name = "🏷️ WatermarkReplacer",
		desc = "Replace watermark → 'copy by Ndrew'",
		module = "WatermarkReplacer",
		action = function(mod)
			mod:Run()
			statusLabel.Text = "✅ Watermark replaced!"
		end,
	},
	{
		name = "🧹 WatermarkCleaner",
		desc = "Hapus semua watermark USSI",
		module = "WatermarkCleaner",
		action = function(mod)
			mod:Run()
			statusLabel.Text = "✅ Watermark cleaned!"
		end,
	},
}

local btnY = 75
for i, info in ipairs(MODULES) do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -20, 0, 38)
	btn.Position = UDim2.new(0, 10, 0, btnY)
	btn.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
	btn.BorderSizePixel = 0
	btn.Text = ""
	btn.Parent = frame

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent = btn

	local btnStroke = Instance.new("UIStroke")
	btnStroke.Color = Color3.fromRGB(50, 50, 70)
	btnStroke.Thickness = 1
	btnStroke.Parent = btn

	-- Button title
	local btnTitle = Instance.new("TextLabel")
	btnTitle.Size = UDim2.new(1, -10, 0, 18)
	btnTitle.Position = UDim2.new(0, 8, 0, 3)
	btnTitle.BackgroundTransparency = 1
	btnTitle.Text = info.name
	btnTitle.TextColor3 = Color3.fromRGB(220, 220, 240)
	btnTitle.TextSize = 13
	btnTitle.Font = Enum.Font.GothamBold
	btnTitle.TextXAlignment = Enum.TextXAlignment.Left
	btnTitle.Parent = btn

	-- Button description
	local btnDesc = Instance.new("TextLabel")
	btnDesc.Size = UDim2.new(1, -10, 0, 14)
	btnDesc.Position = UDim2.new(0, 8, 0, 20)
	btnDesc.BackgroundTransparency = 1
	btnDesc.Text = info.desc
	btnDesc.TextColor3 = Color3.fromRGB(100, 100, 130)
	btnDesc.TextSize = 10
	btnDesc.Font = Enum.Font.Gotham
	btnDesc.TextXAlignment = Enum.TextXAlignment.Left
	btnDesc.Parent = btn

	-- Hover effects
	btn.MouseEnter:Connect(function()
		btn.BackgroundColor3 = Color3.fromRGB(35, 35, 60)
		btnStroke.Color = Color3.fromRGB(80, 120, 255)
	end)
	btn.MouseLeave:Connect(function()
		btn.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
		btnStroke.Color = Color3.fromRGB(50, 50, 70)
	end)

	-- Click handler
	btn.MouseButton1Click:Connect(function()
		statusLabel.Text = "⏳ Loading " .. info.name .. "..."
		statusLabel.TextColor3 = Color3.fromRGB(255, 200, 80)

		task.defer(function()
			local ok, err = pcall(function()
				if info.module then
					local mod = loadModule(info.module)
					if mod then
						info.action(mod)
					else
						statusLabel.Text = "❌ Gagal load " .. info.module
						statusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
					end
				else
					info.action()
				end
			end)

			if not ok then
				warn("[SMARTCOPY] Error: " .. tostring(err))
				statusLabel.Text = "❌ Error: " .. string.sub(tostring(err), 1, 50)
				statusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
			else
				statusLabel.TextColor3 = Color3.fromRGB(80, 200, 120)
			end
		end)
	end)

	btnY += 44
end

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 24, 0, 24)
closeBtn.Position = UDim2.new(1, -32, 0, 8)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 14
closeBtn.Font = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0
closeBtn.Parent = frame

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeBtn

closeBtn.MouseButton1Click:Connect(function()
	gui:Destroy()
end)

-- Make draggable
local dragging, dragStart, startPos
frame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position
		startPos = frame.Position
	end
end)

frame.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
	end
end)

game:GetService("UserInputService").InputChanged:Connect(function(input)
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Position - dragStart
		frame.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end
end)

print("╔══════════════════════════════════════════╗")
print("║     SMARTCOPY by Ndrew — LOADED! ⚡       ║")
print("║     bernadaclub.my.id                    ║")
print("╚══════════════════════════════════════════╝")
