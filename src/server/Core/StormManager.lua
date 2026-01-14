--!strict
--[[
	StormManager.lua
	================
	Extinction Wave (storm) circle management
	Handles shrinking safe zone with damage over time
]]

local Players = game:GetService("Players")

local Events = require(game.ReplicatedStorage.Shared.Events)

-- Forward declarations for HealthManager (to avoid circular dependency)
local HealthManager: any = nil

local StormManager = {}

-- Storm phase configuration from GDD
local STORM_PHASES = {
	{
		phase = 1,
		waitTime = 180,
		shrinkTime = 120,
		damage = 1,
		startRadius = 1.0, -- Percentage of map radius
		endRadius = 0.6,
	},
	{
		phase = 2,
		waitTime = 120,
		shrinkTime = 90,
		damage = 2,
		startRadius = 0.6,
		endRadius = 0.35,
	},
	{
		phase = 3,
		waitTime = 90,
		shrinkTime = 60,
		damage = 5,
		startRadius = 0.35,
		endRadius = 0.15,
	},
	{
		phase = 4,
		waitTime = 60,
		shrinkTime = 45,
		damage = 8,
		startRadius = 0.15,
		endRadius = 0.05,
	},
	{
		phase = 5,
		waitTime = 45,
		shrinkTime = 30,
		damage = 10,
		startRadius = 0.05,
		endRadius = 0.01,
	},
	{
		phase = 6,
		waitTime = 30,
		shrinkTime = 60,
		damage = 15,
		startRadius = 0.01,
		endRadius = 0, -- Closes completely
	},
}

-- State
local isInitialized = false
local isActive = false
local mapCenter = Vector3.zero
local mapRadius = 2000

local currentPhase = 0
local phaseState: "waiting" | "shrinking" | "complete" = "waiting"
local phaseTimer = 0

local currentCircle = {
	center = Vector3.zero,
	radius = 2000,
}

local nextCircle = {
	center = Vector3.zero,
	radius = 1200,
}

local shrinkStartCircle = {
	center = Vector3.zero,
	radius = 2000,
}

local damageTickTimer = 0
local DAMAGE_TICK_INTERVAL = 1 -- Apply damage every second

--[[
	Initialize the storm system
	@param center Map center position
	@param radius Map radius in studs
]]
function StormManager.Initialize(center: Vector3, radius: number)
	mapCenter = center
	mapRadius = radius

	currentCircle = {
		center = center,
		radius = radius,
	}

	nextCircle = {
		center = center,
		radius = radius,
	}

	currentPhase = 0
	phaseState = "waiting"
	phaseTimer = 0
	isActive = false
	isInitialized = true

	print(`[StormManager] Initialized with center {center} and radius {radius}`)
end

--[[
	Set the health manager reference (dependency injection)
]]
function StormManager.SetHealthManager(manager: any)
	HealthManager = manager
end

--[[
	Calculate next circle center
	Weighted toward map center, stays inside current circle
]]
local function calculateNextCircleCenter(currentCenter: Vector3, currentRadius: number, nextRadius: number): Vector3
	-- Weight toward map center
	local maxOffset = currentRadius - nextRadius - 50 -- Buffer to stay inside
	maxOffset = math.max(maxOffset, 0)

	-- Random angle
	local angle = math.random() * math.pi * 2

	-- Random distance (weighted toward center)
	local distanceFactor = math.random() ^ 2 -- Squared for center bias
	local distance = distanceFactor * maxOffset

	-- Calculate new center
	local offsetX = math.cos(angle) * distance
	local offsetZ = math.sin(angle) * distance

	local newCenter = Vector3.new(
		currentCenter.X + offsetX,
		currentCenter.Y,
		currentCenter.Z + offsetZ
	)

	-- Ensure it's inside current circle
	local distFromCurrent = (newCenter - currentCenter).Magnitude
	if distFromCurrent + nextRadius > currentRadius then
		-- Pull back toward current center
		local direction = (newCenter - currentCenter).Unit
		local maxDist = currentRadius - nextRadius - 10
		newCenter = currentCenter + direction * math.max(0, maxDist)
	end

	return newCenter
end

--[[
	Start a new storm phase
	@param phase Phase number (1-6)
]]
function StormManager.StartPhase(phase: number)
	if phase < 1 or phase > #STORM_PHASES then
		warn(`[StormManager] Invalid phase: {phase}`)
		return
	end

	local phaseConfig = STORM_PHASES[phase]
	currentPhase = phase
	phaseState = "waiting"
	phaseTimer = phaseConfig.waitTime
	isActive = true

	-- Calculate next circle
	local nextRadius = mapRadius * phaseConfig.endRadius
	local nextCenter = calculateNextCircleCenter(currentCircle.center, currentCircle.radius, nextRadius)

	nextCircle = {
		center = nextCenter,
		radius = nextRadius,
	}

	-- Save current as shrink start
	shrinkStartCircle = {
		center = currentCircle.center,
		radius = currentCircle.radius,
	}

	-- Broadcast update
	StormManager.BroadcastUpdate()

	print(`[StormManager] Phase {phase} started - wait {phaseConfig.waitTime}s, then shrink to radius {nextRadius}`)
end

--[[
	Update storm state
	@param dt Delta time
]]
function StormManager.Update(dt: number)
	if not isInitialized or not isActive then
		return
	end

	local phaseConfig = STORM_PHASES[currentPhase]
	if not phaseConfig then
		return
	end

	-- Update phase timer
	phaseTimer = phaseTimer - dt

	if phaseState == "waiting" then
		-- Waiting phase
		if phaseTimer <= 0 then
			-- Start shrinking
			phaseState = "shrinking"
			phaseTimer = phaseConfig.shrinkTime

			shrinkStartCircle = {
				center = currentCircle.center,
				radius = currentCircle.radius,
			}

			print(`[StormManager] Phase {currentPhase} shrinking for {phaseConfig.shrinkTime}s`)
		end
	elseif phaseState == "shrinking" then
		-- Shrinking phase - interpolate circle
		local progress = 1 - (phaseTimer / phaseConfig.shrinkTime)
		progress = math.clamp(progress, 0, 1)

		-- Smooth easing
		local easedProgress = progress -- Linear for now, could use easing function

		-- Interpolate center and radius
		currentCircle.center = shrinkStartCircle.center:Lerp(nextCircle.center, easedProgress)
		currentCircle.radius = shrinkStartCircle.radius + (nextCircle.radius - shrinkStartCircle.radius) * easedProgress

		if phaseTimer <= 0 then
			-- Shrink complete
			currentCircle = {
				center = nextCircle.center,
				radius = nextCircle.radius,
			}

			phaseState = "complete"

			-- Start next phase if available
			if currentPhase < #STORM_PHASES then
				StormManager.StartPhase(currentPhase + 1)
			else
				print("[StormManager] Final phase complete - storm fully closed")
			end
		end
	end

	-- Apply damage tick
	damageTickTimer = damageTickTimer - dt
	if damageTickTimer <= 0 then
		damageTickTimer = DAMAGE_TICK_INTERVAL
		StormManager.ApplyStormDamage(phaseConfig.damage)
		StormManager.BroadcastUpdate()
	end
end

--[[
	Apply storm damage to players outside safe zone
]]
function StormManager.ApplyStormDamage(damage: number)
	if not HealthManager then
		return
	end

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if not character then
			continue
		end

		local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not rootPart then
			continue
		end

		local position = rootPart.Position
		if not StormManager.IsInSafeZone(position) then
			-- Apply damage (bypasses shield)
			HealthManager.ApplyDamage(player, damage, "Storm", nil)
		end
	end
end

--[[
	Check if a position is inside the safe zone
	@param position World position to check
	@return Whether the position is safe
]]
function StormManager.IsInSafeZone(position: Vector3): boolean
	-- Check horizontal distance only (Y doesn't matter for circle)
	local horizontalPos = Vector3.new(position.X, currentCircle.center.Y, position.Z)
	local horizontalCenter = Vector3.new(currentCircle.center.X, currentCircle.center.Y, currentCircle.center.Z)
	local distance = (horizontalPos - horizontalCenter).Magnitude

	return distance <= currentCircle.radius
end

--[[
	Get current circle data
	@return Current circle center and radius
]]
function StormManager.GetCurrentCircle(): { center: Vector3, radius: number }
	return {
		center = currentCircle.center,
		radius = currentCircle.radius,
	}
end

--[[
	Get next circle data
	@return Next circle center and radius
]]
function StormManager.GetNextCircle(): { center: Vector3, radius: number }
	return {
		center = nextCircle.center,
		radius = nextCircle.radius,
	}
end

--[[
	Get time remaining in current phase state
	@return Phase name and seconds remaining
]]
function StormManager.GetTimeRemaining(): { phase: string, seconds: number }
	local phaseName = phaseState == "waiting" and "Safe" or "Shrinking"
	return {
		phase = phaseName,
		seconds = math.ceil(math.max(0, phaseTimer)),
	}
end

--[[
	Get current phase number
]]
function StormManager.GetCurrentPhase(): number
	return currentPhase
end

--[[
	Broadcast storm update to all clients
]]
function StormManager.BroadcastUpdate()
	local timeRemaining = StormManager.GetTimeRemaining()

	Events.FireAllClients("GameState", "StormUpdate", {
		phase = currentPhase,
		phaseState = phaseState,
		center = currentCircle.center,
		radius = currentCircle.radius,
		nextCenter = nextCircle.center,
		nextRadius = nextCircle.radius,
		timeRemaining = timeRemaining.seconds,
		timePhase = timeRemaining.phase,
	})
end

--[[
	Reset storm state
]]
function StormManager.Reset()
	currentPhase = 0
	phaseState = "waiting"
	phaseTimer = 0
	isActive = false
	damageTickTimer = 0

	currentCircle = {
		center = mapCenter,
		radius = mapRadius,
	}

	nextCircle = {
		center = mapCenter,
		radius = mapRadius,
	}

	print("[StormManager] Reset")
end

--[[
	Get phase configuration
]]
function StormManager.GetPhaseConfig(phase: number): { [string]: any }?
	if phase < 1 or phase > #STORM_PHASES then
		return nil
	end
	return STORM_PHASES[phase]
end

--[[
	Check if storm is active
]]
function StormManager.IsActive(): boolean
	return isActive
end

return StormManager
