--!strict
--[[
	EliminationManager.lua
	======================
	Handles player death, loot dropping, and game end conditions
	Manages team mode downed state and reboot system
]]

local Players = game:GetService("Players")

local Events = require(game.ReplicatedStorage.Shared.Events)

-- Forward declarations for dependencies
local GameManager: any = nil
local InventoryManager: any = nil
local LootSpawner: any = nil
local HealthManager: any = nil

local EliminationManager = {}

-- Type definitions
type EliminationInfo = {
	victim: Player,
	victimId: number,
	victimName: string,
	eliminator: Player?,
	eliminatorId: number?,
	eliminatorName: string?,
	weapon: string?,
	source: string, -- "Player", "Storm", "Dinosaur", "Fall"
	placement: number,
	timestamp: number,
}

type RebootCard = {
	playerId: number,
	playerName: string,
	position: Vector3,
	expirationTime: number,
	worldItem: BasePart?,
}

-- State
local eliminations = {} :: { EliminationInfo }
local playerStats = {} :: { [number]: { kills: number, assists: number, damageDealt: number } }
local rebootCards = {} :: { [number]: RebootCard }
local currentPlacement = 100 -- Decrements as players are eliminated

-- Settings
local REBOOT_CARD_DURATION = 120 -- 2 minutes
local LOOT_SCATTER_RADIUS = 5
local DOWNED_BLEEDOUT_TIME = 90

-- Team mode settings
local isTeamMode = false -- Set by GameManager

--[[
	Set dependency references
]]
function EliminationManager.SetGameManager(manager: any)
	GameManager = manager
end

function EliminationManager.SetInventoryManager(manager: any)
	InventoryManager = manager
end

function EliminationManager.SetLootSpawner(spawner: any)
	LootSpawner = spawner
end

function EliminationManager.SetHealthManager(manager: any)
	HealthManager = manager
end

--[[
	Set team mode
]]
function EliminationManager.SetTeamMode(enabled: boolean)
	isTeamMode = enabled
end

--[[
	Initialize player stats
]]
function EliminationManager.InitializePlayer(player: Player)
	playerStats[player.UserId] = {
		kills = 0,
		assists = 0,
		damageDealt = 0,
	}
end

--[[
	Record damage dealt (for assists)
]]
function EliminationManager.RecordDamage(attacker: Player, victim: Player, damage: number)
	local stats = playerStats[attacker.UserId]
	if stats then
		stats.damageDealt = stats.damageDealt + damage
	end

	-- Track damage sources for assist calculation (simplified)
	-- In a full implementation, would track per-victim damage history
end

--[[
	Get player stats
]]
function EliminationManager.GetPlayerStats(player: Player): { kills: number, assists: number, damageDealt: number }?
	return playerStats[player.UserId]
end

--[[
	Get current placement number
]]
function EliminationManager.GetCurrentPlacement(): number
	return currentPlacement
end

--[[
	Drop player's loot at death position
]]
local function dropPlayerLoot(player: Player, position: Vector3)
	if not InventoryManager then
		return
	end

	local inventory = InventoryManager.GetInventory(player)
	if not inventory then
		return
	end

	-- Drop weapons
	if inventory.weapons then
		for slot, weapon in pairs(inventory.weapons) do
			if weapon then
				local offsetAngle = (slot / 5) * math.pi * 2
				local offset = Vector3.new(
					math.cos(offsetAngle) * LOOT_SCATTER_RADIUS,
					0.5,
					math.sin(offsetAngle) * LOOT_SCATTER_RADIUS
				)
				local dropPosition = position + offset

				if LootSpawner then
					LootSpawner.CreateWorldItem({
						type = "Weapon",
						id = weapon.id,
						rarity = weapon.rarity,
						state = weapon.state,
					}, dropPosition)
				end
			end
		end
	end

	-- Drop consumables
	if inventory.consumables then
		local consumableIndex = 0
		for itemId, count in pairs(inventory.consumables) do
			if count > 0 then
				local offsetAngle = (consumableIndex / 10) * math.pi * 2
				local offset = Vector3.new(
					math.cos(offsetAngle) * (LOOT_SCATTER_RADIUS + 2),
					0.5,
					math.sin(offsetAngle) * (LOOT_SCATTER_RADIUS + 2)
				)
				local dropPosition = position + offset

				if LootSpawner then
					LootSpawner.CreateWorldItem({
						type = "Consumable",
						id = itemId,
						count = count,
					}, dropPosition)
				end

				consumableIndex = consumableIndex + 1
			end
		end
	end

	-- Drop ammo
	if inventory.ammo then
		local ammoIndex = 0
		for ammoType, count in pairs(inventory.ammo) do
			if count > 0 then
				local offsetAngle = (ammoIndex / 5) * math.pi * 2 + math.pi
				local offset = Vector3.new(
					math.cos(offsetAngle) * (LOOT_SCATTER_RADIUS + 1),
					0.5,
					math.sin(offsetAngle) * (LOOT_SCATTER_RADIUS + 1)
				)
				local dropPosition = position + offset

				if LootSpawner then
					LootSpawner.CreateWorldItem({
						type = "Ammo",
						id = ammoType,
						count = count,
					}, dropPosition)
				end

				ammoIndex = ammoIndex + 1
			end
		end
	end

	-- Clear inventory
	InventoryManager.ClearInventory(player)
end

--[[
	Create reboot card (team mode only)
]]
local function createRebootCard(player: Player, position: Vector3)
	if not isTeamMode then
		return
	end

	-- Create world item for reboot card
	local cardPart: BasePart? = nil
	if LootSpawner then
		cardPart = LootSpawner.CreateWorldItem({
			type = "RebootCard",
			playerId = player.UserId,
			playerName = player.Name,
		}, position + Vector3.new(0, 1, 0))
	end

	rebootCards[player.UserId] = {
		playerId = player.UserId,
		playerName = player.Name,
		position = position,
		expirationTime = tick() + REBOOT_CARD_DURATION,
		worldItem = cardPart,
	}

	-- Notify team
	Events.FireAllClients("Team", "RebootCardDropped", {
		playerId = player.UserId,
		position = position,
	})

	-- Schedule expiration
	task.delay(REBOOT_CARD_DURATION, function()
		local card = rebootCards[player.UserId]
		if card and card.expirationTime <= tick() then
			EliminationManager.ExpireRebootCard(player.UserId)
		end
	end)
end

--[[
	Expire a reboot card
]]
function EliminationManager.ExpireRebootCard(playerId: number)
	local card = rebootCards[playerId]
	if not card then
		return
	end

	-- Destroy world item
	if card.worldItem then
		card.worldItem:Destroy()
	end

	rebootCards[playerId] = nil

	print(`[EliminationManager] Reboot card expired for player {playerId}`)
end

--[[
	Use reboot card at beacon
]]
function EliminationManager.UseRebootCard(user: Player, cardPlayerId: number, beaconPosition: Vector3): boolean
	local card = rebootCards[cardPlayerId]
	if not card then
		return false
	end

	-- Find the player (may be spectating)
	local cardPlayer = Players:GetPlayerByUserId(cardPlayerId)
	if not cardPlayer then
		return false
	end

	-- Destroy card
	if card.worldItem then
		card.worldItem:Destroy()
	end
	rebootCards[cardPlayerId] = nil

	-- Respawn player at beacon
	local spawnPosition = beaconPosition + Vector3.new(0, 5, 0)

	-- Load character if needed
	if not cardPlayer.Character then
		cardPlayer:LoadCharacter()
		task.wait(0.5)
	end

	-- Teleport to beacon
	local character = cardPlayer.Character
	if character then
		local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if rootPart then
			rootPart.CFrame = CFrame.new(spawnPosition)
		end
	end

	-- Restore health (half health, no shield)
	if HealthManager then
		HealthManager.SetHealth(cardPlayer, 50)
		HealthManager.SetShield(cardPlayer, 0)
	end

	-- Register as alive again
	if GameManager then
		GameManager.RegisterAlivePlayer(cardPlayer)
	end

	-- Notify team
	Events.FireAllClients("Team", "RebootComplete", {
		rebooterId = user.UserId,
		rebootedId = cardPlayerId,
		position = spawnPosition,
	})

	print(`[EliminationManager] {user.Name} rebooted {cardPlayer.Name}`)

	return true
end

--[[
	Eliminate a player
]]
function EliminationManager.EliminatePlayer(
	victim: Player,
	eliminator: Player?,
	weapon: string?,
	source: string
)
	-- Get death position
	local position = Vector3.new(0, 0, 0)
	local character = victim.Character
	if character then
		local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if rootPart then
			position = rootPart.Position
		end
	end

	-- Assign placement
	local placement = currentPlacement
	currentPlacement = currentPlacement - 1

	-- Record elimination
	local eliminationInfo: EliminationInfo = {
		victim = victim,
		victimId = victim.UserId,
		victimName = victim.Name,
		eliminator = eliminator,
		eliminatorId = eliminator and eliminator.UserId or nil,
		eliminatorName = eliminator and eliminator.Name or source,
		weapon = weapon,
		source = source,
		placement = placement,
		timestamp = tick(),
	}

	table.insert(eliminations, eliminationInfo)

	-- Update eliminator stats
	if eliminator then
		local stats = playerStats[eliminator.UserId]
		if stats then
			stats.kills = stats.kills + 1
		end
	end

	-- Drop loot
	dropPlayerLoot(victim, position)

	-- Create reboot card (team mode)
	if isTeamMode then
		createRebootCard(victim, position)
	end

	-- Remove from alive players
	if GameManager then
		GameManager.RemoveAlivePlayer(victim)
	end

	-- Broadcast elimination
	Events.FireAllClients("Combat", "PlayerEliminated", {
		victimId = victim.UserId,
		victimName = victim.Name,
		killerId = eliminator and eliminator.UserId or nil,
		killerName = eliminator and eliminator.Name or source,
		weapon = weapon,
		placement = placement,
	})

	-- Notify victim of their placement
	Events.FireClient(victim, "Combat", "YouWereEliminated", {
		placement = placement,
		eliminator = eliminator and eliminator.Name or source,
		weapon = weapon,
	})

	-- Set victim to spectate mode
	task.defer(function()
		-- Remove character or put in spectate mode
		-- In a full implementation, would enable spectator camera
		if victim.Character then
			victim.Character:Destroy()
		end
	end)

	print(
		`[EliminationManager] {victim.Name} eliminated by {eliminator and eliminator.Name or source} (#{placement})`
	)
end

--[[
	Handle player downed (team mode)
]]
function EliminationManager.DownPlayer(victim: Player, attacker: Player?)
	if not isTeamMode then
		-- Solo mode - eliminate immediately
		EliminationManager.EliminatePlayer(victim, attacker, nil, "Player")
		return
	end

	-- Set downed state through HealthManager
	if HealthManager then
		HealthManager.SetDowned(victim, attacker)
	end

	-- Notify team
	local position = Vector3.zero
	local character = victim.Character
	if character then
		local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if rootPart then
			position = rootPart.Position
		end
	end

	Events.FireAllClients("Team", "PlayerDowned", {
		playerId = victim.UserId,
		position = position,
	})

	-- Start bleedout timer
	task.delay(DOWNED_BLEEDOUT_TIME, function()
		-- Check if still downed
		if HealthManager then
			local state = HealthManager.GetState(victim)
			if state and state.isDowned then
				EliminationManager.EliminatePlayer(victim, attacker, nil, "Bleedout")
			end
		end
	end)

	print(`[EliminationManager] {victim.Name} was downed`)
end

--[[
	Handle revive complete
]]
function EliminationManager.OnReviveComplete(reviver: Player, revived: Player)
	if HealthManager then
		HealthManager.Revive(revived, reviver)
	end

	Events.FireAllClients("Team", "ReviveComplete", {
		reviverId = reviver.UserId,
		revivedId = revived.UserId,
	})

	print(`[EliminationManager] {reviver.Name} revived {revived.Name}`)
end

--[[
	Get all eliminations
]]
function EliminationManager.GetEliminations(): { EliminationInfo }
	return eliminations
end

--[[
	Get elimination count
]]
function EliminationManager.GetEliminationCount(): number
	return #eliminations
end

--[[
	Get reboot card for player
]]
function EliminationManager.GetRebootCard(playerId: number): RebootCard?
	return rebootCards[playerId]
end

--[[
	Initialize the elimination manager
]]
function EliminationManager.Initialize()
	eliminations = {}
	playerStats = {}
	rebootCards = {}

	-- Set initial placement based on total players
	if GameManager then
		currentPlacement = GameManager.GetTotalPlayersInMatch()
	else
		currentPlacement = 100
	end

	-- Initialize stats for all current players
	for _, player in ipairs(Players:GetPlayers()) do
		EliminationManager.InitializePlayer(player)
	end

	-- Listen for new players
	Players.PlayerAdded:Connect(function(player)
		EliminationManager.InitializePlayer(player)
	end)

	print("[EliminationManager] Initialized")
end

--[[
	Reset the elimination manager
]]
function EliminationManager.Reset()
	eliminations = {}
	rebootCards = {}
	currentPlacement = 100

	-- Clear reboot card world items
	for _, card in pairs(rebootCards) do
		if card.worldItem then
			card.worldItem:Destroy()
		end
	end
	rebootCards = {}

	-- Reset player stats
	for userId, _ in pairs(playerStats) do
		playerStats[userId] = {
			kills = 0,
			assists = 0,
			damageDealt = 0,
		}
	end

	print("[EliminationManager] Reset")
end

--[[
	Cleanup on player leaving
]]
function EliminationManager.OnPlayerRemoving(player: Player)
	-- Remove reboot card
	local card = rebootCards[player.UserId]
	if card and card.worldItem then
		card.worldItem:Destroy()
	end
	rebootCards[player.UserId] = nil

	-- Clear stats
	playerStats[player.UserId] = nil
end

return EliminationManager
