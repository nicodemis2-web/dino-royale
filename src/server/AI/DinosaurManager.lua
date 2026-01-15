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

--[[
	Create a dinosaur model (placeholder - visible colored box)
]]
local function createDinosaurModel(species: string, position: Vector3): Model
	-- Raycast to find ground height at spawn position
	local workspace = game:GetService("Workspace")
	local rayOrigin = Vector3.new(position.X, 500, position.Z)
	local rayDirection = Vector3.new(0, -600, 0)
	local rayResult = workspace:Raycast(rayOrigin, rayDirection)

	local spawnHeight = position.Y
	if rayResult then
		spawnHeight = rayResult.Position.Y + 3 -- Spawn slightly above ground
	end
	local spawnPosition = Vector3.new(position.X, spawnHeight, position.Z)

	-- In production, would clone from ReplicatedStorage
	local model = Instance.new("Model")
	model.Name = species

	-- Get species data for size scaling
	local speciesData = DinosaurData.AllDinosaurs[species]
	local tier = speciesData and speciesData.tier or "Common"

	-- Size based on tier
	local sizeMultiplier = ({
		Common = 1,
		Uncommon = 1.5,
		Rare = 2,
		Epic = 3,
		Legendary = 5,
	})[tier] or 1

	-- Color based on tier for visibility
	local tierColors = {
		Common = BrickColor.new("Bright green"),
		Uncommon = BrickColor.new("Bright blue"),
		Rare = BrickColor.new("Bright violet"),
		Epic = BrickColor.new("Bright orange"),
		Legendary = BrickColor.new("Bright red"),
	}

	-- Create body (main part)
	local body = Instance.new("Part")
	body.Name = "HumanoidRootPart"
	body.Size = Vector3.new(4 * sizeMultiplier, 3 * sizeMultiplier, 8 * sizeMultiplier)
	body.CFrame = CFrame.new(spawnPosition)
	body.Anchored = false
	body.CanCollide = true
	body.BrickColor = tierColors[tier] or BrickColor.new("Medium stone grey")
	body.Material = Enum.Material.SmoothPlastic
	body.Parent = model

	-- Create head
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2 * sizeMultiplier, 2 * sizeMultiplier, 3 * sizeMultiplier)
	head.CFrame = CFrame.new(spawnPosition + Vector3.new(0, 1 * sizeMultiplier, 4 * sizeMultiplier))
	head.Anchored = false
	head.CanCollide = false
	head.BrickColor = tierColors[tier] or BrickColor.new("Medium stone grey")
	head.Material = Enum.Material.SmoothPlastic
	head.Parent = model

	-- Weld head to body
	local headWeld = Instance.new("WeldConstraint")
	headWeld.Part0 = body
	headWeld.Part1 = head
	headWeld.Parent = head

	-- Create humanoid
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = speciesData and speciesData.health or 100
	humanoid.Health = humanoid.MaxHealth
	humanoid.WalkSpeed = speciesData and speciesData.speed or 16
	humanoid.Parent = model

	-- Add name label
	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Size = UDim2.new(0, 100, 0, 40)
	billboardGui.StudsOffset = Vector3.new(0, 3 * sizeMultiplier, 0)
	billboardGui.Adornee = body
	billboardGui.Parent = model

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = species
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextStrokeTransparency = 0
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.Parent = billboardGui

	model.PrimaryPart = body
	model.Parent = workspace

	return model
end

--[[
	Spawn a single dinosaur
	@param species Species name
	@param position Spawn position
	@return DinosaurInstance or nil
]]
function DinosaurManager.SpawnDinosaur(species: string, position: Vector3): any
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

	-- Create dinosaur
	local dinosaur = DinosaurBase.new(species, position)

	-- Create model
	local model = createDinosaurModel(species, position)
	dinosaur:SetModel(model)

	-- Create behavior tree
	local behaviorTree = dinosaur:CreateDefaultBehaviorTree()
	if behaviorTree then
		dinosaur:SetBehaviorTree(behaviorTree)
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
		if not dinosaur.isAlive then
			-- Cleanup dead dinosaurs
			DinosaurManager.DespawnDinosaur(dinosaur)
			continue
		end

		local oldPosition = dinosaur.currentPosition
		local distance = getNearestPlayerDistance(oldPosition)

		-- Sleep distant dinosaurs
		if distance > SLEEP_RADIUS then
			sleepDinosaur(dinosaur)
			continue
		end

		-- Only update nearby dinosaurs
		if distance <= UPDATE_RADIUS then
			dinosaur:Update(dt)

			-- Update spatial hash if moved
			if (dinosaur.currentPosition - oldPosition).Magnitude > 1 then
				updateSpatialHash(dinosaur, oldPosition)
			end
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

	-- Spawn initial dinosaurs around the spawn area (jungle biome)
	-- Player spawns at (400, Y, 400), so spawn dinos in a ring around that
	local initialCount = math.min(20, MAX_ACTIVE_DINOSAURS)
	local spawnCenter = Vector3.new(400, 50, 400) -- Jungle biome spawn area

	for i = 1, initialCount do
		-- Random position if no spawn points
		local position: Vector3

		if #spawnPoints > 0 then
			local point = spawnPoints[math.random(1, #spawnPoints)]
			position = point.position
		else
			-- Spawn in a ring around the player spawn (100-300 studs away)
			local angle = (i / initialCount) * math.pi * 2 + math.random() * 0.5
			local distance = 100 + math.random() * 200
			position = spawnCenter + Vector3.new(
				math.cos(angle) * distance,
				50,
				math.sin(angle) * distance
			)
		end

		local species = selectRandomSpecies()
		if species then
			DinosaurManager.SpawnDinosaur(species, position)
		end
	end

	print(`[DinosaurManager] Spawned {initialCount} initial dinosaurs around spawn area`)

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
