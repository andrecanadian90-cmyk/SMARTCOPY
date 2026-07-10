--!native
--!optimize 2
-- ============================================================
-- SMARTCOPY v2.0 by Ndrew — Advanced Roblox Map Copier
-- copy by Ndrew | https://bernadaclub.my.id
--
-- Full map extraction: terrain, meshes, textures, assets,
-- scripts, Remote reconstruction, nil instances
-- 
-- Usage:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/andrecanadian90-cmyk/SMARTCOPY/main/main.luau", true))()()
-- 
-- With custom options:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/andrecanadian90-cmyk/SMARTCOPY/main/main.luau", true))()({
--       mode = "full",
--       FixUnions = true,
--       IncludeTerrain = false,
--       IncludeAssets = true,
--       DownloadAssets = true,
--       ServerSpy = true,
--       ServerSpyDuration = 60,
--       Decompile = true,
--       NilInstances = true,
--       SafeMode = true,
--       ReplaceWatermark = true,
--   })
-- ============================================================

local SMARTCOPY_VERSION = "2.0.0"
local REPO_BASE = "https://raw.githubusercontent.com/andrecanadian90-cmyk/SMARTCOPY/main/"

-- ============================================================
-- Module Loader
-- Loads modules from GitHub
-- ============================================================
local function loadModule(name)
	local ok, module = pcall(function()
		return loadstring(
			game:HttpGet(REPO_BASE .. "modules/" .. name .. ".luau", true),
			"SMARTCOPY/" .. name
		)()
	end)

	if ok and module then
		print("[SMARTCOPY] Loaded module: " .. name)
		return module
	end

	warn("[SMARTCOPY] Failed to load module from repo: " .. name)
	return nil
end

-- ============================================================
-- USSI Loader
-- Loads UniversalSynSaveInstance as the base saveinstance engine
-- ============================================================
local function loadUSSI()
	local ok, synsaveinstance = pcall(function()
		return loadstring(
			game:HttpGet("https://raw.githubusercontent.com/luau/UniversalSynSaveInstance/main/saveinstance.luau", true),
			"saveinstance"
		)()
	end)

	if ok and synsaveinstance then
		print("[SMARTCOPY] Loaded USSI saveinstance engine")
		return synsaveinstance
	end

	warn("[SMARTCOPY] Failed to load USSI!")
	return nil
end

-- ============================================================
-- Main Orchestrator
-- ============================================================
return function(userOptions)
	userOptions = userOptions or {}

	-- Default options
	local options = {
		-- Save Instance options (passed to USSI)
		mode = userOptions.mode or "full",
		SafeMode = userOptions.SafeMode ~= false, -- default true (USSI kicks player for clean save)
		Decompile = userOptions.Decompile ~= false, -- default true
		DecompileTimeout = userOptions.DecompileTimeout or 30,
		NilInstances = userOptions.NilInstances ~= false, -- default true
		IgnoreDefaultProperties = userOptions.IgnoreDefaultProperties ~= false,
		IgnoreNotArchivable = userOptions.IgnoreNotArchivable ~= false,
		SaveNotCreatable = userOptions.SaveNotCreatable ~= false,
		IsolateLocalPlayer = userOptions.IsolateLocalPlayer ~= false,
		SaveBytecode = userOptions.SaveBytecode or false,
		ShowStatus = userOptions.ShowStatus ~= false,
		IgnoreSharedStrings = userOptions.IgnoreSharedStrings or false,
		FilePath = userOptions.FilePath or false,

		-- SMARTCOPY extensions
		FixUnions = userOptions.FixUnions ~= false,             -- default true
		IncludeTerrain = userOptions.IncludeTerrain or false,    -- default false
		IncludeAssets = userOptions.IncludeAssets ~= false,      -- default true
		ServerSpy = userOptions.ServerSpy or false,              -- default false (requires duration wait)
		ServerSpyDuration = userOptions.ServerSpyDuration or 60, -- seconds to monitor
		DownloadAssets = userOptions.DownloadAssets or false,     -- generate download script
		ReplaceWatermark = userOptions.ReplaceWatermark ~= false,   -- default true
	}

	local startTime = os.clock()

	print("╔══════════════════════════════════════════════════════════╗")
	print("║          ⚡ SMARTCOPY v" .. SMARTCOPY_VERSION .. " by Ndrew                ║")
	print("║          https://bernadaclub.my.id                      ║")
	print("║          Advanced Roblox Map Copier                     ║")
	print("╚══════════════════════════════════════════════════════════╝")
	print("")

	-- ========================================
	-- Phase 0: Create Status UI
	-- ========================================
	local statusGui
	if options.ShowStatus then
		pcall(function()
			local screenGui = Instance.new("ScreenGui")
			screenGui.Name = "SMARTCOPYStatus"
			screenGui.DisplayOrder = 999999
			screenGui.ResetOnSpawn = false

			local frame = Instance.new("Frame")
			frame.Size = UDim2.new(0, 380, 0, 150)
			frame.Position = UDim2.new(1, -400, 0, 20)
			frame.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
			frame.BackgroundTransparency = 0.15
			frame.BorderSizePixel = 0
			frame.Parent = screenGui

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 10)
			corner.Parent = frame

			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.fromRGB(45, 45, 48)
			stroke.Thickness = 1.5
			stroke.Parent = frame

			-- Title
			local title = Instance.new("TextLabel")
			title.Size = UDim2.new(1, -120, 0, 25)
			title.Position = UDim2.new(0, 15, 0, 12)
			title.BackgroundTransparency = 1
			title.Text = "SMARTCOPY by Ndrew"
			title.TextColor3 = Color3.fromRGB(240, 240, 245)
			title.TextSize = 14
			title.Font = Enum.Font.GothamBold
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.Parent = frame

			-- Active AI Badge
			local badge = Instance.new("Frame")
			badge.Size = UDim2.new(0, 80, 0, 20)
			badge.Position = UDim2.new(1, -95, 0, 14)
			badge.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
			badge.Parent = frame
			
			local badgeCorner = Instance.new("UICorner")
			badgeCorner.CornerRadius = UDim.new(0, 6)
			badgeCorner.Parent = badge

			local badgeStroke = Instance.new("UIStroke")
			badgeStroke.Color = Color3.fromRGB(35, 35, 40)
			badgeStroke.Thickness = 1
			badgeStroke.Parent = badge

			local badgeText = Instance.new("TextLabel")
			badgeText.Size = UDim2.new(1, 0, 1, 0)
			badgeText.BackgroundTransparency = 1
			badgeText.Text = "● ACTIVE"
			badgeText.TextColor3 = Color3.fromRGB(0, 180, 255)
			badgeText.TextSize = 9
			badgeText.Font = Enum.Font.GothamBold
			badgeText.Parent = badge

			-- Phase / Status label
			local statusLabel = Instance.new("TextLabel")
			statusLabel.Name = "Status"
			statusLabel.Size = UDim2.new(1, -100, 0, 20)
			statusLabel.Position = UDim2.new(0, 15, 0, 42)
			statusLabel.BackgroundTransparency = 1
			statusLabel.Text = "Initializing..."
			statusLabel.TextColor3 = Color3.fromRGB(180, 180, 185)
			statusLabel.TextSize = 11
			statusLabel.Font = Enum.Font.GothamMedium
			statusLabel.TextXAlignment = Enum.TextXAlignment.Left
			statusLabel.Parent = frame

			-- Percentage Label
			local percentLabel = Instance.new("TextLabel")
			percentLabel.Name = "Percent"
			percentLabel.Size = UDim2.new(0, 60, 0, 20)
			percentLabel.Position = UDim2.new(1, -75, 0, 42)
			percentLabel.BackgroundTransparency = 1
			percentLabel.Text = "0%"
			percentLabel.TextColor3 = Color3.fromRGB(0, 180, 255)
			percentLabel.TextSize = 11
			percentLabel.Font = Enum.Font.GothamBold
			percentLabel.TextXAlignment = Enum.TextXAlignment.Right
			percentLabel.Parent = frame

			-- Progress Bar Background
			local progressBg = Instance.new("Frame")
			progressBg.Name = "ProgressBg"
			progressBg.Size = UDim2.new(1, -30, 0, 6)
			progressBg.Position = UDim2.new(0, 15, 0, 68)
			progressBg.BackgroundColor3 = Color3.fromRGB(25, 25, 28)
			progressBg.BorderSizePixel = 0
			progressBg.Parent = frame
			Instance.new("UICorner", progressBg).CornerRadius = UDim.new(0, 3)

			-- Progress Bar Fill
			local progressFill = Instance.new("Frame")
			progressFill.Name = "Fill"
			progressFill.Size = UDim2.new(0, 0, 1, 0)
			progressFill.BackgroundColor3 = Color3.fromRGB(0, 180, 255)
			progressFill.BorderSizePixel = 0
			progressFill.Parent = progressBg
			Instance.new("UICorner", progressFill).CornerRadius = UDim.new(0, 3)

			local grad = Instance.new("UIGradient")
			grad.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 150, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 220, 255))
			})
			grad.Parent = progressFill

			-- Detail
			local detail = Instance.new("TextLabel")
			detail.Name = "Detail"
			detail.Size = UDim2.new(1, -30, 0, 50)
			detail.Position = UDim2.new(0, 15, 0, 85)
			detail.BackgroundTransparency = 1
			detail.Text = "Loading systems..."
			detail.TextColor3 = Color3.fromRGB(130, 130, 135)
			detail.TextSize = 10
			detail.Font = Enum.Font.Gotham
			detail.TextXAlignment = Enum.TextXAlignment.Left
			detail.TextYAlignment = Enum.TextYAlignment.Top
			detail.TextWrapped = true
			detail.Parent = frame

			local protectgui = protectgui or (syn and syn.protect_gui)
			if protectgui then pcall(protectgui, screenGui) end
			local gethui = gethui or get_hidden_gui
			screenGui.Parent = (gethui and gethui()) or game:GetService("CoreGui")
			statusGui = screenGui
		end)
	end

	local function updateUI(status, progress, detail)
		if not statusGui then return end
		pcall(function()
			local frame = statusGui:FindFirstChildWhichIsA("Frame")
			if status then frame.Status.Text = status end
			if progress then 
				local pct = math.clamp(math.floor(progress * 100), 0, 100)
				frame.Percent.Text = tostring(pct) .. "%"
				frame.ProgressBg.Fill.Size = UDim2.new(progress, 0, 1, 0) 
			end
			if detail then frame.Detail.Text = detail end
		end)
	end

	local totalPhases = 5
	if options.ServerSpy then totalPhases += 1 end
	if options.FixUnions then totalPhases += 1 end
	local currentPhase = 1

	-- ========================================
	-- Phase 1: ServerSpy (if enabled)
	-- Must start FIRST to capture activity before save kicks us
	-- ========================================
	local serverSpy
	if options.ServerSpy then
		updateUI(string.format("Phase %d/%d: Starting ServerSpy...", currentPhase, totalPhases), 0, "Intercepting Remote communications")
		print("[SMARTCOPY] Phase: Starting ServerSpy monitoring...")

		local ok, mod = pcall(loadModule, "ServerSpy")
		if ok and mod then
			serverSpy = mod
			serverSpy:Start()

			print(string.format("[SMARTCOPY] ServerSpy active — monitoring for %ds...", options.ServerSpyDuration))
			for i = 1, options.ServerSpyDuration do
				task.wait(1)
				updateUI(string.format("Phase %d/%d: Monitoring remotes...", currentPhase, totalPhases), (i / options.ServerSpyDuration) * 0.15,
					string.format("Listening for %ds — play the game normally!\nCaptured: %d calls",
						options.ServerSpyDuration - i, #serverSpy:GetLogs()))
			end

			serverSpy:Stop()
			print("[SMARTCOPY] ServerSpy monitoring complete!")
		else
			print("[SMARTCOPY] ServerSpy module not available, skipping...")
		end
		currentPhase += 1
	end

	-- ========================================
	-- Phase 2: Fix Unions (if enabled)
	-- Must run before USSI save to preserve models
	-- ========================================
	if options.FixUnions then
		updateUI(string.format("Phase %d/%d: Fixing Unions...", currentPhase, totalPhases), 0.2, "Converting UnionOperations to MeshParts")
		print("[SMARTCOPY] Phase: Converting Unions to MeshParts...")

		local ok, mod = pcall(loadModule, "UnionFixer")
		if ok and mod then
			local stats = mod:Run({workspace})
			print(string.format("[SMARTCOPY] UnionFixer done: converted %d unions", stats.converted or 0))
		else
			print("[SMARTCOPY] UnionFixer module not available, skipping...")
		end
		currentPhase += 1
	end

	-- ========================================
	-- Phase 3: Terrain Extraction
	-- ========================================
	local terrainData
	if options.IncludeTerrain then
		updateUI(string.format("Phase %d/%d: Extracting terrain...", currentPhase, totalPhases), 0.35, "Reading voxel data...")
		print("[SMARTCOPY] Phase: Extracting terrain voxels...")

		local ok, mod = pcall(loadModule, "TerrainExtractor")
		if ok and mod then
			local terrainExtractor = mod
			terrainExtractor:Extract({
				onProgress = function(pct)
					updateUI(nil, 0.35 + pct * 0.1,
						string.format("Terrain: %.0f%% — %d chunks",
							pct * 100, terrainExtractor:GetStats().nonEmptyChunks))
				end,
			})

			local terrainScript = terrainExtractor:SerializeForReplay()
			if terrainScript and #terrainScript > 100 then
				local terrainPath = "SMARTCOPY_Terrain.luau"
				pcall(writefile, terrainPath, terrainScript)
				print("[SMARTCOPY] Terrain saved to: " .. terrainPath)
				terrainData = terrainExtractor:GetStats()
			end
		else
			print("[SMARTCOPY] TerrainExtractor not available, skipping...")
		end
		currentPhase += 1
	end

	-- ========================================
	-- Phase 4: Asset Scanning
	-- ========================================
	local assetData
	if options.IncludeAssets then
		updateUI(string.format("Phase %d/%d: Scanning assets...", currentPhase, totalPhases), 0.5, "Finding meshes, textures, audio...")
		print("[SMARTCOPY] Phase: Scanning for assets...")

		local ok, mod = pcall(loadModule, "AssetRipper")
		if ok and mod then
			local assetRipper = mod
			assetRipper:Scan(nil, function(pct)
				updateUI(nil, 0.5 + pct * 0.1,
					string.format("Scanning assets: %.0f%%", pct * 100))
			end)

			assetData = assetRipper:GetStats()
			print(string.format("[SMARTCOPY] Assets found: %d", assetData._total or 0))

			local manifest = assetRipper:ExportManifestJSON()
			if manifest then
				pcall(writefile, "SMARTCOPY_Assets.json", manifest)
			end

			if options.DownloadAssets then
				local dlScript = assetRipper:GenerateDownloadScript()
				pcall(writefile, "SMARTCOPY_Download.ps1", dlScript)
			end
		else
			print("[SMARTCOPY] AssetRipper not available, skipping...")
		end
		currentPhase += 1
	end

	-- ========================================
	-- Phase 5: Save Instance (USSI)
	-- The core map save — this kicks player if SafeMode = true
	-- ========================================
	updateUI(string.format("Phase %d/%d: Saving instance tree...", currentPhase, totalPhases), 0.7, "This is the main save — player may be kicked for safety!")
	print("[SMARTCOPY] Phase: Running SaveInstance (USSI engine)...")

	local synsaveinstance = loadUSSI()
	if synsaveinstance then
		local ussiOptions = {
			mode = options.mode,
			SafeMode = options.SafeMode,
			Decompile = options.Decompile,
			DecompileTimeout = options.DecompileTimeout,
			NilInstances = options.NilInstances,
			IgnoreDefaultProperties = options.IgnoreDefaultProperties,
			IgnoreNotArchivable = options.IgnoreNotArchivable,
			SaveNotCreatable = options.SaveNotCreatable,
			IsolateLocalPlayer = options.IsolateLocalPlayer,
			SaveBytecode = options.SaveBytecode,
			ShowStatus = false,
			IgnoreSharedStrings = options.IgnoreSharedStrings,
			FilePath = options.FilePath,
			ReadMe = true,
			AntiIdle = true,
		}

		local saveOk, saveErr = pcall(synsaveinstance, ussiOptions)
		if saveOk then
			print("[SMARTCOPY] SaveInstance complete!")
		else
			warn("[SMARTCOPY] SaveInstance error: " .. tostring(saveErr))
		end
	else
		warn("[SMARTCOPY] CRITICAL: Could not load USSI engine!")
	end
	currentPhase += 1

	-- ========================================
	-- Phase 6: Watermark Replacer (if enabled)
	-- Runs after save so it can modify saved script sources
	-- ========================================
	if options.ReplaceWatermark then
		updateUI(string.format("Phase %d/%d: Branding scripts...", currentPhase, totalPhases), 0.85, "Applying 'copy by Ndrew' watermark")
		print("[SMARTCOPY] Phase: Replacing watermarks...")

		local ok, mod = pcall(loadModule, "WatermarkReplacer")
		if ok and mod then
			local stats = mod:Run()
			print(string.format("[SMARTCOPY] WatermarkReplacer done: branded %d scripts", stats.replaced or 0))
		else
			print("[SMARTCOPY] WatermarkReplacer not available, skipping...")
		end
		currentPhase += 1
	end

	-- ========================================
	-- Phase 7: Generate Server Stubs (if ServerSpy was used)
	-- ========================================
	if serverSpy then
		updateUI(string.format("Phase %d/%d: Generating server stubs...", currentPhase, totalPhases), 0.95, "Reconstructing server logic...")
		print("[SMARTCOPY] Phase: Generating server script stubs...")

		local report = serverSpy:ExportReport()
		pcall(writefile, "SMARTCOPY_ServerSpy_Report.txt", report)

		local stubs = serverSpy:GenerateServerStubs()
		if #stubs > 0 then
			local allStubs = {}
			for _, stub in ipairs(stubs) do
				table.insert(allStubs, "-- FILE: " .. stub.path)
				table.insert(allStubs, stub.sourceCode)
				table.insert(allStubs, "\n")
			end
			pcall(writefile, "SMARTCOPY_ServerStubs.lua", table.concat(allStubs, "\n"))
		end
	end

	-- ========================================
	-- Final Report
	-- ========================================
	local totalTime = os.clock() - startTime
	local timeStr = totalTime < 60
		and string.format("%.1fs", totalTime)
		or string.format("%dm %ds", math.floor(totalTime / 60), math.floor(totalTime % 60))

	print("")
	print("╔══════════════════════════════════════════════════════════╗")
	print("║              ⚡ SMARTCOPY — COMPLETE                    ║")
	print("╠══════════════════════════════════════════════════════════╣")
	print(string.format("║  Time: %-47s  ║", timeStr))

	if terrainData then
		print(string.format("║  Terrain: %d chunks (%d voxels)%-22s ║",
			terrainData.nonEmptyChunks, terrainData.totalVoxels, ""))
	end

	if assetData then
		print(string.format("║  Assets: %d total%-34s  ║", assetData._total or 0, ""))
	end

	if serverSpy then
		print(string.format("║  Remotes: %d captured, %d stubs generated%-15s ║",
			#serverSpy:GetLogs(),
			#serverSpy:GenerateServerStubs(), ""))
	end

	print("╠══════════════════════════════════════════════════════════╣")
	print("║  Output files:                                          ║")
	print("║    • [game].rbxlx — Full instance tree                  ║")
	if terrainData then
		print("║    • SMARTCOPY_Terrain.luau — Terrain restore script    ║")
	end
	if assetData then
		print("║    • SMARTCOPY_Assets.json — Asset manifest             ║")
	end
	if options.DownloadAssets then
		print("║    • SMARTCOPY_Download.ps1 — Asset download script     ║")
	end
	if serverSpy then
		print("║    • SMARTCOPY_ServerSpy_Report.txt — Remote logs       ║")
		print("║    • SMARTCOPY_ServerStubs.lua — Server script stubs    ║")
	end
	print("╚══════════════════════════════════════════════════════════╝")

	updateUI("✅ SMARTCOPY Complete!", 1, string.format("Done in %s • Check executor workspace folder", timeStr))

	task.delay(30, function()
		if statusGui then pcall(function() statusGui:Destroy() end) end
	end)
end
