-- ============================================================
-- SMARTCOPY :: WatermarkCleaner
-- Removes USSI/decompiler watermark comments from ALL scripts
-- ============================================================

local WatermarkCleaner = {}

local WATERMARKS = {
	"Saved by UniversalSynSaveInstance",
	"https://discord.gg/",
	"https://lua.expert",
	"Decompiled with",
	"Unluau",
	"discord.gg/wx4ThpAsmw",
}

function WatermarkCleaner:Run()
	local cleaned = 0
	local total = 0

	for _, inst in ipairs(game:GetDescendants()) do
		if inst:IsA("LuaSourceContainer") then
			total += 1
			local src = inst.Source
			if src == "" then continue end

			local lines = string.split(src, "\n")
			local newLines = {}
			local removedAny = false

			for _, line in ipairs(lines) do
				local isWatermark = false
				local trimmed = string.match(line, "^%s*(.-)%s*$")

				if string.sub(trimmed, 1, 2) == "--" then
					for _, pattern in ipairs(WATERMARKS) do
						if string.find(trimmed, pattern, 1, true) then
							isWatermark = true
							break
						end
					end
				end

				if isWatermark then
					removedAny = true
				else
					table.insert(newLines, line)
				end
			end

			while #newLines > 0 and string.match(newLines[1], "^%s*$") do
				table.remove(newLines, 1)
			end

			if removedAny then
				inst.Source = table.concat(newLines, "\n")
				cleaned += 1
			end
		end
	end

	print(string.format("[SMARTCOPY/WatermarkCleaner] Done! Cleaned %d / %d scripts", cleaned, total))
	return { cleaned = cleaned, total = total }
end

return WatermarkCleaner