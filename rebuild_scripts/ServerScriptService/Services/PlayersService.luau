local PlayersService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OpRankConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("OpRankConfig"))

function PlayersService:setOpRankAdmin(player, opRank, visible)
	player:SetAttribute("OpRank", opRank)
	player:SetAttribute("OpRankVisible", visible)
	
	local character = player.Character
	if character then
		local head = character:FindFirstChild("Head")
		if head then
			local nametag = head:FindFirstChild("NameTag")
			if nametag then
				local topBanner = nametag:FindFirstChild("TopBannerImage")
				if topBanner then
					local img = OpRankConfig.getImage(opRank)
					if img and visible then
						topBanner.Image = img
						topBanner.Visible = true
					else
						topBanner.Visible = false
					end
				end
			end
		end
	end
end

return PlayersService
