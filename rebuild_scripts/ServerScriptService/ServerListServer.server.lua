-- ============================================================
-- SMARTCOPY Rebuild — Kelas Malam
-- SERVER SCRIPT: Server List & Teleport
--
-- From decompiled scripts:
--   - "ServerListHandler" handles showing available servers
--   - "teleport" module exists for cross-server teleport
--   - Game has "Daftar Server" (Server List) button in UI
-- ============================================================

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local PLACE_ID = game.PlaceId

--------------------------------------------------------------
-- Server List System
--------------------------------------------------------------

-- Find or create remotes for server list
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

--------------------------------------------------------------
-- Get available servers
--------------------------------------------------------------
GetServers.OnServerInvoke = function(player)
	local servers = {}
	local success, pages = pcall(function()
		return game:GetService("MessagingService") -- placeholder
	end)
	
	-- Use DataStore for server registry or MessagingService
	-- For simplicity, return current server info
	table.insert(servers, {
		serverId = game.JobId,
		playerCount = #Players:GetPlayers(),
		maxPlayers = Players.MaxPlayers,
		isCurrent = true,
	})
	
	return servers
end

--------------------------------------------------------------
-- Teleport player to another server
--------------------------------------------------------------
TeleportToServer.OnServerEvent:Connect(function(player, serverId)
	if serverId and serverId ~= game.JobId then
		pcall(function()
			TeleportService:TeleportToPlaceInstance(PLACE_ID, serverId, player)
		end)
	end
end)

print("[Server] Server list & teleport system loaded")
