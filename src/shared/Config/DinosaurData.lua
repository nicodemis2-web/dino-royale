--!strict
--[[
	DinosaurData.lua
	================
	Complete dinosaur definitions for Dino Royale
	Includes stats, behaviors, abilities, and loot tables
]]

local Types = require(script.Parent.Parent.Types)

export type DinosaurDefinition = {
	name: string,
	tier: Types.DinosaurTier,
	health: number,
	damage: number,
	speed: number,
	detectionRange: number,
	behavior: string,
	packSize: { number }?,
	special: (string | { string })?,
	spitRange: number?,
	territorySize: number?,
	armorReduction: number?,
}

export type LootTableEntry = {
	itemType: string,
	chance: number,
	countMin: number,
	countMax: number,
}

local DinosaurData = {}

--[[
	COMMON TIER
	Low threat, common spawns, basic loot
]]
DinosaurData.Common = {
	Compsognathus = {
		name = "Compsognathus",
		tier = "Common" :: Types.DinosaurTier,
		health = 20,
		damage = 5,
		speed = 20,
		detectionRange = 15,
		behavior = "Swarm",
		packSize = { 5, 10 },
	},
	Gallimimus = {
		name = "Gallimimus",
		tier = "Common" :: Types.DinosaurTier,
		health = 50,
		damage = 10,
		speed = 35,
		detectionRange = 40,
		behavior = "Flee",
		packSize = { 3, 6 },
	},
}

--[[
	UNCOMMON TIER
	Moderate threat, territorial behaviors
]]
DinosaurData.Uncommon = {
	Dilophosaurus = {
		name = "Dilophosaurus",
		tier = "Uncommon" :: Types.DinosaurTier,
		health = 80,
		damage = 15,
		speed = 18,
		detectionRange = 25,
		behavior = "Territorial",
		special = "VenomSpit",
		spitRange = 15,
	},
	Triceratops = {
		name = "Triceratops",
		tier = "Uncommon" :: Types.DinosaurTier,
		health = 300,
		damage = 40,
		speed = 22,
		detectionRange = 20,
		behavior = "Territorial",
		special = "Charge",
	},
}

--[[
	RARE TIER
	High threat, advanced behaviors
]]
DinosaurData.Rare = {
	Velociraptor = {
		name = "Velociraptor",
		tier = "Rare" :: Types.DinosaurTier,
		health = 100,
		damage = 30,
		speed = 28,
		detectionRange = 50,
		behavior = "PackHunter",
		packSize = { 3, 5 },
		special = "Flank",
	},
	Baryonyx = {
		name = "Baryonyx",
		tier = "Rare" :: Types.DinosaurTier,
		health = 200,
		damage = 35,
		speed = 20,
		detectionRange = 40,
		behavior = "Ambush",
		special = "WaterSpeed",
	},
	Pteranodon = {
		name = "Pteranodon",
		tier = "Rare" :: Types.DinosaurTier,
		health = 80,
		damage = 25,
		speed = 40,
		detectionRange = 60,
		behavior = "Swoop",
		special = "Flight",
	},
	Dimorphodon = {
		name = "Dimorphodon",
		tier = "Rare" :: Types.DinosaurTier,
		health = 40,
		damage = 15,
		speed = 35,
		detectionRange = 45,
		behavior = "Swarm",
		packSize = { 4, 8 },
		special = "Flight",
	},
}

--[[
	EPIC TIER
	Major threat, powerful abilities
]]
DinosaurData.Epic = {
	Carnotaurus = {
		name = "Carnotaurus",
		tier = "Epic" :: Types.DinosaurTier,
		health = 400,
		damage = 60,
		speed = 32,
		detectionRange = 70,
		behavior = "Pursuit",
		special = "BreakCover",
	},
	Spinosaurus = {
		name = "Spinosaurus",
		tier = "Epic" :: Types.DinosaurTier,
		health = 500,
		damage = 70,
		speed = 18,
		detectionRange = 50,
		behavior = "Territorial",
		special = "Aquatic",
		territorySize = 100,
	},
	Mosasaurus = {
		name = "Mosasaurus",
		tier = "Epic" :: Types.DinosaurTier,
		health = 800,
		damage = 90,
		speed = 30, -- Fast in water
		detectionRange = 80,
		behavior = "Ambush",
		special = { "Aquatic", "DeepDive", "SurfaceStrike" },
		territorySize = 150,
	},
}

--[[
	LEGENDARY TIER (BOSSES)
	Maximum threat, multiple abilities, guaranteed high-tier loot
]]
DinosaurData.Legendary = {
	TRex = {
		name = "Tyrannosaurus Rex",
		tier = "Legendary" :: Types.DinosaurTier,
		health = 2000,
		damage = 100,
		speed = 25,
		detectionRange = 100,
		behavior = "Apex",
		special = { "Stomp", "TailSwipe", "Roar", "SmellWounded" },
		armorReduction = 0.3,
	},
	Indoraptor = {
		name = "Indoraptor",
		tier = "Legendary" :: Types.DinosaurTier,
		health = 1500,
		damage = 80,
		speed = 30,
		detectionRange = 80,
		behavior = "Stalker",
		special = { "OpenDoors", "Echolocation", "NightVision" },
	},
}

--[[
	LOOT TABLES
	Defines what each tier of dinosaur drops on death
]]
DinosaurData.LootTables = {
	Common = {
		{ itemType = "Bandage", chance = 0.5, countMin = 1, countMax = 3 },
		{ itemType = "LightAmmo", chance = 0.6, countMin = 15, countMax = 30 },
		{ itemType = "MediumAmmo", chance = 0.3, countMin = 10, countMax = 20 },
	},
	Uncommon = {
		{ itemType = "Bandage", chance = 0.6, countMin = 2, countMax = 5 },
		{ itemType = "MedKit", chance = 0.2, countMin = 1, countMax = 1 },
		{ itemType = "ShieldSerum", chance = 0.3, countMin = 1, countMax = 2 },
		{ itemType = "MediumAmmo", chance = 0.5, countMin = 20, countMax = 40 },
		{ itemType = "Shells", chance = 0.3, countMin = 5, countMax = 10 },
	},
	Rare = {
		{ itemType = "MedKit", chance = 0.5, countMin = 1, countMax = 2 },
		{ itemType = "ShieldSerum", chance = 0.5, countMin = 1, countMax = 3 },
		{ itemType = "MegaSerum", chance = 0.2, countMin = 1, countMax = 1 },
		{ itemType = "FragGrenade", chance = 0.3, countMin = 1, countMax = 2 },
		{ itemType = "HeavyAmmo", chance = 0.4, countMin = 5, countMax = 15 },
		{ itemType = "RareWeapon", chance = 0.3, countMin = 1, countMax = 1 },
	},
	Epic = {
		{ itemType = "MedKit", chance = 0.7, countMin = 1, countMax = 2 },
		{ itemType = "MegaSerum", chance = 0.5, countMin = 1, countMax = 2 },
		{ itemType = "SlurpCanteen", chance = 0.2, countMin = 1, countMax = 1 },
		{ itemType = "FragGrenade", chance = 0.5, countMin = 2, countMax = 4 },
		{ itemType = "GrappleHook", chance = 0.3, countMin = 1, countMax = 1 },
		{ itemType = "EpicWeapon", chance = 0.5, countMin = 1, countMax = 1 },
	},
	Legendary = {
		{ itemType = "DinoAdrenaline", chance = 1.0, countMin = 1, countMax = 2 },
		{ itemType = "SlurpCanteen", chance = 0.8, countMin = 1, countMax = 2 },
		{ itemType = "LegendaryWeapon", chance = 1.0, countMin = 2, countMax = 3 },
		{ itemType = "GrappleHook", chance = 0.7, countMin = 1, countMax = 1 },
		{ itemType = "MotionSensor", chance = 0.5, countMin = 2, countMax = 3 },
	},
}

--[[
	SPAWN WEIGHTS
	Probability weights for spawning each species in different biomes
	Higher number = more likely to spawn in that biome
]]
DinosaurData.SpawnWeights = {
	Jungle = {
		Compsognathus = 10,
		Gallimimus = 5,
		Dilophosaurus = 8,
		Velociraptor = 6,
		Carnotaurus = 2,
	},
	Plains = {
		Gallimimus = 10,
		Triceratops = 8,
		Velociraptor = 4,
		Carnotaurus = 3,
		TRex = 1,
	},
	Swamp = {
		Compsognathus = 8,
		Dilophosaurus = 10,
		Baryonyx = 8,
		Spinosaurus = 3,
	},
	Coast = {
		Gallimimus = 6,
		Pteranodon = 10,
		Baryonyx = 5,
	},
	Volcanic = {
		Carnotaurus = 8,
		TRex = 2,
		Velociraptor = 5,
	},
	Research = {
		Velociraptor = 8,
		Indoraptor = 1,
		Dilophosaurus = 4,
	},
}

--[[
	TIER SPAWN RATES
	Base probability for spawning each tier
]]
DinosaurData.TierSpawnRates = {
	Common = 0.40,
	Uncommon = 0.30,
	Rare = 0.20,
	Epic = 0.08,
	Legendary = 0.02,
}

-- Lookup table for all dinosaurs by ID
DinosaurData.AllDinosaurs = {} :: { [string]: DinosaurDefinition }

-- Lookup table for species names by tier (for DinosaurManager.selectRandomSpecies)
DinosaurData.ByTier = {} :: { [string]: { string } }

-- Populate AllDinosaurs and ByTier lookups
for _, tier in pairs({ "Common", "Uncommon", "Rare", "Epic", "Legendary" }) do
	DinosaurData.ByTier[tier] = {}
	for dinoId, dinoDef in pairs(DinosaurData[tier]) do
		DinosaurData.AllDinosaurs[dinoId] = dinoDef
		table.insert(DinosaurData.ByTier[tier], dinoId)
	end
end

-- Get dinosaur definition by ID
function DinosaurData.GetDinosaur(dinoId: string): DinosaurDefinition?
	return DinosaurData.AllDinosaurs[dinoId]
end

-- Get all dinosaurs of a specific tier
function DinosaurData.GetDinosaursByTier(tier: Types.DinosaurTier): { [string]: DinosaurDefinition }
	return DinosaurData[tier] or {}
end

-- Get loot table for a tier
function DinosaurData.GetLootTable(tier: Types.DinosaurTier): { LootTableEntry }
	return DinosaurData.LootTables[tier] or {}
end

-- Get spawn weights for a biome
function DinosaurData.GetSpawnWeightsForBiome(biome: string): { [string]: number }
	return DinosaurData.SpawnWeights[biome] or {}
end

-- Check if dinosaur has a specific ability
function DinosaurData.HasAbility(dinoId: string, ability: string): boolean
	local dino = DinosaurData.AllDinosaurs[dinoId]
	if not dino or not dino.special then
		return false
	end

	if type(dino.special) == "string" then
		return dino.special == ability
	elseif type(dino.special) == "table" then
		for _, abil in ipairs(dino.special :: { string }) do
			if abil == ability then
				return true
			end
		end
	end

	return false
end

return DinosaurData
