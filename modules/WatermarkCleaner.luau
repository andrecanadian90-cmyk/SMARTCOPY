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

	local processed = 0
	for _, inst in ipairs(game:GetDescendants()) do
		if inst:IsA("LuaSourceContainer") then
			-- Safely read source to prevent permission crashes (e.g. on CoreGui scripts)
			local ok, src = pcall(function() return inst.Source end)
			if not ok or not src or src == "" then continue end

			total += 1

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
				-- Safely write source
				local writeOk = pcall(function()
					inst.Source = table.concat(newLines, "\n")
				end)
				if writeOk then
					cleaned += 1
				end
			end

			processed += 1
			if processed % 50 == 0 then
				task.wait() -- yield to prevent game freeze
			end
		end
	end

	print(string.format("[SMARTCOPY/WatermarkCleaner] Done! Cleaned %d / %d scripts", cleaned, total))
	return { cleaned = cleaned, total = total }
end

return WatermarkCleaner