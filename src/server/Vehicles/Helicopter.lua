--!strict
--[[
	Helicopter.lua
	==============
	Flying vehicle for aerial traversal
	Seats 4, high speed, vulnerable
	Uses fuel, attracts dinosaur attention
]]

local VehicleBase = require(script.Parent.VehicleBase)
local Events = require(game.ReplicatedStorage.Shared.Events)

local Helicopter = {}
Helicopter.__index = Helicopter
setmetatable(Helicopter, { __index = VehicleBase })

-- Helicopter-specific stats
local HELI_MAX_SPEED = 65
local HELI_VERTICAL_SPEED = 25
local HELI_ACCELERATION = 20
local HELI_TURN_SPEED = 2.5
local HELI_HEALTH = 500
local HELI_SEAT_COUNT = 4

-- Fuel settings
local HELI_MAX_FUEL = 180 -- 3 minutes
local FUEL_CONSUMPTION_RATE = 1 -- Per second when flying
local FUEL_CONSUMPTION_BOOST = 2 -- When boosting

-- Flight settings
local MIN_ALTITUDE = 10
local MAX_ALTITUDE = 200
local ROTOR_WARMUP_TIME = 2
local AUTO_DESCEND_RATE = 10 -- When out of fuel

-- Noise settings
local HELICOPTER_NOISE_RADIUS = 150 -- Attracts dinos from this range

--[[
	Create a new Helicopter
	@param vehicleType Type (should be "Helicopter")
	@param position Spawn CFrame
	@return Helicopter instance
]]
function Helicopter.new(vehicleType: string, position: CFrame): VehicleBase.VehicleInstance
	local self = setmetatable(VehicleBase.new("Helicopter", position), Helicopter) :: any

	-- Override stats
	self.stats.maxSpeed = HELI_MAX_SPEED
	self.stats.acceleration = HELI_ACCELERATION
	self.stats.turnSpeed = HELI_TURN_SPEED
	self.stats.health = HELI_HEALTH
	self.stats.maxHealth = HELI_HEALTH
	self.stats.seatCount = HELI_SEAT_COUNT

	-- Fuel (already set in VehicleBase for helicopters, but ensure it)
	self.fuel = HELI_MAX_FUEL
	self.maxFuel = HELI_MAX_FUEL

	-- Helicopter-specific state
	self.altitude = position.Position.Y
	self.targetAltitude = position.Position.Y
	self.isEngineOn = false
	self.rotorSpeed = 0 -- 0-1
	self.isWarningUp = false
	self.warmupTimer = 0
	self.verticalVelocity = 0

	return self
end

--[[
	Override: Side gunners can shoot
]]
function Helicopter:CanShootFromSeat(player: Player): boolean
	-- Seats 2 and 3 are side gunners
	for seatIndex, occupant in pairs(self.seats) do
		if occupant == player then
			return seatIndex == 2 or seatIndex == 3
		end
	end
	return false
end

--[[
	Start engine
]]
function Helicopter:StartEngine()
	if self.isEngineOn or self.isWarningUp then
		return
	end

	self.isWarningUp = true
	self.warmupTimer = 0

	Events.FireAllClients("Vehicle", "HelicopterStartup", {
		vehicleId = self.id,
		position = self.position,
	})
end

--[[
	Stop engine
]]
function Helicopter:StopEngine()
	self.isEngineOn = false
	self.isWarningUp = false

	Events.FireAllClients("Vehicle", "HelicopterShutdown", {
		vehicleId = self.id,
		position = self.position,
	})
end

--[[
	Override: Apply helicopter flight controls
]]
function Helicopter:ApplyInput(dt: number, input: VehicleBase.VehicleInput)
	-- Handle engine warmup
	if self.isWarningUp then
		self.warmupTimer = self.warmupTimer + dt
		self.rotorSpeed = math.min(1, self.warmupTimer / ROTOR_WARMUP_TIME)

		if self.warmupTimer >= ROTOR_WARMUP_TIME then
			self.isWarningUp = false
			self.isEngineOn = true
		end
		return -- Can't control during warmup
	end

	if not self.isEngineOn then
		-- Start engine on first input
		if input.throttle ~= 0 or input.altitude ~= nil then
			self:StartEngine()
		end
		return
	end

	-- Check fuel
	if self.fuel <= 0 then
		self:HandleOutOfFuel(dt)
		return
	end

	-- Consume fuel
	local consumption = FUEL_CONSUMPTION_RATE
	if input.handbrake then -- Boost
		consumption = FUEL_CONSUMPTION_BOOST
	end
	self.fuel = math.max(0, self.fuel - consumption * dt)

	-- Horizontal movement (WASD)
	if input.throttle ~= 0 then
		local accel = self.stats.acceleration * input.throttle
		self.currentSpeed = math.clamp(
			self.currentSpeed + accel * dt,
			-self.stats.maxSpeed * 0.5,
			self.stats.maxSpeed
		)
	else
		-- Air drag
		self.currentSpeed = self.currentSpeed * (1 - dt * 2)
	end

	-- Turning (A/D)
	if input.steer ~= 0 then
		local turnAmount = input.steer * self.stats.turnSpeed * dt
		self.rotation = self.rotation * CFrame.Angles(0, -turnAmount, 0)
	end

	-- Altitude control (Q/E or dedicated altitude input)
	local altitudeChange = input.altitude or 0
	if altitudeChange ~= 0 then
		self.verticalVelocity = altitudeChange * HELI_VERTICAL_SPEED
	else
		-- Maintain altitude (hover)
		self.verticalVelocity = self.verticalVelocity * (1 - dt * 5)
	end

	-- Apply altitude
	local newAltitude = self.altitude + self.verticalVelocity * dt
	self.altitude = math.clamp(newAltitude, MIN_ALTITUDE, MAX_ALTITUDE)

	-- Generate noise to attract dinosaurs
	self:GenerateNoise()
end

--[[
	Handle out of fuel state
]]
function Helicopter:HandleOutOfFuel(dt: number)
	-- Engine dies
	self.rotorSpeed = math.max(0, self.rotorSpeed - dt * 0.3)

	-- Auto-descend
	self.altitude = math.max(0, self.altitude - AUTO_DESCEND_RATE * dt)
	self.currentSpeed = self.currentSpeed * (1 - dt * 0.5)

	-- Warn driver
	if self.driver then
		Events.FireClient(self.driver, "Vehicle", "FuelEmpty", {
			vehicleId = self.id,
		})
	end

	-- Crash if we hit ground
	if self.altitude <= 2 then
		self:Crash()
	end
end

--[[
	Crash the helicopter
]]
function Helicopter:Crash()
	-- Deal damage based on descent speed
	local crashDamage = math.abs(self.verticalVelocity) * 10 + 100
	self:TakeDamage(crashDamage, "Crash")

	-- Damage passengers
	for _, player in pairs(self:GetOccupants()) do
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:TakeDamage(50) -- Crash damage to passengers
			end
		end
	end

	Events.FireAllClients("Vehicle", "HelicopterCrash", {
		vehicleId = self.id,
		position = self.position,
	})
end

--[[
	Generate noise to attract dinosaurs
]]
function Helicopter:GenerateNoise()
	-- Broadcast noise event every few seconds
	if math.random() < 0.05 then -- ~5% chance per frame
		Events.FireAllClients("AI", "LoudNoise", {
			position = self.position,
			radius = HELICOPTER_NOISE_RADIUS,
			source = "Helicopter",
			vehicleId = self.id,
		})
	end
end

--[[
	Override: Update model position with altitude
]]
function Helicopter:UpdateModelPosition(dt: number)
	if not self.model or not self.model.PrimaryPart then
		return
	end

	-- Calculate new position (horizontal + altitude)
	local forward = self.rotation.LookVector
	local horizontalMovement = forward * self.currentSpeed * dt

	-- Update position with altitude
	self.position = Vector3.new(
		self.position.X + horizontalMovement.X,
		self.altitude,
		self.position.Z + horizontalMovement.Z
	)

	-- Calculate tilt based on movement
	local pitchAngle = -self.currentSpeed / self.stats.maxSpeed * 0.15
	local rollAngle = 0 -- Could add roll on turns

	local targetCFrame = CFrame.new(self.position) * self.rotation.Rotation * CFrame.Angles(pitchAngle, 0, rollAngle)
	self.model:SetPrimaryPartCFrame(targetCFrame)
end

--[[
	Override: Update with flight physics
]]
function Helicopter:Update(dt: number, input: VehicleBase.VehicleInput?)
	-- Update rotor animation
	if self.rotorSpeed > 0 then
		-- Broadcast rotor state for client animation
		Events.FireAllClients("Vehicle", "HelicopterRotor", {
			vehicleId = self.id,
			rotorSpeed = self.rotorSpeed,
		})
	end

	-- Call base update
	VehicleBase.Update(self, dt, input)
end

--[[
	Override: Serialize with helicopter data
]]
function Helicopter:Serialize(): { [string]: any }
	local data = VehicleBase.Serialize(self)

	data.altitude = self.altitude
	data.isEngineOn = self.isEngineOn
	data.rotorSpeed = self.rotorSpeed
	data.verticalVelocity = self.verticalVelocity

	return data
end

return Helicopter
