--!optimize 2
-- ============================================================
-- NexusCopy — AssetRipper Module
-- Scans all instances for asset IDs (meshes, textures, sounds,
-- animations) and generates download manifests
-- ============================================================

local AssetRipper = {}
AssetRipper.__index = AssetRipper

local HttpService = game:GetService("HttpService")

--------------------------------------------------------------
-- Asset ID extraction from various URL formats
--------------------------------------------------------------
local function extractId(url)
	if not url or url == "" then return nil end
	url = tostring(url)

	-- Content type (newer Roblox)
	if typeof(url) ~= "string" then
		local ok, uri = pcall(function() return url.Uri end)
		if ok and uri then url = uri end
	end

	local id = string.match(url, "rbxassetid://(%d+)")
		or string.match(url, "[?&]id=(%d+)")
		or string.match(url, "^(%d+)$")

	if id then return tonumber(id) end

	-- Skip engine-local assets
	if string.find(url, "rbxasset://", 1, true) then return nil end
	if string.find(url, "rbxthumb://", 1, true) then return nil end

	return nil
end

--------------------------------------------------------------
-- Property scan definitions
-- Maps ClassName → list of property names that contain asset IDs
--------------------------------------------------------------
local SCAN_MAP = {
	-- Meshes
	MeshPart = { "MeshId", "TextureID" },
	SpecialMesh = { "MeshId", "TextureId" },
	FileMesh = { "MeshId", "TextureId" },
	
	-- Decals & Textures
	Decal = { "Texture" },
	Texture = { "Texture" },
	
	-- Surface Appearance
	SurfaceAppearance = { "ColorMap", "MetalnessMap", "NormalMap", "RoughnessMap" },
	
	-- Material Variants
	MaterialVariant = { "ColorMap", "MetalnessMap", "NormalMap", "RoughnessMap" },
	
	-- UI Images
	ImageLabel = { "Image", "HoverImage", "PressedImage" },
	ImageButton = { "Image", "HoverImage", "PressedImage" },
	
	-- Audio
	Sound = { "SoundId" },
	
	-- Animations
	Animation = { "AnimationId" },
	
	-- Particles & Effects
	ParticleEmitter = { "Texture" },
	Beam = { "Texture0", "Texture1" },
	Trail = { "Texture0", "Texture1" },
	Fire = {},
	Smoke = {},
	Sparkles = {},
	
	-- Sky
	Sky = { "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp",
			"MoonTextureId", "SunTextureId" },
	
	-- Clothing
	Shirt = { "ShirtTemplate" },
	Pants = { "PantsTemplate" },
	ShirtGraphic = { "Graphic" },
	
	-- Other
	VideoFrame = { "Video" },
	Backpack = {},
}

-- Classify asset type from the property name
local PROPERTY_TYPE_MAP = {
	MeshId = "Mesh",
	TextureID = "Texture",
	TextureId = "Texture",
	Texture = "Texture",
	Texture0 = "Texture",
	Texture1 = "Texture",
	ColorMap = "Texture",
	MetalnessMap = "Texture",
	NormalMap = "Texture",
	RoughnessMap = "Texture",
	Image = "Image",
	HoverImage = "Image",
	PressedImage = "Image",
	SoundId = "Audio",
	AnimationId = "Animation",
	SkyboxBk = "Skybox",
	SkyboxDn = "Skybox",
	SkyboxFt = "Skybox",
	SkyboxLf = "Skybox",
	SkyboxRt = "Skybox",
	SkyboxUp = "Skybox",
	MoonTextureId = "Texture",
	SunTextureId = "Texture",
	ShirtTemplate = "Clothing",
	PantsTemplate = "Clothing",
	Graphic = "Image",
	Video = "Video",
}

--------------------------------------------------------------
-- State
--------------------------------------------------------------
local assets = {} -- id → {id, type, usedBy = {}, url}
local assetCount = 0
local scanTime = 0

--------------------------------------------------------------
-- Register an asset
--------------------------------------------------------------
local function registerAsset(id, assetType, usedByPath)
	if not id then return end

	if assets[id] then
		-- Already known, just add usedBy
		if not assets[id].usedBy[usedByPath] then
			assets[id].usedBy[usedByPath] = true
		end
		return
	end

	assetCount += 1
	assets[id] = {
		id = id,
		type = assetType or "Unknown",
		url = "https://assetdelivery.roblox.com/v1/asset/?id=" .. id,
		usedBy = { [usedByPath] = true },
	}
end

--------------------------------------------------------------
-- Scan instances for assets
--------------------------------------------------------------
--- @param roots {Instance}? — defaults to {game}
--- @param onProgress ((number) -> ())?
function AssetRipper:Scan(roots, onProgress)
	roots = roots or { game }
	assets = {}
	assetCount = 0
	local startTime = os.clock()

	local descendants = {}
	for _, root in ipairs(roots) do
		local ok, desc = pcall(function() return root:GetDescendants() end)
		if ok then
			for _, inst in ipairs(desc) do
				table.insert(descendants, inst)
			end
		end
	end

	local total = #descendants
	print(string.format("[NexusCopy/Assets] Scanning %d instances for asset IDs...", total))

	for i, instance in ipairs(descendants) do
		local className = instance.ClassName

		-- Check specific scan map
		local propsToScan = SCAN_MAP[className]

		if propsToScan then
			local instancePath = ""
			pcall(function() instancePath = instance:GetFullName() end)

			for _, propName in ipairs(propsToScan) do
				local ok, val = pcall(function() return instance[propName] end)
				if ok and val then
					local id = extractId(val)
					local assetType = PROPERTY_TYPE_MAP[propName] or "Unknown"
					registerAsset(id, assetType, instancePath .. "." .. propName)
				end
			end
		end

		-- Also check for generic Content/ContentId properties on any instance
		-- by trying common property names
		if not propsToScan then
			for _, propName in ipairs({ "Image", "Texture", "SoundId", "MeshId", "AnimationId" }) do
				local ok, val = pcall(function() return instance[propName] end)
				if ok and val and val ~= "" then
					local id = extractId(val)
					if id then
						local instancePath = ""
						pcall(function() instancePath = instance:GetFullName() end)
						local assetType = PROPERTY_TYPE_MAP[propName] or "Unknown"
						registerAsset(id, assetType, instancePath .. "." .. propName)
					end
				end
			end
		end

		-- Progress
		if onProgress and i % 500 == 0 then
			onProgress(i / total)
		end

		-- Yield periodically
		if i % 1000 == 0 then
			task.wait()
		end
	end

	scanTime = os.clock() - startTime
	if onProgress then onProgress(1) end

	print(string.format("[NexusCopy/Assets] Found %d unique assets in %.1fs", assetCount, scanTime))
	return assets
end

--------------------------------------------------------------
-- Get categorized manifest
--------------------------------------------------------------
function AssetRipper:GetManifest()
	local manifest = {
		Mesh = {},
		Texture = {},
		Image = {},
		Audio = {},
		Animation = {},
		Skybox = {},
		Clothing = {},
		Video = {},
		Unknown = {},
	}

	for id, data in pairs(assets) do
		local category = manifest[data.type] or manifest.Unknown
		table.insert(category, data)
	end

	return manifest
end

--------------------------------------------------------------
-- Get flat download list
--------------------------------------------------------------
function AssetRipper:GetDownloadList()
	local list = {}
	for id, data in pairs(assets) do
		local usedByList = {}
		for path in pairs(data.usedBy) do
			table.insert(usedByList, path)
		end

		table.insert(list, {
			id = data.id,
			url = data.url,
			type = data.type,
			usedBy = usedByList,
		})
	end

	-- Sort by type then by id
	table.sort(list, function(a, b)
		if a.type == b.type then return a.id < b.id end
		return a.type < b.type
	end)

	return list
end

--------------------------------------------------------------
-- Get stats by category
--------------------------------------------------------------
function AssetRipper:GetStats()
	local counts = {}
	local total = 0

	for id, data in pairs(assets) do
		counts[data.type] = (counts[data.type] or 0) + 1
		total += 1
	end

	counts._total = total
	counts._scanTime = scanTime
	return counts
end

--------------------------------------------------------------
-- Generate PowerShell download script
--------------------------------------------------------------
function AssetRipper:GenerateDownloadScript()
	local list = self:GetDownloadList()
	local lines = {}

	table.insert(lines, "# ============================================================")
	table.insert(lines, "# NexusCopy — Asset Download Script (PowerShell)")
	table.insert(lines, "# Total assets: " .. #list)
	table.insert(lines, "# ============================================================")
	table.insert(lines, "")
	table.insert(lines, '$outputDir = ".\\NexusCopy_Assets"')
	table.insert(lines, "")

	-- Create subdirectories
	local types = { "Mesh", "Texture", "Image", "Audio", "Animation", "Skybox", "Clothing", "Video", "Unknown" }
	for _, t in ipairs(types) do
		table.insert(lines, string.format('New-Item -ItemType Directory -Force "$outputDir\\%s" | Out-Null', t))
	end
	table.insert(lines, "")

	-- Download function
	table.insert(lines, "function Download-Asset($id, $type) {")
	table.insert(lines, '    $url = "https://assetdelivery.roblox.com/v1/asset/?id=$id"')
	table.insert(lines, '    $outPath = "$outputDir\\$type\\$id"')
	table.insert(lines, "    if (!(Test-Path $outPath)) {")
	table.insert(lines, "        try {")
	table.insert(lines, '            Invoke-WebRequest -Uri $url -OutFile $outPath -ErrorAction Stop')
	table.insert(lines, '            Write-Host "[OK] $type/$id" -ForegroundColor Green')
	table.insert(lines, "        } catch {")
	table.insert(lines, '            Write-Host "[FAIL] $type/$id - $_" -ForegroundColor Red')
	table.insert(lines, "        }")
	table.insert(lines, "    } else {")
	table.insert(lines, '        Write-Host "[SKIP] $type/$id (exists)" -ForegroundColor Yellow')
	table.insert(lines, "    }")
	table.insert(lines, "}")
	table.insert(lines, "")

	table.insert(lines, string.format('Write-Host "Downloading %d assets..." -ForegroundColor Cyan', #list))
	table.insert(lines, "")

	for _, asset in ipairs(list) do
		table.insert(lines, string.format('Download-Asset %d "%s"', asset.id, asset.type))
	end

	table.insert(lines, "")
	table.insert(lines, 'Write-Host "\\nDone! Assets saved to $outputDir" -ForegroundColor Green')

	return table.concat(lines, "\n")
end

--------------------------------------------------------------
-- Generate asset manifest JSON (for saving alongside .rbxlx)
--------------------------------------------------------------
function AssetRipper:ExportManifestJSON()
	local list = self:GetDownloadList()
	local ok, json = pcall(function()
		return HttpService:JSONEncode({
			version = 1,
			generatedBy = "NexusCopy AssetRipper",
			totalAssets = #list,
			assets = list,
		})
	end)
	return ok and json or nil
end

return AssetRipper
