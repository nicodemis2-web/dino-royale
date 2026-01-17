--!strict
--[[
	HealthManager.lua
	=================
	Server-authoritative health and shield management
	Handles damage, healing, downed state, and revives
]]

local Players = game:GetService("Players")
local _RunService = game:GetService("RunService")

local Constants = require(game.ReplicatedStorage.Shared.Constants)
local Events = require(game.ReplicatedStorage.Shared.Events)

local HealthManager = {}

--[[
	Types
]]
export type DamageResult = {
	actualDamage: number,
	shieldDamage: number,
	healthDamage: number,
	isKill: boolean,
	isDowned: boolean,
	hitPart: string?,
	isCritical: boolean,
}

export type HealthState = {
	health: number,
	shield: number,
	isAlive: boolean,
	isDowned: boolean,
	downedTime: number?,
	downedAttacker: Player?,
	bleedoutRate: number,
}

-- Player health states stored by UserId
local playerStates = {} :: { [number]: HealthState }

-- Game mode (affects downed behavior)
local isTeamMode = false

-- Bleedout configuration
local BLEEDOUT_DURATION = 90 -- seconds
local BLEEDOUT_BASE_RATE = Constants.PLAYER.MAX_HEALTH / BLEEDOUT_DURATION
local BLEEDOUT_DAMAGE_ACCELERATION = 0.5 -- Extra bleed rate per damage taken while downed
local BLEEDOUT_MAX_RATE = BLEEDOUT_BASE_RATE * 5 -- Cap at 5x normal bleedout rate
local _REVIVE_TIME = 5 -- seconds to revive

--[[
	Initialize health tracking for a player
	@param player The player to initialize
]]
function HealthManager.Initialize(player: Player)
	local userId = player.UserId

	playerStates[userId] = {
		health = Constants.PLAYER.MAX_HEALTH,
		shield = 0,
		isAlive = true,
		isDowned = false,
		downedTime = nil,
		downedAttacker = nil,
		bleedoutRate = BLEEDOUT_BASE_RATE,
	}

	-- Cleanup on player leaving
	player.AncestryChanged:Connect(function(_, parent)
		if not parent then
			playerStates[userId] = nil
		end
	end)
end

--[[
	Apply damage to a player
	@param player The player receiving damage
	@param amount Base damage amount
	@param source Damage source description
	@param hitPart Optional body part hit (Head, Torso, LeftArm, etc.)
	@return DamageResult with damage breakdown
]]
function HealthManager.ApplyDamage(player: Player, amount: number, source: string, hitPart: string?): DamageResult
	local userId = player.UserId
	local state = playerStates[userId]

	if not state then
		return {
			actualDamage = 0,
			shieldDamage = 0,
			healthDamage = 0,
			isKill = false,
			isDowned = false,
			hitPart = hitPart,
			isCritical = false,
		}
	end

	-- Already dead
	if not state.isAlive then
		return {
			actualDamage = 0,
			shieldDamage = 0,
			healthDamage = 0,
			isKill = false,
			isDowned = false,
			hitPart = hitPart,
			isCritical = false,
		}
	end

	-- Calculate damage multiplier based on hit part
	local multiplier = Constants.COMBAT.BODY_MULTIPLIER
	local isCritical = false

	if hitPart then
		local hitPartLower = string.lower(hitPart)
		if hitPartLower == "head" then
			multiplier = Constants.COMBAT.HEADSHOT_MULTIPLIER
			isCritical = true
		elseif
			string.find(hitPartLower, "arm")
			or string.find(hitPartLower, "leg")
			or string.find(hitPartLower, "hand")
			or string.find(hitPartLower, "foot")
		then
			multiplier = Constants.COMBAT.LIMB_MULTIPLIER
		end
	end

	local finalDamage = amount * multiplier
	local shieldDamage = 0
	local healthDamage = 0

	-- Handle downed state damage differently
	if state.isDowned then
		-- Damage while downed accelerates bleedout (capped to prevent overflow)
		state.bleedoutRate = state.bleedoutRate + (finalDamage * BLEEDOUT_DAMAGE_ACCELERATION)
		state.bleedoutRate = math.min(state.bleedoutRate, BLEEDOUT_MAX_RATE)
		healthDamage = finalDamage

		-- Direct lethal damage while downed = elimination
		if finalDamage >= state.health then
			state.health = 0
			state.isAlive = false
			state.isDowned = false

			return {
				actualDamage = finalDamage,
				shieldDamage = 0,
				healthDamage = finalDamage,
				isKill = true,
				isDowned = false,
				hitPart = hitPart,
				isCritical = isCritical,
			}
		end

		state.health = math.max(0, state.health - finalDamage)

		return {
			actualDamage = finalDamage,
			shieldDamage = 0,
			healthDamage = finalDamage,
			isKill = false,
			isDowned = true,
			hitPart = hitPart,
			isCritical = isCritical,
		}
	end

	-- Normal damage: shield absorbs first
	if state.shield > 0 then
		shieldDamage = math.min(state.shield, finalDamage)
		state.shield = state.shield - shieldDamage
		finalDamage = finalDamage - shieldDamage
	end

	-- Remaining damage goes to health
	healthDamage = finalDamage
	state.health = math.max(0, state.health - healthDamage)

	local result: DamageResult = {
		actualDamage = shieldDamage + healthDamage,
		shieldDamage = shieldDamage,
		healthDamage = healthDamage,
		isKill = false,
		isDowned = false,
		hitPart = hitPart,
		isCritical = isCritical,
	}

	-- Check for elimination/downed
	if state.health <= 0 then
		if isTeamMode then
			-- Team mode: enter downed state
			state.isDowned = true
			state.downedTime = tick()
			state.health = Constants.PLAYER.MAX_HEALTH * 0.5 -- Start with 50% health in downed
			state.bleedoutRate = BLEEDOUT_BASE_RATE
			result.isDowned = true
		else
			-- Solo mode: immediate elimination
			state.isAlive = false
			result.isKill = true
		end
	end

	-- Fire damage event to client
	Events.FireClient("Combat", "DamageDealt", player, {
		damage = result.actualDamage,
		hitPart = hitPart,
		isCritical = isCritical,
		source = source,
	})

	return result
end

--[[
	Apply healing to a player
	@param player The player to heal
	@param amount Amount to heal
	@param maxHealTo Maximum health to heal to (optional, defaults to MAX_HEALTH)
	@return Actual amount healed
]]
function HealthManager.ApplyHealing(player: Player, amount: number, maxHealTo: number?): number
	local userId = player.UserId
	local state = playerStates[userId]

	if not state or not state.isAlive or state.isDowned then
		return 0
	end

	local maxHealth = maxHealTo or Constants.PLAYER.MAX_HEALTH
	local currentHealth = state.health
	local newHealth = math.min(maxHealth, currentHealth + amount)
	local actualHealed = newHealth - currentHealth

	state.health = newHealth

	return actualHealed
end

--[[
	Apply shield to a player
	@param player The player to shield
	@param amount Amount of shield to add
	@return Actual amount of shield applied
]]
function HealthManager.ApplyShield(player: Player, amount: number): number
	local userId = player.UserId
	local state = playerStates[userId]

	if not state or not state.isAlive or state.isDowned then
		return 0
	end

	local currentShield = state.shield
	local newShield = math.min(Constants.PLAYER.MAX_SHIELD, currentShield + amount)
	local actualApplied = newShield - currentShield

	state.shield = newShield

	return actualApplied
end

--[[
	Set a player to downed state (team mode only)
	@param player The player to down
	@param attacker Optional player who downed them
]]
function HealthManager.SetDowned(player: Player, attacker: Player?)
	local userId = player.UserId
	local state = playerStates[userId]

	if not state or not state.isAlive then
		return
	end

	state.isDowned = true
	state.downedTime = tick()
	state.downedAttacker = attacker
	state.health = Constants.PLAYER.MAX_HEALTH * 0.5
	state.bleedoutRate = BLEEDOUT_BASE_RATE

	-- Fire downed event
	Events.FireAllClients("Team", "PlayerDowned", {
		playerId = player.UserId,
		position = player.Character and player.Character:GetPivot().Position or Vector3.zero,
	})
end

--[[
	Revive a downed player
	@param player The player to revive
	@param reviver Optional player who revived them
]]
function HealthManager.Revive(player: Player, reviver: Player?)
	local userId = player.UserId
	local state = playerStates[userId]

	if not state or not state.isAlive or not state.isDowned then
		return
	end

	state.isDowned = false
	state.downedTime = nil
	state.downedAttacker = nil
	state.health = 30 -- Revive with low health
	state.bleedoutRate = BLEEDOUT_BASE_RATE

	-- Fire revive event
	Events.FireAllClients("Team", "ReviveComplete", {
		reviverId = reviver and reviver.UserId or nil,
		revivedId = player.UserId,
	})
end

--[[
	Get the current health state for a player
	@param player The player to get state for
	@return The player's health state
]]
function HealthManager.GetState(player: Player): HealthState?
	return playerStates[player.UserId]
end

--[[
	Eliminate a player immediately
	@param player The player to eliminate
	@param killer Optional player who eliminated them
	@param weapon Optional weapon used
]]
function HealthManager.Eliminate(player: Player, killer: Player?, weapon: string?)
	local userId = player.UserId
	local state = playerStates[userId]

	if not state then
		return
	end

	state.health = 0
	state.shield = 0
	state.isAlive = false
	state.isDowned = false

	-- Fire elimination event
	Events.FireAllClients("Combat", "PlayerEliminated", {
		victimId = player.UserId,
		killerId = killer and killer.UserId or nil,
		weapon = weapon or "Unknown",
		placement = 0, -- To be filled by EliminationManager
	})
end

--[[
	Set the game mode (affects downed behavior)
	@param teamMode Whether team mode is active
]]
function HealthManager.SetTeamMode(teamMode: boolean)
	isTeamMode = teamMode
end

--[[
	Reset a player's health state (for respawning)
	@param player The player to reset
]]
function HealthManager.Reset(player: Player)
	local userId = player.UserId

	playerStates[userId] = {
		health = Constants.PLAYER.MAX_HEALTH,
		shield = 0,
		isAlive = true,
		isDowned = false,
		downedTime = nil,
		downedAttacker = nil,
		bleedoutRate = BLEEDOUT_BASE_RATE,
	}
end

--[[
	Update function - handles bleedout for downed players
	Should be called every frame from main game loop
	@param dt Delta time since last update
]]
function HealthManager.Update(dt: number)
	for userId, state in pairs(playerStates) do
		if state.isDowned and state.isAlive and state.downedTime then
			-- Apply bleedout
			state.health = state.health - (state.bleedoutRate * dt)

			-- Check for elimination
			if state.health <= 0 then
				local player = Players:GetPlayerByUserId(userId)
				if player then
					HealthManager.Eliminate(player, state.downedAttacker, nil)
				end
			end

			-- Check for timeout
			local downedDuration = tick() - state.downedTime
			if downedDuration >= BLEEDOUT_DURATION then
				local player = Players:GetPlayerByUserId(userId)
				if player then
					HealthManager.Eliminate(player, state.downedAttacker, nil)
				end
			end
		end
	end
end

--[[
	Get all player states (for debugging/admin)
	@return Table of all player states
]]
function HealthManager.GetAllStates(): { [number]: HealthState }
	return playerStates
end

return HealthManager
