-- ============================================================
-- SMARTCOPY Rebuild — Kelas Malam
-- SERVER SCRIPT: Donation Board (Saweria Integration)
--
-- The ServerSpy captured:
--   Remote: ReplicatedStorage.DonationBoardRemotes.UpdateLeaderboard
--   Direction: S→C (server sends to client)
--   Args: (table) × 2 calls
--
-- This script manages the Saweria donation leaderboard.
-- It fetches donation data and broadcasts to clients.
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

-- Find or create the DonationBoardRemotes folder
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

--------------------------------------------------------------
-- Donation Data
-- Replace SAWERIA_API_KEY with actual Saweria overlay/API key
-- Or use static data if you don't have Saweria integration
--------------------------------------------------------------

-- Static donation data (from ServerSpy captured board entries)
-- The board showed 14 rows of donators
local donationData = {
	-- Replace with actual donator data or Saweria API
	{ rank = 1, displayName = "Donator1", amount = "Rp 100.000", userId = 0 },
	{ rank = 2, displayName = "Donator2", amount = "Rp 75.000", userId = 0 },
	{ rank = 3, displayName = "Donator3", amount = "Rp 50.000", userId = 0 },
	-- Add more entries as needed
}

--------------------------------------------------------------
-- Saweria API Integration (Optional)
-- If you have a Saweria account, you can fetch live data
--------------------------------------------------------------
local function fetchSaweriaData()
	-- Saweria doesn't have a public API, but you can use
	-- their overlay/webhook system
	-- 
	-- Alternative: Use a proxy server that receives Saweria webhooks
	-- and exposes the data via HTTP
	--
	-- Example with custom API:
	-- local success, result = pcall(function()
	--     return HttpService:GetAsync("YOUR_API_ENDPOINT/donations")
	-- end)
	-- if success then
	--     donationData = HttpService:JSONDecode(result)
	-- end
	
	return donationData
end

--------------------------------------------------------------
-- Broadcast leaderboard to all players
--------------------------------------------------------------
local function broadcastLeaderboard()
	local data = fetchSaweriaData()
	for _, player in Players:GetPlayers() do
		UpdateLeaderboard:FireClient(player, data)
	end
end

-- Send leaderboard when player joins
Players.PlayerAdded:Connect(function(player)
	-- Small delay to ensure client is ready
	task.wait(3)
	local data = fetchSaweriaData()
	UpdateLeaderboard:FireClient(player, data)
end)

-- Update leaderboard periodically (every 5 minutes)
while true do
	task.wait(300)
	broadcastLeaderboard()
end
