--!strict
--[[
	BossEventManager.lua
	====================
	Manages boss spawn events during matches
	T-Rex Rampage, Indoraptor Hunt, and other special events
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Events = require(game.ReplicatedStorage.Shared.Events)

-- Lazy load boss modules
local TRex: any = nil
local Indoraptor: any = nil
local DinosaurManager: any = nil

local BossEventManager = {}

-- Event types
export type BossEventType = "TRexRampage" | "IndoraptorHunt" | "RandomBoss"

-- Active boss tracking
local activeBosses = {} :: { [string]: any }
local bossHealthBars = {} :: { [string]: boolean }

-- Event state
local isInitialized = false
local currentEvent: BossEventType? = nil
local eventEndTime = 0

-- Settings
local TREX_RAMPAGE_CIRCLES = { 3, 4 } -- Circles where T-Rex can spawn
local INDORAPTOR_PLAYER_THRESHOLD = 10 -- Spawn when <= 10 players
local BOSS_DESPAWN_DISTANCE = 500 -- Despawn if too far from all players

-- Connections
local connections = {} :: { RBXScriptConnection }

--[[
	Load boss modules (lazy loading)
]]
local function loadModules()
	if not TRex then
		TRex = require(script.Parent.Parent.AI.Dinosaurs.TRex)
	end
	if not Indoraptor then
		Indoraptor = require(script.Parent.Parent.AI.Dinosaurs.Indoraptor)
	end
	if not DinosaurManager then
		DinosaurManager = require(script.Parent.Parent.AI.DinosaurManager)
	end
end

--[[
	Get random spawn position near players but not too close
]]
local function getSpawnPosition(): Vector3
	local validPositions = {} :: { Vector3 }

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if rootPart then
				-- Position 80-150 studs away
				local angle = math.random() * math.pi * 2
				local distance = 80 + math.random() * 70
				local offset = Vector3.new(
					math.cos(angle) * distance,
					0,
					math.sin(angle) * distance
				)
				table.insert(validPositions, rootPart.Position + offset)
			end
		end
	end

	if #validPositions > 0 then
		return validPositions[math.random(1, #validPositions)]
	end

	-- Fallback to center
	return Vector3.new(0, 50, 0)
end

--[[
	Spawn a T-Rex boss
	@param position Spawn position
	@return TRex instance
]]
function BossEventManager.SpawnTRex(position: Vector3): any
	loadModules()

	local trex = TRex.new(position)

	-- Create model
	local model = Instance.new("Model")
	model.Name = "TRex_Boss"

	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = Vector3.new(8, 12, 20) -- Big boi
	rootPart.CFrame = CFrame.new(position)
	rootPart.Anchored = false
	rootPart.CanCollide = true
	rootPart.Parent = model

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = trex.stats.maxHealth
	humanoid.Health = trex.stats.health
	humanoid.WalkSpeed = trex.stats.speed
	humanoid.Parent = model

	model.PrimaryPart = rootPart
	model.Parent = workspace

	trex:SetModel(model)

	-- Create behavior tree
	local behaviorTree = trex:CreateDefaultBehaviorTree()
	if behaviorTree then
		trex:SetBehaviorTree(behaviorTree)
	end

	-- Register boss
	activeBosses[trex.id] = trex

	-- Show boss health bar to all
	BossEventManager.ShowBossHealthBar(trex, "T-Rex")

	-- Broadcast spawn
	Events.FireAllClients("Dinosaur", "BossSpawned", {
		bossId = trex.id,
		species = "TRex",
		position = position,
		health = trex.stats.health,
		maxHealth = trex.stats.maxHealth,
	})

	print(`[BossEventManager] T-Rex spawned at {position}!`)

	return trex
end

--[[
	Spawn an Indoraptor boss
	@param position Spawn position
	@return Indoraptor instance
]]
function BossEventManager.SpawnIndoraptor(position: Vector3): any
	loadModules()

	local indo = Indoraptor.new(position)

	-- Create model
	local model = Instance.new("Model")
	model.Name = "Indoraptor_Boss"

	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = Vector3.new(4, 6, 12)
	rootPart.CFrame = CFrame.new(position)
	rootPart.Anchored = false
	rootPart.CanCollide = true
	rootPart.Color = Color3.fromRGB(30, 30, 30) -- Dark colored
	rootPart.Parent = model

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = indo.stats.maxHealth
	humanoid.Health = indo.stats.health
	humanoid.WalkSpeed = indo.stats.speed
	humanoid.Parent = model

	model.PrimaryPart = rootPart
	model.Parent = workspace

	indo:SetModel(model)

	-- Create behavior tree
	local behaviorTree = indo:CreateDefaultBehaviorTree()
	if behaviorTree then
		indo:SetBehaviorTree(behaviorTree)
	end

	-- Register boss
	activeBosses[indo.id] = indo

	-- Show boss health bar
	BossEventManager.ShowBossHealthBar(indo, "Indoraptor")

	-- Broadcast spawn
	Events.FireAllClients("Dinosaur", "BossSpawned", {
		bossId = indo.id,
		species = "Indoraptor",
		position = position,
		health = indo.stats.health,
		maxHealth = indo.stats.maxHealth,
	})

	print(`[BossEventManager] Indoraptor spawned at {position}!`)

	return indo
end

--[[
	Show boss health bar to all players
]]
function BossEventManager.ShowBossHealthBar(boss: any, name: string)
	bossHealthBars[boss.id] = true

	Events.FireAllClients("UI", "ShowBossHealthBar", {
		bossId = boss.id,
		name = name,
		health = boss.stats.health,
		maxHealth = boss.stats.maxHealth,
	})
end

--[[
	Update boss health bar
]]
function BossEventManager.UpdateBossHealthBar(boss: any)
	if not bossHealthBars[boss.id] then
		return
	end

	Events.FireAllClients("UI", "UpdateBossHealthBar", {
		bossId = boss.id,
		health = boss.stats.health,
		maxHealth = boss.stats.maxHealth,
	})
end

--[[
	Hide boss health bar
]]
function BossEventManager.HideBossHealthBar(bossId: string)
	bossHealthBars[bossId] = nil

	Events.FireAllClients("UI", "HideBossHealthBar", {
		bossId = bossId,
	})
end

--[[
	Start T-Rex Rampage event
]]
function BossEventManager.StartTRexRampage()
	if currentEvent ~= nil then
		return -- Already an event running
	end

	currentEvent = "TRexRampage"
	eventEndTime = tick() + 300 -- 5 minute event

	local spawnPos = getSpawnPosition()
	BossEventManager.SpawnTRex(spawnPos)

	-- Announce to players
	Events.FireAllClients("GameState", "BossEvent", {
		type = "TRexRampage",
		message = "A T-REX HAS APPEARED!",
	})

	print("[BossEventManager] T-Rex Rampage started!")
end

--[[
	Start Indoraptor Hunt event
]]
function BossEventManager.StartIndoraptorHunt()
	if currentEvent ~= nil then
		return
	end

	currentEvent = "IndoraptorHunt"
	eventEndTime = tick() + 600 -- 10 minute event (or until killed)

	local spawnPos = getSpawnPosition()
	BossEventManager.SpawnIndoraptor(spawnPos)

	-- Announce to players
	Events.FireAllClients("GameState", "BossEvent", {
		type = "IndoraptorHunt",
		message = "The INDORAPTOR stalks the island...",
	})

	print("[BossEventManager] Indoraptor Hunt started!")
end

--[[
	Check event triggers based on game state
]]
function BossEventManager.CheckEventTriggers(gameState: { currentPhase: number?, aliveCount: number? })
	-- T-Rex during circles 3-4
	if gameState.currentPhase then
		local phase = gameState.currentPhase
		for _, triggerPhase in ipairs(TREX_RAMPAGE_CIRCLES) do
			if phase == triggerPhase and currentEvent == nil then
				-- Random chance to trigger
				if math.random() < 0.3 then
					BossEventManager.StartTRexRampage()
				end
				break
			end
		end
	end

	-- Indoraptor when <= 10 players
	if gameState.aliveCount and gameState.aliveCount <= INDORAPTOR_PLAYER_THRESHOLD then
		if currentEvent == nil then
			BossEventManager.StartIndoraptorHunt()
		end
	end
end

--[[
	Update all active bosses
	@param dt Delta time
]]
function BossEventManager.Update(dt: number)
	if not isInitialized then
		return
	end

	-- Update active bosses
	for id, boss in pairs(activeBosses) do
		if not boss.isAlive then
			-- Boss died
			BossEventManager.OnBossDeath(boss)
			activeBosses[id] = nil
			continue
		end

		-- Update boss
		boss:Update(dt)

		-- Update health bar
		BossEventManager.UpdateBossHealthBar(boss)

		-- Check if boss is too far from all players (despawn)
		local nearestDistance = math.huge
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			if character then
				local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if rootPart then
					local distance = (rootPart.Position - boss.currentPosition).Magnitude
					nearestDistance = math.min(nearestDistance, distance)
				end
			end
		end

		if nearestDistance > BOSS_DESPAWN_DISTANCE then
			print(`[BossEventManager] Boss {boss.id} despawned (too far)`)
			boss:Die()
		end
	end

	-- Check event timeout
	if currentEvent and tick() > eventEndTime then
		BossEventManager.EndCurrentEvent()
	end
end

--[[
	Handle boss death
]]
function BossEventManager.OnBossDeath(boss: any)
	-- Hide health bar
	BossEventManager.HideBossHealthBar(boss.id)

	-- Broadcast death
	Events.FireAllClients("Dinosaur", "BossKilled", {
		bossId = boss.id,
		species = boss.species,
		killerId = boss.target and boss.target.UserId or nil,
	})

	-- Spawn legendary loot
	BossEventManager.SpawnBossLoot(boss)

	print(`[BossEventManager] Boss {boss.species} killed!`)

	-- End event if this was the event boss
	if currentEvent then
		BossEventManager.EndCurrentEvent()
	end
end

--[[
	Spawn loot from boss death
]]
function BossEventManager.SpawnBossLoot(boss: any)
	local lootCount = boss.species == "TRex" and 3 or 2 -- T-Rex drops 3, Indo drops 2

	-- Would integrate with LootSpawner
	Events.FireAllClients("GameState", "BossLootDropped", {
		position = boss.currentPosition,
		lootCount = lootCount,
		species = boss.species,
	})

	print(`[BossEventManager] Dropped {lootCount} legendary items from {boss.species}`)
end

--[[
	End current event
]]
function BossEventManager.EndCurrentEvent()
	local eventType = currentEvent
	currentEvent = nil
	eventEndTime = 0

	-- Announce event end
	Events.FireAllClients("GameState", "BossEventEnded", {
		type = eventType,
	})

	print(`[BossEventManager] Event {eventType} ended`)
end

--[[
	Get active boss count
]]
function BossEventManager.GetActiveBossCount(): number
	local count = 0
	for _ in pairs(activeBosses) do
		count = count + 1
	end
	return count
end

--[[
	Get boss by ID
]]
function BossEventManager.GetBoss(id: string): any?
	return activeBosses[id]
end

--[[
	Initialize the boss event manager
]]
function BossEventManager.Initialize()
	if isInitialized then
		return
	end

	loadModules()

	-- Update loop
	local updateConnection = RunService.Heartbeat:Connect(function(dt)
		BossEventManager.Update(dt)
	end)
	table.insert(connections, updateConnection)

	isInitialized = true
	print("[BossEventManager] Initialized")
end

--[[
	Reset the manager
]]
function BossEventManager.Reset()
	-- Kill all active bosses
	for id, boss in pairs(activeBosses) do
		BossEventManager.HideBossHealthBar(id)
		if boss.model then
			boss.model:Destroy()
		end
	end

	activeBosses = {}
	bossHealthBars = {}
	currentEvent = nil
	eventEndTime = 0

	print("[BossEventManager] Reset")
end

--[[
	Cleanup
]]
function BossEventManager.Cleanup()
	isInitialized = false

	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	connections = {}

	BossEventManager.Reset()
end

return BossEventManager
