--!strict
--[[
	ShopData.lua
	============
	Item Shop configuration and catalog
	Based on GDD Section 8.3: Shop Structure
]]

export type ShopItemType = "Skin" | "Emote" | "Glider" | "BackBling" | "WeaponSkin" | "Bundle" | "Trail" | "Pickaxe"

export type ShopItem = {
	id: string,
	name: string,
	description: string,
	itemType: ShopItemType,
	rarity: string,
	price: number, -- In Robux
	originalPrice: number?, -- For sales
	isOnSale: boolean,
	previewImage: string?,
	assetId: string?,
	bundleContents: { string }?, -- For bundles
	availableUntil: number?, -- Timestamp
	isExclusive: boolean,
}

export type ShopRotation = {
	featured: { ShopItem },
	daily: { ShopItem },
	special: { ShopItem }?,
}

local ShopData = {}

-- All available shop items
ShopData.Catalog: { [string]: ShopItem } = {
	-- LEGENDARY SKINS (1500-2000 Robux)
	Skin_RexHunter = {
		id = "Skin_RexHunter",
		name = "Rex Hunter",
		description = "The ultimate T-Rex hunter. Complete with tracking gear and protective armor.",
		itemType = "Skin",
		rarity = "Legendary",
		price = 2000,
		isOnSale = false,
		isExclusive = false,
	},
	Skin_DinoKnight = {
		id = "Skin_DinoKnight",
		name = "Dino Knight",
		description = "Medieval warrior with dinosaur-scale armor.",
		itemType = "Skin",
		rarity = "Legendary",
		price = 1800,
		isOnSale = false,
		isExclusive = false,
	},
	Skin_PrimalChampion = {
		id = "Skin_PrimalChampion",
		name = "Primal Champion",
		description = "Channel the power of the prehistoric era.",
		itemType = "Skin",
		rarity = "Legendary",
		price = 1500,
		isOnSale = false,
		isExclusive = false,
	},

	-- EPIC SKINS (800-1200 Robux)
	Skin_JungleExplorer = {
		id = "Skin_JungleExplorer",
		name = "Jungle Explorer",
		description = "Ready for any expedition through the wilds.",
		itemType = "Skin",
		rarity = "Epic",
		price = 1200,
		isOnSale = false,
		isExclusive = false,
	},
	Skin_LabTech = {
		id = "Skin_LabTech",
		name = "Lab Technician",
		description = "InGen's finest genetic researcher.",
		itemType = "Skin",
		rarity = "Epic",
		price = 1000,
		isOnSale = false,
		isExclusive = false,
	},
	Skin_SecurityForce = {
		id = "Skin_SecurityForce",
		name = "Security Force",
		description = "Park security tactical response unit.",
		itemType = "Skin",
		rarity = "Epic",
		price = 800,
		isOnSale = false,
		isExclusive = false,
	},

	-- RARE SKINS (400-800 Robux)
	Skin_SafariGuide = {
		id = "Skin_SafariGuide",
		name = "Safari Guide",
		description = "Expert tour guide for dangerous territory.",
		itemType = "Skin",
		rarity = "Rare",
		price = 600,
		isOnSale = false,
		isExclusive = false,
	},
	Skin_Paleontologist = {
		id = "Skin_Paleontologist",
		name = "Paleontologist",
		description = "Dig into prehistoric mysteries.",
		itemType = "Skin",
		rarity = "Rare",
		price = 500,
		isOnSale = false,
		isExclusive = false,
	},

	-- EMOTES (200-500 Robux)
	Emote_RaptorCall = {
		id = "Emote_RaptorCall",
		name = "Raptor Call",
		description = "Communicate like a velociraptor.",
		itemType = "Emote",
		rarity = "Rare",
		price = 500,
		isOnSale = false,
		isExclusive = false,
	},
	Emote_DinoDigging = {
		id = "Emote_DinoDigging",
		name = "Excavation",
		description = "Dig up some fossils.",
		itemType = "Emote",
		rarity = "Uncommon",
		price = 300,
		isOnSale = false,
		isExclusive = false,
	},
	Emote_JurassicDance = {
		id = "Emote_JurassicDance",
		name = "Jurassic Groove",
		description = "Dance like it's 65 million years ago.",
		itemType = "Emote",
		rarity = "Rare",
		price = 400,
		isOnSale = false,
		isExclusive = false,
	},
	Emote_ChestThump = {
		id = "Emote_ChestThump",
		name = "Primal Victory",
		description = "Assert your dominance.",
		itemType = "Emote",
		rarity = "Uncommon",
		price = 200,
		isOnSale = false,
		isExclusive = false,
	},

	-- GLIDERS (400-1000 Robux)
	Glider_PteranodonDeluxe = {
		id = "Glider_PteranodonDeluxe",
		name = "Golden Pteranodon",
		description = "Soar in prehistoric luxury.",
		itemType = "Glider",
		rarity = "Legendary",
		price = 1000,
		isOnSale = false,
		isExclusive = false,
	},
	Glider_JungleLeaf = {
		id = "Glider_JungleLeaf",
		name = "Giant Leaf",
		description = "Ride the winds on ancient foliage.",
		itemType = "Glider",
		rarity = "Rare",
		price = 600,
		isOnSale = false,
		isExclusive = false,
	},
	Glider_AmberWings = {
		id = "Glider_AmberWings",
		name = "Amber Wings",
		description = "Preserved in time, ready to fly.",
		itemType = "Glider",
		rarity = "Epic",
		price = 800,
		isOnSale = false,
		isExclusive = false,
	},

	-- BACK BLING (300-800 Robux)
	BackBling_DinoBackpack = {
		id = "BackBling_DinoBackpack",
		name = "Dino Backpack",
		description = "A friendly dinosaur friend riding along.",
		itemType = "BackBling",
		rarity = "Epic",
		price = 800,
		isOnSale = false,
		isExclusive = false,
	},
	BackBling_FossilShield = {
		id = "BackBling_FossilShield",
		name = "Fossil Shield",
		description = "Ancient bones provide protection.",
		itemType = "BackBling",
		rarity = "Rare",
		price = 500,
		isOnSale = false,
		isExclusive = false,
	},
	BackBling_AmberCrystal = {
		id = "BackBling_AmberCrystal",
		name = "Amber Crystal",
		description = "Perfectly preserved prehistoric amber.",
		itemType = "BackBling",
		rarity = "Rare",
		price = 400,
		isOnSale = false,
		isExclusive = false,
	},

	-- WEAPON SKINS (300-600 Robux)
	WeaponSkin_FossilBone = {
		id = "WeaponSkin_FossilBone",
		name = "Fossil Bone",
		description = "Weapons crafted from ancient remains.",
		itemType = "WeaponSkin",
		rarity = "Epic",
		price = 600,
		isOnSale = false,
		isExclusive = false,
	},
	WeaponSkin_LavaFlow = {
		id = "WeaponSkin_LavaFlow",
		name = "Lava Flow",
		description = "Forged in volcanic fire.",
		itemType = "WeaponSkin",
		rarity = "Rare",
		price = 450,
		isOnSale = false,
		isExclusive = false,
	},
	WeaponSkin_PrimalCamo = {
		id = "WeaponSkin_PrimalCamo",
		name = "Primal Camo",
		description = "Blend with the prehistoric jungle.",
		itemType = "WeaponSkin",
		rarity = "Uncommon",
		price = 300,
		isOnSale = false,
		isExclusive = false,
	},

	-- BUNDLES (1500-2500 Robux)
	Bundle_DinoHunterPack = {
		id = "Bundle_DinoHunterPack",
		name = "Dino Hunter Pack",
		description = "Everything you need to become the ultimate hunter.",
		itemType = "Bundle",
		rarity = "Legendary",
		price = 2500,
		originalPrice = 3500,
		isOnSale = true,
		isExclusive = false,
		bundleContents = {
			"Skin_RexHunter",
			"BackBling_DinoBackpack",
			"Glider_PteranodonDeluxe",
			"Emote_RaptorCall",
		},
	},
	Bundle_JungleExpedition = {
		id = "Bundle_JungleExpedition",
		name = "Jungle Expedition Bundle",
		description = "Gear up for adventure.",
		itemType = "Bundle",
		rarity = "Epic",
		price = 1800,
		originalPrice = 2400,
		isOnSale = true,
		isExclusive = false,
		bundleContents = {
			"Skin_JungleExplorer",
			"Glider_JungleLeaf",
			"BackBling_AmberCrystal",
		},
	},
	Bundle_StarterPack = {
		id = "Bundle_StarterPack",
		name = "Starter Pack",
		description = "Great value for new survivors.",
		itemType = "Bundle",
		rarity = "Rare",
		price = 800,
		originalPrice = 1200,
		isOnSale = true,
		isExclusive = false,
		bundleContents = {
			"Skin_SafariGuide",
			"Emote_ChestThump",
			"WeaponSkin_PrimalCamo",
		},
	},
}

-- Current shop rotation (would be managed by server in production)
ShopData.CurrentRotation: ShopRotation = {
	featured = {},
	daily = {},
	special = {},
}

-- Get item by ID
function ShopData.GetItem(id: string): ShopItem?
	return ShopData.Catalog[id]
end

-- Get items by type
function ShopData.GetByType(itemType: ShopItemType): { ShopItem }
	local result = {}
	for _, item in pairs(ShopData.Catalog) do
		if item.itemType == itemType then
			table.insert(result, item)
		end
	end
	return result
end

-- Get items by rarity
function ShopData.GetByRarity(rarity: string): { ShopItem }
	local result = {}
	for _, item in pairs(ShopData.Catalog) do
		if item.rarity == rarity then
			table.insert(result, item)
		end
	end
	return result
end

-- Get all bundles
function ShopData.GetBundles(): { ShopItem }
	return ShopData.GetByType("Bundle")
end

-- Get items on sale
function ShopData.GetOnSale(): { ShopItem }
	local result = {}
	for _, item in pairs(ShopData.Catalog) do
		if item.isOnSale then
			table.insert(result, item)
		end
	end
	return result
end

-- Calculate bundle savings
function ShopData.GetBundleSavings(bundleId: string): number
	local bundle = ShopData.Catalog[bundleId]
	if not bundle or not bundle.bundleContents then return 0 end

	local totalValue = 0
	for _, contentId in ipairs(bundle.bundleContents) do
		local item = ShopData.Catalog[contentId]
		if item then
			totalValue = totalValue + item.price
		end
	end

	return totalValue - bundle.price
end

-- Get rarity color
function ShopData.GetRarityColor(rarity: string): Color3
	if rarity == "Legendary" then
		return Color3.fromRGB(255, 180, 50)
	elseif rarity == "Epic" then
		return Color3.fromRGB(180, 100, 255)
	elseif rarity == "Rare" then
		return Color3.fromRGB(100, 150, 255)
	elseif rarity == "Uncommon" then
		return Color3.fromRGB(100, 200, 100)
	else
		return Color3.fromRGB(180, 180, 180)
	end
end

return ShopData
