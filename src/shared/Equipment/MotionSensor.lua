--!strict
--[[
	MotionSensor.lua
	================
	Deployable that detects players and dinosaurs
	Based on GDD Section 6.2: Tactical Equipment
]]

local EquipmentBase = require(script.Parent.EquipmentBase)

local MotionSensor = {}
MotionSensor.__index = MotionSensor
setmetatable(MotionSensor, { __index = EquipmentBase })

MotionSensor.Stats = {
	name = "MotionSensor",
	displayName = "Motion Sensor",
	description = "Deployable sensor that detects players and dinos within 30m for 60 seconds",
	category = "Deployable",
	rarity = "Rare",

	maxStack = 2,
	useTime = 1.0, -- Deploy time
	cooldown = 2.0,

	-- Detection
	detectionRadius = 30,
	effectDuration = 60,

	-- Ping
	pingInterval = 2.0, -- Updates every 2 seconds
	detectsPlayers = true,
	detectsDinosaurs = true,
	detectsVehicles = true,

	-- Visibility
	isVisible = true, -- Can be seen and destroyed
	health = 50,

	sounds = {
		deploy = "SensorDeploy",
		ping = "SensorPing",
		detect = "SensorDetect",
		destroy = "SensorDestroy",
	},
}

-- Deployed sensor data
export type DeployedSensor = {
	id: string,
	position: Vector3,
	owner: any,
	deployTime: number,
	endTime: number,
	health: number,
	detectedEntities: { DetectedEntity },
	lastPingTime: number,
}

export type DetectedEntity = {
	entityType: string, -- "Player" | "Dinosaur" | "Vehicle"
	position: Vector3,
	lastSeen: number,
}

--[[
	Create new motion sensor
]]
function MotionSensor.new(config: any?): any
	local self = EquipmentBase.new(MotionSensor.Stats, config)
	setmetatable(self, MotionSensor)

	-- Track deployed sensors
	self.deployedSensors = {} :: { DeployedSensor }

	return self
end

--[[
	Deploy sensor at position
]]
function MotionSensor:Use(origin: Vector3, direction: Vector3): any
	if not self:CanUse() then return nil end

	self.isUsing = true
	self.lastUseTime = tick()

	-- Deploy slightly in front of player
	local deployPosition = origin + direction * 2

	local sensorData = {
		type = "MotionSensor",
		position = deployPosition,
		owner = self.owner,
		radius = MotionSensor.Stats.detectionRadius,
		duration = MotionSensor.Stats.effectDuration,
		health = MotionSensor.Stats.health,
	}

	task.delay(MotionSensor.Stats.useTime, function()
		self:OnUseComplete()
	end)

	return sensorData
end

--[[
	Create deployed sensor instance
]]
function MotionSensor.CreateDeployedSensor(position: Vector3, owner: any): DeployedSensor
	return {
		id = tostring(math.random(100000, 999999)),
		position = position,
		owner = owner,
		deployTime = tick(),
		endTime = tick() + MotionSensor.Stats.effectDuration,
		health = MotionSensor.Stats.health,
		detectedEntities = {},
		lastPingTime = 0,
	}
end

--[[
	Update sensor detection
]]
function MotionSensor.UpdateSensor(sensor: DeployedSensor, nearbyEntities: { any }): { DetectedEntity }
	local now = tick()

	-- Check if expired
	if now > sensor.endTime then
		return {}
	end

	-- Check ping interval
	if now - sensor.lastPingTime < MotionSensor.Stats.pingInterval then
		return sensor.detectedEntities
	end

	sensor.lastPingTime = now
	sensor.detectedEntities = {}

	-- Detect entities
	for _, entity in ipairs(nearbyEntities) do
		local entityPos = entity.position or entity.Position
		if not entityPos then continue end

		local distance = (entityPos - sensor.position).Magnitude

		if distance <= MotionSensor.Stats.detectionRadius then
			local entityType = "Unknown"

			if entity.isPlayer and MotionSensor.Stats.detectsPlayers then
				entityType = "Player"
			elseif entity.isDinosaur and MotionSensor.Stats.detectsDinosaurs then
				entityType = "Dinosaur"
			elseif entity.isVehicle and MotionSensor.Stats.detectsVehicles then
				entityType = "Vehicle"
			else
				continue
			end

			table.insert(sensor.detectedEntities, {
				entityType = entityType,
				position = entityPos,
				lastSeen = now,
			})
		end
	end

	return sensor.detectedEntities
end

--[[
	Damage sensor
]]
function MotionSensor.DamageSensor(sensor: DeployedSensor, amount: number): boolean
	sensor.health = sensor.health - amount

	if sensor.health <= 0 then
		return true -- Destroyed
	end

	return false
end

--[[
	Check if sensor is active
]]
function MotionSensor.IsSensorActive(sensor: DeployedSensor): boolean
	return tick() < sensor.endTime and sensor.health > 0
end

--[[
	Get remaining time
]]
function MotionSensor.GetRemainingTime(sensor: DeployedSensor): number
	return math.max(0, sensor.endTime - tick())
end

return MotionSensor
