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
	print("===========================================")

	-- Clean up existing spawn points
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

	print("[MapManager] Phase 1: Creating spawn area...")
	terrain:FillBlock(
		CFrame.new(spawnX, spawnHeight / 2, spawnZ),
		Vector3.new(spawnAreaSize, spawnHeight, spawnAreaSize),
		Enum.Material.Grass
	)

	-- Spawn platform
	local spawnPlatform = Instance.new("Part")
	spawnPlatform.Name = "LobbyPlatform"
	spawnPlatform.Size = Vector3.new(60, 3, 60)
	spawnPlatform.Position = Vector3.new(spawnX, spawnHeight + 2, spawnZ)
	spawnPlatform.Anchored = true
	spawnPlatform.BrickColor = BrickColor.new("Bright green")
	spawnPlatform.Material = Enum.Material.Grass
	spawnPlatform.Parent = workspace

	-- Spawn location
	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "LobbySpawn"
	spawnLocation.Size = Vector3.new(40, 1, 40)
	spawnLocation.Position = Vector3.new(spawnX, spawnHeight + 5, spawnZ)
	spawnLocation.Anchored = true
	spawnLocation.Transparency = 0.8
	spawnLocation.CanCollide = false
	spawnLocation.Neutral = true
	spawnLocation.Duration = 0
	spawnLocation.Parent = workspace

	print(`[MapManager] Spawn created at ({spawnX}, {spawnHeight + 5}, {spawnZ})`)

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

	print("===========================================")
	print("[MapManager] TERRAIN GENERATION COMPLETE!")
	print(`  Total cells: {totalCells}`)
	print(`  Jungle: {biomeCounts.jungle} | Plains: {biomeCounts.plains}`)
	print(`  Volcanic: {biomeCounts.volcanic} | Swamp: {biomeCounts.swamp}`)
	print(`  Coastal: {biomeCounts.coastal}`)
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
