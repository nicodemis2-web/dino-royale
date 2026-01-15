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
]]
local TERRAIN_CONFIG = {
	mapSize = 4000, -- Total map size (4000x4000 studs = 4km x 4km per GDD)
	resolution = 16, -- Terrain cell size (larger for performance on 4km map)
	baseHeight = 0,

	-- Biome regions (angles in radians, map divided into 3 main sectors)
	-- Per GDD Section 3.3:
	-- NORTH: Volcanic Region
	-- CENTER: Jungle & Research
	-- EAST: Swamplands
	-- WEST: Open Plains
	-- SOUTH: Coastal Area
	biomes = {
		jungle = { startAngle = 0, endAngle = math.pi * 2/3 },           -- NE sector
		desert = { startAngle = math.pi * 2/3, endAngle = math.pi * 4/3 }, -- S sector (plains)
		mountains = { startAngle = math.pi * 4/3, endAngle = math.pi * 2 }, -- NW sector (volcanic)
	}
}

--[[
	Get biome at world position
]]
local function getBiomeAtPosition(x: number, z: number): string
	local angle = math.atan2(z, x) + math.pi -- Convert to 0-2π range

	if angle >= TERRAIN_CONFIG.biomes.jungle.startAngle and angle < TERRAIN_CONFIG.biomes.jungle.endAngle then
		return "jungle"
	elseif angle >= TERRAIN_CONFIG.biomes.desert.startAngle and angle < TERRAIN_CONFIG.biomes.desert.endAngle then
		return "desert"
	else
		return "mountains"
	end
end

--[[
	Get terrain height at position based on biome
]]
local function getHeightAtPosition(x: number, z: number, biome: string): number
	local distance = math.sqrt(x * x + z * z)
	local normalizedDist = distance / TERRAIN_CONFIG.mapSize

	-- Base noise for variation
	local noise1 = math.noise(x / 200, z / 200) * 15
	local noise2 = math.noise(x / 50, z / 50) * 5

	if biome == "jungle" then
		-- Jungle: Rolling hills, medium height
		local jungleNoise = math.noise(x / 100, z / 100) * 25
		return TERRAIN_CONFIG.baseHeight + noise1 + noise2 + jungleNoise + 5

	elseif biome == "desert" then
		-- Desert: Flat with gentle dunes
		local duneNoise = math.noise(x / 150, z / 150) * 10
		local smallDunes = math.noise(x / 30, z / 30) * 3
		return TERRAIN_CONFIG.baseHeight + duneNoise + smallDunes

	else -- mountains
		-- Mountains: High peaks, dramatic elevation
		local mountainNoise = math.noise(x / 80, z / 80) * 60
		local peakNoise = math.max(0, math.noise(x / 40, z / 40)) * 40
		local ridges = math.abs(math.noise(x / 60, z / 60)) * 30
		return TERRAIN_CONFIG.baseHeight + mountainNoise + peakNoise + ridges + 20
	end
end

--[[
	Get terrain material based on biome and height
]]
local function getMaterialAtPosition(biome: string, height: number): Enum.Material
	if biome == "jungle" then
		if height > 30 then
			return Enum.Material.Rock
		elseif height > 10 then
			return Enum.Material.LeafyGrass
		else
			return Enum.Material.Grass
		end

	elseif biome == "desert" then
		if height > 15 then
			return Enum.Material.Sandstone
		else
			return Enum.Material.Sand
		end

	else -- mountains
		if height > 80 then
			return Enum.Material.Snow
		elseif height > 50 then
			return Enum.Material.Glacier
		elseif height > 30 then
			return Enum.Material.Slate
		else
			return Enum.Material.Rock
		end
	end
end

--[[
	Create the multi-biome terrain
]]
local function createBaseTerrain()
	local terrain = workspace.Terrain

	print("[MapManager] Generating 4km x 4km terrain...")

	-- Clean up any existing spawns first
	for _, name in ipairs({"TempSpawnPlatform", "SpawnPlatform", "TempSpawn", "MainSpawn", "LobbySpawn", "LobbyPlatform", "TempLobbyPlatform"}) do
		local obj = workspace:FindFirstChild(name)
		if obj then
			obj:Destroy()
			print(`[MapManager] Removed {name}`)
		end
	end

	-- Clear any existing terrain
	terrain:Clear()

	-- SPAWN AREA CONFIG - Jungle biome at (400, Y, 400)
	local spawnX, spawnZ = 400, 400
	local spawnAreaSize = 200 -- Large flat area around spawn
	local baseTerrainHeight = 20 -- Fixed base height for reliable spawning

	-- STEP 1: Create a guaranteed flat spawn area FIRST
	print("[MapManager] Creating spawn area...")
	terrain:FillBlock(
		CFrame.new(spawnX, baseTerrainHeight / 2, spawnZ),
		Vector3.new(spawnAreaSize, baseTerrainHeight, spawnAreaSize),
		Enum.Material.Grass
	)

	-- STEP 2: Create spawn platform on top of terrain
	local spawnPlatform = Instance.new("Part")
	spawnPlatform.Name = "LobbyPlatform"
	spawnPlatform.Size = Vector3.new(50, 3, 50)
	spawnPlatform.Position = Vector3.new(spawnX, baseTerrainHeight + 2, spawnZ)
	spawnPlatform.Anchored = true
	spawnPlatform.BrickColor = BrickColor.new("Bright green")
	spawnPlatform.Material = Enum.Material.Grass
	spawnPlatform.Parent = workspace
	print(`[MapManager] Spawn platform at ({spawnX}, {baseTerrainHeight + 2}, {spawnZ})`)

	-- STEP 3: Create spawn location
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "LobbySpawn"
	spawnLocation.Size = Vector3.new(30, 1, 30)
	spawnLocation.Position = Vector3.new(spawnX, baseTerrainHeight + 5, spawnZ)
	spawnLocation.Anchored = true
	spawnLocation.Transparency = 0.5 -- Semi-visible for debugging
	spawnLocation.CanCollide = false
	spawnLocation.Neutral = true
	spawnLocation.Duration = 0
	spawnLocation.Parent = workspace
	print(`[MapManager] Spawn location at ({spawnX}, {baseTerrainHeight + 5}, {spawnZ})`)

	-- STEP 4: Generate terrain chunks around spawn (simplified for performance)
	print("[MapManager] Generating surrounding terrain...")
	local mapSize = TERRAIN_CONFIG.mapSize
	local resolution = 64 -- Larger chunks for faster generation
	local halfSize = mapSize / 2
	local totalCells = 0

	for x = -halfSize, halfSize, resolution do
		for z = -halfSize, halfSize, resolution do
			-- Skip the spawn area (already created)
			local distFromSpawn = math.sqrt((x - spawnX)^2 + (z - spawnZ)^2)
			if distFromSpawn > spawnAreaSize then
				local biome = getBiomeAtPosition(x, z)
				local height = getHeightAtPosition(x, z, biome)
				local material = getMaterialAtPosition(biome, height)

				-- Fill terrain column from below ground to surface
				terrain:FillBlock(
					CFrame.new(x, height / 2, z),
					Vector3.new(resolution, height + 20, resolution),
					material
				)
				totalCells = totalCells + 1
			end
		end

		-- Yield to prevent timeout
		if totalCells % 500 == 0 then
			task.wait()
		end
	end

	-- STEP 5: Add water in low areas
	terrain:FillBlock(
		CFrame.new(0, -5, 0),
		Vector3.new(mapSize, 10, mapSize),
		Enum.Material.Water
	)

	print("[MapManager] Terrain generation complete!")
	print(`  Total cells: {totalCells}`)
	print(`  Spawn area: ({spawnX}, {baseTerrainHeight + 5}, {spawnZ})`)
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
