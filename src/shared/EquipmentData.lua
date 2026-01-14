--!strict
--[[
	EquipmentData.lua
	=================
	Complete equipment data for Dino Royale
	Based on GDD Section 6.2: Tactical Equipment
]]

export type EquipmentCategory = "Throwable" | "Deployable" | "Consumable"

export type EquipmentStats = {
	name: string,
	displayName: string,
	description: string,
	category: EquipmentCategory,
	rarity: string,

	maxStack: number,
	useTime: number,
	cooldown: number,

	-- Throwable properties
	throwForce: number?,
	throwArc: number?,
	fuseTime: number?,

	-- Effect properties
	effectRadius: number?,
	effectDuration: number?,
	damage: number?,

	-- Special properties
	special: { [string]: any }?,
}

local EquipmentData = {}

EquipmentData.Equipment: { [string]: EquipmentStats } = {
	-- THROWABLES
	FragGrenade = {
		name = "FragGrenade",
		displayName = "Frag Grenade",
		description = "Explosive grenade with 5m blast radius. 70 damage at center.",
		category = "Throwable",
		rarity = "Uncommon",
		maxStack = 6,
		useTime = 0.5,
		cooldown = 0.5,
		throwForce = 80,
		throwArc = 0.3,
		fuseTime = 3.0,
		effectRadius = 5,
		damage = 70,
		special = {
			falloffStart = 2,
			falloffEnd = 5,
		},
	},

	SmokeBomb = {
		name = "SmokeBomb",
		displayName = "Smoke Bomb",
		description = "Creates visual cover and confuses dinosaur AI for 5 seconds",
		category = "Throwable",
		rarity = "Common",
		maxStack = 4,
		useTime = 0.3,
		cooldown = 0.5,
		throwForce = 60,
		throwArc = 0.4,
		fuseTime = 1.0,
		effectRadius = 8,
		effectDuration = 15,
		special = {
			dinoConfuseDuration = 5,
			opacity = 0.8,
		},
	},

	Flashbang = {
		name = "Flashbang",
		displayName = "Flashbang",
		description = "Blinds players and panics dinosaurs for 3 seconds",
		category = "Throwable",
		rarity = "Uncommon",
		maxStack = 4,
		useTime = 0.4,
		cooldown = 0.5,
		throwForce = 70,
		throwArc = 0.35,
		fuseTime = 2.0,
		effectRadius = 12,
		special = {
			blindDuration = 3.0,
			dinoPanicDuration = 3.0,
			fullEffectAngle = 90,
		},
	},

	Flare = {
		name = "Flare",
		displayName = "Flare",
		description = "Attracts dinosaurs and marks enemy locations with bright light",
		category = "Throwable",
		rarity = "Common",
		maxStack = 6,
		useTime = 0.3,
		cooldown = 0.5,
		throwForce = 65,
		throwArc = 0.6,
		effectRadius = 30,
		effectDuration = 45,
		special = {
			revealRadius = 25,
			dinoAttractRadius = 40,
			dinoAttractChance = 0.5,
		},
	},

	MeatBait = {
		name = "MeatBait",
		displayName = "Meat Bait",
		description = "Throwable lure that attracts carnivores for 20 seconds",
		category = "Throwable",
		rarity = "Common",
		maxStack = 4,
		useTime = 0.5,
		cooldown = 0.5,
		throwForce = 50,
		throwArc = 0.5,
		effectRadius = 50,
		effectDuration = 20,
		special = {
			attractPriority = 0.8,
			attractedTypes = { "Velociraptor", "Dilophosaurus", "Compsognathus", "Carnotaurus", "Baryonyx" },
		},
	},

	-- DEPLOYABLES
	GrappleHook = {
		name = "GrappleHook",
		displayName = "Grapple Hook",
		description = "50m range grapple for quick traversal and escaping dinosaurs",
		category = "Deployable",
		rarity = "Rare",
		maxStack = 3,
		useTime = 0.2,
		cooldown = 1.0,
		special = {
			maxRange = 50,
			hookSpeed = 100,
			pullSpeed = 40,
			minAttachAngle = 30,
			canBeInterrupted = true,
		},
	},

	MotionSensor = {
		name = "MotionSensor",
		displayName = "Motion Sensor",
		description = "Deployable sensor that detects players and dinos within 30m for 60 seconds",
		category = "Deployable",
		rarity = "Rare",
		maxStack = 2,
		useTime = 1.0,
		cooldown = 2.0,
		effectRadius = 30,
		effectDuration = 60,
		special = {
			pingInterval = 2.0,
			health = 50,
			detectsPlayers = true,
			detectsDinosaurs = true,
			detectsVehicles = true,
		},
	},

	DinoRepellent = {
		name = "DinoRepellent",
		displayName = "Dino Repellent",
		description = "Spray creating a 10m dinosaur-free zone for 30 seconds",
		category = "Deployable",
		rarity = "Uncommon",
		maxStack = 2,
		useTime = 1.5,
		cooldown = 1.0,
		effectRadius = 10,
		effectDuration = 30,
		special = {
			repelStrength = 1.0,
			bossRepelStrength = 0.3,
		},
	},
}

-- Get equipment by category
function EquipmentData.GetByCategory(category: EquipmentCategory): { EquipmentStats }
	local result = {}
	for _, equip in pairs(EquipmentData.Equipment) do
		if equip.category == category then
			table.insert(result, equip)
		end
	end
	return result
end

-- Get equipment by rarity
function EquipmentData.GetByRarity(rarity: string): { EquipmentStats }
	local result = {}
	for _, equip in pairs(EquipmentData.Equipment) do
		if equip.rarity == rarity then
			table.insert(result, equip)
		end
	end
	return result
end

-- Get throwables
function EquipmentData.GetThrowables(): { EquipmentStats }
	return EquipmentData.GetByCategory("Throwable")
end

-- Get deployables
function EquipmentData.GetDeployables(): { EquipmentStats }
	return EquipmentData.GetByCategory("Deployable")
end

return EquipmentData
