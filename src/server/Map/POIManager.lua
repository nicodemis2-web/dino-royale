--!strict
--[[
	POIManager.lua
	==============
	Server-side POI management
	Handles loot spawning, vehicle spawning, and POI state
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local _ServerStorage = game:GetService("ServerStorage")

local POIData = require(ReplicatedStorage.Shared.POIData)
local _BiomeData = require(ReplicatedStorage.Shared.BiomeData)
local Events = require(ReplicatedStorage.Shared.Events)

local POIManager = {}

-- State
local isInitialized = false
local poiStates: { [string]: POIState } = {}
local spawnedLoot: { [string]: { any } } = {}
local spawnedVehicles: { [string]: { any } } = {}

export type POIState = {
	name: string,
	isLooted: boolean,
	lootedChests: number,
	totalChests: number,
	activeDinos: { any },
	activeVehicles: { any },
	specialState: { [string]: any }?,
}

--[[
	Initialize a POI's state
]]
local function initializePOIState(poiName: string, config: POIData.POIConfig): POIState
	local chestCount = math.random(config.chestCount.min, config.chestCount.max)

	return {
		name = poiName,
		isLooted = false,
		lootedChests = 0,
		totalChests = chestCount,
		activeDinos = {},
		activeVehicles = {},
		specialState = {},
	}
end

--[[
	Spawn loot at a POI
]]
function POIManager.SpawnLootAtPOI(poiName: string)
	local config = POIData.POIs[poiName]
	if not config then
		warn("[POIManager] Unknown POI: " .. poiName)
		return
	end

	local state = poiStates[poiName]
	if not state then return end

	spawnedLoot[poiName] = {}

	-- Spawn chests
	for _ = 1, state.totalChests do
		local chestData = {
			id = poiName .. "_chest_" .. i,
			poiName = poiName,
			position = {
				x = config.position.x + math.random(-config.radius, config.radius) * 0.8,
				y = config.position.y + math.random(0, 10),
				z = config.position.z + math.random(-config.radius, config.radius) * 0.8,
			},
			lootTier = config.lootTier,
			isOpened = false,
		}
		table.insert(spawnedLoot[poiName], chestData)
	end

	-- Spawn floor loot
	for _ = 1, config.floorLootSpawns do
		local floorLootData = {
			id = poiName .. "_floor_" .. i,
			poiName = poiName,
			position = {
				x = config.position.x + math.random(-config.radius, config.radius) * 0.9,
				y = config.position.y,
				z = config.position.z + math.random(-config.radius, config.radius) * 0.9,
			},
			lootTier = config.lootTier,
			isPickedUp = false,
		}
		table.insert(spawnedLoot[poiName], floorLootData)
	end

	print(`[POIManager] Spawned {#spawnedLoot[poiName]} loot items at {poiName}`)
end

--[[
	Spawn vehicles at a POI
]]
function POIManager.SpawnVehiclesAtPOI(poiName: string)
	local config = POIData.POIs[poiName]
	if not config then return end

	if not config.hasVehicleSpawn or not config.vehicleTypes then
		return
	end

	spawnedVehicles[poiName] = {}

	for _, vehicleType in ipairs(config.vehicleTypes) do
		local vehicleData = {
			id = poiName .. "_vehicle_" .. vehicleType .. "_" .. math.random(1000, 9999),
			poiName = poiName,
			vehicleType = vehicleType,
			position = {
				x = config.position.x + math.random(-20, 20),
				y = config.position.y,
				z = config.position.z + math.random(-20, 20),
			},
			isSpawned = true,
		}
		table.insert(spawnedVehicles[poiName], vehicleData)
	end

	print(`[POIManager] Spawned {#spawnedVehicles[poiName]} vehicles at {poiName}`)
end

--[[
	Spawn guaranteed dinosaurs at POI
]]
function POIManager.SpawnDinosaursAtPOI(poiName: string)
	local config = POIData.POIs[poiName]
	if not config then return end

	if not config.guaranteedDinos then return end

	local state = poiStates[poiName]
	if not state then return end

	state.activeDinos = {}

	for _, dinoType in ipairs(config.guaranteedDinos) do
		local dinoData = {
			type = dinoType,
			poiName = poiName,
			spawnPosition = {
				x = config.position.x + math.random(-config.radius * 0.5, config.radius * 0.5),
				y = config.position.y,
				z = config.position.z + math.random(-config.radius * 0.5, config.radius * 0.5),
			},
		}
		table.insert(state.activeDinos, dinoData)
	end

	print(`[POIManager] Spawned {#state.activeDinos} guaranteed dinosaurs at {poiName}`)
end

--[[
	Get POI state
]]
function POIManager.GetPOIState(poiName: string): POIState?
	return poiStates[poiName]
end

--[[
	Get all POI states
]]
function POIManager.GetAllPOIStates(): { [string]: POIState }
	return poiStates
end

--[[
	Mark chest as looted
]]
function POIManager.MarkChestLooted(poiName: string, chestId: string)
	local state = poiStates[poiName]
	if not state then return end

	state.lootedChests = state.lootedChests + 1

	if state.lootedChests >= state.totalChests then
		state.isLooted = true

		-- Broadcast POI looted
		Events.FireAllClients("Map", "POILooted", {
			poiName = poiName,
		})
	end

	-- Update loot state
	if spawnedLoot[poiName] then
		for _, loot in ipairs(spawnedLoot[poiName]) do
			if loot.id == chestId then
				loot.isOpened = true
				break
			end
		end
	end
end

--[[
	Get loot at POI
]]
function POIManager.GetLootAtPOI(poiName: string): { any }
	return spawnedLoot[poiName] or {}
end

--[[
	Get vehicles at POI
]]
function POIManager.GetVehiclesAtPOI(poiName: string): { any }
	return spawnedVehicles[poiName] or {}
end

--[[
	Get POI at position
]]
function POIManager.GetPOIAtPosition(x: number, z: number): POIData.POIConfig?
	local isInside, poi = POIData.IsInsidePOI(x, z)
	if isInside then
		return poi
	end
	return nil
end

--[[
	Get hot drop locations for deployment UI
]]
function POIManager.GetHotDropLocations(): { { name: string, position: { x: number, y: number, z: number }, dangerRating: number } }
	local hotDrops = POIData.GetHotDrops()
	local result = {}

	for _, poi in ipairs(hotDrops) do
		table.insert(result, {
			name = poi.displayName,
			position = poi.position,
			dangerRating = poi.dangerRating,
		})
	end

	return result
end

--[[
	Trigger special POI event
]]
function POIManager.TriggerPOIEvent(poiName: string, eventType: string, data: any?)
	local config = POIData.POIs[poiName]
	if not config then return end

	local state = poiStates[poiName]
	if not state then return end

	-- Store event in special state
	state.specialState = state.specialState or {}
	state.specialState[eventType] = {
		triggered = true,
		timestamp = tick(),
		data = data,
	}

	-- Broadcast to clients
	Events.FireAllClients("Map", "POIEvent", {
		poiName = poiName,
		eventType = eventType,
		data = data,
	})

	print(`[POIManager] Triggered event '{eventType}' at {poiName}`)
end

--[[
	Initialize all POIs
]]
function POIManager.InitializeAllPOIs()
	print("[POIManager] Initializing all POIs...")

	for poiName, config in pairs(POIData.POIs) do
		-- Initialize state
		poiStates[poiName] = initializePOIState(poiName, config)

		-- Spawn loot
		POIManager.SpawnLootAtPOI(poiName)

		-- Spawn vehicles
		POIManager.SpawnVehiclesAtPOI(poiName)

		-- Spawn dinosaurs
		POIManager.SpawnDinosaursAtPOI(poiName)
	end

	local poiCount = 0
	for _ in pairs(POIData.POIs) do
		poiCount = poiCount + 1
	end

	print(`[POIManager] Initialized {poiCount} POIs`)
end

--[[
	Initialize the POI manager
]]
function POIManager.Initialize()
	if isInitialized then return end

	isInitialized = true
	print("[POIManager] Initialized")
end

--[[
	Reset all loot at POIs (without resetting vehicles/dinos)
	Used by MapManager for between-match resets
]]
function POIManager.ResetAllLoot()
	print("[POIManager] Resetting all POI loot...")

	-- Reset loot state for all POIs
	for poiName, state in pairs(poiStates) do
		state.isLooted = false
		state.lootedChests = 0

		-- Clear spawned loot for this POI
		if spawnedLoot[poiName] then
			for _, loot in ipairs(spawnedLoot[poiName]) do
				loot.isOpened = false
				loot.isPickedUp = false
			end
		end
	end

	-- Respawn loot at all POIs
	for poiName, _ in pairs(POIData.POIs) do
		POIManager.SpawnLootAtPOI(poiName)
	end

	print("[POIManager] All POI loot reset")
end

--[[
	Reset for new match
]]
function POIManager.Reset()
	poiStates = {}
	spawnedLoot = {}
	spawnedVehicles = {}

	-- Re-initialize all POIs
	POIManager.InitializeAllPOIs()

	print("[POIManager] Reset")
end

return POIManager
