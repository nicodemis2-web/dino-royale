--!strict
--[[
	VehicleBase.lua
	===============
	Base class for all vehicles
	Handles physics, passengers, damage, and destruction
]]

local _Players = game:GetService("Players")

local Events = require(game.ReplicatedStorage.Shared.Events)

local VehicleBase = {}
VehicleBase.__index = VehicleBase

-- Type definitions
export type VehicleInput = {
	throttle: number, -- -1 to 1
	steer: number, -- -1 to 1
	brake: boolean,
	handbrake: boolean,
	horn: boolean,
	-- Helicopter specific
	altitude: number?, -- -1 to 1
}

export type VehicleStats = {
	maxSpeed: number,
	acceleration: number,
	deceleration: number,
	turnSpeed: number,
	health: number,
	maxHealth: number,
	seatCount: number,
}

export type VehicleInstance = {
	id: string,
	vehicleType: string,
	model: Model?,
	stats: VehicleStats,
	seats: { [number]: Player? },
	driver: Player?,
	currentSpeed: number,
	currentHealth: number,
	fuel: number?,
	maxFuel: number?,
	isDestroyed: boolean,
	position: Vector3,
	rotation: CFrame,

	-- Methods
	Enter: (self: VehicleInstance, player: Player, seatIndex: number) -> boolean,
	Exit: (self: VehicleInstance, player: Player) -> (),
	TakeDamage: (self: VehicleInstance, amount: number, source: string) -> (),
	Destroy: (self: VehicleInstance) -> (),
	Update: (self: VehicleInstance, dt: number, input: VehicleInput?) -> (),
	GetOccupants: (self: VehicleInstance) -> { Player },
	IsOccupied: (self: VehicleInstance) -> boolean,
	Serialize: (self: VehicleInstance) -> { [string]: any },
}

-- Unique ID counter
local nextId = 0

-- Default stats per vehicle type
local DEFAULT_STATS = {
	Jeep = {
		maxSpeed = 50,
		acceleration = 15,
		deceleration = 25,
		turnSpeed = 2,
		health = 800,
		maxHealth = 800,
		seatCount = 4,
	},
	ATV = {
		maxSpeed = 60,
		acceleration = 20,
		deceleration = 30,
		turnSpeed = 3,
		health = 400,
		maxHealth = 400,
		seatCount = 2,
	},
	Boat = {
		maxSpeed = 45,
		acceleration = 12,
		deceleration = 15,
		turnSpeed = 1.5,
		health = 500,
		maxHealth = 500,
		seatCount = 4,
	},
	Helicopter = {
		maxSpeed = 65,
		acceleration = 25,
		deceleration = 20,
		turnSpeed = 2,
		health = 600,
		maxHealth = 600,
		seatCount = 4,
	},
	Motorcycle = {
		maxSpeed = 70,
		acceleration = 25,
		deceleration = 35,
		turnSpeed = 4,
		health = 200,
		maxHealth = 200,
		seatCount = 1,
	},
}

--[[
	Create a new vehicle instance
	@param vehicleType Type of vehicle
	@param position Spawn position CFrame
	@return VehicleInstance
]]
function VehicleBase.new(vehicleType: string, position: CFrame): VehicleInstance
	local defaultStats = DEFAULT_STATS[vehicleType]
	if not defaultStats then
		error(`Unknown vehicle type: {vehicleType}`)
	end

	nextId = nextId + 1

	local self = setmetatable({}, VehicleBase) :: any

	self.id = `vehicle_{nextId}`
	self.vehicleType = vehicleType
	self.model = nil

	self.stats = {
		maxSpeed = defaultStats.maxSpeed,
		acceleration = defaultStats.acceleration,
		deceleration = defaultStats.deceleration,
		turnSpeed = defaultStats.turnSpeed,
		health = defaultStats.health,
		maxHealth = defaultStats.maxHealth,
		seatCount = defaultStats.seatCount,
	}

	self.seats = {} :: { [number]: Player? }
	for i = 1, self.stats.seatCount do
		self.seats[i] = nil
	end

	self.driver = nil
	self.currentSpeed = 0
	self.currentHealth = self.stats.health
	self.isDestroyed = false
	self.position = position.Position
	self.rotation = position

	-- Fuel for helicopter
	if vehicleType == "Helicopter" then
		self.fuel = 180 -- 3 minutes
		self.maxFuel = 180
	end

	return self
end

--[[
	Set the model for this vehicle
	@param model Vehicle model
]]
function VehicleBase:SetModel(model: Model)
	self.model = model

	-- Position model
	if model.PrimaryPart then
		model:SetPrimaryPartCFrame(self.rotation)
	end
end

--[[
	Player enters vehicle
	@param player Player entering
	@param seatIndex Seat to enter (1 = driver)
	@return Whether entry was successful
]]
function VehicleBase:Enter(player: Player, seatIndex: number): boolean
	if self.isDestroyed then
		return false
	end

	if seatIndex < 1 or seatIndex > self.stats.seatCount then
		return false
	end

	-- Check if seat is occupied
	if self.seats[seatIndex] ~= nil then
		return false
	end

	-- Check if player is already in a vehicle
	for _, occupant in pairs(self.seats) do
		if occupant == player then
			return false
		end
	end

	-- Enter seat
	self.seats[seatIndex] = player

	if seatIndex == 1 then
		self.driver = player
	end

	-- Seat player in vehicle
	local character = player.Character
	if character and self.model then
		local seat = self.model:FindFirstChild(`Seat{seatIndex}`)
		if seat and seat:IsA("VehicleSeat") or seat:IsA("Seat") then
			(seat :: Seat):Sit(character:FindFirstChildOfClass("Humanoid"))
		end
	end

	-- Broadcast entry
	Events.FireAllClients("Vehicle", "PlayerEntered", {
		vehicleId = self.id,
		playerId = player.UserId,
		seatIndex = seatIndex,
	})

	print(`[VehicleBase] {player.Name} entered {self.vehicleType} seat {seatIndex}`)

	return true
end

--[[
	Player exits vehicle
	@param player Player exiting
]]
function VehicleBase:Exit(player: Player)
	local seatIndex: number? = nil

	for i, occupant in pairs(self.seats) do
		if occupant == player then
			seatIndex = i
			self.seats[i] = nil
			break
		end
	end

	if seatIndex == 1 then
		self.driver = nil
	end

	if seatIndex == nil then
		return -- Player wasn't in this vehicle
	end

	-- Unseat player
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Sit = false

			-- Teleport slightly away from vehicle
			local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if rootPart then
				local exitOffset = self.rotation:VectorToWorldSpace(Vector3.new(5, 2, 0))
				rootPart.CFrame = CFrame.new(self.position + exitOffset)
			end
		end
	end

	-- Broadcast exit
	Events.FireAllClients("Vehicle", "PlayerExited", {
		vehicleId = self.id,
		playerId = player.UserId,
		seatIndex = seatIndex,
	})

	print(`[VehicleBase] {player.Name} exited {self.vehicleType}`)
end

--[[
	Vehicle takes damage
	@param amount Damage amount
	@param source Damage source description
]]
function VehicleBase:TakeDamage(amount: number, source: string)
	if self.isDestroyed then
		return
	end

	self.currentHealth = math.max(0, self.currentHealth - amount)

	-- Broadcast damage
	Events.FireAllClients("Vehicle", "VehicleDamaged", {
		vehicleId = self.id,
		newHealth = self.currentHealth,
		maxHealth = self.stats.maxHealth,
		source = source,
	})

	-- Check destruction
	if self.currentHealth <= 0 then
		self:Destroy()
	end
end

--[[
	Destroy the vehicle
]]
function VehicleBase:Destroy()
	if self.isDestroyed then
		return
	end

	self.isDestroyed = true

	-- Eject all passengers
	local passengers = self:GetOccupants()
	for _, player in ipairs(passengers) do
		self:Exit(player)

		-- Apply damage to ejected players (especially for helicopter)
		if self.vehicleType == "Helicopter" then
			local character = player.Character
			if character then
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					-- Fall damage will be applied by the physics system
					-- But we can add explosion damage
					humanoid:TakeDamage(25)
				end
			end
		end
	end

	-- Broadcast destruction
	Events.FireAllClients("Vehicle", "VehicleDestroyed", {
		vehicleId = self.id,
		position = self.position,
		vehicleType = self.vehicleType,
	})

	-- Destroy model after delay (for explosion effect)
	if self.model then
		-- Create explosion effect
		local explosion = Instance.new("Explosion")
		explosion.Position = self.position
		explosion.BlastRadius = 15
		explosion.BlastPressure = 5000
		explosion.DestroyJointRadiusPercent = 0
		explosion.Parent = workspace

		task.delay(0.5, function()
			if self.model then
				self.model:Destroy()
				self.model = nil
			end
		end)
	end

	print(`[VehicleBase] {self.vehicleType} destroyed!`)
end

--[[
	Update vehicle physics
	@param dt Delta time
	@param input Vehicle input (nil if no driver)
]]
function VehicleBase:Update(dt: number, input: VehicleInput?)
	if self.isDestroyed then
		return
	end

	-- Update fuel for helicopter
	if self.fuel ~= nil and self.driver then
		self.fuel = self.fuel - dt
		if self.fuel <= 0 then
			self.fuel = 0
			-- Force land/crash
			print(`[VehicleBase] {self.vehicleType} out of fuel!`)
		end
	end

	-- Apply physics based on input
	if input and self.driver then
		self:ApplyInput(dt, input)
	else
		-- Decelerate when no input
		self.currentSpeed = self.currentSpeed * (1 - self.stats.deceleration * dt * 0.1)
		if math.abs(self.currentSpeed) < 0.1 then
			self.currentSpeed = 0
		end
	end

	-- Update model position
	self:UpdateModelPosition(dt)
end

--[[
	Apply input to vehicle
]]
function VehicleBase:ApplyInput(dt: number, input: VehicleInput)
	local stats = self.stats

	-- Throttle (acceleration/deceleration)
	if input.throttle > 0 then
		self.currentSpeed = math.min(
			stats.maxSpeed,
			self.currentSpeed + input.throttle * stats.acceleration * dt
		)
	elseif input.throttle < 0 then
		self.currentSpeed = math.max(
			-stats.maxSpeed * 0.5, -- Reverse is slower
			self.currentSpeed + input.throttle * stats.acceleration * dt
		)
	end

	-- Brake
	if input.brake then
		local brakeForce = stats.deceleration * 2 * dt
		if self.currentSpeed > 0 then
			self.currentSpeed = math.max(0, self.currentSpeed - brakeForce)
		elseif self.currentSpeed < 0 then
			self.currentSpeed = math.min(0, self.currentSpeed + brakeForce)
		end
	end

	-- Steering (only when moving)
	if math.abs(self.currentSpeed) > 1 then
		local steerAmount = input.steer * stats.turnSpeed * dt
		-- Reduce steering at high speeds
		local speedFactor = 1 - (math.abs(self.currentSpeed) / stats.maxSpeed) * 0.5
		steerAmount = steerAmount * speedFactor

		self.rotation = self.rotation * CFrame.Angles(0, -steerAmount, 0)
	end

	-- Horn
	if input.horn then
		-- Broadcast horn (for audio and dinosaur attraction)
		Events.FireAllClients("Vehicle", "Horn", {
			vehicleId = self.id,
			position = self.position,
		})
	end
end

--[[
	Update model position based on current state
]]
function VehicleBase:UpdateModelPosition(dt: number)
	if not self.model or not self.model.PrimaryPart then
		return
	end

	-- Calculate new position
	local forward = self.rotation.LookVector
	local movement = forward * self.currentSpeed * dt
	self.position = self.position + movement

	-- Apply to model
	local targetCFrame = CFrame.new(self.position) * self.rotation.Rotation
	self.model:SetPrimaryPartCFrame(targetCFrame)
end

--[[
	Get all occupants
	@return Array of players in vehicle
]]
function VehicleBase:GetOccupants(): { Player }
	local occupants = {} :: { Player }
	for _, player in pairs(self.seats) do
		if player then
			table.insert(occupants, player)
		end
	end
	return occupants
end

--[[
	Check if vehicle has any occupants
	@return Whether vehicle is occupied
]]
function VehicleBase:IsOccupied(): boolean
	for _, player in pairs(self.seats) do
		if player then
			return true
		end
	end
	return false
end

--[[
	Get available seat
	@return First available seat index or nil
]]
function VehicleBase:GetAvailableSeat(): number?
	for i = 1, self.stats.seatCount do
		if self.seats[i] == nil then
			return i
		end
	end
	return nil
end

--[[
	Check if player can shoot from their seat
	@param player Player to check
	@return Whether they can shoot
]]
function VehicleBase:CanShootFromSeat(player: Player): boolean
	-- Override in subclasses
	-- Default: only non-drivers can shoot
	return self.driver ~= player
end

--[[
	Get speed as percentage of max
	@return Speed percentage (0-1)
]]
function VehicleBase:GetSpeedPercent(): number
	return math.abs(self.currentSpeed) / self.stats.maxSpeed
end

--[[
	Get health as percentage
	@return Health percentage (0-1)
]]
function VehicleBase:GetHealthPercent(): number
	return self.currentHealth / self.stats.maxHealth
end

--[[
	Serialize vehicle data
	@return Serialized data
]]
function VehicleBase:Serialize(): { [string]: any }
	local seatData = {}
	for i, player in pairs(self.seats) do
		if player then
			seatData[i] = player.UserId
		end
	end

	return {
		id = self.id,
		vehicleType = self.vehicleType,
		position = self.position,
		rotation = self.rotation,
		health = self.currentHealth,
		maxHealth = self.stats.maxHealth,
		speed = self.currentSpeed,
		fuel = self.fuel,
		maxFuel = self.maxFuel,
		seats = seatData,
		isDestroyed = self.isDestroyed,
	}
end

return VehicleBase
