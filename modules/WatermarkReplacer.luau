-- ============================================================
-- SMARTCOPY :: WatermarkReplacer
-- Replaces USSI/decompiler watermark comments with custom
-- branding on ALL scripts in the game tree.
--
-- USAGE:
--   Option A — Run in Roblox Studio Command Bar after loading .rbxl
--   Option B — Run in executor after USSI save but before closing
--
-- To customize the replacement text, edit NEW_HEADER below.
-- ============================================================

local WatermarkReplacer = {}

-- ┌─────────────────────────────────────────────┐
-- │  CUSTOM HEADER — edit this to your liking   │
-- └─────────────────────────────────────────────┘
local NEW_HEADER = {
	"-- copy by Ndrew |",
	"-- https://bernadaclub.my.id",
}

-- Patterns to detect as old watermark lines (matched inside -- comments)
local OLD_WATERMARKS = {
	"Saved by UniversalSynSaveInstance",
	"https://discord.gg/",
	"https://lua.expert",
	"discord.gg/wx4ThpAsmw",
	"Decompiled with",
	"Unluau",
	"unluau",
	"Join to Copy Games",
}

local stats = {
	total = 0,
	replaced = 0,
	skipped = 0,
}

function WatermarkReplacer:Run(header, watermarks)
	local headerLines = header or NEW_HEADER
	local patterns = watermarks or OLD_WATERMARKS

	local headerStr = table.concat(headerLines, "\n")

	local processed = 0
	for _, inst in ipairs(game:GetDescendants()) do
		if not inst:IsA("LuaSourceContainer") then continue end
		local src = inst.Source
		if src == "" then continue end

		stats.total += 1

		local lines = string.split(src, "\n")
		local bodyLines = {}
		local foundWatermark = false

		for _, line in ipairs(lines) do
			local trimmed = string.match(line, "^%s*(.-)%s*$")
			local isOld = false

			if string.sub(trimmed, 1, 2) == "--" then
				for _, pat in ipairs(patterns) do
					if string.find(trimmed, pat, 1, true) then
						isOld = true
						break
					end
				end
			end

			if isOld then
				foundWatermark = true
			else
				table.insert(bodyLines, line)
			end
		end

		if not foundWatermark then
			stats.skipped += 1
			continue
		end

		-- Strip leading blank lines left behind
		while #bodyLines > 0 and string.match(bodyLines[1], "^%s*$") do
			table.remove(bodyLines, 1)
		end

		inst.Source = headerStr .. "\n\n" .. table.concat(bodyLines, "\n")
		stats.replaced += 1

		processed += 1
		if processed % 50 == 0 then
			task.wait() -- yield to prevent game freeze
		end
	end

	print("============================================")
	print("[SMARTCOPY/WatermarkReplacer] DONE!")
	print(string.format("  Scripts scanned:  %d", stats.total))
	print(string.format("  Replaced:         %d", stats.replaced))
	print(string.format("  No watermark:     %d", stats.skipped))
	print("============================================")

	return stats
end

function WatermarkReplacer:GetStats()
	return stats
end

return WatermarkReplacer
