--!strict
--[[
	MeatBait.lua
	============
	Throwable lure that attracts carnivorous dinosaurs
	Based on GDD Section 6.2: Tactical Equipment
]]

local EquipmentBase = require(script.Parent.EquipmentBase)

local MeatBait = {}
MeatBait.__index = MeatBait
setmetatable(MeatBait, { __index = EquipmentBase })

MeatBait.Stats = {
	name = "MeatBait",
	displayName = "Meat Bait",
	description = "Throwable lure that attracts carnivores for 20 seconds",
	category = "Throwable",
	rarity = "Common",

	maxStack = 4,
	useTime = 0.5,
	cooldown = 0.5,

	-- Throw
	throwForce = 50,
	throwArc = 0.5,

	-- Effect
	attractRadius = 50,
	effectDuration = 20,

	-- Dinosaurs attracted
	attractedTypes = {
		"Velociraptor",
		"Dilophosaurus",
		"Compsognathus",
		"Carnotaurus",
		"Baryonyx",
		-- Does NOT attract apex predators (T-Rex, Spinosaurus, Indoraptor)
	},

	-- Priority
	attractPriority = 0.8, -- 80% chance dino prioritizes bait over other targets

	sounds = {
		throw = "MeatThrow",
		land = "MeatLand",
		attract = "DinoSniff",
	},
}

-- Active bait data
export type ActiveBait = {
	id: string,
	position: Vector3,
	owner: any,
	startTime: number,
	endTime: number,
	attractedDinos: { any },
}

--[[
	Create new meat bait
]]
function MeatBait.new(config: any?): any
	local self = EquipmentBase.new(MeatBait.Stats, config)
	setmetatable(self, MeatBait)

	return self
end

--[[
	Throw meat bait
]]
function MeatBait:Use(origin: Vector3, direction: Vector3): any
	if not self:CanUse() then return nil end

	self.isUsing = true
	self.lastUseTime = tick()

	local throwVelocity = direction * MeatBait.Stats.throwForce
	throwVelocity = throwVelocity + Vector3.new(0, MeatBait.Stats.throwForce * MeatBait.Stats.throwArc, 0)

	local baitData = {
		type = "MeatBait",
		origin = origin,
		velocity = throwVelocity,
		owner = self.owner,
		attractRadius = MeatBait.Stats.attractRadius,
		duration = MeatBait.Stats.effectDuration,
		attractedTypes = MeatBait.Stats.attractedTypes,
		attractPriority = MeatBait.Stats.attractPriority,
	}

	task.delay(MeatBait.Stats.useTime, function()
		self:OnUseComplete()
	end)

	return baitData
end

--[[
	Create active bait at landing position
]]
function MeatBait.CreateActiveBait(position: Vector3, owner: any): ActiveBait
	return {
		id = tostring(math.random(100000, 999999)),
		position = position,
		owner = owner,
		startTime = tick(),
		endTime = tick() + MeatBait.Stats.effectDuration,
		attractedDinos = {},
	}
end

--[[
	Check if dinosaur type is attracted to bait
]]
function MeatBait.IsDinoAttracted(dinoType: string): boolean
	for _, attractedType in ipairs(MeatBait.Stats.attractedTypes) do
		if dinoType == attractedType then
			return true
		end
	end
	return false
end

--[[
	Check if dino should prioritize bait
]]
function MeatBait.ShouldPrioritizeBait(bait: ActiveBait, dinoPosition: Vector3, dinoType: string): boolean
	-- Check if bait is active
	if tick() > bait.endTime then
		return false
	end

	-- Check if dino type is attracted
	if not MeatBait.IsDinoAttracted(dinoType) then
		return false
	end

	-- Check if in range
	local distance = (dinoPosition - bait.position).Magnitude
	if distance > MeatBait.Stats.attractRadius then
		return false
	end

	-- Random priority check
	return math.random() < MeatBait.Stats.attractPriority
end

--[[
	Check if bait is active
]]
function MeatBait.IsBaitActive(bait: ActiveBait): boolean
	return tick() < bait.endTime
end

--[[
	Get remaining time
]]
function MeatBait.GetRemainingTime(bait: ActiveBait): number
	return math.max(0, bait.endTime - tick())
end

return MeatBait
