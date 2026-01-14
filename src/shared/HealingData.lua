--!strict
--[[
	HealingData.lua
	===============
	Healing items and consumables data
	Based on GDD Section 6: Items & Loot
]]

export type HealingType = "Instant" | "OverTime" | "Shield" | "Buff"

export type HealingItem = {
	id: string,
	name: string,
	displayName: string,
	description: string,
	healingType: HealingType,

	-- Healing properties
	healAmount: number,
	healDuration: number?, -- For over-time healing
	healPerSecond: number?, -- For over-time healing

	-- Armor/Shield
	armorAmount: number?,
	shieldDuration: number?,

	-- Buff properties
	speedBoost: number?,
	damageBoost: number?,
	buffDuration: number?,

	-- Usage
	useTime: number, -- Seconds to use
	maxStack: number,
	canMoveWhileUsing: boolean,
	canCancelUse: boolean,

	-- Audio/Visual
	useSound: string,
	useEffect: string?,
}

local HealingData = {}

HealingData.Items: { [string]: HealingItem } = {
	Bandage = {
		id = "Bandage",
		name = "Bandage",
		displayName = "Bandage",
		description = "Basic healing. Restores 15 health over 4 seconds.",
		healingType = "OverTime",

		healAmount = 15,
		healDuration = 4,
		healPerSecond = 3.75,

		useTime = 3,
		maxStack = 15,
		canMoveWhileUsing = true,
		canCancelUse = true,

		useSound = "BandageUse",
		useEffect = "BandageHeal",
	},

	MedKit = {
		id = "MedKit",
		name = "MedKit",
		displayName = "Med Kit",
		description = "Full medical kit. Restores 75 health.",
		healingType = "Instant",

		healAmount = 75,

		useTime = 5,
		maxStack = 5,
		canMoveWhileUsing = false,
		canCancelUse = true,

		useSound = "MedKitUse",
		useEffect = "MedKitHeal",
	},

	Stimpack = {
		id = "Stimpack",
		name = "Stimpack",
		displayName = "Stimpack",
		description = "Emergency injection. Instant 50 health and 20% speed boost for 10 seconds.",
		healingType = "Buff",

		healAmount = 50,
		speedBoost = 0.2,
		buffDuration = 10,

		useTime = 1.5,
		maxStack = 3,
		canMoveWhileUsing = true,
		canCancelUse = false,

		useSound = "StimpackUse",
		useEffect = "StimpackBuff",
	},

	Adrenaline = {
		id = "Adrenaline",
		name = "Adrenaline",
		displayName = "Adrenaline Shot",
		description = "Combat stimulant. Full health, 30% speed and 15% damage boost for 15 seconds.",
		healingType = "Buff",

		healAmount = 100,
		speedBoost = 0.3,
		damageBoost = 0.15,
		buffDuration = 15,

		useTime = 2,
		maxStack = 2,
		canMoveWhileUsing = true,
		canCancelUse = false,

		useSound = "AdrenalineUse",
		useEffect = "AdrenalineBuff",
	},

	ShieldPotion = {
		id = "ShieldPotion",
		name = "ShieldPotion",
		displayName = "Shield Potion",
		description = "Grants 50 armor points.",
		healingType = "Shield",

		healAmount = 0,
		armorAmount = 50,

		useTime = 4,
		maxStack = 3,
		canMoveWhileUsing = false,
		canCancelUse = true,

		useSound = "ShieldUse",
		useEffect = "ShieldGain",
	},

	MiniShield = {
		id = "MiniShield",
		name = "MiniShield",
		displayName = "Mini Shield",
		description = "Quick shield boost. Grants 25 armor points.",
		healingType = "Shield",

		healAmount = 0,
		armorAmount = 25,

		useTime = 2,
		maxStack = 6,
		canMoveWhileUsing = true,
		canCancelUse = true,

		useSound = "MiniShieldUse",
		useEffect = "ShieldGain",
	},
}

-- Armor types and their properties
HealingData.ArmorTypes = {
	LightArmor = {
		id = "LightArmor",
		name = "Light Armor",
		displayName = "Light Armor",
		description = "Basic protection. 25 armor points.",
		armorAmount = 25,
		movementPenalty = 0,
	},

	MediumArmor = {
		id = "MediumArmor",
		name = "Medium Armor",
		displayName = "Medium Armor",
		description = "Standard protection. 50 armor points.",
		armorAmount = 50,
		movementPenalty = 0.05,
	},

	HeavyArmor = {
		id = "HeavyArmor",
		name = "Heavy Armor",
		displayName = "Heavy Armor",
		description = "Maximum protection. 100 armor points.",
		armorAmount = 100,
		movementPenalty = 0.1,
	},

	DinoHideArmor = {
		id = "DinoHideArmor",
		name = "Dino Hide Armor",
		displayName = "Dino Hide Armor",
		description = "Crafted from dinosaur scales. 75 armor with dino damage resistance.",
		armorAmount = 75,
		movementPenalty = 0.05,
		dinoDamageReduction = 0.25,
	},
}

-- Get healing item by ID
function HealingData.GetItem(id: string): HealingItem?
	return HealingData.Items[id]
end

-- Get all healing items
function HealingData.GetAllItems(): { HealingItem }
	local result = {}
	for _, item in pairs(HealingData.Items) do
		table.insert(result, item)
	end
	return result
end

-- Calculate heal per second
function HealingData.GetHealPerSecond(item: HealingItem): number
	if item.healingType == "OverTime" then
		return item.healPerSecond or (item.healAmount / (item.healDuration or 1))
	end
	return 0
end

return HealingData
