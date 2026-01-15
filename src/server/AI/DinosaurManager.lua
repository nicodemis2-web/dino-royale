--!strict
--[[
	DinosaurManager.lua
	===================
	Manages spawning, updating, and lifecycle of all dinosaurs
	Handles spatial queries, sound events, and performance optimization
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local DinosaurData = require(game.ReplicatedStorage.Shared.Config.DinosaurData)
local Events = require(game.ReplicatedStorage.Shared.Events)

-- Lazy-load to avoid cyclic dependency
local DinosaurBase: any = nil
local BehaviorTree: any = nil

local DinosaurManager = {}

-- Type definitions
type SoundEvent = {
	position: Vector3,
	range: number,
	type: string, -- "Gunshot", "Footstep", "Vehicle", etc.
	source: Player?,
}

type SpawnPoint = {
	position: Vector3,
	biome: string,
	used: boolean,
}

-- State
local activeDinosaurs = {} :: { [string]: any } -- id -> DinosaurInstance
local sleepingDinosaurs = {} :: { [string]: { species: string, position: Vector3, state: any } }
local spawnPoints = {} :: { SpawnPoint }
local isInitialized = false

-- Settings
local MAX_ACTIVE_DINOSAURS = 50
local UPDATE_RADIUS = 200 -- Only update dinosaurs within this distance of players
local SLEEP_RADIUS = 250 -- Sleep dinosaurs beyond this distance
local MIN_SPAWN_DISTANCE = 50 -- Minimum distance between packs
local RESPAWN_CHECK_INTERVAL = 30 -- Check for respawns every 30 seconds

-- Spatial hash for efficient proximity queries
local CELL_SIZE = 50
local spatialHash = {} :: { [string]: { [string]: boolean } }

-- Tier spawn weights
local TIER_WEIGHTS = {
	Common = 40,
	Uncommon = 30,
	Rare = 20,
	Epic = 8,
	Legendary = 2,
}

-- Connections
local connections = {} :: { RBXScriptConnection }

--[[
	Get spatial hash key for a position
]]
local function getSpatialKey(position: Vector3): string
	local x = math.floor(position.X / CELL_SIZE)
	local z = math.floor(position.Z / CELL_SIZE)
	return `{x}_{z}`
end

--[[
	Add dinosaur to spatial hash
]]
local function addToSpatialHash(dinosaur: any)
	local key = getSpatialKey(dinosaur.currentPosition)
	if not spatialHash[key] then
		spatialHash[key] = {}
	end
	spatialHash[key][dinosaur.id] = true
end

--[[
	Remove dinosaur from spatial hash
]]
local function removeFromSpatialHash(dinosaur: any)
	local key = getSpatialKey(dinosaur.currentPosition)
	if spatialHash[key] then
		spatialHash[key][dinosaur.id] = nil
	end
end

--[[
	Update dinosaur position in spatial hash
]]
local function updateSpatialHash(dinosaur: any, oldPosition: Vector3)
	local oldKey = getSpatialKey(oldPosition)
	local newKey = getSpatialKey(dinosaur.currentPosition)

	if oldKey ~= newKey then
		if spatialHash[oldKey] then
			spatialHash[oldKey][dinosaur.id] = nil
		end
		if not spatialHash[newKey] then
			spatialHash[newKey] = {}
		end
		spatialHash[newKey][dinosaur.id] = true
	end
end

--[[
	Load dinosaur modules (lazy loading)
]]
local function loadModules()
	if not DinosaurBase then
		DinosaurBase = require(script.Parent.DinosaurBase)
	end
	if not BehaviorTree then
		BehaviorTree = require(script.Parent.BehaviorTree)
		DinosaurBase.SetBehaviorTreeModule(BehaviorTree)
	end
end

--[[
	Get nearest player position (for optimization checks)
]]
local function getNearestPlayerDistance(position: Vector3): number
	local nearestDistance = math.huge

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if rootPart then
				local distance = (rootPart.Position - position).Magnitude
				nearestDistance = math.min(nearestDistance, distance)
			end
		end
	end

	return nearestDistance
end

--[[
	Select a random species based on tier weights
]]
local function selectRandomSpecies(biome: string?): string?
	-- Calculate total weight
	local totalWeight = 0
	for _, weight in pairs(TIER_WEIGHTS) do
		totalWeight = totalWeight + weight
	end

	-- Random roll
	local roll = math.random() * totalWeight
	local currentWeight = 0
	local selectedTier: string? = nil

	for tier, weight in pairs(TIER_WEIGHTS) do
		currentWeight = currentWeight + weight
		if roll <= currentWeight then
			selectedTier = tier
			break
		end
	end

	if not selectedTier then
		selectedTier = "Common"
	end

	-- Get species list for tier
	local tierSpecies = DinosaurData.ByTier[selectedTier]
	if not tierSpecies or #tierSpecies == 0 then
		return nil
	end

	-- Random species from tier
	return tierSpecies[math.random(1, #tierSpecies)]
end

-- Require the realistic dinosaur model builder
local DinosaurModelBuilder = require(script.Parent:FindFirstChild("DinosaurModelBuilder"))

--[[
	Create a realistic dinosaur model using the model builder
]]
local function createDinosaurModel(species: string, position: Vector3): Model?
	print(`[DinosaurManager] Creating realistic model for {species} at {position}`)

	-- Get species data
	local speciesData = DinosaurData.AllDinosaurs[species]
	local tier = speciesData and speciesData.tier or "Common"
	local health = speciesData and speciesData.health or 100
	local speed = speciesData and speciesData.speed or 16

	-- Use the model builder for realistic multi-part dinosaur models
	local model = DinosaurModelBuilder.Build(species, position, tier, health, speed)

	if model then
		print(`[DinosaurManager] SUCCESS: {species} realistic model created at {position}`)
	else
		warn(`[DinosaurManager] FAILED: Could not build {species} model`)
	end

	return model
end

--[[
	Spawn a single dinosaur
	@param species Species name
	@param position Spawn position
	@return DinosaurInstance or nil
]]
function DinosaurManager.SpawnDinosaur(species: string, position: Vector3): any
	local success, result = pcall(function()
		loadModules()

		if not DinosaurData.AllDinosaurs[species] then
			warn(`[DinosaurManager] Unknown species: {species}`)
			return nil
		end

		-- Check max count
		local activeCount = 0
		for _ in pairs(activeDinosaurs) do
			activeCount = activeCount + 1
		end

		if activeCount >= MAX_ACTIVE_DINOSAURS then
			warn("[DinosaurManager] Max dinosaurs reached")
			return nil
		end

		-- Create dinosaur instance
		print(`[DinosaurManager] Creating {species} instance...`)
		local dinosaur = DinosaurBase.new(species, position)

		-- Create model
		print(`[DinosaurManager] Creating model for {species}...`)
		local model = createDinosaurModel(species, position)
		dinosaur:SetModel(model)

		-- Create behavior tree (optional - don't fail if it errors)
		local btSuccess, behaviorTree = pcall(function()
			return dinosaur:CreateDefaultBehaviorTree()
		end)
		if btSuccess and behaviorTree then
			dinosaur:SetBehaviorTree(behaviorTree)
		else
			print(`[DinosaurManager] Behavior tree creation skipped for {species}`)
		end

		-- Register
		activeDinosaurs[dinosaur.id] = dinosaur
		addToSpatialHash(dinosaur)

		-- Broadcast spawn
		Events.FireAllClients("Dinosaur", "DinosaurSpawned", {
			dinoId = dinosaur.id,
			species = species,
			position = position,
		})

		print(`[DinosaurManager] Spawned {species} at {position}`)

		return dinosaur
	end)

	if not success then
		warn(`[DinosaurManager] Failed to spawn {species}: {result}`)
		return nil
	end

	return result
end

--[[
	Spawn a pack of dinosaurs
	@param species Species name
	@param position Center position
	@param count Number of dinosaurs
	@return Array of DinosaurInstances
]]
function DinosaurManager.SpawnPack(species: string, position: Vector3, count: number): { any }
	local pack = {} :: { any }

	for i = 1, count do
		local offset = Vector3.new(
			(math.random() - 0.5) * 10,
			0,
			(math.random() - 0.5) * 10
		)
		local spawnPos = position + offset

		local dinosaur = DinosaurManager.SpawnDinosaur(species, spawnPos)
		if dinosaur then
			table.insert(pack, dinosaur)
		end
	end

	return pack
end

--[[
	Despawn a dinosaur
	@param dinosaur DinosaurInstance
]]
function DinosaurManager.DespawnDinosaur(dinosaur: any)
	if not dinosaur then
		return
	end

	removeFromSpatialHash(dinosaur)
	activeDinosaurs[dinosaur.id] = nil

	if dinosaur.model then
		dinosaur.model:Destroy()
	end

	print(`[DinosaurManager] Despawned {dinosaur.species} ({dinosaur.id})`)
end

--[[
	Get dinosaurs near a position
	@param position Center position
	@param radius Search radius
	@return Array of DinosaurInstances
]]
function DinosaurManager.GetNearbyDinosaurs(position: Vector3, radius: number): { any }
	local nearby = {} :: { any }

	-- Check cells within radius
	local cellRadius = math.ceil(radius / CELL_SIZE)
	local centerX = math.floor(position.X / CELL_SIZE)
	local centerZ = math.floor(position.Z / CELL_SIZE)

	for dx = -cellRadius, cellRadius do
		for dz = -cellRadius, cellRadius do
			local key = `{centerX + dx}_{centerZ + dz}`
			local cell = spatialHash[key]

			if cell then
				for dinoId in pairs(cell) do
					local dinosaur = activeDinosaurs[dinoId]
					if dinosaur then
						local distance = (dinosaur.currentPosition - position).Magnitude
						if distance <= radius then
							table.insert(nearby, dinosaur)
						end
					end
				end
			end
		end
	end

	return nearby
end

--[[
	Broadcast a sound event to nearby dinosaurs
	@param event SoundEvent
]]
function DinosaurManager.BroadcastSoundEvent(event: SoundEvent)
	local nearbyDinos = DinosaurManager.GetNearbyDinosaurs(event.position, event.range)

	for _, dinosaur in ipairs(nearbyDinos) do
		if dinosaur:CanHear(event.position, event.range) then
			-- Update behavior tree context
			if dinosaur.behaviorTree then
				dinosaur.behaviorTree.context.alertLevel = 3
				dinosaur.behaviorTree.context.lastTargetPosition = event.position

				-- Some dinosaurs might aggro on sound source
				if event.source and event.type == "Gunshot" then
					dinosaur.behaviorTree:SetTarget(event.source)
				end
			end
		end
	end
end

--[[
	Sleep a dinosaur (remove model, save state)
]]
local function sleepDinosaur(dinosaur: any)
	sleepingDinosaurs[dinosaur.id] = {
		species = dinosaur.species,
		position = dinosaur.currentPosition,
		state = dinosaur:Serialize(),
	}

	removeFromSpatialHash(dinosaur)
	activeDinosaurs[dinosaur.id] = nil

	if dinosaur.model then
		dinosaur.model:Destroy()
		dinosaur.model = nil
	end
end

--[[
	Wake a sleeping dinosaur (recreate model)
]]
local function wakeDinosaur(id: string)
	local sleepData = sleepingDinosaurs[id]
	if not sleepData then
		return
	end

	sleepingDinosaurs[id] = nil

	-- Respawn
	local dinosaur = DinosaurManager.SpawnDinosaur(sleepData.species, sleepData.position)
	if dinosaur and sleepData.state then
		-- Restore state
		dinosaur.stats.health = sleepData.state.health
	end
end

--[[
	Update all active dinosaurs
	@param dt Delta time
]]
function DinosaurManager.Update(dt: number)
	if not isInitialized then
		return
	end

	-- Update active dinosaurs
	for id, dinosaur in pairs(activeDinosaurs) do
		local success, err = pcall(function()
			if not dinosaur.isAlive then
				-- Cleanup dead dinosaurs
				DinosaurManager.DespawnDinosaur(dinosaur)
				return
			end

			local oldPosition = dinosaur.currentPosition
			local distance = getNearestPlayerDistance(oldPosition)

			-- Sleep distant dinosaurs
			if distance > SLEEP_RADIUS then
				sleepDinosaur(dinosaur)
				return
			end

			-- Only update nearby dinosaurs
			if distance <= UPDATE_RADIUS then
				dinosaur:Update(dt)

				-- Update spatial hash if moved
				if (dinosaur.currentPosition - oldPosition).Magnitude > 1 then
					updateSpatialHash(dinosaur, oldPosition)
				end
			end
		end)

		if not success then
			warn(`[DinosaurManager] Error updating dinosaur {id}: {err}`)
		end
	end

	-- Wake sleeping dinosaurs near players
	for id, sleepData in pairs(sleepingDinosaurs) do
		local distance = getNearestPlayerDistance(sleepData.position)
		if distance < UPDATE_RADIUS then
			wakeDinosaur(id)
		end
	end
end

--[[
	Check for respawn opportunities
]]
local function checkRespawns()
	-- Count active dinosaurs
	local activeCount = 0
	for _ in pairs(activeDinosaurs) do
		activeCount = activeCount + 1
	end

	-- Spawn more if under limit
	local toSpawn = math.min(5, MAX_ACTIVE_DINOSAURS - activeCount)

	for _ = 1, toSpawn do
		-- Find spawn point near players but not too close
		local spawnPos: Vector3? = nil

		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			if character then
				local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if rootPart then
					-- Random offset from player
					local angle = math.random() * math.pi * 2
					local distance = 100 + math.random() * 100
					local offset = Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
					spawnPos = rootPart.Position + offset
					break
				end
			end
		end

		if spawnPos then
			local species = selectRandomSpecies()
			if species then
				DinosaurManager.SpawnDinosaur(species, spawnPos)
			end
		end
	end
end

--[[
	Find spawn points from map tags
]]
local function findSpawnPoints()
	spawnPoints = {}

	-- Look for tagged spawn points
	local taggedPoints = CollectionService:GetTagged("DinosaurSpawn")

	for _, part in ipairs(taggedPoints) do
		if part:IsA("BasePart") then
			local biome = part:GetAttribute("Biome") or "Default"
			table.insert(spawnPoints, {
				position = part.Position,
				biome = biome,
				used = false,
			})
		end
	end

	print(`[DinosaurManager] Found {#spawnPoints} spawn points`)
end

--[[
	Initialize the dinosaur manager
]]
function DinosaurManager.Initialize()
	if isInitialized then
		return
	end

	loadModules()
	findSpawnPoints()

	-- Spawn initial dinosaurs around the jungle spawn area (200, Y, 200)
	-- This matches where MapManager creates the LobbySpawn in the jungle center
	local initialCount = math.min(15, MAX_ACTIVE_DINOSAURS) -- Spawn more dinos for bigger map

	-- Find LobbySpawn position, or use default jungle center location
	local spawnCenter = Vector3.new(200, 0, 200) -- Jungle center (per updated MapManager)
	local lobbySpawn = workspace:FindFirstChild("LobbySpawn")
	if lobbySpawn then
		spawnCenter = Vector3.new(lobbySpawn.Position.X, 0, lobbySpawn.Position.Z)
		print(`[DinosaurManager] Found LobbySpawn, spawning dinos around {spawnCenter}`)
	else
		print(`[DinosaurManager] No LobbySpawn found, using default jungle center {spawnCenter}`)
	end

	-- Get terrain height at spawn location using raycast
	local function getTerrainHeight(x: number, z: number): number
		local rayOrigin = Vector3.new(x, 500, z)
		local rayResult = workspace:Raycast(rayOrigin, Vector3.new(0, -1000, 0))
		if rayResult then
			return rayResult.Position.Y + 10 -- 10 studs above terrain for realistic dino models
		end
		return 35 -- Fallback height (spawn platform is at Y~27-30)
	end

	print(`[DinosaurManager] Spawning {initialCount} realistic dinosaurs around jungle spawn...`)

	for i = 1, initialCount do
		-- Random position around spawn at various distances (40-120 studs out for bigger map)
		local angle = (i / initialCount) * math.pi * 2 -- Evenly distributed
		local distance = 40 + (i * 8) -- 48, 56, 64... studs out

		local x = spawnCenter.X + math.cos(angle) * distance
		local z = spawnCenter.Z + math.sin(angle) * distance
		local y = getTerrainHeight(x, z)

		local position = Vector3.new(x, y, z)

		print(`[DinosaurManager] Spawn #{i}: position={position}`)

		local species = selectRandomSpecies()
		if species then
			local dino = DinosaurManager.SpawnDinosaur(species, position)
			if dino then
				print(`[DinosaurManager] SUCCESS #{i}: Spawned {species} at {position}`)
			else
				warn(`[DinosaurManager] FAILED #{i}: Could not spawn {species}`)
			end
		else
			warn(`[DinosaurManager] FAILED #{i}: No species selected!`)
		end
	end

	print(`[DinosaurManager] Finished spawning initial dinosaurs`)

	-- Update loop
	local updateConnection = RunService.Heartbeat:Connect(function(dt)
		DinosaurManager.Update(dt)
	end)
	table.insert(connections, updateConnection)

	-- Respawn check
	task.spawn(function()
		while isInitialized do
			task.wait(RESPAWN_CHECK_INTERVAL)
			checkRespawns()
		end
	end)

	-- Listen for weapon fire events (for sound broadcasting)
	local fireConnection = Events.OnServerEvent("Combat", "WeaponFire", function(player, data)
		DinosaurManager.BroadcastSoundEvent({
			position = data.origin,
			range = 150, -- Gunshots are loud
			type = "Gunshot",
			source = player,
		})
	end)
	table.insert(connections, fireConnection)

	isInitialized = true
	print("[DinosaurManager] Initialized")
end

--[[
	Get active dinosaur count
]]
function DinosaurManager.GetActiveCount(): number
	local count = 0
	for _ in pairs(activeDinosaurs) do
		count = count + 1
	end
	return count
end

--[[
	Get dinosaur by ID
]]
function DinosaurManager.GetDinosaur(id: string): any?
	return activeDinosaurs[id]
end

--[[
	Reset the manager
]]
function DinosaurManager.Reset()
	-- Despawn all dinosaurs
	for id, dinosaur in pairs(activeDinosaurs) do
		if dinosaur.model then
			dinosaur.model:Destroy()
		end
	end

	activeDinosaurs = {}
	sleepingDinosaurs = {}
	spatialHash = {}

	print("[DinosaurManager] Reset")
end

--[[
	Cleanup
]]
function DinosaurManager.Cleanup()
	isInitialized = false

	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	connections = {}

	DinosaurManager.Reset()
end

return DinosaurManager
