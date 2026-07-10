-- ============================================================
-- Server-side ByteNet Handler (Super-Reconstructed)
-- Implements all interactive features: Dances, Tools, Likes,
-- Music, Light Operators, Profiles, Sync Dance, Carry, and Overhead Nametags.
-- ============================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local ByteNet = require(Packages:WaitForChild("ByteNet"))
local Packets = require(ReplicatedStorage.Shared.Net.Packets)
local Animations = require(ReplicatedStorage.Animation.Animation)
local ToolConfig = require(ReplicatedStorage.Shared.Config.ToolConfig)
local OverheadService = require(game.ServerScriptService.Services.OverheadService)

local playerDances = {}
local playerLikes = {}

-- Sync Dance state
local playerFollowerOf = {}
local leaderFollowers = {}
local activeDanceNames = {}

-- Carry state
local carryRequests = {}
local activeCarries = {}

print("[Server/ByteNet] Initializing super packet listeners...")

-- Helper: Get animation ID by name
local function findAnimationId(danceName)
	for _, item in ipairs(Animations.Dance) do
		if item.Name == danceName then
			return item.AnimationId
		end
	end
	for _, item in ipairs(Animations.Emote) do
		if item.Name == danceName then
			return item.AnimationId
		end
	end
	return nil
end

-- Helper: Play server animation
local function playServerAnimation(player, animId)
	local character = player.Character
	if not character then return nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	
	if playerDances[player] then
		pcall(function() playerDances[player]:Stop() end)
		pcall(function() playerDances[player]:Destroy() end)
		playerDances[player] = nil
	end
	
	local anim = Instance.new("Animation")
	anim.AnimationId = animId
	
	local track = animator:LoadAnimation(anim)
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = true
	track:Play()
	
	playerDances[player] = track
	return track
end

-- Helper: Send player profile sync
local function sendProfile(targetPlayer, dataPlayer)
	Packets.profileSync.sendTo({
		userId = dataPlayer.UserId,
		displayName = dataPlayer.DisplayName,
		username = dataPlayer.Name,
		status = dataPlayer:GetAttribute("Status") or "Enjoying Kelas Malam!",
		customTitle = dataPlayer:GetAttribute("CustomTitle") or "",
		customTitleColor = Vector3.new(1, 1, 1),
		customTitleHasColor = false,
		customTitleFont = "",
		primaryCommunityVisible = false,
		rankVisible = true
	}, targetPlayer)
end

-- ============================================================
-- Sync Dance helpers
-- ============================================================

local function startDanceForFollowers(leader, danceName, animId)
	local followers = leaderFollowers[leader]
	if not followers then return end
	for _, follower in ipairs(followers) do
		local track = playServerAnimation(follower, animId)
		local leaderTrack = playerDances[leader]
		if track and leaderTrack then
			pcall(function() track:AdjustSpeed(leaderTrack.Speed) end)
		end
		Packets.danceStarted.sendTo({ danceName = danceName }, follower)
		Packets.followStateSync.sendTo({
			leaderId = leader.UserId,
			leaderDisplayName = leader.DisplayName,
			danceName = danceName
		}, follower)
	end
end

local function stopDanceForFollowers(leader)
	local followers = leaderFollowers[leader]
	if not followers then return end
	for _, follower in ipairs(followers) do
		if playerDances[follower] then
			pcall(function() playerDances[follower]:Stop() end)
			pcall(function() playerDances[follower]:Destroy() end)
			playerDances[follower] = nil
		end
		Packets.danceStopped.sendTo(nil, follower)
		Packets.followStateSync.sendTo({
			leaderId = leader.UserId,
			leaderDisplayName = leader.DisplayName,
			danceName = ""
		}, follower)
	end
end

local function cleanupFollow(player)
	local leader = playerFollowerOf[player]
	if leader then
		local followers = leaderFollowers[leader]
		if followers then
			for i, f in ipairs(followers) do
				if f == player then
					table.remove(followers, i)
					break
				end
			end
		end
		playerFollowerOf[player] = nil
	end
	
	local followers = leaderFollowers[player]
	if followers then
		for _, follower in ipairs(followers) do
			playerFollowerOf[follower] = nil
			if playerDances[follower] then
				pcall(function() playerDances[follower]:Stop() end)
				pcall(function() playerDances[follower]:Destroy() end)
				playerDances[follower] = nil
			end
			Packets.danceStopped.sendTo(nil, follower)
			Packets.followStateSync.sendTo({ leaderId = 0, leaderDisplayName = "", danceName = "" }, follower)
		end
		leaderFollowers[player] = nil
	end
	
	activeDanceNames[player] = nil
end

-- ============================================================
-- Carry helpers
-- ============================================================

local function endCarry(player)
	local partner = activeCarries[player]
	if not partner then return end
	
	activeCarries[player] = nil
	activeCarries[partner] = nil
	
	local char1 = player.Character
	local char2 = partner.Character
	if char1 then
		local c = char1:FindFirstChild("Carryble")
		if c then c.Value = true end
	end
	if char2 then
		local c = char2:FindFirstChild("Carryble")
		if c then c.Value = true end
	end
	
	Packets.carryStateSync.sendTo({ role = "none", partnerUserId = 0, pose = "" }, player)
	Packets.carryStateSync.sendTo({ role = "none", partnerUserId = 0, pose = "" }, partner)
end

local function setupCharacter(player, character)
	if not character:FindFirstChild("Carryble") then
		local carryble = Instance.new("BoolValue")
		carryble.Name = "Carryble"
		carryble.Value = true
		carryble.Parent = character
	end
	
	-- Attach Overhead Nametag after appearance/character is fully stable
	task.spawn(function()
		local count = 0
		while not player:HasAppearanceLoaded() and count < 10 do
			task.wait(0.5)
			count = count + 0.5
		end
		task.wait(0.5) -- brief extra buffer for Roblox physics/tag replication setup
		
		if player.Character == character then
			pcall(function()
				OverheadService.reattach(player)
			end)
		end
	end)
	
	local humanoid = character:WaitForChild("Humanoid", 5)
	if humanoid then
		humanoid.Died:Connect(function()
			endCarry(player)
		end)
	end
end

-- ============================================================
-- Player initialization connections
-- ============================================================

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		setupCharacter(player, character)
	end)
	if player.Character then
		setupCharacter(player, player.Character)
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	player.CharacterAdded:Connect(function(character)
		setupCharacter(player, character)
	end)
	if player.Character then
		setupCharacter(player, player.Character)
	end
end

Players.PlayerRemoving:Connect(function(player)
	cleanupFollow(player)
	endCarry(player)
end)

-- ============================================================
-- 1. Profiles, Status, and Titles
-- ============================================================

Packets.clientBootstrapReady.listen(function(value, player)
	print("[Server/ByteNet] Client ready:", player.Name)
end)

Packets.requestProfileSync.listen(function(value, player)
	print("[Server/ByteNet] Profile sync requested by:", player.Name)
	sendProfile(player, player)
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			sendProfile(player, other)
			sendProfile(other, player)
		end
	end
end)

Packets.setStatus.listen(function(value, player)
	local text = tostring(value.text or "")
	player:SetAttribute("Status", text)
	for _, other in ipairs(Players:GetPlayers()) do
		sendProfile(other, player)
	end
end)

Packets.setCustomTitle.listen(function(value, player)
	local text = tostring(value.text or "")
	player:SetAttribute("CustomTitle", text)
	for _, other in ipairs(Players:GetPlayers()) do
		sendProfile(other, player)
	end
end)

-- ============================================================
-- 2. Dances and Emotes
-- ============================================================

Packets.playDance.listen(function(value, player)
	local danceName = value.danceName
	print("[Server/ByteNet] playDance requested by:", player.Name, "dance:", danceName)
	activeDanceNames[player] = danceName
	local animId = findAnimationId(danceName)
	if animId then
		playServerAnimation(player, animId)
		Packets.danceStarted.sendTo({ danceName = danceName }, player)
		startDanceForFollowers(player, danceName, animId)
	end
end)

Packets.stopDance.listen(function(value, player)
	print("[Server/ByteNet] stopDance requested by:", player.Name)
	activeDanceNames[player] = nil
	if playerDances[player] then
		pcall(function() playerDances[player]:Stop() end)
		pcall(function() playerDances[player]:Destroy() end)
		playerDances[player] = nil
	end
	Packets.danceStopped.sendTo(nil, player)
	stopDanceForFollowers(player)
end)

Packets.setDanceSpeed.listen(function(value, player)
	local speed = tonumber(value.speed) or 1
	local track = playerDances[player]
	if track then
		pcall(function() track:AdjustSpeed(speed) end)
	end
	local followers = leaderFollowers[player]
	if followers then
		for _, follower in ipairs(followers) do
			local followerTrack = playerDances[follower]
			if followerTrack then
				pcall(function() followerTrack:AdjustSpeed(speed) end)
			end
		end
	end
end)

-- ============================================================
-- 3. Tools
-- ============================================================

Packets.equipTool.listen(function(value, player)
	local toolEnum = value.toolEnum
	print("[Server/ByteNet] equipTool requested by:", player.Name, "tool:", toolEnum)
	
	local toolData = ToolConfig.get(toolEnum)
	local sourceName = toolData and toolData.sourceName or toolEnum
	
	local char = player.Character
	if char then
		local existing = char:FindFirstChild(sourceName)
		if existing then existing:Destroy() end
	end
	local existingInBackpack = player.Backpack:FindFirstChild(sourceName)
	if existingInBackpack then existingInBackpack:Destroy() end
	
	local toolsFolder = ServerStorage:FindFirstChild("Tools")
	local tool = toolsFolder and toolsFolder:FindFirstChild(sourceName)
	if tool then
		local cloned = tool:Clone()
		cloned.Parent = player.Backpack
	else
		local mock = Instance.new("Tool")
		mock.Name = sourceName
		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = Vector3.new(1, 1, 1)
		handle.Transparency = 1
		handle.Parent = mock
		mock.Parent = player.Backpack
	end
	
	Packets.toolStateSync.sendTo({ toolEnum = toolEnum, equipped = true }, player)
end)

Packets.unequipTool.listen(function(value, player)
	local toolEnum = value.toolEnum
	print("[Server/ByteNet] unequipTool requested by:", player.Name, "tool:", toolEnum)
	
	local toolData = ToolConfig.get(toolEnum)
	local sourceName = toolData and toolData.sourceName or toolEnum
	
	local char = player.Character
	if char then
		local existing = char:FindFirstChild(sourceName)
		if existing then existing:Destroy() end
	end
	local existingInBackpack = player.Backpack:FindFirstChild(sourceName)
	if existingInBackpack then existingInBackpack:Destroy() end
	
	Packets.toolStateSync.sendTo({ toolEnum = toolEnum, equipped = false }, player)
end)

-- ============================================================
-- 4. Likes
-- ============================================================

Packets.likePlayer.listen(function(value, sender)
	local targetUserId = value.targetUserId
	local targetPlayer = nil
	for _, p in ipairs(Players:GetPlayers()) do
		if p.UserId == targetUserId then
			targetPlayer = p
			break
		end
	end
	
	if not targetPlayer then return end
	
	playerLikes[targetUserId] = (playerLikes[targetUserId] or 0) + 1
	local newCount = playerLikes[targetUserId]
	
	print("[Server/ByteNet] likePlayer from", sender.Name, "to", targetPlayer.Name, "new count:", newCount)
	
	Packets.likeSync.sendToAll({ userId = targetUserId, count = newCount })
	
	local senderChar = sender.Character
	local targetChar = targetPlayer.Character
	if senderChar and targetChar then
		local senderPos = senderChar:GetPivot().Position
		local targetPos = targetChar:GetPivot().Position
		
		local cp1 = senderPos + Vector3.new(math.random(-10, 10), math.random(5, 15), math.random(-10, 10))
		local cp2 = targetPos + Vector3.new(math.random(-10, 10), math.random(5, 15), math.random(-10, 10))
		
		Packets.likeAnimation.sendToAll({
			senderUserId = sender.UserId,
			targetUserId = targetUserId,
			startPos = senderPos,
			cp1 = cp1,
			cp2 = cp2,
			endPos = targetPos
		})
	end
end)

-- ============================================================
-- 5. Sync Dance (Follow Leader)
-- ============================================================

Packets.followLeader.listen(function(value, player)
	local leaderId = tonumber(value.leaderId) or 0
	print("[Server/ByteNet] followLeader request from:", player.Name, "leaderId:", leaderId)
	
	if leaderId == 0 then
		cleanupFollow(player)
		Packets.followStateSync.sendTo({ leaderId = 0, leaderDisplayName = "", danceName = "" }, player)
	else
		local leaderPlayer = nil
		for _, p in ipairs(Players:GetPlayers()) do
			if p.UserId == leaderId then
				leaderPlayer = p
				break
			end
		end
		
		if leaderPlayer then
			cleanupFollow(player)
			
			playerFollowerOf[player] = leaderPlayer
			if not leaderFollowers[leaderPlayer] then
				leaderFollowers[leaderPlayer] = {}
			end
			table.insert(leaderFollowers[leaderPlayer], player)
			
			local leaderTrack = playerDances[leaderPlayer]
			local leaderDanceName = ""
			local activeDance = activeDanceNames[leaderPlayer]
			if activeDance then
				leaderDanceName = activeDance
				local animId = findAnimationId(activeDance)
				if animId then
					local track = playServerAnimation(player, animId)
					if track and leaderTrack then
						pcall(function() track:AdjustSpeed(leaderTrack.Speed) end)
					end
					Packets.danceStarted.sendTo({ danceName = activeDance }, player)
				end
			end
			
			Packets.followStateSync.sendTo({
				leaderId = leaderId,
				leaderDisplayName = leaderPlayer.DisplayName,
				danceName = leaderDanceName
			}, player)
		end
	end
end)

-- ============================================================
-- 6. Carry System
-- ============================================================

Packets.carryRequest.listen(function(value, initiator)
	local targetUserId = tonumber(value.targetUserId) or 0
	local pose = tostring(value.pose or "")
	print("[Server/ByteNet] carryRequest from:", initiator.Name, "targetUserId:", targetUserId, "pose:", pose)
	
	local target = nil
	for _, p in ipairs(Players:GetPlayers()) do
		if p.UserId == targetUserId then
			target = p
			break
		end
	end
	
	if not target then return end
	
	local requestId = tostring(math.random(100000, 999999))
	carryRequests[requestId] = { initiator = initiator, target = target, pose = pose }
	
	Packets.carryRequestIncoming.sendTo({
		requestId = requestId,
		initiatorUserId = initiator.UserId,
		initiatorDisplayName = initiator.DisplayName,
		pose = pose,
		timeoutSec = 20
	}, target)
end)

Packets.carryAccept.listen(function(value, target)
	local requestId = tostring(value.requestId or "")
	local req = carryRequests[requestId]
	if not req or req.target ~= target then return end
	carryRequests[requestId] = nil
	
	local initiator = req.initiator
	local pose = req.pose
	local char1 = initiator.Character
	local char2 = target.Character
	
	if char1 and char2 then
		local c1 = char1:FindFirstChild("Carryble")
		if not c1 then
			c1 = Instance.new("BoolValue")
			c1.Name = "Carryble"
			c1.Parent = char1
		end
		c1.Value = false
		
		local c2 = char2:FindFirstChild("Carryble")
		if not c2 then
			c2 = Instance.new("BoolValue")
			c2.Name = "Carryble"
			c2.Parent = char2
		end
		c2.Value = false
		
		local choiceModule = ReplicatedStorage.CarryReplic.CarryChoices:FindFirstChild(pose)
		if choiceModule then
			local carryChoice = require(choiceModule)
			task.spawn(function()
				pcall(carryChoice, { Players = { First = initiator, Second = target } })
			end)
		end
		
		activeCarries[initiator] = target
		activeCarries[target] = initiator
		
		Packets.carryStateSync.sendTo({ role = "carrier", partnerUserId = target.UserId, pose = pose }, initiator)
		Packets.carryStateSync.sendTo({ role = "carried", partnerUserId = initiator.UserId, pose = pose }, target)
		Packets.carryRequestResolved.sendTo({ requestId = requestId }, initiator)
		Packets.carryRequestResolved.sendTo({ requestId = requestId }, target)
	end
end)

Packets.carryReject.listen(function(value, target)
	local requestId = tostring(value.requestId or "")
	local req = carryRequests[requestId]
	if not req or req.target ~= target then return end
	carryRequests[requestId] = nil
	
	Packets.carryRequestResolved.sendTo({ requestId = requestId }, req.initiator)
	Packets.carryRequestResolved.sendTo({ requestId = requestId }, target)
end)

Packets.carryCancel.listen(function(value, player)
	print("[Server/ByteNet] carryCancel from:", player.Name)
	endCarry(player)
end)

-- ============================================================
-- 7. Music, Donations, and Preferences
-- ============================================================

Packets.requestOwnsPassesSync.listen(function(value, player)
	Packets.ownsPassesSync.sendTo({ passes = "[]" }, player)
end)

Packets.requestOwnershipSync.listen(function(value, player)
	Packets.ownershipSync.sendTo({
		ownedDances = "[]",
		ownedTools = "[]",
		favorites = "[]"
	}, player)
end)

Packets.musicRequestSync.listen(function(value, player)
	Packets.musicStateSync.sendTo({
		currentAssetId = "0",
		currentName = "None",
		currentCreator = "System",
		currentStartedAt = 0,
		currentDuration = 0,
		currentPlaybackSpeed = 1,
		isPlaying = false,
		paused = false,
		pausedSinceUnix = 0,
		pausedAccumSeconds = 0,
		queue = "[]",
		serverEpochNow = os.time()
	}, player)
end)

Packets.saweriaRequestSync.listen(function(value, player)
	Packets.saweriaTopSync.sendTo({ entries = "[]" }, player)
end)

Packets.preferencesRequestSync.listen(function(value, player)
	Packets.preferencesSync.sendTo({ entries = "[]" }, player)
end)

Packets.glightOperatorRequestSync.listen(function(value, player)
	Packets.glightOperatorAuthSync.sendTo({ isAuthorized = true }, player)
end)

print("[Server/ByteNet] Listeners initialized successfully!")
