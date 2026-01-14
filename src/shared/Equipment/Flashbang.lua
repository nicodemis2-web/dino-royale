--!strict
--[[
	Flashbang.lua
	=============
	Blinds players and panics dinosaurs
	Based on GDD Section 6.2: Tactical Equipment
]]

local EquipmentBase = require(script.Parent.EquipmentBase)

local Flashbang = {}
Flashbang.__index = Flashbang
setmetatable(Flashbang, { __index = EquipmentBase })

Flashbang.Stats = {
	name = "Flashbang",
	displayName = "Flashbang",
	description = "Blinds players and panics dinosaurs for 3 seconds",
	category = "Throwable",
	rarity = "Uncommon",

	maxStack = 4,
	useTime = 0.4,
	cooldown = 0.5,

	-- Throw
	throwForce = 70,
	throwArc = 0.35,
	fuseTime = 2.0,

	-- Effect
	effectRadius = 12,
	blindDuration = 3.0,
	dinoPanicDuration = 3.0,

	-- Falloff based on facing
	fullEffectAngle = 90, -- Full effect if flash is within 90° of view
	reducedEffectMultiplier = 0.5, -- 50% effect if facing away

	sounds = {
		throw = "FlashbangThrow",
		bounce = "FlashbangBounce",
		explode = "FlashbangBang",
	},
}

--[[
	Create new flashbang
]]
function Flashbang.new(config: any?): any
	local self = EquipmentBase.new(Flashbang.Stats, config)
	setmetatable(self, Flashbang)

	return self
end

--[[
	Use (throw) flashbang
]]
function Flashbang:Use(origin: Vector3, direction: Vector3): any
	if not self:CanUse() then return nil end

	self.isUsing = true
	self.lastUseTime = tick()

	local throwVelocity = direction * Flashbang.Stats.throwForce
	throwVelocity = throwVelocity + Vector3.new(0, Flashbang.Stats.throwForce * Flashbang.Stats.throwArc, 0)

	local flashData = {
		type = "Flashbang",
		origin = origin,
		velocity = throwVelocity,
		fuseTime = Flashbang.Stats.fuseTime,
		owner = self.owner,

		onExplode = {
			radius = Flashbang.Stats.effectRadius,
			blindDuration = Flashbang.Stats.blindDuration,
			dinoPanicDuration = Flashbang.Stats.dinoPanicDuration,
			fullEffectAngle = Flashbang.Stats.fullEffectAngle,
			reducedMultiplier = Flashbang.Stats.reducedEffectMultiplier,
		},
	}

	task.delay(Flashbang.Stats.useTime, function()
		self:OnUseComplete()
	end)

	return flashData
end

--[[
	Calculate flash effect on target
]]
function Flashbang.CalculateEffect(flashPosition: Vector3, targetPosition: Vector3, targetFacing: Vector3): { duration: number, intensity: number }
	local toFlash = (flashPosition - targetPosition).Unit
	local dot = targetFacing:Dot(toFlash)
	local angle = math.deg(math.acos(math.clamp(dot, -1, 1)))

	local intensity = 1.0
	if angle > Flashbang.Stats.fullEffectAngle then
		intensity = Flashbang.Stats.reducedEffectMultiplier
	end

	return {
		duration = Flashbang.Stats.blindDuration * intensity,
		intensity = intensity,
	}
end

return Flashbang
