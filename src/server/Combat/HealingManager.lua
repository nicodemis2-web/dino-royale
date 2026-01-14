--!strict
--[[
	HealingManager.lua
	==================
	Server-side healing item usage and buff management
	Based on GDD Section 6: Items & Loot
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Events = require(ReplicatedStorage.Shared.Events)
local HealingData = require(ReplicatedStorage.Shared.HealingData)

-- Forward declare CombatManager
local CombatManager: any = nil

local HealingManager = {}

-- Types
export type ActiveHeal = {
	player: Player,
	item: HealingData.HealingItem,
	startTime: number,
	endTime: number,
	healRemaining: number,
}

export type ActiveBuff = {
	player: Player,
	buffType: string,
	value: number,
	startTime: number,
	endTime: number,
}

-- State
local activeHeals: { [Player]: ActiveHeal } = {}
local activeBuffs: { [Player]: { [string]: ActiveBuff } } = {}
local healingInProgress: { [Player]: { item: HealingData.HealingItem, startTime: number } } = {}
local isInitialized = false

-- Signals
local onHealStarted = Instance.new("BindableEvent")
local onHealCompleted = Instance.new("BindableEvent")
local onHealCancelled = Instance.new("BindableEvent")
local onBuffApplied = Instance.new("BindableEvent")
local onBuffExpired = Instance.new("BindableEvent")

HealingManager.OnHealStarted = onHealStarted.Event
HealingManager.OnHealCompleted = onHealCompleted.Event
HealingManager.OnHealCancelled = onHealCancelled.Event
HealingManager.OnBuffApplied = onBuffApplied.Event
HealingManager.OnBuffExpired = onBuffExpired.Event

--[[
	Initialize the healing manager
]]
function HealingManager.Initialize()
	if isInitialized then return end
	isInitialized = true

	print("[HealingManager] Initializing...")

	-- Get CombatManager reference
	local Combat = script.Parent
	CombatManager = require(Combat.CombatManager)

	-- Setup client events
	Events.OnServerEvent("Healing", function(player, action, data)
		if action == "StartUse" then
			HealingManager.StartUsingItem(player, data.itemId)
		elseif action == "CancelUse" then
			HealingManager.CancelUsingItem(player)
		end
	end)

	-- Start update loop
	task.spawn(function()
		while true do
			HealingManager.Update()
			task.wait(0.1)
		end
	end)

	print("[HealingManager] Initialized")
end

--[[
	Start using a healing item
]]
function HealingManager.StartUsingItem(player: Player, itemId: string)
	-- Check if already using something
	if healingInProgress[player] then
		return
	end

	local item = HealingData.GetItem(itemId)
	if not item then return end

	-- TODO: Check if player has item in inventory
	-- local hasItem = InventoryManager.HasItem(player, itemId)
	-- if not hasItem then return end

	-- Start using
	healingInProgress[player] = {
		item = item,
		startTime = tick(),
	}

	-- Notify client
	Events.FireClient(player, "Healing", "UseStarted", {
		itemId = itemId,
		useTime = item.useTime,
		canMove = item.canMoveWhileUsing,
	})

	onHealStarted:Fire(player, item)
	print(`[HealingManager] {player.Name} started using {item.displayName}`)

	-- Schedule completion
	task.delay(item.useTime, function()
		HealingManager.CompleteUsingItem(player)
	end)
end

--[[
	Cancel using item
]]
function HealingManager.CancelUsingItem(player: Player)
	local inProgress = healingInProgress[player]
	if not inProgress then return end

	if not inProgress.item.canCancelUse then
		return -- Can't cancel this item
	end

	healingInProgress[player] = nil

	-- Notify client
	Events.FireClient(player, "Healing", "UseCancelled", {})

	onHealCancelled:Fire(player, inProgress.item)
	print(`[HealingManager] {player.Name} cancelled using {inProgress.item.displayName}`)
end

--[[
	Complete using item
]]
function HealingManager.CompleteUsingItem(player: Player)
	local inProgress = healingInProgress[player]
	if not inProgress then return end

	local item = inProgress.item
	healingInProgress[player] = nil

	-- Apply effect based on type
	if item.healingType == "Instant" then
		CombatManager.HealPlayer(player, item.healAmount, item.id)

	elseif item.healingType == "OverTime" then
		-- Start over-time healing
		local heal: ActiveHeal = {
			player = player,
			item = item,
			startTime = tick(),
			endTime = tick() + (item.healDuration or 0),
			healRemaining = item.healAmount,
		}
		activeHeals[player] = heal

	elseif item.healingType == "Shield" then
		if item.armorAmount then
			CombatManager.AddArmor(player, item.armorAmount, item.id)
		end

	elseif item.healingType == "Buff" then
		-- Apply instant heal if any
		if item.healAmount > 0 then
			CombatManager.HealPlayer(player, item.healAmount, item.id)
		end

		-- Apply buffs
		if item.speedBoost then
			HealingManager.ApplyBuff(player, "Speed", item.speedBoost, item.buffDuration or 10)
		end

		if item.damageBoost then
			HealingManager.ApplyBuff(player, "Damage", item.damageBoost, item.buffDuration or 10)
		end

		if item.armorAmount then
			CombatManager.AddArmor(player, item.armorAmount, item.id)
		end
	end

	-- TODO: Remove item from inventory
	-- InventoryManager.RemoveItem(player, item.id, 1)

	-- Notify client
	Events.FireClient(player, "Healing", "UseCompleted", {
		itemId = item.id,
		healAmount = item.healAmount,
		armorAmount = item.armorAmount,
	})

	onHealCompleted:Fire(player, item)
	print(`[HealingManager] {player.Name} used {item.displayName}`)
end

--[[
	Apply a buff to player
]]
function HealingManager.ApplyBuff(player: Player, buffType: string, value: number, duration: number)
	if not activeBuffs[player] then
		activeBuffs[player] = {}
	end

	local buff: ActiveBuff = {
		player = player,
		buffType = buffType,
		value = value,
		startTime = tick(),
		endTime = tick() + duration,
	}

	activeBuffs[player][buffType] = buff

	-- Apply effect
	HealingManager.ApplyBuffEffect(player, buffType, value)

	-- Notify client
	Events.FireClient(player, "Healing", "BuffApplied", {
		buffType = buffType,
		value = value,
		duration = duration,
	})

	onBuffApplied:Fire(player, buffType, value, duration)
	print(`[HealingManager] Applied {buffType} buff ({value}) to {player.Name}`)
end

--[[
	Apply buff effect to character
]]
function HealingManager.ApplyBuffEffect(player: Player, buffType: string, value: number)
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
	if not humanoid then return end

	if buffType == "Speed" then
		local baseSpeed = 16
		humanoid.WalkSpeed = baseSpeed * (1 + value)
	end

	-- Damage buff is handled in CombatManager when calculating damage
end

--[[
	Remove buff effect from character
]]
function HealingManager.RemoveBuffEffect(player: Player, buffType: string)
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
	if not humanoid then return end

	if buffType == "Speed" then
		humanoid.WalkSpeed = 16 -- Reset to default
	end
end

--[[
	Get active buff value
]]
function HealingManager.GetBuffValue(player: Player, buffType: string): number
	local buffs = activeBuffs[player]
	if not buffs then return 0 end

	local buff = buffs[buffType]
	if not buff then return 0 end

	if tick() > buff.endTime then
		return 0
	end

	return buff.value
end

--[[
	Check if player has buff
]]
function HealingManager.HasBuff(player: Player, buffType: string): boolean
	return HealingManager.GetBuffValue(player, buffType) > 0
end

--[[
	Update loop
]]
function HealingManager.Update()
	local currentTime = tick()

	-- Update over-time heals
	for player, heal in pairs(activeHeals) do
		if currentTime >= heal.endTime or heal.healRemaining <= 0 then
			activeHeals[player] = nil
		else
			-- Apply heal tick
			local healPerTick = heal.item.healPerSecond or (heal.item.healAmount / (heal.item.healDuration or 1))
			local healAmount = healPerTick * 0.1 -- 0.1 second tick rate

			healAmount = math.min(healAmount, heal.healRemaining)
			heal.healRemaining = heal.healRemaining - healAmount

			CombatManager.HealPlayer(player, healAmount, heal.item.id)
		end
	end

	-- Update buffs
	for player, buffs in pairs(activeBuffs) do
		for buffType, buff in pairs(buffs) do
			if currentTime >= buff.endTime then
				-- Remove expired buff
				HealingManager.RemoveBuffEffect(player, buffType)
				buffs[buffType] = nil

				-- Notify client
				Events.FireClient(player, "Healing", "BuffExpired", {
					buffType = buffType,
				})

				onBuffExpired:Fire(player, buffType)
				print(`[HealingManager] {buffType} buff expired for {player.Name}`)
			end
		end

		-- Clean up empty buff tables
		local hasBuffs = false
		for _ in pairs(buffs) do
			hasBuffs = true
			break
		end
		if not hasBuffs then
			activeBuffs[player] = nil
		end
	end

	-- Check for interrupted healing (player took damage while healing)
	for player, inProgress in pairs(healingInProgress) do
		if not inProgress.item.canMoveWhileUsing then
			-- Check if player is moving
			local character = player.Character
			if character then
				local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
				if humanoid and humanoid.MoveDirection.Magnitude > 0.1 then
					HealingManager.CancelUsingItem(player)
				end
			end
		end
	end
end

--[[
	Reset for new match
]]
function HealingManager.Reset()
	activeHeals = {}
	activeBuffs = {}
	healingInProgress = {}
	print("[HealingManager] Reset")
end

--[[
	Cleanup player
]]
function HealingManager.CleanupPlayer(player: Player)
	activeHeals[player] = nil
	healingInProgress[player] = nil

	if activeBuffs[player] then
		for buffType in pairs(activeBuffs[player]) do
			HealingManager.RemoveBuffEffect(player, buffType)
		end
		activeBuffs[player] = nil
	end
end

return HealingManager
