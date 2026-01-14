--!strict
--[[
	Boat.lua
	========
	Water vehicle for crossing rivers and lakes
	Seats 4, fast on water, useless on land
	Can outrun aquatic dinosaurs
]]

local VehicleBase = require(script.Parent.VehicleBase)
local Events = require(game.ReplicatedStorage.Shared.Events)

local Boat = {}
Boat.__index = Boat
setmetatable(Boat, { __index = VehicleBase })

-- Boat-specific stats
local BOAT_MAX_SPEED = 50
local BOAT_ACCELERATION = 15
local BOAT_DECELERATION = 10
local BOAT_TURN_SPEED = 1.8
local BOAT_HEALTH = 600
local BOAT_SEAT_COUNT = 4

-- Water settings
local WATER_LEVEL = 0 -- Y coordinate of water surface
local WAVE_AMPLITUDE = 1.5
local WAVE_FREQUENCY = 0.5
local BEACHING_DAMAGE_RATE = 20 -- Damage per second when beached

--[[
	Create a new Boat
	@param vehicleType Type (should be "Boat")
	@param position Spawn CFrame
	@return Boat instance
]]
function Boat.new(vehicleType: string, position: CFrame): VehicleBase.VehicleInstance
	local self = setmetatable(VehicleBase.new("Boat", position), Boat) :: any

	-- Override stats
	self.stats.maxSpeed = BOAT_MAX_SPEED
	self.stats.acceleration = BOAT_ACCELERATION
	self.stats.deceleration = BOAT_DECELERATION
	self.stats.turnSpeed = BOAT_TURN_SPEED
	self.stats.health = BOAT_HEALTH
	self.stats.maxHealth = BOAT_HEALTH
	self.stats.seatCount = BOAT_SEAT_COUNT

	-- Boat-specific state
	self.isInWater = false
	self.isBeached = false
	self.waveOffset = math.random() * math.pi * 2 -- Random wave phase
	self.waterLevel = WATER_LEVEL
	self.boostActive = false
	self.boostCooldown = 0

	return self
end

--[[
	Override: All passengers can shoot from boat
]]
function Boat:CanShootFromSeat(player: Player): boolean
	-- Everyone except driver can shoot
	return self.driver ~= player
end

--[[
	Override: Apply water-based physics
]]
function Boat:ApplyInput(dt: number, input: VehicleBase.VehicleInput)
	-- Check water state
	self:UpdateWaterState()

	if not self.isInWater then
		-- Beached - severely limit controls
		if self.isBeached then
			self:HandleBeaching(dt)
		end
		return
	end

	-- Normal water controls
	VehicleBase.ApplyInput(self, dt, input)

	-- Apply wave motion
	self:ApplyWaveMotion(dt)

	-- Speed boost (shift)
	if input.handbrake and self.boostCooldown <= 0 then
		self:ActivateBoost()
	end

	-- Update boost cooldown
	if self.boostCooldown > 0 then
		self.boostCooldown = self.boostCooldown - dt
	end
end

--[[
	Update water detection
]]
function Boat:UpdateWaterState()
	-- Check if position is at/below water level
	-- In a real implementation, you'd check against Terrain water
	local wasInWater = self.isInWater

	-- Simplified water check - assume water at Y=0
	self.isInWater = self.position.Y <= self.waterLevel + 5

	-- Check for beaching (shallow water or land)
	local raycastParams = RaycastParams.new()
	if self.model then
		raycastParams.FilterDescendantsInstances = { self.model }
	end
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local result = workspace:Raycast(self.position, Vector3.new(0, -10, 0), raycastParams)

	if result then
		-- Check if ground is above water
		if result.Position.Y > self.waterLevel - 2 then
			self.isBeached = true
			self.isInWater = false
		else
			self.isBeached = false
		end
	end

	-- Transition events
	if wasInWater and not self.isInWater then
		Events.FireAllClients("Vehicle", "BoatExitWater", {
			vehicleId = self.id,
			position = self.position,
		})
	elseif not wasInWater and self.isInWater then
		Events.FireAllClients("Vehicle", "BoatEnterWater", {
			vehicleId = self.id,
			position = self.position,
		})
	end
end

--[[
	Handle beaching damage
]]
function Boat:HandleBeaching(dt: number)
	-- Slowly damage boat when beached
	self:TakeDamage(BEACHING_DAMAGE_RATE * dt, "Beached")

	-- Drastically reduce speed
	self.currentSpeed = self.currentSpeed * 0.9

	-- Broadcast warning
	if self.driver then
		Events.FireClient(self.driver, "Vehicle", "BeachingWarning", {
			vehicleId = self.id,
			damage = BEACHING_DAMAGE_RATE,
		})
	end
end

--[[
	Apply wave motion for realistic movement
]]
function Boat:ApplyWaveMotion(dt: number)
	local time = tick()

	-- Calculate wave offset
	local waveY = math.sin(time * WAVE_FREQUENCY + self.waveOffset) * WAVE_AMPLITUDE

	-- Apply to position (keep at water level with wave offset)
	local targetY = self.waterLevel + 2 + waveY -- 2 studs above water
	self.position = Vector3.new(self.position.X, targetY, self.position.Z)

	-- Apply slight roll based on wave
	local rollAngle = math.sin(time * WAVE_FREQUENCY * 0.7 + self.waveOffset + 1) * 0.05
	self.rotation = self.rotation * CFrame.Angles(0, 0, rollAngle)
end

--[[
	Activate speed boost
]]
function Boat:ActivateBoost()
	self.boostActive = true
	self.boostCooldown = 15 -- 15 second cooldown

	-- Temporary speed increase
	local boostDuration = 3
	local originalMaxSpeed = self.stats.maxSpeed

	self.stats.maxSpeed = originalMaxSpeed * 1.5 -- 50% boost

	Events.FireAllClients("Vehicle", "BoatBoost", {
		vehicleId = self.id,
		position = self.position,
	})

	-- Reset after duration
	task.delay(boostDuration, function()
		self.stats.maxSpeed = originalMaxSpeed
		self.boostActive = false
	end)
end

--[[
	Override: Update with water physics
]]
function Boat:Update(dt: number, input: VehicleBase.VehicleInput?)
	-- Always update water state
	self:UpdateWaterState()

	-- Only update normally if in water
	if self.isInWater and not self.isBeached then
		VehicleBase.Update(self, dt, input)
		self:ApplyWaveMotion(dt)
	elseif self.isBeached then
		-- Minimal movement when beached
		self.currentSpeed = self.currentSpeed * (1 - dt * 2)
		self:HandleBeaching(dt)
	end

	-- Create wake effect at speed
	if self.isInWater and math.abs(self.currentSpeed) > 10 then
		self:CreateWakeEffect()
	end
end

--[[
	Create wake/splash effects
]]
function Boat:CreateWakeEffect()
	-- Broadcast wake for client-side effects
	Events.FireAllClients("Vehicle", "BoatWake", {
		vehicleId = self.id,
		position = self.position,
		speed = self.currentSpeed,
		direction = self.rotation.LookVector,
	})
end

--[[
	Override: Serialize with boat data
]]
function Boat:Serialize(): { [string]: any }
	local data = VehicleBase.Serialize(self)

	data.isInWater = self.isInWater
	data.isBeached = self.isBeached
	data.boostActive = self.boostActive
	data.boostCooldown = self.boostCooldown

	return data
end

return Boat
