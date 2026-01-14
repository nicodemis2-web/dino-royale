--!strict
--[[
	LootSpawner.lua
	===============
	Manages loot spawning throughout the map
	Handles floor loot, chests, supply drops, and dino nests
]]

local CollectionService = game:GetService("CollectionService")

local WeaponData = require(game.ReplicatedStorage.Shared.Config.WeaponData)
local ItemData = require(game.ReplicatedStorage.Shared.Config.ItemData)

local LootSpawner = {}

--[[
	Types
]]
export type SpawnType = "FloorLoot" | "Chest" | "SupplyDrop" | "DinoNest"

export type LootItem = {
	itemType: string, -- "Weapon", "Consumable", "Ammo", "Equipment"
	itemId: string,
	rarity: string?,
	count: number,
}

export type Chest = {
	id: string,
	position: Vector3,
	model: Model?,
	isLooted: boolean,
	spawnType: SpawnType,
}

export type SupplyDrop = {
	id: string,
	position: Vector3,
	model: Model?,
	isLooted: boolean,
	contents: { LootItem },
}

-- Rarity weights by spawn type
local RARITY_WEIGHTS = {
	FloorLoot = { Common = 45, Uncommon = 30, Rare = 18, Epic = 6, Legendary = 1 },
	Chest = { Common = 30, Uncommon = 35, Rare = 25, Epic = 8, Legendary = 2 },
	SupplyDrop = { Common = 10, Uncommon = 20, Rare = 35, Epic = 25, Legendary = 10 },
	DinoNest = { Common = 0, Uncommon = 0, Rare = 50, Epic = 35, Legendary = 15 },
}

-- Item distribution by category
local LOOT_CATEGORIES = {
	Weapon = 40,
	Consumable = 25,
	Ammo = 25,
	Equipment = 10,
}

-- Reference to InventoryManager (set during initialization)
local InventoryManager: any = nil

-- Spawned chests and supply drops
local chests = {} :: { [string]: Chest }
local supplyDrops = {} :: { [string]: SupplyDrop }
local chestCounter = 0
local supplyDropCounter = 0

-- Weapon pools by rarity
local weaponPools = {} :: { [string]: { string } }

-- Consumable pool
local consumablePool = {} :: { string }

-- Equipment pool
local equipmentPool = {} :: { string }

--[[
	Initialize the loot spawner
	@param inventoryManager Reference to InventoryManager
]]
function LootSpawner.Initialize(inventoryManager: any)
	InventoryManager = inventoryManager

	-- Build weapon pools by rarity
	LootSpawner.BuildWeaponPools()

	-- Build item pools
	LootSpawner.BuildItemPools()

	-- Spawn initial loot
	LootSpawner.SpawnInitialLoot()
end

--[[
	Build weapon pools organized by rarity
]]
function LootSpawner.BuildWeaponPools()
	-- All weapons can be any rarity, so we just get all weapon IDs
	local allWeaponIds = {} :: { string }

	for weaponId, _ in pairs(WeaponData.AllWeapons) do
		table.insert(allWeaponIds, weaponId)
	end

	-- Create pools for each rarity (same weapons, different rarity applied)
	weaponPools = {
		Common = allWeaponIds,
		Uncommon = allWeaponIds,
		Rare = allWeaponIds,
		Epic = allWeaponIds,
		Legendary = allWeaponIds,
	}
end

--[[
	Build consumable and equipment pools
]]
function LootSpawner.BuildItemPools()
	-- Consumables (healing and shields)
	for itemId, itemDef in pairs(ItemData.Healing) do
		table.insert(consumablePool, itemId)
	end
	for itemId, itemDef in pairs(ItemData.Shields) do
		table.insert(consumablePool, itemId)
	end

	-- Equipment (tactical items)
	for itemId, itemDef in pairs(ItemData.Tactical) do
		table.insert(equipmentPool, itemId)
	end
end

--[[
	Spawn initial loot at all spawn points
]]
function LootSpawner.SpawnInitialLoot()
	-- Find all loot spawn points by tag
	local floorLootPoints = CollectionService:GetTagged("FloorLoot")
	local chestPoints = CollectionService:GetTagged("Chest")
	local dinoNestPoints = CollectionService:GetTagged("DinoNest")

	-- Spawn floor loot
	for _, point in ipairs(floorLootPoints) do
		if point:IsA("BasePart") then
			LootSpawner.SpawnLootAtPoint(point, "FloorLoot")
		end
	end

	-- Spawn chests
	for _, point in ipairs(chestPoints) do
		if point:IsA("BasePart") or point:IsA("Model") then
			LootSpawner.CreateChest(point)
		end
	end

	-- Spawn dino nest loot (guarded areas)
	for _, point in ipairs(dinoNestPoints) do
		if point:IsA("BasePart") then
			LootSpawner.SpawnLootAtPoint(point, "DinoNest")
		end
	end
end

--[[
	Spawn loot at a specific point
	@param point The spawn point
	@param spawnType The type of spawn
	@return Array of created world items
]]
function LootSpawner.SpawnLootAtPoint(point: BasePart, spawnType: SpawnType): { any }
	local position = point.Position
	local items = {} :: { any }

	-- Determine number of items based on spawn type
	local itemCount = 1
	if spawnType == "Chest" then
		itemCount = math.random(2, 4)
	elseif spawnType == "SupplyDrop" then
		itemCount = math.random(3, 5)
	elseif spawnType == "DinoNest" then
		itemCount = math.random(2, 3)
	end

	-- Spawn each item
	for i = 1, itemCount do
		local item = LootSpawner.GenerateLootItem(spawnType)
		if item and InventoryManager then
			-- Offset position slightly for multiple items
			local offset = Vector3.new((math.random() - 0.5) * 2, 0, (math.random() - 0.5) * 2)
			local spawnPos = position + offset

			local worldItem = InventoryManager.CreateWorldItem(item.itemType, item.itemId, spawnPos, item.rarity, item.count)
			table.insert(items, worldItem)
		end
	end

	return items
end

--[[
	Generate a random loot item based on spawn type
	@param spawnType The spawn type for rarity weights
	@return LootItem or nil
]]
function LootSpawner.GenerateLootItem(spawnType: SpawnType): LootItem?
	-- Determine item category
	local category = LootSpawner.WeightedRandom(LOOT_CATEGORIES)

	-- Determine rarity
	local rarityWeights = RARITY_WEIGHTS[spawnType] or RARITY_WEIGHTS.FloorLoot
	local rarity = LootSpawner.WeightedRandom(rarityWeights)

	if category == "Weapon" then
		return LootSpawner.GenerateWeapon(rarity)
	elseif category == "Consumable" then
		return LootSpawner.GenerateConsumable()
	elseif category == "Ammo" then
		return LootSpawner.GenerateAmmo()
	elseif category == "Equipment" then
		return LootSpawner.GenerateEquipment()
	end

	return nil
end

--[[
	Generate a random weapon
	@param rarity The weapon rarity
	@return LootItem
]]
function LootSpawner.GenerateWeapon(rarity: string): LootItem
	local pool = weaponPools[rarity] or weaponPools.Common
	local weaponId = pool[math.random(1, #pool)]

	return {
		itemType = "Weapon",
		itemId = weaponId,
		rarity = rarity,
		count = 1,
	}
end

--[[
	Generate a random consumable
	@return LootItem
]]
function LootSpawner.GenerateConsumable(): LootItem
	local itemId = consumablePool[math.random(1, #consumablePool)]
	local itemDef = ItemData.GetItem(itemId)

	-- Random count based on item type
	local count = 1
	if itemDef then
		local maxStack = itemDef.maxStack or 1
		count = math.random(1, math.min(3, maxStack))
	end

	return {
		itemType = "Consumable",
		itemId = itemId,
		rarity = nil,
		count = count,
	}
end

--[[
	Generate random ammo
	@return LootItem
]]
function LootSpawner.GenerateAmmo(): LootItem
	local ammoTypes = { "LightAmmo", "MediumAmmo", "HeavyAmmo", "Shells", "SpecialAmmo" }
	local ammoWeights = { LightAmmo = 30, MediumAmmo = 30, HeavyAmmo = 15, Shells = 20, SpecialAmmo = 5 }

	local ammoType = LootSpawner.WeightedRandom(ammoWeights)

	-- Amount based on ammo type
	local amounts = {
		LightAmmo = { 30, 60 },
		MediumAmmo = { 20, 40 },
		HeavyAmmo = { 5, 15 },
		Shells = { 5, 15 },
		SpecialAmmo = { 5, 10 },
	}

	local range = amounts[ammoType] or { 10, 20 }
	local count = math.random(range[1], range[2])

	return {
		itemType = "Ammo",
		itemId = ammoType,
		rarity = nil,
		count = count,
	}
end

--[[
	Generate random equipment
	@return LootItem
]]
function LootSpawner.GenerateEquipment(): LootItem
	local itemId = equipmentPool[math.random(1, #equipmentPool)]

	return {
		itemType = "Equipment",
		itemId = itemId,
		rarity = nil,
		count = 1,
	}
end

--[[
	Create a chest at a position
	@param point The chest location (part or model)
	@return The created chest
]]
function LootSpawner.CreateChest(point: Instance): Chest
	chestCounter = chestCounter + 1
	local id = `Chest_{chestCounter}`

	local position = Vector3.zero
	if point:IsA("BasePart") then
		position = point.Position
	elseif point:IsA("Model") then
		local primaryPart = point.PrimaryPart or point:FindFirstChildWhichIsA("BasePart")
		if primaryPart then
			position = primaryPart.Position
		end
	end

	local chest: Chest = {
		id = id,
		position = position,
		model = nil,
		isLooted = false,
		spawnType = "Chest",
	}

	-- Create or use existing model
	if point:IsA("Model") then
		chest.model = point :: Model

		-- Add interaction prompt
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Open"
		prompt.ObjectText = "Chest"
		prompt.HoldDuration = 2
		prompt.MaxActivationDistance = 6

		local attachPart = point.PrimaryPart or point:FindFirstChildWhichIsA("BasePart")
		if attachPart then
			prompt.Parent = attachPart
		end

		prompt.Triggered:Connect(function(player)
			LootSpawner.OpenChest(chest, player)
		end)
	else
		-- Create a simple chest model
		local model = Instance.new("Model")
		model.Name = id

		local part = Instance.new("Part")
		part.Name = "Base"
		part.Anchored = true
		part.Size = Vector3.new(2, 1.5, 1)
		part.Position = position
		part.Color = Color3.fromRGB(139, 90, 43)
		part.Material = Enum.Material.Wood
		part.Parent = model

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Open"
		prompt.ObjectText = "Chest"
		prompt.HoldDuration = 2
		prompt.MaxActivationDistance = 6
		prompt.Parent = part

		prompt.Triggered:Connect(function(player)
			LootSpawner.OpenChest(chest, player)
		end)

		model.PrimaryPart = part
		model.Parent = workspace

		chest.model = model
	end

	chests[id] = chest
	return chest
end

--[[
	Open a chest and spawn its contents
	@param chest The chest to open
	@param player The player opening it
]]
function LootSpawner.OpenChest(chest: Chest, player: Player)
	if chest.isLooted then
		return
	end

	chest.isLooted = true

	-- Spawn loot
	if chest.model then
		local position = chest.position
		LootSpawner.SpawnLootAtPoint(
			Instance.new("Part") :: BasePart, -- Dummy part
			"Chest"
		)

		-- Actually spawn at chest position
		local itemCount = math.random(2, 4)
		for i = 1, itemCount do
			local item = LootSpawner.GenerateLootItem("Chest")
			if item and InventoryManager then
				local offset = Vector3.new((math.random() - 0.5) * 3, 1, (math.random() - 0.5) * 3)
				local spawnPos = position + offset
				InventoryManager.CreateWorldItem(item.itemType, item.itemId, spawnPos, item.rarity, item.count)
			end
		end

		-- Play open animation/effect
		-- Change chest appearance
		local basePart = chest.model:FindFirstChild("Base") :: BasePart?
		if basePart then
			basePart.Color = Color3.fromRGB(80, 50, 30) -- Darker = opened

			-- Remove prompt
			local prompt = basePart:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt:Destroy()
			end
		end
	end
end

--[[
	Spawn a supply drop at a position
	@param position World position
	@return The created supply drop
]]
function LootSpawner.SpawnSupplyDrop(position: Vector3): SupplyDrop
	supplyDropCounter = supplyDropCounter + 1
	local id = `SupplyDrop_{supplyDropCounter}`

	-- Generate contents
	local contents = {} :: { LootItem }
	local itemCount = math.random(3, 5)
	for _ = 1, itemCount do
		local item = LootSpawner.GenerateLootItem("SupplyDrop")
		if item then
			table.insert(contents, item)
		end
	end

	local supplyDrop: SupplyDrop = {
		id = id,
		position = position,
		model = nil,
		isLooted = false,
		contents = contents,
	}

	-- Create model
	local model = Instance.new("Model")
	model.Name = id

	local crate = Instance.new("Part")
	crate.Name = "Crate"
	crate.Anchored = true
	crate.Size = Vector3.new(4, 2, 3)
	crate.Position = position + Vector3.new(0, 100, 0) -- Start high
	crate.Color = Color3.fromRGB(50, 100, 200)
	crate.Material = Enum.Material.Metal
	crate.Parent = model

	-- Add glow
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(100, 150, 255)
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.5
	highlight.Parent = model

	-- Add beam/light
	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 20
	light.Color = Color3.fromRGB(100, 150, 255)
	light.Parent = crate

	model.PrimaryPart = crate
	model.Parent = workspace

	supplyDrop.model = model

	-- Animate falling
	task.spawn(function()
		local targetY = position.Y
		local currentY = position.Y + 100

		while currentY > targetY do
			currentY = currentY - 1
			crate.Position = Vector3.new(position.X, currentY, position.Z)
			task.wait(0.02)
		end

		crate.Position = position

		-- Add prompt after landing
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Open"
		prompt.ObjectText = "Supply Drop"
		prompt.HoldDuration = 3
		prompt.MaxActivationDistance = 8
		prompt.Parent = crate

		prompt.Triggered:Connect(function(player)
			LootSpawner.OpenSupplyDrop(supplyDrop, player)
		end)
	end)

	supplyDrops[id] = supplyDrop
	return supplyDrop
end

--[[
	Open a supply drop
	@param supplyDrop The supply drop
	@param player The player opening it
]]
function LootSpawner.OpenSupplyDrop(supplyDrop: SupplyDrop, player: Player)
	if supplyDrop.isLooted then
		return
	end

	supplyDrop.isLooted = true

	-- Spawn contents
	for _, item in ipairs(supplyDrop.contents) do
		if InventoryManager then
			local offset = Vector3.new((math.random() - 0.5) * 4, 1, (math.random() - 0.5) * 4)
			local spawnPos = supplyDrop.position + offset
			InventoryManager.CreateWorldItem(item.itemType, item.itemId, spawnPos, item.rarity, item.count)
		end
	end

	-- Remove model after delay
	task.delay(5, function()
		if supplyDrop.model then
			supplyDrop.model:Destroy()
		end
	end)
end

--[[
	Weighted random selection
	@param weights Table of item -> weight
	@return Selected item
]]
function LootSpawner.WeightedRandom(weights: { [string]: number }): string
	local totalWeight = 0
	for _, weight in pairs(weights) do
		totalWeight = totalWeight + weight
	end

	local random = math.random() * totalWeight
	local cumulative = 0

	for item, weight in pairs(weights) do
		cumulative = cumulative + weight
		if random <= cumulative then
			return item
		end
	end

	-- Fallback to first item
	for item, _ in pairs(weights) do
		return item
	end

	return ""
end

--[[
	Get all active chests
	@return Table of chests
]]
function LootSpawner.GetChests(): { [string]: Chest }
	return chests
end

--[[
	Get all active supply drops
	@return Table of supply drops
]]
function LootSpawner.GetSupplyDrops(): { [string]: SupplyDrop }
	return supplyDrops
end

return LootSpawner
