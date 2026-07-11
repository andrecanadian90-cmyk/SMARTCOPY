--!optimize 2
-- ============================================================
-- SMARTCOPY :: UnionFixer
-- Converts UnionOperations -> MeshParts before USSI save
-- so the visual mesh is preserved as a proper asset reference.
--
-- HOW IT WORKS:
--   Every UnionOperation in Roblox has a hidden "AssetId"
--   property that points to the pre-computed mesh Roblox
--   generated from the CSG boolean operation.
--   This script reads that AssetId via gethiddenproperty(),
--   creates an equivalent MeshPart with that mesh, copies
--   all visual/physics properties + children, then replaces
--   the Union. The result is a MeshPart that looks identical
--   but saves cleanly with USSI.
--
-- USAGE:
--   1. Join the target game with your executor
--   2. Execute this script FIRST
--   3. Wait for "COMPLETE" message
--   4. THEN run your USSI saveinstance script
--
-- REQUIREMENTS:
--   - Executor must support: gethiddenproperty, sethiddenproperty
--   - (Most modern executors do: Synapse, Fluxus, Wave, etc.)
-- ============================================================

local UnionFixer = {}

-- Stats
local stats = {
	totalFound     = 0,
	converted      = 0,
	keptAsUnion    = 0,
	errors         = 0,
	skippedNegate  = 0,
}

-- ============================================================
-- Property copy helpers
-- ============================================================

local APPEARANCE_PROPS = {
	"Color", "Material", "MaterialVariant",
	"Transparency", "Reflectance", "CastShadow",
}

local PHYSICS_PROPS = {
	"Anchored", "CanCollide", "CanTouch", "CanQuery", "Massless",
}

local OPTIONAL_PROPS = {
	"CollisionGroup", "CollisionFidelity", "RenderFidelity",
	"CustomPhysicalProperties", "EnableFluidForces",
}

local function safeCopy(src, dst, propName)
	pcall(function()
		dst[propName] = src[propName]
	end)
end

local function copyChildren(src, dst)
	for _, child in ipairs(src:GetChildren()) do
		-- Skip NegateOperations (they are part of the CSG tree, not visual children)
		if not child:IsA("NegateOperation") then
			local ok, cloned = pcall(function() return child:Clone() end)
			if ok and cloned then
				cloned.Parent = dst
			end
		end
	end
end

local function copyAttributes(src, dst)
	for name, value in pairs(src:GetAttributes()) do
		pcall(function() dst:SetAttribute(name, value) end)
	end
end

local function copyTags(src, dst)
	for _, tag in ipairs(src:GetTags()) do
		pcall(function() dst:AddTag(tag) end)
	end
end

-- ============================================================
-- Weld / Constraint re-targeting
-- When a WeldConstraint or other constraint references the
-- old Union as Part0 or Part1, we need to update it to point
-- to the new MeshPart instead.
-- ============================================================

local function retargetConstraints(oldPart, newPart)
	-- Find constraints in parent and siblings that reference oldPart
	local parent = newPart.Parent
	if not parent then return end

	for _, desc in ipairs(parent:GetDescendants()) do
		pcall(function()
			if desc:IsA("Constraint") or desc:IsA("WeldConstraint") or desc:IsA("JointInstance") then
				if desc.Part0 == oldPart then desc.Part0 = newPart end
				if desc.Part1 == oldPart then desc.Part1 = newPart end
			end
		end)
	end
end

-- ============================================================
-- Core conversion: Union -> MeshPart
-- ============================================================

local function convertSingle(union)
	-- Skip NegateOperations (they are CSG subtraction children, not standalone)
	if union:IsA("NegateOperation") then
		stats.skippedNegate += 1
		return true
	end

	-- -- Step 1: Read hidden AssetId ----------------------
	local assetId = nil
	local gotAsset = pcall(function()
		assetId = gethiddenproperty(union, "AssetId")
	end)

	-- Also try "MeshData" as fallback (some executors expose this)
	local meshData = nil
	pcall(function()
		meshData = gethiddenproperty(union, "MeshData")
	end)

	-- Read InitialSize for proper mesh scaling
	local initialSize = nil
	pcall(function()
		initialSize = gethiddenproperty(union, "InitialSize")
	end)

	-- -- Step 2: Determine if we can convert --------------
	local hasValidAsset = assetId and tostring(assetId) ~= ""

	if not hasValidAsset then
		-- No AssetId available ? Union can't be reliably converted.
		-- Mark for manual review but keep as-is so USSI still saves it.
		union:SetAttribute("_SMARTCOPY_NeedsReview", true)
		union:SetAttribute("_SMARTCOPY_Reason", "No AssetId - CSG data may be lost")
		stats.keptAsUnion += 1
		return true
	end

	-- -- Step 3: Create replacement MeshPart --------------
	local mesh = Instance.new("MeshPart")
	mesh.Name = union.Name

	-- Transform
	mesh.CFrame = union.CFrame
	mesh.Size = union.Size
	
	-- Copy PivotOffset (CRITICAL to prevent offset/displacement!)
	pcall(function()
		mesh.PivotOffset = union.PivotOffset
	end)

	-- Appearance
	for _, prop in ipairs(APPEARANCE_PROPS) do
		safeCopy(union, mesh, prop)
	end

	-- Physics
	for _, prop in ipairs(PHYSICS_PROPS) do
		safeCopy(union, mesh, prop)
	end

	-- Optional properties
	for _, prop in ipairs(OPTIONAL_PROPS) do
		safeCopy(union, mesh, prop)
	end

	-- -- Step 4: Set mesh asset --------------------------
	-- Try multiple approaches to set the mesh
	local meshSet = false

	-- Approach A: sethiddenproperty for MeshId
	if not meshSet then
		pcall(function()
			sethiddenproperty(mesh, "MeshId", tostring(assetId))
			meshSet = true
		end)
	end

	-- Approach B: direct property (some executors allow this)
	if not meshSet then
		pcall(function()
			mesh.MeshId = tostring(assetId)
			meshSet = true
		end)
	end

	if not meshSet then
		-- Can't set mesh ? abort conversion, keep original Union
		mesh:Destroy()
		union:SetAttribute("_SMARTCOPY_NeedsReview", true)
		union:SetAttribute("_SMARTCOPY_Reason", "Failed to set MeshId on MeshPart")
		stats.keptAsUnion += 1
		return true
	end

	-- -- Step 5: Set InitialSize for correct scaling ------
	if initialSize then
		pcall(function()
			sethiddenproperty(mesh, "InitialSize", initialSize)
		end)
	end

	-- -- Step 6: Copy children, attributes, tags ----------
	copyChildren(union, mesh)
	copyAttributes(union, mesh)
	copyTags(union, mesh)

	-- Mark as converted for debugging
	mesh:SetAttribute("_SMARTCOPY_ConvertedFrom", "UnionOperation")
	mesh:SetAttribute("_SMARTCOPY_OriginalAssetId", tostring(assetId))

	-- -- Step 7: Replace in hierarchy --------------------
	local parent = union.Parent
	mesh.Parent = parent

	-- Retarget any constraints/welds
	retargetConstraints(union, mesh)

	-- Destroy original
	union:Destroy()

	stats.converted += 1
	return true
end

-- ============================================================
-- Main scan & convert
-- ============================================================

function UnionFixer:Run(roots)
	roots = roots or { workspace }

	print("============================================")
	print("[SMARTCOPY/UnionFixer] Starting...")
	print("============================================")

	-- Collect all unions first (to avoid iterator invalidation)
	local unions = {}
	for _, root in ipairs(roots) do
		for _, desc in ipairs(root:GetDescendants()) do
			if desc:IsA("UnionOperation") or desc:IsA("IntersectOperation") then
				table.insert(unions, desc)
			end
		end
	end

	stats.totalFound = #unions
	print(string.format("[SMARTCOPY/UnionFixer] Found %d Union/Intersect operations", #unions))

	if #unions == 0 then
		print("[SMARTCOPY/UnionFixer] Nothing to convert!")
		return stats
	end

	-- Convert each
	for i, union in ipairs(unions) do
		-- Check if it still exists (might have been a child of an already-converted union)
		if union.Parent == nil then
			continue
		end

		local ok, err = pcall(convertSingle, union)
		if not ok then
			stats.errors += 1
			warn(string.format(
				"[SMARTCOPY/UnionFixer] ERROR on '%s': %s",
				(pcall(function() return union:GetFullName() end) and union:GetFullName() or "???"),
				tostring(err)
			))
		end

		-- Progress + yield to prevent timeout
		if i % 30 == 0 then
			local pct = math.floor(i / #unions * 100)
			print(string.format(
				"[SMARTCOPY/UnionFixer] Progress: %d/%d (%d%%) ? converted: %d, kept: %d, errors: %d",
				i, #unions, pct, stats.converted, stats.keptAsUnion, stats.errors
			))
			task.wait()
		end
	end

	-- Final report
	print("============================================")
	print("[SMARTCOPY/UnionFixer] COMPLETE!")
	print(string.format("  Total Found:       %d", stats.totalFound))
	print(string.format("  Converted -> Mesh:  %d", stats.converted))
	print(string.format("  Kept as Union:     %d (marked for review)", stats.keptAsUnion))
	print(string.format("  Skipped Negates:   %d", stats.skippedNegate))
	print(string.format("  Errors:            %d", stats.errors))
	print("============================================")

	if stats.keptAsUnion > 0 then
		print("[SMARTCOPY/UnionFixer] TIP: Unions marked '_SMARTCOPY_NeedsReview' had no")
		print("  AssetId ? they may appear broken after save. Consider recreating them")
		print("  manually in Studio using regular Parts + Union tool.")
	end

	print("")
	print("[SMARTCOPY/UnionFixer] You can now run USSI saveinstance!")

	return stats
end

function UnionFixer:GetStats()
	return stats
end

return UnionFixer