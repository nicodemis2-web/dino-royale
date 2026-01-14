--!strict
--[[
	Jeep.lua
	========
	All-terrain military jeep
	Seats 4, moderate speed, good durability
	Can mount a turret for passengers
]]

local VehicleBase = require(script.Parent.VehicleBase)
local Events = require(game.ReplicatedStorage.Shared.Events)

local Jeep = {}
Jeep.__index = Jeep
setmetatable(Jeep, { __index = VehicleBase })

-- Jeep-specific stats
local JEEP_MAX_SPEED = 55
local JEEP_ACCELERATION = 18
local JEEP_TURN_SPEED = 2.2
local JEEP_HEALTH = 1000
local JEEP_SEAT_COUNT = 4

-- Turret settings
local TURRET_DAMAGE = 15
local TURRET_FIRE_RATE = 0.15 -- Seconds between shots
local TURRET_RANGE = 150
local TURRET_AMMO = 200

--[[
	Create a new Jeep
	@param position Spawn CFrame
	@return Jeep instance
]]
function Jeep.new(vehicleType: string, position: CFrame): VehicleBase.VehicleInstance
	local self = setmetatable(VehicleBase.new("Jeep", position), Jeep) :: any

	-- Override stats
	self.stats.maxSpeed = JEEP_MAX_SPEED
	self.stats.acceleration = JEEP_ACCELERATION
	self.stats.turnSpeed = JEEP_TURN_SPEED
	self.stats.health = JEEP_HEALTH
	self.stats.maxHealth = JEEP_HEALTH
	self.stats.seatCount = JEEP_SEAT_COUNT

	-- Jeep-specific state
	self.turretAmmo = TURRET_AMMO
	self.maxTurretAmmo = TURRET_AMMO
	self.lastTurretFire = 0
	self.turretRotation = 0 -- Yaw angle

	return self
end

--[[
	Override: Passengers in seat 2 (turret) can shoot mounted gun
]]
function Jeep:CanShootFromSeat(player: Player): boolean
	-- Check if player is in turret seat (seat 2)
	for seatIndex, occupant in pairs(self.seats) do
		if occupant == player then
			return seatIndex == 2 -- Turret seat
		end
	end
	return false
end

--[[
	Fire turret weapon
	@param player Player firing
	@param targetPosition World position to fire at
]]
function Jeep:FireTurret(player: Player, targetPosition: Vector3)
	-- Verify player is in turret seat
	if self.seats[2] ~= player then
		return
	end

	-- Check ammo
	if self.turretAmmo <= 0 then
		return
	end

	-- Check fire rate
	local now = tick()
	if now - self.lastTurretFire < TURRET_FIRE_RATE then
		return
	end

	self.lastTurretFire = now
	self.turretAmmo = self.turretAmmo - 1

	-- Calculate direction
	local turretPosition = self.position + Vector3.new(0, 3, 0) -- Turret height
	local direction = (targetPosition - turretPosition).Unit
	local distance = (targetPosition - turretPosition).Magnitude

	if distance > TURRET_RANGE then
		-- Cap at max range
		targetPosition = turretPosition + direction * TURRET_RANGE
	end

	-- Raycast for hit
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = { self.model }
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local result = workspace:Raycast(turretPosition, direction * TURRET_RANGE, raycastParams)

	-- Broadcast fire event (for visuals)
	Events.FireAllClients("Vehicle", "TurretFire", {
		vehicleId = self.id,
		origin = turretPosition,
		direction = direction,
		hitPosition = result and result.Position or (turretPosition + direction * TURRET_RANGE),
	})

	-- Apply damage if hit
	if result then
		local hitPart = result.Instance
		local hitModel = hitPart:FindFirstAncestorOfClass("Model")

		if hitModel then
			local humanoid = hitModel:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:TakeDamage(TURRET_DAMAGE)
			end
		end
	end
end

--[[
	Rotate turret
	@param yawDelta Rotation amount
]]
function Jeep:RotateTurret(yawDelta: number)
	self.turretRotation = self.turretRotation + yawDelta
	-- Keep in range
	self.turretRotation = self.turretRotation % (math.pi * 2)
end

--[[
	Get turret world direction
]]
function Jeep:GetTurretDirection(): Vector3
	local vehicleForward = self.rotation.LookVector
	local turretAngle = CFrame.Angles(0, self.turretRotation, 0)
	return (turretAngle * CFrame.new(vehicleForward)).LookVector
end

--[[
	Override: Apply terrain effects
]]
function Jeep:ApplyInput(dt: number, input: VehicleBase.VehicleInput)
	-- Check terrain type under vehicle
	local terrainMod = self:GetTerrainModifier()

	-- Temporarily modify stats based on terrain
	local originalAccel = self.stats.acceleration
	local originalMaxSpeed = self.stats.maxSpeed

	self.stats.acceleration = originalAccel * terrainMod
	self.stats.maxSpeed = originalMaxSpeed * terrainMod

	-- Call base input
	VehicleBase.ApplyInput(self, dt, input)

	-- Restore stats
	self.stats.acceleration = originalAccel
	self.stats.maxSpeed = originalMaxSpeed
end

--[[
	Get terrain modifier for current position
]]
function Jeep:GetTerrainModifier(): number
	-- Raycast down to check terrain
	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = { self.model }
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local result = workspace:Raycast(self.position + Vector3.new(0, 2, 0), Vector3.new(0, -10, 0), raycastParams)

	if result then
		local material = result.Material

		-- Different terrain types
		if material == Enum.Material.Sand then
			return 0.7 -- Slower on sand
		elseif material == Enum.Material.Mud then
			return 0.6 -- Slowest on mud
		elseif material == Enum.Material.Grass then
			return 0.9 -- Slightly slower on grass
		elseif material == Enum.Material.Rock or material == Enum.Material.Concrete then
			return 1.0 -- Full speed on roads
		end
	end

	return 0.85 -- Default slight reduction
end

--[[
	Override: Serialize with turret data
]]
function Jeep:Serialize(): { [string]: any }
	local data = VehicleBase.Serialize(self)

	data.turretAmmo = self.turretAmmo
	data.maxTurretAmmo = self.maxTurretAmmo
	data.turretRotation = self.turretRotation

	return data
end

return Jeep
