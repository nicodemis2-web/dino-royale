--!strict
--[[
	SmokeBomb.lua
	=============
	Creates visual cover and confuses dinosaur AI
	Based on GDD Section 6.2: Tactical Equipment
]]

local EquipmentBase = require(script.Parent.EquipmentBase)

local SmokeBomb = {}
SmokeBomb.__index = SmokeBomb
setmetatable(SmokeBomb, { __index = EquipmentBase })

SmokeBomb.Stats = {
	name = "SmokeBomb",
	displayName = "Smoke Bomb",
	description = "Creates visual cover and confuses dinosaur AI for 5 seconds",
	category = "Throwable",
	rarity = "Common",

	maxStack = 4,
	useTime = 0.3,
	cooldown = 0.5,

	-- Throw
	throwForce = 60,
	throwArc = 0.4,
	fuseTime = 1.0, -- Activates quickly

	-- Effect
	effectRadius = 8,
	effectDuration = 15, -- Smoke lasts 15 seconds
	dinoConfuseDuration = 5, -- Dinos confused for 5 seconds

	-- Visual
	smokeColor = { r = 200, g = 200, b = 200 },
	smokeOpacity = 0.8,

	sounds = {
		throw = "SmokeBombThrow",
		activate = "SmokeBombPop",
		ambient = "SmokeAmbient",
	},
}

--[[
	Create new smoke bomb
]]
function SmokeBomb.new(config: any?): any
	local self = EquipmentBase.new(SmokeBomb.Stats, config)
	setmetatable(self, SmokeBomb)

	return self
end

--[[
	Use (throw) smoke bomb
]]
function SmokeBomb:Use(origin: Vector3, direction: Vector3): any
	if not self:CanUse() then return nil end

	self.isUsing = true
	self.lastUseTime = tick()

	local throwVelocity = direction * SmokeBomb.Stats.throwForce
	throwVelocity = throwVelocity + Vector3.new(0, SmokeBomb.Stats.throwForce * SmokeBomb.Stats.throwArc, 0)

	local smokeData = {
		type = "SmokeBomb",
		origin = origin,
		velocity = throwVelocity,
		fuseTime = SmokeBomb.Stats.fuseTime,
		owner = self.owner,

		onActivate = {
			radius = SmokeBomb.Stats.effectRadius,
			duration = SmokeBomb.Stats.effectDuration,
			dinoConfuseDuration = SmokeBomb.Stats.dinoConfuseDuration,
			color = SmokeBomb.Stats.smokeColor,
			opacity = SmokeBomb.Stats.smokeOpacity,
		},
	}

	task.delay(SmokeBomb.Stats.useTime, function()
		self:OnUseComplete()
	end)

	return smokeData
end

--[[
	Check if position is in smoke
]]
function SmokeBomb.IsInSmoke(position: Vector3, smokePosition: Vector3, radius: number): boolean
	return (position - smokePosition).Magnitude <= radius
end

return SmokeBomb
