--!strict
--[[
	MapManager.lua
	==============
	Central coordinator for all map-related systems in Dino Royale.

	RESPONSIBILITIES:
	- Coordinates BiomeManager, POIManager, and EnvironmentalEventManager
	- Provides unified API for querying map state at any position
	- Handles match phase transitions and their effects on the map
	- Serves map data to clients for minimap and UI display

	ARCHITECTURE:
	MapManager acts as a facade pattern, delegating to specialized managers:
	- BiomeManager: Terrain types, danger levels, loot multipliers
	- POIManager: Points of interest, hot drops, landmarks
	- EnvironmentalEventManager: Dynamic events (stampedes, migrations)

	USAGE:
	```lua
	local MapManager = require(path.to.MapManager)
	MapManager.Initialize()

	-- Query map state
	local biome = MapManager.GetBiomeAtPosition(100, 200)
	local danger = MapManager.GetDangerLevelAtPosition(100, 200)
	```

	@server
	@singleton
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

--------------------------------------------------------------------------------
-- MODULE DEPENDENCIES
--------------------------------------------------------------------------------

-- Server-side managers (handle specific subsystems)
local BiomeManager = require(script.Parent.BiomeManager)
local POIManager = require(script.Parent.POIManager)
local EnvironmentalEventManager = require(script.Parent.EnvironmentalEventManager)
local FloraGenerator = require(script.Parent.FloraGenerator)
local EnvironmentalPropsGenerator = require(script.Parent.EnvironmentalPropsGenerator)
local LootManager = require(script.Parent.Parent.Loot.LootManager)

-- Configuration module (all hardcoded values extracted here)
local MapConfig = require(script.Parent.MapConfig)

-- Shared data modules (read-only configuration)
local BiomeData = require(ReplicatedStorage.Shared.BiomeData)
local POIData = require(ReplicatedStorage.Shared.POIData)
local Events = require(ReplicatedStorage.Shared.Events)

--------------------------------------------------------------------------------
-- MODULE DECLARATION
--------------------------------------------------------------------------------

local MapManager = {}

--------------------------------------------------------------------------------
-- STATE VARIABLES
--------------------------------------------------------------------------------

-- Initialization flag to prevent double-init
local isInitialized = false

-- Current match phase affects environmental events and loot spawning
-- Values: "Lobby", "Deploying", "Playing", "Ending"
local currentMatchPhase = "Lobby"

-- Height cache to reduce raycast usage
local heightCache: { [string]: number } = {}

-- Generation results tracking
local generationResults: { [string]: boolean } = {}

--------------------------------------------------------------------------------
-- CONSTANTS
--------------------------------------------------------------------------------

--[[
	MAP_INFO: Static map configuration
	- name: Display name shown in UI
	- size: Total map dimensions in studs
	- center: World coordinates of map center
	- biomeCount: Number of distinct biome regions
	- poiCount: Number of POIs (populated during initialization)
]]
local MAP_INFO = {
	name = "Isla Primordial",
	size = BiomeData.MapSize,
	center = BiomeData.MapCenter,
	biomeCount = 6,
	poiCount = 0, -- Set during init
}

--------------------------------------------------------------------------------
-- ERROR HANDLING & LOGGING HELPERS
--------------------------------------------------------------------------------

--[[
	Execute a function with error handling and logging.
	Replaces silent pcall failures with proper error logging.

	@param phaseName The name of the phase being executed
	@param func The function to execute
	@return boolean Whether the function executed successfully
]]
local function safeExecute(phaseName: string, func: () -> ()): boolean
	local success, err = pcall(func)
	if not success then
		warn(`[MapManager] {phaseName} FAILED: {err}`)
		generationResults[phaseName] = false
		return false
	end
	print(`[MapManager] {phaseName} completed`)
	generationResults[phaseName] = true
	return true
end

--[[
	Print a summary of the generation process.
]]
local function printGenerationSummary()
	print("===========================================")
	print("[MapManager] GENERATION SUMMARY")
	local allSucceeded = true
	for phase, success in pairs(generationResults) do
		local status = success and "OK" or "FAILED"
		print(`  {phase}: {status}`)
		if not success then
			allSucceeded = false
		end
	end
	if allSucceeded then
		print("  All phases completed successfully!")
	else
		warn("  Some phases failed - map may be incomplete")
	end
	print("===========================================")
end

--------------------------------------------------------------------------------
-- FOLDER MANAGEMENT
--------------------------------------------------------------------------------

--[[
	Get or create a folder in workspace for organizing objects.
	Improves cleanup and organization.

	@param name The name of the folder
	@return Folder The folder instance
]]
local function getOrCreateFolder(name: string): Folder
	local existing = workspace:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing :: Folder
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = workspace
	return folder
end

-- Pre-create folders for organization
local foldersCreated = false
local function ensureFoldersExist()
	if foldersCreated then return end
	getOrCreateFolder("Trees")
	getOrCreateFolder("Bushes")
	getOrCreateFolder("Ferns")
	getOrCreateFolder("Flowers")
	getOrCreateFolder("Rocks")
	getOrCreateFolder("Buildings")
	getOrCreateFolder("Structures")
	getOrCreateFolder("LootCaches")
	foldersCreated = true
end

--------------------------------------------------------------------------------
-- HEIGHT CACHING
--------------------------------------------------------------------------------

--[[
	Cache terrain height to reduce raycast usage.

	@param x World X coordinate
	@param z World Z coordinate
	@param height The height at this position
]]
local function cacheTerrainHeight(x: number, z: number, height: number)
	local key = `{math.floor(x / 32)}_{math.floor(z / 32)}`
	heightCache[key] = height
end

--[[
	Get cached height or perform raycast.

	@param x World X coordinate
	@param z World Z coordinate
	@param defaultY Fallback height if not found
	@return number The height at this position
]]
local function getCachedHeight(x: number, z: number, defaultY: number?): number
	local key = `{math.floor(x / 32)}_{math.floor(z / 32)}`
	if heightCache[key] then
		return heightCache[key]
	end
	return getGroundLevel(x, z, defaultY or 25)
end

--[[
	Clear the height cache (for match reset).
]]
local function clearHeightCache()
	heightCache = {}
end

--------------------------------------------------------------------------------
-- GROUND LEVEL HELPER FUNCTIONS
--------------------------------------------------------------------------------

-- Raycast to find ground level at a position
function getGroundLevel(x: number, z: number, defaultY: number?): number
	local rayOrigin = Vector3.new(x, 500, z)
	local rayResult = workspace:Raycast(rayOrigin, Vector3.new(0, -600, 0))
	if rayResult then
		local height = rayResult.Position.Y
		cacheTerrainHeight(x, z, height)
		return height
	end
	return defaultY or 25
end

-- Place object at ground level
local function placeAtGroundLevel(position: Vector3, offsetY: number?): Vector3
	local groundY = getCachedHeight(position.X, position.Z, position.Y)
	return Vector3.new(position.X, groundY + (offsetY or 0), position.Z)
end

--------------------------------------------------------------------------------
-- PUBLIC API: MAP INFO
--------------------------------------------------------------------------------

--[[
	Get map information
]]
function MapManager.GetMapInfo(): typeof(MAP_INFO)
	return MAP_INFO
end

--[[
	Get complete map data for client
]]
function MapManager.GetMapDataForClient(): any
	local biomes = {}
	for biomeName, config in pairs(BiomeData.Biomes) do
		biomes[biomeName] = {
			name = config.name,
			displayName = config.displayName,
			sector = config.sector,
			dangerLevel = BiomeData.GetDangerLevel(biomeName :: BiomeData.BiomeType),
		}
	end

	local pois = {}
	for poiName, config in pairs(POIData.POIs) do
		pois[poiName] = {
			name = config.name,
			displayName = config.displayName,
			position = config.position,
			poiType = config.poiType,
			biome = config.biome,
			dangerRating = config.dangerRating,
			hasVehicles = config.hasVehicleSpawn,
		}
	end

	return {
		mapName = MAP_INFO.name,
		mapSize = MAP_INFO.size,
		biomes = biomes,
		pois = pois,
		hotDrops = POIManager.GetHotDropLocations(),
	}
end

--[[
	Get biome at position
]]
function MapManager.GetBiomeAtPosition(x: number, z: number): BiomeData.BiomeType
	return BiomeData.GetBiomeAtPosition(x, z)
end

--[[
	Get POI at position
]]
function MapManager.GetPOIAtPosition(x: number, z: number): POIData.POIConfig?
	return POIManager.GetPOIAtPosition(x, z)
end

--[[
	Get danger level at position
]]
function MapManager.GetDangerLevelAtPosition(x: number, z: number): number
	local poi = POIManager.GetPOIAtPosition(x, z)
	if poi then
		return poi.dangerRating
	end

	return BiomeManager.GetDangerLevelAtPosition(x, z)
end

--[[
	Get loot multiplier at position
]]
function MapManager.GetLootMultiplierAtPosition(x: number, z: number): number
	return BiomeManager.GetLootMultiplierAtPosition(x, z)
end

--[[
	Get dinosaur spawn config at position
]]
function MapManager.GetDinosaurConfigAtPosition(x: number, z: number): { types: { string }, density: number }
	local poi = POIManager.GetPOIAtPosition(x, z)

	if poi then
		return {
			types = poi.guaranteedDinos or {},
			density = poi.dinoDensityMultiplier,
		}
	end

	return BiomeManager.GetDinosaurConfigAtPosition(x, z)
end

--[[
	Record gunfire for environmental events
]]
function MapManager.RecordGunfire(position: Vector3)
	EnvironmentalEventManager.RecordGunfire(position)
end

--[[
	Trigger environmental event
]]
function MapManager.TriggerEnvironmentalEvent(eventType: string): boolean
	return EnvironmentalEventManager.TriggerEvent(eventType :: any)
end

--[[
	Handle match phase changes
]]
function MapManager.OnMatchPhaseChanged(phase: string)
	currentMatchPhase = phase

	if phase == "Playing" then
		-- Mid-game events become possible
		task.delay(300, function() -- 5 minutes into match
			if currentMatchPhase == "Playing" then
				EnvironmentalEventManager.OnMidGame()
			end
		end)
	end
end

--[[
	Setup event handlers
]]
local function setupEventHandlers()
	-- Client requests map data
	Events.OnServerEvent("Map", "RequestMapData", function(player)
		Events.FireClient(player, "Map", "MapData", MapManager.GetMapDataForClient())
	end)

	-- Client requests POI info
	Events.OnServerEvent("Map", "RequestPOIInfo", function(player, data)
		local poiName = data.poiName
		local state = POIManager.GetPOIState(poiName)
		local config = POIData.POIs[poiName]

		if state and config then
			Events.FireClient(player, "Map", "POIInfo", {
				name = poiName,
				config = config,
				state = state,
			})
		end
	end)
end

--------------------------------------------------------------------------------
-- BIOME HELPERS
--------------------------------------------------------------------------------

--[[
	Get biome at world position based on GDD layout
	Uses quadrant-based system with smooth transitions
]]
local function getBiomeAtPosition(x: number, z: number): string
	local halfSize = MapConfig.MapSize / 2

	-- Normalize to -1 to 1 range
	local nx = x / halfSize
	local nz = z / halfSize

	-- Distance from center for coastal detection
	local distFromCenter = math.sqrt(nx * nx + nz * nz)

	-- SOUTH (z > 0.5): Coastal Area
	if nz > 0.4 and distFromCenter > 0.5 then
		return "coastal"
	end

	-- NORTH (z < -0.4): Volcanic Region
	if nz < -0.4 then
		return "volcanic"
	end

	-- EAST (x > 0.4): Swamplands
	if nx > 0.4 then
		return "swamp"
	end

	-- WEST (x < -0.4): Open Plains
	if nx < -0.4 then
		return "plains"
	end

	-- CENTER: Jungle (default for main play area)
	return "jungle"
end

--[[
	Get terrain height at position based on biome
]]
local function getHeightAtPosition(x: number, z: number, biome: string): number
	local base = MapConfig.BaseHeight

	-- Multi-octave noise for natural terrain
	local noise1 = math.noise(x / 300, z / 300, 1) * 20  -- Large features
	local noise2 = math.noise(x / 100, z / 100, 2) * 10  -- Medium features
	local noise3 = math.noise(x / 40, z / 40, 3) * 5     -- Small details

	if biome == "jungle" then
		local jungleBase = math.noise(x / 150, z / 150, 4) * 15
		return base + noise1 + noise2 + noise3 + jungleBase + 10

	elseif biome == "plains" then
		local plainNoise = math.noise(x / 200, z / 200, 5) * 8
		return base + plainNoise + noise3 * 0.5

	elseif biome == "volcanic" then
		local volcanoBase = math.noise(x / 120, z / 120, 6) * 40
		local peaks = math.max(0, math.noise(x / 60, z / 60, 7)) * 35
		local ridges = math.abs(math.noise(x / 80, z / 80, 8)) * 20
		return base + volcanoBase + peaks + ridges + 15

	elseif biome == "swamp" then
		local swampBase = math.noise(x / 100, z / 100, 9) * 8
		local channels = math.abs(math.noise(x / 50, z / 50, 10)) * 5
		return base + swampBase - channels - 5

	elseif biome == "coastal" then
		local distFromCenter = math.sqrt(x * x + z * z)
		local normalizedDist = distFromCenter / (MapConfig.MapSize / 2)
		local coastSlope = (1 - normalizedDist) * 15
		local dunes = math.noise(x / 80, z / 80, 11) * 5
		return math.max(0, coastSlope + dunes)
	end

	return base + noise1
end

--[[
	Get terrain material based on biome and height
]]
local function getMaterialAtPosition(biome: string, height: number): Enum.Material
	if biome == "jungle" then
		if height > 40 then
			return Enum.Material.Rock
		elseif height > 25 then
			return Enum.Material.LeafyGrass
		else
			return Enum.Material.Grass
		end

	elseif biome == "plains" then
		if height > 20 then
			return Enum.Material.Grass
		else
			return Enum.Material.Ground
		end

	elseif biome == "volcanic" then
		if height > 70 then
			return Enum.Material.CrackedLava
		elseif height > 50 then
			return Enum.Material.Basalt
		elseif height > 35 then
			return Enum.Material.Slate
		else
			return Enum.Material.Rock
		end

	elseif biome == "swamp" then
		if height > 15 then
			return Enum.Material.LeafyGrass
		elseif height > 8 then
			return Enum.Material.Mud
		else
			return Enum.Material.Ground
		end

	elseif biome == "coastal" then
		if height > 10 then
			return Enum.Material.Grass
		else
			return Enum.Material.Sand
		end
	end

	return Enum.Material.Grass
end

--------------------------------------------------------------------------------
-- BUILDING AND STRUCTURE CREATION HELPERS
--------------------------------------------------------------------------------

-- Create a simple building structure (anchored at ground level)
local function createBuilding(name: string, position: Vector3, size: Vector3, color: BrickColor, material: Enum.Material?): Model
	local building = Instance.new("Model")
	building.Name = name

	local groundPos = placeAtGroundLevel(position, 0)
	local mat = material or Enum.Material.Concrete

	-- Floor
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = Vector3.new(size.X, 1, size.Z)
	floor.Position = groundPos + Vector3.new(0, 0.5, 0)
	floor.Anchored = true
	floor.BrickColor = BrickColor.new("Medium stone grey")
	floor.Material = Enum.Material.Concrete
	floor.Parent = building

	-- Walls
	local wallHeight = size.Y
	local wallThickness = 2

	-- Front wall (with door gap)
	local frontLeft = Instance.new("Part")
	frontLeft.Name = "FrontWallLeft"
	frontLeft.Size = Vector3.new((size.X - 10) / 2, wallHeight, wallThickness)
	frontLeft.Position = groundPos + Vector3.new(-(size.X / 4) - 2.5, wallHeight / 2 + 1, -size.Z / 2)
	frontLeft.Anchored = true
	frontLeft.BrickColor = color
	frontLeft.Material = mat
	frontLeft.Parent = building

	local frontRight = Instance.new("Part")
	frontRight.Name = "FrontWallRight"
	frontRight.Size = Vector3.new((size.X - 10) / 2, wallHeight, wallThickness)
	frontRight.Position = groundPos + Vector3.new((size.X / 4) + 2.5, wallHeight / 2 + 1, -size.Z / 2)
	frontRight.Anchored = true
	frontRight.BrickColor = color
	frontRight.Material = mat
	frontRight.Parent = building

	-- Back wall
	local backWall = Instance.new("Part")
	backWall.Name = "BackWall"
	backWall.Size = Vector3.new(size.X, wallHeight, wallThickness)
	backWall.Position = groundPos + Vector3.new(0, wallHeight / 2 + 1, size.Z / 2)
	backWall.Anchored = true
	backWall.BrickColor = color
	backWall.Material = mat
	backWall.Parent = building

	-- Side walls
	local leftWall = Instance.new("Part")
	leftWall.Name = "LeftWall"
	leftWall.Size = Vector3.new(wallThickness, wallHeight, size.Z)
	leftWall.Position = groundPos + Vector3.new(-size.X / 2, wallHeight / 2 + 1, 0)
	leftWall.Anchored = true
	leftWall.BrickColor = color
	leftWall.Material = mat
	leftWall.Parent = building

	local rightWall = Instance.new("Part")
	rightWall.Name = "RightWall"
	rightWall.Size = Vector3.new(wallThickness, wallHeight, size.Z)
	rightWall.Position = groundPos + Vector3.new(size.X / 2, wallHeight / 2 + 1, 0)
	rightWall.Anchored = true
	rightWall.BrickColor = color
	rightWall.Material = mat
	rightWall.Parent = building

	-- Roof
	local roof = Instance.new("Part")
	roof.Name = "Roof"
	roof.Size = Vector3.new(size.X + 4, 2, size.Z + 4)
	roof.Position = groundPos + Vector3.new(0, wallHeight + 2, 0)
	roof.Anchored = true
	roof.BrickColor = BrickColor.new("Dark stone grey")
	roof.Material = Enum.Material.Slate
	roof.Parent = building

	building.PrimaryPart = floor
	building.Parent = getOrCreateFolder("Buildings")

	return building
end

-- Create a simple house/cabin (anchored at ground level)
local function createHouse(name: string, position: Vector3, size: number): Model
	local house = Instance.new("Model")
	house.Name = name

	local groundPos = placeAtGroundLevel(position, 0)

	-- Base/Foundation
	local foundation = Instance.new("Part")
	foundation.Name = "Foundation"
	foundation.Size = Vector3.new(size, 2, size)
	foundation.Position = groundPos + Vector3.new(0, 1, 0)
	foundation.Anchored = true
	foundation.BrickColor = BrickColor.new("Brick yellow")
	foundation.Material = Enum.Material.Concrete
	foundation.Parent = house

	-- Main structure
	local main = Instance.new("Part")
	main.Name = "MainStructure"
	main.Size = Vector3.new(size - 2, size * 0.6, size - 2)
	main.Position = groundPos + Vector3.new(0, 2 + (size * 0.3), 0)
	main.Anchored = true
	main.BrickColor = BrickColor.new("Reddish brown")
	main.Material = Enum.Material.Wood
	main.Parent = house

	-- Roof
	local roofLeft = Instance.new("Part")
	roofLeft.Name = "RoofLeft"
	roofLeft.Size = Vector3.new(size + 2, 1, size * 0.6)
	roofLeft.Position = groundPos + Vector3.new(0, 2 + size * 0.6 + 0.5, -size * 0.15)
	roofLeft.Rotation = Vector3.new(25, 0, 0)
	roofLeft.Anchored = true
	roofLeft.BrickColor = BrickColor.new("Brown")
	roofLeft.Material = Enum.Material.Slate
	roofLeft.Parent = house

	local roofRight = Instance.new("Part")
	roofRight.Name = "RoofRight"
	roofRight.Size = Vector3.new(size + 2, 1, size * 0.6)
	roofRight.Position = groundPos + Vector3.new(0, 2 + size * 0.6 + 0.5, size * 0.15)
	roofRight.Rotation = Vector3.new(-25, 0, 0)
	roofRight.Anchored = true
	roofRight.BrickColor = BrickColor.new("Brown")
	roofRight.Material = Enum.Material.Slate
	roofRight.Parent = house

	-- Door
	local door = Instance.new("Part")
	door.Name = "Door"
	door.Size = Vector3.new(4, 7, 1)
	door.Position = groundPos + Vector3.new(0, 5.5, -size / 2 + 0.5)
	door.Anchored = true
	door.BrickColor = BrickColor.new("Dark orange")
	door.Material = Enum.Material.Wood
	door.Parent = house

	-- Windows
	for i = -1, 1, 2 do
		local window = Instance.new("Part")
		window.Name = "Window" .. (i == -1 and "Left" or "Right")
		window.Size = Vector3.new(1, 4, 4)
		window.Position = groundPos + Vector3.new(i * (size / 2 - 0.5), 5, 0)
		window.Anchored = true
		window.BrickColor = BrickColor.new("Cyan")
		window.Material = Enum.Material.Glass
		window.Transparency = 0.5
		window.Parent = house
	end

	house.PrimaryPart = foundation
	house.Parent = getOrCreateFolder("Buildings")

	return house
end

-- Create a rock formation
local function createRock(position: Vector3, size: number, material: Enum.Material?): Part
	local rock = Instance.new("Part")
	rock.Name = "Rock"
	rock.Size = Vector3.new(size * (0.8 + math.random() * 0.4), size * (0.6 + math.random() * 0.4), size * (0.8 + math.random() * 0.4))
	rock.Position = position + Vector3.new(0, rock.Size.Y / 2, 0)
	rock.Anchored = true
	rock.BrickColor = BrickColor.new("Dark stone grey")
	rock.Material = material or Enum.Material.Rock
	rock.Parent = getOrCreateFolder("Rocks")
	return rock
end

-- Create a watchtower/observation tower
local function createTower(name: string, position: Vector3, height: number): Model
	local tower = Instance.new("Model")
	tower.Name = name

	local groundPos = placeAtGroundLevel(position, 0)

	-- Support legs
	local legSize = 2
	for x = -1, 1, 2 do
		for z = -1, 1, 2 do
			local leg = Instance.new("Part")
			leg.Name = "Leg"
			leg.Size = Vector3.new(legSize, height, legSize)
			leg.Position = groundPos + Vector3.new(x * 5, height / 2, z * 5)
			leg.Anchored = true
			leg.BrickColor = BrickColor.new("Brown")
			leg.Material = Enum.Material.Wood
			leg.Parent = tower
		end
	end

	-- Platform at top
	local platform = Instance.new("Part")
	platform.Name = "Platform"
	platform.Size = Vector3.new(14, 1, 14)
	platform.Position = groundPos + Vector3.new(0, height, 0)
	platform.Anchored = true
	platform.BrickColor = BrickColor.new("Brown")
	platform.Material = Enum.Material.WoodPlanks
	platform.Parent = tower

	-- Railing
	for i = 1, 4 do
		local rail = Instance.new("Part")
		rail.Name = "Rail" .. i
		rail.Size = Vector3.new(i <= 2 and 14 or 1, 3, i <= 2 and 1 or 14)
		local offset = i == 1 and Vector3.new(0, height + 2, 7) or
					   i == 2 and Vector3.new(0, height + 2, -7) or
					   i == 3 and Vector3.new(7, height + 2, 0) or
					   Vector3.new(-7, height + 2, 0)
		rail.Position = groundPos + offset
		rail.Anchored = true
		rail.BrickColor = BrickColor.new("Brown")
		rail.Material = Enum.Material.Wood
		rail.Parent = tower
	end

	-- Roof
	local roof = Instance.new("Part")
	roof.Name = "Roof"
	roof.Size = Vector3.new(16, 1, 16)
	roof.Position = groundPos + Vector3.new(0, height + 8, 0)
	roof.Anchored = true
	roof.BrickColor = BrickColor.new("Bright green")
	roof.Material = Enum.Material.Grass
	roof.Parent = tower

	tower.PrimaryPart = platform
	tower.Parent = getOrCreateFolder("Structures")

	return tower
end

-- Create industrial structure
local function createIndustrialBuilding(name: string, position: Vector3): Model
	local building = Instance.new("Model")
	building.Name = name

	local groundPos = placeAtGroundLevel(position, 0)

	-- Main structure
	local main = Instance.new("Part")
	main.Name = "MainBuilding"
	main.Size = Vector3.new(60, 25, 40)
	main.Position = groundPos + Vector3.new(0, 12.5, 0)
	main.Anchored = true
	main.BrickColor = BrickColor.new("Medium stone grey")
	main.Material = Enum.Material.Concrete
	main.Parent = building

	-- Smokestack
	local stack = Instance.new("Part")
	stack.Name = "Smokestack"
	stack.Size = Vector3.new(8, 50, 8)
	stack.Position = groundPos + Vector3.new(20, 25, 10)
	stack.Anchored = true
	stack.BrickColor = BrickColor.new("Dark stone grey")
	stack.Material = Enum.Material.Metal
	stack.Parent = building

	-- Pipes
	for i = 1, 3 do
		local pipe = Instance.new("Part")
		pipe.Name = "Pipe" .. i
		pipe.Size = Vector3.new(3, 20, 3)
		pipe.Position = groundPos + Vector3.new(-15 + (i * 10), 20, -25)
		pipe.Rotation = Vector3.new(0, 0, 45)
		pipe.Anchored = true
		pipe.BrickColor = BrickColor.new("Rust")
		pipe.Material = Enum.Material.CorrodedMetal
		pipe.Parent = building
	end

	-- Steam vent areas
	for i = 1, 4 do
		local vent = Instance.new("Part")
		vent.Name = "SteamVent" .. i
		vent.Size = Vector3.new(6, 2, 6)
		vent.Position = groundPos + Vector3.new(-20 + (i * 12), 1, 30)
		vent.Anchored = true
		vent.BrickColor = BrickColor.new("Dark stone grey")
		vent.Material = Enum.Material.DiamondPlate
		vent.Parent = building
	end

	building.PrimaryPart = main
	building.Parent = getOrCreateFolder("Buildings")

	return building
end

-- Create lighthouse
local function createLighthouse(position: Vector3): Model
	local lighthouse = Instance.new("Model")
	lighthouse.Name = "Lighthouse"

	local groundPos = placeAtGroundLevel(position, 0)

	-- Base
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(20, 5, 20)
	base.Position = groundPos + Vector3.new(0, 2.5, 0)
	base.Anchored = true
	base.BrickColor = BrickColor.new("White")
	base.Material = Enum.Material.Concrete
	base.Parent = lighthouse

	-- Tower sections
	local towerHeight = 60
	local sections = 6
	for i = 1, sections do
		local section = Instance.new("Part")
		section.Name = "Section" .. i
		local sectionHeight = towerHeight / sections
		local sectionWidth = 12 - (i * 1.2)
		section.Size = Vector3.new(sectionWidth, sectionHeight, sectionWidth)
		section.Position = groundPos + Vector3.new(0, 5 + (i - 0.5) * sectionHeight, 0)
		section.Anchored = true
		section.BrickColor = i % 2 == 1 and BrickColor.new("White") or BrickColor.new("Bright red")
		section.Material = Enum.Material.Concrete
		section.Parent = lighthouse
	end

	-- Light room
	local lightRoom = Instance.new("Part")
	lightRoom.Name = "LightRoom"
	lightRoom.Size = Vector3.new(10, 8, 10)
	lightRoom.Position = groundPos + Vector3.new(0, towerHeight + 9, 0)
	lightRoom.Anchored = true
	lightRoom.BrickColor = BrickColor.new("Black")
	lightRoom.Material = Enum.Material.Metal
	lightRoom.Parent = lighthouse

	-- Light
	local light = Instance.new("Part")
	light.Name = "Light"
	light.Shape = Enum.PartType.Ball
	light.Size = Vector3.new(6, 6, 6)
	light.Position = groundPos + Vector3.new(0, towerHeight + 9, 0)
	light.Anchored = true
	light.BrickColor = BrickColor.new("Bright yellow")
	light.Material = Enum.Material.Neon
	light.Parent = lighthouse

	-- Roof
	local roof = Instance.new("Part")
	roof.Name = "Roof"
	roof.Size = Vector3.new(12, 3, 12)
	roof.Position = groundPos + Vector3.new(0, towerHeight + 14, 0)
	roof.Anchored = true
	roof.BrickColor = BrickColor.new("Bright red")
	roof.Material = Enum.Material.Metal
	roof.Parent = lighthouse

	lighthouse.PrimaryPart = base
	lighthouse.Parent = getOrCreateFolder("Structures")

	return lighthouse
end

-- Create dock/pier
local function createDock(position: Vector3, length: number): Model
	local dock = Instance.new("Model")
	dock.Name = "Dock"

	local groundPos = placeAtGroundLevel(position, 0)

	-- Main platform
	local platform = Instance.new("Part")
	platform.Name = "Platform"
	platform.Size = Vector3.new(15, 2, length)
	platform.Position = groundPos + Vector3.new(0, 3, length / 2)
	platform.Anchored = true
	platform.BrickColor = BrickColor.new("Brown")
	platform.Material = Enum.Material.WoodPlanks
	platform.Parent = dock

	-- Support pillars
	local pillarCount = math.floor(length / 20)
	for i = 1, pillarCount do
		local pillar = Instance.new("Part")
		pillar.Name = "Pillar" .. i
		pillar.Size = Vector3.new(2, 10, 2)
		pillar.Position = groundPos + Vector3.new(0, -2, i * 20)
		pillar.Anchored = true
		pillar.BrickColor = BrickColor.new("Dark stone grey")
		pillar.Material = Enum.Material.Concrete
		pillar.Parent = dock
	end

	dock.PrimaryPart = platform
	dock.Parent = getOrCreateFolder("Structures")

	return dock
end

-- Create multi-story building with interior
local function createMultiStoryBuilding(
	name: string,
	position: Vector3,
	floors: number,
	footprint: Vector3,
	style: string
): Model
	local building = Instance.new("Model")
	building.Name = name

	local groundPos = placeAtGroundLevel(position, 0)

	local width = footprint.X
	local floorHeight = footprint.Y
	local depth = footprint.Z
	local wallThickness = 2

	-- Style-based colors
	local styleConfig = MapConfig.POIStyles[style] or MapConfig.POIStyles.Commercial
	local wallColor = styleConfig.WallColor
	local roofColor = styleConfig.RoofColor
	local windowColor = styleConfig.WindowColor
	local interiorWallColor = styleConfig.InteriorWallColor

	-- Foundation
	local foundation = Instance.new("Part")
	foundation.Name = "Foundation"
	foundation.Size = Vector3.new(width + 4, 3, depth + 4)
	foundation.Position = groundPos + Vector3.new(0, 1.5, 0)
	foundation.Anchored = true
	foundation.BrickColor = BrickColor.new("Dark stone grey")
	foundation.Material = Enum.Material.Concrete
	foundation.Parent = building

	-- Create each floor
	for floor = 1, floors do
		local floorY = 3 + (floor - 1) * floorHeight

		-- Floor slab
		local slab = Instance.new("Part")
		slab.Name = "Floor" .. floor
		slab.Size = Vector3.new(width, 1, depth)
		slab.Position = groundPos + Vector3.new(0, floorY + 0.5, 0)
		slab.Anchored = true
		slab.BrickColor = BrickColor.new("Medium stone grey")
		slab.Material = Enum.Material.Concrete
		slab.Parent = building

		-- Walls
		local wallHeight = floorHeight - 1

		-- Front wall with door on ground floor
		if floor == 1 then
			local frontLeft = Instance.new("Part")
			frontLeft.Name = "FrontWallLeft" .. floor
			frontLeft.Size = Vector3.new((width - 8) / 2, wallHeight, wallThickness)
			frontLeft.Position = groundPos + Vector3.new(-(width / 4) - 2, floorY + 1 + wallHeight / 2, -depth / 2)
			frontLeft.Anchored = true
			frontLeft.BrickColor = wallColor
			frontLeft.Material = Enum.Material.Concrete
			frontLeft.Parent = building

			local frontRight = Instance.new("Part")
			frontRight.Name = "FrontWallRight" .. floor
			frontRight.Size = Vector3.new((width - 8) / 2, wallHeight, wallThickness)
			frontRight.Position = groundPos + Vector3.new((width / 4) + 2, floorY + 1 + wallHeight / 2, -depth / 2)
			frontRight.Anchored = true
			frontRight.BrickColor = wallColor
			frontRight.Material = Enum.Material.Concrete
			frontRight.Parent = building

			local doorHeader = Instance.new("Part")
			doorHeader.Name = "DoorHeader" .. floor
			doorHeader.Size = Vector3.new(8, wallHeight - 8, wallThickness)
			doorHeader.Position = groundPos + Vector3.new(0, floorY + 1 + 8 + (wallHeight - 8) / 2, -depth / 2)
			doorHeader.Anchored = true
			doorHeader.BrickColor = wallColor
			doorHeader.Material = Enum.Material.Concrete
			doorHeader.Parent = building
		else
			local frontWall = Instance.new("Part")
			frontWall.Name = "FrontWall" .. floor
			frontWall.Size = Vector3.new(width, wallHeight, wallThickness)
			frontWall.Position = groundPos + Vector3.new(0, floorY + 1 + wallHeight / 2, -depth / 2)
			frontWall.Anchored = true
			frontWall.BrickColor = wallColor
			frontWall.Material = Enum.Material.Concrete
			frontWall.Parent = building
		end

		-- Back wall
		local backWall = Instance.new("Part")
		backWall.Name = "BackWall" .. floor
		backWall.Size = Vector3.new(width, wallHeight, wallThickness)
		backWall.Position = groundPos + Vector3.new(0, floorY + 1 + wallHeight / 2, depth / 2)
		backWall.Anchored = true
		backWall.BrickColor = wallColor
		backWall.Material = Enum.Material.Concrete
		backWall.Parent = building

		-- Side walls
		local leftWall = Instance.new("Part")
		leftWall.Name = "LeftWall" .. floor
		leftWall.Size = Vector3.new(wallThickness, wallHeight, depth)
		leftWall.Position = groundPos + Vector3.new(-width / 2, floorY + 1 + wallHeight / 2, 0)
		leftWall.Anchored = true
		leftWall.BrickColor = wallColor
		leftWall.Material = Enum.Material.Concrete
		leftWall.Parent = building

		local rightWall = Instance.new("Part")
		rightWall.Name = "RightWall" .. floor
		rightWall.Size = Vector3.new(wallThickness, wallHeight, depth)
		rightWall.Position = groundPos + Vector3.new(width / 2, floorY + 1 + wallHeight / 2, 0)
		rightWall.Anchored = true
		rightWall.BrickColor = wallColor
		rightWall.Material = Enum.Material.Concrete
		rightWall.Parent = building

		-- Interior walls
		local interiorWall = Instance.new("Part")
		interiorWall.Name = "InteriorWall" .. floor
		interiorWall.Size = Vector3.new(1, wallHeight - 2, depth - 10)
		interiorWall.Position = groundPos + Vector3.new(-width / 6, floorY + 1 + (wallHeight - 2) / 2, 0)
		interiorWall.Anchored = true
		interiorWall.BrickColor = interiorWallColor
		interiorWall.Material = Enum.Material.SmoothPlastic
		interiorWall.Parent = building

		-- Windows
		local windowsPerSide = math.max(2, math.floor(width / 12))
		for w = 1, windowsPerSide do
			local windowX = -width / 2 + w * (width / (windowsPerSide + 1))

			local frontWindow = Instance.new("Part")
			frontWindow.Name = "FrontWindow" .. floor .. "_" .. w
			frontWindow.Size = Vector3.new(4, 5, 1)
			frontWindow.Position = groundPos + Vector3.new(windowX, floorY + 1 + wallHeight / 2, -depth / 2 - 0.5)
			frontWindow.Anchored = true
			frontWindow.BrickColor = windowColor
			frontWindow.Material = Enum.Material.Glass
			frontWindow.Transparency = 0.5
			frontWindow.Parent = building

			local backWindow = Instance.new("Part")
			backWindow.Name = "BackWindow" .. floor .. "_" .. w
			backWindow.Size = Vector3.new(4, 5, 1)
			backWindow.Position = groundPos + Vector3.new(windowX, floorY + 1 + wallHeight / 2, depth / 2 + 0.5)
			backWindow.Anchored = true
			backWindow.BrickColor = windowColor
			backWindow.Material = Enum.Material.Glass
			backWindow.Transparency = 0.5
			backWindow.Parent = building
		end

		-- Stairs between floors
		if floor < floors then
			local stairWidth = 5
			local stairDepth = 10
			local stepCount = 10
			local stepHeight = floorHeight / stepCount

			local stairBaseX = width / 2 - stairWidth - 2
			local stairBaseZ = depth / 2 - stairDepth - 2

			for step = 1, stepCount do
				local stepPart = Instance.new("Part")
				stepPart.Name = "Step" .. floor .. "_" .. step
				stepPart.Size = Vector3.new(stairWidth, stepHeight * 0.8, stairDepth / stepCount)
				stepPart.Position = groundPos + Vector3.new(
					stairBaseX,
					floorY + 1 + (step - 0.5) * stepHeight,
					stairBaseZ + (step - 0.5) * (stairDepth / stepCount)
				)
				stepPart.Anchored = true
				stepPart.BrickColor = BrickColor.new("Medium stone grey")
				stepPart.Material = Enum.Material.Concrete
				stepPart.Parent = building
			end
		end
	end

	-- Roof
	local roofY = 3 + floors * floorHeight
	local roof = Instance.new("Part")
	roof.Name = "Roof"
	roof.Size = Vector3.new(width + 4, 2, depth + 4)
	roof.Position = groundPos + Vector3.new(0, roofY + 1, 0)
	roof.Anchored = true
	roof.BrickColor = roofColor
	roof.Material = Enum.Material.Slate
	roof.Parent = building

	building.PrimaryPart = foundation
	building.Parent = getOrCreateFolder("Buildings")
	return building
end

-- Create apartment building
local function createApartmentBuilding(name: string, position: Vector3, floors: number): Model
	return createMultiStoryBuilding(name, position, floors, Vector3.new(30, 12, 20), "Residential")
end

-- Create warehouse
local function createWarehouse(name: string, position: Vector3): Model
	local warehouse = Instance.new("Model")
	warehouse.Name = name

	local groundPos = placeAtGroundLevel(position, 0)

	local main = Instance.new("Part")
	main.Name = "Main"
	main.Size = Vector3.new(60, 25, 45)
	main.Position = groundPos + Vector3.new(0, 12.5, 0)
	main.Anchored = true
	main.BrickColor = BrickColor.new("Dark stone grey")
	main.Material = Enum.Material.Metal
	main.Parent = warehouse

	-- Loading bay doors
	for i = 1, 3 do
		local door = Instance.new("Part")
		door.Name = "LoadingDoor" .. i
		door.Size = Vector3.new(12, 15, 1)
		door.Position = groundPos + Vector3.new(-20 + i * 15, 7.5, -23)
		door.Anchored = true
		door.BrickColor = BrickColor.new("Medium stone grey")
		door.Material = Enum.Material.DiamondPlate
		door.Parent = warehouse
	end

	-- Office section
	local office = Instance.new("Part")
	office.Name = "Office"
	office.Size = Vector3.new(15, 12, 20)
	office.Position = groundPos + Vector3.new(-22, 6, 12)
	office.Anchored = true
	office.BrickColor = BrickColor.new("Brick yellow")
	office.Material = Enum.Material.Concrete
	office.Parent = warehouse

	warehouse.PrimaryPart = main
	warehouse.Parent = getOrCreateFolder("Buildings")
	return warehouse
end

-- Create small shed
local function createShed(name: string, position: Vector3, size: number): Model
	local shed = Instance.new("Model")
	shed.Name = name

	local groundPos = placeAtGroundLevel(position, 0)

	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = Vector3.new(size, 0.5, size)
	floor.Position = groundPos + Vector3.new(0, 0.25, 0)
	floor.Anchored = true
	floor.BrickColor = BrickColor.new("Brown")
	floor.Material = Enum.Material.WoodPlanks
	floor.Parent = shed

	local wallHeight = size * 0.6
	local walls = {
		{Vector3.new(size, wallHeight, 0.5), Vector3.new(0, wallHeight / 2 + 0.5, -size / 2)},
		{Vector3.new(size, wallHeight, 0.5), Vector3.new(0, wallHeight / 2 + 0.5, size / 2)},
		{Vector3.new(0.5, wallHeight, size), Vector3.new(-size / 2, wallHeight / 2 + 0.5, 0)},
		{Vector3.new(0.5, wallHeight, size), Vector3.new(size / 2, wallHeight / 2 + 0.5, 0)},
	}

	for i, wallData in ipairs(walls) do
		local wall = Instance.new("Part")
		wall.Name = "Wall" .. i
		wall.Size = wallData[1]
		wall.Position = groundPos + wallData[2]
		wall.Anchored = true
		wall.BrickColor = BrickColor.new("Reddish brown")
		wall.Material = Enum.Material.Wood
		wall.Parent = shed
	end

	local roof = Instance.new("Part")
	roof.Name = "Roof"
	roof.Size = Vector3.new(size + 1, 0.5, size + 1)
	roof.Position = groundPos + Vector3.new(0, wallHeight + 0.75, 0)
	roof.Anchored = true
	roof.BrickColor = BrickColor.new("Dark stone grey")
	roof.Material = Enum.Material.Metal
	roof.Parent = shed

	shed.PrimaryPart = floor
	shed.Parent = getOrCreateFolder("Buildings")
	return shed
end

-- Create ruins
local function createRuins(name: string, position: Vector3, size: number): Model
	local ruins = Instance.new("Model")
	ruins.Name = name

	local groundPos = placeAtGroundLevel(position, 0)

	local foundation = Instance.new("Part")
	foundation.Name = "Foundation"
	foundation.Size = Vector3.new(size, 2, size)
	foundation.Position = groundPos + Vector3.new(0, 1, 0)
	foundation.Anchored = true
	foundation.BrickColor = BrickColor.new("Dark stone grey")
	foundation.Material = Enum.Material.Concrete
	foundation.Parent = ruins

	-- Scattered wall fragments
	for i = 1, math.random(4, 8) do
		local fragment = Instance.new("Part")
		fragment.Name = "Fragment" .. i
		fragment.Size = Vector3.new(
			math.random(3, 8),
			math.random(4, 12),
			math.random(1, 3)
		)
		fragment.Position = groundPos + Vector3.new(
			math.random(-size / 2, size / 2),
			fragment.Size.Y / 2 + 2,
			math.random(-size / 2, size / 2)
		)
		fragment.Rotation = Vector3.new(math.random(-15, 15), math.random(0, 360), math.random(-15, 15))
		fragment.Anchored = true
		fragment.BrickColor = BrickColor.new("Medium stone grey")
		fragment.Material = Enum.Material.Concrete
		fragment.Parent = ruins
	end

	-- Rubble
	for i = 1, math.random(6, 12) do
		local rubble = Instance.new("Part")
		rubble.Name = "Rubble" .. i
		rubble.Size = Vector3.new(
			math.random(1, 4),
			math.random(1, 3),
			math.random(1, 4)
		)
		rubble.Position = groundPos + Vector3.new(
			math.random(-size / 2, size / 2),
			rubble.Size.Y / 2 + 2,
			math.random(-size / 2, size / 2)
		)
		rubble.Anchored = true
		rubble.BrickColor = BrickColor.new("Dark stone grey")
		rubble.Material = Enum.Material.Concrete
		rubble.Parent = ruins
	end

	ruins.PrimaryPart = foundation
	ruins.Parent = getOrCreateFolder("Structures")
	return ruins
end

--------------------------------------------------------------------------------
-- WATER AND CAVE FUNCTIONS
--------------------------------------------------------------------------------

local function createRiverSegment(terrain: Terrain, startPos: Vector3, endPos: Vector3, width: number, depth: number)
	local segments = math.ceil((endPos - startPos).Magnitude / 50)

	for i = 0, segments do
		local t = i / segments
		local pos = startPos:Lerp(endPos, t)
		local noiseOffset = math.noise(pos.X / 100, pos.Z / 100, 5) * width * 0.3

		terrain:FillBlock(
			CFrame.new(pos.X + noiseOffset, -depth - 5, pos.Z),
			Vector3.new(width + 10, 10, 60),
			Enum.Material.Sand
		)

		terrain:FillBlock(
			CFrame.new(pos.X + noiseOffset - width / 2 - 5, -depth - 3, pos.Z),
			Vector3.new(10, 6, 60),
			Enum.Material.Mud
		)
		terrain:FillBlock(
			CFrame.new(pos.X + noiseOffset + width / 2 + 5, -depth - 3, pos.Z),
			Vector3.new(10, 6, 60),
			Enum.Material.Mud
		)

		terrain:FillBlock(
			CFrame.new(pos.X + noiseOffset, -depth / 2, pos.Z),
			Vector3.new(width, depth, 60),
			Enum.Material.Water
		)
	end
end

local function createLake(terrain: Terrain, centerPos: Vector3, radius: number, depth: number)
	terrain:FillBlock(
		CFrame.new(centerPos.X, -depth - 8, centerPos.Z),
		Vector3.new(radius * 2 + 20, 15, radius * 2 + 20),
		Enum.Material.Sand
	)

	for i = 1, 8 do
		local angle = (i / 8) * math.pi * 2
		local dist = radius * 0.6
		terrain:FillBlock(
			CFrame.new(
				centerPos.X + math.cos(angle) * dist,
				-depth - 5,
				centerPos.Z + math.sin(angle) * dist
			),
			Vector3.new(radius * 0.3, 8, radius * 0.3),
			i % 2 == 0 and Enum.Material.Mud or Enum.Material.Ground
		)
	end

	terrain:FillBlock(
		CFrame.new(centerPos.X, -depth / 2, centerPos.Z),
		Vector3.new(radius * 2, depth, radius * 2),
		Enum.Material.Water
	)

	terrain:FillBlock(
		CFrame.new(centerPos.X, -2, centerPos.Z),
		Vector3.new(radius * 2.2, 4, radius * 2.2),
		Enum.Material.Water
	)
end

local function createCave(terrain: Terrain, entrancePos: Vector3, caveDepth: number, width: number, height: number)
	terrain:FillBlock(
		CFrame.new(entrancePos.X, entrancePos.Y, entrancePos.Z - caveDepth / 2),
		Vector3.new(width, height, caveDepth),
		Enum.Material.Air
	)

	terrain:FillBlock(
		CFrame.new(entrancePos.X, entrancePos.Y - height / 2 - 2, entrancePos.Z - caveDepth / 2),
		Vector3.new(width + 4, 4, caveDepth),
		Enum.Material.Slate
	)

	terrain:FillBlock(
		CFrame.new(entrancePos.X, entrancePos.Y + height / 2 + 2, entrancePos.Z - caveDepth / 2),
		Vector3.new(width + 4, 4, caveDepth),
		Enum.Material.Slate
	)
end

--------------------------------------------------------------------------------
-- VEGETATION HELPERS
--------------------------------------------------------------------------------

local function createTreeCluster(centerPos: Vector3, radius: number, count: number, treeType: string, baseHeight: number)
	local floraType = MapConfig.TreeTypeMap[treeType] or "Oak"
	local biome = MapConfig.TreeBiomeMap[treeType] or "Plains"

	for i = 1, count do
		local angle = math.random() * math.pi * 2
		local dist = math.random() * radius
		local x = centerPos.X + math.cos(angle) * dist
		local z = centerPos.Z + math.sin(angle) * dist

		local treePos = Vector3.new(x, centerPos.Y, z)

		pcall(function()
			FloraGenerator.CreateTree(treePos, floraType, biome)
		end)

		if i % MapConfig.TreeClusterYieldInterval == 0 then
			task.wait()
		end
	end
end

local function createFloraTree(position: Vector3, treeType: string)
	local floraType = MapConfig.TreeTypeMap[treeType] or "Oak"
	local biome = MapConfig.TreeBiomeMap[treeType] or "Plains"

	pcall(function()
		FloraGenerator.CreateTree(position, floraType, biome)
	end)
end

local function createRockFormation(centerPos: Vector3, rockCount: number, minSize: number, maxSize: number, material: Enum.Material?)
	local biome = "Plains"
	if material == Enum.Material.Basalt then
		biome = "Volcanic"
	elseif material == Enum.Material.Sandstone then
		biome = "Coastal"
	end

	pcall(function()
		FloraGenerator.CreateRockCluster(centerPos, math.max(minSize, maxSize), rockCount, biome)
	end)
end

local function createGrassPatch(terrain: Terrain, centerPos: Vector3, radius: number)
	terrain:FillBlock(
		CFrame.new(centerPos.X, centerPos.Y + 1, centerPos.Z),
		Vector3.new(radius * 2, 3, radius * 2),
		Enum.Material.LeafyGrass
	)

	if math.random() > 0.5 then
		pcall(function()
			FloraGenerator.CreateGrassCluster(centerPos, radius * 0.5, "Plains")
		end)
	end
end

local function createBush(position: Vector3, size: number): Model
	local bush = Instance.new("Model")
	bush.Name = "Bush"

	local groundPos = placeAtGroundLevel(position, 0)

	for i = 1, 3 do
		local part = Instance.new("Part")
		part.Name = "Foliage" .. i
		part.Shape = Enum.PartType.Ball
		local partSize = size * (0.6 + math.random() * 0.3)
		part.Size = Vector3.new(partSize, partSize * 0.8, partSize)
		local offsetX = (math.random() - 0.5) * size * 0.4
		local offsetZ = (math.random() - 0.5) * size * 0.4
		part.Position = groundPos + Vector3.new(offsetX, partSize * 0.35, offsetZ)
		part.Anchored = true
		part.BrickColor = BrickColor.new("Forest green")
		part.Material = Enum.Material.Grass
		part.Parent = bush
	end

	bush.Parent = getOrCreateFolder("Bushes")
	return bush
end

local function createFern(position: Vector3): Model
	local fern = Instance.new("Model")
	fern.Name = "Fern"

	local groundPos = placeAtGroundLevel(position, 0)

	for i = 1, 6 do
		local frond = Instance.new("Part")
		frond.Name = "Frond" .. i
		frond.Size = Vector3.new(0.3, 2.5, 0.8)
		local angle = (i / 6) * math.pi * 2
		frond.Position = groundPos + Vector3.new(math.cos(angle) * 0.3, 1.2, math.sin(angle) * 0.3)
		frond.Rotation = Vector3.new(30, math.deg(angle), 0)
		frond.Anchored = true
		frond.BrickColor = BrickColor.new("Bright green")
		frond.Material = Enum.Material.Grass
		frond.Parent = fern
	end

	fern.Parent = getOrCreateFolder("Ferns")
	return fern
end

local function createFlowerPatch(position: Vector3, count: number): Model
	local patch = Instance.new("Model")
	patch.Name = "FlowerPatch"

	local groundPos = placeAtGroundLevel(position, 0)
	local colors = { "Bright red", "Bright yellow", "Magenta", "Bright orange", "White" }

	for i = 1, count do
		local flower = Instance.new("Part")
		flower.Name = "Flower" .. i
		flower.Shape = Enum.PartType.Ball
		flower.Size = Vector3.new(0.8, 0.8, 0.8)
		local offsetX = (math.random() - 0.5) * 4
		local offsetZ = (math.random() - 0.5) * 4
		flower.Position = groundPos + Vector3.new(offsetX, 0.5, offsetZ)
		flower.Anchored = true
		flower.BrickColor = BrickColor.new(colors[math.random(1, #colors)])
		flower.Material = Enum.Material.SmoothPlastic
		flower.Parent = patch

		local stem = Instance.new("Part")
		stem.Name = "Stem" .. i
		stem.Size = Vector3.new(0.1, 0.6, 0.1)
		stem.Position = groundPos + Vector3.new(offsetX, 0.2, offsetZ)
		stem.Anchored = true
		stem.BrickColor = BrickColor.new("Bright green")
		stem.Material = Enum.Material.Grass
		stem.Parent = patch
	end

	patch.Parent = getOrCreateFolder("Flowers")
	return patch
end

--------------------------------------------------------------------------------
-- LOOT CACHE CREATION (with LootManager integration)
--------------------------------------------------------------------------------

local function createLootCache(position: Vector3, cacheType: string): Model
	local cache = Instance.new("Model")
	cache.Name = "LootCache_" .. cacheType

	local groundPos = placeAtGroundLevel(position, 0)

	-- Determine tier based on cache type
	local tier = "Medium"
	if cacheType == "weapon_crate" then
		tier = "High"
	elseif cacheType == "ammo_box" then
		tier = "Low"
	-- elseif cacheType == "medkit" or cacheType == "supply_drop": keep default "Medium"
	end

	-- Add loot data attributes for LootManager integration
	cache:SetAttribute("LootTier", tier)
	cache:SetAttribute("CacheType", cacheType)
	cache:SetAttribute("IsLooted", false)
	cache:SetAttribute("SpawnTime", tick())

	local base: Part

	if cacheType == "weapon_crate" then
		local crate = Instance.new("Part")
		crate.Name = "Crate"
		crate.Size = Vector3.new(5, 3, 3)
		crate.Position = groundPos + Vector3.new(0, 1.5, 0)
		crate.Anchored = true
		crate.BrickColor = BrickColor.new("Dark green")
		crate.Material = Enum.Material.Metal
		crate.Parent = cache
		base = crate

		local lid = Instance.new("Part")
		lid.Name = "Lid"
		lid.Size = Vector3.new(5.2, 0.5, 3.2)
		lid.Position = groundPos + Vector3.new(0, 3.25, 0)
		lid.Anchored = true
		lid.BrickColor = BrickColor.new("Dark green")
		lid.Material = Enum.Material.Metal
		lid.Parent = cache

		local stripe = Instance.new("Part")
		stripe.Name = "Stripe"
		stripe.Size = Vector3.new(4, 0.5, 0.1)
		stripe.Position = groundPos + Vector3.new(0, 2, -1.55)
		stripe.Anchored = true
		stripe.BrickColor = BrickColor.new("White")
		stripe.Material = Enum.Material.SmoothPlastic
		stripe.Parent = cache

	elseif cacheType == "ammo_box" then
		local box = Instance.new("Part")
		box.Name = "Box"
		box.Size = Vector3.new(2.5, 2, 2)
		box.Position = groundPos + Vector3.new(0, 1, 0)
		box.Anchored = true
		box.BrickColor = BrickColor.new("Olive")
		box.Material = Enum.Material.Metal
		box.Parent = cache
		base = box

		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = Vector3.new(1.5, 0.3, 0.3)
		handle.Position = groundPos + Vector3.new(0, 2.15, 0)
		handle.Anchored = true
		handle.BrickColor = BrickColor.new("Dark stone grey")
		handle.Material = Enum.Material.Metal
		handle.Parent = cache

	elseif cacheType == "medkit" then
		local kit = Instance.new("Part")
		kit.Name = "Kit"
		kit.Size = Vector3.new(3, 2, 2)
		kit.Position = groundPos + Vector3.new(0, 1, 0)
		kit.Anchored = true
		kit.BrickColor = BrickColor.new("White")
		kit.Material = Enum.Material.SmoothPlastic
		kit.Parent = cache
		base = kit

		local crossH = Instance.new("Part")
		crossH.Name = "CrossH"
		crossH.Size = Vector3.new(1.2, 0.3, 0.1)
		crossH.Position = groundPos + Vector3.new(0, 1.5, -1.05)
		crossH.Anchored = true
		crossH.BrickColor = BrickColor.new("Bright red")
		crossH.Material = Enum.Material.SmoothPlastic
		crossH.Parent = cache

		local crossV = Instance.new("Part")
		crossV.Name = "CrossV"
		crossV.Size = Vector3.new(0.3, 1.2, 0.1)
		crossV.Position = groundPos + Vector3.new(0, 1.5, -1.05)
		crossV.Anchored = true
		crossV.BrickColor = BrickColor.new("Bright red")
		crossV.Material = Enum.Material.SmoothPlastic
		crossV.Parent = cache

	else -- supply_drop
		local crate = Instance.new("Part")
		crate.Name = "Crate"
		crate.Size = Vector3.new(4, 4, 4)
		crate.Position = groundPos + Vector3.new(0, 2, 0)
		crate.Anchored = true
		crate.BrickColor = BrickColor.new("Reddish brown")
		crate.Material = Enum.Material.Wood
		crate.Parent = cache
		base = crate

		for i = -1, 1, 2 do
			local strap = Instance.new("Part")
			strap.Name = "Strap"
			strap.Size = Vector3.new(4.2, 0.5, 0.3)
			strap.Position = groundPos + Vector3.new(0, 2, i * 1.5)
			strap.Anchored = true
			strap.BrickColor = BrickColor.new("Dark stone grey")
			strap.Material = Enum.Material.Metal
			strap.Parent = cache
		end
	end

	-- Create ProximityPrompt for interaction
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = tier .. " Cache"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 8
	prompt.Parent = base

	-- Connect to LootManager for loot spawning
	prompt.Triggered:Connect(function(player)
		if not cache:GetAttribute("IsLooted") then
			LootManager.SpawnLootFromCache(player, cache, tier)

			-- Visual feedback: change cache appearance after looting
			for _, part in ipairs(cache:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Transparency = 0.5
				end
			end

			-- Disable the prompt after use
			prompt.Enabled = false
		end
	end)

	cache.Parent = getOrCreateFolder("LootCaches")
	return cache
end

--------------------------------------------------------------------------------
-- TERRAIN GENERATION PHASES (Split from monolithic createBaseTerrain)
--------------------------------------------------------------------------------

--[[
	Phase 1: Create solid base layer to prevent gaps
]]
local function createBaseLayer(terrain: Terrain, config: typeof(MapConfig)): boolean
	return safeExecute("Phase 1: Base Layer", function()
		terrain:FillBlock(
			CFrame.new(0, -15, 0),
			Vector3.new(config.MapSize + 200, 40, config.MapSize + 200),
			Enum.Material.Rock
		)
	end)
end

--[[
	Phase 2: Create spawn area
]]
local function createSpawnArea(terrain: Terrain, config: typeof(MapConfig)): boolean
	return safeExecute("Phase 2: Spawn Area", function()
		local spawnPos = config.SpawnPosition
		terrain:FillBlock(
			CFrame.new(spawnPos.X, config.SpawnHeight / 2, spawnPos.Z),
			Vector3.new(config.SpawnAreaSize, config.SpawnHeight, config.SpawnAreaSize),
			Enum.Material.Grass
		)
	end)
end

--[[
	Phase 3: Generate terrain cells
]]
local function generateTerrainCells(terrain: Terrain, config: typeof(MapConfig)): (boolean, { [string]: number })
	local totalCells = 0
	local biomeCounts = { jungle = 0, plains = 0, volcanic = 0, swamp = 0, coastal = 0 }

	local success = safeExecute("Phase 3: Terrain Cells", function()
		local halfSize = config.MapSize / 2
		local resolution = config.Resolution
		local spawnPos = config.SpawnPosition

		for x = -halfSize, halfSize, resolution do
			for z = -halfSize, halfSize, resolution do
				local distFromSpawn = math.sqrt((x - spawnPos.X)^2 + (z - spawnPos.Z)^2)
				if distFromSpawn > config.SpawnAreaSize * 0.7 then
					local biome = getBiomeAtPosition(x, z)
					local height = getHeightAtPosition(x, z, biome)
					local material = getMaterialAtPosition(biome, height)

					height = math.max(height, 8)

					-- Cache the height
					cacheTerrainHeight(x, z, height)

					terrain:FillBlock(
						CFrame.new(x, height / 2, z),
						Vector3.new(resolution + 2, height + 10, resolution + 2),
						material
					)

					totalCells = totalCells + 1
					biomeCounts[biome] = (biomeCounts[biome] or 0) + 1
				end
			end

			if totalCells % config.TerrainYieldInterval == 0 then
				task.wait()
			end
		end
	end)

	return success, biomeCounts
end

--[[
	Phase 4: Create water system (ocean, rivers, lakes)
]]
local function createWaterSystem(terrain: Terrain, config: typeof(MapConfig)): boolean
	return safeExecute("Phase 4: Water System", function()
		local halfSize = config.MapSize / 2

		-- Ocean
		terrain:FillBlock(
			CFrame.new(0, -25, halfSize * 0.85),
			Vector3.new(config.MapSize + 100, 20, config.MapSize * 0.35),
			Enum.Material.Sand
		)
		terrain:FillBlock(
			CFrame.new(0, -5, halfSize * 0.85),
			Vector3.new(config.MapSize + 100, 15, config.MapSize * 0.35),
			Enum.Material.Water
		)

		-- Rivers
		for _, river in ipairs(config.Water.Rivers) do
			createRiverSegment(terrain, river.Start, river.End, river.Width, river.Depth)
		end

		-- Lakes
		for _, lake in ipairs(config.Water.Lakes) do
			createLake(terrain, lake.Position, lake.Radius, lake.Depth)
		end

		-- Swamp water channels
		terrain:FillBlock(
			CFrame.new(halfSize * 0.55, -8, 0),
			Vector3.new(config.MapSize * 0.25, 12, config.MapSize * 0.4),
			Enum.Material.Sand
		)
		terrain:FillBlock(
			CFrame.new(halfSize * 0.55, -3, 0),
			Vector3.new(config.MapSize * 0.25, 8, config.MapSize * 0.4),
			Enum.Material.Water
		)
	end)
end

--[[
	Phase 5: Create cave systems
]]
local function createCaveSystems(terrain: Terrain, config: typeof(MapConfig)): boolean
	return safeExecute("Phase 5: Cave Systems", function()
		for _, cave in ipairs(config.Caves) do
			createCave(terrain, cave.Position, cave.Depth, cave.Width, cave.Height)
		end
	end)
end

--[[
	Phase 6: Create volcanic features
]]
local function createVolcanicFeatures(terrain: Terrain, config: typeof(MapConfig)): boolean
	return safeExecute("Phase 6: Volcanic Features", function()
		local halfSize = config.MapSize / 2
		for _ = 1, config.LavaPoolCount do
			local lavaX = math.random(-600, 600)
			local lavaZ = -halfSize + math.random(100, 700)
			terrain:FillBlock(
				CFrame.new(lavaX, 35, lavaZ),
				Vector3.new(math.random(30, 70), 8, math.random(30, 70)),
				Enum.Material.CrackedLava
			)
		end
	end)
end

--[[
	Phase 7: Create POI buildings
]]
local function createPOIBuildings(config: typeof(MapConfig)): boolean
	return safeExecute("Phase 7: POI Buildings", function()
		local terrain = workspace.Terrain
		local biomes = config.BiomeCenters

		-- JUNGLE BIOME
		local visitorCenterPos = Vector3.new(0, 30, -200)
		createBuilding("VisitorCenter_Main", visitorCenterPos, Vector3.new(80, 20, 60), BrickColor.new("Brick yellow"), Enum.Material.Concrete)
		createBuilding("VisitorCenter_GiftShop", visitorCenterPos + Vector3.new(-60, 0, 0), Vector3.new(30, 12, 25), BrickColor.new("Bright blue"), Enum.Material.Concrete)
		createBuilding("VisitorCenter_Restaurant", visitorCenterPos + Vector3.new(60, 0, 0), Vector3.new(35, 12, 30), BrickColor.new("Bright red"), Enum.Material.Concrete)
		createTower("VisitorCenter_Tower", visitorCenterPos + Vector3.new(0, 0, -50), 30)

		-- Hammond's Villa
		local hammondPos = Vector3.new(-300, 60, 100)
		terrain:FillBlock(CFrame.new(hammondPos.X, hammondPos.Y / 2, hammondPos.Z), Vector3.new(150, hammondPos.Y, 150), Enum.Material.Grass)
		createMultiStoryBuilding("HammondVilla_Main", hammondPos + Vector3.new(0, 5, 0), 3, Vector3.new(40, 12, 35), "Residential")
		createBuilding("HammondVilla_Garage", hammondPos + Vector3.new(40, 5, 20), Vector3.new(25, 10, 20), BrickColor.new("Medium stone grey"), Enum.Material.Concrete)
		createHouse("HammondVilla_GuestHouse", hammondPos + Vector3.new(-50, 5, 30), 18)

		-- Raptor Paddock
		local raptorPaddockPos = Vector3.new(300, 25, -100)
		createTower("RaptorPaddock_WatchTower1", raptorPaddockPos + Vector3.new(-40, 0, -40), 25)
		createTower("RaptorPaddock_WatchTower2", raptorPaddockPos + Vector3.new(40, 0, 40), 25)
		createBuilding("RaptorPaddock_ControlRoom", raptorPaddockPos, Vector3.new(25, 12, 20), BrickColor.new("Dark stone grey"), Enum.Material.Metal)

		-- PLAINS BIOME
		local plainsCenter = biomes.Plains
		createBuilding("SafariLodge_Main", plainsCenter, Vector3.new(60, 15, 45), BrickColor.new("Reddish brown"), Enum.Material.Wood)
		createBuilding("SafariLodge_Reception", plainsCenter + Vector3.new(-50, 0, 0), Vector3.new(25, 10, 20), BrickColor.new("Brown"), Enum.Material.Wood)
		createTower("SafariLodge_ViewingTower", plainsCenter + Vector3.new(60, 0, 30), 35)
		for i = 1, config.Buildings.SafariCabinCount do
			local cabinX = plainsCenter.X + 100 + (i * 40)
			local cabinZ = plainsCenter.Z + math.random(-50, 50)
			createHouse("SafariCabin" .. i, Vector3.new(cabinX, 15, cabinZ), 12)
		end

		-- VOLCANIC BIOME
		local volcanicCenter = biomes.Volcanic
		createIndustrialBuilding("GeothermalPlant", volcanicCenter)
		local observatoryPos = volcanicCenter + Vector3.new(300, 30, 200)
		terrain:FillBlock(CFrame.new(observatoryPos.X, observatoryPos.Y, observatoryPos.Z), Vector3.new(80, 60, 80), Enum.Material.Basalt)
		createMultiStoryBuilding("Observatory", observatoryPos + Vector3.new(0, 30, 0), 2, Vector3.new(30, 15, 30), "Industrial")
		local trexPaddockPos = volcanicCenter + Vector3.new(-400, 0, 300)
		createTower("TRexPaddock_Tower", trexPaddockPos, 40)
		createBuilding("TRexPaddock_Bunker", trexPaddockPos + Vector3.new(60, 0, 0), Vector3.new(30, 8, 25), BrickColor.new("Dark stone grey"), Enum.Material.Concrete)

		-- SWAMP BIOME
		local swampCenter = biomes.Swamp
		createMultiStoryBuilding("ResearchOutpost_Main", swampCenter, 2, Vector3.new(40, 12, 30), "Commercial")
		createBuilding("ResearchOutpost_Lab", swampCenter + Vector3.new(40, 0, -30), Vector3.new(30, 10, 25), BrickColor.new("White"), Enum.Material.SmoothPlastic)
		createTower("ResearchOutpost_Tower", swampCenter + Vector3.new(-50, 0, 20), 20)
		local boatDockPos = swampCenter + Vector3.new(200, 0, 100)
		createDock(boatDockPos, 80)
		createBuilding("BoatDock_Shed", boatDockPos + Vector3.new(-30, 0, 0), Vector3.new(20, 10, 15), BrickColor.new("Brown"), Enum.Material.Wood)

		-- COASTAL BIOME
		local coastalCenter = biomes.Coastal
		createLighthouse(coastalCenter + Vector3.new(-400, 0, 200))
		local harborPos = coastalCenter + Vector3.new(0, 0, -100)
		createDock(harborPos, 120)
		createWarehouse("Harbor_Warehouse", harborPos + Vector3.new(-60, 0, -50))
		createBuilding("Harbor_Office", harborPos + Vector3.new(50, 0, -30), Vector3.new(25, 12, 20), BrickColor.new("Brick yellow"), Enum.Material.Concrete)
		local resortPos = coastalCenter + Vector3.new(400, 0, 0)
		createMultiStoryBuilding("BeachResort_Main", resortPos, 4, Vector3.new(50, 12, 40), "Commercial")
		createBuilding("BeachResort_Restaurant", resortPos + Vector3.new(-60, 0, 30), Vector3.new(35, 12, 30), BrickColor.new("Bright blue"), Enum.Material.Concrete)

		-- Beach cabanas
		for i = 1, config.Buildings.CabanaCount do
			local cabanaPos = resortPos + Vector3.new(-200 + (i * 50), 0, 80)
			local cabana = Instance.new("Model")
			cabana.Name = "Cabana" .. i
			local floor = Instance.new("Part")
			floor.Name = "Floor"
			floor.Size = Vector3.new(10, 1, 10)
			floor.Position = cabanaPos + Vector3.new(0, 0.5, 0)
			floor.Anchored = true
			floor.BrickColor = BrickColor.new("Brown")
			floor.Material = Enum.Material.WoodPlanks
			floor.Parent = cabana
			local roof = Instance.new("Part")
			roof.Name = "Roof"
			roof.Size = Vector3.new(12, 1, 12)
			roof.Position = cabanaPos + Vector3.new(0, 8, 0)
			roof.Anchored = true
			roof.BrickColor = BrickColor.new("Brick yellow")
			roof.Material = Enum.Material.Fabric
			roof.Parent = cabana
			for x = -1, 1, 2 do
				for z = -1, 1, 2 do
					local pole = Instance.new("Part")
					pole.Name = "Pole"
					pole.Size = Vector3.new(1, 8, 1)
					pole.Position = cabanaPos + Vector3.new(x * 4, 4, z * 4)
					pole.Anchored = true
					pole.BrickColor = BrickColor.new("Brown")
					pole.Material = Enum.Material.Wood
					pole.Parent = cabana
				end
			end
			cabana.Parent = getOrCreateFolder("Structures")
		end
	end)
end

--[[
	Phase 8: Create vegetation
]]
local function createVegetation(config: typeof(MapConfig)): boolean
	return safeExecute("Phase 8: Vegetation", function()
		local terrain = workspace.Terrain
		local biomes = config.BiomeCenters
		local veg = config.Vegetation
		local yieldInterval = config.VegetationYieldInterval
		local itemsCreated = 0

		-- JUNGLE VEGETATION
		for _ = 1, veg.JungleTreeClusters do
			local clusterX = math.random(-500, 500)
			local clusterZ = math.random(-500, 400)
			if math.abs(clusterX) > 120 or math.abs(clusterZ - (-200)) > 100 then
				createTreeCluster(Vector3.new(clusterX, 25, clusterZ), 80, math.random(4, 8), "jungle", 28)
			end
			itemsCreated = itemsCreated + 1
			if itemsCreated % yieldInterval == 0 then task.wait() end
		end

		for _ = 1, veg.JungleIndividualTrees do
			local treeX = math.random(-600, 600)
			local treeZ = math.random(-600, 500)
			if math.abs(treeX) > 100 or math.abs(treeZ - (-200)) > 80 then
				createFloraTree(Vector3.new(treeX, 25, treeZ), math.random() > 0.5 and "jungle" or "jungleMedium")
			end
			itemsCreated = itemsCreated + 1
			if itemsCreated % yieldInterval == 0 then task.wait() end
		end

		for _ = 1, veg.JungleGrassPatches do
			createGrassPatch(terrain, Vector3.new(math.random(-500, 500), 25, math.random(-500, 400)), math.random(20, 50))
		end

		for _ = 1, veg.JungleFlowerPatches do
			pcall(function()
				FloraGenerator.CreateFlowerPatch(
					Vector3.new(math.random(-500, 500), 25, math.random(-500, 400)),
					math.random(5, 15),
					"Jungle"
				)
			end)
		end

		-- PLAINS VEGETATION
		local plainsCenter = biomes.Plains
		for _ = 1, veg.PlainsTreeClusters do
			local clusterX = plainsCenter.X + math.random(-600, 600)
			local clusterZ = plainsCenter.Z + math.random(-600, 600)
			createTreeCluster(Vector3.new(clusterX, 18, clusterZ), 60, math.random(2, 4), "oak", 18)
			itemsCreated = itemsCreated + 1
			if itemsCreated % yieldInterval == 0 then task.wait() end
		end

		for _ = 1, veg.PlainsBirchTrees do
			local treeX = plainsCenter.X + math.random(-700, 700)
			local treeZ = plainsCenter.Z + math.random(-700, 700)
			createFloraTree(Vector3.new(treeX, 15, treeZ), "birch")
			itemsCreated = itemsCreated + 1
			if itemsCreated % yieldInterval == 0 then task.wait() end
		end

		for _ = 1, veg.PlainsGrassPatches do
			createGrassPatch(terrain, Vector3.new(plainsCenter.X + math.random(-600, 600), 18, plainsCenter.Z + math.random(-600, 600)), math.random(30, 80))
		end

		for _ = 1, veg.PlainsRockFormations do
			createRockFormation(Vector3.new(plainsCenter.X + math.random(-500, 500), 18, plainsCenter.Z + math.random(-500, 500)), math.random(4, 8), 3, 10)
		end

		for _ = 1, veg.PlainsFlowerPatches do
			pcall(function()
				FloraGenerator.CreateFlowerPatch(
					Vector3.new(plainsCenter.X + math.random(-600, 600), 18, plainsCenter.Z + math.random(-600, 600)),
					math.random(8, 20),
					"Plains"
				)
			end)
		end

		-- VOLCANIC VEGETATION
		local volcanicCenter = biomes.Volcanic
		for _ = 1, veg.VolcanicTrees do
			local treeX = volcanicCenter.X + math.random(-700, 700)
			local treeZ = volcanicCenter.Z + math.random(-400, 500)
			createFloraTree(Vector3.new(treeX, 45, treeZ), math.random() > 0.6 and "charred" or "heatResistant")
			itemsCreated = itemsCreated + 1
			if itemsCreated % yieldInterval == 0 then task.wait() end
		end

		for _ = 1, veg.VolcanicRockFormations do
			createRockFormation(
				Vector3.new(volcanicCenter.X + math.random(-600, 600), 45, volcanicCenter.Z + math.random(-400, 400)),
				math.random(5, 12), 5, 20, Enum.Material.Basalt
			)
		end

		for _ = 1, veg.VolcanicScatteredRocks do
			local rockX = volcanicCenter.X + math.random(-800, 800)
			local rockZ = volcanicCenter.Z + math.random(-500, 500)
			createRock(Vector3.new(rockX, 45, rockZ), math.random(4, 15), Enum.Material.Basalt)
		end

		-- Volcanic ruins
		for _, ruin in ipairs(config.Buildings.Ruins) do
			createRuins(ruin.Name, volcanicCenter + ruin.Position, ruin.Size)
		end

		-- SWAMP VEGETATION
		local swampCenter = biomes.Swamp
		for _ = 1, veg.SwampTreeClusters do
			local clusterX = swampCenter.X + math.random(-500, 500)
			local clusterZ = swampCenter.Z + math.random(-500, 500)
			createTreeCluster(Vector3.new(clusterX, 12, clusterZ), 50, math.random(3, 6), "dead", 15)
			itemsCreated = itemsCreated + 1
			if itemsCreated % yieldInterval == 0 then task.wait() end
		end

		for _ = 1, veg.SwampIndividualTrees do
			local treeX = swampCenter.X + math.random(-600, 600)
			local treeZ = swampCenter.Z + math.random(-600, 600)
			createFloraTree(Vector3.new(treeX, 12, treeZ), math.random() > 0.4 and "dead" or "cypress")
			itemsCreated = itemsCreated + 1
			if itemsCreated % yieldInterval == 0 then task.wait() end
		end

		-- Swamp stilt houses
		for i = 1, config.Buildings.StiltHouseCount do
			local housePos = swampCenter + Vector3.new(math.random(-400, 400), 8, math.random(-400, 400))
			local stilts = Instance.new("Model")
			stilts.Name = "StiltHouse" .. i
			for x = -1, 1, 2 do
				for z = -1, 1, 2 do
					local stilt = Instance.new("Part")
					stilt.Name = "Stilt"
					stilt.Size = Vector3.new(2, 15, 2)
					stilt.Position = housePos + Vector3.new(x * 5, 7.5, z * 5)
					stilt.Anchored = true
					stilt.BrickColor = BrickColor.new("Brown")
					stilt.Material = Enum.Material.Wood
					stilt.Parent = stilts
				end
			end
			stilts.Parent = getOrCreateFolder("Structures")
			createHouse("SwampHouse" .. i, housePos + Vector3.new(0, 15, 0), math.random(12, 16))
		end

		-- COASTAL VEGETATION
		local coastalCenter = biomes.Coastal
		for _ = 1, veg.CoastalTreeClusters do
			local clusterX = coastalCenter.X + math.random(-700, 700)
			local clusterZ = coastalCenter.Z + math.random(-300, 200)
			createTreeCluster(Vector3.new(clusterX, 10, clusterZ), 60, math.random(4, 7), "palm", 18)
			itemsCreated = itemsCreated + 1
			if itemsCreated % yieldInterval == 0 then task.wait() end
		end

		for _ = 1, veg.CoastalIndividualTrees do
			local palmX = coastalCenter.X + math.random(-800, 800)
			local palmZ = coastalCenter.Z + math.random(-400, 300)
			createFloraTree(Vector3.new(palmX, 8, palmZ), math.random() > 0.3 and "palm" or "pine")
			itemsCreated = itemsCreated + 1
			if itemsCreated % yieldInterval == 0 then task.wait() end
		end

		for _ = 1, veg.CoastalRockFormations do
			createRockFormation(
				Vector3.new(coastalCenter.X + math.random(-600, 600), 8, coastalCenter.Z + math.random(0, 300)),
				math.random(3, 7), 2, 8, Enum.Material.Sandstone
			)
		end
	end)
end

--[[
	Phase 9: Create scattered buildings
]]
local function createScatteredBuildings(config: typeof(MapConfig)): boolean
	return safeExecute("Phase 9: Scattered Buildings", function()
		-- Apartments
		for _, apt in ipairs(config.Buildings.Apartments) do
			createApartmentBuilding(apt.Name, apt.Position, apt.Floors)
		end

		-- Warehouses
		for _, wh in ipairs(config.Buildings.Warehouses) do
			createWarehouse(wh.Name, wh.Position)
		end

		-- Scattered houses
		for i, loc in ipairs(config.Buildings.Houses) do
			createHouse("ScatteredHouse" .. i, loc.Position, loc.Size)
		end

		-- Sheds
		for i = 1, config.Buildings.ShedCount do
			local shedX = math.random(-1500, 1500)
			local shedZ = math.random(-1200, 1200)
			local shedY = 15
			if shedZ < -800 then shedY = 45 end
			if shedX > 800 then shedY = 12 end
			if shedZ > 800 then shedY = 10 end
			createShed("Shed" .. i, Vector3.new(shedX, shedY, shedZ), math.random(8, 14))
		end

		-- Guard towers
		for _, tower in ipairs(config.Buildings.GuardTowers) do
			createTower(tower.Name, tower.Position, tower.Height)
		end

		-- Research buildings
		for _, research in ipairs(config.Buildings.ResearchBuildings) do
			createMultiStoryBuilding(research.Name, research.Position, research.Floors, research.Footprint, "Commercial")
		end
	end)
end

--[[
	Phase 10: Create loot caches
]]
local function createLootCaches(config: typeof(MapConfig)): boolean
	return safeExecute("Phase 10: Loot Caches", function()
		local spawnCenter = config.GetSpawnCenter()
		local cacheTypes = config.LootCacheTypes
		local lootCacheCount = 16

		-- Ring pattern around spawn
		for i = 1, lootCacheCount do
			local ring = math.ceil(i / 8)
			local angleOffset = (ring - 1) * 0.25
			local angle = ((i - 1) / 8) * math.pi * 2 + angleOffset
			local distance = config.LootRingDistances.Inner + (ring - 1) * (config.LootRingDistances.Outer - config.LootRingDistances.Inner) + math.random(-20, 20)

			local cacheX = spawnCenter.X + math.cos(angle) * distance
			local cacheZ = spawnCenter.Z + math.sin(angle) * distance

			local cacheType = cacheTypes[math.random(1, #cacheTypes)]
			createLootCache(Vector3.new(cacheX, spawnCenter.Y, cacheZ), cacheType)
		end

		-- Additional random loot
		for _ = 1, 20 do
			local angle = math.random() * math.pi * 2
			local distance = 50 + math.random() * 250
			local lootX = spawnCenter.X + math.cos(angle) * distance
			local lootZ = spawnCenter.Z + math.sin(angle) * distance

			local cacheType = cacheTypes[math.random(1, #cacheTypes)]
			createLootCache(Vector3.new(lootX, spawnCenter.Y, lootZ), cacheType)
		end
	end)
end

--[[
	Phase 11: Create foliage details (bushes, ferns, flowers)
]]
local function createFoliageDetails(config: typeof(MapConfig)): boolean
	return safeExecute("Phase 11: Foliage Details", function()
		local veg = config.Vegetation
		local biomes = config.BiomeCenters
		local spawnCenter = config.GetSpawnCenter()

		-- Bushes
		for _ = 1, veg.TotalBushes do
			local bushX = math.random(-1800, 1800)
			local bushZ = math.random(-1500, 1500)
			local bushY = 20
			if bushZ < -800 then bushY = 45 end
			if bushX > 800 then bushY = 12 end
			if bushZ > 800 then bushY = 10 end
			createBush(Vector3.new(bushX, bushY, bushZ), math.random(2, 5))
		end

		-- Jungle ferns
		for _ = 1, veg.JungleFerns do
			local fernX = math.random(-600, 600)
			local fernZ = math.random(-500, 400)
			createFern(Vector3.new(fernX, 25, fernZ))
		end

		-- Swamp ferns
		local swampCenter = biomes.Swamp
		for _ = 1, veg.SwampFerns do
			local fernX = swampCenter.X + math.random(-500, 500)
			local fernZ = swampCenter.Z + math.random(-500, 500)
			createFern(Vector3.new(fernX, 12, fernZ))
		end

		-- Plains flowers
		local plainsCenter = biomes.Plains
		for _ = 1, veg.PlainsDetailFlowers do
			local flowerX = plainsCenter.X + math.random(-600, 600)
			local flowerZ = plainsCenter.Z + math.random(-600, 600)
			createFlowerPatch(Vector3.new(flowerX, 18, flowerZ), math.random(5, 12))
		end

		-- Coastal flowers
		local coastalCenter = biomes.Coastal
		for _ = 1, veg.CoastalDetailFlowers do
			local flowerX = coastalCenter.X + math.random(-600, 600)
			local flowerZ = coastalCenter.Z + math.random(-200, 200)
			createFlowerPatch(Vector3.new(flowerX, 10, flowerZ), math.random(4, 8))
		end

		-- Spawn area bushes
		for _ = 1, veg.SpawnAreaBushes do
			local angle = math.random() * math.pi * 2
			local dist = 50 + math.random() * 150
			local bushX = spawnCenter.X + math.cos(angle) * dist
			local bushZ = spawnCenter.Z + math.sin(angle) * dist
			createBush(Vector3.new(bushX, spawnCenter.Y, bushZ), math.random(3, 6))
		end
	end)
end

--[[
	Phase 12: Create final rock details
]]
local function createRockDetails(config: typeof(MapConfig)): boolean
	return safeExecute("Phase 12: Rock Details", function()
		for _ = 1, config.Vegetation.FinalRockDetails do
			local x = math.random(-1800, 1800)
			local z = math.random(-1600, 1600)
			local y = 20
			if z < -800 then y = 45 end
			if x > 900 then y = 12 end
			if z > 900 then y = 10 end
			createRock(Vector3.new(x, y, z), math.random(2, 8))
		end
	end)
end

--------------------------------------------------------------------------------
-- MAIN TERRAIN GENERATION
--------------------------------------------------------------------------------

--[[
	Create the full 4km x 4km multi-biome terrain
	Split into separate phases for maintainability and error tracking
]]
local function createBaseTerrain()
	local terrain = workspace.Terrain
	local config = MapConfig

	-- Reset generation results
	generationResults = {}

	print("===========================================")
	print("[MapManager] GENERATING ISLA PRIMORDIAL")
	print("  Size: 4km x 4km (4000 studs)")
	print("  Biomes: Jungle, Plains, Volcanic, Swamp, Coastal")
	print("  Features: Rivers, Lakes, Caves, Dense Foliage")
	print("  Coverage: 30% Water, 30% Foliage/Structures")
	print("===========================================")

	-- Ensure folders exist
	ensureFoldersExist()

	-- Clean up existing objects
	local cleanupNames = {
		"TempSpawnPlatform", "SpawnPlatform", "TempSpawn",
		"LobbySpawn", "LobbyPlatform", "TempLobbyPlatform", "FallbackSpawnPlatform"
	}
	for _, name in ipairs(cleanupNames) do
		local obj = workspace:FindFirstChild(name)
		if obj then
			obj:Destroy()
		end
	end

	-- Clear existing terrain and height cache
	print("[MapManager] Clearing existing terrain...")
	terrain:Clear()
	clearHeightCache()

	-- Execute all phases
	createBaseLayer(terrain, config)
	createSpawnArea(terrain, config)

	local terrainSuccess, biomeCounts = generateTerrainCells(terrain, config)

	createWaterSystem(terrain, config)
	createCaveSystems(terrain, config)
	createVolcanicFeatures(terrain, config)
	createPOIBuildings(config)
	createVegetation(config)
	createScatteredBuildings(config)
	createLootCaches(config)
	createFoliageDetails(config)
	createRockDetails(config)

	-- Phase 13: Environmental props (cover, decorations, particles)
	safeExecute("Phase 13: Environmental Props", function()
		EnvironmentalPropsGenerator.GenerateMapProps()
	end)

	task.wait() -- Final yield

	-- Print generation summary
	printGenerationSummary()

	print("===========================================")
	print("[MapManager] TERRAIN GENERATION COMPLETE!")
	if biomeCounts then
		print(`  Biome distribution:`)
		print(`    Jungle: {biomeCounts.jungle or 0} | Plains: {biomeCounts.plains or 0}`)
		print(`    Volcanic: {biomeCounts.volcanic or 0} | Swamp: {biomeCounts.swamp or 0}`)
		print(`    Coastal: {biomeCounts.coastal or 0}`)
	end
	print("  Features added:")
	print("    - Solid base layer (no gaps)")
	print("    - Rivers with solid beds")
	print("    - Lakes with terrain beds")
	print("    - Accessible caves")
	print("    - Trees (ground-anchored)")
	print("    - Multi-story buildings with interiors")
	print("    - Scattered structures (ground-anchored)")
	print("    - Loot caches near spawn")
	print("    - Bushes, ferns, flower patches")
	print("    - Strategic cover props per biome")
	print("    - Decorative environmental props")
	print("    - Biome-specific landmarks")
	print("  Coverage: ~30% water, ~30% foliage/structures")
	print("===========================================")
end

--------------------------------------------------------------------------------
-- PUBLIC API: INITIALIZATION & LIFECYCLE
--------------------------------------------------------------------------------

--[[
	Initialize the map manager
]]
function MapManager.Initialize()
	if isInitialized then return end

	print("[MapManager] Initializing Isla Primordial...")

	-- Create base terrain first
	createBaseTerrain()

	-- Initialize sub-managers
	BiomeManager.Initialize()
	POIManager.Initialize()
	EnvironmentalEventManager.Initialize()

	-- Count POIs
	local poiCount = 0
	for _ in pairs(POIData.POIs) do
		poiCount = poiCount + 1
	end
	MAP_INFO.poiCount = poiCount

	-- Setup event handlers
	setupEventHandlers()

	isInitialized = true

	print("[MapManager] Initialized")
	print(`  Map: {MAP_INFO.name}`)
	print(`  Size: {MAP_INFO.size.width}x{MAP_INFO.size.height} studs`)
	print(`  Biomes: {MAP_INFO.biomeCount}`)
	print(`  POIs: {MAP_INFO.poiCount}`)
end

--[[
	Start new match (spawn all POI content)
]]
function MapManager.StartMatch()
	POIManager.InitializeAllPOIs()
	print("[MapManager] Match started - all POIs initialized")
end

--[[
	Reset for new match - clears dynamic objects and respawns loot
]]
function MapManager.Reset()
	print("[MapManager] Resetting map for new match...")

	currentMatchPhase = "Lobby"

	-- Clear loot caches folder
	local lootFolder = workspace:FindFirstChild("LootCaches")
	if lootFolder then
		for _, child in ipairs(lootFolder:GetChildren()) do
			child:Destroy()
		end
	end

	-- Reset sub-managers
	BiomeManager.Reset()
	POIManager.Reset()
	EnvironmentalEventManager.Reset()
	EnvironmentalPropsGenerator.Reset()

	-- Respawn loot caches
	createLootCaches(MapConfig)

	-- Clear height cache (terrain doesn't change, but good for consistency)
	clearHeightCache()

	print("[MapManager] Map reset complete")
end

--[[
	Full reset for new match (alias for Reset)
]]
function MapManager.ResetForNewMatch()
	MapManager.Reset()
end

return MapManager
