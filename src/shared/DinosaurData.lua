--!strict
--[[
	DinosaurData.lua
	================
	Complete dinosaur roster data for Dino Royale
	Based on GDD Section 5: Dinosaur System
]]

export type DinosaurTier = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"

export type DinosaurStats = {
	name: string,
	displayName: string,
	tier: DinosaurTier,

	-- Health
	maxHealth: number,

	-- Combat
	damage: number,
	attackRange: number,
	attackCooldown: number,

	-- Movement
	walkSpeed: number,
	runSpeed: number,

	-- Detection
	visionRange: number,
	visionAngle: number,
	hearingRange: number,

	-- Behavior
	aggroRange: number,
	territoryRadius: number,
	fleeHealthPercent: number,

	-- Loot
	lootDropChance: number,
	xpReward: number,

	-- Special abilities
	abilities: { string }?,

	-- Biome preference
	preferredBiomes: { string },
}

local DinosaurData = {}

DinosaurData.Dinosaurs: { [string]: DinosaurStats } = {
	-- COMMON TIER
	Compsognathus = {
		name = "Compsognathus",
		displayName = "Compsognathus",
		tier = "Common",
		maxHealth = 25,
		damage = 5,
		attackRange = 2,
		attackCooldown = 0.5,
		walkSpeed = 12,
		runSpeed = 20,
		visionRange = 30,
		visionAngle = 160,
		hearingRange = 20,
		aggroRange = 15,
		territoryRadius = 30,
		fleeHealthPercent = 0.5,
		lootDropChance = 0.3,
		xpReward = 10,
		abilities = { "Swarm", "ScavengeCorpses" },
		preferredBiomes = { "Jungle", "Research" },
	},

	Gallimimus = {
		name = "Gallimimus",
		displayName = "Gallimimus",
		tier = "Common",
		maxHealth = 80,
		damage = 10,
		attackRange = 3,
		attackCooldown = 1.0,
		walkSpeed = 18,
		runSpeed = 35,
		visionRange = 60,
		visionAngle = 180,
		hearingRange = 50,
		aggroRange = 10,
		territoryRadius = 100,
		fleeHealthPercent = 0.8,
		lootDropChance = 0.3,
		xpReward = 10,
		abilities = { "Stampede", "FlockBehavior" },
		preferredBiomes = { "Plains" },
	},

	-- UNCOMMON TIER
	Dilophosaurus = {
		name = "Dilophosaurus",
		displayName = "Dilophosaurus",
		tier = "Uncommon",
		maxHealth = 150,
		damage = 15,
		attackRange = 5,
		attackCooldown = 1.2,
		walkSpeed = 14,
		runSpeed = 24,
		visionRange = 50,
		visionAngle = 140,
		hearingRange = 40,
		aggroRange = 30,
		territoryRadius = 60,
		fleeHealthPercent = 0.3,
		lootDropChance = 0.5,
		xpReward = 15,
		abilities = { "VenomSpit", "BlindingAttack" },
		preferredBiomes = { "Jungle", "Swamp" },
	},

	Triceratops = {
		name = "Triceratops",
		displayName = "Triceratops",
		tier = "Uncommon",
		maxHealth = 500,
		damage = 40,
		attackRange = 6,
		attackCooldown = 2.0,
		walkSpeed = 10,
		runSpeed = 22,
		visionRange = 40,
		visionAngle = 120,
		hearingRange = 35,
		aggroRange = 20,
		territoryRadius = 80,
		fleeHealthPercent = 0.2,
		lootDropChance = 0.5,
		xpReward = 15,
		abilities = { "ChargeAttack", "HerdDefense" },
		preferredBiomes = { "Plains" },
	},

	-- RARE TIER
	Velociraptor = {
		name = "Velociraptor",
		displayName = "Velociraptor",
		tier = "Rare",
		maxHealth = 200,
		damage = 30,
		attackRange = 4,
		attackCooldown = 0.8,
		walkSpeed = 16,
		runSpeed = 32,
		visionRange = 70,
		visionAngle = 180,
		hearingRange = 60,
		aggroRange = 50,
		territoryRadius = 100,
		fleeHealthPercent = 0.15,
		lootDropChance = 0.7,
		xpReward = 25,
		abilities = { "PackHunting", "FlankAttack", "PackCall" },
		preferredBiomes = { "Jungle", "Research" },
	},

	Baryonyx = {
		name = "Baryonyx",
		displayName = "Baryonyx",
		tier = "Rare",
		maxHealth = 400,
		damage = 35,
		attackRange = 8,
		attackCooldown = 1.8,
		walkSpeed = 14,
		runSpeed = 26,
		visionRange = 80,
		visionAngle = 140,
		hearingRange = 60,
		aggroRange = 50,
		territoryRadius = 120,
		fleeHealthPercent = 0.15,
		lootDropChance = 0.7,
		xpReward = 25,
		abilities = { "WaterHunter", "AmbushAttack" },
		preferredBiomes = { "Swamp" },
	},

	Pteranodon = {
		name = "Pteranodon",
		displayName = "Pteranodon",
		tier = "Rare",
		maxHealth = 150,
		damage = 25,
		attackRange = 5,
		attackCooldown = 1.5,
		walkSpeed = 8,
		runSpeed = 40, -- Flight speed
		visionRange = 120,
		visionAngle = 200,
		hearingRange = 80,
		aggroRange = 60,
		territoryRadius = 150,
		fleeHealthPercent = 0.3,
		lootDropChance = 0.7,
		xpReward = 25,
		abilities = { "Flight", "DiveAttack", "Knockback" },
		preferredBiomes = { "Coast", "Swamp" },
	},

	-- EPIC TIER
	Carnotaurus = {
		name = "Carnotaurus",
		displayName = "Carnotaurus",
		tier = "Epic",
		maxHealth = 800,
		damage = 60,
		attackRange = 10,
		attackCooldown = 2.0,
		walkSpeed = 16,
		runSpeed = 34,
		visionRange = 120,
		visionAngle = 100,
		hearingRange = 80,
		aggroRange = 80,
		territoryRadius = 200,
		fleeHealthPercent = 0.1,
		lootDropChance = 0.8,
		xpReward = 50,
		abilities = { "ChargeAttack", "RelentlessPursuit", "Enrage" },
		preferredBiomes = { "Volcanic" },
	},

	Spinosaurus = {
		name = "Spinosaurus",
		displayName = "Spinosaurus",
		tier = "Epic",
		maxHealth = 1200,
		damage = 70,
		attackRange = 12,
		attackCooldown = 2.2,
		walkSpeed = 12,
		runSpeed = 24,
		visionRange = 100,
		visionAngle = 160,
		hearingRange = 70,
		aggroRange = 60,
		territoryRadius = 250,
		fleeHealthPercent = 0.1,
		lootDropChance = 0.8,
		xpReward = 50,
		abilities = { "SemiAquatic", "TailSwipe", "DominanceRoar" },
		preferredBiomes = { "Swamp" },
	},

	-- LEGENDARY TIER
	TRex = {
		name = "TRex",
		displayName = "Tyrannosaurus Rex",
		tier = "Legendary",
		maxHealth = 2000,
		damage = 100,
		attackRange = 12,
		attackCooldown = 2.5,
		walkSpeed = 14,
		runSpeed = 28,
		visionRange = 150,
		visionAngle = 120,
		hearingRange = 100,
		aggroRange = 100,
		territoryRadius = 300,
		fleeHealthPercent = 0.05,
		lootDropChance = 1.0,
		xpReward = 100,
		abilities = { "TerrifyingRoar", "CrushingBite", "GroundTremor", "SmellWounded" },
		preferredBiomes = { "Volcanic", "Plains" },
	},

	Indoraptor = {
		name = "Indoraptor",
		displayName = "Indoraptor",
		tier = "Legendary",
		maxHealth = 1500,
		damage = 80,
		attackRange = 8,
		attackCooldown = 1.2,
		walkSpeed = 18,
		runSpeed = 38,
		visionRange = 180,
		visionAngle = 220,
		hearingRange = 120,
		aggroRange = 150,
		territoryRadius = 500,
		fleeHealthPercent = 0.0, -- Never flees
		lootDropChance = 1.0,
		xpReward = 100,
		abilities = { "Echolocation", "OpenDoors", "Stealth", "PlayerHunter" },
		preferredBiomes = { "Research" },
	},
}

-- Get dinosaurs by tier
function DinosaurData.GetByTier(tier: DinosaurTier): { DinosaurStats }
	local result = {}
	for _, dino in pairs(DinosaurData.Dinosaurs) do
		if dino.tier == tier then
			table.insert(result, dino)
		end
	end
	return result
end

-- Get dinosaurs by biome
function DinosaurData.GetByBiome(biome: string): { DinosaurStats }
	local result = {}
	for _, dino in pairs(DinosaurData.Dinosaurs) do
		for _, preferred in ipairs(dino.preferredBiomes) do
			if preferred == biome then
				table.insert(result, dino)
				break
			end
		end
	end
	return result
end

-- Get XP reward for tier
function DinosaurData.GetXPForTier(tier: DinosaurTier): number
	local xpValues = {
		Common = 10,
		Uncommon = 15,
		Rare = 25,
		Epic = 50,
		Legendary = 100,
	}
	return xpValues[tier] or 10
end

-- Get loot drop chance for tier
function DinosaurData.GetLootChanceForTier(tier: DinosaurTier): number
	local chances = {
		Common = 0.3,
		Uncommon = 0.5,
		Rare = 0.7,
		Epic = 0.8,
		Legendary = 1.0,
	}
	return chances[tier] or 0.3
end

return DinosaurData
