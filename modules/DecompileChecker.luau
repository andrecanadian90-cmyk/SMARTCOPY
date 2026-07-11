-- ============================================================
-- SMARTCOPY :: DecompileChecker v2
-- Dynamically retries failed decompilations with increasing
-- timeouts until ALL scripts are decompiled or no more
-- progress can be made.
--
-- USAGE: Run in executor after joining the target game.
--        It will keep retrying until everything is done.
-- ============================================================

local DecompileChecker = {}

local FAIL_MARKERS = {
	"Failed to decompile",
	"Decompiler timed out",
	"Decompilation failed",
	"failed to decompile",
	"--[[ Failed",
	"This script was not decompiled",
	"Bytecode version mismatch",
	"Unrecognized opcode",
}

-- Escalating timeout rounds (seconds)
local TIMEOUT_ROUNDS = { 15, 30, 60, 120, 240 }

-- ============================================================
-- Detect decompiler function
-- ============================================================
local decompileFn = nil

pcall(function()
	if type(decompile) == "function" then decompileFn = decompile end
end)
if not decompileFn then
	pcall(function()
		if type(decompilescript) == "function" then decompileFn = decompilescript end
	end)
end

-- ============================================================
-- Check if source is a failed decompile
-- ============================================================
local function isFailed(src)
	if not src or src == "" then return false end
	local lines = string.split(src, "\n")
	local checkCount = math.min(#lines, 8)
	for i = 1, checkCount do
		for _, marker in ipairs(FAIL_MARKERS) do
			if string.find(lines[i], marker, 1, true) then
				return true
			end
		end
	end
	return false
end

-- ============================================================
-- Collect all failed scripts
-- ============================================================
local function collectFailed()
	local failed = {}
	local total = 0
	local healthy = 0
	local empty = 0

	for _, inst in ipairs(game:GetDescendants()) do
		if not inst:IsA("LuaSourceContainer") then continue end
		total += 1
		local src = inst.Source
		if not src or src == "" then
			empty += 1
		elseif isFailed(src) then
			table.insert(failed, inst)
		else
			healthy += 1
		end
	end

	return failed, total, healthy, empty
end

-- ============================================================
-- Single decompile attempt
-- ============================================================
local function tryDecompile(inst, timeout)
	local result = nil
	local ok = pcall(function()
		-- Try with timeout param
		local s
		local gotIt = pcall(function()
			s = decompileFn(inst, timeout)
		end)
		if not gotIt or not s then
			s = decompileFn(inst)
		end
		result = s
	end)

	if ok and result and result ~= "" and not isFailed(result) then
		return true, result
	end
	return false, nil
end

-- ============================================================
-- Main dynamic loop
-- ============================================================
function DecompileChecker:Run()
	if not decompileFn then
		warn("[DecompileChecker] ERROR: No decompile() function found!")
		warn("[DecompileChecker] This script must run inside an executor.")
		return
	end

	print("============================================")
	print("[SMARTCOPY/DecompileChecker] Starting...")
	print("============================================")

	local failed, total, healthy, empty = collectFailed()

	print(string.format("  Total scripts: %d | Healthy: %d | Failed: %d | Empty: %d",
		total, healthy, #failed, empty))

	if #failed == 0 then
		print("[DecompileChecker] All scripts are healthy! Nothing to do. [OK]")
		return
	end

	local totalFixed = 0
	local stillBroken = table.clone(failed)

	-- -- Round loop with escalating timeouts --------------
	for round, timeout in ipairs(TIMEOUT_ROUNDS) do
		if #stillBroken == 0 then break end

		print("")
		print(string.format("-- Round %d/%d | Timeout: %ds | Remaining: %d --",
			round, #TIMEOUT_ROUNDS, timeout, #stillBroken))

		local fixedThisRound = 0
		local nextRound = {}

		for i, inst in ipairs(stillBroken) do
			-- Check if instance still exists
			if not inst or not inst.Parent then continue end

			local success, src = tryDecompile(inst, timeout)

			if success then
				inst.Source = src
				fixedThisRound += 1
				totalFixed += 1
				print(string.format("  [OK] [%d/%d] %s", i, #stillBroken, inst:GetFullName()))
			else
				table.insert(nextRound, inst)
			end

			-- Yield every few scripts to prevent freezing
			if i % 5 == 0 then
				task.wait()
			end
		end

		stillBroken = nextRound

		print(string.format("  Round %d result: +%d fixed | %d remaining",
			round, fixedThisRound, #stillBroken))

		-- If no progress was made this round, try next timeout
		-- If we're on the last round and still no progress, we're done
		if fixedThisRound == 0 and round >= #TIMEOUT_ROUNDS then
			print("  No progress on final round ? giving up on remaining scripts.")
			break
		end

		if fixedThisRound == 0 then
			print("  No progress ? escalating timeout...")
		end
	end

	-- -- Extra aggressive pass for stubborn scripts ------?
	if #stillBroken > 0 then
		print("")
		print(string.format("-- Final aggressive pass | Timeout: 300s | Remaining: %d --", #stillBroken))

		local lastChance = {}
		for i, inst in ipairs(stillBroken) do
			if not inst or not inst.Parent then continue end

			-- One last try with maximum timeout
			local success, src = tryDecompile(inst, 300)
			if success then
				inst.Source = src
				totalFixed += 1
				print(string.format("  [OK] [%d/%d] %s", i, #stillBroken, inst:GetFullName()))
			else
				table.insert(lastChance, inst)
			end

			task.wait(0.1) -- breathe between heavy attempts
		end

		stillBroken = lastChance
	end

	-- -- Final Report ------------------------------------?
	print("")
	print("============================================")
	print("[SMARTCOPY/DecompileChecker] COMPLETE!")
	print("============================================")
	print(string.format("  Total Scripts:       %d", total))
	print(string.format("  Already Healthy:     %d [OK]", healthy))
	print(string.format("  Fixed by Retry:      %d [OK]", totalFixed))
	print(string.format("  Still Failed:        %d [FAIL]", #stillBroken))
	print(string.format("  Empty (no source):   %d [ ]", empty))

	local successRate = math.floor(((healthy + totalFixed) / math.max(total - empty, 1)) * 100)
	print(string.format("  Success Rate:        %d%%", successRate))
	print("============================================")

	if #stillBroken > 0 then
		print("")
		print("-- Scripts that could NOT be decompiled ----")
		for i, inst in ipairs(stillBroken) do
			print(string.format("  %d. %s [%s]", i, inst:GetFullName(), inst.ClassName))
		end
		print("")
		print("  These are likely obfuscated (IronBrew/Luraph)")
		print("  and need a dedicated de-obfuscator or manual rewrite.")
	else
		print("")
		print("  ? ALL scripts decompiled successfully!")
	end

	print("============================================")
end

return DecompileChecker