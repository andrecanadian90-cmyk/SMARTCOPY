local OverheadService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local OpRankConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("OpRankConfig"))

local template = ReplicatedStorage:WaitForChild("OverheadNew"):WaitForChild("NameTag")

function OverheadService.reattach(player)
	local character = player.Character
	if not character then return end
	local head = character:WaitForChild("Head", 5)
	if not head then return end
	
	-- Destroy old Nametag if it exists
	local oldTag = head:FindFirstChild("NameTag")
	if oldTag then
		oldTag:Destroy()
	end
	
	-- Clone new Nametag
	local tag = template:Clone()
	tag.Name = "NameTag"
	tag.Parent = head
	
	-- Configure defaults
	local nameLabel = tag:FindFirstChild("NameLabel")
	if nameLabel then
		nameLabel.Text = player.DisplayName or player.Name
	end
	
	local statusLabel = tag:FindFirstChild("Status")
	local status = player:GetAttribute("Status") or ""
	if statusLabel then
		statusLabel.Text = status
		statusLabel.Visible = (status ~= "")
	end
	
	local titleLabel = tag:FindFirstChild("CustomTitleLabel")
	local customTitle = player:GetAttribute("CustomTitle") or ""
	if titleLabel then
		titleLabel.Text = customTitle
		titleLabel.Visible = (customTitle ~= "")
	end
	
	-- Configure OpRank banner
	local topBannerImage = tag:FindFirstChild("TopBannerImage")
	if topBannerImage then
		local opRank = player:GetAttribute("OpRank") or ""
		local visible = player:GetAttribute("OpRankVisible") ~= false
		local img = OpRankConfig.getImage(opRank)
		if img and visible then
			topBannerImage.Image = img
			topBannerImage.Visible = true
		else
			topBannerImage.Visible = false
		end
	end
	
	-- Hide rank text by default
	local topRank = tag:FindFirstChild("TopRank")
	if topRank then
		topRank.Visible = false
	end
	
	-- Also listen to player attributes to update nametag dynamically
	local conn1 = player:GetAttributeChangedSignal("Status"):Connect(function()
		local curStatus = player:GetAttribute("Status") or ""
		if tag and tag.Parent then
			local sl = tag:FindFirstChild("Status")
			if sl then
				sl.Text = curStatus
				sl.Visible = (curStatus ~= "")
			end
		end
	end)
	
	local conn2 = player:GetAttributeChangedSignal("CustomTitle"):Connect(function()
		local curTitle = player:GetAttribute("CustomTitle") or ""
		if tag and tag.Parent then
			local tl = tag:FindFirstChild("CustomTitleLabel")
			if tl then
				tl.Text = curTitle
				tl.Visible = (curTitle ~= "")
			end
		end
	end)
	
	local conn3 = player:GetAttributeChangedSignal("OpRank"):Connect(function()
		local opRank = player:GetAttribute("OpRank") or ""
		local visible = player:GetAttribute("OpRankVisible") ~= false
		if tag and tag.Parent then
			local tb = tag:FindFirstChild("TopBannerImage")
			if tb then
				local img = OpRankConfig.getImage(opRank)
				if img and visible then
					tb.Image = img
					tb.Visible = true
				else
					tb.Visible = false
				end
			end
		end
	end)
	
	local conn4 = player:GetAttributeChangedSignal("OpRankVisible"):Connect(function()
		local opRank = player:GetAttribute("OpRank") or ""
		local visible = player:GetAttribute("OpRankVisible") ~= false
		if tag and tag.Parent then
			local tb = tag:FindFirstChild("TopBannerImage")
			if tb then
				local img = OpRankConfig.getImage(opRank)
				if img and visible then
					tb.Image = img
					tb.Visible = true
				else
					tb.Visible = false
				end
			end
		end
	end)
	
	-- Set up connection tracking to disconnect when player character changes or player leaves
	local cleanConn
	cleanConn = character.AncestryChanged:Connect(function()
		if not character.Parent then
			conn1:Disconnect()
			conn2:Disconnect()
			conn3:Disconnect()
			conn4:Disconnect()
			cleanConn:Disconnect()
		end
	end)
end

return OverheadService
