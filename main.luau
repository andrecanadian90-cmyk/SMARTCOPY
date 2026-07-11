--!native
--!optimize 2
-- ============================================================
-- SMARTCOPY v2.0 by Ndrew ? Advanced Roblox Map Copier
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
--       FixUnions = true,           -- Convert Union ke MeshPart agar visual bagus
--       IncludeTerrain = false,     -- Set true jika map memakai terrain voxel
--       IncludeAssets = true,       -- Scan asset IDs
--       DownloadAssets = true,      -- Buat script batch download asset
--       ServerSpy = true,           -- AKTIFKAN ini biar memantau remote dulu!
--       ServerSpyDuration = 60,     -- Durasi monitoring (detik) sebelum save
--       Decompile = true,           -- Decompile scripts
--       NilInstances = true,
--       SafeMode = true,            -- Biarkan true (aman), player akan kick di akhir proses
--   })
-- ============================================================

local SMARTCOPY_VERSION = "2.0.0"
local REPO_BASE = "https://raw.githubusercontent.com/andrecanadian90-cmyk/SMARTCOPY/main/"

-- ============================================================
-- Module Loader
-- Loads modules from GitHub
-- ============================================================
local function loadModule(name)
	-- Generate a random token to bypass HTTP cache
	local cacheBuster = "?nocache=" .. tostring(math.random(1, 100000)) .. "_" .. tostring(os.time())
	local url = REPO_BASE .. "modules/" .. name .. ".luau" .. cacheBuster
	
	local ok, module = pcall(function()
		return loadstring(
			game:HttpGet(url, true),
			"SMARTCOPY/" .. name
		)()
	end)

	if ok and module then
		print("[SMARTCOPY] Loaded module: " .. name)
		return module
	end

	warn("[SMARTCOPY] Failed to load module: " .. name .. " — Error: " .. tostring(module))
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

	-- Get Place Name dynamically
	local MarketplaceService = game:GetService("MarketplaceService")
	local placeName = "Unknown_Place"
	pcall(function()
		local info = MarketplaceService:GetProductInfo(game.PlaceId)
		placeName = info.Name
	end)

	-- Sanitize placeName for folder path (remove illegal characters)
	placeName = string.gsub(placeName, "[\\/:*?\"<>|]", "_")
	placeName = string.gsub(placeName, "%s+", "_") -- replace spaces with underscores for neatness
	local folderName = "SMARTCOPY_" .. game.PlaceId .. "_" .. placeName
	
	-- Create the dedicated folder
	pcall(makefolder, folderName)

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
		FilePath = userOptions.FilePath or (folderName .. "/place_" .. game.PlaceId .. "_" .. placeName),

		-- SMARTCOPY extensions
		FixUnions = userOptions.FixUnions ~= false,             -- default true
		IncludeTerrain = userOptions.IncludeTerrain or false,    -- default false
		IncludeAssets = userOptions.IncludeAssets ~= false,      -- default true
		ServerSpy = userOptions.ServerSpy or false,              -- default false (requires duration wait)
		ServerSpyDuration = userOptions.ServerSpyDuration or 60, -- seconds to monitor
		DownloadAssets = userOptions.DownloadAssets or false,     -- generate download script
		ReplaceWatermark = userOptions.ReplaceWatermark ~= false,   -- default true
		BypassAssetPrivacy = userOptions.BypassAssetPrivacy or false, -- default false
	}

	-- Clean up any old temporary folders left behind from previous runs/crashes
	pcall(function()
		for _, child in ipairs(game:GetChildren()) do
			if child.Name == "Nil Instances" or child.Name == "LocalPlayer" or child.Name == "StudioData" or string.find(child.Name, "FilteredSelection") then
				child:Destroy()
			end
		end
	end)

	-- Auto-detect if map actually has terrain cells, and force enable IncludeTerrain
	pcall(function()
		if workspace.Terrain:CountCells() > 0 then
			options.IncludeTerrain = true
		end
	end)

	local startTime = os.clock()

	print("+==========================================================?")
	print("|          [SMARTCOPY] SMARTCOPY v" .. SMARTCOPY_VERSION .. " by Ndrew                |")
	print("|          https://bernadaclub.my.id                      |")
	print("|          Advanced Roblox Map Copier                     |")
	print("+==========================================================?")
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
			badgeText.Text = "* ACTIVE"
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
			
			local parent = nil
			local gethui = gethui or get_hidden_gui
			if gethui then
				pcall(function()
					parent = gethui()
				end)
			end
			
			local parented = false
			if parent then
				local ok = pcall(function()
					screenGui.Parent = parent
					parented = true
				end)
			end
			
			if not parented then
				pcall(function()
					screenGui.Parent = game:GetService("CoreGui")
					parented = true
				end)
			end
			
			if not parented then
				pcall(function()
					screenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
					parented = true
				end)
			end
			
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

	-- Calculate only active phases dynamically
	local activePhases = {}
	if options.ServerSpy then table.insert(activePhases, "ServerSpy") end
	if options.FixUnions then table.insert(activePhases, "FixUnions") end
	if options.IncludeTerrain then table.insert(activePhases, "IncludeTerrain") end
	if options.IncludeAssets then table.insert(activePhases, "IncludeAssets") end
	if options.BypassAssetPrivacy then table.insert(activePhases, "BypassAssetPrivacy") end
	table.insert(activePhases, "SaveInstance") -- Always runs
	if serverSpy or options.ServerSpy then table.insert(activePhases, "ServerStubs") end

	local totalPhases = #activePhases
	local currentPhase = 0

	local function getNextPhaseNum()
		currentPhase += 1
		return currentPhase
	end

	-- ========================================
	-- Phase 1: ServerSpy (if enabled)
	-- Must start FIRST to capture activity before save kicks us
	-- ========================================
	local serverSpy
	if options.ServerSpy then
		local phaseNum = getNextPhaseNum()
		updateUI(string.format("Phase %d/%d: Starting ServerSpy...", phaseNum, totalPhases), 0, "Intercepting Remote communications")
		print("[SMARTCOPY] Phase: Starting ServerSpy monitoring...")

		local ok, mod = pcall(loadModule, "ServerSpy")
		if ok and mod then
			serverSpy = mod
			serverSpy:Start()

			print(string.format("[SMARTCOPY] ServerSpy active ? monitoring for %ds...", options.ServerSpyDuration))
			for i = 1, options.ServerSpyDuration do
				task.wait(1)
				updateUI(string.format("Phase %d/%d: Monitoring remotes...", phaseNum, totalPhases), (i / options.ServerSpyDuration) * 0.15,
					string.format("Listening for %ds ? play the game normally!\nCaptured: %d calls",
						options.ServerSpyDuration - i, #serverSpy:GetLogs()))
			end

			serverSpy:Stop()
			print("[SMARTCOPY] ServerSpy monitoring complete!")
		else
			print("[SMARTCOPY] ServerSpy module not available, skipping...")
		end
	end

	-- ========================================
	-- Phase 2: Fix Unions (if enabled)
	-- Must run before USSI save to preserve models
	-- ========================================
	if options.FixUnions then
		local phaseNum = getNextPhaseNum()
		updateUI(string.format("Phase %d/%d: Fixing Unions...", phaseNum, totalPhases), 0.2, "Converting UnionOperations to MeshParts")
		print("[SMARTCOPY] Phase: Converting Unions to MeshParts...")

		local ok, mod = pcall(loadModule, "UnionFixer")
		if ok and mod then
			local stats = mod:Run({workspace})
			print(string.format("[SMARTCOPY] UnionFixer done: converted %d unions", stats.converted or 0))
		else
			print("[SMARTCOPY] UnionFixer module not available, skipping...")
		end
	end

	-- ========================================
	-- Phase 3: Terrain Extraction
	-- ========================================
	local terrainData
	if options.IncludeTerrain then
		local phaseNum = getNextPhaseNum()
		updateUI(string.format("Phase %d/%d: Extracting terrain...", phaseNum, totalPhases), 0.35, "Reading voxel data...")
		print("[SMARTCOPY] Phase: Extracting terrain voxels...")

		local ok, mod = pcall(loadModule, "TerrainExtractor")
		if ok and mod then
			local terrainExtractor = mod
			terrainExtractor:Extract({
				onProgress = function(pct)
					updateUI(nil, 0.35 + pct * 0.1,
						string.format("Terrain: %.0f%% ? %d chunks",
							pct * 100, terrainExtractor:GetStats().nonEmptyChunks))
				end,
			})

			local terrainScript = terrainExtractor:SerializeForReplay()
			if terrainScript and #terrainScript > 100 then
				local terrainPath = folderName .. "/SMARTCOPY_Terrain.luau"
				pcall(writefile, terrainPath, terrainScript)
				print("[SMARTCOPY] Terrain saved to: " .. terrainPath)
				terrainData = terrainExtractor:GetStats()
			end
		else
			print("[SMARTCOPY] TerrainExtractor not available, skipping...")
		end
	end

	-- ========================================
	-- Phase 4: Asset Scanning
	-- ========================================
	local assetData
	if options.IncludeAssets then
		local phaseNum = getNextPhaseNum()
		updateUI(string.format("Phase %d/%d: Scanning assets...", phaseNum, totalPhases), 0.5, "Finding meshes, textures, audio...")
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
				pcall(writefile, folderName .. "/SMARTCOPY_Assets.json", manifest)
			end

			if options.DownloadAssets then
				local dlScript = assetRipper:GenerateDownloadScript()
				pcall(writefile, folderName .. "/SMARTCOPY_Download_ps1.txt", dlScript)
			end
		else
			print("[SMARTCOPY] AssetRipper not available, skipping...")
		end
	end

	-- ========================================
	-- Phase: Bypass Asset Privacy (if enabled)
	-- Downloads all assets locally via authenticated client request and 
	-- redirects game tree URLs to localhost:8000
	-- ========================================
	if options.BypassAssetPrivacy then
		local phaseNum = getNextPhaseNum()
		updateUI(string.format("Phase %d/%d: Bypassing Asset Privacy...", phaseNum, totalPhases), 0.6, "Downloading assets locally & generating server...")
		print("[SMARTCOPY] Phase: Bypassing Asset Privacy (Downloading + Redirecting)...")

		local ok, mod = pcall(loadModule, "AssetRipper")
		if ok and mod then
			local assetRipper = mod
			
			-- 1. Download all assets via game client authentication
			assetRipper:DownloadAllLocal(folderName, function(pct, downloaded, failed, skipped)
				updateUI(nil, 0.6 + pct * 0.08,
					string.format("Local Download: %.0f%%\nOK: %d | Skip: %d | Fail: %d",
						pct * 100, downloaded, skipped, failed))
			end)
			
			-- 2. Generate Python local server
			local pyServer = assetRipper:GeneratePythonServer()
			pcall(writefile, folderName .. "/start_asset_server_py.txt", pyServer)
			print("[SMARTCOPY] Python Local Asset Server written to: " .. folderName .. "/start_asset_server_py.txt")
			
			-- 3. Traverse and replace URLs in-game
			updateUI(nil, 0.68, "Redirecting game tree assets to localhost:8000...")
			local assetServerUrl = "http://localhost:8000/assets/"
			local SCAN_MAP = assetRipper.SCAN_MAP
			local PROP_TYPE = assetRipper.PROP_TYPE
			
			local function redirect(instance)
				local props = SCAN_MAP[instance.ClassName]
				if props then
					for _, prop in ipairs(props) do
						pcall(function()
							local currentVal = instance[prop]
							if currentVal and currentVal ~= "" then
								-- Extract digits
								local digits = string.match(tostring(currentVal), "%d+")
								if digits and digits ~= "0" then
									local propType = PROP_TYPE[prop] or "Texture"
									instance[prop] = assetServerUrl .. propType .. "/" .. digits
								end
							end
						end)
					end
				end
			end

			-- Redirect in Workspace
			for _, desc in ipairs(workspace:GetDescendants()) do
				redirect(desc)
			end
			
			-- Redirect in ReplicatedStorage, StarterGui, StarterPlayer
			for _, svcName in ipairs({"ReplicatedStorage", "StarterGui", "StarterPlayer"}) do
				local svc = game:GetService(svcName)
				if svc then
					for _, desc in ipairs(svc:GetDescendants()) do
						redirect(desc)
					end
				end
			end
			
			print("[SMARTCOPY] Redirection complete! All assets now point to localhost:8000.")
		else
			print("[SMARTCOPY] AssetRipper not available for BypassAssetPrivacy, skipping...")
		end
	end

	-- ========================================
	-- Watermark Replacer (Runs silently in background BEFORE save)
	-- Modifies script sources in game tree first so USSI saves them branded
	-- ========================================
	if options.ReplaceWatermark then
		print("[SMARTCOPY] Background Task: Replacing watermarks...")
		updateUI(nil, nil, "Replacing script watermarks with custom branding...")

		local ok, mod = pcall(loadModule, "WatermarkReplacer")
		if ok and mod then
			local stats = mod:Run()
			print(string.format("[SMARTCOPY] WatermarkReplacer done: branded %d scripts", stats.replaced or 0))
		else
			print("[SMARTCOPY] WatermarkReplacer not available, skipping...")
		end
	end

	-- ========================================
	-- Phase: Save Instance (USSI)
	-- The core map save - this kicks player if SafeMode = true
	-- ========================================
	local phaseNum = getNextPhaseNum()
	updateUI(string.format("Phase %d/%d: Saving instance tree...", phaseNum, totalPhases), 0.7, "This is the main save - player may be kicked for safety!")
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



	-- ========================================
	-- Phase 7: Generate Server Stubs (if ServerSpy was used)
	-- ========================================
	if serverSpy then
		local phaseNum = getNextPhaseNum()
		updateUI(string.format("Phase %d/%d: Generating server stubs...", phaseNum, totalPhases), 0.95, "Reconstructing server logic...")
		print("[SMARTCOPY] Phase: Generating server script stubs...")

		local report = serverSpy:ExportReport()
		pcall(writefile, folderName .. "/SMARTCOPY_ServerSpy_Report.txt", report)

		local stubs = serverSpy:GenerateServerStubs()
		if #stubs > 0 then
			local allStubs = {}
			for _, stub in ipairs(stubs) do
				table.insert(allStubs, "-- FILE: " .. stub.path)
				table.insert(allStubs, stub.sourceCode)
				table.insert(allStubs, "\n")
			end
			pcall(writefile, folderName .. "/SMARTCOPY_ServerStubs.lua", table.concat(allStubs, "\n"))
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
	print("+==========================================================?")
	print("|              [SMARTCOPY] SMARTCOPY ? COMPLETE                    |")
	print("+==========================================================+")
	print(string.format("|  Time: %-47s  |", timeStr))

	if terrainData then
		print(string.format("|  Terrain: %d chunks (%d voxels)%-22s |",
			terrainData.nonEmptyChunks, terrainData.totalVoxels, ""))
	end

	if assetData then
		print(string.format("|  Assets: %d total%-34s  |", assetData._total or 0, ""))
	end

	if serverSpy then
		print(string.format("|  Remotes: %d captured, %d stubs generated%-15s |",
			#serverSpy:GetLogs(),
			#serverSpy:GenerateServerStubs(), ""))
	end

	print("+==========================================================+")
	print("|  Output files:                                          |")
	print("|    ? [game].rbxlx ? Full instance tree                  |")
	if terrainData then
		print("|    ? SMARTCOPY_Terrain.luau ? Terrain restore script    |")
	end
	if assetData then
		print("|    ? SMARTCOPY_Assets.json ? Asset manifest             |")
	end
	if options.DownloadAssets then
		print("|    ? SMARTCOPY_Download_ps1.txt ? Asset download script     |")
	end
	if options.BypassAssetPrivacy then
		print("|    ? start_asset_server_py.txt ? Local asset server python  |")
	end
	if serverSpy then
		print("|    ? SMARTCOPY_ServerSpy_Report.txt ? Remote logs       |")
		print("|    ? SMARTCOPY_ServerStubs.lua ? Server script stubs    |")
	end
	print("+==========================================================?")

	updateUI("[OK] SMARTCOPY Complete!", 1, string.format("Done in %s ? Check executor workspace folder", timeStr))

	task.delay(30, function()
		if statusGui then pcall(function() statusGui:Destroy() end) end
	end)
end