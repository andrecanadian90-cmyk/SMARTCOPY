-- ============================================================
-- SMARTCOPY Rebuild — Kelas Malam
-- SERVER SCRIPT: CO2/Smoke Effects & Fireworks
--
-- From the game scan:
--   - "CO2GonServer" script was marked as [IMPOSSIBLE to save]
--   - "SpawnFireworks" and "StopFireworks" RemoteEvents exist
--   - CO2 cannons and smoke effects are part of the nightclub
--
-- This script handles server-side effects triggering
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

--------------------------------------------------------------
-- CO2 / Smoke Cannon System
--------------------------------------------------------------

-- Find CO2 related remotes or create them
local function findOrCreate(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then return existing end
	local new = Instance.new(className)
	new.Name = name
	new.Parent = parent
	return new
end

-- CO2 Cannon fire event
local CO2Remote = findOrCreate(ReplicatedStorage, "RemoteEvent", "FireCO2")
local SpawnFireworks = findOrCreate(ReplicatedStorage, "RemoteEvent", "SpawnFireworks")
local StopFireworks = findOrCreate(ReplicatedStorage, "RemoteEvent", "StopFireworks")

--------------------------------------------------------------
-- CO2 Cannon Handler
-- When triggered, fires CO2 effect on all clients
--------------------------------------------------------------
CO2Remote.OnServerEvent:Connect(function(player)
	-- Only allow admins/DJs to fire CO2
	-- Check whitelist from the decompiled admin list:
	-- { "CLaavooo", "baroonsteinfeld", "OnlyChips1st", "KLSM0120", "asyrawi", "Buurrr19", "adisuruh" }
	local admins = {
		"CLaavooo", "baroonsteinfeld", "OnlyChips1st", 
		"KLSM0120", "asyrawi", "Buurrr19", "adisuruh"
	}
	
	local isAdmin = false
	for _, adminName in ipairs(admins) do
		if player.Name == adminName then
			isAdmin = true
			break
		end
	end
	
	if isAdmin then
		-- Fire to all clients
		CO2Remote:FireAllClients()
	end
end)

--------------------------------------------------------------
-- Fireworks Handler
--------------------------------------------------------------
SpawnFireworks.OnServerEvent:Connect(function(player)
	-- Verify admin
	local admins = {
		"CLaavooo", "baroonsteinfeld", "OnlyChips1st", 
		"KLSM0120", "asyrawi", "Buurrr19", "adisuruh"
	}
	
	local isAdmin = false
	for _, name in ipairs(admins) do
		if player.Name == name then isAdmin = true break end
	end
	
	if isAdmin then
		SpawnFireworks:FireAllClients()
		print("[Server] Fireworks started by", player.Name)
	end
end)

StopFireworks.OnServerEvent:Connect(function(player)
	local admins = {
		"CLaavooo", "baroonsteinfeld", "OnlyChips1st", 
		"KLSM0120", "asyrawi", "Buurrr19", "adisuruh"
	}
	
	local isAdmin = false
	for _, name in ipairs(admins) do
		if player.Name == name then isAdmin = true break end
	end
	
	if isAdmin then
		StopFireworks:FireAllClients()
		print("[Server] Fireworks stopped by", player.Name)
	end
end)

print("[Server] CO2 & Fireworks system loaded")
