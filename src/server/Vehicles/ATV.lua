--!strict
--[[
	ATV.lua
	=======
	Fast all-terrain vehicle (quad bike)
	Seats 2, high speed, nimble handling
	Low durability but great for quick escapes
]]

local VehicleBase = require(script.Parent.VehicleBase)
local Events = require(game.ReplicatedStorage.Shared.Events)

local ATV = {}
ATV.__index = ATV
setmetatable(ATV, { __index = VehicleBase })

-- ATV-specific stats
local ATV_MAX_SPEED = 70
local ATV_ACCELERATION = 25
local ATV_DECELERATION = 35
local ATV_TURN_SPEED = 3.5
local ATV_HEALTH = 400
local ATV_SEAT_COUNT = 2

-- Trick settings
local WHEELIE_SPEED_BOOST = 1.2
local WHEELIE_MIN_SPEED = 30
local JUMP_BOOST_FORCE = 50

--[[
	Create a new ATV
	@param vehicleType Type (should be "ATV")
	@param position Spawn CFrame
	@return ATV instance
]]
function ATV.new(vehicleType: string, position: CFrame): VehicleBase.VehicleInstance
	local self = setmetatable(VehicleBase.new("ATV", position), ATV) :: any

	-- Override stats
	self.stats.maxSpeed = ATV_MAX_SPEED
	self.stats.acceleration = ATV_ACCELERATION
	self.stats.deceleration = ATV_DECELERATION
	self.stats.turnSpeed = ATV_TURN_SPEED
	self.stats.health = ATV_HEALTH
	self.stats.maxHealth = ATV_HEALTH
	self.stats.seatCount = ATV_SEAT_COUNT

	-- ATV-specific state
	self.isWheeling = false
	self.wheelieTimer = 0
	self.airTime = 0
	self.isGrounded = true
	self.driftAngle = 0

	return self
end

--[[
	Override: Passenger can shoot while riding
]]
function ATV:CanShootFromSeat(player: Player): boolean
	-- Passenger seat can shoot
	return self.seats[2] == player
end

--[[
	Override: Apply input with wheelie/drift mechanics
]]
function ATV:ApplyInput(dt: number, input: VehicleBase.VehicleInput)
	-- Check if grounded
	self:UpdateGroundedState()

	-- Wheelie when accelerating hard at high speed
	if input.throttle > 0.8 and self.currentSpeed > WHEELIE_MIN_SPEED and self.isGrounded then
		if not self.isWheeling then
			self:StartWheelie()
		end
		self.wheelieTimer = self.wheelieTimer + dt
	else
		if self.isWheeling then
			self:EndWheelie()
		end
		self.wheelieTimer = 0
	end

	-- Apply wheelie speed boost
	local speedMod = 1.0
	if self.isWheeling then
		speedMod = WHEELIE_SPEED_BOOST
	end

	-- Drift when handbraking while turning
	if input.handbrake and math.abs(input.steer) > 0.5 and self.currentSpeed > 20 then
		self:ApplyDrift(dt, input.steer)
	else
		-- Reduce drift angle
		self.driftAngle = self.driftAngle * (1 - dt * 5)
	end

	-- Modify max speed temporarily
	local originalMaxSpeed = self.stats.maxSpeed
	self.stats.maxSpeed = originalMaxSpeed * speedMod

	-- Call base input
	VehicleBase.ApplyInput(self, dt, input)

	-- Restore max speed
	self.stats.maxSpeed = originalMaxSpeed

	-- Track air time
	if not self.isGrounded then
		self.airTime = self.airTime + dt
	else
		if self.airTime > 0.5 then
			-- Landed after significant air time
			self:OnLanded(self.airTime)
		end
		self.airTime = 0
	end
end

--[[
	Update grounded state
]]
function ATV:UpdateGroundedState()
	local raycastParams = RaycastParams.new()
	if self.model then
		raycastParams.FilterDescendantsInstances = { self.model }
	end
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local result = workspace:Raycast(self.position, Vector3.new(0, -3, 0), raycastParams)
	self.isGrounded = result ~= nil
end

--[[
	Start wheelie
]]
function ATV:StartWheelie()
	self.isWheeling = true

	Events.FireAllClients("Vehicle", "ATVWheelie", {
		vehicleId = self.id,
		started = true,
	})
end

--[[
	End wheelie
]]
function ATV:EndWheelie()
	self.isWheeling = false

	Events.FireAllClients("Vehicle", "ATVWheelie", {
		vehicleId = self.id,
		started = false,
		duration = self.wheelieTimer,
	})
end

--[[
	Apply drift physics
]]
function ATV:ApplyDrift(dt: number, steerInput: number)
	-- Increase drift angle
	local targetDrift = steerInput * 45 -- Max 45 degree drift
	self.driftAngle = self.driftAngle + (targetDrift - self.driftAngle) * dt * 3

	-- Apply lateral movement
	local driftRadians = math.rad(self.driftAngle)
	local lateralDir = self.rotation:VectorToWorldSpace(Vector3.new(math.sin(driftRadians), 0, 0))

	-- Slide sideways
	self.position = self.position + lateralDir * math.abs(self.currentSpeed) * dt * 0.3

	-- Broadcast drift for effects
	Events.FireAllClients("Vehicle", "ATVDrift", {
		vehicleId = self.id,
		driftAngle = self.driftAngle,
		position = self.position,
	})
end

--[[
	Handle landing after jump
]]
function ATV:OnLanded(airTime: number)
	-- Award style points or apply landing effects
	Events.FireAllClients("Vehicle", "ATVLanded", {
		vehicleId = self.id,
		airTime = airTime,
		position = self.position,
	})

	-- Hard landing damage
	if airTime > 2.0 then
		local damage = (airTime - 2.0) * 50
		self:TakeDamage(damage, "HardLanding")
	end
end

--[[
	Perform jump boost (when going off ramp)
]]
function ATV:ApplyJumpBoost()
	if not self.model or not self.model.PrimaryPart then
		return
	end

	-- Add upward velocity
	self.model.PrimaryPart.AssemblyLinearVelocity = self.model.PrimaryPart.AssemblyLinearVelocity + Vector3.new(0, JUMP_BOOST_FORCE, 0)

	Events.FireAllClients("Vehicle", "ATVJump", {
		vehicleId = self.id,
		position = self.position,
	})
end

--[[
	Override: Nimble turning at all speeds
]]
function ATV:Update(dt: number, input: VehicleBase.VehicleInput?)
	-- ATVs can turn even when stationary (pivot)
	if input and math.abs(self.currentSpeed) < 5 then
		local pivotSpeed = self.stats.turnSpeed * 0.3
		self.rotation = self.rotation * CFrame.Angles(0, -input.steer * pivotSpeed * dt, 0)
	end

	-- Call base update
	VehicleBase.Update(self, dt, input)
end

--[[
	Override: Serialize with ATV data
]]
function ATV:Serialize(): { [string]: any }
	local data = VehicleBase.Serialize(self)

	data.isWheeling = self.isWheeling
	data.isGrounded = self.isGrounded
	data.driftAngle = self.driftAngle

	return data
end

return ATV
