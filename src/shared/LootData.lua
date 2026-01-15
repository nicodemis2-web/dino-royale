--!strict
--[[
	LootData.lua
	============
	Loot tables and drop rates for Dino Royale.
	Based on Game Design Document Section 6: Items & Loot

	LOOT SYSTEM OVERVIEW:
	The loot system uses weighted random selection:
	1. Each item has a "weight" value (higher = more common)
	2. Rarity also has weights that modify selection
	3. Chest tier provides bonus to rarity rolls

	RARITY DISTRIBUTION:
	Base weights (before chest tier bonus):
	- Common: 100 (56% chance)
	- Uncommon: 50 (28% chance)
	- Rare: 20 (11% chance)
	- Epic: 5 (3% chance)
	- Legendary: 1 (0.5% chance)

	CHEST TIERS:
	- Low: Floor loot, basic supplies (1-2 items)
	- Medium: Standard chests (2-4 items, guaranteed weapon)
	- High: POI chests (3-5 items, guaranteed weapon + healing)
	- VeryHigh: Hot drop chests (4-6 items, +2 rarity bonus)
	- Legendary: Supply drops (5-8 items, +5 rarity bonus)

	DROP AMOUNTS:
	Stackable items drop in quantities based on tier:
	- Ammo: 30 rounds per cache (standardized)
	- Healing: 1-2 items per drop
	- Materials: 10-150 based on tier

	USAGE:
	```lua
	local LootData = require(path.to.LootData)
	local items = LootData.GetItemsByCategory("Weapon")
	local amount = LootData.GetDropAmount(item, "High")
	```

	@shared
]]

--------------------------------------------------------------------------------
-- TYPE DEFINITIONS
--------------------------------------------------------------------------------

--[[
	Rarity: Item quality tier affecting stats and visual appearance
	Colors defined in RarityColors table for UI consistency
]]
export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"

--[[
	LootCategory: Item classification for filtering and guaranteed drops
]]
export type LootCategory = "Weapon" | "Ammo" | "Equipment" | "Healing" | "Armor" | "Material"

--[[
	LootItem: Definition of a lootable item
	- weight: Relative spawn chance (100 = common, 1 = extremely rare)
	- stackable: Whether multiple can occupy one inventory slot
	- maxStack: Maximum count per stack
]]
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

--[[
	LootTier: Chest quality level affecting contents
]]
export type LootTier = "Low" | "Medium" | "High" | "VeryHigh" | "Legendary"

--[[
	ChestConfig: Configuration for a chest spawn
	- guaranteedCategories: These categories will always have at least one drop
	- rarityBonus: Added to rarity roll (higher = better items)
]]
export type ChestConfig = {
	tier: LootTier,
	minItems: number,
	maxItems: number,
	guaranteedCategories: { LootCategory }?,
	rarityBonus: number, -- Increases chance of higher rarity
}

--------------------------------------------------------------------------------
-- MODULE DECLARATION
--------------------------------------------------------------------------------

local LootData = {}

-- Rarity colors for UI
LootData.RarityColors = {
	Common = Color3.fromRGB(180, 180, 180),
	Uncommon = Color3.fromRGB(100, 200, 100),
	Rare = Color3.fromRGB(80, 150, 255),
	Epic = Color3.fromRGB(200, 80, 255),
	Legendary = Color3.fromRGB(255, 180, 0),
}

-- Rarity drop weights (base chances)
LootData.RarityWeights = {
	Common = 100,
	Uncommon = 50,
	Rare = 20,
	Epic = 5,
	Legendary = 1,
}

-- All loot items
-- Note: Weapon IDs must match WeaponData.lua definitions
LootData.Items = {
	-- PISTOLS (from WeaponData.Pistols)
	RangerSidearm = { id = "RangerSidearm", name = "RangerSidearm", displayName = "Ranger Sidearm", category = "Weapon", rarity = "Common", stackable = false, maxStack = 1, weight = 100 },
	SurvivorsFriend = { id = "SurvivorsFriend", name = "SurvivorsFriend", displayName = "Survivor's Friend", category = "Weapon", rarity = "Uncommon", stackable = false, maxStack = 1, weight = 60 },
	DesertClaw = { id = "DesertClaw", name = "DesertClaw", displayName = "Desert Claw", category = "Weapon", rarity = "Rare", stackable = false, maxStack = 1, weight = 30 },

	-- SMGS (from WeaponData.SMGs)
	RaptorSMG = { id = "RaptorSMG", name = "RaptorSMG", displayName = "Raptor SMG", category = "Weapon", rarity = "Common", stackable = false, maxStack = 1, weight = 80 },
	JungleSprayer = { id = "JungleSprayer", name = "JungleSprayer", displayName = "Jungle Sprayer", category = "Weapon", rarity = "Uncommon", stackable = false, maxStack = 1, weight = 50 },
	CompactSurvivor = { id = "CompactSurvivor", name = "CompactSurvivor", displayName = "Compact Survivor", category = "Weapon", rarity = "Rare", stackable = false, maxStack = 1, weight = 25 },

	-- ASSAULT RIFLES (from WeaponData.AssaultRifles)
	RangerAR = { id = "RangerAR", name = "RangerAR", displayName = "Ranger AR", category = "Weapon", rarity = "Uncommon", stackable = false, maxStack = 1, weight = 60 },
	ExpeditionRifle = { id = "ExpeditionRifle", name = "ExpeditionRifle", displayName = "Expedition Rifle", category = "Weapon", rarity = "Rare", stackable = false, maxStack = 1, weight = 35 },
	PredatorCarbine = { id = "PredatorCarbine", name = "PredatorCarbine", displayName = "Predator Carbine", category = "Weapon", rarity = "Epic", stackable = false, maxStack = 1, weight = 15 },

	-- SHOTGUNS (from WeaponData.Shotguns)
	RexBlaster = { id = "RexBlaster", name = "RexBlaster", displayName = "Rex Blaster", category = "Weapon", rarity = "Uncommon", stackable = false, maxStack = 1, weight = 50 },
	SafariPump = { id = "SafariPump", name = "SafariPump", displayName = "Safari Pump", category = "Weapon", rarity = "Rare", stackable = false, maxStack = 1, weight = 30 },
	DinoDeva = { id = "DinoDeva", name = "DinoDeva", displayName = "Dino Devastator", category = "Weapon", rarity = "Epic", stackable = false, maxStack = 1, weight = 10 },

	-- SNIPERS (from WeaponData.Snipers)
	TranqRifle = { id = "TranqRifle", name = "TranqRifle", displayName = "Tranq Rifle", category = "Weapon", rarity = "Rare", stackable = false, maxStack = 1, weight = 25 },
	SpottersChoice = { id = "SpottersChoice", name = "SpottersChoice", displayName = "Spotter's Choice", category = "Weapon", rarity = "Epic", stackable = false, maxStack = 1, weight = 12 },
	ApexHunter = { id = "ApexHunter", name = "ApexHunter", displayName = "Apex Hunter", category = "Weapon", rarity = "Legendary", stackable = false, maxStack = 1, weight = 5 },

	-- DMRs (from WeaponData.DMRs)
	ScoutMarksman = { id = "ScoutMarksman", name = "ScoutMarksman", displayName = "Scout Marksman", category = "Weapon", rarity = "Uncommon", stackable = false, maxStack = 1, weight = 40 },
	ParkWarden = { id = "ParkWarden", name = "ParkWarden", displayName = "Park Warden", category = "Weapon", rarity = "Rare", stackable = false, maxStack = 1, weight = 20 },
	PrecisionRanger = { id = "PrecisionRanger", name = "PrecisionRanger", displayName = "Precision Ranger", category = "Weapon", rarity = "Epic", stackable = false, maxStack = 1, weight = 8 },

	-- SPECIAL WEAPONS (from WeaponData.Special)
	TranqDartGun = { id = "TranqDartGun", name = "TranqDartGun", displayName = "Tranq Dart Gun", category = "Weapon", rarity = "Epic", stackable = false, maxStack = 1, weight = 12 },
	Flamethrower = { id = "Flamethrower", name = "Flamethrower", displayName = "Flamethrower", category = "Weapon", rarity = "Legendary", stackable = false, maxStack = 1, weight = 2 },

	-- AMMO (30 rounds per cache drop, 300 max capacity for light/medium)
	LightAmmo = { id = "LightAmmo", name = "LightAmmo", displayName = "Light Ammo", category = "Ammo", rarity = "Common", stackable = true, maxStack = 300, weight = 100 },
	MediumAmmo = { id = "MediumAmmo", name = "MediumAmmo", displayName = "Medium Ammo", category = "Ammo", rarity = "Common", stackable = true, maxStack = 300, weight = 80 },
	HeavyAmmo = { id = "HeavyAmmo", name = "HeavyAmmo", displayName = "Heavy Ammo", category = "Ammo", rarity = "Common", stackable = true, maxStack = 60, weight = 60 },
	ShotgunShells = { id = "ShotgunShells", name = "ShotgunShells", displayName = "Shotgun Shells", category = "Ammo", rarity = "Common", stackable = true, maxStack = 60, weight = 50 },
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
LootData.ChestConfigs = {
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
LootData.FloorLootWeights = {
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
		-- Ammo drops are standardized to 30 rounds per cache
		Ammo = { Low = { 30, 30 }, Medium = { 30, 30 }, High = { 30, 30 }, VeryHigh = { 30, 30 }, Legendary = { 30, 60 } },
		Healing = { Low = { 1, 1 }, Medium = { 1, 1 }, High = { 1, 2 }, VeryHigh = { 1, 2 }, Legendary = { 2, 2 } },
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
