--!strict
--[[
	EnvironmentalEventManager.lua
	=============================
	Manages environmental events like volcanic eruptions, stampedes, and power outages
	Based on GDD Section 3.4: Environmental Events
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local BiomeData = require(ReplicatedStorage.Shared.BiomeData)
local POIData = require(ReplicatedStorage.Shared.POIData)
local Events = require(ReplicatedStorage.Shared.Events)

local EnvironmentalEventManager = {}

-- Types
export type EventType = "VolcanicEruption" | "Stampede" | "PowerOutage" | "PteranodonSwarm" | "Monsoon"

export type EventConfig = {
	name: string,
	displayName: string,
	description: string,
	duration: number, -- seconds
	warningTime: number, -- seconds before event starts
	cooldown: number, -- minimum seconds between events of this type
	biomes: { BiomeData.BiomeType }, -- biomes where this can occur
	triggerCondition: string, -- "Random" | "GunfireNearby" | "MidGame" | "NearAviary" | "Random"
	effects: { string },
}

-- Event configurations
local EVENT_CONFIGS: { [EventType]: EventConfig } = {
	VolcanicEruption = {
		name = "VolcanicEruption",
		displayName = "Volcanic Eruption",
		description = "Lava bombs rain down from the volcano, forcing players south",
		duration = 45,
		warningTime = 30,
		cooldown = 180,
		biomes = { "Volcanic" },
		triggerCondition = "Random",
		effects = { "LavaBombs", "ScreenShake", "ForcedRotation" },
	},

	Stampede = {
		name = "Stampede",
		displayName = "Dinosaur Stampede",
		description = "Herbivores charge across the plains, damaging everything in their path",
		duration = 20,
		warningTime = 10,
		cooldown = 120,
		biomes = { "Plains" },
		triggerCondition = "GunfireNearby",
		effects = { "ChargingDinos", "GroundShake", "AreaDamage" },
	},

	PowerOutage = {
		name = "PowerOutage",
		displayName = "Power Outage",
		description = "Facility lights go out and the Indoraptor is released",
		duration = 60,
		warningTime = 5,
		cooldown = 300,
		biomes = { "Research" },
		triggerCondition = "MidGame",
		effects = { "LightsOut", "IndoraptorRelease", "EmergencyAlarms" },
	},

	PteranodonSwarm = {
		name = "PteranodonSwarm",
		displayName = "Pteranodon Swarm",
		description = "Flying dinosaurs attack exposed players near the Aviary",
		duration = 30,
		warningTime = 8,
		cooldown = 150,
		biomes = { "Coast" },
		triggerCondition = "NearAviary",
		effects = { "AerialAttacks", "Knockback", "VisionObscured" },
	},

	Monsoon = {
		name = "Monsoon",
		displayName = "Monsoon",
		description = "Heavy rain reduces visibility and forces dinosaurs to seek shelter",
		duration = 90,
		warningTime = 15,
		cooldown = 240,
		biomes = { "Swamp", "Jungle", "Coast" },
		triggerCondition = "Random",
		effects = { "ReducedVisibility", "DinosShelter", "SlowMovement" },
	},
}

-- State
local isInitialized = false
local activeEvents: { [EventType]: ActiveEvent } = {}
local eventCooldowns: { [EventType]: number } = {}
local totalGunfireInPlains = 0

export type ActiveEvent = {
	eventType: EventType,
	startTime: number,
	endTime: number,
	warningStartTime: number,
	phase: "Warning" | "Active" | "Ending",
	affectedPlayers: { Player },
	data: { [string]: any },
}

--[[
	Check if an event can be triggered
]]
local function canTriggerEvent(eventType: EventType): boolean
	-- Check if already active
	if activeEvents[eventType] then
		return false
	end

	-- Check cooldown
	local lastTime = eventCooldowns[eventType] or 0
	local config = EVENT_CONFIGS[eventType]

	if tick() - lastTime < config.cooldown then
		return false
	end

	return true
end

--[[
	Get players in affected biomes
]]
local function getPlayersInBiomes(biomes: { BiomeData.BiomeType }): { Player }
	local affected = {}

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if not character then continue end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then continue end

		local playerBiome = BiomeData.GetBiomeAtPosition(rootPart.Position.X, rootPart.Position.Z)

		for _, biome in ipairs(biomes) do
			if playerBiome == biome then
				table.insert(affected, player)
				break
			end
		end
	end

	return affected
end

--[[
	Start warning phase for event
]]
local function startWarningPhase(eventType: EventType)
	local config = EVENT_CONFIGS[eventType]

	local event: ActiveEvent = {
		eventType = eventType,
		startTime = tick() + config.warningTime,
		endTime = tick() + config.warningTime + config.duration,
		warningStartTime = tick(),
		phase = "Warning",
		affectedPlayers = getPlayersInBiomes(config.biomes),
		data = {},
	}

	activeEvents[eventType] = event

	-- Broadcast warning
	Events.FireAllClients("Environment", "EventWarning", {
		eventType = eventType,
		displayName = config.displayName,
		description = config.description,
		warningTime = config.warningTime,
		biomes = config.biomes,
	})

	print(`[EnvironmentalEventManager] Warning: {config.displayName} in {config.warningTime}s`)
end

--[[
	Start active phase for event
]]
local function startActivePhase(eventType: EventType)
	local event = activeEvents[eventType]
	if not event then return end

	local config = EVENT_CONFIGS[eventType]

	event.phase = "Active"
	event.affectedPlayers = getPlayersInBiomes(config.biomes)

	-- Broadcast event start
	Events.FireAllClients("Environment", "EventStarted", {
		eventType = eventType,
		displayName = config.displayName,
		duration = config.duration,
		effects = config.effects,
	})

	-- Apply event-specific effects
	EnvironmentalEventManager.ApplyEventEffects(eventType, event)

	print(`[EnvironmentalEventManager] Started: {config.displayName}`)
end

--[[
	End event
]]
local function endEvent(eventType: EventType)
	local event = activeEvents[eventType]
	if not event then return end

	local config = EVENT_CONFIGS[eventType]

	-- Remove event effects
	EnvironmentalEventManager.RemoveEventEffects(eventType, event)

	-- Broadcast event end
	Events.FireAllClients("Environment", "EventEnded", {
		eventType = eventType,
		displayName = config.displayName,
	})

	-- Record cooldown
	eventCooldowns[eventType] = tick()

	-- Remove from active
	activeEvents[eventType] = nil

	print(`[EnvironmentalEventManager] Ended: {config.displayName}`)
end

--[[
	Apply event-specific effects
]]
function EnvironmentalEventManager.ApplyEventEffects(eventType: EventType, event: ActiveEvent)
	local config = EVENT_CONFIGS[eventType]

	if eventType == "VolcanicEruption" then
		-- Start lava bomb spawning
		event.data.lavaBombTask = task.spawn(function()
			while activeEvents[eventType] and activeEvents[eventType].phase == "Active" do
				-- Spawn lava bomb at random position in volcanic biome
				local bombX = BiomeData.MapCenter.x + math.random(-500, 500)
				local bombZ = 600 + math.random(-300, 300) -- Northern volcanic area

				Events.FireAllClients("Environment", "LavaBomb", {
					position = { x = bombX, y = 200, z = bombZ },
					radius = 15,
					damage = 50,
				})

				-- Deal damage to nearby players
				for _, player in ipairs(event.affectedPlayers) do
					local character = player.Character
					if not character then continue end

					local rootPart = character:FindFirstChild("HumanoidRootPart")
					if not rootPart then continue end

					local dx = rootPart.Position.X - bombX
					local dz = rootPart.Position.Z - bombZ
					local dist = math.sqrt(dx * dx + dz * dz)

					if dist < 15 then
						local humanoid = character:FindFirstChild("Humanoid")
						if humanoid then
							humanoid:TakeDamage(50)
						end
					end
				end

				task.wait(2 + math.random() * 2)
			end
		end)

	elseif eventType == "Stampede" then
		-- Spawn charging dinosaurs
		event.data.stampedePath = {
			startX = 600,
			startZ = 2000,
			endX = 1400,
			endZ = 2000,
			width = 100,
		}

		Events.FireAllClients("Environment", "StampedeStart", {
			path = event.data.stampedePath,
			duration = config.duration,
		})

		-- Damage players in path
		event.data.stampedeDamageTask = task.spawn(function()
			while activeEvents[eventType] and activeEvents[eventType].phase == "Active" do
				local elapsed = tick() - event.startTime
				local progress = elapsed / config.duration
				local currentX = event.data.stampedePath.startX +
					(event.data.stampedePath.endX - event.data.stampedePath.startX) * progress

				for _, player in ipairs(Players:GetPlayers()) do
					local character = player.Character
					if not character then continue end

					local rootPart = character:FindFirstChild("HumanoidRootPart")
					if not rootPart then continue end

					local dx = math.abs(rootPart.Position.X - currentX)
					local dz = math.abs(rootPart.Position.Z - event.data.stampedePath.startZ)

					if dx < 50 and dz < event.data.stampedePath.width then
						local humanoid = character:FindFirstChild("Humanoid")
						if humanoid then
							humanoid:TakeDamage(40)
							Events.FireClient(player, "Environment", "StampedeHit", {})
						end
					end
				end

				task.wait(0.5)
			end
		end)

	elseif eventType == "PowerOutage" then
		-- Trigger darkness in research complex
		Events.FireAllClients("Environment", "PowerOutage", {
			duration = config.duration,
		})

		-- Signal to spawn Indoraptor (handled by DinosaurManager)
		event.data.indoraptorSpawned = true

	elseif eventType == "PteranodonSwarm" then
		-- Start aerial attacks
		event.data.swarmTask = task.spawn(function()
			while activeEvents[eventType] and activeEvents[eventType].phase == "Active" do
				for _, player in ipairs(event.affectedPlayers) do
					local character = player.Character
					if not character then continue end

					local rootPart = character:FindFirstChild("HumanoidRootPart")
					if not rootPart then continue end

					-- Check if player is exposed (not under cover)
					-- Simplified: random chance of attack
					if math.random() < 0.3 then
						local humanoid = character:FindFirstChild("Humanoid")
						if humanoid then
							humanoid:TakeDamage(25)
							Events.FireClient(player, "Environment", "PteranodonAttack", {
								knockback = Vector3.new(
									math.random(-10, 10),
									5,
									math.random(-10, 10)
								),
							})
						end
					end
				end

				task.wait(3)
			end
		end)

	elseif eventType == "Monsoon" then
		-- Apply visibility reduction and movement slow
		Events.FireAllClients("Environment", "MonsoonStart", {
			duration = config.duration,
			visibilityMultiplier = 0.3,
			movementMultiplier = 0.85,
		})

		for _, player in ipairs(event.affectedPlayers) do
			local character = player.Character
			if not character then continue end

			local humanoid = character:FindFirstChild("Humanoid")
			if humanoid then
				local originalSpeed = humanoid.WalkSpeed
				humanoid:SetAttribute("PreMonsoonSpeed", originalSpeed)
				humanoid.WalkSpeed = originalSpeed * 0.85
			end
		end
	end
end

--[[
	Remove event-specific effects
]]
function EnvironmentalEventManager.RemoveEventEffects(eventType: EventType, event: ActiveEvent)
	if eventType == "Monsoon" then
		-- Restore movement speed
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			if not character then continue end

			local humanoid = character:FindFirstChild("Humanoid")
			if humanoid then
				local originalSpeed = humanoid:GetAttribute("PreMonsoonSpeed")
				if originalSpeed then
					humanoid.WalkSpeed = originalSpeed
					humanoid:SetAttribute("PreMonsoonSpeed", nil)
				end
			end
		end
	end

	-- Clear any running tasks
	if event.data then
		for key, value in pairs(event.data) do
			if type(value) == "thread" then
				task.cancel(value)
			end
		end
	end
end

--[[
	Trigger a specific event
]]
function EnvironmentalEventManager.TriggerEvent(eventType: EventType): boolean
	if not canTriggerEvent(eventType) then
		return false
	end

	startWarningPhase(eventType)
	return true
end

--[[
	Record gunfire (for stampede trigger)
]]
function EnvironmentalEventManager.RecordGunfire(position: Vector3)
	local biome = BiomeData.GetBiomeAtPosition(position.X, position.Z)

	if biome == "Plains" then
		totalGunfireInPlains = totalGunfireInPlains + 1

		-- Chance to trigger stampede
		if totalGunfireInPlains > 20 and math.random() < 0.1 then
			if EnvironmentalEventManager.TriggerEvent("Stampede") then
				totalGunfireInPlains = 0
			end
		end
	end
end

--[[
	Get active events
]]
function EnvironmentalEventManager.GetActiveEvents(): { [EventType]: ActiveEvent }
	return activeEvents
end

--[[
	Check if event is active
]]
function EnvironmentalEventManager.IsEventActive(eventType: EventType): boolean
	return activeEvents[eventType] ~= nil
end

--[[
	Update loop
]]
local function update()
	local now = tick()

	for eventType, event in pairs(activeEvents) do
		if event.phase == "Warning" and now >= event.startTime then
			startActivePhase(eventType)
		elseif event.phase == "Active" and now >= event.endTime then
			endEvent(eventType)
		end
	end
end

--[[
	Random event check
]]
local function checkRandomEvents()
	-- Check for random volcanic eruption
	if math.random() < 0.01 then -- 1% chance per check
		EnvironmentalEventManager.TriggerEvent("VolcanicEruption")
	end

	-- Check for random monsoon
	if math.random() < 0.005 then -- 0.5% chance per check
		EnvironmentalEventManager.TriggerEvent("Monsoon")
	end
end

--[[
	Initialize
]]
function EnvironmentalEventManager.Initialize()
	if isInitialized then return end

	-- Update loop
	task.spawn(function()
		while true do
			task.wait(1)
			update()
		end
	end)

	-- Random event check (every 30 seconds)
	task.spawn(function()
		while true do
			task.wait(30)
			checkRandomEvents()
		end
	end)

	isInitialized = true
	print("[EnvironmentalEventManager] Initialized")
end

--[[
	Reset for new match
]]
function EnvironmentalEventManager.Reset()
	-- End all active events
	for eventType in pairs(activeEvents) do
		endEvent(eventType)
	end

	activeEvents = {}
	eventCooldowns = {}
	totalGunfireInPlains = 0

	print("[EnvironmentalEventManager] Reset")
end

--[[
	Trigger mid-game events (called by GameManager)
]]
function EnvironmentalEventManager.OnMidGame()
	-- Chance to trigger power outage
	if math.random() < 0.5 then
		EnvironmentalEventManager.TriggerEvent("PowerOutage")
	end
end

return EnvironmentalEventManager
