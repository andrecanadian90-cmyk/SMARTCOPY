--!native
--!optimize 2
-- ============================================================
-- NexusCopy v1.0 — Advanced Roblox Map Copier
-- Full map extraction: terrain, meshes, textures, assets,
-- scripts, Remote reconstruction, nil instances
-- 
-- Usage:
--   loadstring(game:HttpGet("YOUR_REPO_URL/main.luau", true))()
-- 
-- Or with custom options:
--   loadstring(game:HttpGet("YOUR_REPO_URL/main.luau", true))()({
--       IncludeTerrain = true,
--       IncludeAssets = true,
--       ServerSpy = true,
--       ServerSpyDuration = 60,
--   })
-- ============================================================

local NEXUSCOPY_VERSION = "1.0.0"
local REPO_BASE = "https://raw.githubusercontent.com/andrecanadian90-cmyk/NexusCopy/main/"

-- ============================================================
-- Module Loader
-- Loads modules from GitHub or uses bundled versions
-- ============================================================
local function loadModule(name)
	-- Try loading from repo
	local ok, module = pcall(function()
		return loadstring(
			game:HttpGet(REPO_BASE .. "modules/" .. name .. ".luau", true),
			"NexusCopy/" .. name
		)()
	end)

	if ok and module then
		print("[NexusCopy] Loaded module: " .. name)
		return module
	end

	warn("[NexusCopy] Failed to load module from repo: " .. name)
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
		print("[NexusCopy] Loaded USSI saveinstance engine")
		return synsaveinstance
	end

	warn("[NexusCopy] Failed to load USSI!")
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
		SafeMode = userOptions.SafeMode ~= false, -- default true
		Decompile = userOptions.Decompile ~= false, -- default true
		DecompileTimeout = userOptions.DecompileTimeout or 15,
		NilInstances = userOptions.NilInstances ~= false, -- default true
		IgnoreDefaultProperties = userOptions.IgnoreDefaultProperties ~= false,
		IgnoreNotArchivable = userOptions.IgnoreNotArchivable ~= false,
		SaveNotCreatable = userOptions.SaveNotCreatable ~= false,
		IsolateLocalPlayer = userOptions.IsolateLocalPlayer ~= false,
		SaveBytecode = userOptions.SaveBytecode or false,
		ShowStatus = userOptions.ShowStatus ~= false,
		IgnoreSharedStrings = userOptions.IgnoreSharedStrings or false, -- try disabled for fuller save
		FilePath = userOptions.FilePath or false,

		-- NexusCopy extensions
		IncludeTerrain = userOptions.IncludeTerrain ~= false, -- default true
		IncludeAssets = userOptions.IncludeAssets ~= false,   -- default true
		ServerSpy = userOptions.ServerSpy or false,           -- default false (needs time)
		ServerSpyDuration = userOptions.ServerSpyDuration or 60, -- seconds to monitor
		DownloadAssets = userOptions.DownloadAssets or false,  -- generate download script
	}

	local startTime = os.clock()

	print("╔══════════════════════════════════════════════════════════╗")
	print("║              ⚡ NexusCopy v" .. NEXUSCOPY_VERSION .. "                       ║")
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
			screenGui.Name = "NexusCopyStatus"
			screenGui.DisplayOrder = 999999
			screenGui.ResetOnSpawn = false

			local frame = Instance.new("Frame")
			frame.Size = UDim2.new(0, 360, 0, 140)
			frame.Position = UDim2.new(1, -380, 0, 20)
			frame.BackgroundColor3 = Color3.fromRGB(12, 12, 22)
			frame.BackgroundTransparency = 0.1
			frame.BorderSizePixel = 0
			frame.Parent = screenGui

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 12)
			corner.Parent = frame

			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.fromRGB(100, 60, 255)
			stroke.Thickness = 2
			stroke.Parent = frame

			local title = Instance.new("TextLabel")
			title.Size = UDim2.new(1, -20, 0, 25)
			title.Position = UDim2.new(0, 10, 0, 8)
			title.BackgroundTransparency = 1
			title.Text = "⚡ NexusCopy v" .. NEXUSCOPY_VERSION
			title.TextColor3 = Color3.fromRGB(140, 100, 255)
			title.TextSize = 16
			title.Font = Enum.Font.GothamBold
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.Parent = frame

			local statusLabel = Instance.new("TextLabel")
			statusLabel.Name = "Status"
			statusLabel.Size = UDim2.new(1, -20, 0, 20)
			statusLabel.Position = UDim2.new(0, 10, 0, 38)
			statusLabel.BackgroundTransparency = 1
			statusLabel.Text = "Initializing..."
			statusLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
			statusLabel.TextSize = 13
			statusLabel.Font = Enum.Font.Gotham
			statusLabel.TextXAlignment = Enum.TextXAlignment.Left
			statusLabel.Parent = frame

			local progressBg = Instance.new("Frame")
			progressBg.Size = UDim2.new(1, -20, 0, 8)
			progressBg.Position = UDim2.new(0, 10, 0, 65)
			progressBg.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
			progressBg.BorderSizePixel = 0
			progressBg.Parent = frame
			Instance.new("UICorner", progressBg).CornerRadius = UDim.new(0, 4)

			local progressFill = Instance.new("Frame")
			progressFill.Name = "Fill"
			progressFill.Size = UDim2.new(0, 0, 1, 0)
			progressFill.BackgroundColor3 = Color3.fromRGB(100, 60, 255)
			progressFill.BorderSizePixel = 0
			progressFill.Parent = progressBg
			Instance.new("UICorner", progressFill).CornerRadius = UDim.new(0, 4)

			local detail = Instance.new("TextLabel")
			detail.Name = "Detail"
			detail.Size = UDim2.new(1, -20, 0, 40)
			detail.Position = UDim2.new(0, 10, 0, 82)
			detail.BackgroundTransparency = 1
			detail.Text = ""
			detail.TextColor3 = Color3.fromRGB(140, 140, 160)
			detail.TextSize = 11
			detail.Font = Enum.Font.Gotham
			detail.TextXAlignment = Enum.TextXAlignment.Left
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
			if progress then frame:FindFirstChild("Frame").Fill.Size = UDim2.new(math.clamp(progress, 0, 1), 0, 1, 0) end
			if detail then frame.Detail.Text = detail end
		end)
	end

	-- ========================================
	-- Phase 1: ServerSpy (if enabled)
	-- Must start FIRST to capture activity
	-- ========================================
	local serverSpy
	if options.ServerSpy then
		updateUI("Phase 1/5: Starting ServerSpy...", 0, "Intercepting Remote communications")
		print("[NexusCopy] Phase 1: Starting ServerSpy monitoring...")

		-- Try loading ServerSpy module
		local ok, mod = pcall(loadModule, "ServerSpy")
		if ok and mod then
			serverSpy = mod
			serverSpy:Start()

			-- Let it monitor for the specified duration
			print(string.format("[NexusCopy] ServerSpy active — monitoring for %ds...", options.ServerSpyDuration))
			updateUI("Phase 1/5: Monitoring remotes...", 0.05,
				string.format("Listening for %ds — play the game normally!", options.ServerSpyDuration))

			for i = 1, options.ServerSpyDuration do
				task.wait(1)
				updateUI(nil, 0.05 + (i / options.ServerSpyDuration) * 0.1,
					string.format("Monitoring... %ds/%ds — %d calls captured",
						i, options.ServerSpyDuration, #serverSpy:GetLogs()))
			end

			serverSpy:Stop()
			print("[NexusCopy] ServerSpy monitoring complete!")
		else
			print("[NexusCopy] ServerSpy module not available, skipping...")
		end
	end

	-- ========================================
	-- Phase 2: Terrain Extraction
	-- ========================================
	local terrainData
	if options.IncludeTerrain then
		updateUI("Phase 2/5: Extracting terrain...", 0.15, "Reading voxel data...")
		print("[NexusCopy] Phase 2: Extracting terrain voxels...")

		local ok, mod = pcall(loadModule, "TerrainExtractor")
		if ok and mod then
			local terrainExtractor = mod
			terrainExtractor:Extract({
				onProgress = function(pct)
					updateUI(nil, 0.15 + pct * 0.15,
						string.format("Terrain: %.0f%% — %d non-empty chunks",
							pct * 100, terrainExtractor:GetStats().nonEmptyChunks))
				end,
			})

			-- Serialize terrain to file
			local terrainScript = terrainExtractor:SerializeForReplay()
			if terrainScript and #terrainScript > 100 then
				local terrainPath = "NexusCopy_Terrain.luau"
				pcall(writefile, terrainPath, terrainScript)
				print("[NexusCopy] Terrain saved to: " .. terrainPath)
				terrainData = terrainExtractor:GetStats()
			else
				print("[NexusCopy] No significant terrain detected")
			end
		else
			print("[NexusCopy] TerrainExtractor not available, skipping...")
		end
	end

	-- ========================================
	-- Phase 3: Asset Scanning
	-- ========================================
	local assetData
	if options.IncludeAssets then
		updateUI("Phase 3/5: Scanning assets...", 0.3, "Finding meshes, textures, audio...")
		print("[NexusCopy] Phase 3: Scanning for assets...")

		local ok, mod = pcall(loadModule, "AssetRipper")
		if ok and mod then
			local assetRipper = mod
			assetRipper:Scan(nil, function(pct)
				updateUI(nil, 0.3 + pct * 0.1,
					string.format("Scanning assets: %.0f%%", pct * 100))
			end)

			assetData = assetRipper:GetStats()
			print(string.format("[NexusCopy] Assets found — Total: %d", assetData._total or 0))

			-- Save asset manifest
			local manifest = assetRipper:ExportManifestJSON()
			if manifest then
				pcall(writefile, "NexusCopy_Assets.json", manifest)
				print("[NexusCopy] Asset manifest saved to: NexusCopy_Assets.json")
			end

			-- Generate download script if requested
			if options.DownloadAssets then
				local dlScript = assetRipper:GenerateDownloadScript()
				pcall(writefile, "NexusCopy_Download.ps1", dlScript)
				print("[NexusCopy] Download script saved to: NexusCopy_Download.ps1")
			end
		else
			print("[NexusCopy] AssetRipper not available, skipping...")
		end
	end

	-- ========================================
	-- Phase 4: Save Instance (USSI)
	-- The core map save — this is the big one
	-- ========================================
	updateUI("Phase 4/5: Saving instance tree...", 0.4, "This is the main save — may take a while!")
	print("[NexusCopy] Phase 4: Running SaveInstance (USSI engine)...")

	local synsaveinstance = loadUSSI()
	if synsaveinstance then
		-- Build USSI options from our options
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
			ShowStatus = false, -- we have our own UI
			IgnoreSharedStrings = options.IgnoreSharedStrings,
			FilePath = options.FilePath,
			ReadMe = true,
			AntiIdle = true,
		}

		-- Run saveinstance
		local saveOk, saveErr = pcall(synsaveinstance, ussiOptions)
		if saveOk then
			print("[NexusCopy] SaveInstance complete!")
		else
			warn("[NexusCopy] SaveInstance error: " .. tostring(saveErr))
		end
	else
		warn("[NexusCopy] CRITICAL: Could not load USSI engine!")
	end

	-- ========================================
	-- Phase 5: Generate Server Stubs (if ServerSpy was used)
	-- ========================================
	if serverSpy then
		updateUI("Phase 5/5: Generating server stubs...", 0.9, "Reconstructing server logic...")
		print("[NexusCopy] Phase 5: Generating server script stubs...")

		-- Save ServerSpy report
		local report = serverSpy:ExportReport()
		pcall(writefile, "NexusCopy_ServerSpy_Report.txt", report)

		-- Save individual server stubs
		local stubs = serverSpy:GenerateServerStubs()
		if #stubs > 0 then
			local allStubs = {}
			for _, stub in ipairs(stubs) do
				table.insert(allStubs, "-- FILE: " .. stub.path)
				table.insert(allStubs, stub.sourceCode)
				table.insert(allStubs, "\n")
			end
			pcall(writefile, "NexusCopy_ServerStubs.lua", table.concat(allStubs, "\n"))
			print(string.format("[NexusCopy] Generated %d server script stubs", #stubs))
		end

		-- Save spawned instances list
		local spawned = serverSpy:GetSpawnedInstances()
		if #spawned > 0 then
			print(string.format("[NexusCopy] Captured %d server-spawned instances", #spawned))
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
	print("║              ⚡ NexusCopy — COMPLETE                    ║")
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
		print("║    • NexusCopy_Terrain.luau — Terrain restore script    ║")
	end
	if assetData then
		print("║    • NexusCopy_Assets.json — Asset manifest             ║")
	end
	if options.DownloadAssets then
		print("║    • NexusCopy_Download.ps1 — Asset download script     ║")
	end
	if serverSpy then
		print("║    • NexusCopy_ServerSpy_Report.txt — Remote logs       ║")
		print("║    • NexusCopy_ServerStubs.lua — Server script stubs    ║")
	end
	print("╚══════════════════════════════════════════════════════════╝")

	-- Update UI with completion
	updateUI("✅ NexusCopy Complete!", 1, string.format("Done in %s • Check executor workspace folder", timeStr))

	-- Auto-destroy UI after 30 seconds
	task.delay(30, function()
		if statusGui then pcall(function() statusGui:Destroy() end) end
	end)
end
