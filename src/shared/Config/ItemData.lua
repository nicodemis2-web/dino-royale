--!strict
--[[
	ItemData.lua
	============
	Complete item definitions for Dino Royale
	Includes healing, shields, tactical, and ammo items
]]

export type HealingItem = {
	name: string,
	category: "Healing",
	healAmount: number,
	useTime: number,
	maxStack: number,
	maxHealTo: number?,
	overheal: number?,
	overTime: boolean?,
	duration: number?,
}

export type ShieldItem = {
	name: string,
	category: "Shield",
	shieldAmount: number,
	healAmount: number?,
	useTime: number,
	maxStack: number,
	overTime: boolean?,
	duration: number?,
}

export type TacticalItem = {
	name: string,
	category: "Tactical",
	maxStack: number,
	damage: number?,
	radius: number?,
	fuseTime: number?,
	blindDuration: number?,
	dinoEffect: string?,
	duration: number?,
	blocksVision: boolean?,
	confusesDinos: boolean?,
	range: number?,
	charges: number?,
	cooldown: number?,
	attracts: string?,
}

export type AmmoItem = {
	name: string,
	category: "Ammo",
	maxStack: number,
	weapons: { string },
}

export type ItemDefinition = HealingItem | ShieldItem | TacticalItem | AmmoItem

local ItemData = {}

--[[
	HEALING ITEMS
	Restore health over time or instantly
]]
ItemData.Healing = {
	Bandage = {
		name = "Bandage",
		category = "Healing" :: "Healing",
		healAmount = 15,
		useTime = 3,
		maxStack = 15,
		maxHealTo = 75,
	},
	MedKit = {
		name = "Med Kit",
		category = "Healing" :: "Healing",
		healAmount = 75,
		useTime = 7,
		maxStack = 5,
		maxHealTo = 100,
	},
	DinoAdrenaline = {
		name = "Dino Adrenaline",
		category = "Healing" :: "Healing",
		healAmount = 100,
		useTime = 10,
		maxStack = 2,
		maxHealTo = 100,
		overheal = 25,
	},
}

--[[
	SHIELD ITEMS
	Restore or add shield protection
]]
ItemData.Shields = {
	ShieldSerum = {
		name = "Shield Serum",
		category = "Shield" :: "Shield",
		shieldAmount = 50,
		useTime = 4,
		maxStack = 6,
	},
	MegaSerum = {
		name = "Mega Serum",
		category = "Shield" :: "Shield",
		shieldAmount = 100,
		useTime = 8,
		maxStack = 3,
	},
	SlurpCanteen = {
		name = "Slurp Canteen",
		category = "Shield" :: "Shield",
		healAmount = 75,
		shieldAmount = 75,
		useTime = 5,
		maxStack = 2,
		overTime = true,
		duration = 15,
	},
}

--[[
	TACTICAL ITEMS
	Combat utility items like grenades and gadgets
]]
ItemData.Tactical = {
	FragGrenade = {
		name = "Frag Grenade",
		category = "Tactical" :: "Tactical",
		damage = 70,
		radius = 5,
		fuseTime = 3,
		maxStack = 6,
	},
	Flashbang = {
		name = "Flashbang",
		category = "Tactical" :: "Tactical",
		blindDuration = 3,
		fuseTime = 2,
		maxStack = 4,
		dinoEffect = "Panic",
	},
	SmokeGrenade = {
		name = "Smoke Grenade",
		category = "Tactical" :: "Tactical",
		duration = 15,
		radius = 8,
		maxStack = 4,
		blocksVision = true,
		confusesDinos = true,
	},
	GrappleHook = {
		name = "Grapple Hook",
		category = "Tactical" :: "Tactical",
		range = 50,
		charges = 3,
		cooldown = 2,
		maxStack = 1,
	},
	MotionSensor = {
		name = "Motion Sensor",
		category = "Tactical" :: "Tactical",
		duration = 60,
		range = 30,
		maxStack = 3,
	},
	MeatBait = {
		name = "Meat Bait",
		category = "Tactical" :: "Tactical",
		duration = 20,
		range = 50,
		maxStack = 5,
		attracts = "Carnivore",
	},
	DinoRepellent = {
		name = "Dino Repellent",
		category = "Tactical" :: "Tactical",
		duration = 30,
		radius = 10,
		maxStack = 3,
	},
}

--[[
	AMMO TYPES
	Ammunition for different weapon categories
]]
ItemData.Ammo = {
	LightAmmo = {
		name = "Light Ammo",
		category = "Ammo" :: "Ammo",
		maxStack = 999,
		weapons = { "SMG", "Pistol" },
	},
	MediumAmmo = {
		name = "Medium Ammo",
		category = "Ammo" :: "Ammo",
		maxStack = 999,
		weapons = { "AssaultRifle", "DMR" },
	},
	HeavyAmmo = {
		name = "Heavy Ammo",
		category = "Ammo" :: "Ammo",
		maxStack = 60,
		weapons = { "Sniper" },
	},
	Shells = {
		name = "Shotgun Shells",
		category = "Ammo" :: "Ammo",
		maxStack = 60,
		weapons = { "Shotgun" },
	},
	SpecialAmmo = {
		name = "Special Ammo",
		category = "Ammo" :: "Ammo",
		maxStack = 30,
		weapons = { "TranqDartGun", "Flamethrower" },
	},
}

-- Lookup table for all items by ID
ItemData.AllItems = {} :: { [string]: ItemDefinition }

-- Populate AllItems lookup
for _, category in pairs({ "Healing", "Shields", "Tactical", "Ammo" }) do
	for itemId, itemDef in pairs(ItemData[category]) do
		ItemData.AllItems[itemId] = itemDef
	end
end

-- Get item definition by ID
function ItemData.GetItem(itemId: string): ItemDefinition?
	return ItemData.AllItems[itemId]
end

-- Get max stack size for an item
function ItemData.GetMaxStack(itemId: string): number
	local item = ItemData.AllItems[itemId]
	if item then
		return item.maxStack
	end
	return 1
end

-- Check if item is consumable (healing or shield)
function ItemData.IsConsumable(itemId: string): boolean
	local item = ItemData.AllItems[itemId]
	if not item then
		return false
	end
	return item.category == "Healing" or item.category == "Shield"
end

-- Check if item is a throwable
function ItemData.IsThrowable(itemId: string): boolean
	local item = ItemData.AllItems[itemId]
	if not item then
		return false
	end
	if item.category ~= "Tactical" then
		return false
	end
	local tactical = item :: TacticalItem
	return tactical.fuseTime ~= nil
end

-- Get ammo type for a weapon category
function ItemData.GetAmmoForWeaponCategory(weaponCategory: string): string?
	for ammoId, ammoDef in pairs(ItemData.Ammo) do
		for _, weaponCat in ipairs(ammoDef.weapons) do
			if weaponCat == weaponCategory then
				return ammoId
			end
		end
	end
	return nil
end

-- Check if ammo type works with weapon category
function ItemData.IsAmmoCompatible(ammoId: string, weaponCategory: string): boolean
	local ammo = ItemData.Ammo[ammoId]
	if not ammo then
		return false
	end
	for _, cat in ipairs(ammo.weapons) do
		if cat == weaponCategory then
			return true
		end
	end
	return false
end

return ItemData
