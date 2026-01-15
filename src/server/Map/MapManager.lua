--!strict
--[[
	MapManager.lua
	==============
	Central coordinator for all map-related systems
	Manages biomes, POIs, and environmental events
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BiomeManager = require(script.Parent.BiomeManager)
local POIManager = require(script.Parent.POIManager)
local EnvironmentalEventManager = require(script.Parent.EnvironmentalEventManager)

local BiomeData = require(ReplicatedStorage.Shared.BiomeData)
local POIData = require(ReplicatedStorage.Shared.POIData)
local Events = require(ReplicatedStorage.Shared.Events)

local MapManager = {}

-- State
local isInitialized = false
local currentMatchPhase = "Lobby"

-- Map info
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
			region = config.region,
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
-- BUILDING AND STRUCTURE CREATION HELPERS
-- =============================================

-- Create a simple building structure
local function createBuilding(name: string, position: Vector3, size: Vector3, color: BrickColor, material: Enum.Material?): Model
	local building = Instance.new("Model")
	building.Name = name

	local mat = material or Enum.Material.Concrete

	-- Floor
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = Vector3.new(size.X, 1, size.Z)
	floor.Position = position + Vector3.new(0, 0.5, 0)
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
	frontLeft.Position = position + Vector3.new(-(size.X / 4) - 2.5, wallHeight / 2 + 1, -size.Z / 2)
	frontLeft.Anchored = true
	frontLeft.BrickColor = color
	frontLeft.Material = mat
	frontLeft.Parent = building

	local frontRight = Instance.new("Part")
	frontRight.Name = "FrontWallRight"
	frontRight.Size = Vector3.new((size.X - 10) / 2, wallHeight, wallThickness)
	frontRight.Position = position + Vector3.new((size.X / 4) + 2.5, wallHeight / 2 + 1, -size.Z / 2)
	frontRight.Anchored = true
	frontRight.BrickColor = color
	frontRight.Material = mat
	frontRight.Parent = building

	-- Back wall
	local backWall = Instance.new("Part")
	backWall.Name = "BackWall"
	backWall.Size = Vector3.new(size.X, wallHeight, wallThickness)
	backWall.Position = position + Vector3.new(0, wallHeight / 2 + 1, size.Z / 2)
	backWall.Anchored = true
	backWall.BrickColor = color
	backWall.Material = mat
	backWall.Parent = building

	-- Side walls
	local leftWall = Instance.new("Part")
	leftWall.Name = "LeftWall"
	leftWall.Size = Vector3.new(wallThickness, wallHeight, size.Z)
	leftWall.Position = position + Vector3.new(-size.X / 2, wallHeight / 2 + 1, 0)
	leftWall.Anchored = true
	leftWall.BrickColor = color
	leftWall.Material = mat
	leftWall.Parent = building

	local rightWall = Instance.new("Part")
	rightWall.Name = "RightWall"
	rightWall.Size = Vector3.new(wallThickness, wallHeight, size.Z)
	rightWall.Position = position + Vector3.new(size.X / 2, wallHeight / 2 + 1, 0)
	rightWall.Anchored = true
	rightWall.BrickColor = color
	rightWall.Material = mat
	rightWall.Parent = building

	-- Roof
	local roof = Instance.new("Part")
	roof.Name = "Roof"
	roof.Size = Vector3.new(size.X + 4, 2, size.Z + 4)
	roof.Position = position + Vector3.new(0, wallHeight + 2, 0)
	roof.Anchored = true
	roof.BrickColor = BrickColor.new("Dark stone grey")
	roof.Material = Enum.Material.Slate
	roof.Parent = building

	building.PrimaryPart = floor
	building.Parent = workspace

	return building
end

-- Create a simple house/cabin
local function createHouse(name: string, position: Vector3, size: number): Model
	local house = Instance.new("Model")
	house.Name = name

	-- Base/Foundation
	local foundation = Instance.new("Part")
	foundation.Name = "Foundation"
	foundation.Size = Vector3.new(size, 2, size)
	foundation.Position = position + Vector3.new(0, 1, 0)
	foundation.Anchored = true
	foundation.BrickColor = BrickColor.new("Brick yellow")
	foundation.Material = Enum.Material.Concrete
	foundation.Parent = house

	-- Main structure
	local main = Instance.new("Part")
	main.Name = "MainStructure"
	main.Size = Vector3.new(size - 2, size * 0.6, size - 2)
	main.Position = position + Vector3.new(0, 2 + (size * 0.3), 0)
	main.Anchored = true
	main.BrickColor = BrickColor.new("Reddish brown")
	main.Material = Enum.Material.Wood
	main.Parent = house

	-- Roof (wedge-shaped using two parts)
	local roofLeft = Instance.new("Part")
	roofLeft.Name = "RoofLeft"
	roofLeft.Size = Vector3.new(size + 2, 1, size * 0.6)
	roofLeft.Position = position + Vector3.new(0, 2 + size * 0.6 + 0.5, -size * 0.15)
	roofLeft.Rotation = Vector3.new(25, 0, 0)
	roofLeft.Anchored = true
	roofLeft.BrickColor = BrickColor.new("Brown")
	roofLeft.Material = Enum.Material.Slate
	roofLeft.Parent = house

	local roofRight = Instance.new("Part")
	roofRight.Name = "RoofRight"
	roofRight.Size = Vector3.new(size + 2, 1, size * 0.6)
	roofRight.Position = position + Vector3.new(0, 2 + size * 0.6 + 0.5, size * 0.15)
	roofRight.Rotation = Vector3.new(-25, 0, 0)
	roofRight.Anchored = true
	roofRight.BrickColor = BrickColor.new("Brown")
	roofRight.Material = Enum.Material.Slate
	roofRight.Parent = house

	-- Door
	local door = Instance.new("Part")
	door.Name = "Door"
	door.Size = Vector3.new(4, 7, 1)
	door.Position = position + Vector3.new(0, 5.5, -size / 2 + 0.5)
	door.Anchored = true
	door.BrickColor = BrickColor.new("Dark orange")
	door.Material = Enum.Material.Wood
	door.Parent = house

	-- Windows
	for i = -1, 1, 2 do
		local window = Instance.new("Part")
		window.Name = "Window" .. (i == -1 and "Left" or "Right")
		window.Size = Vector3.new(1, 4, 4)
		window.Position = position + Vector3.new(i * (size / 2 - 0.5), 5, 0)
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

-- Create a tree
local function createTree(position: Vector3, height: number, treeType: string?): Model
	local tree = Instance.new("Model")
	tree.Name = "Tree"

	local trunkHeight = height * 0.4
	local canopySize = height * 0.8

	-- Trunk
	local trunk = Instance.new("Part")
	trunk.Name = "Trunk"
	trunk.Size = Vector3.new(height * 0.15, trunkHeight, height * 0.15)
	trunk.Position = position + Vector3.new(0, trunkHeight / 2, 0)
	trunk.Anchored = true
	trunk.BrickColor = BrickColor.new("Reddish brown")
	trunk.Material = Enum.Material.Wood
	trunk.Parent = tree

	-- Canopy
	local canopy = Instance.new("Part")
	canopy.Name = "Canopy"
	canopy.Shape = Enum.PartType.Ball
	canopy.Size = Vector3.new(canopySize, canopySize, canopySize)
	canopy.Position = position + Vector3.new(0, trunkHeight + canopySize * 0.3, 0)
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

-- Create a watchtower/observation tower
local function createTower(name: string, position: Vector3, height: number): Model
	local tower = Instance.new("Model")
	tower.Name = name

	-- Support legs (4 corners)
	local legSize = 2
	for x = -1, 1, 2 do
		for z = -1, 1, 2 do
			local leg = Instance.new("Part")
			leg.Name = "Leg"
			leg.Size = Vector3.new(legSize, height, legSize)
			leg.Position = position + Vector3.new(x * 5, height / 2, z * 5)
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
	platform.Position = position + Vector3.new(0, height, 0)
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
		rail.Position = position + offset
		rail.Anchored = true
		rail.BrickColor = BrickColor.new("Brown")
		rail.Material = Enum.Material.Wood
		rail.Parent = tower
	end

	-- Roof
	local roof = Instance.new("Part")
	roof.Name = "Roof"
	roof.Size = Vector3.new(16, 1, 16)
	roof.Position = position + Vector3.new(0, height + 8, 0)
	roof.Anchored = true
	roof.BrickColor = BrickColor.new("Bright green")
	roof.Material = Enum.Material.Grass
	roof.Parent = tower

	tower.PrimaryPart = platform
	tower.Parent = workspace

	return tower
end

-- Create industrial structure (for geothermal plant)
local function createIndustrialBuilding(name: string, position: Vector3): Model
	local building = Instance.new("Model")
	building.Name = name

	-- Main structure
	local main = Instance.new("Part")
	main.Name = "MainBuilding"
	main.Size = Vector3.new(60, 25, 40)
	main.Position = position + Vector3.new(0, 12.5, 0)
	main.Anchored = true
	main.BrickColor = BrickColor.new("Medium stone grey")
	main.Material = Enum.Material.Concrete
	main.Parent = building

	-- Smokestack
	local stack = Instance.new("Part")
	stack.Name = "Smokestack"
	stack.Size = Vector3.new(8, 50, 8)
	stack.Position = position + Vector3.new(20, 25, 10)
	stack.Anchored = true
	stack.BrickColor = BrickColor.new("Dark stone grey")
	stack.Material = Enum.Material.Metal
	stack.Parent = building

	-- Pipes
	for i = 1, 3 do
		local pipe = Instance.new("Part")
		pipe.Name = "Pipe" .. i
		pipe.Size = Vector3.new(3, 20, 3)
		pipe.Position = position + Vector3.new(-15 + (i * 10), 20, -25)
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
		vent.Position = position + Vector3.new(-20 + (i * 12), 1, 30)
		vent.Anchored = true
		vent.BrickColor = BrickColor.new("Dark stone grey")
		vent.Material = Enum.Material.DiamondPlate
		vent.Parent = building
	end

	building.PrimaryPart = main
	building.Parent = workspace

	return building
end

-- Create lighthouse
local function createLighthouse(position: Vector3): Model
	local lighthouse = Instance.new("Model")
	lighthouse.Name = "Lighthouse"

	-- Base
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(20, 5, 20)
	base.Position = position + Vector3.new(0, 2.5, 0)
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
		section.Position = position + Vector3.new(0, 5 + (i - 0.5) * sectionHeight, 0)
		section.Anchored = true
		section.BrickColor = i % 2 == 1 and BrickColor.new("White") or BrickColor.new("Bright red")
		section.Material = Enum.Material.Concrete
		section.Parent = lighthouse
	end

	-- Light room
	local lightRoom = Instance.new("Part")
	lightRoom.Name = "LightRoom"
	lightRoom.Size = Vector3.new(10, 8, 10)
	lightRoom.Position = position + Vector3.new(0, towerHeight + 9, 0)
	lightRoom.Anchored = true
	lightRoom.BrickColor = BrickColor.new("Black")
	lightRoom.Material = Enum.Material.Metal
	lightRoom.Parent = lighthouse

	-- Light
	local light = Instance.new("Part")
	light.Name = "Light"
	light.Shape = Enum.PartType.Ball
	light.Size = Vector3.new(6, 6, 6)
	light.Position = position + Vector3.new(0, towerHeight + 9, 0)
	light.Anchored = true
	light.BrickColor = BrickColor.new("Bright yellow")
	light.Material = Enum.Material.Neon
	light.Parent = lighthouse

	-- Roof
	local roof = Instance.new("Part")
	roof.Name = "Roof"
	roof.Size = Vector3.new(12, 3, 12)
	roof.Position = position + Vector3.new(0, towerHeight + 14, 0)
	roof.Anchored = true
	roof.BrickColor = BrickColor.new("Bright red")
	roof.Material = Enum.Material.Metal
	roof.Parent = lighthouse

	lighthouse.PrimaryPart = base
	lighthouse.Parent = workspace

	return lighthouse
end

-- Create dock/pier
local function createDock(position: Vector3, length: number): Model
	local dock = Instance.new("Model")
	dock.Name = "Dock"

	-- Main platform
	local platform = Instance.new("Part")
	platform.Name = "Platform"
	platform.Size = Vector3.new(15, 2, length)
	platform.Position = position + Vector3.new(0, 3, length / 2)
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
		pillar.Position = position + Vector3.new(0, -2, i * 20)
		pillar.Anchored = true
		pillar.BrickColor = BrickColor.new("Dark stone grey")
		pillar.Material = Enum.Material.Concrete
		pillar.Parent = dock
	end

	dock.PrimaryPart = platform
	dock.Parent = workspace

	return dock
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
]]
local function createBaseTerrain()
	local terrain = workspace.Terrain

	print("===========================================")
	print("[MapManager] GENERATING ISLA PRIMORDIAL")
	print("  Size: 4km x 4km (4000 studs)")
	print("  Biomes: Jungle, Plains, Volcanic, Swamp, Coastal")
	print("  POIs: Visitor Center, Hammond Villa, Safari Lodge, etc.")
	print("===========================================")

	-- Clean up existing objects
	local cleanupNames = {
		"TempSpawnPlatform", "SpawnPlatform", "TempSpawn", "MainSpawn",
		"LobbySpawn", "LobbyPlatform", "TempLobbyPlatform", "FallbackSpawnPlatform"
	}
	for _, name in ipairs(cleanupNames) do
		local obj = workspace:FindFirstChild(name)
		if obj then
			obj:Destroy()
		end
	end

	-- Clear existing terrain
	terrain:Clear()

	-- =============================================
	-- PHASE 1: Create spawn area in Jungle (CENTER)
	-- =============================================
	local spawnX, spawnZ = 200, 200 -- Jungle center area
	local spawnAreaSize = 150
	local spawnHeight = 25

	print("[MapManager] Phase 1: Creating spawn area terrain...")
	terrain:FillBlock(
		CFrame.new(spawnX, spawnHeight / 2, spawnZ),
		Vector3.new(spawnAreaSize, spawnHeight, spawnAreaSize),
		Enum.Material.Grass
	)

	-- No spawn platform - players spawn directly on terrain
	print(`[MapManager] Spawn area at ({spawnX}, {spawnHeight}, {spawnZ})`)

	-- =============================================
	-- PHASE 2: Generate full terrain in chunks
	-- =============================================
	print("[MapManager] Phase 2: Generating terrain chunks...")

	local mapSize = TERRAIN_CONFIG.mapSize
	local resolution = TERRAIN_CONFIG.resolution
	local halfSize = mapSize / 2
	local totalCells = 0
	local biomeCounts = { jungle = 0, plains = 0, volcanic = 0, swamp = 0, coastal = 0 }

	-- Generate terrain in a grid pattern
	for x = -halfSize, halfSize, resolution do
		for z = -halfSize, halfSize, resolution do
			-- Skip spawn area
			local distFromSpawn = math.sqrt((x - spawnX)^2 + (z - spawnZ)^2)
			if distFromSpawn > spawnAreaSize * 0.7 then
				local biome = getBiomeAtPosition(x, z)
				local height = getHeightAtPosition(x, z, biome)
				local material = getMaterialAtPosition(biome, height)

				-- Ensure minimum height above water
				height = math.max(height, 5)

				-- Fill terrain block
				terrain:FillBlock(
					CFrame.new(x, height / 2 - 5, z),
					Vector3.new(resolution, height + 15, resolution),
					material
				)

				totalCells = totalCells + 1
				biomeCounts[biome] = (biomeCounts[biome] or 0) + 1
			end
		end

		-- Yield periodically to prevent timeout
		if totalCells % 200 == 0 then
			task.wait()
		end
	end

	-- =============================================
	-- PHASE 3: Add water bodies
	-- =============================================
	print("[MapManager] Phase 3: Adding water...")

	-- Ocean around coastal areas
	terrain:FillBlock(
		CFrame.new(0, TERRAIN_CONFIG.waterLevel, halfSize * 0.8),
		Vector3.new(mapSize, 8, mapSize * 0.4),
		Enum.Material.Water
	)

	-- Swamp water channels
	terrain:FillBlock(
		CFrame.new(halfSize * 0.6, TERRAIN_CONFIG.waterLevel, 0),
		Vector3.new(mapSize * 0.3, 6, mapSize * 0.5),
		Enum.Material.Water
	)

	-- Central lake
	terrain:FillBlock(
		CFrame.new(0, TERRAIN_CONFIG.waterLevel - 2, 0),
		Vector3.new(300, 8, 300),
		Enum.Material.Water
	)

	-- =============================================
	-- PHASE 4: Add volcanic lava pools
	-- =============================================
	print("[MapManager] Phase 4: Adding volcanic features...")

	-- Lava pools in volcanic region (north)
	for i = 1, 5 do
		local lavaX = math.random(-500, 500)
		local lavaZ = -halfSize + math.random(200, 800)
		terrain:FillBlock(
			CFrame.new(lavaX, 30, lavaZ),
			Vector3.new(math.random(40, 80), 10, math.random(40, 80)),
			Enum.Material.CrackedLava
		)
	end

	-- =============================================
	-- PHASE 5: Create POI Buildings & Structures
	-- =============================================
	print("[MapManager] Phase 5: Creating POI buildings...")

	-- === JUNGLE BIOME (CENTER) ===
	-- Visitor Center (Hot Drop) - Main attraction
	local visitorCenterPos = Vector3.new(0, 30, -200)
	createBuilding("VisitorCenter_Main", visitorCenterPos, Vector3.new(80, 20, 60), BrickColor.new("Brick yellow"), Enum.Material.Concrete)
	createBuilding("VisitorCenter_GiftShop", visitorCenterPos + Vector3.new(-60, 0, 0), Vector3.new(30, 12, 25), BrickColor.new("Bright blue"), Enum.Material.Concrete)
	createBuilding("VisitorCenter_Restaurant", visitorCenterPos + Vector3.new(60, 0, 0), Vector3.new(35, 12, 30), BrickColor.new("Bright red"), Enum.Material.Concrete)
	createTower("VisitorCenter_Tower", visitorCenterPos + Vector3.new(0, 0, -50), 30)

	-- Hammond's Villa (hilltop mansion)
	local hammondPos = Vector3.new(-300, 60, 100)
	terrain:FillBlock(CFrame.new(hammondPos.X, hammondPos.Y / 2, hammondPos.Z), Vector3.new(150, hammondPos.Y, 150), Enum.Material.Grass) -- Hill
	createBuilding("HammondVilla_Main", hammondPos + Vector3.new(0, 5, 0), Vector3.new(50, 18, 40), BrickColor.new("Institutional white"), Enum.Material.Marble)
	createBuilding("HammondVilla_Garage", hammondPos + Vector3.new(40, 5, 20), Vector3.new(25, 10, 20), BrickColor.new("Medium stone grey"), Enum.Material.Concrete)
	createHouse("HammondVilla_GuestHouse", hammondPos + Vector3.new(-50, 5, 30), 18)

	-- Raptor Paddock
	local raptorPaddockPos = Vector3.new(300, 25, -100)
	createTower("RaptorPaddock_WatchTower1", raptorPaddockPos + Vector3.new(-40, 0, -40), 25)
	createTower("RaptorPaddock_WatchTower2", raptorPaddockPos + Vector3.new(40, 0, 40), 25)
	createBuilding("RaptorPaddock_ControlRoom", raptorPaddockPos, Vector3.new(25, 12, 20), BrickColor.new("Dark stone grey"), Enum.Material.Metal)
	-- Fence posts
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

	-- Jungle trees (dense vegetation)
	print("[MapManager] Adding jungle vegetation...")
	for i = 1, 50 do
		local treeX = math.random(-400, 400)
		local treeZ = math.random(-400, 400)
		-- Avoid POI areas
		if math.abs(treeX) > 100 or math.abs(treeZ - (-200)) > 80 then
			createTree(Vector3.new(treeX, 25, treeZ), math.random(15, 30))
		end
	end

	-- === PLAINS BIOME (WEST) ===
	print("[MapManager] Creating plains POIs...")
	local plainsCenter = Vector3.new(-1200, 20, 0)

	-- Safari Lodge
	createBuilding("SafariLodge_Main", plainsCenter, Vector3.new(60, 15, 45), BrickColor.new("Reddish brown"), Enum.Material.Wood)
	createBuilding("SafariLodge_Reception", plainsCenter + Vector3.new(-50, 0, 0), Vector3.new(25, 10, 20), BrickColor.new("Brown"), Enum.Material.Wood)
	createTower("SafariLodge_ViewingTower", plainsCenter + Vector3.new(60, 0, 30), 35)

	-- Safari cabins
	for i = 1, 5 do
		local cabinX = plainsCenter.X + 100 + (i * 40)
		local cabinZ = plainsCenter.Z + math.random(-50, 50)
		createHouse("SafariCabin" .. i, Vector3.new(cabinX, 15, cabinZ), 12)
	end

	-- Feeding stations
	for i = 1, 3 do
		local stationPos = plainsCenter + Vector3.new(math.random(-200, 200), 0, math.random(-200, 200))
		local station = Instance.new("Part")
		station.Name = "FeedingStation" .. i
		station.Size = Vector3.new(20, 8, 20)
		station.Position = stationPos + Vector3.new(0, 4, 0)
		station.Anchored = true
		station.BrickColor = BrickColor.new("Brown")
		station.Material = Enum.Material.WoodPlanks
		station.Parent = workspace

		-- Hay bales
		for j = 1, 3 do
			local bale = Instance.new("Part")
			bale.Name = "HayBale"
			bale.Size = Vector3.new(6, 4, 6)
			bale.Position = stationPos + Vector3.new(math.random(-15, 15), 10, math.random(-15, 15))
			bale.Anchored = true
			bale.BrickColor = BrickColor.new("Brick yellow")
			bale.Material = Enum.Material.Fabric
			bale.Parent = workspace
		end
	end

	-- Plains scattered trees (sparse)
	for i = 1, 20 do
		local treeX = plainsCenter.X + math.random(-500, 500)
		local treeZ = plainsCenter.Z + math.random(-500, 500)
		createTree(Vector3.new(treeX, 15, treeZ), math.random(8, 15))
	end

	-- === VOLCANIC BIOME (NORTH) ===
	print("[MapManager] Creating volcanic POIs...")
	local volcanicCenter = Vector3.new(0, 50, -1400)

	-- Geothermal Plant
	createIndustrialBuilding("GeothermalPlant", volcanicCenter)

	-- Observatory on high ground
	local observatoryPos = volcanicCenter + Vector3.new(300, 30, 200)
	terrain:FillBlock(CFrame.new(observatoryPos.X, observatoryPos.Y, observatoryPos.Z), Vector3.new(80, 60, 80), Enum.Material.Basalt)
	createBuilding("Observatory", observatoryPos + Vector3.new(0, 30, 0), Vector3.new(35, 20, 35), BrickColor.new("Dark stone grey"), Enum.Material.Metal)

	-- T-Rex Paddock
	local trexPaddockPos = volcanicCenter + Vector3.new(-400, 0, 300)
	createTower("TRexPaddock_Tower", trexPaddockPos, 40)
	createBuilding("TRexPaddock_Bunker", trexPaddockPos + Vector3.new(60, 0, 0), Vector3.new(30, 8, 25), BrickColor.new("Dark stone grey"), Enum.Material.Concrete)

	-- Volcanic rocks
	for i = 1, 30 do
		local rockX = volcanicCenter.X + math.random(-600, 600)
		local rockZ = volcanicCenter.Z + math.random(-400, 400)
		createRock(Vector3.new(rockX, 40, rockZ), math.random(5, 15), Enum.Material.Basalt)
	end

	-- === SWAMP BIOME (EAST) ===
	print("[MapManager] Creating swamp POIs...")
	local swampCenter = Vector3.new(1200, 12, 0)

	-- Research Outpost
	createBuilding("ResearchOutpost_Main", swampCenter, Vector3.new(45, 12, 35), BrickColor.new("Medium stone grey"), Enum.Material.Concrete)
	createBuilding("ResearchOutpost_Lab", swampCenter + Vector3.new(40, 0, -30), Vector3.new(30, 10, 25), BrickColor.new("White"), Enum.Material.SmoothPlastic)
	createTower("ResearchOutpost_Tower", swampCenter + Vector3.new(-50, 0, 20), 20)

	-- Boat Dock
	local boatDockPos = swampCenter + Vector3.new(200, 0, 100)
	createDock(boatDockPos, 80)
	createBuilding("BoatDock_Shed", boatDockPos + Vector3.new(-30, 0, 0), Vector3.new(20, 10, 15), BrickColor.new("Brown"), Enum.Material.Wood)

	-- Swamp houses on stilts
	for i = 1, 4 do
		local housePos = swampCenter + Vector3.new(math.random(-300, 300), 8, math.random(-300, 300))
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
		createHouse("SwampHouse" .. i, housePos + Vector3.new(0, 15, 0), 14)
	end

	-- Dead trees in swamp
	for i = 1, 15 do
		local treeX = swampCenter.X + math.random(-400, 400)
		local treeZ = swampCenter.Z + math.random(-400, 400)
		local deadTree = Instance.new("Part")
		deadTree.Name = "DeadTree"
		deadTree.Size = Vector3.new(2, math.random(10, 20), 2)
		deadTree.Position = Vector3.new(treeX, 15, treeZ)
		deadTree.Anchored = true
		deadTree.BrickColor = BrickColor.new("Dark taupe")
		deadTree.Material = Enum.Material.Wood
		deadTree.Parent = workspace
	end

	-- === COASTAL BIOME (SOUTH) ===
	print("[MapManager] Creating coastal POIs...")
	local coastalCenter = Vector3.new(0, 10, 1400)

	-- Lighthouse
	createLighthouse(coastalCenter + Vector3.new(-400, 0, 200))

	-- Harbor
	local harborPos = coastalCenter + Vector3.new(0, 0, -100)
	createDock(harborPos, 120)
	createBuilding("Harbor_Warehouse", harborPos + Vector3.new(-60, 0, -50), Vector3.new(50, 15, 35), BrickColor.new("Medium stone grey"), Enum.Material.Concrete)
	createBuilding("Harbor_Office", harborPos + Vector3.new(50, 0, -30), Vector3.new(25, 12, 20), BrickColor.new("Brick yellow"), Enum.Material.Concrete)

	-- Beach Resort
	local resortPos = coastalCenter + Vector3.new(400, 0, 0)
	createBuilding("BeachResort_Main", resortPos, Vector3.new(70, 18, 50), BrickColor.new("Institutional white"), Enum.Material.Concrete)
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

		-- Poles
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

	-- Palm trees on beach
	for i = 1, 25 do
		local palmX = coastalCenter.X + math.random(-600, 600)
		local palmZ = coastalCenter.Z + math.random(-200, 100)
		createTree(Vector3.new(palmX, 8, palmZ), math.random(12, 20), "palm")
	end

	-- Beach rocks
	for i = 1, 15 do
		local rockX = coastalCenter.X + math.random(-500, 500)
		local rockZ = coastalCenter.Z + math.random(50, 200)
		createRock(Vector3.new(rockX, 5, rockZ), math.random(3, 8), Enum.Material.Sandstone)
	end

	print("===========================================")
	print("[MapManager] TERRAIN GENERATION COMPLETE!")
	print(`  Total cells: {totalCells}`)
	print(`  Jungle: {biomeCounts.jungle} | Plains: {biomeCounts.plains}`)
	print(`  Volcanic: {biomeCounts.volcanic} | Swamp: {biomeCounts.swamp}`)
	print(`  Coastal: {biomeCounts.coastal}`)
	print("  POIs: Visitor Center, Hammond Villa, Safari Lodge,")
	print("        Geothermal Plant, Research Outpost, Lighthouse, Harbor")
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
