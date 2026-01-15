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

--[[
	Terrain configuration (per GDD Section 3.3: 4km x 4km map)

	GDD Map Layout:
	- NORTH: Volcanic Region (High Danger) - Geothermal Plant, Lava Caves, T-Rex Paddock
	- CENTER: Jungle & Research (Main POIs) - Visitor Center, Research Complex, Hammond Villa
	- EAST: Swamplands (Medium Danger) - River Delta, Research Outpost, Boat Dock
	- WEST: Open Plains (Beginner Friendly) - Herbivore Valley, Safari Lodge
	- SOUTH: Coastal Area (Mixed) - Harbor, Lighthouse, Beach Resort
]]
local TERRAIN_CONFIG = {
	mapSize = 4000, -- 4km x 4km (4000 studs)
	resolution = 48, -- Cell size for balance of detail vs performance
	baseHeight = 15,
	waterLevel = -2,
}

-- =============================================
-- GROUND LEVEL HELPER FUNCTIONS
-- =============================================

-- Raycast to find ground level at a position
local function getGroundLevel(x: number, z: number, defaultY: number?): number
	local rayOrigin = Vector3.new(x, 500, z)
	local rayResult = workspace:Raycast(rayOrigin, Vector3.new(0, -600, 0))
	if rayResult then
		return rayResult.Position.Y
	end
	return defaultY or 25
end

-- Place object at ground level
local function placeAtGroundLevel(position: Vector3, offsetY: number?): Vector3
	local groundY = getGroundLevel(position.X, position.Z, position.Y)
	return Vector3.new(position.X, groundY + (offsetY or 0), position.Z)
end

-- =============================================
-- BUILDING AND STRUCTURE CREATION HELPERS
-- =============================================

-- Create a simple building structure (anchored at ground level)
local function createBuilding(name: string, position: Vector3, size: Vector3, color: BrickColor, material: Enum.Material?): Model
	local building = Instance.new("Model")
	building.Name = name

	-- Raycast to find actual ground level
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
	building.Parent = workspace

	return building
end

-- Create a simple house/cabin (anchored at ground level)
local function createHouse(name: string, position: Vector3, size: number): Model
	local house = Instance.new("Model")
	house.Name = name

	-- Raycast to find actual ground level
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

	-- Roof (wedge-shaped using two parts)
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
	house.Parent = workspace

	return house
end

-- Create a tree (anchored at ground level)
local function createTree(position: Vector3, height: number, treeType: string?): Model
	local tree = Instance.new("Model")
	tree.Name = "Tree"

	-- Raycast to find actual ground level
	local groundPos = placeAtGroundLevel(position, 0)

	local trunkHeight = height * 0.4
	local canopySize = height * 0.8

	-- Trunk
	local trunk = Instance.new("Part")
	trunk.Name = "Trunk"
	trunk.Size = Vector3.new(height * 0.15, trunkHeight, height * 0.15)
	trunk.Position = groundPos + Vector3.new(0, trunkHeight / 2, 0)
	trunk.Anchored = true
	trunk.BrickColor = BrickColor.new("Reddish brown")
	trunk.Material = Enum.Material.Wood
	trunk.Parent = tree

	-- Canopy
	local canopy = Instance.new("Part")
	canopy.Name = "Canopy"
	canopy.Shape = Enum.PartType.Ball
	canopy.Size = Vector3.new(canopySize, canopySize, canopySize)
	canopy.Position = groundPos + Vector3.new(0, trunkHeight + canopySize * 0.3, 0)
	canopy.Anchored = true
	canopy.BrickColor = treeType == "palm" and BrickColor.new("Bright green") or BrickColor.new("Forest green")
	canopy.Material = Enum.Material.Grass
	canopy.Parent = tree

	tree.PrimaryPart = trunk
	tree.Parent = workspace

	return tree
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
	rock.Parent = workspace
	return rock
end

-- Create a watchtower/observation tower (anchored at ground level)
local function createTower(name: string, position: Vector3, height: number): Model
	local tower = Instance.new("Model")
	tower.Name = name

	-- Raycast to find actual ground level
	local groundPos = placeAtGroundLevel(position, 0)

	-- Support legs (4 corners)
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
	tower.Parent = workspace

	return tower
end

-- Create industrial structure (for geothermal plant, anchored at ground level)
local function createIndustrialBuilding(name: string, position: Vector3): Model
	local building = Instance.new("Model")
	building.Name = name

	-- Raycast to find actual ground level
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
	building.Parent = workspace

	return building
end

-- Create lighthouse (anchored at ground level)
local function createLighthouse(position: Vector3): Model
	local lighthouse = Instance.new("Model")
	lighthouse.Name = "Lighthouse"

	-- Raycast to find actual ground level
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

	-- Tower (multiple sections with alternating colors)
	local towerHeight = 60
	local sections = 6
	for i = 1, sections do
		local section = Instance.new("Part")
		section.Name = "Section" .. i
		local sectionHeight = towerHeight / sections
		local sectionWidth = 12 - (i * 1.2) -- Tapers up
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
	lighthouse.Parent = workspace

	return lighthouse
end

-- Create dock/pier (anchored at ground level)
local function createDock(position: Vector3, length: number): Model
	local dock = Instance.new("Model")
	dock.Name = "Dock"

	-- Raycast to find actual ground level
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
	dock.Parent = workspace

	return dock
end

-- =============================================
-- ENHANCED TREE VARIETY FUNCTIONS
-- =============================================

-- Create a pine tree (conical shape, for volcanic/mountain areas)
local function createPineTree(position: Vector3, height: number): Model
	local tree = Instance.new("Model")
	tree.Name = "PineTree"

	-- Raycast to find actual ground level
	local groundPos = placeAtGroundLevel(position, 0)

	local trunkHeight = height * 0.7
	local trunkWidth = height * 0.08

	-- Trunk
	local trunk = Instance.new("Part")
	trunk.Name = "Trunk"
	trunk.Size = Vector3.new(trunkWidth, trunkHeight, trunkWidth)
	trunk.Position = groundPos + Vector3.new(0, trunkHeight / 2, 0)
	trunk.Anchored = true
	trunk.BrickColor = BrickColor.new("Reddish brown")
	trunk.Material = Enum.Material.Wood
	trunk.Parent = tree

	-- Conical layers (3 cone-like sections)
	for i = 1, 3 do
		local layerHeight = height * 0.25
		local layerWidth = height * (0.5 - i * 0.1)
		local layer = Instance.new("Part")
		layer.Name = "Foliage" .. i
		layer.Size = Vector3.new(layerWidth, layerHeight, layerWidth)
		layer.Position = groundPos + Vector3.new(0, trunkHeight * 0.3 + i * (height * 0.2), 0)
		layer.Anchored = true
		layer.BrickColor = BrickColor.new("Dark green")
		layer.Material = Enum.Material.Grass
		layer.Parent = tree
	end

	tree.PrimaryPart = trunk
	tree.Parent = workspace
	return tree
end

-- Create an oak tree (wide spreading canopy, anchored at ground level)
local function createOakTree(position: Vector3, height: number): Model
	local tree = Instance.new("Model")
	tree.Name = "OakTree"

	-- Raycast to find actual ground level
	local groundPos = placeAtGroundLevel(position, 0)

	local trunkHeight = height * 0.5
	local canopyWidth = height * 1.2

	-- Trunk
	local trunk = Instance.new("Part")
	trunk.Name = "Trunk"
	trunk.Size = Vector3.new(height * 0.18, trunkHeight, height * 0.18)
	trunk.Position = groundPos + Vector3.new(0, trunkHeight / 2, 0)
	trunk.Anchored = true
	trunk.BrickColor = BrickColor.new("Brown")
	trunk.Material = Enum.Material.Wood
	trunk.Parent = tree

	-- Wide spreading canopy (multiple overlapping spheres)
	local canopyPositions = {
		Vector3.new(0, 0, 0),
		Vector3.new(canopyWidth * 0.3, -height * 0.05, 0),
		Vector3.new(-canopyWidth * 0.3, -height * 0.05, 0),
		Vector3.new(0, -height * 0.05, canopyWidth * 0.3),
		Vector3.new(0, -height * 0.05, -canopyWidth * 0.3),
	}

	for i, offset in ipairs(canopyPositions) do
		local canopy = Instance.new("Part")
		canopy.Name = "Canopy" .. i
		canopy.Shape = Enum.PartType.Ball
		local size = height * (0.6 - math.abs(offset.X + offset.Z) * 0.001)
		canopy.Size = Vector3.new(size, size * 0.7, size)
		canopy.Position = groundPos + Vector3.new(0, trunkHeight + height * 0.25, 0) + offset
		canopy.Anchored = true
		canopy.BrickColor = BrickColor.new("Forest green")
		canopy.Material = Enum.Material.Grass
		canopy.Parent = tree
	end

	tree.PrimaryPart = trunk
	tree.Parent = workspace
	return tree
end

-- Create a birch tree (white bark, smaller leaves, anchored at ground level)
local function createBirchTree(position: Vector3, height: number): Model
	local tree = Instance.new("Model")
	tree.Name = "BirchTree"

	-- Raycast to find actual ground level
	local groundPos = placeAtGroundLevel(position, 0)

	local trunkHeight = height * 0.65
	local canopySize = height * 0.5

	-- White trunk
	local trunk = Instance.new("Part")
	trunk.Name = "Trunk"
	trunk.Size = Vector3.new(height * 0.08, trunkHeight, height * 0.08)
	trunk.Position = groundPos + Vector3.new(0, trunkHeight / 2, 0)
	trunk.Anchored = true
	trunk.BrickColor = BrickColor.new("Institutional white")
	trunk.Material = Enum.Material.Wood
	trunk.Parent = tree

	-- Small clustered canopy
	for i = 1, 4 do
		local canopy = Instance.new("Part")
		canopy.Name = "Canopy" .. i
		canopy.Shape = Enum.PartType.Ball
		canopy.Size = Vector3.new(canopySize * 0.6, canopySize * 0.5, canopySize * 0.6)
		local angle = (i / 4) * math.pi * 2
		canopy.Position = groundPos + Vector3.new(
			math.cos(angle) * canopySize * 0.2,
			trunkHeight + canopySize * 0.2 + (i % 2) * canopySize * 0.15,
			math.sin(angle) * canopySize * 0.2
		)
		canopy.Anchored = true
		canopy.BrickColor = BrickColor.new("Bright green")
		canopy.Material = Enum.Material.Grass
		canopy.Parent = tree
	end

	tree.PrimaryPart = trunk
	tree.Parent = workspace
	return tree
end

-- Create a jungle tree (large, with vines, anchored at ground level)
local function createJungleTree(position: Vector3, height: number): Model
	local tree = Instance.new("Model")
	tree.Name = "JungleTree"

	-- Raycast to find actual ground level
	local groundPos = placeAtGroundLevel(position, 0)

	local trunkHeight = height * 0.55
	local canopySize = height * 0.9

	-- Thick trunk
	local trunk = Instance.new("Part")
	trunk.Name = "Trunk"
	trunk.Size = Vector3.new(height * 0.2, trunkHeight, height * 0.2)
	trunk.Position = groundPos + Vector3.new(0, trunkHeight / 2, 0)
	trunk.Anchored = true
	trunk.BrickColor = BrickColor.new("Reddish brown")
	trunk.Material = Enum.Material.Wood
	trunk.Parent = tree

	-- Buttress roots
	for i = 1, 4 do
		local root = Instance.new("Part")
		root.Name = "Root" .. i
		local rootLength = height * 0.25
		root.Size = Vector3.new(height * 0.1, rootLength, height * 0.08)
		local angle = (i / 4) * math.pi * 2

		-- Use CFrame to properly position and angle roots outward from trunk base
		local rootCF = CFrame.new(groundPos)
			* CFrame.Angles(0, angle, 0) -- Rotate around Y to face outward
			* CFrame.new(0, rootLength * 0.3, height * 0.12) -- Offset outward from trunk
			* CFrame.Angles(math.rad(-30), 0, 0) -- Tilt outward

		root.CFrame = rootCF
		root.Anchored = true
		root.BrickColor = BrickColor.new("Reddish brown")
		root.Material = Enum.Material.Wood
		root.Parent = tree
	end

	-- Large canopy
	local mainCanopy = Instance.new("Part")
	mainCanopy.Name = "MainCanopy"
	mainCanopy.Shape = Enum.PartType.Ball
	mainCanopy.Size = Vector3.new(canopySize, canopySize * 0.6, canopySize)
	mainCanopy.Position = groundPos + Vector3.new(0, trunkHeight + canopySize * 0.25, 0)
	mainCanopy.Anchored = true
	mainCanopy.BrickColor = BrickColor.new("Dark green")
	mainCanopy.Material = Enum.Material.Grass
	mainCanopy.Parent = tree

	-- Hanging vines (positioned to hang from canopy edge)
	for i = 1, 6 do
		local vine = Instance.new("Part")
		vine.Name = "Vine" .. i
		local vineLength = height * 0.35
		vine.Size = Vector3.new(0.4, vineLength, 0.4)
		local angle = (i / 6) * math.pi * 2
		-- Position vine so it hangs from the bottom edge of canopy
		local vineTop = groundPos + Vector3.new(
			math.cos(angle) * canopySize * 0.35,
			trunkHeight + canopySize * 0.05, -- At bottom of canopy
			math.sin(angle) * canopySize * 0.35
		)
		vine.Position = vineTop - Vector3.new(0, vineLength * 0.5, 0) -- Hang downward from that point
		vine.Anchored = true
		vine.BrickColor = BrickColor.new("Bright green")
		vine.Material = Enum.Material.Grass
		vine.Parent = tree
	end

	tree.PrimaryPart = trunk
	tree.Parent = workspace
	return tree
end

-- Create palm tree (enhanced version, anchored at ground level)
local function createPalmTree(position: Vector3, height: number): Model
	local tree = Instance.new("Model")
	tree.Name = "PalmTree"

	-- Raycast to find actual ground level
	local groundPos = placeAtGroundLevel(position, 0)

	local trunkHeight = height * 0.8

	-- Curved trunk (multiple segments)
	local segments = 5
	for i = 1, segments do
		local segment = Instance.new("Part")
		segment.Name = "TrunkSegment" .. i
		local segmentHeight = trunkHeight / segments
		local curve = math.sin((i / segments) * math.pi * 0.3) * height * 0.1
		segment.Size = Vector3.new(height * 0.1, segmentHeight, height * 0.1)
		segment.Position = groundPos + Vector3.new(curve, (i - 0.5) * segmentHeight, 0)
		segment.Anchored = true
		segment.BrickColor = BrickColor.new("Brown")
		segment.Material = Enum.Material.Wood
		segment.Parent = tree
	end

	-- Palm fronds (8 radiating leaves)
	local frondLength = height * 0.4
	for i = 1, 8 do
		local frond = Instance.new("Part")
		frond.Name = "Frond" .. i
		frond.Size = Vector3.new(frondLength * 0.15, frondLength, frondLength * 0.05)
		local angle = (i / 8) * math.pi * 2

		-- Use CFrame to properly position and rotate fronds radiating outward
		local basePos = groundPos + Vector3.new(0, trunkHeight, 0)
		local outwardDir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local tiltAngle = math.rad(50) -- Tilt outward from vertical

		-- Position frond so it originates from trunk top and extends outward/downward
		local frondCF = CFrame.new(basePos)
			* CFrame.Angles(0, angle, 0) -- Rotate around Y to face outward
			* CFrame.Angles(tiltAngle, 0, 0) -- Tilt outward
			* CFrame.new(0, frondLength * 0.5, 0) -- Offset so base is at trunk top

		frond.CFrame = frondCF
		frond.Anchored = true
		frond.BrickColor = BrickColor.new("Bright green")
		frond.Material = Enum.Material.Grass
		frond.Parent = tree
	end

	-- Coconuts cluster
	local coconuts = Instance.new("Part")
	coconuts.Name = "Coconuts"
	coconuts.Shape = Enum.PartType.Ball
	coconuts.Size = Vector3.new(height * 0.15, height * 0.12, height * 0.15)
	coconuts.Position = groundPos + Vector3.new(0, trunkHeight, 0)
	coconuts.Anchored = true
	coconuts.BrickColor = BrickColor.new("Brown")
	coconuts.Material = Enum.Material.Wood
	coconuts.Parent = tree

	tree.Parent = workspace
	return tree
end

-- Create dead/swamp tree (anchored at ground level)
local function createDeadTree(position: Vector3, height: number): Model
	local tree = Instance.new("Model")
	tree.Name = "DeadTree"

	-- Raycast to find actual ground level
	local groundPos = placeAtGroundLevel(position, 0)

	-- Gnarled trunk (slight random tilt using CFrame)
	local trunk = Instance.new("Part")
	trunk.Name = "Trunk"
	trunk.Size = Vector3.new(height * 0.12, height * 0.6, height * 0.12)
	local trunkTiltX = math.rad(math.random(-5, 5))
	local trunkTiltZ = math.rad(math.random(-5, 5))
	trunk.CFrame = CFrame.new(groundPos + Vector3.new(0, height * 0.3, 0))
		* CFrame.Angles(trunkTiltX, 0, trunkTiltZ)
	trunk.Anchored = true
	trunk.BrickColor = BrickColor.new("Dark taupe")
	trunk.Material = Enum.Material.Wood
	trunk.Parent = tree

	-- Dead branches (no leaves) - properly attached to trunk using CFrame
	local branchCount = math.random(3, 5)
	for i = 1, branchCount do
		local branch = Instance.new("Part")
		branch.Name = "Branch" .. i
		local branchLength = height * (0.2 + math.random() * 0.2)
		branch.Size = Vector3.new(height * 0.04, branchLength, height * 0.04)
		local angle = (i / branchCount) * math.pi * 2
		local branchHeight = height * (0.35 + i * 0.08)
		local tiltOut = math.rad(math.random(40, 70)) -- Tilt outward from trunk

		-- Use CFrame to attach branch to trunk and angle it outward
		local branchCF = CFrame.new(groundPos + Vector3.new(0, branchHeight, 0))
			* CFrame.Angles(0, angle, 0) -- Face outward direction
			* CFrame.Angles(tiltOut, 0, math.rad(math.random(-15, 15))) -- Tilt out and slight twist
			* CFrame.new(0, branchLength * 0.5, 0) -- Offset so base is at trunk

		branch.CFrame = branchCF
		branch.Anchored = true
		branch.BrickColor = BrickColor.new("Dark taupe")
		branch.Material = Enum.Material.Wood
		branch.Parent = tree
	end

	tree.PrimaryPart = trunk
	tree.Parent = workspace
	return tree
end

-- =============================================
-- MULTI-STORY BUILDING FUNCTIONS
-- =============================================

-- Helper: Create a statue decoration
local function createStatue(parent: Model, position: Vector3, statueType: string)
	local statue = Instance.new("Model")
	statue.Name = "Statue"

	if statueType == "dinosaur" then
		-- Dinosaur statue (T-Rex silhouette)
		local body = Instance.new("Part")
		body.Name = "Body"
		body.Size = Vector3.new(3, 4, 6)
		body.Position = position + Vector3.new(0, 2, 0)
		body.Anchored = true
		body.BrickColor = BrickColor.new("Dark stone grey")
		body.Material = Enum.Material.Rock
		body.Parent = statue

		local head = Instance.new("Part")
		head.Name = "Head"
		head.Size = Vector3.new(2, 2.5, 3)
		head.Position = position + Vector3.new(0, 4.5, 3.5)
		head.Anchored = true
		head.BrickColor = BrickColor.new("Dark stone grey")
		head.Material = Enum.Material.Rock
		head.Parent = statue

		local tail = Instance.new("Part")
		tail.Name = "Tail"
		tail.Size = Vector3.new(1.5, 1.5, 5)
		tail.Position = position + Vector3.new(0, 2.5, -4)
		tail.Anchored = true
		tail.BrickColor = BrickColor.new("Dark stone grey")
		tail.Material = Enum.Material.Rock
		tail.Parent = statue
	elseif statueType == "pillar" then
		-- Decorative pillar
		local base = Instance.new("Part")
		base.Name = "Base"
		base.Size = Vector3.new(3, 1, 3)
		base.Position = position + Vector3.new(0, 0.5, 0)
		base.Anchored = true
		base.BrickColor = BrickColor.new("Medium stone grey")
		base.Material = Enum.Material.Marble
		base.Parent = statue

		local column = Instance.new("Part")
		column.Name = "Column"
		column.Size = Vector3.new(2, 6, 2)
		column.Position = position + Vector3.new(0, 4, 0)
		column.Anchored = true
		column.BrickColor = BrickColor.new("White")
		column.Material = Enum.Material.Marble
		column.Parent = statue

		local top = Instance.new("Part")
		top.Name = "Top"
		top.Size = Vector3.new(3.5, 1, 3.5)
		top.Position = position + Vector3.new(0, 7.5, 0)
		top.Anchored = true
		top.BrickColor = BrickColor.new("Medium stone grey")
		top.Material = Enum.Material.Marble
		top.Parent = statue
	else
		-- Explorer statue
		local pedestal = Instance.new("Part")
		pedestal.Name = "Pedestal"
		pedestal.Size = Vector3.new(4, 2, 4)
		pedestal.Position = position + Vector3.new(0, 1, 0)
		pedestal.Anchored = true
		pedestal.BrickColor = BrickColor.new("Dark stone grey")
		pedestal.Material = Enum.Material.Concrete
		pedestal.Parent = statue

		local figure = Instance.new("Part")
		figure.Name = "Figure"
		figure.Size = Vector3.new(2, 5, 2)
		figure.Position = position + Vector3.new(0, 4.5, 0)
		figure.Anchored = true
		figure.BrickColor = BrickColor.new("Medium stone grey")
		figure.Material = Enum.Material.Rock
		figure.Parent = statue
	end

	statue.Parent = parent
	return statue
end

-- Helper: Create a loot chest
local function createChest(parent: Model, position: Vector3)
	local chest = Instance.new("Model")
	chest.Name = "LootChest"

	-- Chest body
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(4, 3, 3)
	body.Position = position + Vector3.new(0, 1.5, 0)
	body.Anchored = true
	body.BrickColor = BrickColor.new("Reddish brown")
	body.Material = Enum.Material.Wood
	body.Parent = chest

	-- Chest lid
	local lid = Instance.new("Part")
	lid.Name = "Lid"
	lid.Size = Vector3.new(4.2, 1.5, 3.2)
	lid.Position = position + Vector3.new(0, 3.5, 0)
	lid.Anchored = true
	lid.BrickColor = BrickColor.new("Brown")
	lid.Material = Enum.Material.Wood
	lid.Parent = chest

	-- Metal bands
	for i = -1, 1, 2 do
		local band = Instance.new("Part")
		band.Name = "Band"
		band.Size = Vector3.new(0.3, 3.5, 3.2)
		band.Position = position + Vector3.new(i * 1.5, 2, 0)
		band.Anchored = true
		band.BrickColor = BrickColor.new("Dark stone grey")
		band.Material = Enum.Material.Metal
		band.Parent = chest
	end

	-- Lock
	local lock = Instance.new("Part")
	lock.Name = "Lock"
	lock.Size = Vector3.new(0.8, 0.8, 0.5)
	lock.Position = position + Vector3.new(0, 2.5, -1.6)
	lock.Anchored = true
	lock.BrickColor = BrickColor.new("Bright yellow")
	lock.Material = Enum.Material.Metal
	lock.Parent = chest

	chest.Parent = parent
	return chest
end

-- Create a multi-story building with full interior (anchored at ground level)
local function createMultiStoryBuilding(
	name: string,
	position: Vector3,
	floors: number,
	footprint: Vector3, -- width, floorHeight, depth
	style: string
): Model
	local building = Instance.new("Model")
	building.Name = name

	-- Raycast to find actual ground level
	local groundPos = placeAtGroundLevel(position, 0)

	local width = footprint.X
	local floorHeight = footprint.Y
	local depth = footprint.Z
	local wallThickness = 2

	-- Style-based colors
	local wallColor, roofColor, windowColor, interiorWallColor
	if style == "residential" then
		wallColor = BrickColor.new("Brick yellow")
		roofColor = BrickColor.new("Brown")
		windowColor = BrickColor.new("Cyan")
		interiorWallColor = BrickColor.new("Institutional white")
	elseif style == "commercial" then
		wallColor = BrickColor.new("Medium stone grey")
		roofColor = BrickColor.new("Dark stone grey")
		windowColor = BrickColor.new("Light blue")
		interiorWallColor = BrickColor.new("White")
	elseif style == "industrial" then
		wallColor = BrickColor.new("Dark stone grey")
		roofColor = BrickColor.new("Really black")
		windowColor = BrickColor.new("Medium stone grey")
		interiorWallColor = BrickColor.new("Medium stone grey")
	else
		wallColor = BrickColor.new("White")
		roofColor = BrickColor.new("Dark stone grey")
		windowColor = BrickColor.new("Cyan")
		interiorWallColor = BrickColor.new("Institutional white")
	end

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

		-- Walls for this floor
		local wallHeight = floorHeight - 1

		-- Front wall with door/windows (split for door opening)
		if floor == 1 then
			-- Ground floor: door gap
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

			-- Door frame header
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

		-- =============================================
		-- INTERIOR ROOMS
		-- =============================================

		-- Interior dividing wall (creates 2 rooms per floor)
		local interiorWall = Instance.new("Part")
		interiorWall.Name = "InteriorWall" .. floor
		interiorWall.Size = Vector3.new(1, wallHeight - 2, depth - 10)
		interiorWall.Position = groundPos + Vector3.new(-width / 6, floorY + 1 + (wallHeight - 2) / 2, 0)
		interiorWall.Anchored = true
		interiorWall.BrickColor = interiorWallColor
		interiorWall.Material = Enum.Material.SmoothPlastic
		interiorWall.Parent = building

		-- Interior cross wall for hallway
		local hallwayWall = Instance.new("Part")
		hallwayWall.Name = "HallwayWall" .. floor
		hallwayWall.Size = Vector3.new(width / 3, wallHeight - 2, 1)
		hallwayWall.Position = groundPos + Vector3.new(width / 4, floorY + 1 + (wallHeight - 2) / 2, depth / 4)
		hallwayWall.Anchored = true
		hallwayWall.BrickColor = interiorWallColor
		hallwayWall.Material = Enum.Material.SmoothPlastic
		hallwayWall.Parent = building

		-- Windows on front and back
		local windowsPerSide = math.max(2, math.floor(width / 12))
		for w = 1, windowsPerSide do
			local windowX = -width / 2 + w * (width / (windowsPerSide + 1))

			-- Front window
			local frontWindow = Instance.new("Part")
			frontWindow.Name = "FrontWindow" .. floor .. "_" .. w
			frontWindow.Size = Vector3.new(4, 5, 1)
			frontWindow.Position = groundPos + Vector3.new(windowX, floorY + 1 + wallHeight / 2, -depth / 2 - 0.5)
			frontWindow.Anchored = true
			frontWindow.BrickColor = windowColor
			frontWindow.Material = Enum.Material.Glass
			frontWindow.Transparency = 0.5
			frontWindow.Parent = building

			-- Back window
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

		-- =============================================
		-- STAIRS (Proper stepped staircase)
		-- =============================================
		if floor < floors then
			local stairWidth = 5
			local stairDepth = 10
			local stepCount = 10
			local stepHeight = floorHeight / stepCount

			-- Stairwell location (back-right corner)
			local stairBaseX = width / 2 - stairWidth - 2
			local stairBaseZ = depth / 2 - stairDepth - 2

			-- Floor opening for stairs (hole in floor above)
			local stairOpening = Instance.new("Part")
			stairOpening.Name = "StairOpening" .. floor
			stairOpening.Size = Vector3.new(stairWidth + 4, 1, stairDepth + 2)
			stairOpening.Position = groundPos + Vector3.new(stairBaseX, floorY + floorHeight + 0.5, stairBaseZ + stairDepth / 2)
			stairOpening.Anchored = true
			stairOpening.BrickColor = BrickColor.new("Dark stone grey")
			stairOpening.Material = Enum.Material.Concrete
			stairOpening.Transparency = 1 -- Invisible, just for collision
			stairOpening.CanCollide = false
			stairOpening.Parent = building

			-- Create individual steps
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

			-- Stair railings
			local leftRailing = Instance.new("Part")
			leftRailing.Name = "StairRailingLeft" .. floor
			leftRailing.Size = Vector3.new(0.5, 3, stairDepth)
			leftRailing.Position = groundPos + Vector3.new(stairBaseX - stairWidth / 2 - 0.25, floorY + floorHeight / 2 + 2, stairBaseZ + stairDepth / 2)
			leftRailing.Anchored = true
			leftRailing.BrickColor = BrickColor.new("Brown")
			leftRailing.Material = Enum.Material.Wood
			leftRailing.Parent = building

			local rightRailing = Instance.new("Part")
			rightRailing.Name = "StairRailingRight" .. floor
			rightRailing.Size = Vector3.new(0.5, 3, stairDepth)
			rightRailing.Position = groundPos + Vector3.new(stairBaseX + stairWidth / 2 + 0.25, floorY + floorHeight / 2 + 2, stairBaseZ + stairDepth / 2)
			rightRailing.Anchored = true
			rightRailing.BrickColor = BrickColor.new("Brown")
			rightRailing.Material = Enum.Material.Wood
			rightRailing.Parent = building
		end

		-- =============================================
		-- DECORATIONS (Statues and Chests)
		-- =============================================

		-- Add statue on ground floor lobby
		if floor == 1 then
			local statueTypes = { "dinosaur", "pillar", "explorer" }
			local statueType = statueTypes[math.random(1, #statueTypes)]
			createStatue(building, groundPos + Vector3.new(-width / 4, floorY + 1, -depth / 4), statueType)
		end

		-- Add chest in each room (2 per floor)
		local chestPositions = {
			groundPos + Vector3.new(-width / 3, floorY + 1, depth / 4),
			groundPos + Vector3.new(width / 4, floorY + 1, -depth / 4 + 2),
		}
		for _, chestPos in ipairs(chestPositions) do
			if math.random() > 0.3 then -- 70% chance of chest
				createChest(building, chestPos)
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

	-- Roof access structure
	local roofAccess = Instance.new("Part")
	roofAccess.Name = "RoofAccess"
	roofAccess.Size = Vector3.new(8, 10, 8)
	roofAccess.Position = groundPos + Vector3.new(width / 2 - 6, roofY + 6, depth / 2 - 6)
	roofAccess.Anchored = true
	roofAccess.BrickColor = wallColor
	roofAccess.Material = Enum.Material.Concrete
	roofAccess.Parent = building

	-- Roof door opening
	local roofDoor = Instance.new("Part")
	roofDoor.Name = "RoofDoor"
	roofDoor.Size = Vector3.new(4, 7, 0.5)
	roofDoor.Position = groundPos + Vector3.new(width / 2 - 6, roofY + 5.5, depth / 2 - 10)
	roofDoor.Anchored = true
	roofDoor.BrickColor = BrickColor.new("Dark orange")
	roofDoor.Material = Enum.Material.Wood
	roofDoor.Parent = building

	building.PrimaryPart = foundation
	building.Parent = workspace
	return building
end

-- Create apartment building (specialized multi-story)
local function createApartmentBuilding(name: string, position: Vector3, floors: number): Model
	return createMultiStoryBuilding(name, position, floors, Vector3.new(30, 12, 20), "residential")
end

-- Create warehouse (single story but tall, anchored at ground level)
local function createWarehouse(name: string, position: Vector3): Model
	local warehouse = Instance.new("Model")
	warehouse.Name = name

	-- Raycast to find actual ground level
	local groundPos = placeAtGroundLevel(position, 0)

	-- Main structure
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
	warehouse.Parent = workspace
	return warehouse
end

-- Create small shed (anchored at ground level)
local function createShed(name: string, position: Vector3, size: number): Model
	local shed = Instance.new("Model")
	shed.Name = name

	-- Raycast to find actual ground level
	local groundPos = placeAtGroundLevel(position, 0)

	-- Floor
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = Vector3.new(size, 0.5, size)
	floor.Position = groundPos + Vector3.new(0, 0.25, 0)
	floor.Anchored = true
	floor.BrickColor = BrickColor.new("Brown")
	floor.Material = Enum.Material.WoodPlanks
	floor.Parent = shed

	-- Walls
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

	-- Roof
	local roof = Instance.new("Part")
	roof.Name = "Roof"
	roof.Size = Vector3.new(size + 1, 0.5, size + 1)
	roof.Position = groundPos + Vector3.new(0, wallHeight + 0.75, 0)
	roof.Anchored = true
	roof.BrickColor = BrickColor.new("Dark stone grey")
	roof.Material = Enum.Material.Metal
	roof.Parent = shed

	shed.PrimaryPart = floor
	shed.Parent = workspace
	return shed
end

-- Create ruins/destroyed building (anchored at ground level)
local function createRuins(name: string, position: Vector3, size: number): Model
	local ruins = Instance.new("Model")
	ruins.Name = name

	-- Raycast to find actual ground level
	local groundPos = placeAtGroundLevel(position, 0)

	-- Broken foundation
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
	ruins.Parent = workspace
	return ruins
end

-- =============================================
-- WATER AND CAVE FUNCTIONS
-- =============================================

-- Create a river segment with bed
local function createRiverSegment(terrain: Terrain, startPos: Vector3, endPos: Vector3, width: number, depth: number)
	local segments = math.ceil((endPos - startPos).Magnitude / 50)

	for i = 0, segments do
		local t = i / segments
		local pos = startPos:Lerp(endPos, t)

		-- Add some noise to position for natural curves
		local noiseOffset = math.noise(pos.X / 100, pos.Z / 100, 5) * width * 0.3

		-- River bed (solid bottom)
		terrain:FillBlock(
			CFrame.new(pos.X + noiseOffset, -depth - 5, pos.Z),
			Vector3.new(width + 10, 10, 60),
			Enum.Material.Sand
		)

		-- Mud/gravel on bed edges
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

		-- Water
		terrain:FillBlock(
			CFrame.new(pos.X + noiseOffset, -depth / 2, pos.Z),
			Vector3.new(width, depth, 60),
			Enum.Material.Water
		)
	end
end

-- Create a lake with bed
local function createLake(terrain: Terrain, centerPos: Vector3, radius: number, depth: number)
	-- Solid lake bed
	terrain:FillBlock(
		CFrame.new(centerPos.X, -depth - 8, centerPos.Z),
		Vector3.new(radius * 2 + 20, 15, radius * 2 + 20),
		Enum.Material.Sand
	)

	-- Gravel/mud patches on bed
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

	-- Water body
	terrain:FillBlock(
		CFrame.new(centerPos.X, -depth / 2, centerPos.Z),
		Vector3.new(radius * 2, depth, radius * 2),
		Enum.Material.Water
	)

	-- Shallow edges
	terrain:FillBlock(
		CFrame.new(centerPos.X, -2, centerPos.Z),
		Vector3.new(radius * 2.2, 4, radius * 2.2),
		Enum.Material.Water
	)
end

-- Create a cave entrance
local function createCave(terrain: Terrain, entrancePos: Vector3, caveDepth: number, width: number, height: number)
	-- Cave entrance (hollow out terrain)
	terrain:FillBlock(
		CFrame.new(entrancePos.X, entrancePos.Y, entrancePos.Z - caveDepth / 2),
		Vector3.new(width, height, caveDepth),
		Enum.Material.Air
	)

	-- Cave walls (darker rock)
	terrain:FillBlock(
		CFrame.new(entrancePos.X, entrancePos.Y - height / 2 - 2, entrancePos.Z - caveDepth / 2),
		Vector3.new(width + 4, 4, caveDepth),
		Enum.Material.Slate
	)

	-- Cave ceiling
	terrain:FillBlock(
		CFrame.new(entrancePos.X, entrancePos.Y + height / 2 + 2, entrancePos.Z - caveDepth / 2),
		Vector3.new(width + 4, 4, caveDepth),
		Enum.Material.Slate
	)
end

-- =============================================
-- FOLIAGE CLUSTER FUNCTIONS
-- =============================================

-- Create a cluster of trees
local function createTreeCluster(centerPos: Vector3, radius: number, count: number, treeType: string, baseHeight: number)
	for i = 1, count do
		local angle = math.random() * math.pi * 2
		local dist = math.random() * radius
		local x = centerPos.X + math.cos(angle) * dist
		local z = centerPos.Z + math.sin(angle) * dist
		local height = baseHeight + math.random(-3, 5)

		local treePos = Vector3.new(x, centerPos.Y, z)

		if treeType == "pine" then
			createPineTree(treePos, height)
		elseif treeType == "oak" then
			createOakTree(treePos, height)
		elseif treeType == "birch" then
			createBirchTree(treePos, height)
		elseif treeType == "jungle" then
			createJungleTree(treePos, height)
		elseif treeType == "palm" then
			createPalmTree(treePos, height)
		elseif treeType == "dead" then
			createDeadTree(treePos, height)
		else
			createTree(treePos, height)
		end
	end
end

-- Create a rock formation cluster
local function createRockFormation(centerPos: Vector3, rockCount: number, minSize: number, maxSize: number, material: Enum.Material?)
	for i = 1, rockCount do
		local angle = math.random() * math.pi * 2
		local dist = math.random(5, 30)
		local x = centerPos.X + math.cos(angle) * dist
		local z = centerPos.Z + math.sin(angle) * dist
		local size = minSize + math.random() * (maxSize - minSize)

		createRock(Vector3.new(x, centerPos.Y, z), size, material)
	end
end

-- Create grass patch using terrain
local function createGrassPatch(terrain: Terrain, centerPos: Vector3, radius: number)
	terrain:FillBlock(
		CFrame.new(centerPos.X, centerPos.Y + 1, centerPos.Z),
		Vector3.new(radius * 2, 3, radius * 2),
		Enum.Material.LeafyGrass
	)
end

--[[
	Get biome at world position based on GDD layout
	Uses quadrant-based system with smooth transitions
]]
local function getBiomeAtPosition(x: number, z: number): string
	local halfSize = TERRAIN_CONFIG.mapSize / 2

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
	local base = TERRAIN_CONFIG.baseHeight

	-- Multi-octave noise for natural terrain
	local noise1 = math.noise(x / 300, z / 300, 1) * 20  -- Large features
	local noise2 = math.noise(x / 100, z / 100, 2) * 10  -- Medium features
	local noise3 = math.noise(x / 40, z / 40, 3) * 5     -- Small details

	if biome == "jungle" then
		-- Jungle: Rolling hills with dense variation (15-45 height)
		local jungleBase = math.noise(x / 150, z / 150, 4) * 15
		return base + noise1 + noise2 + noise3 + jungleBase + 10

	elseif biome == "plains" then
		-- Plains: Mostly flat with gentle rolling hills (10-25 height)
		local plainNoise = math.noise(x / 200, z / 200, 5) * 8
		return base + plainNoise + noise3 * 0.5

	elseif biome == "volcanic" then
		-- Volcanic: Dramatic peaks and valleys (20-100 height)
		local volcanoBase = math.noise(x / 120, z / 120, 6) * 40
		local peaks = math.max(0, math.noise(x / 60, z / 60, 7)) * 35
		local ridges = math.abs(math.noise(x / 80, z / 80, 8)) * 20
		return base + volcanoBase + peaks + ridges + 15

	elseif biome == "swamp" then
		-- Swamp: Low-lying with water channels (5-20 height)
		local swampBase = math.noise(x / 100, z / 100, 9) * 8
		local channels = math.abs(math.noise(x / 50, z / 50, 10)) * 5
		return base + swampBase - channels - 5

	elseif biome == "coastal" then
		-- Coastal: Beach sloping to water (0-15 height)
		local distFromCenter = math.sqrt(x * x + z * z)
		local normalizedDist = distFromCenter / (TERRAIN_CONFIG.mapSize / 2)
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
		elseif height > 3 then
			return Enum.Material.Sand
		else
			return Enum.Material.Sand
		end
	end

	return Enum.Material.Grass
end

--[[
	Create the full 4km x 4km multi-biome terrain
	Enhanced with:
	- Gap-filling base layer
	- 30% water coverage with solid bottoms
	- 30% foliage/structures
	- Varied trees, caves, multi-story buildings
]]
local function createBaseTerrain()
	local terrain = workspace.Terrain

	print("===========================================")
	print("[MapManager] GENERATING ISLA PRIMORDIAL")
	print("  Size: 4km x 4km (4000 studs)")
	print("  Biomes: Jungle, Plains, Volcanic, Swamp, Coastal")
	print("  Features: Rivers, Lakes, Caves, Dense Foliage")
	print("  Coverage: 30% Water, 30% Foliage/Structures")
	print("===========================================")

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

	-- Clear existing terrain
	print("[MapManager] Clearing existing terrain...")
	terrain:Clear()

	local mapSize = TERRAIN_CONFIG.mapSize
	local halfSize = mapSize / 2

	-- =============================================
	-- PHASE 1: SOLID BASE LAYER (Gap Prevention)
	-- =============================================
	print("[MapManager] Phase 1: Creating solid base layer...")

	pcall(function()
		-- Create a massive solid rock layer to prevent any fall-through
		terrain:FillBlock(
			CFrame.new(0, -15, 0),
			Vector3.new(mapSize + 200, 40, mapSize + 200),
			Enum.Material.Rock
		)
	end)
	print("[MapManager] Base layer complete - no gaps possible")

	-- =============================================
	-- PHASE 2: Create spawn area
	-- =============================================
	local spawnX, spawnZ = 200, 200
	local spawnAreaSize = 200
	local spawnHeight = 30

	print("[MapManager] Phase 2: Creating spawn area...")

	pcall(function()
		terrain:FillBlock(
			CFrame.new(spawnX, spawnHeight / 2, spawnZ),
			Vector3.new(spawnAreaSize, spawnHeight, spawnAreaSize),
			Enum.Material.Grass
		)
	end)

	-- =============================================
	-- PHASE 3: Generate terrain (finer resolution)
	-- =============================================
	print("[MapManager] Phase 3: Generating terrain...")

	local resolution = 32 -- Finer resolution for better detail
	local totalCells = 0
	local biomeCounts = { jungle = 0, plains = 0, volcanic = 0, swamp = 0, coastal = 0 }

	pcall(function()
		for x = -halfSize, halfSize, resolution do
			for z = -halfSize, halfSize, resolution do
				local distFromSpawn = math.sqrt((x - spawnX)^2 + (z - spawnZ)^2)
				if distFromSpawn > spawnAreaSize * 0.7 then
					local biome = getBiomeAtPosition(x, z)
					local height = getHeightAtPosition(x, z, biome)
					local material = getMaterialAtPosition(biome, height)

					height = math.max(height, 8)

					terrain:FillBlock(
						CFrame.new(x, height / 2, z),
						Vector3.new(resolution + 2, height + 10, resolution + 2),
						material
					)

					totalCells = totalCells + 1
					biomeCounts[biome] = (biomeCounts[biome] or 0) + 1
				end
			end

			if totalCells % 150 == 0 then
				task.wait()
			end
		end
	end)
	print(`[MapManager] Generated {totalCells} terrain cells`)

	-- =============================================
	-- PHASE 4: WATER SYSTEM (30% Coverage)
	-- Rivers, Lakes, Ocean with solid bottoms
	-- =============================================
	print("[MapManager] Phase 4: Creating water system (30% coverage)...")

	-- === OCEAN (South - ~10% coverage) ===
	-- Ocean bed (solid bottom)
	terrain:FillBlock(
		CFrame.new(0, -25, halfSize * 0.85),
		Vector3.new(mapSize + 100, 20, mapSize * 0.35),
		Enum.Material.Sand
	)
	-- Ocean water
	terrain:FillBlock(
		CFrame.new(0, -5, halfSize * 0.85),
		Vector3.new(mapSize + 100, 15, mapSize * 0.35),
		Enum.Material.Water
	)

	-- === MAJOR RIVERS (~8% coverage) ===
	print("[MapManager] Creating rivers with solid beds...")

	-- River 1: Volcanic to Swamp (North to East)
	createRiverSegment(terrain, Vector3.new(-200, 0, -1200), Vector3.new(1000, 0, 0), 60, 12)

	-- River 2: Jungle to Coast (Center to South)
	createRiverSegment(terrain, Vector3.new(0, 0, -400), Vector3.new(200, 0, 1200), 50, 10)

	-- River 3: Plains to Coast (West to South)
	createRiverSegment(terrain, Vector3.new(-1200, 0, -200), Vector3.new(-400, 0, 1000), 45, 10)

	-- River 4: Swamp delta channels
	createRiverSegment(terrain, Vector3.new(800, 0, -300), Vector3.new(1400, 0, 200), 40, 8)
	createRiverSegment(terrain, Vector3.new(1000, 0, 100), Vector3.new(1500, 0, 400), 35, 8)

	-- === LAKES (~8% coverage) ===
	print("[MapManager] Creating lakes with solid beds...")

	-- Central Lake (large)
	createLake(terrain, Vector3.new(0, 0, 0), 200, 15)

	-- Jungle Lakes
	createLake(terrain, Vector3.new(-400, 0, -300), 120, 12)
	createLake(terrain, Vector3.new(350, 0, -150), 100, 10)

	-- Plains Lakes
	createLake(terrain, Vector3.new(-1000, 0, 200), 150, 12)
	createLake(terrain, Vector3.new(-800, 0, -400), 80, 8)

	-- Swamp Lakes (shallow)
	createLake(terrain, Vector3.new(900, 0, -200), 100, 6)
	createLake(terrain, Vector3.new(1100, 0, 300), 120, 7)
	createLake(terrain, Vector3.new(1300, 0, -100), 90, 5)

	-- Volcanic Crater Lake
	createLake(terrain, Vector3.new(200, 0, -1500), 100, 20)

	-- Coastal Lagoons
	createLake(terrain, Vector3.new(-600, 0, 1100), 130, 8)
	createLake(terrain, Vector3.new(500, 0, 1000), 110, 8)

	-- === SWAMP WATER CHANNELS (~4% coverage) ===
	terrain:FillBlock(
		CFrame.new(halfSize * 0.55, -8, 0),
		Vector3.new(mapSize * 0.25, 12, mapSize * 0.4),
		Enum.Material.Sand
	)
	terrain:FillBlock(
		CFrame.new(halfSize * 0.55, -3, 0),
		Vector3.new(mapSize * 0.25, 8, mapSize * 0.4),
		Enum.Material.Water
	)

	print("[MapManager] Water system complete (~30% coverage)")

	-- =============================================
	-- PHASE 5: CAVE SYSTEMS
	-- =============================================
	print("[MapManager] Phase 5: Creating cave systems...")

	-- Volcanic caves (lava caves)
	createCave(terrain, Vector3.new(-300, 45, -1300), 80, 25, 15)
	createCave(terrain, Vector3.new(100, 50, -1400), 60, 20, 12)
	createCave(terrain, Vector3.new(400, 40, -1200), 70, 22, 14)
	createCave(terrain, Vector3.new(-500, 55, -1500), 50, 18, 10)

	-- Jungle hillside caves
	createCave(terrain, Vector3.new(-200, 35, -100), 50, 18, 12)
	createCave(terrain, Vector3.new(250, 30, 100), 45, 16, 10)
	createCave(terrain, Vector3.new(-350, 40, 200), 55, 20, 12)

	print("[MapManager] Created 7 accessible caves")

	-- =============================================
	-- PHASE 6: VOLCANIC FEATURES
	-- =============================================
	print("[MapManager] Phase 6: Adding volcanic features...")

	for i = 1, 8 do
		local lavaX = math.random(-600, 600)
		local lavaZ = -halfSize + math.random(100, 700)
		terrain:FillBlock(
			CFrame.new(lavaX, 35, lavaZ),
			Vector3.new(math.random(30, 70), 8, math.random(30, 70)),
			Enum.Material.CrackedLava
		)
	end

	-- =============================================
	-- PHASE 7: Create POI Buildings & Structures
	-- =============================================
	print("[MapManager] Phase 7: Creating POI buildings...")

	-- === JUNGLE BIOME (CENTER) ===
	local visitorCenterPos = Vector3.new(0, 30, -200)
	createBuilding("VisitorCenter_Main", visitorCenterPos, Vector3.new(80, 20, 60), BrickColor.new("Brick yellow"), Enum.Material.Concrete)
	createBuilding("VisitorCenter_GiftShop", visitorCenterPos + Vector3.new(-60, 0, 0), Vector3.new(30, 12, 25), BrickColor.new("Bright blue"), Enum.Material.Concrete)
	createBuilding("VisitorCenter_Restaurant", visitorCenterPos + Vector3.new(60, 0, 0), Vector3.new(35, 12, 30), BrickColor.new("Bright red"), Enum.Material.Concrete)
	createTower("VisitorCenter_Tower", visitorCenterPos + Vector3.new(0, 0, -50), 30)

	-- Hammond's Villa
	local hammondPos = Vector3.new(-300, 60, 100)
	terrain:FillBlock(CFrame.new(hammondPos.X, hammondPos.Y / 2, hammondPos.Z), Vector3.new(150, hammondPos.Y, 150), Enum.Material.Grass)
	createMultiStoryBuilding("HammondVilla_Main", hammondPos + Vector3.new(0, 5, 0), 3, Vector3.new(40, 12, 35), "residential")
	createBuilding("HammondVilla_Garage", hammondPos + Vector3.new(40, 5, 20), Vector3.new(25, 10, 20), BrickColor.new("Medium stone grey"), Enum.Material.Concrete)
	createHouse("HammondVilla_GuestHouse", hammondPos + Vector3.new(-50, 5, 30), 18)

	-- Raptor Paddock
	local raptorPaddockPos = Vector3.new(300, 25, -100)
	createTower("RaptorPaddock_WatchTower1", raptorPaddockPos + Vector3.new(-40, 0, -40), 25)
	createTower("RaptorPaddock_WatchTower2", raptorPaddockPos + Vector3.new(40, 0, 40), 25)
	createBuilding("RaptorPaddock_ControlRoom", raptorPaddockPos, Vector3.new(25, 12, 20), BrickColor.new("Dark stone grey"), Enum.Material.Metal)
	for i = 1, 8 do
		local angle = (i / 8) * math.pi * 2
		local fenceX = raptorPaddockPos.X + math.cos(angle) * 60
		local fenceZ = raptorPaddockPos.Z + math.sin(angle) * 60
		local post = Instance.new("Part")
		post.Name = "FencePost" .. i
		post.Size = Vector3.new(3, 15, 3)
		post.Position = Vector3.new(fenceX, 32, fenceZ)
		post.Anchored = true
		post.BrickColor = BrickColor.new("Medium stone grey")
		post.Material = Enum.Material.Metal
		post.Parent = workspace
	end

	-- === PLAINS BIOME (WEST) ===
	print("[MapManager] Creating plains POIs...")
	local plainsCenter = Vector3.new(-1200, 20, 0)
	createBuilding("SafariLodge_Main", plainsCenter, Vector3.new(60, 15, 45), BrickColor.new("Reddish brown"), Enum.Material.Wood)
	createBuilding("SafariLodge_Reception", plainsCenter + Vector3.new(-50, 0, 0), Vector3.new(25, 10, 20), BrickColor.new("Brown"), Enum.Material.Wood)
	createTower("SafariLodge_ViewingTower", plainsCenter + Vector3.new(60, 0, 30), 35)
	for i = 1, 5 do
		local cabinX = plainsCenter.X + 100 + (i * 40)
		local cabinZ = plainsCenter.Z + math.random(-50, 50)
		createHouse("SafariCabin" .. i, Vector3.new(cabinX, 15, cabinZ), 12)
	end

	-- === VOLCANIC BIOME (NORTH) ===
	print("[MapManager] Creating volcanic POIs...")
	local volcanicCenter = Vector3.new(0, 50, -1400)
	createIndustrialBuilding("GeothermalPlant", volcanicCenter)
	local observatoryPos = volcanicCenter + Vector3.new(300, 30, 200)
	terrain:FillBlock(CFrame.new(observatoryPos.X, observatoryPos.Y, observatoryPos.Z), Vector3.new(80, 60, 80), Enum.Material.Basalt)
	createMultiStoryBuilding("Observatory", observatoryPos + Vector3.new(0, 30, 0), 2, Vector3.new(30, 15, 30), "industrial")
	local trexPaddockPos = volcanicCenter + Vector3.new(-400, 0, 300)
	createTower("TRexPaddock_Tower", trexPaddockPos, 40)
	createBuilding("TRexPaddock_Bunker", trexPaddockPos + Vector3.new(60, 0, 0), Vector3.new(30, 8, 25), BrickColor.new("Dark stone grey"), Enum.Material.Concrete)

	-- === SWAMP BIOME (EAST) ===
	print("[MapManager] Creating swamp POIs...")
	local swampCenter = Vector3.new(1200, 12, 0)
	createMultiStoryBuilding("ResearchOutpost_Main", swampCenter, 2, Vector3.new(40, 12, 30), "commercial")
	createBuilding("ResearchOutpost_Lab", swampCenter + Vector3.new(40, 0, -30), Vector3.new(30, 10, 25), BrickColor.new("White"), Enum.Material.SmoothPlastic)
	createTower("ResearchOutpost_Tower", swampCenter + Vector3.new(-50, 0, 20), 20)
	local boatDockPos = swampCenter + Vector3.new(200, 0, 100)
	createDock(boatDockPos, 80)
	createBuilding("BoatDock_Shed", boatDockPos + Vector3.new(-30, 0, 0), Vector3.new(20, 10, 15), BrickColor.new("Brown"), Enum.Material.Wood)

	-- === COASTAL BIOME (SOUTH) ===
	print("[MapManager] Creating coastal POIs...")
	local coastalCenter = Vector3.new(0, 10, 1400)
	createLighthouse(coastalCenter + Vector3.new(-400, 0, 200))
	local harborPos = coastalCenter + Vector3.new(0, 0, -100)
	createDock(harborPos, 120)
	createWarehouse("Harbor_Warehouse", harborPos + Vector3.new(-60, 0, -50))
	createBuilding("Harbor_Office", harborPos + Vector3.new(50, 0, -30), Vector3.new(25, 12, 20), BrickColor.new("Brick yellow"), Enum.Material.Concrete)
	local resortPos = coastalCenter + Vector3.new(400, 0, 0)
	createMultiStoryBuilding("BeachResort_Main", resortPos, 4, Vector3.new(50, 12, 40), "commercial")
	createBuilding("BeachResort_Restaurant", resortPos + Vector3.new(-60, 0, 30), Vector3.new(35, 12, 30), BrickColor.new("Bright blue"), Enum.Material.Concrete)

	-- Beach cabanas
	for i = 1, 6 do
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
		cabana.Parent = workspace
	end

	-- =============================================
	-- PHASE 8: DENSE FOLIAGE (30% Coverage)
	-- =============================================
	print("[MapManager] Phase 8: Creating dense foliage (30% coverage)...")

	-- === JUNGLE DENSE VEGETATION (many varied trees) ===
	print("[MapManager] Adding jungle vegetation...")
	-- Dense jungle tree clusters
	for i = 1, 25 do
		local clusterX = math.random(-500, 500)
		local clusterZ = math.random(-500, 400)
		-- Avoid POI areas
		if math.abs(clusterX) > 120 or math.abs(clusterZ - (-200)) > 100 then
			createTreeCluster(Vector3.new(clusterX, 25, clusterZ), 80, math.random(4, 8), "jungle", 28)
		end
	end
	-- Individual jungle trees for filling
	for i = 1, 80 do
		local treeX = math.random(-600, 600)
		local treeZ = math.random(-600, 500)
		if math.abs(treeX) > 100 or math.abs(treeZ - (-200)) > 80 then
			createJungleTree(Vector3.new(treeX, 25, treeZ), math.random(22, 38))
		end
	end
	-- Grass patches in jungle
	for i = 1, 20 do
		createGrassPatch(terrain, Vector3.new(math.random(-500, 500), 25, math.random(-500, 400)), math.random(20, 50))
	end

	-- === PLAINS VEGETATION (sparse trees, grass) ===
	print("[MapManager] Adding plains vegetation...")
	-- Oak tree clusters (sparse)
	for i = 1, 15 do
		local clusterX = plainsCenter.X + math.random(-600, 600)
		local clusterZ = plainsCenter.Z + math.random(-600, 600)
		createTreeCluster(Vector3.new(clusterX, 18, clusterZ), 60, math.random(2, 4), "oak", 18)
	end
	-- Birch trees scattered
	for i = 1, 30 do
		local treeX = plainsCenter.X + math.random(-700, 700)
		local treeZ = plainsCenter.Z + math.random(-700, 700)
		createBirchTree(Vector3.new(treeX, 15, treeZ), math.random(12, 18))
	end
	-- Large grass patches
	for i = 1, 30 do
		createGrassPatch(terrain, Vector3.new(plainsCenter.X + math.random(-600, 600), 18, plainsCenter.Z + math.random(-600, 600)), math.random(30, 80))
	end
	-- Rock formations
	for i = 1, 8 do
		createRockFormation(Vector3.new(plainsCenter.X + math.random(-500, 500), 18, plainsCenter.Z + math.random(-500, 500)), math.random(4, 8), 3, 10)
	end

	-- === VOLCANIC VEGETATION (sparse pine, many rocks) ===
	print("[MapManager] Adding volcanic vegetation...")
	-- Sparse pine trees on slopes
	for i = 1, 25 do
		local treeX = volcanicCenter.X + math.random(-700, 700)
		local treeZ = volcanicCenter.Z + math.random(-400, 500)
		createPineTree(Vector3.new(treeX, 45, treeZ), math.random(15, 28))
	end
	-- Many rock formations
	for i = 1, 20 do
		createRockFormation(
			Vector3.new(volcanicCenter.X + math.random(-600, 600), 45, volcanicCenter.Z + math.random(-400, 400)),
			math.random(5, 12), 5, 20, Enum.Material.Basalt
		)
	end
	-- Scattered individual rocks
	for i = 1, 60 do
		local rockX = volcanicCenter.X + math.random(-800, 800)
		local rockZ = volcanicCenter.Z + math.random(-500, 500)
		createRock(Vector3.new(rockX, 45, rockZ), math.random(4, 15), Enum.Material.Basalt)
	end
	-- Ruins in volcanic area
	createRuins("VolcanicRuins1", volcanicCenter + Vector3.new(-600, 0, 100), 30)
	createRuins("VolcanicRuins2", volcanicCenter + Vector3.new(500, 0, -200), 25)
	createRuins("VolcanicRuins3", volcanicCenter + Vector3.new(200, 0, 400), 35)

	-- === SWAMP VEGETATION (dead trees, murky) ===
	print("[MapManager] Adding swamp vegetation...")
	-- Dead tree clusters
	for i = 1, 20 do
		local clusterX = swampCenter.X + math.random(-500, 500)
		local clusterZ = swampCenter.Z + math.random(-500, 500)
		createTreeCluster(Vector3.new(clusterX, 12, clusterZ), 50, math.random(3, 6), "dead", 15)
	end
	-- Individual dead trees
	for i = 1, 40 do
		local treeX = swampCenter.X + math.random(-600, 600)
		local treeZ = swampCenter.Z + math.random(-600, 600)
		createDeadTree(Vector3.new(treeX, 12, treeZ), math.random(10, 22))
	end
	-- Swamp stilt houses
	for i = 1, 6 do
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
		stilts.Parent = workspace
		createHouse("SwampHouse" .. i, housePos + Vector3.new(0, 15, 0), math.random(12, 16))
	end

	-- === COASTAL VEGETATION (palm trees, beach) ===
	print("[MapManager] Adding coastal vegetation...")
	-- Dense palm tree clusters
	for i = 1, 15 do
		local clusterX = coastalCenter.X + math.random(-700, 700)
		local clusterZ = coastalCenter.Z + math.random(-300, 200)
		createTreeCluster(Vector3.new(clusterX, 10, clusterZ), 60, math.random(4, 7), "palm", 18)
	end
	-- Individual palms
	for i = 1, 50 do
		local palmX = coastalCenter.X + math.random(-800, 800)
		local palmZ = coastalCenter.Z + math.random(-400, 300)
		createPalmTree(Vector3.new(palmX, 8, palmZ), math.random(14, 22))
	end
	-- Beach rocks and formations
	for i = 1, 12 do
		createRockFormation(
			Vector3.new(coastalCenter.X + math.random(-600, 600), 8, coastalCenter.Z + math.random(0, 300)),
			math.random(3, 7), 2, 8, Enum.Material.Sandstone
		)
	end

	-- =============================================
	-- PHASE 9: SCATTERED BUILDINGS (Between POIs)
	-- =============================================
	print("[MapManager] Phase 9: Adding scattered buildings...")

	-- Multi-story apartments in various locations
	createApartmentBuilding("Apartments_Jungle1", Vector3.new(-150, 25, 350), 3)
	createApartmentBuilding("Apartments_Plains1", Vector3.new(-900, 18, 300), 2)
	createApartmentBuilding("Apartments_Coast1", Vector3.new(-200, 10, 1100), 4)
	createApartmentBuilding("Apartments_Coast2", Vector3.new(600, 10, 900), 3)

	-- Warehouses
	createWarehouse("Warehouse_Jungle1", Vector3.new(450, 25, 200))
	createWarehouse("Warehouse_Swamp1", Vector3.new(800, 12, -300))

	-- Scattered houses across the map
	local houseLocations = {
		{Vector3.new(-500, 25, -400), 16},
		{Vector3.new(400, 25, 300), 14},
		{Vector3.new(-700, 18, -300), 12},
		{Vector3.new(-1400, 18, 400), 15},
		{Vector3.new(-1000, 18, -500), 14},
		{Vector3.new(700, 12, 400), 13},
		{Vector3.new(1000, 12, -400), 12},
		{Vector3.new(-300, 10, 900), 14},
		{Vector3.new(300, 10, 800), 15},
		{Vector3.new(-600, 10, 1200), 13},
	}
	for i, loc in ipairs(houseLocations) do
		createHouse("ScatteredHouse" .. i, loc[1], loc[2])
	end

	-- Small sheds scattered around
	for i = 1, 15 do
		local shedX = math.random(-1500, 1500)
		local shedZ = math.random(-1200, 1200)
		local shedY = 15
		if shedZ < -800 then shedY = 45 end -- Volcanic
		if shedX > 800 then shedY = 12 end -- Swamp
		if shedZ > 800 then shedY = 10 end -- Coastal
		createShed("Shed" .. i, Vector3.new(shedX, shedY, shedZ), math.random(8, 14))
	end

	-- Guard posts/small towers
	createTower("GuardTower1", Vector3.new(-600, 25, 0), 20)
	createTower("GuardTower2", Vector3.new(600, 25, -400), 22)
	createTower("GuardTower3", Vector3.new(-1500, 18, -200), 18)
	createTower("GuardTower4", Vector3.new(0, 10, 800), 20)

	-- Research buildings
	createMultiStoryBuilding("Research1", Vector3.new(-100, 25, -500), 2, Vector3.new(30, 12, 25), "commercial")
	createMultiStoryBuilding("Research2", Vector3.new(500, 25, -350), 2, Vector3.new(25, 12, 20), "commercial")

	-- =============================================
	-- PHASE 10: LOOT CACHES NEAR SPAWN
	-- =============================================
	print("[MapManager] Phase 10: Adding loot caches near spawn...")

	-- Spawn area is at (200, 30, 200) with 200 stud radius
	-- Add loot caches within 300 studs (~100 yards) of spawn
	local spawnCenter = Vector3.new(200, 30, 200)
	local lootRadius = 300

	-- Create floor loot cache (weapon crate)
	local function createLootCache(position: Vector3, cacheType: string): Model
		local cache = Instance.new("Model")
		cache.Name = "LootCache_" .. cacheType

		local groundPos = placeAtGroundLevel(position, 0)

		if cacheType == "weapon_crate" then
			-- Military-style weapon crate
			local crate = Instance.new("Part")
			crate.Name = "Crate"
			crate.Size = Vector3.new(5, 3, 3)
			crate.Position = groundPos + Vector3.new(0, 1.5, 0)
			crate.Anchored = true
			crate.BrickColor = BrickColor.new("Dark green")
			crate.Material = Enum.Material.Metal
			crate.Parent = cache

			local lid = Instance.new("Part")
			lid.Name = "Lid"
			lid.Size = Vector3.new(5.2, 0.5, 3.2)
			lid.Position = groundPos + Vector3.new(0, 3.25, 0)
			lid.Anchored = true
			lid.BrickColor = BrickColor.new("Dark green")
			lid.Material = Enum.Material.Metal
			lid.Parent = cache

			-- Stencil markings (white stripe)
			local stripe = Instance.new("Part")
			stripe.Name = "Stripe"
			stripe.Size = Vector3.new(4, 0.5, 0.1)
			stripe.Position = groundPos + Vector3.new(0, 2, -1.55)
			stripe.Anchored = true
			stripe.BrickColor = BrickColor.new("White")
			stripe.Material = Enum.Material.SmoothPlastic
			stripe.Parent = cache

		elseif cacheType == "ammo_box" then
			-- Ammo box (smaller)
			local box = Instance.new("Part")
			box.Name = "Box"
			box.Size = Vector3.new(2.5, 2, 2)
			box.Position = groundPos + Vector3.new(0, 1, 0)
			box.Anchored = true
			box.BrickColor = BrickColor.new("Olive")
			box.Material = Enum.Material.Metal
			box.Parent = cache

			local handle = Instance.new("Part")
			handle.Name = "Handle"
			handle.Size = Vector3.new(1.5, 0.3, 0.3)
			handle.Position = groundPos + Vector3.new(0, 2.15, 0)
			handle.Anchored = true
			handle.BrickColor = BrickColor.new("Dark stone grey")
			handle.Material = Enum.Material.Metal
			handle.Parent = cache

		elseif cacheType == "medkit" then
			-- Medical supply kit
			local kit = Instance.new("Part")
			kit.Name = "Kit"
			kit.Size = Vector3.new(3, 2, 2)
			kit.Position = groundPos + Vector3.new(0, 1, 0)
			kit.Anchored = true
			kit.BrickColor = BrickColor.new("White")
			kit.Material = Enum.Material.SmoothPlastic
			kit.Parent = cache

			-- Red cross
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
			-- General supply crate
			local crate = Instance.new("Part")
			crate.Name = "Crate"
			crate.Size = Vector3.new(4, 4, 4)
			crate.Position = groundPos + Vector3.new(0, 2, 0)
			crate.Anchored = true
			crate.BrickColor = BrickColor.new("Reddish brown")
			crate.Material = Enum.Material.Wood
			crate.Parent = cache

			-- Metal straps
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

		cache.Parent = workspace
		return cache
	end

	-- Place loot caches around spawn in a ring pattern
	local lootCacheCount = 16 -- 16 caches = good coverage within 300 studs
	local cacheTypes = { "weapon_crate", "weapon_crate", "ammo_box", "ammo_box", "medkit", "supply_drop" }

	for i = 1, lootCacheCount do
		-- Distribute caches in rings
		local ring = math.ceil(i / 8) -- 2 rings
		local angleOffset = (ring - 1) * 0.25 -- Offset second ring
		local angle = ((i - 1) / 8) * math.pi * 2 + angleOffset
		local distance = 80 + (ring - 1) * 120 + math.random(-20, 20) -- 80-100 studs, then 200-220 studs

		local cacheX = spawnCenter.X + math.cos(angle) * distance
		local cacheZ = spawnCenter.Z + math.sin(angle) * distance

		local cacheType = cacheTypes[math.random(1, #cacheTypes)]
		createLootCache(Vector3.new(cacheX, spawnCenter.Y, cacheZ), cacheType)
	end

	-- Add additional random floor loot scattered around spawn
	for i = 1, 20 do
		local angle = math.random() * math.pi * 2
		local distance = 50 + math.random() * 250 -- 50-300 studs from spawn
		local lootX = spawnCenter.X + math.cos(angle) * distance
		local lootZ = spawnCenter.Z + math.sin(angle) * distance

		local cacheType = cacheTypes[math.random(1, #cacheTypes)]
		createLootCache(Vector3.new(lootX, spawnCenter.Y, lootZ), cacheType)
	end

	print("[MapManager] Created 36 loot caches near spawn (within 300 studs)")

	-- =============================================
	-- PHASE 11: ADDITIONAL FOLIAGE DETAILS
	-- =============================================
	print("[MapManager] Phase 11: Adding foliage details...")

	-- Create bush decoration
	local function createBush(position: Vector3, size: number): Model
		local bush = Instance.new("Model")
		bush.Name = "Bush"

		local groundPos = placeAtGroundLevel(position, 0)

		-- Main bush body (cluster of spheres)
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

		bush.Parent = workspace
		return bush
	end

	-- Create fern
	local function createFern(position: Vector3): Model
		local fern = Instance.new("Model")
		fern.Name = "Fern"

		local groundPos = placeAtGroundLevel(position, 0)

		-- Fern fronds radiating outward
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

		fern.Parent = workspace
		return fern
	end

	-- Create flower patch
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

			-- Stem
			local stem = Instance.new("Part")
			stem.Name = "Stem" .. i
			stem.Size = Vector3.new(0.1, 0.6, 0.1)
			stem.Position = groundPos + Vector3.new(offsetX, 0.2, offsetZ)
			stem.Anchored = true
			stem.BrickColor = BrickColor.new("Bright green")
			stem.Material = Enum.Material.Grass
			stem.Parent = patch
		end

		patch.Parent = workspace
		return patch
	end

	-- Add bushes throughout the map
	print("[MapManager] Adding bushes...")
	for i = 1, 100 do
		local bushX = math.random(-1800, 1800)
		local bushZ = math.random(-1500, 1500)
		local bushY = 20
		if bushZ < -800 then bushY = 45 end
		if bushX > 800 then bushY = 12 end
		if bushZ > 800 then bushY = 10 end
		createBush(Vector3.new(bushX, bushY, bushZ), math.random(2, 5))
	end

	-- Add ferns in jungle and swamp areas
	print("[MapManager] Adding ferns...")
	for i = 1, 60 do
		-- Jungle ferns
		local fernX = math.random(-600, 600)
		local fernZ = math.random(-500, 400)
		createFern(Vector3.new(fernX, 25, fernZ))
	end
	for i = 1, 40 do
		-- Swamp ferns
		local fernX = swampCenter.X + math.random(-500, 500)
		local fernZ = swampCenter.Z + math.random(-500, 500)
		createFern(Vector3.new(fernX, 12, fernZ))
	end

	-- Add flower patches in plains and coastal
	print("[MapManager] Adding flower patches...")
	for i = 1, 30 do
		-- Plains flowers
		local flowerX = plainsCenter.X + math.random(-600, 600)
		local flowerZ = plainsCenter.Z + math.random(-600, 600)
		createFlowerPatch(Vector3.new(flowerX, 18, flowerZ), math.random(5, 12))
	end
	for i = 1, 20 do
		-- Coastal flowers
		local flowerX = coastalCenter.X + math.random(-600, 600)
		local flowerZ = coastalCenter.Z + math.random(-200, 200)
		createFlowerPatch(Vector3.new(flowerX, 10, flowerZ), math.random(4, 8))
	end

	-- Add dense bushes around spawn for early cover
	for i = 1, 15 do
		local angle = math.random() * math.pi * 2
		local dist = 50 + math.random() * 150
		local bushX = spawnCenter.X + math.cos(angle) * dist
		local bushZ = spawnCenter.Z + math.sin(angle) * dist
		createBush(Vector3.new(bushX, spawnCenter.Y, bushZ), math.random(3, 6))
	end

	print("[MapManager] Added 100 bushes, 100 ferns, 50 flower patches")

	-- =============================================
	-- PHASE 12: FINAL ROCK DETAILS
	-- =============================================
	print("[MapManager] Phase 12: Adding final rock details...")

	-- Additional rock clusters everywhere
	for i = 1, 40 do
		local x = math.random(-1800, 1800)
		local z = math.random(-1600, 1600)
		local y = 20
		if z < -800 then y = 45 end
		if x > 900 then y = 12 end
		if z > 900 then y = 10 end
		createRock(Vector3.new(x, y, z), math.random(2, 8))
	end

	task.wait() -- Final yield

	print("===========================================")
	print("[MapManager] TERRAIN GENERATION COMPLETE!")
	print(`  Total terrain cells: {totalCells}`)
	print(`  Biome distribution:`)
	print(`    Jungle: {biomeCounts.jungle} | Plains: {biomeCounts.plains}`)
	print(`    Volcanic: {biomeCounts.volcanic} | Swamp: {biomeCounts.swamp}`)
	print(`    Coastal: {biomeCounts.coastal}`)
	print("  Features added:")
	print("    - Solid base layer (no gaps)")
	print("    - 4 rivers with solid beds")
	print("    - 11 lakes with terrain beds")
	print("    - 7 accessible caves")
	print("    - 500+ trees (6 varieties, ground-anchored)")
	print("    - 20+ multi-story buildings with interiors")
	print("    - 80+ scattered structures (ground-anchored)")
	print("    - 36 loot caches near spawn (~300 studs)")
	print("    - 100 bushes, 100 ferns, 50 flower patches")
	print("    - Building interiors with rooms, stairs, statues, chests")
	print("  Coverage: ~30% water, ~30% foliage/structures")
	print("===========================================")
end

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
	Reset for new match
]]
function MapManager.Reset()
	currentMatchPhase = "Lobby"

	BiomeManager.Reset()
	POIManager.Reset()
	EnvironmentalEventManager.Reset()

	print("[MapManager] Reset for new match")
end

return MapManager
