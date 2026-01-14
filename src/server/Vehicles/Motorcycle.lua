--!strict
--[[
	Motorcycle.lua
	==============
	Fast single-rider vehicle
	Highest speed, extremely agile
	Very fragile, rider exposed to attacks
]]

local VehicleBase = require(script.Parent.VehicleBase)
local Events = require(game.ReplicatedStorage.Shared.Events)

local Motorcycle = {}
Motorcycle.__index = Motorcycle
setmetatable(Motorcycle, { __index = VehicleBase })

-- Motorcycle-specific stats
local MOTO_MAX_SPEED = 80
local MOTO_ACCELERATION = 30
local MOTO_DECELERATION = 40
local MOTO_TURN_SPEED = 4.5
local MOTO_HEALTH = 200
local MOTO_SEAT_COUNT = 1

-- Special abilities
local NITRO_BOOST_SPEED = 1.5 -- 50% speed increase
local NITRO_DURATION = 3
local NITRO_COOLDOWN = 20
local WHEELIE_BONUS_ACCEL = 1.3

-- Leaning settings
local MAX_LEAN_ANGLE = 35 -- Degrees
local LEAN_SPEED = 8

--[[
	Create a new Motorcycle
	@param vehicleType Type (should be "Motorcycle")
	@param position Spawn CFrame
	@return Motorcycle instance
]]
function Motorcycle.new(vehicleType: string, position: CFrame): VehicleBase.VehicleInstance
	local self = setmetatable(VehicleBase.new("Motorcycle", position), Motorcycle) :: any

	-- Override stats
	self.stats.maxSpeed = MOTO_MAX_SPEED
	self.stats.acceleration = MOTO_ACCELERATION
	self.stats.deceleration = MOTO_DECELERATION
	self.stats.turnSpeed = MOTO_TURN_SPEED
	self.stats.health = MOTO_HEALTH
	self.stats.maxHealth = MOTO_HEALTH
	self.stats.seatCount = MOTO_SEAT_COUNT

	-- Motorcycle-specific state
	self.leanAngle = 0
	self.isWheeling = false
	self.wheelieTimer = 0
	self.nitroActive = false
	self.nitroCooldown = 0
	self.isGrounded = true

	return self
end

--[[
	Override: Rider cannot shoot while driving
]]
function Motorcycle:CanShootFromSeat(player: Player): boolean
	return false -- Can't shoot while driving motorcycle
end

--[[
	Activate nitro boost
]]
function Motorcycle:ActivateNitro()
	if self.nitroActive or self.nitroCooldown > 0 then
		return
	end

	self.nitroActive = true

	-- Store original max speed
	local originalMaxSpeed = MOTO_MAX_SPEED

	-- Apply boost
	self.stats.maxSpeed = originalMaxSpeed * NITRO_BOOST_SPEED

	Events.FireAllClients("Vehicle", "MotorcycleNitro", {
		vehicleId = self.id,
		position = self.position,
		active = true,
	})

	-- End nitro after duration
	task.delay(NITRO_DURATION, function()
		self.nitroActive = false
		self.nitroCooldown = NITRO_COOLDOWN
		self.stats.maxSpeed = originalMaxSpeed

		Events.FireAllClients("Vehicle", "MotorcycleNitro", {
			vehicleId = self.id,
			active = false,
		})
	end)
end

--[[
	Override: Apply motorcycle physics
]]
function Motorcycle:ApplyInput(dt: number, input: VehicleBase.VehicleInput)
	-- Update grounded state
	self:UpdateGroundedState()

	-- Update nitro cooldown
	if self.nitroCooldown > 0 then
		self.nitroCooldown = self.nitroCooldown - dt
	end

	-- Nitro activation (handbrake/shift)
	if input.handbrake and not self.nitroActive and self.nitroCooldown <= 0 then
		self:ActivateNitro()
	end

	-- Wheelie when accelerating hard
	if input.throttle > 0.9 and self.currentSpeed > 30 and self.isGrounded then
		self.isWheeling = true
		self.wheelieTimer = self.wheelieTimer + dt
	else
		if self.isWheeling then
			self:EndWheelie()
		end
		self.isWheeling = false
		self.wheelieTimer = 0
	end

	-- Apply wheelie acceleration bonus
	local accelMod = 1.0
	if self.isWheeling then
		accelMod = WHEELIE_BONUS_ACCEL
	end

	local originalAccel = self.stats.acceleration
	self.stats.acceleration = originalAccel * accelMod

	-- Calculate lean angle based on steering and speed
	self:UpdateLean(dt, input.steer)

	-- Call base input
	VehicleBase.ApplyInput(self, dt, input)

	-- Restore acceleration
	self.stats.acceleration = originalAccel

	-- High-speed handling bonus
	if self.currentSpeed > 60 then
		-- Better turning at high speed (counter-steering effect)
		local speedBonus = (self.currentSpeed - 60) / 20
		self.stats.turnSpeed = MOTO_TURN_SPEED * (1 + speedBonus * 0.5)
	else
		self.stats.turnSpeed = MOTO_TURN_SPEED
	end
end

--[[
	Update grounded state
]]
function Motorcycle:UpdateGroundedState()
	local raycastParams = RaycastParams.new()
	if self.model then
		raycastParams.FilterDescendantsInstances = { self.model }
	end
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local result = workspace:Raycast(self.position, Vector3.new(0, -2, 0), raycastParams)
	self.isGrounded = result ~= nil
end

--[[
	Update lean angle
]]
function Motorcycle:UpdateLean(dt: number, steerInput: number)
	-- Target lean based on steering and speed
	local speedFactor = math.clamp(self.currentSpeed / MOTO_MAX_SPEED, 0, 1)
	local targetLean = -steerInput * MAX_LEAN_ANGLE * speedFactor

	-- Smooth lean transition
	self.leanAngle = self.leanAngle + (targetLean - self.leanAngle) * LEAN_SPEED * dt

	-- Broadcast lean for visuals
	Events.FireAllClients("Vehicle", "MotorcycleLean", {
		vehicleId = self.id,
		leanAngle = self.leanAngle,
	})
end

--[[
	End wheelie
]]
function Motorcycle:EndWheelie()
	if self.wheelieTimer > 1 then
		-- Style points!
		Events.FireAllClients("Vehicle", "MotorcycleWheelie", {
			vehicleId = self.id,
			duration = self.wheelieTimer,
		})
	end
end

--[[
	Override: Update model with lean
]]
function Motorcycle:UpdateModelPosition(dt: number)
	if not self.model or not self.model.PrimaryPart then
		return
	end

	-- Calculate movement
	local forward = self.rotation.LookVector
	local movement = forward * self.currentSpeed * dt
	self.position = self.position + movement

	-- Apply lean rotation
	local leanRadians = math.rad(self.leanAngle)
	local wheelieAngle = 0
	if self.isWheeling then
		wheelieAngle = math.min(self.wheelieTimer * 0.3, 0.4) -- Max ~23 degree wheelie
	end

	local targetCFrame = CFrame.new(self.position) * self.rotation.Rotation * CFrame.Angles(wheelieAngle, 0, leanRadians)
	self.model:SetPrimaryPartCFrame(targetCFrame)
end

--[[
	Override: Take extra damage (exposed rider)
]]
function Motorcycle:TakeDamage(amount: number, source: string)
	-- Motorcycle takes more damage from collisions
	if source == "Collision" or source == "Impact" then
		amount = amount * 1.5
	end

	VehicleBase.TakeDamage(self, amount, source)

	-- Damage rider directly for some damage types
	if self.driver and (source == "Dinosaur" or source == "Bullet") then
		local character = self.driver.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				-- Rider takes partial damage
				humanoid:TakeDamage(amount * 0.3)
			end
		end
	end
end

--[[
	Stunt detection
]]
function Motorcycle:CheckStunt(previousPosition: Vector3, dt: number)
	-- Detect air time
	if not self.isGrounded then
		-- Track air time for stunt scoring
		local airTime = self.airTime or 0
		self.airTime = airTime + dt
	else
		if self.airTime and self.airTime > 0.5 then
			-- Landed after a jump
			Events.FireAllClients("Vehicle", "MotorcycleStunt", {
				vehicleId = self.id,
				stuntType = "Jump",
				airTime = self.airTime,
			})
		end
		self.airTime = 0
	end
end

--[[
	Override: Serialize with motorcycle data
]]
function Motorcycle:Serialize(): { [string]: any }
	local data = VehicleBase.Serialize(self)

	data.leanAngle = self.leanAngle
	data.isWheeling = self.isWheeling
	data.nitroActive = self.nitroActive
	data.nitroCooldown = self.nitroCooldown

	return data
end

return Motorcycle
