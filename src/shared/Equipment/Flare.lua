--!strict
--[[
	Flare.lua
	=========
	Throwable that attracts dinosaurs and marks enemy locations
	Based on GDD Section 6.2: Tactical Equipment
]]

local EquipmentBase = require(script.Parent.EquipmentBase)

local Flare = {}
Flare.__index = Flare
setmetatable(Flare, { __index = EquipmentBase })

Flare.Stats = {
	name = "Flare",
	displayName = "Flare",
	description = "Attracts dinosaurs and marks enemy locations with bright light",
	category = "Throwable",
	rarity = "Common",

	maxStack = 6,
	useTime = 0.3,
	cooldown = 0.5,

	-- Throw
	throwForce = 65,
	throwArc = 0.6,

	-- Light effect
	lightRadius = 30,
	lightDuration = 45,
	lightColor = { r = 255, g = 100, b = 50 },

	-- Detection
	revealRadius = 25, -- Reveals enemies in radius
	revealDuration = 3, -- How long enemies stay marked

	-- Dinosaur attraction
	dinoAttractRadius = 40,
	dinoAttractChance = 0.5, -- 50% chance to attract nearby dinos

	sounds = {
		throw = "FlareThrow",
		ignite = "FlareIgnite",
		burn = "FlareBurn",
	},
}

-- Active flare data
export type ActiveFlare = {
	id: string,
	position: Vector3,
	owner: any,
	startTime: number,
	endTime: number,
	revealedPlayers: { any },
}

--[[
	Create new flare
]]
function Flare.new(config: any?): any
	local self = EquipmentBase.new(Flare.Stats, config)
	setmetatable(self, Flare)

	return self
end

--[[
	Throw flare
]]
function Flare:Use(origin: Vector3, direction: Vector3): any
	if not self:CanUse() then return nil end

	self.isUsing = true
	self.lastUseTime = tick()

	local throwVelocity = direction * Flare.Stats.throwForce
	throwVelocity = throwVelocity + Vector3.new(0, Flare.Stats.throwForce * Flare.Stats.throwArc, 0)

	local flareData = {
		type = "Flare",
		origin = origin,
		velocity = throwVelocity,
		owner = self.owner,
		lightRadius = Flare.Stats.lightRadius,
		lightDuration = Flare.Stats.lightDuration,
		lightColor = Flare.Stats.lightColor,
		revealRadius = Flare.Stats.revealRadius,
		dinoAttractRadius = Flare.Stats.dinoAttractRadius,
		dinoAttractChance = Flare.Stats.dinoAttractChance,
	}

	task.delay(Flare.Stats.useTime, function()
		self:OnUseComplete()
	end)

	return flareData
end

--[[
	Create active flare at landing position
]]
function Flare.CreateActiveFlare(position: Vector3, owner: any): ActiveFlare
	return {
		id = tostring(math.random(100000, 999999)),
		position = position,
		owner = owner,
		startTime = tick(),
		endTime = tick() + Flare.Stats.lightDuration,
		revealedPlayers = {},
	}
end

--[[
	Check if player should be revealed
]]
function Flare.ShouldRevealPlayer(flare: ActiveFlare, playerPosition: Vector3, playerOwner: any): boolean
	-- Don't reveal owner
	if playerOwner == flare.owner then
		return false
	end

	-- Check if flare is active
	if tick() > flare.endTime then
		return false
	end

	-- Check if in reveal radius
	local distance = (playerPosition - flare.position).Magnitude
	return distance <= Flare.Stats.revealRadius
end

--[[
	Check if dino should be attracted
]]
function Flare.ShouldAttractDino(flare: ActiveFlare, dinoPosition: Vector3): boolean
	-- Check if flare is active
	if tick() > flare.endTime then
		return false
	end

	-- Check if in attract radius
	local distance = (dinoPosition - flare.position).Magnitude
	if distance > Flare.Stats.dinoAttractRadius then
		return false
	end

	-- Random chance
	return math.random() < Flare.Stats.dinoAttractChance
end

--[[
	Check if flare is active
]]
function Flare.IsFlareActive(flare: ActiveFlare): boolean
	return tick() < flare.endTime
end

--[[
	Get remaining time
]]
function Flare.GetRemainingTime(flare: ActiveFlare): number
	return math.max(0, flare.endTime - tick())
end

return Flare
