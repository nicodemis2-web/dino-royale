--!strict
--[[
	CombatManager.lua
	=================
	Server-side combat, damage, and hit registration
	Based on GDD Section 7: Combat System
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Events = require(ReplicatedStorage.Shared.Events)
local WeaponData = require(ReplicatedStorage.Shared.Config.WeaponData)

local CombatManager = {}

-- Types
export type DamageInfo = {
	amount: number,
	source: Player?,
	sourceType: string, -- "Weapon" | "Dinosaur" | "Storm" | "Environment" | "Fall"
	weaponId: string?,
	isHeadshot: boolean,
	isCritical: boolean,
	position: Vector3?,
}

export type PlayerCombatState = {
	player: Player,
	health: number,
	maxHealth: number,
	armor: number,
	maxArmor: number,
	lastDamageTime: number,
	lastDamageSource: Player?,
	killStreak: number,
	damageDealt: number,
	damageTaken: number,
	assists: { [number]: { damage: number, timestamp: number } }, -- UserId -> damage and time
	isDead: boolean, -- Prevents duplicate death processing
}

-- State
local playerStates: { [Player]: PlayerCombatState } = {}
local playerConnections: { [Player]: { RBXScriptConnection } } = {} -- Per-player connections for cleanup
local isInitialized = false

-- Constants
local DEFAULT_MAX_HEALTH = 100
local DEFAULT_MAX_ARMOR = 100
local HEADSHOT_MULTIPLIER = 2.0
local CRITICAL_CHANCE = 0.05
local CRITICAL_MULTIPLIER = 1.5
local ASSIST_THRESHOLD = 30 -- Minimum damage for assist
local ASSIST_TIMEOUT = 15 -- Seconds before assist expires
local ARMOR_DAMAGE_REDUCTION = 0.5 -- Armor absorbs 50% of damage

-- Signals
local onPlayerDamaged = Instance.new("BindableEvent")
local onPlayerHealed = Instance.new("BindableEvent")
local onPlayerKilled = Instance.new("BindableEvent")
local onArmorBroken = Instance.new("BindableEvent")

CombatManager.OnPlayerDamaged = onPlayerDamaged.Event
CombatManager.OnPlayerHealed = onPlayerHealed.Event
CombatManager.OnPlayerKilled = onPlayerKilled.Event
CombatManager.OnArmorBroken = onArmorBroken.Event

--[[
	Initialize the combat manager
]]
function CombatManager.Initialize()
	if isInitialized then return end
	isInitialized = true

	print("[CombatManager] Initializing...")

	-- Setup client events
	Events.OnServerEvent("Combat", "RequestHit", function(player, data)
		CombatManager.ProcessHitRequest(player, data)
	end)

	Events.OnServerEvent("Combat", "RequestMelee", function(player, data)
		CombatManager.ProcessMeleeRequest(player, data)
	end)

	-- Setup player tracking
	Players.PlayerAdded:Connect(function(player)
		CombatManager.InitializePlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		CombatManager.CleanupPlayer(player)
	end)

	-- Initialize existing players
	for _, player in ipairs(Players:GetPlayers()) do
		CombatManager.InitializePlayer(player)
	end

	print("[CombatManager] Initialized")
end

--[[
	Initialize player combat state
]]
function CombatManager.InitializePlayer(player: Player)
	local state: PlayerCombatState = {
		player = player,
		health = DEFAULT_MAX_HEALTH,
		maxHealth = DEFAULT_MAX_HEALTH,
		armor = 0,
		maxArmor = DEFAULT_MAX_ARMOR,
		lastDamageTime = 0,
		lastDamageSource = nil,
		killStreak = 0,
		damageDealt = 0,
		damageTaken = 0,
		assists = {},
		isDead = false,
	}

	playerStates[player] = state
	playerConnections[player] = {}

	-- Sync with character humanoid
	local charAddedConn = player.CharacterAdded:Connect(function(character)
		CombatManager.SyncWithCharacter(player, character)
	end)
	table.insert(playerConnections[player], charAddedConn)

	if player.Character then
		CombatManager.SyncWithCharacter(player, player.Character)
	end
end

--[[
	Sync combat state with character humanoid
]]
function CombatManager.SyncWithCharacter(player: Player, character: Model)
	local state = playerStates[player]
	if not state then return end

	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if not humanoid then return end

	-- Set max health
	humanoid.MaxHealth = state.maxHealth
	humanoid.Health = state.health

	-- Get or create connections table for this player
	local connections = playerConnections[player]
	if not connections then
		connections = {}
		playerConnections[player] = connections
	end

	-- Listen for humanoid health changes (from other sources)
	local healthConn = humanoid.HealthChanged:Connect(function(newHealth)
		-- Only update if changed externally
		if math.abs(newHealth - state.health) > 0.1 then
			state.health = newHealth
			CombatManager.BroadcastHealthUpdate(player)
		end
	end)
	table.insert(connections, healthConn)

	-- Listen for death
	local diedConn = humanoid.Died:Connect(function()
		CombatManager.HandlePlayerDeath(player)
	end)
	table.insert(connections, diedConn)
end

--[[
	Cleanup player state
]]
function CombatManager.CleanupPlayer(player: Player)
	-- Disconnect all connections for this player
	local connections = playerConnections[player]
	if connections then
		for _, conn in ipairs(connections) do
			conn:Disconnect()
		end
		playerConnections[player] = nil
	end

	playerStates[player] = nil
end

--[[
	Process hit request from client
]]
function CombatManager.ProcessHitRequest(attacker: Player, data: any)
	local targetPlayer = Players:GetPlayerByUserId(data.targetId)
	if not targetPlayer then return end

	local weaponId = data.weaponId
	local hitPosition = data.hitPosition
	local hitPart = data.hitPart

	-- Validate weapon
	local weaponStats = WeaponData.GetWeapon(weaponId)
	if not weaponStats then return end

	-- Validate distance (anti-cheat)
	local attackerChar = attacker.Character
	local targetChar = targetPlayer.Character
	if not attackerChar or not targetChar then return end

	local attackerRoot = attackerChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	local targetRoot = targetChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not attackerRoot or not targetRoot then return end

	local distance = (attackerRoot.Position - targetRoot.Position).Magnitude
	local maxRange = weaponStats.range * 1.2 -- Allow some tolerance

	if distance > maxRange then
		warn(`[CombatManager] Hit rejected: distance {distance} > range {maxRange}`)
		return
	end

	-- Calculate damage
	local baseDamage = weaponStats.damage
	local isHeadshot = hitPart and (hitPart.Name == "Head" or hitPart.Name == "face")
	local isCritical = math.random() < CRITICAL_CHANCE

	local finalDamage = baseDamage

	if isHeadshot then
		finalDamage = finalDamage * HEADSHOT_MULTIPLIER
	end

	if isCritical then
		finalDamage = finalDamage * CRITICAL_MULTIPLIER
	end

	-- Apply damage falloff for ranged weapons
	if weaponStats.falloffStart and weaponStats.falloffEnd then
		if distance > weaponStats.falloffStart then
			local falloffRange = weaponStats.falloffEnd - weaponStats.falloffStart
			local falloffProgress = math.clamp((distance - weaponStats.falloffStart) / falloffRange, 0, 1)
			local falloffMultiplier = weaponStats.falloffMultiplier or 0.5
			finalDamage = finalDamage * (1 - falloffProgress * (1 - falloffMultiplier))
		end
	end

	-- Apply damage
	local damageInfo: DamageInfo = {
		amount = finalDamage,
		source = attacker,
		sourceType = "Weapon",
		weaponId = weaponId,
		isHeadshot = isHeadshot,
		isCritical = isCritical,
		position = hitPosition,
	}

	CombatManager.DealDamage(targetPlayer, damageInfo)
end

--[[
	Process melee request
]]
function CombatManager.ProcessMeleeRequest(attacker: Player, data: any)
	local targetPlayer = Players:GetPlayerByUserId(data.targetId)
	if not targetPlayer then return end

	-- Validate melee range
	local attackerChar = attacker.Character
	local targetChar = targetPlayer.Character
	if not attackerChar or not targetChar then return end

	local attackerRoot = attackerChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	local targetRoot = targetChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not attackerRoot or not targetRoot then return end

	local distance = (attackerRoot.Position - targetRoot.Position).Magnitude
	if distance > 5 then return end -- Melee range

	local damageInfo: DamageInfo = {
		amount = 25, -- Base melee damage
		source = attacker,
		sourceType = "Weapon",
		weaponId = "Melee",
		isHeadshot = false,
		isCritical = false,
		position = targetRoot.Position,
	}

	CombatManager.DealDamage(targetPlayer, damageInfo)
end

--[[
	Deal damage to a player
]]
function CombatManager.DealDamage(target: Player, damageInfo: DamageInfo)
	local state = playerStates[target]
	if not state then return end

	-- Prevent damage to dead players (race condition guard)
	if state.isDead then return end

	local damage = damageInfo.amount

	-- Apply armor
	local armorDamage = 0
	if state.armor > 0 then
		armorDamage = damage * ARMOR_DAMAGE_REDUCTION
		armorDamage = math.min(armorDamage, state.armor)
		state.armor = state.armor - armorDamage
		damage = damage - armorDamage

		if state.armor <= 0 then
			onArmorBroken:Fire(target)
			Events.FireClient("Combat", "ArmorBroken", target, {})
		end
	end

	-- Apply remaining damage to health
	local previousHealth = state.health
	state.health = math.max(0, state.health - damage)
	state.damageTaken = state.damageTaken + damage
	state.lastDamageTime = tick()
	state.lastDamageSource = damageInfo.source

	-- Track assists with timestamp
	if damageInfo.source then
		local sourceId = damageInfo.source.UserId
		local currentTime = tick()
		local existingAssist = state.assists[sourceId]
		state.assists[sourceId] = {
			damage = (existingAssist and existingAssist.damage or 0) + damage,
			timestamp = currentTime,
		}

		-- Update attacker stats
		local attackerState = playerStates[damageInfo.source]
		if attackerState then
			attackerState.damageDealt = attackerState.damageDealt + damage
		end
	end

	-- Update humanoid
	local character = target.Character
	if character then
		local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
		if humanoid then
			humanoid.Health = state.health
		end
	end

	-- Broadcast damage event
	Events.FireClient("Combat", "DamageTaken", target, {
		amount = damage,
		armorDamage = armorDamage,
		health = state.health,
		armor = state.armor,
		sourceId = damageInfo.source and damageInfo.source.UserId or nil,
		sourceType = damageInfo.sourceType,
		isHeadshot = damageInfo.isHeadshot,
		isCritical = damageInfo.isCritical,
	})

	if damageInfo.source then
		Events.FireClient("Combat", "DamageDealt", damageInfo.source, {
			amount = damage,
			targetId = target.UserId,
			targetName = target.Name,
			isHeadshot = damageInfo.isHeadshot,
			isCritical = damageInfo.isCritical,
			targetHealth = state.health,
		})
	end

	onPlayerDamaged:Fire(target, damageInfo)

	-- Check for death
	if state.health <= 0 then
		CombatManager.HandlePlayerDeath(target)
	end
end

--[[
	Deal damage from dinosaur
]]
function CombatManager.DealDinoDamage(target: Player, dinoType: string, damage: number, position: Vector3?)
	local damageInfo: DamageInfo = {
		amount = damage,
		source = nil,
		sourceType = "Dinosaur",
		weaponId = dinoType,
		isHeadshot = false,
		isCritical = false,
		position = position,
	}

	CombatManager.DealDamage(target, damageInfo)
end

--[[
	Deal storm damage
]]
function CombatManager.DealStormDamage(target: Player, damage: number)
	local damageInfo: DamageInfo = {
		amount = damage,
		source = nil,
		sourceType = "Storm",
		isHeadshot = false,
		isCritical = false,
	}

	CombatManager.DealDamage(target, damageInfo)
end

--[[
	Deal environmental damage
]]
function CombatManager.DealEnvironmentDamage(target: Player, damage: number, source: string)
	local damageInfo: DamageInfo = {
		amount = damage,
		source = nil,
		sourceType = "Environment",
		weaponId = source,
		isHeadshot = false,
		isCritical = false,
	}

	CombatManager.DealDamage(target, damageInfo)
end

--[[
	Handle player death
]]
function CombatManager.HandlePlayerDeath(victim: Player)
	local state = playerStates[victim]
	if not state then return end

	-- Prevent duplicate death processing (race condition guard)
	if state.isDead then return end
	state.isDead = true

	local killer = state.lastDamageSource
	local currentTime = tick()

	-- Find assists (filtering expired ones based on ASSIST_TIMEOUT)
	local assists: { Player } = {}
	for userId, assistData in pairs(state.assists) do
		-- Check if assist has expired
		if currentTime - assistData.timestamp > ASSIST_TIMEOUT then
			continue
		end
		-- Check damage threshold and not the killer
		if assistData.damage >= ASSIST_THRESHOLD and userId ~= (killer and killer.UserId or 0) then
			local assistPlayer = Players:GetPlayerByUserId(userId)
			if assistPlayer then
				table.insert(assists, assistPlayer)
			end
		end
	end

	-- Update killer stats
	if killer then
		local killerState = playerStates[killer]
		if killerState then
			killerState.killStreak = killerState.killStreak + 1

			-- Notify killer
			Events.FireClient("Combat", "Kill", killer, {
				victimId = victim.UserId,
				victimName = victim.Name,
				killStreak = killerState.killStreak,
				weaponId = state.assists[killer.UserId] and "Unknown" or nil,
			})
		end
	end

	-- Notify assists
	for _, assistPlayer in ipairs(assists) do
		Events.FireClient("Combat", "Assist", assistPlayer, {
			victimId = victim.UserId,
			victimName = victim.Name,
		})
	end

	-- Reset victim state
	state.killStreak = 0
	state.assists = {}

	onPlayerKilled:Fire(victim, killer, assists)
end

--[[
	Heal a player
]]
function CombatManager.HealPlayer(target: Player, amount: number, source: string?)
	local state = playerStates[target]
	if not state then return end

	local previousHealth = state.health
	state.health = math.min(state.maxHealth, state.health + amount)
	local actualHeal = state.health - previousHealth

	-- Update humanoid
	local character = target.Character
	if character then
		local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
		if humanoid then
			humanoid.Health = state.health
		end
	end

	-- Notify client
	Events.FireClient("Combat", "Healed", target, {
		amount = actualHeal,
		health = state.health,
		source = source,
	})

	onPlayerHealed:Fire(target, actualHeal, source)
end

--[[
	Add armor to player
]]
function CombatManager.AddArmor(target: Player, amount: number, armorType: string?)
	local state = playerStates[target]
	if not state then return end

	local previousArmor = state.armor
	state.armor = math.min(state.maxArmor, state.armor + amount)
	local actualArmor = state.armor - previousArmor

	-- Notify client
	Events.FireClient("Combat", "ArmorAdded", target, {
		amount = actualArmor,
		armor = state.armor,
		armorType = armorType,
	})
end

--[[
	Set player armor
]]
function CombatManager.SetArmor(target: Player, amount: number)
	local state = playerStates[target]
	if not state then return end

	state.armor = math.clamp(amount, 0, state.maxArmor)

	Events.FireClient("Combat", "ArmorUpdated", target, {
		armor = state.armor,
	})
end

--[[
	Get player health
]]
function CombatManager.GetHealth(player: Player): number
	local state = playerStates[player]
	return state and state.health or 0
end

--[[
	Get player armor
]]
function CombatManager.GetArmor(player: Player): number
	local state = playerStates[player]
	return state and state.armor or 0
end

--[[
	Get player combat state
]]
function CombatManager.GetPlayerState(player: Player): PlayerCombatState?
	return playerStates[player]
end

--[[
	Get kill streak
]]
function CombatManager.GetKillStreak(player: Player): number
	local state = playerStates[player]
	return state and state.killStreak or 0
end

--[[
	Broadcast health update to client
]]
function CombatManager.BroadcastHealthUpdate(player: Player)
	local state = playerStates[player]
	if not state then return end

	Events.FireClient("Combat", "HealthUpdate", player, {
		health = state.health,
		maxHealth = state.maxHealth,
		armor = state.armor,
		maxArmor = state.maxArmor,
	})
end

--[[
	Reset player for new match
]]
function CombatManager.ResetPlayer(player: Player)
	local state = playerStates[player]
	if not state then return end

	state.health = state.maxHealth
	state.armor = 0
	state.lastDamageTime = 0
	state.lastDamageSource = nil
	state.killStreak = 0
	state.damageDealt = 0
	state.damageTaken = 0
	state.assists = {}
	state.isDead = false -- Allow damage processing again

	CombatManager.BroadcastHealthUpdate(player)
end

--[[
	Reset all for new match
]]
function CombatManager.Reset()
	for player in pairs(playerStates) do
		CombatManager.ResetPlayer(player)
	end
	print("[CombatManager] Reset")
end

return CombatManager
