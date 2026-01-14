--!strict
--[[
	WeaponData.lua
	==============
	Complete weapon data for Dino Royale
	Based on GDD Section 4: Weapons System
]]

export type WeaponCategory = "AssaultRifle" | "SMG" | "Shotgun" | "SniperRifle" | "Pistol" | "DMR" | "Special"
export type WeaponRarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"
export type AmmoType = "Light" | "Medium" | "Heavy" | "Shells" | "Special" | "Fuel" | "None"

export type WeaponStats = {
	name: string,
	displayName: string,
	description: string,
	category: WeaponCategory,
	rarity: WeaponRarity,

	-- Damage
	baseDamage: number,
	headshotMultiplier: number,

	-- Fire rate
	fireRate: number,
	fireMode: string,

	-- Magazine
	magazineSize: number,
	ammoType: AmmoType,

	-- Reload
	reloadTime: number,

	-- Accuracy
	baseSpread: number,
	adsSpread: number,

	-- Range
	effectiveRange: number,
	maxRange: number,

	-- Special properties
	special: { [string]: any }?,
}

local WeaponData = {}

-- Rarity multipliers (applied to base stats)
WeaponData.RarityMultipliers = {
	Common = { damage = 1.0, reload = 1.0, magSize = 0 },
	Uncommon = { damage = 1.1, reload = 0.95, magSize = 0 },
	Rare = { damage = 1.2, reload = 0.90, magSize = 2 },
	Epic = { damage = 1.3, reload = 0.85, magSize = 4 },
	Legendary = { damage = 1.4, reload = 0.80, magSize = 6 },
}

WeaponData.Weapons: { [string]: WeaponStats } = {
	-- ASSAULT RIFLES
	RangerAR = {
		name = "RangerAR",
		displayName = "Ranger AR",
		description = "Balanced assault rifle with good accuracy",
		category = "AssaultRifle",
		rarity = "Common",
		baseDamage = 32,
		headshotMultiplier = 2.0,
		fireRate = 5.5,
		fireMode = "Automatic",
		magazineSize = 30,
		ammoType = "Medium",
		reloadTime = 2.5,
		baseSpread = 0.03,
		adsSpread = 0.015,
		effectiveRange = 80,
		maxRange = 150,
	},

	ExpeditionRifle = {
		name = "ExpeditionRifle",
		displayName = "Expedition Rifle",
		description = "Long-range assault rifle with higher damage",
		category = "AssaultRifle",
		rarity = "Uncommon",
		baseDamage = 36,
		headshotMultiplier = 2.0,
		fireRate = 4.5,
		fireMode = "Automatic",
		magazineSize = 25,
		ammoType = "Medium",
		reloadTime = 2.8,
		baseSpread = 0.025,
		adsSpread = 0.012,
		effectiveRange = 100,
		maxRange = 180,
	},

	PredatorCarbine = {
		name = "PredatorCarbine",
		displayName = "Predator Carbine",
		description = "Fast-firing carbine for aggressive play",
		category = "AssaultRifle",
		rarity = "Rare",
		baseDamage = 28,
		headshotMultiplier = 2.0,
		fireRate = 7.0,
		fireMode = "Automatic",
		magazineSize = 35,
		ammoType = "Medium",
		reloadTime = 2.2,
		baseSpread = 0.035,
		adsSpread = 0.02,
		effectiveRange = 70,
		maxRange = 130,
	},

	-- SMGs
	RaptorSMG = {
		name = "RaptorSMG",
		displayName = "Raptor SMG",
		description = "High fire rate SMG for close quarters",
		category = "SMG",
		rarity = "Common",
		baseDamage = 18,
		headshotMultiplier = 1.75,
		fireRate = 10.0,
		fireMode = "Automatic",
		magazineSize = 30,
		ammoType = "Light",
		reloadTime = 2.0,
		baseSpread = 0.05,
		adsSpread = 0.03,
		effectiveRange = 30,
		maxRange = 60,
	},

	JungleSprayer = {
		name = "JungleSprayer",
		displayName = "Jungle Sprayer",
		description = "Large magazine SMG with extreme fire rate",
		category = "SMG",
		rarity = "Uncommon",
		baseDamage = 15,
		headshotMultiplier = 1.75,
		fireRate = 12.0,
		fireMode = "Automatic",
		magazineSize = 40,
		ammoType = "Light",
		reloadTime = 2.5,
		baseSpread = 0.06,
		adsSpread = 0.04,
		effectiveRange = 25,
		maxRange = 50,
	},

	CompactSurvivor = {
		name = "CompactSurvivor",
		displayName = "Compact Survivor",
		description = "Accurate SMG with extended range",
		category = "SMG",
		rarity = "Rare",
		baseDamage = 22,
		headshotMultiplier = 1.75,
		fireRate = 8.0,
		fireMode = "Automatic",
		magazineSize = 25,
		ammoType = "Light",
		reloadTime = 1.8,
		baseSpread = 0.04,
		adsSpread = 0.025,
		effectiveRange = 40,
		maxRange = 70,
	},

	-- SHOTGUNS
	RexBlaster = {
		name = "RexBlaster",
		displayName = "Rex Blaster",
		description = "Semi-auto shotgun with wide spread",
		category = "Shotgun",
		rarity = "Common",
		baseDamage = 95,
		headshotMultiplier = 1.5,
		fireRate = 1.0,
		fireMode = "SemiAuto",
		magazineSize = 8,
		ammoType = "Shells",
		reloadTime = 6.5,
		baseSpread = 0.12,
		adsSpread = 0.08,
		effectiveRange = 15,
		maxRange = 30,
	},

	SafariPump = {
		name = "SafariPump",
		displayName = "Safari Pump",
		description = "Pump-action with tight spread",
		category = "Shotgun",
		rarity = "Uncommon",
		baseDamage = 110,
		headshotMultiplier = 1.5,
		fireRate = 0.7,
		fireMode = "Pump",
		magazineSize = 5,
		ammoType = "Shells",
		reloadTime = 4.5,
		baseSpread = 0.08,
		adsSpread = 0.05,
		effectiveRange = 20,
		maxRange = 35,
	},

	DinoDevastator = {
		name = "DinoDevastator",
		displayName = "Dino Devastator",
		description = "Double-barrel with massive damage",
		category = "Shotgun",
		rarity = "Rare",
		baseDamage = 140,
		headshotMultiplier = 1.5,
		fireRate = 0.5,
		fireMode = "DoubleBarrel",
		magazineSize = 2,
		ammoType = "Shells",
		reloadTime = 3.0,
		baseSpread = 0.07,
		adsSpread = 0.04,
		effectiveRange = 15,
		maxRange = 25,
	},

	-- SNIPER RIFLES
	TranqRifle = {
		name = "TranqRifle",
		displayName = "Tranq Rifle",
		description = "Fast semi-auto sniper with moderate damage",
		category = "SniperRifle",
		rarity = "Uncommon",
		baseDamage = 85,
		headshotMultiplier = 2.5,
		fireRate = 0.8,
		fireMode = "SemiAuto",
		magazineSize = 10,
		ammoType = "Heavy",
		reloadTime = 3.0,
		baseSpread = 0.01,
		adsSpread = 0.002,
		effectiveRange = 150,
		maxRange = 250,
		special = {
			scopeZoom = 4,
		},
	},

	SpottersChoice = {
		name = "SpottersChoice",
		displayName = "Spotter's Choice",
		description = "Balanced bolt-action sniper",
		category = "SniperRifle",
		rarity = "Rare",
		baseDamage = 105,
		headshotMultiplier = 2.5,
		fireRate = 0.5,
		fireMode = "BoltAction",
		magazineSize = 5,
		ammoType = "Heavy",
		reloadTime = 3.5,
		baseSpread = 0.008,
		adsSpread = 0.001,
		effectiveRange = 180,
		maxRange = 300,
		special = {
			scopeZoom = 6,
		},
	},

	ApexHunter = {
		name = "ApexHunter",
		displayName = "Apex Hunter",
		description = "Heavy sniper designed for taking down large targets",
		category = "SniperRifle",
		rarity = "Epic",
		baseDamage = 150,
		headshotMultiplier = 2.5,
		fireRate = 0.3,
		fireMode = "BoltAction",
		magazineSize = 3,
		ammoType = "Heavy",
		reloadTime = 4.0,
		baseSpread = 0.005,
		adsSpread = 0.0005,
		effectiveRange = 200,
		maxRange = 350,
		special = {
			scopeZoom = 8,
			dinoMultiplier = 1.25,
		},
	},

	-- PISTOLS
	RangerSidearm = {
		name = "RangerSidearm",
		displayName = "Ranger Sidearm",
		description = "Standard semi-auto pistol",
		category = "Pistol",
		rarity = "Common",
		baseDamage = 25,
		headshotMultiplier = 2.0,
		fireRate = 4.0,
		fireMode = "SemiAuto",
		magazineSize = 12,
		ammoType = "Light",
		reloadTime = 1.5,
		baseSpread = 0.04,
		adsSpread = 0.02,
		effectiveRange = 30,
		maxRange = 50,
	},

	SurvivorsFriend = {
		name = "SurvivorsFriend",
		displayName = "Survivor's Friend",
		description = "Accurate revolver with stopping power",
		category = "Pistol",
		rarity = "Uncommon",
		baseDamage = 35,
		headshotMultiplier = 2.0,
		fireRate = 2.5,
		fireMode = "SemiAuto",
		magazineSize = 8,
		ammoType = "Light",
		reloadTime = 1.8,
		baseSpread = 0.03,
		adsSpread = 0.015,
		effectiveRange = 40,
		maxRange = 60,
	},

	DesertClaw = {
		name = "DesertClaw",
		displayName = "Desert Claw",
		description = "High-caliber hand cannon",
		category = "Pistol",
		rarity = "Rare",
		baseDamage = 55,
		headshotMultiplier = 2.0,
		fireRate = 1.5,
		fireMode = "SemiAuto",
		magazineSize = 7,
		ammoType = "Light",
		reloadTime = 2.0,
		baseSpread = 0.025,
		adsSpread = 0.01,
		effectiveRange = 45,
		maxRange = 70,
	},

	-- DMRs
	ScoutMarksman = {
		name = "ScoutMarksman",
		displayName = "Scout Marksman",
		description = "Light DMR for rapid follow-up shots",
		category = "DMR",
		rarity = "Uncommon",
		baseDamage = 48,
		headshotMultiplier = 2.0,
		fireRate = 2.5,
		fireMode = "SemiAuto",
		magazineSize = 15,
		ammoType = "Heavy",
		reloadTime = 2.5,
		baseSpread = 0.02,
		adsSpread = 0.01,
		effectiveRange = 100,
		maxRange = 180,
		special = {
			scopeZoom = 2,
		},
	},

	ParkWarden = {
		name = "ParkWarden",
		displayName = "Park Warden",
		description = "Balanced DMR with good damage",
		category = "DMR",
		rarity = "Rare",
		baseDamage = 58,
		headshotMultiplier = 2.0,
		fireRate = 2.0,
		fireMode = "SemiAuto",
		magazineSize = 12,
		ammoType = "Heavy",
		reloadTime = 2.8,
		baseSpread = 0.018,
		adsSpread = 0.008,
		effectiveRange = 120,
		maxRange = 200,
		special = {
			scopeZoom = 3,
		},
	},

	PrecisionRanger = {
		name = "PrecisionRanger",
		displayName = "Precision Ranger",
		description = "Heavy DMR for long-range precision",
		category = "DMR",
		rarity = "Epic",
		baseDamage = 68,
		headshotMultiplier = 2.0,
		fireRate = 1.5,
		fireMode = "SemiAuto",
		magazineSize = 10,
		ammoType = "Heavy",
		reloadTime = 3.0,
		baseSpread = 0.015,
		adsSpread = 0.005,
		effectiveRange = 140,
		maxRange = 220,
		special = {
			scopeZoom = 4,
		},
	},

	-- SPECIAL WEAPONS
	ElectroNetGun = {
		name = "ElectroNetGun",
		displayName = "Electro Net Gun",
		description = "Fires electrified nets that slow players and stun dinosaurs",
		category = "Special",
		rarity = "Epic",
		baseDamage = 15,
		headshotMultiplier = 1.0,
		fireRate = 0.5,
		fireMode = "Single",
		magazineSize = 3,
		ammoType = "Special",
		reloadTime = 4.0,
		baseSpread = 0.05,
		adsSpread = 0.03,
		effectiveRange = 30,
		maxRange = 50,
		special = {
			playerSlowPercent = 0.5,
			playerSlowDuration = 3.0,
			dinoStunDuration = 5.0,
			vehicleDisableDuration = 4.0,
			projectileSpeed = 80,
		},
	},

	AmberLauncher = {
		name = "AmberLauncher",
		displayName = "Amber Launcher",
		description = "Fires explosive amber that creates sticky zones",
		category = "Special",
		rarity = "Legendary",
		baseDamage = 50,
		headshotMultiplier = 1.0,
		fireRate = 0.8,
		fireMode = "Single",
		magazineSize = 4,
		ammoType = "Special",
		reloadTime = 3.5,
		baseSpread = 0.03,
		adsSpread = 0.02,
		effectiveRange = 60,
		maxRange = 80,
		special = {
			splashDamage = 25,
			zoneRadius = 4,
			zoneDuration = 10,
			slowPercent = 0.7,
			zoneDPS = 5,
			projectileGravity = 15,
		},
	},

	TranquilizerGun = {
		name = "TranquilizerGun",
		displayName = "Tranquilizer Dart Gun",
		description = "Puts small dinos to sleep, slows players",
		category = "Special",
		rarity = "Epic",
		baseDamage = 15,
		headshotMultiplier = 1.5,
		fireRate = 0.8,
		fireMode = "Single",
		magazineSize = 6,
		ammoType = "Special",
		reloadTime = 3.0,
		baseSpread = 0.01,
		adsSpread = 0.005,
		effectiveRange = 80,
		maxRange = 120,
		special = {
			playerSlowPercent = 0.6,
			playerSlowDuration = 5.0,
			playerBlurDuration = 3.0,
			stackable = true,
			maxStacks = 3,
			scopeZoom = 2,
		},
	},

	Flamethrower = {
		name = "Flamethrower",
		displayName = "Flamethrower",
		description = "Continuous fire stream with burn damage",
		category = "Special",
		rarity = "Legendary",
		baseDamage = 12,
		headshotMultiplier = 1.0,
		fireRate = 10,
		fireMode = "Automatic",
		magazineSize = 100,
		ammoType = "Fuel",
		reloadTime = 5.0,
		baseSpread = 0.15,
		adsSpread = 0.12,
		effectiveRange = 15,
		maxRange = 20,
		special = {
			burnDamage = 5,
			burnDuration = 4,
			firePatchRadius = 3,
			firePatchDuration = 5,
			firePatchDPS = 8,
			dinoMultiplier = 1.5,
			fuelDrainRate = 10,
		},
	},

	DinoCall = {
		name = "DinoCall",
		displayName = "Dino Call",
		description = "Attracts nearby dinosaurs to target location",
		category = "Special",
		rarity = "Rare",
		baseDamage = 0,
		headshotMultiplier = 1.0,
		fireRate = 0.067, -- 15 second cooldown
		fireMode = "Single",
		magazineSize = 5,
		ammoType = "None",
		reloadTime = 0,
		baseSpread = 0,
		adsSpread = 0,
		effectiveRange = 100,
		maxRange = 100,
		special = {
			attractRadius = 80,
			attractDuration = 20,
			variants = { "Carnivore", "Herbivore", "Apex", "Flying" },
		},
	},
}

-- Get weapons by category
function WeaponData.GetByCategory(category: WeaponCategory): { WeaponStats }
	local result = {}
	for _, weapon in pairs(WeaponData.Weapons) do
		if weapon.category == category then
			table.insert(result, weapon)
		end
	end
	return result
end

-- Get weapons by rarity
function WeaponData.GetByRarity(rarity: WeaponRarity): { WeaponStats }
	local result = {}
	for _, weapon in pairs(WeaponData.Weapons) do
		if weapon.rarity == rarity then
			table.insert(result, weapon)
		end
	end
	return result
end

-- Apply rarity multipliers to base weapon
function WeaponData.GetWeaponWithRarity(baseName: string, rarity: WeaponRarity): WeaponStats?
	local base = WeaponData.Weapons[baseName]
	if not base then return nil end

	local multipliers = WeaponData.RarityMultipliers[rarity]
	if not multipliers then return base end

	-- Clone and apply multipliers
	local modified = table.clone(base)
	modified.rarity = rarity
	modified.baseDamage = math.floor(base.baseDamage * multipliers.damage)
	modified.reloadTime = base.reloadTime * multipliers.reload
	modified.magazineSize = base.magazineSize + multipliers.magSize

	return modified
end

return WeaponData
