--!strict
--[[
	DinoRepellent.lua
	=================
	Creates a dinosaur-free safe zone
	Based on GDD Section 6.2: Tactical Equipment
]]

local EquipmentBase = require(script.Parent.EquipmentBase)

local DinoRepellent = {}
DinoRepellent.__index = DinoRepellent
setmetatable(DinoRepellent, { __index = EquipmentBase })

DinoRepellent.Stats = {
	name = "DinoRepellent",
	displayName = "Dino Repellent",
	description = "Spray creating a 10m dinosaur-free zone for 30 seconds",
	category = "Deployable",
	rarity = "Uncommon",

	maxStack = 2,
	useTime = 1.5, -- Spray time
	cooldown = 1.0,

	-- Effect
	effectRadius = 10,
	effectDuration = 30,

	-- Dinosaur interaction
	repelStrength = 1.0, -- Full repel for most dinos
	bossRepelStrength = 0.3, -- Weaker against bosses

	-- Visual
	showBoundary = true,
	boundaryColor = { r = 100, g = 200, b = 100 },

	sounds = {
		spray = "RepellentSpray",
		activate = "RepellentActivate",
		expire = "RepellentExpire",
	},
}

-- Active repellent zone
export type RepellentZone = {
	id: string,
	position: Vector3,
	radius: number,
	owner: any,
	startTime: number,
	endTime: number,
}

--[[
	Create new dino repellent
]]
function DinoRepellent.new(config: any?): any
	local self = EquipmentBase.new(DinoRepellent.Stats, config)
	setmetatable(self, DinoRepellent)

	return self
end

--[[
	Use repellent at current position
]]
function DinoRepellent:Use(origin: Vector3, direction: Vector3): any
	if not self:CanUse() then return nil end

	self.isUsing = true
	self.lastUseTime = tick()

	local repellentData = {
		type = "DinoRepellent",
		position = origin,
		radius = DinoRepellent.Stats.effectRadius,
		duration = DinoRepellent.Stats.effectDuration,
		owner = self.owner,
		repelStrength = DinoRepellent.Stats.repelStrength,
		bossRepelStrength = DinoRepellent.Stats.bossRepelStrength,
	}

	task.delay(DinoRepellent.Stats.useTime, function()
		self:OnUseComplete()
	end)

	return repellentData
end

--[[
	Create repellent zone
]]
function DinoRepellent.CreateZone(position: Vector3, owner: any): RepellentZone
	return {
		id = tostring(math.random(100000, 999999)),
		position = position,
		radius = DinoRepellent.Stats.effectRadius,
		owner = owner,
		startTime = tick(),
		endTime = tick() + DinoRepellent.Stats.effectDuration,
	}
end

--[[
	Check if dinosaur should flee from zone
]]
function DinoRepellent.ShouldDinoFlee(zone: RepellentZone, dinoPosition: Vector3, isBoss: boolean): boolean
	-- Check if zone is still active
	if tick() > zone.endTime then
		return false
	end

	-- Check if dino is in range
	local distance = (dinoPosition - zone.position).Magnitude
	if distance > zone.radius then
		return false
	end

	-- Apply repel strength
	local repelStrength = isBoss and DinoRepellent.Stats.bossRepelStrength or DinoRepellent.Stats.repelStrength

	-- Random chance based on repel strength
	return math.random() < repelStrength
end

--[[
	Get flee direction for dinosaur
]]
function DinoRepellent.GetFleeDirection(zone: RepellentZone, dinoPosition: Vector3): Vector3
	local awayFromCenter = (dinoPosition - zone.position).Unit
	return awayFromCenter
end

--[[
	Check if zone is active
]]
function DinoRepellent.IsZoneActive(zone: RepellentZone): boolean
	return tick() < zone.endTime
end

--[[
	Get remaining time
]]
function DinoRepellent.GetRemainingTime(zone: RepellentZone): number
	return math.max(0, zone.endTime - tick())
end

return DinoRepellent
