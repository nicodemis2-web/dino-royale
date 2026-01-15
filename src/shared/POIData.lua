--!strict
--[[
	POIData.lua
	===========
	Defines all Points of Interest on Isla Primordial
	Based on GDD Section 3.2: Major Points of Interest
]]

local BiomeData = require(script.Parent.BiomeData)

export type POIType = "HotDrop" | "Major" | "Minor" | "Landmark"

export type POIConfig = {
	name: string,
	displayName: string,
	description: string,
	poiType: POIType,
	biome: BiomeData.BiomeType,

	-- Position (world coordinates)
	position: {
		x: number,
		y: number,
		z: number,
	},

	-- Size
	radius: number, -- Approximate POI radius

	-- Loot
	lootTier: string,
	chestCount: { min: number, max: number },
	floorLootSpawns: number,

	-- Dinosaurs
	guaranteedDinos: { string }?,
	dinoDensityMultiplier: number,

	-- Special features
	hasVehicleSpawn: boolean,
	vehicleTypes: { string }?,
	specialFeatures: { string }?,

	-- Danger
	dangerRating: number, -- 1-5
}

local POIData = {}

POIData.POIs = {
	-- JUNGLE ZONE POIs
	VisitorCenter = {
		name = "VisitorCenter",
		displayName = "Visitor Center",
		description = "The iconic main building with grand rotunda, gift shop, and restaurant. Raptors patrol the kitchen.",
		poiType = "HotDrop",
		biome = "Jungle",

		position = { x = 2000, y = 50, z = 2000 },
		radius = 150,

		lootTier = "High",
		chestCount = { min = 8, max = 12 },
		floorLootSpawns = 25,

		guaranteedDinos = { "Velociraptor", "Velociraptor" },
		dinoDensityMultiplier = 1.5,

		hasVehicleSpawn = true,
		vehicleTypes = { "Jeep" },
		specialFeatures = { "MultipleFloors", "Skylights", "KitchenRaptors" },

		dangerRating = 4,
	},

	RaptorPaddock = {
		name = "RaptorPaddock",
		displayName = "Raptor Paddock",
		description = "Fenced enclosure with walkways above. 3-5 Velociraptors always spawn here.",
		poiType = "Major",
		biome = "Jungle",

		position = { x = 1700, y = 45, z = 1800 },
		radius = 100,

		lootTier = "High",
		chestCount = { min = 4, max = 6 },
		floorLootSpawns = 12,

		guaranteedDinos = { "Velociraptor", "Velociraptor", "Velociraptor" },
		dinoDensityMultiplier = 3.0,

		hasVehicleSpawn = false,
		specialFeatures = { "Catwalks", "FeedingPen", "ObservationTower" },

		dangerRating = 5,
	},

	MaintenanceShed = {
		name = "MaintenanceShed",
		displayName = "Maintenance Shed",
		description = "Small utility building with vehicle parts and basic supplies.",
		poiType = "Minor",
		biome = "Jungle",

		position = { x = 2200, y = 48, z = 1900 },
		radius = 40,

		lootTier = "Medium",
		chestCount = { min = 2, max = 3 },
		floorLootSpawns = 6,

		dinoDensityMultiplier = 0.5,

		hasVehicleSpawn = true,
		vehicleTypes = { "ATV", "Motorcycle" },
		specialFeatures = { "WorkBench", "FuelStation" },

		dangerRating = 2,
	},

	-- PLAINS POIs
	HerbivoreValley = {
		name = "HerbivoreValley",
		displayName = "Herbivore Valley",
		description = "Wide open grassland where Triceratops and Gallimimus roam freely.",
		poiType = "Major",
		biome = "Plains",

		position = { x = 1000, y = 30, z = 2000 },
		radius = 200,

		lootTier = "Medium",
		chestCount = { min = 3, max = 5 },
		floorLootSpawns = 10,

		guaranteedDinos = { "Triceratops", "Gallimimus", "Gallimimus" },
		dinoDensityMultiplier = 1.5,

		hasVehicleSpawn = true,
		vehicleTypes = { "Jeep", "ATV" },
		specialFeatures = { "WaterHole", "GrazingGrounds" },

		dangerRating = 2,
	},

	SafariLodge = {
		name = "SafariLodge",
		displayName = "Safari Lodge",
		description = "Tourist accommodation with viewing decks overlooking the plains.",
		poiType = "Major",
		biome = "Plains",

		position = { x = 800, y = 35, z = 2200 },
		radius = 80,

		lootTier = "Medium",
		chestCount = { min = 5, max = 7 },
		floorLootSpawns = 15,

		dinoDensityMultiplier = 0.3,

		hasVehicleSpawn = true,
		vehicleTypes = { "Jeep" },
		specialFeatures = { "ViewingDeck", "GiftShop", "Restaurant" },

		dangerRating = 1,
	},

	FeedingStation = {
		name = "FeedingStation",
		displayName = "Feeding Station",
		description = "Automated herbivore feeding facility with supply storage.",
		poiType = "Minor",
		biome = "Plains",

		position = { x = 1200, y = 32, z = 1800 },
		radius = 50,

		lootTier = "Medium",
		chestCount = { min = 2, max = 4 },
		floorLootSpawns = 8,

		dinoDensityMultiplier = 2.0,

		hasVehicleSpawn = false,
		specialFeatures = { "FeedingTrough", "StorageSilo" },

		dangerRating = 2,
	},

	-- VOLCANIC REGION POIs
	GeothermalPlant = {
		name = "GeothermalPlant",
		displayName = "Geothermal Plant",
		description = "Industrial facility near the volcano. Steam vents provide cover but deal damage.",
		poiType = "HotDrop",
		biome = "Volcanic",

		position = { x = 2000, y = 80, z = 600 },
		radius = 120,

		lootTier = "High",
		chestCount = { min = 6, max = 10 },
		floorLootSpawns = 20,

		guaranteedDinos = { "Carnotaurus" },
		dinoDensityMultiplier = 0.8,

		hasVehicleSpawn = true,
		vehicleTypes = { "Jeep", "ATV" },
		specialFeatures = { "SteamVents", "ControlRoom", "Catwalks" },

		dangerRating = 4,
	},

	TRexPaddock = {
		name = "TRexPaddock",
		displayName = "T-Rex Paddock",
		description = "Massive fenced area where the T-Rex roams. Goat feeding station contains legendary loot.",
		poiType = "Major",
		biome = "Volcanic",

		position = { x = 1800, y = 70, z = 400 },
		radius = 180,

		lootTier = "VeryHigh",
		chestCount = { min = 3, max = 5 },
		floorLootSpawns = 8,

		guaranteedDinos = { "TRex" },
		dinoDensityMultiplier = 0.3,

		hasVehicleSpawn = false,
		specialFeatures = { "BrokenFence", "GoatFeeder", "ObservationTower", "LegendaryChest" },

		dangerRating = 5,
	},

	LavaCaves = {
		name = "LavaCaves",
		displayName = "Lava Caves",
		description = "Underground cave system with lava flows and rare minerals.",
		poiType = "Major",
		biome = "Volcanic",

		position = { x = 2200, y = 60, z = 500 },
		radius = 100,

		lootTier = "High",
		chestCount = { min = 4, max = 6 },
		floorLootSpawns = 12,

		dinoDensityMultiplier = 0.5,

		hasVehicleSpawn = false,
		specialFeatures = { "LavaFlows", "CrystalDeposits", "HiddenChambers" },

		dangerRating = 4,
	},

	Observatory = {
		name = "Observatory",
		displayName = "Volcano Observatory",
		description = "Scientific monitoring station on the volcano slope with excellent sightlines.",
		poiType = "Minor",
		biome = "Volcanic",

		position = { x = 2400, y = 120, z = 300 },
		radius = 60,

		lootTier = "Medium",
		chestCount = { min = 2, max = 4 },
		floorLootSpawns = 6,

		dinoDensityMultiplier = 0.2,

		hasVehicleSpawn = false,
		specialFeatures = { "Telescope", "RadioTower", "HighGround" },

		dangerRating = 3,
	},

	-- SWAMP POIs
	RiverDelta = {
		name = "RiverDelta",
		displayName = "River Delta",
		description = "Muddy river mouth where multiple waterways converge. Spinosaurus territory.",
		poiType = "Major",
		biome = "Swamp",

		position = { x = 3200, y = 20, z = 2000 },
		radius = 150,

		lootTier = "Medium",
		chestCount = { min = 4, max = 6 },
		floorLootSpawns = 14,

		guaranteedDinos = { "Spinosaurus", "Baryonyx" },
		dinoDensityMultiplier = 1.5,

		hasVehicleSpawn = true,
		vehicleTypes = { "Boat" },
		specialFeatures = { "DeepWater", "MudFlats", "Mangroves" },

		dangerRating = 4,
	},

	ResearchOutpost = {
		name = "ResearchOutpost",
		displayName = "Research Outpost",
		description = "Remote field station for studying swamp dinosaurs.",
		poiType = "Major",
		biome = "Swamp",

		position = { x = 3400, y = 25, z = 1800 },
		radius = 70,

		lootTier = "High",
		chestCount = { min = 5, max = 7 },
		floorLootSpawns = 12,

		dinoDensityMultiplier = 0.8,

		hasVehicleSpawn = true,
		vehicleTypes = { "Boat", "ATV" },
		specialFeatures = { "Laboratory", "DockedBoats", "RadioEquipment" },

		dangerRating = 3,
	},

	BoatDock = {
		name = "BoatDock",
		displayName = "Boat Dock",
		description = "Small pier with boats and fishing supplies.",
		poiType = "Minor",
		biome = "Swamp",

		position = { x = 3000, y = 18, z = 2200 },
		radius = 40,

		lootTier = "Low",
		chestCount = { min = 1, max = 3 },
		floorLootSpawns = 5,

		dinoDensityMultiplier = 0.5,

		hasVehicleSpawn = true,
		vehicleTypes = { "Boat", "Boat" },
		specialFeatures = { "FishingSupplies", "FuelBarrels" },

		dangerRating = 2,
	},

	-- COASTAL POIs
	Harbor = {
		name = "Harbor",
		displayName = "Harbor",
		description = "Main port facility with cargo containers and warehouses.",
		poiType = "HotDrop",
		biome = "Coast",

		position = { x = 2000, y = 10, z = 3400 },
		radius = 130,

		lootTier = "High",
		chestCount = { min = 7, max = 10 },
		floorLootSpawns = 22,

		dinoDensityMultiplier = 0.4,

		hasVehicleSpawn = true,
		vehicleTypes = { "Boat", "Jeep" },
		specialFeatures = { "CargoContainers", "Cranes", "Warehouses" },

		dangerRating = 3,
	},

	Lighthouse = {
		name = "Lighthouse",
		displayName = "Lighthouse",
		description = "Tall lighthouse with excellent view of the coast and surrounding waters.",
		poiType = "Minor",
		biome = "Coast",

		position = { x = 1600, y = 15, z = 3600 },
		radius = 30,

		lootTier = "Medium",
		chestCount = { min = 2, max = 3 },
		floorLootSpawns = 4,

		dinoDensityMultiplier = 0.2,

		hasVehicleSpawn = false,
		specialFeatures = { "HighGround", "Spotlight", "SniperNest" },

		dangerRating = 2,
	},

	BeachResort = {
		name = "BeachResort",
		displayName = "Beach Resort",
		description = "Luxury resort with pool, cabanas, and beach access.",
		poiType = "Major",
		biome = "Coast",

		position = { x = 2400, y = 8, z = 3500 },
		radius = 100,

		lootTier = "Medium",
		chestCount = { min = 5, max = 8 },
		floorLootSpawns = 16,

		guaranteedDinos = { "Pteranodon" },
		dinoDensityMultiplier = 0.5,

		hasVehicleSpawn = true,
		vehicleTypes = { "ATV", "Boat" },
		specialFeatures = { "Pool", "Cabanas", "BeachBar" },

		dangerRating = 2,
	},

	Aviary = {
		name = "Aviary",
		displayName = "Aviary",
		description = "Large dome structure housing flying reptiles. Watch the skies.",
		poiType = "Major",
		biome = "Coast",

		position = { x = 1800, y = 20, z = 3200 },
		radius = 90,

		lootTier = "Medium",
		chestCount = { min = 4, max = 6 },
		floorLootSpawns = 10,

		guaranteedDinos = { "Pteranodon", "Pteranodon", "Dimorphodon" },
		dinoDensityMultiplier = 2.5,

		hasVehicleSpawn = false,
		specialFeatures = { "BrokenDome", "Nests", "Catwalks" },

		dangerRating = 3,
	},

	-- RESEARCH COMPLEX POIs
	MainLab = {
		name = "MainLab",
		displayName = "Main Laboratory",
		description = "Central research facility with multiple floors. Highest-tier loot but may spawn Indoraptor.",
		poiType = "HotDrop",
		biome = "Research",

		position = { x = 2400, y = 40, z = 1600 },
		radius = 140,

		lootTier = "VeryHigh",
		chestCount = { min = 10, max = 15 },
		floorLootSpawns = 30,

		guaranteedDinos = { "Velociraptor" },
		dinoDensityMultiplier = 0.8,

		hasVehicleSpawn = true,
		vehicleTypes = { "Jeep" },
		specialFeatures = { "MultipleFloors", "SecurityDoors", "EmergencyLockdown", "IndoraptorCage" },

		dangerRating = 5,
	},

	Hatchery = {
		name = "Hatchery",
		displayName = "Hatchery",
		description = "Dinosaur egg incubation facility with valuable genetic samples.",
		poiType = "Major",
		biome = "Research",

		position = { x = 2600, y = 38, z = 1500 },
		radius = 70,

		lootTier = "High",
		chestCount = { min = 4, max = 6 },
		floorLootSpawns = 12,

		dinoDensityMultiplier = 0.3,

		hasVehicleSpawn = false,
		specialFeatures = { "Incubators", "GeneticSamples", "ControlRoom" },

		dangerRating = 3,
	},

	ControlRoom = {
		name = "ControlRoom",
		displayName = "Control Room",
		description = "Central command for the entire park. Contains keycard for restricted areas.",
		poiType = "Major",
		biome = "Research",

		position = { x = 2300, y = 42, z = 1700 },
		radius = 50,

		lootTier = "High",
		chestCount = { min = 3, max = 5 },
		floorLootSpawns = 8,

		dinoDensityMultiplier = 0.2,

		hasVehicleSpawn = false,
		specialFeatures = { "SecurityMonitors", "Keycard", "EmergencyControls" },

		dangerRating = 3,
	},

	ServerHub = {
		name = "ServerHub",
		displayName = "Server Hub",
		description = "Underground data center with backup power and secure storage.",
		poiType = "Minor",
		biome = "Research",

		position = { x = 2500, y = 30, z = 1750 },
		radius = 45,

		lootTier = "High",
		chestCount = { min = 3, max = 4 },
		floorLootSpawns = 6,

		dinoDensityMultiplier = 0.1,

		hasVehicleSpawn = false,
		specialFeatures = { "ServerRacks", "CoolingSystem", "SecureVault" },

		dangerRating = 2,
	},

	-- SPECIAL LOCATIONS
	HammondsVilla = {
		name = "HammondsVilla",
		displayName = "Hammond's Villa",
		description = "Luxurious hilltop mansion with excellent sightlines. Contains hidden bunker.",
		poiType = "Major",
		biome = "Jungle",

		position = { x = 2100, y = 90, z = 2200 },
		radius = 80,

		lootTier = "VeryHigh",
		chestCount = { min = 6, max = 8 },
		floorLootSpawns = 14,

		dinoDensityMultiplier = 0.3,

		hasVehicleSpawn = true,
		vehicleTypes = { "Helicopter" },
		specialFeatures = { "HelicopterPad", "HiddenBunker", "AmberCollection", "ViewingDeck" },

		dangerRating = 3,
	},
}

-- Get all POIs in a biome
function POIData.GetPOIsInBiome(biome: BiomeData.BiomeType): { POIConfig }
	local result = {}
	for _, poi in pairs(POIData.POIs) do
		if poi.biome == biome then
			table.insert(result, poi)
		end
	end
	return result
end

-- Get POI by type
function POIData.GetPOIsByType(poiType: POIType): { POIConfig }
	local result = {}
	for _, poi in pairs(POIData.POIs) do
		if poi.poiType == poiType then
			table.insert(result, poi)
		end
	end
	return result
end

-- Get hot drop locations
function POIData.GetHotDrops(): { POIConfig }
	return POIData.GetPOIsByType("HotDrop")
end

-- Get nearest POI to position
function POIData.GetNearestPOI(x: number, z: number): POIConfig?
	local nearest: POIConfig? = nil
	local nearestDist = math.huge

	for _, poi in pairs(POIData.POIs) do
		local dx = x - poi.position.x
		local dz = z - poi.position.z
		local dist = math.sqrt(dx * dx + dz * dz)

		if dist < nearestDist then
			nearestDist = dist
			nearest = poi
		end
	end

	return nearest
end

-- Check if position is inside a POI
function POIData.IsInsidePOI(x: number, z: number): (boolean, POIConfig?)
	for _, poi in pairs(POIData.POIs) do
		local dx = x - poi.position.x
		local dz = z - poi.position.z
		local dist = math.sqrt(dx * dx + dz * dz)

		if dist <= poi.radius then
			return true, poi
		end
	end

	return false, nil
end

-- Get loot tier color for minimap
function POIData.GetTierColor(lootTier: string): Color3
	local colors = {
		Low = Color3.fromRGB(150, 150, 150),
		["Low-Medium"] = Color3.fromRGB(100, 180, 100),
		Medium = Color3.fromRGB(100, 150, 255),
		["Medium-High"] = Color3.fromRGB(180, 100, 255),
		High = Color3.fromRGB(255, 180, 0),
		VeryHigh = Color3.fromRGB(255, 100, 100),
	}
	return colors[lootTier] or Color3.fromRGB(200, 200, 200)
end

-- Get POI position as Vector3
function POIData.GetPosition(poi: POIConfig): Vector3
	return Vector3.new(poi.position.x, poi.position.y, poi.position.z)
end

-- Get POI icon based on type
function POIData.GetIcon(poi: POIConfig): string
	local icons = {
		HotDrop = "rbxassetid://0", -- Would be actual asset IDs
		Major = "rbxassetid://0",
		Minor = "rbxassetid://0",
		Landmark = "rbxassetid://0",
	}
	return icons[poi.poiType] or ""
end

return POIData
