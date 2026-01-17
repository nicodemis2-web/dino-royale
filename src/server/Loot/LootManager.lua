--!strict
--[[
	LootManager.lua
	===============
	Server-side loot spawning and management
	Based on GDD Section 6: Items & Loot
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Events = require(ReplicatedStorage.Shared.Events)
local LootData = require(ReplicatedStorage.Shared.LootData)
local POIData = require(ReplicatedStorage.Shared.POIData)

local LootManager = {}

-- Types
export type LootSpawn = {
	id: string,
	item: LootData.LootItem,
	amount: number,
	position: Vector3,
	isPickedUp: boolean,
	spawnTime: number,
}

export type Chest = {
	id: string,
	position: Vector3,
	tier: LootData.LootTier,
	isOpened: boolean,
	contents: { LootSpawn },
}

-- State
local worldLoot: { [string]: LootSpawn } = {}
local chests: { [string]: Chest } = {}
local lootIdCounter = 0
local isInitialized = false

-- Signals
local onLootSpawned = Instance.new("BindableEvent")
local onLootPickedUp = Instance.new("BindableEvent")
local onChestOpened = Instance.new("BindableEvent")

LootManager.OnLootSpawned = onLootSpawned.Event
LootManager.OnLootPickedUp = onLootPickedUp.Event
LootManager.OnChestOpened = onChestOpened.Event

--[[
	Generate unique loot ID
]]
local function generateLootId(): string
	lootIdCounter = lootIdCounter + 1
	return `loot_{lootIdCounter}`
end

--[[
	Initialize the loot manager
]]
function LootManager.Initialize()
	if isInitialized then return end
	isInitialized = true

	print("[LootManager] Initializing...")

	-- Setup client events
	Events.OnServerEvent("Loot", "RequestPickup", function(player, data)
		if typeof(data) == "table" and typeof(data.lootId) == "string" then
			LootManager.PickupLoot(player, data.lootId)
		end
	end)

	print("[LootManager] Initialized")
end

--[[
	Spawn loot at all POIs
]]
function LootManager.SpawnPOILoot()
	print("[LootManager] Spawning POI loot...")

	for poiId, poi in pairs(POIData.POIs) do
		local position = POIData.GetPosition(poi)

		-- Spawn chests
		local chestCount = math.random(poi.chestCount.min, poi.chestCount.max)
		for i = 1, chestCount do
			local offset = Vector3.new(
				math.random(-poi.radius, poi.radius) * 0.8,
				0,
				math.random(-poi.radius, poi.radius) * 0.8
			)
			LootManager.SpawnChest(position + offset, poi.lootTier :: LootData.LootTier)
		end

		-- Spawn floor loot
		for i = 1, poi.floorLootSpawns do
			local offset = Vector3.new(
				math.random(-poi.radius, poi.radius) * 0.9,
				math.random(0, 3),
				math.random(-poi.radius, poi.radius) * 0.9
			)
			LootManager.SpawnRandomLoot(position + offset, poi.lootTier :: LootData.LootTier)
		end
	end

	print(`[LootManager] Spawned loot at {#POIData.POIs} POIs`)
end

--[[
	Spawn a chest at position
]]
function LootManager.SpawnChest(position: Vector3, tier: LootData.LootTier): Chest
	local chestConfig = LootData.ChestConfigs[tier]
	local chestId = `chest_{generateLootId()}`

	local chest: Chest = {
		id = chestId,
		position = position,
		tier = tier,
		isOpened = false,
		contents = {},
	}

	-- Generate contents
	local itemCount = math.random(chestConfig.minItems, chestConfig.maxItems)

	-- Guaranteed categories first
	if chestConfig.guaranteedCategories then
		for _, category in ipairs(chestConfig.guaranteedCategories) do
			local item = LootManager.SelectRandomItem(category, chestConfig.rarityBonus)
			if item then
				local spawn: LootSpawn = {
					id = generateLootId(),
					item = item,
					amount = LootData.GetDropAmount(item, tier),
					position = position,
					isPickedUp = false,
					spawnTime = tick(),
				}
				table.insert(chest.contents, spawn)
			end
		end
	end

	-- Fill remaining with random
	while #chest.contents < itemCount do
		local item = LootManager.SelectRandomItem(nil, chestConfig.rarityBonus)
		if item then
			local spawn: LootSpawn = {
				id = generateLootId(),
				item = item,
				amount = LootData.GetDropAmount(item, tier),
				position = position,
				isPickedUp = false,
				spawnTime = tick(),
			}
			table.insert(chest.contents, spawn)
		end
	end

	chests[chestId] = chest

	-- Notify clients
	Events.FireAllClients("Loot", "ChestSpawned", {
		id = chestId,
		position = position,
		tier = tier,
	})

	return chest
end

--[[
	Spawn random loot at position (floor loot)
]]
function LootManager.SpawnRandomLoot(position: Vector3, tier: LootData.LootTier): LootSpawn?
	local chestConfig = LootData.ChestConfigs[tier]
	local item = LootManager.SelectRandomItem(nil, chestConfig.rarityBonus)

	if not item then return nil end

	local lootId = generateLootId()
	local spawn: LootSpawn = {
		id = lootId,
		item = item,
		amount = LootData.GetDropAmount(item, tier),
		position = position,
		isPickedUp = false,
		spawnTime = tick(),
	}

	worldLoot[lootId] = spawn

	-- Notify clients
	Events.FireAllClients("Loot", "LootSpawned", {
		id = lootId,
		itemId = item.id,
		itemName = item.displayName,
		amount = spawn.amount,
		rarity = item.rarity,
		category = item.category,
		position = position,
	})

	onLootSpawned:Fire(spawn)
	return spawn
end

--[[
	Select random item from loot pool
]]
function LootManager.SelectRandomItem(category: LootData.LootCategory?, rarityBonus: number): LootData.LootItem?
	-- Build pool of items
	local pool: { { item: LootData.LootItem, weight: number } } = {}
	local totalWeight = 0

	for _, item in pairs(LootData.Items) do
		-- Filter by category if specified
		if category and item.category ~= category then
			continue
		end

		-- Calculate weight based on rarity and item weight
		local rarityWeight = LootData.RarityWeights[item.rarity] or 10
		local adjustedRarityWeight = rarityWeight * (1 + rarityBonus * 0.1)
		local finalWeight = item.weight * (adjustedRarityWeight / 100)

		table.insert(pool, { item = item, weight = finalWeight })
		totalWeight = totalWeight + finalWeight
	end

	if totalWeight <= 0 or #pool == 0 then
		return nil
	end

	-- Random selection
	local roll = math.random() * totalWeight
	local cumulative = 0

	for _, entry in ipairs(pool) do
		cumulative = cumulative + entry.weight
		if roll <= cumulative then
			return entry.item
		end
	end

	-- Fallback to first item
	return pool[1].item
end

--[[
	Player picks up loot
]]
function LootManager.PickupLoot(player: Player, lootId: string)
	local spawn = worldLoot[lootId]
	if not spawn then return end
	if spawn.isPickedUp then return end

	-- Check distance
	local character = player.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then return end

	local distance = (rootPart.Position - spawn.position).Magnitude
	if distance > 10 then return end -- Too far

	-- Mark as picked up
	spawn.isPickedUp = true

	-- Add to player inventory (would integrate with InventoryManager)
	-- InventoryManager.AddItem(player, spawn.item.id, spawn.amount)

	-- Notify clients
	Events.FireAllClients("Loot", "LootPickedUp", {
		id = lootId,
		playerId = player.UserId,
		playerName = player.Name,
	})

	-- Notify picker
	Events.FireClient(player, "Loot", "ItemAcquired", {
		itemId = spawn.item.id,
		itemName = spawn.item.displayName,
		amount = spawn.amount,
		rarity = spawn.item.rarity,
	})

	onLootPickedUp:Fire(player, spawn)

	-- Remove from world
	worldLoot[lootId] = nil
end

--[[
	Player opens chest
]]
function LootManager.OpenChest(player: Player, chestId: string)
	local chest = chests[chestId]
	if not chest then return end
	if chest.isOpened then return end

	-- Check distance
	local character = player.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then return end

	local distance = (rootPart.Position - chest.position).Magnitude
	if distance > 8 then return end -- Too far

	-- Mark as opened
	chest.isOpened = true

	-- Spawn contents as world loot
	local contents = {}
	for i, spawn in ipairs(chest.contents) do
		local offset = Vector3.new(
			math.cos(i * 2.4) * 2,
			1,
			math.sin(i * 2.4) * 2
		)
		spawn.position = chest.position + offset
		worldLoot[spawn.id] = spawn

		table.insert(contents, {
			id = spawn.id,
			itemId = spawn.item.id,
			itemName = spawn.item.displayName,
			amount = spawn.amount,
			rarity = spawn.item.rarity,
			category = spawn.item.category,
			position = spawn.position,
		})
	end

	-- Notify clients
	Events.FireAllClients("Loot", "ChestOpened", {
		chestId = chestId,
		openedBy = player.UserId,
		contents = contents,
	})

	onChestOpened:Fire(player, chest)
	print(`[LootManager] {player.Name} opened {chest.tier} chest`)
end

--[[
	Drop item from player inventory
]]
function LootManager.DropItem(player: Player, itemId: string, amount: number)
	local item = LootData.Items[itemId]
	if not item then return end

	-- Get player position
	local character = player.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then return end

	local dropPosition = rootPart.Position + rootPart.CFrame.LookVector * 3 + Vector3.new(0, 1, 0)

	-- Create dropped loot
	local lootId = generateLootId()
	local spawn: LootSpawn = {
		id = lootId,
		item = item,
		amount = amount,
		position = dropPosition,
		isPickedUp = false,
		spawnTime = tick(),
	}

	worldLoot[lootId] = spawn

	-- Notify clients
	Events.FireAllClients("Loot", "LootDropped", {
		id = lootId,
		itemId = item.id,
		itemName = item.displayName,
		amount = amount,
		rarity = item.rarity,
		category = item.category,
		position = dropPosition,
		droppedBy = player.UserId,
	})
end

--[[
	Spawn death loot when player is eliminated
]]
function LootManager.SpawnDeathLoot(player: Player, position: Vector3, inventory: { [string]: number })
	for itemId, amount in pairs(inventory) do
		local item = LootData.Items[itemId]
		if item then
			local offset = Vector3.new(
				math.random(-3, 3),
				1,
				math.random(-3, 3)
			)

			local lootId = generateLootId()
			local spawn: LootSpawn = {
				id = lootId,
				item = item,
				amount = amount,
				position = position + offset,
				isPickedUp = false,
				spawnTime = tick(),
			}

			worldLoot[lootId] = spawn

			Events.FireAllClients("Loot", "LootSpawned", {
				id = lootId,
				itemId = item.id,
				itemName = item.displayName,
				amount = amount,
				rarity = item.rarity,
				category = item.category,
				position = spawn.position,
			})
		end
	end
end

--[[
	Spawn dinosaur loot when dino is killed
]]
function LootManager.SpawnDinoLoot(dinoType: string, tier: string, position: Vector3)
	-- Dino-specific drops
	local dinoDrops = {
		Common = { "DinoScale", "MeatBait" },
		Uncommon = { "DinoScale", "MeatBait", "Bandage" },
		Rare = { "DinoScale", "AmberShard", "MedKit" },
		Epic = { "AmberShard", "DinoHideArmor", "Stimpack" },
		Legendary = { "AmberShard", "DinoHideArmor", "Adrenaline" },
	}

	local possibleDrops = dinoDrops[tier] or dinoDrops.Common

	-- Random number of drops
	local dropCount = math.random(1, math.min(3, #possibleDrops))

	for i = 1, dropCount do
		local itemId = possibleDrops[math.random(1, #possibleDrops)]
		local item = LootData.Items[itemId]

		if item then
			local offset = Vector3.new(
				math.random(-2, 2),
				0.5,
				math.random(-2, 2)
			)

			local lootId = generateLootId()
			local amount = LootData.GetDropAmount(item, "Medium")

			local spawn: LootSpawn = {
				id = lootId,
				item = item,
				amount = amount,
				position = position + offset,
				isPickedUp = false,
				spawnTime = tick(),
			}

			worldLoot[lootId] = spawn

			Events.FireAllClients("Loot", "LootSpawned", {
				id = lootId,
				itemId = item.id,
				itemName = item.displayName,
				amount = amount,
				rarity = item.rarity,
				category = item.category,
				position = spawn.position,
			})
		end
	end
end

--[[
	Get all world loot
]]
function LootManager.GetAllLoot(): { LootSpawn }
	local result = {}
	for _, spawn in pairs(worldLoot) do
		table.insert(result, spawn)
	end
	return result
end

--[[
	Get all chests
]]
function LootManager.GetAllChests(): { Chest }
	local result = {}
	for _, chest in pairs(chests) do
		table.insert(result, chest)
	end
	return result
end

--[[
	Spawn loot from a map loot cache (called when player opens a cache)
	@param player The player who opened the cache
	@param cache The cache model with attributes (LootTier, CacheType, IsLooted)
	@param tier The loot tier ("Low", "Medium", "High")
]]
function LootManager.SpawnLootFromCache(player: Player, cache: Model, tier: string)
	-- Check if already looted
	if cache:GetAttribute("IsLooted") then
		return
	end

	-- Verify player distance
	local character = player.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then return end

	local cachePosition = cache:GetPivot().Position
	local distance = (rootPart.Position - cachePosition).Magnitude
	if distance > 12 then return end -- Too far

	-- Mark as looted
	cache:SetAttribute("IsLooted", true)

	-- Map tier string to LootData tier
	local lootTier: LootData.LootTier = "Medium"
	if tier == "High" then
		lootTier = "High"
	elseif tier == "Low" then
		lootTier = "Low"
	end

	-- Get cache type for special handling
	local cacheType = cache:GetAttribute("CacheType") or "supply_drop"

	-- Determine item count based on tier
	local itemCount = 2
	if lootTier == "High" then
		itemCount = 3
	elseif lootTier == "Low" then
		itemCount = 1
	end

	-- Determine guaranteed categories based on cache type
	local guaranteedCategories: { LootData.LootCategory }? = nil
	if cacheType == "weapon_crate" then
		guaranteedCategories = { "Weapon" }
	elseif cacheType == "ammo_box" then
		guaranteedCategories = { "Ammo" }
	elseif cacheType == "medkit" then
		guaranteedCategories = { "Medical" }
	end

	-- Spawn items around the cache
	local spawnedItems = {}
	local chestConfig = LootData.ChestConfigs[lootTier]
	local rarityBonus = chestConfig and chestConfig.rarityBonus or 0

	-- Guaranteed category first if applicable
	if guaranteedCategories then
		for _, category in ipairs(guaranteedCategories) do
			local item = LootManager.SelectRandomItem(category, rarityBonus)
			if item then
				local offset = Vector3.new(
					math.cos(#spawnedItems * 2.4) * 2,
					1,
					math.sin(#spawnedItems * 2.4) * 2
				)
				local spawn = LootManager.SpawnRandomLoot(cachePosition + offset, lootTier)
				if spawn then
					table.insert(spawnedItems, spawn)
				end
			end
		end
	end

	-- Fill remaining slots with random items
	while #spawnedItems < itemCount do
		local offset = Vector3.new(
			math.cos(#spawnedItems * 2.4) * 2,
			1,
			math.sin(#spawnedItems * 2.4) * 2
		)
		local spawn = LootManager.SpawnRandomLoot(cachePosition + offset, lootTier)
		if spawn then
			table.insert(spawnedItems, spawn)
		else
			break -- Prevent infinite loop if no items available
		end
	end

	-- Notify the player
	Events.FireClient(player, "Loot", "CacheOpened", {
		cacheType = cacheType,
		tier = tier,
		itemCount = #spawnedItems,
	})

	print(`[LootManager] {player.Name} opened {cacheType} cache, spawned {#spawnedItems} items`)
end

--[[
	Reset for new match
]]
function LootManager.Reset()
	worldLoot = {}
	chests = {}
	lootIdCounter = 0

	print("[LootManager] Reset")
end

return LootManager
