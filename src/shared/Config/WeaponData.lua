--!strict
--[[
	WeaponData.lua
	==============
	Complete weapon definitions for Dino Royale
	All stats are base values - apply rarity multiplier for final stats
]]

local Types = require(script.Parent.Parent.Types)

export type WeaponDefinition = {
	name: string,
	category: string,
	damage: number,
	fireRate: number,
	magSize: number,
	reloadTime: number,
	range: number,
	spread: number,
	pellets: number?,
	scopeZoom: number?,
	special: string?,
}

local WeaponData = {}

-- Rarity multipliers applied to damage
WeaponData.RARITY_MULTIPLIERS = {
	Common = 1.0,
	Uncommon = 1.1,
	Rare = 1.2,
	Epic = 1.3,
	Legendary = 1.4,
}

-- Ammo types per weapon category
WeaponData.AMMO_TYPES = {
	AssaultRifle = "MediumAmmo",
	SMG = "LightAmmo",
	Shotgun = "Shells",
	Sniper = "HeavyAmmo",
	Pistol = "LightAmmo",
	DMR = "MediumAmmo",
	Special = "SpecialAmmo",
}

--[[
	ASSAULT RIFLES
	Medium range, automatic fire, balanced stats
]]
WeaponData.AssaultRifles = {
	RangerAR = {
		name = "Ranger AR",
		category = "AssaultRifle",
		damage = 32,
		fireRate = 5.5,
		magSize = 30,
		reloadTime = 2.5,
		range = 150,
		spread = 0.02,
	},
	ExpeditionRifle = {
		name = "Expedition Rifle",
		category = "AssaultRifle",
		damage = 36,
		fireRate = 4.5,
		magSize = 25,
		reloadTime = 2.8,
		range = 175,
		spread = 0.015,
	},
	PredatorCarbine = {
		name = "Predator Carbine",
		category = "AssaultRifle",
		damage = 28,
		fireRate = 7.0,
		magSize = 35,
		reloadTime = 2.2,
		range = 125,
		spread = 0.025,
	},
}

--[[
	SMGS
	Close range, high fire rate, lower damage
]]
WeaponData.SMGs = {
	RaptorSMG = {
		name = "Raptor SMG",
		category = "SMG",
		damage = 18,
		fireRate = 10.0,
		magSize = 30,
		reloadTime = 2.0,
		range = 75,
		spread = 0.04,
	},
	JungleSprayer = {
		name = "Jungle Sprayer",
		category = "SMG",
		damage = 15,
		fireRate = 12.0,
		magSize = 40,
		reloadTime = 2.5,
		range = 60,
		spread = 0.05,
	},
	CompactSurvivor = {
		name = "Compact Survivor",
		category = "SMG",
		damage = 22,
		fireRate = 8.0,
		magSize = 25,
		reloadTime = 1.8,
		range = 80,
		spread = 0.035,
	},
}

--[[
	SHOTGUNS
	Close range, high burst damage, multiple pellets
]]
WeaponData.Shotguns = {
	RexBlaster = {
		name = "Rex Blaster",
		category = "Shotgun",
		damage = 95,
		fireRate = 1.0,
		magSize = 8,
		reloadTime = 6.5,
		range = 30,
		spread = 0.15,
		pellets = 10,
	},
	SafariPump = {
		name = "Safari Pump",
		category = "Shotgun",
		damage = 110,
		fireRate = 0.7,
		magSize = 5,
		reloadTime = 4.5,
		range = 40,
		spread = 0.08,
		pellets = 8,
	},
	DinoDeva = {
		name = "Dino Devastator",
		category = "Shotgun",
		damage = 140,
		fireRate = 0.5,
		magSize = 2,
		reloadTime = 3.0,
		range = 35,
		spread = 0.08,
		pellets = 6,
	},
}

--[[
	SNIPERS
	Long range, high damage, scope zoom
]]
WeaponData.Snipers = {
	TranqRifle = {
		name = "Tranq Rifle",
		category = "Sniper",
		damage = 85,
		fireRate = 0.8,
		magSize = 10,
		reloadTime = 3.0,
		range = 500,
		spread = 0,
		scopeZoom = 4,
	},
	SpottersChoice = {
		name = "Spotter's Choice",
		category = "Sniper",
		damage = 105,
		fireRate = 0.5,
		magSize = 5,
		reloadTime = 3.5,
		range = 600,
		spread = 0,
		scopeZoom = 6,
	},
	ApexHunter = {
		name = "Apex Hunter",
		category = "Sniper",
		damage = 150,
		fireRate = 0.3,
		magSize = 3,
		reloadTime = 4.0,
		range = 800,
		spread = 0,
		scopeZoom = 8,
	},
}

--[[
	PISTOLS
	Sidearm, fast switch, decent damage
]]
WeaponData.Pistols = {
	RangerSidearm = {
		name = "Ranger Sidearm",
		category = "Pistol",
		damage = 25,
		fireRate = 4.0,
		magSize = 12,
		reloadTime = 1.5,
		range = 50,
		spread = 0.03,
	},
	SurvivorsFriend = {
		name = "Survivor's Friend",
		category = "Pistol",
		damage = 35,
		fireRate = 2.5,
		magSize = 8,
		reloadTime = 1.8,
		range = 60,
		spread = 0.025,
	},
	DesertClaw = {
		name = "Desert Claw",
		category = "Pistol",
		damage = 55,
		fireRate = 1.5,
		magSize = 7,
		reloadTime = 2.0,
		range = 75,
		spread = 0.02,
	},
}

--[[
	DMRs (Designated Marksman Rifles)
	Medium-long range, semi-auto, moderate zoom
]]
WeaponData.DMRs = {
	ScoutMarksman = {
		name = "Scout Marksman",
		category = "DMR",
		damage = 48,
		fireRate = 2.5,
		magSize = 15,
		reloadTime = 2.5,
		range = 200,
		spread = 0.01,
		scopeZoom = 2,
	},
	ParkWarden = {
		name = "Park Warden",
		category = "DMR",
		damage = 58,
		fireRate = 2.0,
		magSize = 12,
		reloadTime = 2.8,
		range = 250,
		spread = 0.008,
		scopeZoom = 3,
	},
	PrecisionRanger = {
		name = "Precision Ranger",
		category = "DMR",
		damage = 68,
		fireRate = 1.5,
		magSize = 10,
		reloadTime = 3.0,
		range = 300,
		spread = 0.005,
		scopeZoom = 4,
	},
}

--[[
	SPECIAL WEAPONS
	Unique mechanics and effects
]]
WeaponData.Special = {
	TranqDartGun = {
		name = "Tranq Dart Gun",
		category = "Special",
		damage = 20,
		fireRate = 0.5,
		magSize = 5,
		reloadTime = 4.0,
		range = 100,
		spread = 0.01,
		special = "sleepDino",
	},
	Flamethrower = {
		name = "Flamethrower",
		category = "Special",
		damage = 15,
		fireRate = 10.0,
		magSize = 100,
		reloadTime = 5.0,
		range = 20,
		spread = 0.1,
		special = "fire",
	},
}

-- Lookup table for all weapons by ID
WeaponData.AllWeapons = {} :: { [string]: WeaponDefinition }

-- Populate AllWeapons lookup
for _, category in pairs({ "AssaultRifles", "SMGs", "Shotguns", "Snipers", "Pistols", "DMRs", "Special" }) do
	for weaponId, weaponDef in pairs(WeaponData[category]) do
		WeaponData.AllWeapons[weaponId] = weaponDef
	end
end

-- Get weapon definition by ID
function WeaponData.GetWeapon(weaponId: string): WeaponDefinition?
	return WeaponData.AllWeapons[weaponId]
end

-- Calculate final stats with rarity multiplier
function WeaponData.GetStatsWithRarity(weaponId: string, rarity: Types.Rarity): Types.WeaponStats?
	local baseDef = WeaponData.AllWeapons[weaponId]
	if not baseDef then
		return nil
	end

	local multiplier = WeaponData.RARITY_MULTIPLIERS[rarity] or 1.0

	return {
		damage = baseDef.damage * multiplier,
		fireRate = baseDef.fireRate,
		magSize = baseDef.magSize,
		reloadTime = baseDef.reloadTime,
		range = baseDef.range,
		spread = baseDef.spread,
	}
end

-- Get ammo type for a weapon
function WeaponData.GetAmmoType(weaponId: string): string?
	local weapon = WeaponData.AllWeapons[weaponId]
	if not weapon then
		return nil
	end
	return WeaponData.AMMO_TYPES[weapon.category]
end

return WeaponData
