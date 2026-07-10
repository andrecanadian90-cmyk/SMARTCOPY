-- ============================================================
-- SMARTCOPY Rebuild — Kelas Malam
-- SERVER SCRIPT: Main Game Server
-- 
-- Handles: Player setup, tool giving, anti-idle,
-- character loading, and core game loop
-- ============================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

--------------------------------------------------------------
-- Player Setup
--------------------------------------------------------------
Players.PlayerAdded:Connect(function(player)
	-- Create leaderstats (if game uses currency)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	-- VIP check (game shows VIP tag on players)
	local hasGamepass = false
	pcall(function()
		local MarketplaceService = game:GetService("MarketplaceService")
		-- Replace GAMEPASS_ID with actual VIP gamepass ID from the game
		-- You can find it in the decompiled client scripts
		-- hasGamepass = MarketplaceService:UserOwnsGamePassAsync(player.UserId, GAMEPASS_ID)
	end)

	if hasGamepass then
		-- Tag player as VIP (the game shows "VIP" above player name)
		local vipTag = Instance.new("BoolValue")
		vipTag.Name = "IsVIP"
		vipTag.Value = true
		vipTag.Parent = player
	end

	print("[Server] Player joined:", player.Name)
end)

--------------------------------------------------------------
-- Character Setup
--------------------------------------------------------------
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		-- Wait for humanoid
		local humanoid = character:WaitForChild("Humanoid")
		
		-- Give default tool (Concave) from ServerStorage
		-- The ServerSpy captured "Concave" Tool being given to players
		local toolsFolder = ServerStorage:FindFirstChild("Tools")
		if toolsFolder then
			local concave = toolsFolder:FindFirstChild("Concave")
			if concave then
				local clone = concave:Clone()
				clone.Parent = player.Backpack
			end
		end
		
		-- Anti-idle: Keep player connected
		-- Many Indonesian social games have this
		humanoid.Died:Connect(function()
			task.wait(5)
			player:LoadCharacter()
		end)
	end)
end)

--------------------------------------------------------------
-- Player Leaving
--------------------------------------------------------------
Players.PlayerRemoving:Connect(function(player)
	print("[Server] Player left:", player.Name)
end)

--------------------------------------------------------------
-- Anti-Idle System
--------------------------------------------------------------
-- Keep server alive even with AFK players
while true do
	task.wait(60)
	-- Heartbeat to keep server running
end
