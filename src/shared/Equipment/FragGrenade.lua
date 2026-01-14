--!strict
--[[
	FragGrenade.lua
	===============
	Standard explosive grenade
	Based on GDD Section 6.2: Tactical Equipment
]]

local EquipmentBase = require(script.Parent.EquipmentBase)

local FragGrenade = {}
FragGrenade.__index = FragGrenade
setmetatable(FragGrenade, { __index = EquipmentBase })

FragGrenade.Stats = {
	name = "FragGrenade",
	displayName = "Frag Grenade",
	description = "Explosive grenade with 5m blast radius. 70 damage at center.",
	category = "Throwable",
	rarity = "Uncommon",

	maxStack = 6,
	useTime = 0.5, -- Wind up time
	cooldown = 0.5,

	-- Throw
	throwForce = 80,
	throwArc = 0.3,
	fuseTime = 3.0,

	-- Damage
	damage = 70, -- Center damage
	effectRadius = 5,
	falloffStart = 2, -- Full damage within 2m
	falloffEnd = 5, -- No damage at 5m

	-- Effects
	sounds = {
		throw = "GrenadeThrow",
		bounce = "GrenadeBounce",
		explode = "GrenadeExplode",
	},
}

--[[
	Create new frag grenade
]]
function FragGrenade.new(config: any?): any
	local self = EquipmentBase.new(FragGrenade.Stats, config)
	setmetatable(self, FragGrenade)

	return self
end

--[[
	Use (throw) grenade
]]
function FragGrenade:Use(origin: Vector3, direction: Vector3): any
	if not self:CanUse() then return nil end

	self.isUsing = true
	self.lastUseTime = tick()

	-- Calculate throw velocity with arc
	local throwVelocity = direction * FragGrenade.Stats.throwForce
	throwVelocity = throwVelocity + Vector3.new(0, FragGrenade.Stats.throwForce * FragGrenade.Stats.throwArc, 0)

	local grenadeData = {
		type = "FragGrenade",
		origin = origin,
		velocity = throwVelocity,
		fuseTime = FragGrenade.Stats.fuseTime,
		owner = self.owner,

		-- Explosion data
		onExplode = {
			damage = FragGrenade.Stats.damage,
			radius = FragGrenade.Stats.effectRadius,
			falloffStart = FragGrenade.Stats.falloffStart,
			falloffEnd = FragGrenade.Stats.falloffEnd,
		},
	}

	-- Consume after throw completes
	task.delay(FragGrenade.Stats.useTime, function()
		self:OnUseComplete()
	end)

	return grenadeData
end

--[[
	Calculate damage at distance
]]
function FragGrenade.CalculateDamage(distance: number): number
	if distance <= FragGrenade.Stats.falloffStart then
		return FragGrenade.Stats.damage
	elseif distance >= FragGrenade.Stats.falloffEnd then
		return 0
	else
		local falloffRange = FragGrenade.Stats.falloffEnd - FragGrenade.Stats.falloffStart
		local falloffProgress = (distance - FragGrenade.Stats.falloffStart) / falloffRange
		return FragGrenade.Stats.damage * (1 - falloffProgress)
	end
end

return FragGrenade
