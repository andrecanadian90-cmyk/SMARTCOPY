-- ============================================================
-- SMARTCOPY INSTALLER — Kelas Malam
-- Paste SEMUA isi file ini ke Command Bar di Roblox Studio
-- (View → Command Bar atau Ctrl+Shift+C)
-- Lalu tekan ENTER
-- ============================================================

local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Helper: create script
local function createScript(parent, name, source)
	local existing = parent:FindFirstChild(name)
	if existing then existing:Destroy() end
	local s = Instance.new("Script")
	s.Name = name
	s.Source = source
	s.Parent = parent
	return s
end

print("⚡ SMARTCOPY Installer — Starting...")

-- ============================================================
-- 1. MAIN SERVER
-- ============================================================
createScript(ServerScriptService, "MainServer", [[
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

Players.PlayerAdded:Connect(function(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	print("[Server] Player joined:", player.Name)
	
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		
		local toolsFolder = ServerStorage:FindFirstChild("Tools")
		if toolsFolder then
			for _, tool in toolsFolder:GetChildren() do
				if tool:IsA("Tool") then
					tool:Clone().Parent = player.Backpack
				end
			end
		end
		
		humanoid.Died:Connect(function()
			task.wait(5)
			player:LoadCharacter()
		end)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	print("[Server] Player left:", player.Name)
end)
]])
print("  ✅ MainServer installed")

-- ============================================================
-- 2. DONATION BOARD SERVER (Saweria)
-- ============================================================
createScript(ServerScriptService, "DonationBoardServer", [[
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DonationBoardRemotes = ReplicatedStorage:FindFirstChild("DonationBoardRemotes")
if not DonationBoardRemotes then
	DonationBoardRemotes = Instance.new("Folder")
	DonationBoardRemotes.Name = "DonationBoardRemotes"
	DonationBoardRemotes.Parent = ReplicatedStorage
end

local UpdateLeaderboard = DonationBoardRemotes:FindFirstChild("UpdateLeaderboard")
if not UpdateLeaderboard then
	UpdateLeaderboard = Instance.new("RemoteEvent")
	UpdateLeaderboard.Name = "UpdateLeaderboard"
	UpdateLeaderboard.Parent = DonationBoardRemotes
end

local donationData = {
	{ rank = 1, displayName = "TopDonator", amount = "Rp 100.000" },
	{ rank = 2, displayName = "Donator2", amount = "Rp 75.000" },
	{ rank = 3, displayName = "Donator3", amount = "Rp 50.000" },
}

Players.PlayerAdded:Connect(function(player)
	task.wait(3)
	UpdateLeaderboard:FireClient(player, donationData)
end)

while true do
	task.wait(300)
	for _, player in Players:GetPlayers() do
		UpdateLeaderboard:FireClient(player, donationData)
	end
end
]])
print("  ✅ DonationBoardServer installed")

-- ============================================================
-- 3. EFFECTS SERVER (CO2 + Fireworks)
-- ============================================================
createScript(ServerScriptService, "EffectsServer", [[
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local admins = {"CLaavooo","baroonsteinfeld","OnlyChips1st","KLSM0120","asyrawi","Buurrr19","adisuruh"}

local function isAdmin(player)
	for _, name in ipairs(admins) do
		if player.Name == name then return true end
	end
	return false
end

local function findOrCreate(parent, className, name)
	local e = parent:FindFirstChild(name)
	if e then return e end
	local n = Instance.new(className)
	n.Name = name
	n.Parent = parent
	return n
end

local CO2Remote = findOrCreate(ReplicatedStorage, "RemoteEvent", "FireCO2")
local SpawnFireworks = findOrCreate(ReplicatedStorage, "RemoteEvent", "SpawnFireworks")
local StopFireworks = findOrCreate(ReplicatedStorage, "RemoteEvent", "StopFireworks")

CO2Remote.OnServerEvent:Connect(function(player)
	if isAdmin(player) then CO2Remote:FireAllClients() end
end)

SpawnFireworks.OnServerEvent:Connect(function(player)
	if isAdmin(player) then SpawnFireworks:FireAllClients() end
end)

StopFireworks.OnServerEvent:Connect(function(player)
	if isAdmin(player) then StopFireworks:FireAllClients() end
end)

print("[Server] CO2 and Fireworks system loaded")
]])
print("  ✅ EffectsServer installed")

-- ============================================================
-- 4. SERVER LIST & TELEPORT
-- ============================================================
createScript(ServerScriptService, "ServerListServer", [[
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerListFolder = ReplicatedStorage:FindFirstChild("ServerListRemotes")
if not ServerListFolder then
	ServerListFolder = Instance.new("Folder")
	ServerListFolder.Name = "ServerListRemotes"
	ServerListFolder.Parent = ReplicatedStorage
end

local GetServers = Instance.new("RemoteFunction")
GetServers.Name = "GetServers"
GetServers.Parent = ServerListFolder

local TeleportToServer = Instance.new("RemoteEvent")
TeleportToServer.Name = "TeleportToServer"
TeleportToServer.Parent = ServerListFolder

GetServers.OnServerInvoke = function(player)
	return {{
		serverId = game.JobId,
		playerCount = #Players:GetPlayers(),
		maxPlayers = Players.MaxPlayers,
		isCurrent = true,
	}}
end

TeleportToServer.OnServerEvent:Connect(function(player, serverId)
	if serverId and serverId ~= game.JobId then
		pcall(function()
			TeleportService:TeleportToPlaceInstance(game.PlaceId, serverId, player)
		end)
	end
end)

print("[Server] Server list system loaded")
]])
print("  ✅ ServerListServer installed")

-- ============================================================
-- 5. SETUP SERVER STORAGE
-- ============================================================
local toolsFolder = ServerStorage:FindFirstChild("Tools")
if not toolsFolder then
	toolsFolder = Instance.new("Folder")
	toolsFolder.Name = "Tools"
	toolsFolder.Parent = ServerStorage
end

-- Try to find Concave tool in workspace and move a copy to ServerStorage
for _, desc in game.Workspace:GetDescendants() do
	if desc:IsA("Tool") and desc.Name == "Concave" then
		local clone = desc:Clone()
		clone.Parent = toolsFolder
		print("  ✅ Found and copied 'Concave' tool to ServerStorage")
		break
	end
end

-- ============================================================
-- 6. SETUP REMOTE EVENTS (if missing)
-- ============================================================
local function ensureRemote(parent, name)
	if not parent:FindFirstChild(name) then
		local r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = parent
		print("  ✅ Created RemoteEvent:", name)
	end
end

ensureRemote(ReplicatedStorage, "ByteNetReliable")
ensureRemote(ReplicatedStorage, "FireCO2")
ensureRemote(ReplicatedStorage, "SpawnFireworks")
ensureRemote(ReplicatedStorage, "StopFireworks")

print("")
print("╔══════════════════════════════════════════════════════╗")
print("║     ⚡ SMARTCOPY Install COMPLETE!                   ║")
print("║                                                      ║")
print("║  5 Server Scripts installed                          ║")
print("║  ServerStorage/Tools folder created                  ║")
print("║  RemoteEvents verified                               ║")
print("║                                                      ║")
print("║  Next: File → Save (Ctrl+S)                         ║")
print("║  Test:  File → Publish → Start Server (2 players)   ║")
print("╚══════════════════════════════════════════════════════╝")
