--!strict
--[[
	Baryonyx.lua
	============
	Rare water-hunting dinosaur that patrols near rivers and swamps
	Based on GDD Section 5.1: Dinosaur Roster
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DinosaurBase = require(script.Parent.Parent.DinosaurBase)

local Baryonyx = {}
Baryonyx.__index = Baryonyx
setmetatable(Baryonyx, { __index = DinosaurBase })

-- Baryonyx stats
Baryonyx.Stats = {
	name = "Baryonyx",
	displayName = "Baryonyx",
	tier = "Rare",

	-- Health
	maxHealth = 400,

	-- Combat
	damage = 35,
	attackRange = 8,
	attackCooldown = 1.8,

	-- Movement
	walkSpeed = 14,
	runSpeed = 26,
	swimSpeed = 32, -- Faster in water

	-- Detection
	visionRange = 80,
	visionAngle = 140,
	hearingRange = 60,

	-- Behavior
	aggroRange = 50,
	territoryRadius = 120,
	fleeHealthPercent = 0.15,

	-- Loot
	lootTable = {
		{ item = "RareWeapon", chance = 0.4 },
		{ item = "Ammo_Medium", chance = 0.8 },
		{ item = "MedKit", chance = 0.5 },
		{ item = "ShieldSerum", chance = 0.3 },
	},
	xpReward = 25,
}

-- Water behavior state
export type BaryonyxState = {
	isInWater: boolean,
	lastWaterCheck: number,
	preferredWaterSource: Vector3?,
	huntingInWater: boolean,
	fishingMode: boolean,
}

--[[
	Create a new Baryonyx
]]
function Baryonyx.new(position: Vector3, config: any?): any
	local self = DinosaurBase.new(position, Baryonyx.Stats, config)
	setmetatable(self, Baryonyx)

	-- Baryonyx-specific state
	self.baryonyxState = {
		isInWater = false,
		lastWaterCheck = 0,
		preferredWaterSource = nil,
		huntingInWater = false,
		fishingMode = false,
	} :: BaryonyxState

	-- Set initial behavior
	self:SetBehavior("Patrol")

	return self
end

--[[
	Check if position is in water
]]
function Baryonyx:IsInWater(position: Vector3?): boolean
	local checkPos = position or self.position

	-- Simplified water check - in real implementation would raycast
	-- Baryonyx prefers swamp biome water areas
	local waterLevel = 25 -- Approximate water level in swamp
	return checkPos.Y < waterLevel
end

--[[
	Find nearest water source
]]
function Baryonyx:FindNearestWater(): Vector3?
	-- Known water locations in swamp biome
	local waterSources = {
		Vector3.new(3200, 20, 2000), -- River Delta
		Vector3.new(3000, 18, 2200), -- Boat Dock area
		Vector3.new(3400, 22, 1800), -- Research Outpost waters
	}

	local nearest: Vector3? = nil
	local nearestDist = math.huge

	for _, source in ipairs(waterSources) do
		local dist = (self.position - source).Magnitude
		if dist < nearestDist then
			nearestDist = dist
			nearest = source
		end
	end

	return nearest
end

--[[
	Update water state
]]
function Baryonyx:UpdateWaterState()
	local now = tick()
	if now - self.baryonyxState.lastWaterCheck < 1 then return end

	self.baryonyxState.lastWaterCheck = now
	self.baryonyxState.isInWater = self:IsInWater()

	-- Adjust speed based on water
	if self.baryonyxState.isInWater then
		self.currentSpeed = Baryonyx.Stats.swimSpeed
	else
		self.currentSpeed = self.isRunning and Baryonyx.Stats.runSpeed or Baryonyx.Stats.walkSpeed
	end
end

--[[
	Override patrol to prefer water areas
]]
function Baryonyx:Patrol()
	self:UpdateWaterState()

	-- If not near water, move toward it
	if not self.baryonyxState.isInWater and not self.baryonyxState.preferredWaterSource then
		self.baryonyxState.preferredWaterSource = self:FindNearestWater()
	end

	-- Patrol near water
	if self.baryonyxState.preferredWaterSource then
		local distToWater = (self.position - self.baryonyxState.preferredWaterSource).Magnitude

		if distToWater > 50 then
			-- Move toward water
			self:MoveTo(self.baryonyxState.preferredWaterSource)
		else
			-- Patrol around water source
			local offset = Vector3.new(
				math.random(-40, 40),
				0,
				math.random(-40, 40)
			)
			self:MoveTo(self.baryonyxState.preferredWaterSource + offset)
		end
	else
		-- Default patrol
		DinosaurBase.Patrol(self)
	end
end

--[[
	Override attack - more effective in water
]]
function Baryonyx:Attack(target: any)
	if not self:CanAttack() then return end

	local damage = Baryonyx.Stats.damage

	-- Bonus damage if attacking from water
	if self.baryonyxState.isInWater then
		damage = damage * 1.25 -- 25% bonus in water
	end

	-- Check if target is in water (extra effective)
	if self:IsInWater(target.position) then
		damage = damage * 1.15 -- Additional 15% vs targets in water
	end

	self.lastAttackTime = tick()

	-- Fire attack event
	if self.onAttack then
		self.onAttack(target, damage, "Bite")
	end

	return damage
end

--[[
	Override chase - can pursue into water
]]
function Baryonyx:Chase(target: any)
	self:UpdateWaterState()

	local targetPos = target.position or target.Position
	local targetInWater = self:IsInWater(targetPos)

	-- Baryonyx is more aggressive when target enters water
	if targetInWater and not self.baryonyxState.huntingInWater then
		self.baryonyxState.huntingInWater = true
		self.aggressionMultiplier = 1.5 -- More aggressive in water hunts
	end

	-- Maintain pursuit through water
	DinosaurBase.Chase(self, target)
end

--[[
	Water ambush behavior
]]
function Baryonyx:WaterAmbush()
	if not self.baryonyxState.isInWater then return false end

	-- Look for nearby targets on shore
	local nearbyTargets = self:GetNearbyTargets(Baryonyx.Stats.visionRange)

	for _, target in ipairs(nearbyTargets) do
		local targetPos = target.position or target.Position
		local targetInWater = self:IsInWater(targetPos)

		-- Target near water but not in it - good ambush opportunity
		if not targetInWater then
			local distToTarget = (self.position - targetPos).Magnitude
			if distToTarget < 30 then
				-- Launch ambush attack
				self:SetBehavior("Chase")
				self.currentTarget = target
				self.baryonyxState.huntingInWater = true
				return true
			end
		end
	end

	return false
end

--[[
	Fishing behavior (idle in water)
]]
function Baryonyx:Fish()
	if not self.baryonyxState.isInWater then
		self.baryonyxState.fishingMode = false
		return
	end

	self.baryonyxState.fishingMode = true

	-- Stay relatively still, occasionally move
	if math.random() < 0.1 then
		local smallMove = self.position + Vector3.new(
			math.random(-5, 5),
			0,
			math.random(-5, 5)
		)
		self:MoveTo(smallMove)
	end
end

--[[
	Override update
]]
function Baryonyx:Update(deltaTime: number)
	self:UpdateWaterState()

	-- Check for ambush opportunities when in water
	if self.baryonyxState.isInWater and self.currentBehavior == "Patrol" then
		if self:WaterAmbush() then
			return
		end
	end

	-- Random chance to fish when idle in water
	if self.baryonyxState.isInWater and self.currentBehavior == "Idle" then
		if math.random() < 0.3 then
			self:Fish()
			return
		end
	end

	DinosaurBase.Update(self, deltaTime)
end

--[[
	Override take damage - retreats to water when hurt
]]
function Baryonyx:TakeDamage(amount: number, source: any?)
	DinosaurBase.TakeDamage(self, amount, source)

	-- If badly hurt and not in water, flee to water
	local healthPercent = self.health / Baryonyx.Stats.maxHealth
	if healthPercent < 0.4 and not self.baryonyxState.isInWater then
		local waterSource = self:FindNearestWater()
		if waterSource then
			self:SetBehavior("Flee")
			self.fleeTarget = waterSource
		end
	end
end

--[[
	Get display info
]]
function Baryonyx:GetDisplayInfo(): any
	local baseInfo = DinosaurBase.GetDisplayInfo(self)
	baseInfo.isInWater = self.baryonyxState.isInWater
	baseInfo.isHunting = self.baryonyxState.huntingInWater
	return baseInfo
end

return Baryonyx
