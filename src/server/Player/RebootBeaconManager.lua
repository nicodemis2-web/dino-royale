--!strict
--[[
	RebootBeaconManager.lua
	=======================
	Handles reboot beacons for bringing back eliminated teammates
	Based on GDD Section 4.5: Team Modes
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Events = require(ReplicatedStorage.Shared.Events)
local TeamData = require(ReplicatedStorage.Shared.TeamData)

local RebootBeaconManager = {}

-- Types
export type RebootCard = {
	playerId: number,
	playerName: string,
	teamId: string,
	position: Vector3,
	createdTime: number,
	expiresTime: number,
	collectedBy: Player?,
}

export type RebootBeacon = {
	id: string,
	position: Vector3,
	isActive: boolean,
	lastUsedTime: number,
	cooldownEndTime: number,
	currentUser: Player?,
	rebootProgress: number,
	rebootTarget: RebootCard?,
}

export type RebootAttempt = {
	player: Player,
	beacon: RebootBeacon,
	card: RebootCard,
	startTime: number,
	requiredTime: number,
}

-- State
local rebootCards: { [number]: RebootCard } = {} -- By player userId
local collectedCards: { [Player]: { RebootCard } } = {} -- Cards held by players
local rebootBeacons: { [string]: RebootBeacon } = {}
local rebootAttempts: { [Player]: RebootAttempt } = {}
local currentMode: TeamData.TeamMode = "Solos"
local isInitialized = false

-- Constants
local CARD_COLLECT_RANGE = 5
local BEACON_USE_RANGE = 8
local BEACON_COOLDOWN = 120 -- 2 minutes default, overridden by mode

-- Signals
local onCardDropped = Instance.new("BindableEvent")
local onCardCollected = Instance.new("BindableEvent")
local onCardExpired = Instance.new("BindableEvent")
local onRebootStarted = Instance.new("BindableEvent")
local onRebootCompleted = Instance.new("BindableEvent")
local onRebootCancelled = Instance.new("BindableEvent")

RebootBeaconManager.OnCardDropped = onCardDropped.Event
RebootBeaconManager.OnCardCollected = onCardCollected.Event
RebootBeaconManager.OnCardExpired = onCardExpired.Event
RebootBeaconManager.OnRebootStarted = onRebootStarted.Event
RebootBeaconManager.OnRebootCompleted = onRebootCompleted.Event
RebootBeaconManager.OnRebootCancelled = onRebootCancelled.Event

--[[
	Initialize the reboot beacon manager
]]
function RebootBeaconManager.Initialize()
	if isInitialized then return end
	isInitialized = true

	print("[RebootBeaconManager] Initializing...")

	-- Setup client events
	Events.OnServerEvent("Reboot", "RequestReboot", function(player, data)
		if typeof(data) == "table" and typeof(data.beaconId) == "string" then
			RebootBeaconManager.StartReboot(player, data.beaconId, data.cardPlayerId)
		end
	end)

	Events.OnServerEvent("Reboot", "CancelReboot", function(player)
		RebootBeaconManager.CancelReboot(player)
	end)

	-- Start update loop
	task.spawn(function()
		while true do
			RebootBeaconManager.Update()
			task.wait(0.1)
		end
	end)

	print("[RebootBeaconManager] Initialized")
end

--[[
	Set the current game mode
]]
function RebootBeaconManager.SetMode(mode: TeamData.TeamMode)
	currentMode = mode
	print(`[RebootBeaconManager] Mode set to: {mode}`)
end

--[[
	Register a reboot beacon on the map
]]
function RebootBeaconManager.RegisterBeacon(id: string, position: Vector3)
	local beacon: RebootBeacon = {
		id = id,
		position = position,
		isActive = true,
		lastUsedTime = 0,
		cooldownEndTime = 0,
		currentUser = nil,
		rebootProgress = 0,
		rebootTarget = nil,
	}

	rebootBeacons[id] = beacon
	print(`[RebootBeaconManager] Registered beacon: {id}`)
end

--[[
	Drop a reboot card when player is eliminated
]]
function RebootBeaconManager.DropCard(player: Player, position: Vector3, teamId: string)
	local modeConfig = TeamData.GetModeConfig(currentMode)

	-- Check if mode supports reboot
	if not modeConfig.canReboot then
		return
	end

	local card: RebootCard = {
		playerId = player.UserId,
		playerName = player.Name,
		teamId = teamId,
		position = position,
		createdTime = tick(),
		expiresTime = tick() + modeConfig.rebootCardDuration,
		collectedBy = nil,
	}

	rebootCards[player.UserId] = card

	-- Notify clients
	Events.FireAllClients("Reboot", "CardDropped", {
		playerId = player.UserId,
		playerName = player.Name,
		teamId = teamId,
		position = position,
		expiresIn = modeConfig.rebootCardDuration,
	})

	onCardDropped:Fire(player, position)
	print(`[RebootBeaconManager] Dropped card for {player.Name}`)
end

--[[
	Try to collect a reboot card
]]
function RebootBeaconManager.TryCollectCard(collector: Player, targetPlayerId: number)
	local card = rebootCards[targetPlayerId]
	if not card then return false end

	-- Check if already collected
	if card.collectedBy then return false end

	-- Check if expired
	if tick() > card.expiresTime then
		return false
	end

	-- Check if same team
	-- (would need RevivalManager reference for team checking)

	-- Check distance
	local collectorChar = collector.Character
	if not collectorChar then return false end

	local rootPart = collectorChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then return false end

	local distance = (rootPart.Position - card.position).Magnitude
	if distance > CARD_COLLECT_RANGE then
		return false
	end

	-- Collect the card
	card.collectedBy = collector

	if not collectedCards[collector] then
		collectedCards[collector] = {}
	end
	table.insert(collectedCards[collector], card)

	-- Remove from world
	rebootCards[targetPlayerId] = nil

	-- Notify clients
	Events.FireAllClients("Reboot", "CardCollected", {
		collectorId = collector.UserId,
		collectorName = collector.Name,
		cardPlayerId = targetPlayerId,
		cardPlayerName = card.playerName,
	})

	onCardCollected:Fire(collector, card)
	print(`[RebootBeaconManager] {collector.Name} collected {card.playerName}'s card`)
	return true
end

--[[
	Get cards held by a player
]]
function RebootBeaconManager.GetCollectedCards(player: Player): { RebootCard }
	return collectedCards[player] or {}
end

--[[
	Check if player has any cards
]]
function RebootBeaconManager.HasCards(player: Player): boolean
	local cards = collectedCards[player]
	return cards ~= nil and #cards > 0
end

--[[
	Start using a reboot beacon
]]
function RebootBeaconManager.StartReboot(player: Player, beaconId: string, cardPlayerId: number)
	local beacon = rebootBeacons[beaconId]
	if not beacon then return end

	-- Check if beacon is active
	if not beacon.isActive then return end

	-- Check if beacon is on cooldown
	if tick() < beacon.cooldownEndTime then
		Events.FireClient(player, "Reboot", "BeaconOnCooldown", {
			beaconId = beaconId,
			cooldownRemaining = beacon.cooldownEndTime - tick(),
		})
		return
	end

	-- Check if beacon is in use
	if beacon.currentUser then return end

	-- Check if player has the card
	local cards = collectedCards[player]
	if not cards then return end

	local targetCard: RebootCard? = nil
	for _, card in ipairs(cards) do
		if card.playerId == cardPlayerId then
			targetCard = card
			break
		end
	end

	if not targetCard then return end

	-- Check distance
	local playerChar = player.Character
	if not playerChar then return end

	local rootPart = playerChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then return end

	local distance = (rootPart.Position - beacon.position).Magnitude
	if distance > BEACON_USE_RANGE then
		return
	end

	local modeConfig = TeamData.GetModeConfig(currentMode)

	-- Start reboot
	local attempt: RebootAttempt = {
		player = player,
		beacon = beacon,
		card = targetCard,
		startTime = tick(),
		requiredTime = modeConfig.rebootTime,
	}

	rebootAttempts[player] = attempt
	beacon.currentUser = player
	beacon.rebootTarget = targetCard
	beacon.rebootProgress = 0

	-- Notify clients
	Events.FireAllClients("Reboot", "RebootStarted", {
		playerId = player.UserId,
		beaconId = beaconId,
		targetPlayerId = cardPlayerId,
		targetPlayerName = targetCard.playerName,
		rebootTime = modeConfig.rebootTime,
	})

	onRebootStarted:Fire(player, beacon, targetCard)
	print(`[RebootBeaconManager] {player.Name} started rebooting {targetCard.playerName}`)
end

--[[
	Cancel a reboot attempt
]]
function RebootBeaconManager.CancelReboot(player: Player)
	local attempt = rebootAttempts[player]
	if not attempt then return end

	-- Clear beacon state
	attempt.beacon.currentUser = nil
	attempt.beacon.rebootTarget = nil
	attempt.beacon.rebootProgress = 0

	rebootAttempts[player] = nil

	-- Notify clients
	Events.FireAllClients("Reboot", "RebootCancelled", {
		playerId = player.UserId,
		beaconId = attempt.beacon.id,
	})

	onRebootCancelled:Fire(player, attempt.beacon)
	print(`[RebootBeaconManager] {player.Name} cancelled reboot`)
end

--[[
	Complete a reboot
]]
function RebootBeaconManager.CompleteReboot(player: Player, attempt: RebootAttempt)
	local modeConfig = TeamData.GetModeConfig(currentMode)
	local card = attempt.card
	local beacon = attempt.beacon

	-- Remove card from player's collection
	local cards = collectedCards[player]
	if cards then
		for i, c in ipairs(cards) do
			if c.playerId == card.playerId then
				table.remove(cards, i)
				break
			end
		end
	end

	-- Clear beacon state
	beacon.currentUser = nil
	beacon.rebootTarget = nil
	beacon.rebootProgress = 0
	beacon.lastUsedTime = tick()
	beacon.cooldownEndTime = tick() + modeConfig.rebootCooldown

	rebootAttempts[player] = nil

	-- Respawn the player
	local respawnPlayer = Players:GetPlayerByUserId(card.playerId)
	if respawnPlayer then
		-- Spawn near beacon
		local spawnOffset = Vector3.new(math.random(-5, 5), 3, math.random(-5, 5))
		local spawnPosition = beacon.position + spawnOffset

		respawnPlayer:LoadCharacter()

		-- Wait for character and position them
		task.spawn(function()
			local character = respawnPlayer.CharacterAdded:Wait()
			task.wait(0.1)

			local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if rootPart then
				rootPart.CFrame = CFrame.new(spawnPosition)
			end

			-- Set health
			local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
			if humanoid then
				humanoid.Health = humanoid.MaxHealth * modeConfig.rebootHealthPercent
			end
		end)
	end

	-- Notify clients
	Events.FireAllClients("Reboot", "RebootCompleted", {
		rebooterId = player.UserId,
		rebooterName = player.Name,
		rebootedId = card.playerId,
		rebootedName = card.playerName,
		beaconId = beacon.id,
		beaconCooldown = modeConfig.rebootCooldown,
	})

	onRebootCompleted:Fire(player, respawnPlayer, beacon)
	print(`[RebootBeaconManager] {player.Name} rebooted {card.playerName}`)
end

--[[
	Update loop
]]
function RebootBeaconManager.Update()
	local currentTime = tick()

	-- Update card expiration
	for playerId, card in pairs(rebootCards) do
		if currentTime > card.expiresTime then
			rebootCards[playerId] = nil

			-- Notify clients
			Events.FireAllClients("Reboot", "CardExpired", {
				playerId = playerId,
				playerName = card.playerName,
			})

			onCardExpired:Fire(card)
			print(`[RebootBeaconManager] {card.playerName}'s card expired`)
		end
	end

	-- Update reboot attempts
	for player, attempt in pairs(rebootAttempts) do
		-- Check if player is still alive
		local character = player.Character
		if not character then
			RebootBeaconManager.CancelReboot(player)
			continue
		end

		local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
		if not humanoid or humanoid.Health <= 0 then
			RebootBeaconManager.CancelReboot(player)
			continue
		end

		-- Check if still in range
		local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if rootPart then
			local distance = (rootPart.Position - attempt.beacon.position).Magnitude
			if distance > BEACON_USE_RANGE then
				RebootBeaconManager.CancelReboot(player)
				continue
			end
		end

		-- Update progress
		local elapsed = currentTime - attempt.startTime
		local progress = math.clamp(elapsed / attempt.requiredTime, 0, 1)
		attempt.beacon.rebootProgress = progress

		-- Check if complete
		if progress >= 1 then
			RebootBeaconManager.CompleteReboot(player, attempt)
		else
			-- Send progress update
			Events.FireClient(player, "Reboot", "RebootProgress", {
				progress = progress,
				beaconId = attempt.beacon.id,
			})
		end
	end
end

--[[
	Get all beacons
]]
function RebootBeaconManager.GetAllBeacons(): { RebootBeacon }
	local result = {}
	for _, beacon in pairs(rebootBeacons) do
		table.insert(result, beacon)
	end
	return result
end

--[[
	Get beacon by ID
]]
function RebootBeaconManager.GetBeacon(id: string): RebootBeacon?
	return rebootBeacons[id]
end

--[[
	Get all active cards in world
]]
function RebootBeaconManager.GetWorldCards(): { RebootCard }
	local result = {}
	for _, card in pairs(rebootCards) do
		table.insert(result, card)
	end
	return result
end

--[[
	Check if beacon is available
]]
function RebootBeaconManager.IsBeaconAvailable(beaconId: string): boolean
	local beacon = rebootBeacons[beaconId]
	if not beacon then return false end

	return beacon.isActive
		and beacon.currentUser == nil
		and tick() >= beacon.cooldownEndTime
end

--[[
	Get beacon cooldown remaining
]]
function RebootBeaconManager.GetBeaconCooldown(beaconId: string): number
	local beacon = rebootBeacons[beaconId]
	if not beacon then return 0 end

	return math.max(0, beacon.cooldownEndTime - tick())
end

--[[
	Deactivate beacon (when in storm, etc.)
]]
function RebootBeaconManager.SetBeaconActive(beaconId: string, active: boolean)
	local beacon = rebootBeacons[beaconId]
	if not beacon then return end

	beacon.isActive = active

	-- Cancel any in-progress reboots
	if not active and beacon.currentUser then
		RebootBeaconManager.CancelReboot(beacon.currentUser)
	end

	Events.FireAllClients("Reboot", "BeaconStateChanged", {
		beaconId = beaconId,
		isActive = active,
	})
end

--[[
	Reset for new match
]]
function RebootBeaconManager.Reset()
	rebootCards = {}
	collectedCards = {}
	rebootAttempts = {}

	-- Reset all beacons
	for _, beacon in pairs(rebootBeacons) do
		beacon.isActive = true
		beacon.lastUsedTime = 0
		beacon.cooldownEndTime = 0
		beacon.currentUser = nil
		beacon.rebootProgress = 0
		beacon.rebootTarget = nil
	end

	print("[RebootBeaconManager] Reset")
end

--[[
	Cleanup player
]]
function RebootBeaconManager.CleanupPlayer(player: Player)
	-- Cancel any reboot attempts
	if rebootAttempts[player] then
		RebootBeaconManager.CancelReboot(player)
	end

	-- Drop any collected cards back to world
	local cards = collectedCards[player]
	if cards then
		local character = player.Character
		local dropPosition = Vector3.new(0, 100, 0)

		if character then
			local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if rootPart then
				dropPosition = rootPart.Position
			end
		end

		for _, card in ipairs(cards) do
			card.collectedBy = nil
			card.position = dropPosition
			rebootCards[card.playerId] = card
		end
	end

	collectedCards[player] = nil
end

return RebootBeaconManager
