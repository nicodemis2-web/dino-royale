--!strict
--[[
	LootData.lua
	============
	Loot tables and drop rates for Dino Royale
	Based on GDD Section 6: Items & Loot
]]

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"

export type LootCategory = "Weapon" | "Ammo" | "Equipment" | "Healing" | "Armor" | "Material"

export type LootItem = {
	id: string,
	name: string,
	displayName: string,
	category: LootCategory,
	rarity: Rarity,
	stackable: boolean,
	maxStack: number,
	weight: number, -- Higher = more common in loot pools
}

export type LootTier = "Low" | "Medium" | "High" | "VeryHigh" | "Legendary"

export type ChestConfig = {
	tier: LootTier,
	minItems: number,
	maxItems: number,
	guaranteedCategories: { LootCategory }?,
	rarityBonus: number, -- Increases chance of higher rarity
}

local LootData = {}

-- Rarity colors for UI
LootData.RarityColors: { [Rarity]: Color3 } = {
	Common = Color3.fromRGB(180, 180, 180),
	Uncommon = Color3.fromRGB(100, 200, 100),
	Rare = Color3.fromRGB(80, 150, 255),
	Epic = Color3.fromRGB(200, 80, 255),
	Legendary = Color3.fromRGB(255, 180, 0),
}

-- Rarity drop weights (base chances)
LootData.RarityWeights: { [Rarity]: number } = {
	Common = 100,
	Uncommon = 50,
	Rare = 20,
	Epic = 5,
	Legendary = 1,
}

-- All loot items
LootData.Items: { [string]: LootItem } = {
	-- WEAPONS (from WeaponData)
	Pistol = { id = "Pistol", name = "Pistol", displayName = "9mm Pistol", category = "Weapon", rarity = "Common", stackable = false, maxStack = 1, weight = 100 },
	SMG = { id = "SMG", name = "SMG", displayName = "SMG", category = "Weapon", rarity = "Common", stackable = false, maxStack = 1, weight = 80 },
	AssaultRifle = { id = "AssaultRifle", name = "AssaultRifle", displayName = "Assault Rifle", category = "Weapon", rarity = "Uncommon", stackable = false, maxStack = 1, weight = 60 },
	Shotgun = { id = "Shotgun", name = "Shotgun", displayName = "Pump Shotgun", category = "Weapon", rarity = "Uncommon", stackable = false, maxStack = 1, weight = 50 },
	SniperRifle = { id = "SniperRifle", name = "SniperRifle", displayName = "Sniper Rifle", category = "Weapon", rarity = "Rare", stackable = false, maxStack = 1, weight = 30 },
	LMG = { id = "LMG", name = "LMG", displayName = "Light Machine Gun", category = "Weapon", rarity = "Rare", stackable = false, maxStack = 1, weight = 25 },
	RocketLauncher = { id = "RocketLauncher", name = "RocketLauncher", displayName = "Rocket Launcher", category = "Weapon", rarity = "Epic", stackable = false, maxStack = 1, weight = 10 },

	-- Special Weapons
	ElectroNetGun = { id = "ElectroNetGun", name = "ElectroNetGun", displayName = "Electro Net Gun", category = "Weapon", rarity = "Epic", stackable = false, maxStack = 1, weight = 8 },
	DinoCall = { id = "DinoCall", name = "DinoCall", displayName = "Dino Call", category = "Weapon", rarity = "Rare", stackable = false, maxStack = 1, weight = 20 },
	AmberLauncher = { id = "AmberLauncher", name = "AmberLauncher", displayName = "Amber Launcher", category = "Weapon", rarity = "Legendary", stackable = false, maxStack = 1, weight = 3 },
	TranquilizerGun = { id = "TranquilizerGun", name = "TranquilizerGun", displayName = "Tranquilizer Gun", category = "Weapon", rarity = "Epic", stackable = false, maxStack = 1, weight = 12 },
	Flamethrower = { id = "Flamethrower", name = "Flamethrower", displayName = "Flamethrower", category = "Weapon", rarity = "Legendary", stackable = false, maxStack = 1, weight = 2 },

	-- AMMO
	LightAmmo = { id = "LightAmmo", name = "LightAmmo", displayName = "Light Ammo", category = "Ammo", rarity = "Common", stackable = true, maxStack = 999, weight = 100 },
	MediumAmmo = { id = "MediumAmmo", name = "MediumAmmo", displayName = "Medium Ammo", category = "Ammo", rarity = "Common", stackable = true, maxStack = 999, weight = 80 },
	HeavyAmmo = { id = "HeavyAmmo", name = "HeavyAmmo", displayName = "Heavy Ammo", category = "Ammo", rarity = "Common", stackable = true, maxStack = 999, weight = 60 },
	ShotgunShells = { id = "ShotgunShells", name = "ShotgunShells", displayName = "Shotgun Shells", category = "Ammo", rarity = "Common", stackable = true, maxStack = 999, weight = 50 },
	Rockets = { id = "Rockets", name = "Rockets", displayName = "Rockets", category = "Ammo", rarity = "Rare", stackable = true, maxStack = 20, weight = 15 },
	FuelCanister = { id = "FuelCanister", name = "FuelCanister", displayName = "Fuel Canister", category = "Ammo", rarity = "Uncommon", stackable = true, maxStack = 100, weight = 30 },

	-- EQUIPMENT (from EquipmentData)
	FragGrenade = { id = "FragGrenade", name = "FragGrenade", displayName = "Frag Grenade", category = "Equipment", rarity = "Uncommon", stackable = true, maxStack = 6, weight = 40 },
	SmokeBomb = { id = "SmokeBomb", name = "SmokeBomb", displayName = "Smoke Bomb", category = "Equipment", rarity = "Common", stackable = true, maxStack = 4, weight = 60 },
	Flashbang = { id = "Flashbang", name = "Flashbang", displayName = "Flashbang", category = "Equipment", rarity = "Uncommon", stackable = true, maxStack = 4, weight = 35 },
	GrappleHook = { id = "GrappleHook", name = "GrappleHook", displayName = "Grapple Hook", category = "Equipment", rarity = "Rare", stackable = true, maxStack = 3, weight = 20 },
	MotionSensor = { id = "MotionSensor", name = "MotionSensor", displayName = "Motion Sensor", category = "Equipment", rarity = "Rare", stackable = true, maxStack = 2, weight = 18 },
	DinoRepellent = { id = "DinoRepellent", name = "DinoRepellent", displayName = "Dino Repellent", category = "Equipment", rarity = "Uncommon", stackable = true, maxStack = 2, weight = 30 },
	MeatBait = { id = "MeatBait", name = "MeatBait", displayName = "Meat Bait", category = "Equipment", rarity = "Common", stackable = true, maxStack = 4, weight = 50 },
	Flare = { id = "Flare", name = "Flare", displayName = "Flare", category = "Equipment", rarity = "Common", stackable = true, maxStack = 6, weight = 70 },

	-- HEALING
	Bandage = { id = "Bandage", name = "Bandage", displayName = "Bandage", category = "Healing", rarity = "Common", stackable = true, maxStack = 15, weight = 100 },
	MedKit = { id = "MedKit", name = "MedKit", displayName = "Med Kit", category = "Healing", rarity = "Uncommon", stackable = true, maxStack = 5, weight = 40 },
	Stimpack = { id = "Stimpack", name = "Stimpack", displayName = "Stimpack", category = "Healing", rarity = "Rare", stackable = true, maxStack = 3, weight = 20 },
	Adrenaline = { id = "Adrenaline", name = "Adrenaline", displayName = "Adrenaline Shot", category = "Healing", rarity = "Epic", stackable = true, maxStack = 2, weight = 8 },

	-- ARMOR
	LightArmor = { id = "LightArmor", name = "LightArmor", displayName = "Light Armor", category = "Armor", rarity = "Common", stackable = false, maxStack = 1, weight = 60 },
	MediumArmor = { id = "MediumArmor", name = "MediumArmor", displayName = "Medium Armor", category = "Armor", rarity = "Uncommon", stackable = false, maxStack = 1, weight = 35 },
	HeavyArmor = { id = "HeavyArmor", name = "HeavyArmor", displayName = "Heavy Armor", category = "Armor", rarity = "Rare", stackable = false, maxStack = 1, weight = 15 },
	DinoHideArmor = { id = "DinoHideArmor", name = "DinoHideArmor", displayName = "Dino Hide Armor", category = "Armor", rarity = "Epic", stackable = false, maxStack = 1, weight = 5 },

	-- MATERIALS
	ScrapMetal = { id = "ScrapMetal", name = "ScrapMetal", displayName = "Scrap Metal", category = "Material", rarity = "Common", stackable = true, maxStack = 200, weight = 80 },
	AmberShard = { id = "AmberShard", name = "AmberShard", displayName = "Amber Shard", category = "Material", rarity = "Rare", stackable = true, maxStack = 50, weight = 15 },
	DinoScale = { id = "DinoScale", name = "DinoScale", displayName = "Dinosaur Scale", category = "Material", rarity = "Uncommon", stackable = true, maxStack = 100, weight = 25 },
}

-- Chest configurations by tier
LootData.ChestConfigs: { [LootTier]: ChestConfig } = {
	Low = {
		tier = "Low",
		minItems = 1,
		maxItems = 2,
		rarityBonus = 0,
	},
	Medium = {
		tier = "Medium",
		minItems = 2,
		maxItems = 4,
		guaranteedCategories = { "Weapon" },
		rarityBonus = 0.5,
	},
	High = {
		tier = "High",
		minItems = 3,
		maxItems = 5,
		guaranteedCategories = { "Weapon", "Healing" },
		rarityBonus = 1.0,
	},
	VeryHigh = {
		tier = "VeryHigh",
		minItems = 4,
		maxItems = 6,
		guaranteedCategories = { "Weapon", "Healing", "Equipment" },
		rarityBonus = 2.0,
	},
	Legendary = {
		tier = "Legendary",
		minItems = 5,
		maxItems = 8,
		guaranteedCategories = { "Weapon", "Weapon", "Healing", "Equipment" },
		rarityBonus = 5.0,
	},
}

-- Floor loot spawn rates by category
LootData.FloorLootWeights: { [LootCategory]: number } = {
	Weapon = 20,
	Ammo = 40,
	Equipment = 15,
	Healing = 20,
	Armor = 3,
	Material = 10,
}

-- Get items by category
function LootData.GetItemsByCategory(category: LootCategory): { LootItem }
	local result = {}
	for _, item in pairs(LootData.Items) do
		if item.category == category then
			table.insert(result, item)
		end
	end
	return result
end

-- Get items by rarity
function LootData.GetItemsByRarity(rarity: Rarity): { LootItem }
	local result = {}
	for _, item in pairs(LootData.Items) do
		if item.rarity == rarity then
			table.insert(result, item)
		end
	end
	return result
end

-- Get rarity color
function LootData.GetRarityColor(rarity: Rarity): Color3
	return LootData.RarityColors[rarity] or Color3.fromRGB(200, 200, 200)
end

-- Calculate drop amount for stackable items
function LootData.GetDropAmount(item: LootItem, tier: LootTier): number
	if not item.stackable then
		return 1
	end

	local baseAmounts = {
		Ammo = { Low = { 10, 20 }, Medium = { 20, 40 }, High = { 30, 60 }, VeryHigh = { 50, 80 }, Legendary = { 80, 120 } },
		Healing = { Low = { 1, 2 }, Medium = { 2, 3 }, High = { 2, 4 }, VeryHigh = { 3, 5 }, Legendary = { 4, 6 } },
		Equipment = { Low = { 1, 1 }, Medium = { 1, 2 }, High = { 1, 2 }, VeryHigh = { 2, 3 }, Legendary = { 2, 4 } },
		Material = { Low = { 10, 25 }, Medium = { 20, 50 }, High = { 40, 80 }, VeryHigh = { 60, 100 }, Legendary = { 80, 150 } },
	}

	local categoryAmounts = baseAmounts[item.category]
	if categoryAmounts then
		local tierRange = categoryAmounts[tier]
		if tierRange then
			return math.random(tierRange[1], tierRange[2])
		end
	end

	return 1
end

return LootData
