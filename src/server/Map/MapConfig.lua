--!strict
--[[
	MapConfig.lua
	=============
	Centralized configuration for all map generation parameters.

	This module extracts all hardcoded values from MapManager.lua
	to enable easy adjustment and testing without code changes.

	USAGE:
	```lua
	local MapConfig = require(script.Parent.MapConfig)
	local mapSize = MapConfig.MapSize
	```

	@server
]]

local MapConfig = {}

--------------------------------------------------------------------------------
-- MAP DIMENSIONS
--------------------------------------------------------------------------------

-- Total map size in studs (4km x 4km)
MapConfig.MapSize = 4000

-- Cell size for terrain generation (balance of detail vs performance)
MapConfig.Resolution = 32

-- Base terrain height above water level
MapConfig.BaseHeight = 15

-- Water level (Y position)
MapConfig.WaterLevel = -2

--------------------------------------------------------------------------------
-- SPAWN AREA CONFIGURATION
--------------------------------------------------------------------------------

-- Position of the spawn area center
MapConfig.SpawnPosition = Vector3.new(200, 0, 200)

-- Size of the spawn area (diameter)
MapConfig.SpawnAreaSize = 200

-- Height of the spawn area terrain
MapConfig.SpawnHeight = 30

--------------------------------------------------------------------------------
-- BIOME CENTERS
-- Used for POI placement and environmental feature distribution
--------------------------------------------------------------------------------

MapConfig.BiomeCenters = {
	Plains = Vector3.new(-1200, 20, 0),
	Volcanic = Vector3.new(0, 50, -1400),
	Swamp = Vector3.new(1200, 12, 0),
	Coastal = Vector3.new(0, 10, 1400),
	Jungle = Vector3.new(0, 25, 0),
}

--------------------------------------------------------------------------------
-- VEGETATION COUNTS
-- Number of vegetation items to generate per biome
--------------------------------------------------------------------------------

MapConfig.Vegetation = {
	-- Tree clusters per biome
	JungleTreeClusters = 25,
	JungleIndividualTrees = 80,
	PlainsTreeClusters = 15,
	PlainsBirchTrees = 30,
	VolcanicTrees = 25,
	SwampTreeClusters = 20,
	SwampIndividualTrees = 40,
	CoastalTreeClusters = 15,
	CoastalIndividualTrees = 50,

	-- Bushes and undergrowth
	TotalBushes = 100,
	JungleFerns = 60,
	SwampFerns = 40,
	SpawnAreaBushes = 15,

	-- Flower patches
	JungleFlowerPatches = 15,
	PlainsFlowerPatches = 25,
	CoastalFlowerPatches = 20,
	PlainsDetailFlowers = 30,
	CoastalDetailFlowers = 20,

	-- Grass patches
	JungleGrassPatches = 20,
	PlainsGrassPatches = 30,

	-- Rock formations
	PlainsRockFormations = 8,
	VolcanicRockFormations = 20,
	VolcanicScatteredRocks = 60,
	CoastalRockFormations = 12,
	FinalRockDetails = 40,
}

--------------------------------------------------------------------------------
-- LOOT CONFIGURATION
--------------------------------------------------------------------------------

-- Number of loot caches near spawn
MapConfig.LootCachesNearSpawn = 36

-- Radius for loot cache distribution around spawn (in studs)
MapConfig.LootCacheRadius = 300

-- Loot cache types and their relative weights
MapConfig.LootCacheTypes = {
	"weapon_crate",
	"weapon_crate",
	"ammo_box",
	"ammo_box",
	"medkit",
	"supply_drop",
}

-- Ring-based loot distribution
MapConfig.LootRingDistances = {
	Inner = 80,  -- First ring distance from spawn
	Outer = 200, -- Second ring distance from spawn
}

--------------------------------------------------------------------------------
-- WATER SYSTEM CONFIGURATION
--------------------------------------------------------------------------------

MapConfig.Water = {
	-- Ocean (South)
	OceanDepth = 25,
	OceanWaterDepth = 15,

	-- Rivers
	Rivers = {
		{
			Name = "VolcanicToSwamp",
			Start = Vector3.new(-200, 0, -1200),
			End = Vector3.new(1000, 0, 0),
			Width = 60,
			Depth = 12,
		},
		{
			Name = "JungleToCoast",
			Start = Vector3.new(0, 0, -400),
			End = Vector3.new(200, 0, 1200),
			Width = 50,
			Depth = 10,
		},
		{
			Name = "PlainsToCoast",
			Start = Vector3.new(-1200, 0, -200),
			End = Vector3.new(-400, 0, 1000),
			Width = 45,
			Depth = 10,
		},
		{
			Name = "SwampDelta1",
			Start = Vector3.new(800, 0, -300),
			End = Vector3.new(1400, 0, 200),
			Width = 40,
			Depth = 8,
		},
		{
			Name = "SwampDelta2",
			Start = Vector3.new(1000, 0, 100),
			End = Vector3.new(1500, 0, 400),
			Width = 35,
			Depth = 8,
		},
	},

	-- Lakes
	Lakes = {
		-- Central
		{ Name = "CentralLake", Position = Vector3.new(0, 0, 0), Radius = 200, Depth = 15 },
		-- Jungle
		{ Name = "JungleLake1", Position = Vector3.new(-400, 0, -300), Radius = 120, Depth = 12 },
		{ Name = "JungleLake2", Position = Vector3.new(350, 0, -150), Radius = 100, Depth = 10 },
		-- Plains
		{ Name = "PlainsLake1", Position = Vector3.new(-1000, 0, 200), Radius = 150, Depth = 12 },
		{ Name = "PlainsLake2", Position = Vector3.new(-800, 0, -400), Radius = 80, Depth = 8 },
		-- Swamp (shallow)
		{ Name = "SwampLake1", Position = Vector3.new(900, 0, -200), Radius = 100, Depth = 6 },
		{ Name = "SwampLake2", Position = Vector3.new(1100, 0, 300), Radius = 120, Depth = 7 },
		{ Name = "SwampLake3", Position = Vector3.new(1300, 0, -100), Radius = 90, Depth = 5 },
		-- Volcanic Crater
		{ Name = "CraterLake", Position = Vector3.new(200, 0, -1500), Radius = 100, Depth = 20 },
		-- Coastal Lagoons
		{ Name = "Lagoon1", Position = Vector3.new(-600, 0, 1100), Radius = 130, Depth = 8 },
		{ Name = "Lagoon2", Position = Vector3.new(500, 0, 1000), Radius = 110, Depth = 8 },
	},
}

--------------------------------------------------------------------------------
-- CAVE CONFIGURATION
--------------------------------------------------------------------------------

MapConfig.Caves = {
	-- Volcanic caves (lava caves)
	{ Position = Vector3.new(-300, 45, -1300), Depth = 80, Width = 25, Height = 15 },
	{ Position = Vector3.new(100, 50, -1400), Depth = 60, Width = 20, Height = 12 },
	{ Position = Vector3.new(400, 40, -1200), Depth = 70, Width = 22, Height = 14 },
	{ Position = Vector3.new(-500, 55, -1500), Depth = 50, Width = 18, Height = 10 },
	-- Jungle hillside caves
	{ Position = Vector3.new(-200, 35, -100), Depth = 50, Width = 18, Height = 12 },
	{ Position = Vector3.new(250, 30, 100), Depth = 45, Width = 16, Height = 10 },
	{ Position = Vector3.new(-350, 40, 200), Depth = 55, Width = 20, Height = 12 },
}

--------------------------------------------------------------------------------
-- PERFORMANCE CONFIGURATION
--------------------------------------------------------------------------------

-- Number of terrain cells before yielding
MapConfig.TerrainYieldInterval = 150

-- Number of vegetation items before yielding
MapConfig.VegetationYieldInterval = 10

-- Number of tree cluster items before yielding
MapConfig.TreeClusterYieldInterval = 5

--------------------------------------------------------------------------------
-- BUILDING COUNTS
--------------------------------------------------------------------------------

MapConfig.Buildings = {
	-- Scattered multi-story apartments
	Apartments = {
		{ Name = "Apartments_Jungle1", Position = Vector3.new(-150, 25, 350), Floors = 3 },
		{ Name = "Apartments_Plains1", Position = Vector3.new(-900, 18, 300), Floors = 2 },
		{ Name = "Apartments_Coast1", Position = Vector3.new(-200, 10, 1100), Floors = 4 },
		{ Name = "Apartments_Coast2", Position = Vector3.new(600, 10, 900), Floors = 3 },
	},

	-- Warehouses
	Warehouses = {
		{ Name = "Warehouse_Jungle1", Position = Vector3.new(450, 25, 200) },
		{ Name = "Warehouse_Swamp1", Position = Vector3.new(800, 12, -300) },
	},

	-- Scattered houses
	Houses = {
		{ Position = Vector3.new(-500, 25, -400), Size = 16 },
		{ Position = Vector3.new(400, 25, 300), Size = 14 },
		{ Position = Vector3.new(-700, 18, -300), Size = 12 },
		{ Position = Vector3.new(-1400, 18, 400), Size = 15 },
		{ Position = Vector3.new(-1000, 18, -500), Size = 14 },
		{ Position = Vector3.new(700, 12, 400), Size = 13 },
		{ Position = Vector3.new(1000, 12, -400), Size = 12 },
		{ Position = Vector3.new(-300, 10, 900), Size = 14 },
		{ Position = Vector3.new(300, 10, 800), Size = 15 },
		{ Position = Vector3.new(-600, 10, 1200), Size = 13 },
	},

	-- Number of small sheds to scatter
	ShedCount = 15,

	-- Guard towers
	GuardTowers = {
		{ Name = "GuardTower1", Position = Vector3.new(-600, 25, 0), Height = 20 },
		{ Name = "GuardTower2", Position = Vector3.new(600, 25, -400), Height = 22 },
		{ Name = "GuardTower3", Position = Vector3.new(-1500, 18, -200), Height = 18 },
		{ Name = "GuardTower4", Position = Vector3.new(0, 10, 800), Height = 20 },
	},

	-- Research buildings
	ResearchBuildings = {
		{ Name = "Research1", Position = Vector3.new(-100, 25, -500), Floors = 2, Footprint = Vector3.new(30, 12, 25) },
		{ Name = "Research2", Position = Vector3.new(500, 25, -350), Floors = 2, Footprint = Vector3.new(25, 12, 20) },
	},

	-- Volcanic ruins
	Ruins = {
		{ Name = "VolcanicRuins1", Position = Vector3.new(-600, 0, 100), Size = 30 },
		{ Name = "VolcanicRuins2", Position = Vector3.new(500, 0, -200), Size = 25 },
		{ Name = "VolcanicRuins3", Position = Vector3.new(200, 0, 400), Size = 35 },
	},

	-- Swamp stilt houses
	StiltHouseCount = 6,

	-- Coastal cabanas
	CabanaCount = 6,

	-- Safari cabins
	SafariCabinCount = 5,
}

--------------------------------------------------------------------------------
-- POI BUILDING STYLES
--------------------------------------------------------------------------------

MapConfig.POIStyles = {
	Residential = {
		WallColor = BrickColor.new("Brick yellow"),
		RoofColor = BrickColor.new("Brown"),
		WindowColor = BrickColor.new("Cyan"),
		InteriorWallColor = BrickColor.new("Institutional white"),
	},
	Commercial = {
		WallColor = BrickColor.new("Medium stone grey"),
		RoofColor = BrickColor.new("Dark stone grey"),
		WindowColor = BrickColor.new("Light blue"),
		InteriorWallColor = BrickColor.new("White"),
	},
	Industrial = {
		WallColor = BrickColor.new("Dark stone grey"),
		RoofColor = BrickColor.new("Really black"),
		WindowColor = BrickColor.new("Medium stone grey"),
		InteriorWallColor = BrickColor.new("Medium stone grey"),
	},
}

--------------------------------------------------------------------------------
-- TREE TYPE MAPPINGS
-- Maps old tree type names to FloraGenerator tree types and biomes
--------------------------------------------------------------------------------

MapConfig.TreeTypeMap = {
	pine = "CoastalPine",
	oak = "Oak",
	birch = "Birch",
	jungle = "JungleGiant",
	jungleMedium = "JungleMedium",
	palm = "Palm",
	dead = "DeadTree",
	cypress = "Cypress",
	charred = "CharredTree",
	heatResistant = "HeatResistant",
}

MapConfig.TreeBiomeMap = {
	pine = "Coastal",
	oak = "Plains",
	birch = "Plains",
	jungle = "Jungle",
	jungleMedium = "Jungle",
	palm = "Coastal",
	dead = "Swamp",
	cypress = "Swamp",
	charred = "Volcanic",
	heatResistant = "Volcanic",
}

--------------------------------------------------------------------------------
-- LAVA POOL CONFIGURATION
--------------------------------------------------------------------------------

MapConfig.LavaPoolCount = 8

--------------------------------------------------------------------------------
-- HELPER FUNCTIONS
--------------------------------------------------------------------------------

--[[
	Get the biome center position
]]
function MapConfig.GetBiomeCenter(biomeName: string): Vector3?
	return MapConfig.BiomeCenters[biomeName]
end

--[[
	Get all lake configurations
]]
function MapConfig.GetLakes(): { any }
	return MapConfig.Water.Lakes
end

--[[
	Get all river configurations
]]
function MapConfig.GetRivers(): { any }
	return MapConfig.Water.Rivers
end

--[[
	Get all cave configurations
]]
function MapConfig.GetCaves(): { any }
	return MapConfig.Caves
end

--[[
	Get spawn center as Vector3
]]
function MapConfig.GetSpawnCenter(): Vector3
	return Vector3.new(
		MapConfig.SpawnPosition.X,
		MapConfig.SpawnHeight,
		MapConfig.SpawnPosition.Z
	)
end

return MapConfig
