--!strict
--[[
	Spinosaurus.lua
	===============
	Epic tier swamp apex predator - semi-aquatic
	Largest carnivore on the island, dominates water areas
	Based on GDD Section 5.1: Dinosaur Roster
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DinosaurBase = require(script.Parent.Parent.DinosaurBase)

local Spinosaurus = {}
Spinosaurus.__index = Spinosaurus
setmetatable(Spinosaurus, { __index = DinosaurBase })

-- Spinosaurus stats
Spinosaurus.Stats = {
	name = "Spinosaurus",
	displayName = "Spinosaurus",
	tier = "Epic",

	-- Health (largest carnivore)
	maxHealth = 1200,

	-- Combat
	damage = 70,
	attackRange = 12, -- Long reach with claws
	attackCooldown = 2.2,
	tailSwipeDamage = 40,
	tailSwipeRange = 15,

	-- Movement
	walkSpeed = 12,
	runSpeed = 24,
	swimSpeed = 30, -- Excellent swimmer

	-- Detection
	visionRange = 100,
	visionAngle = 160,
	hearingRange = 70,
	waterDetectionRange = 150, -- Can detect movement in water from far

	-- Behavior
	aggroRange = 60,
	territoryRadius = 250, -- Large territory
	fleeHealthPercent = 0.1, -- Apex predator rarely flees

	-- Loot
	lootTable = {
		{ item = "EpicWeapon", chance = 0.6 },
		{ item = "EpicWeapon", chance = 0.3 }, -- Chance for second epic
		{ item = "Ammo_Heavy", chance = 0.9 },
		{ item = "MegaSerum", chance = 0.5 },
		{ item = "DinoAdrenaline", chance = 0.4 },
	},
	xpReward = 50,
}

-- Spinosaurus behavior state
export type SpinosaurusState = {
	isInWater: boolean,
	isSubmerged: boolean,
	lastWaterCheck: number,
	territoryCenter: Vector3,
	isDefendingTerritory: boolean,
	tailSwipeCooldown: number,
	lastRoarTime: number,
	dominanceDisplay: boolean,
}

--[[
	Create a new Spinosaurus
]]
function Spinosaurus.new(position: Vector3, config: any?): any
	local self = DinosaurBase.new(position, Spinosaurus.Stats, config)
	setmetatable(self, Spinosaurus)

	-- Spinosaurus-specific state
	self.spinoState = {
		isInWater = false,
		isSubmerged = false,
		lastWaterCheck = 0,
		territoryCenter = position,
		isDefendingTerritory = false,
		tailSwipeCooldown = 0,
		lastRoarTime = 0,
		dominanceDisplay = false,
	} :: SpinosaurusState

	-- Set as apex predator
	self.isApexPredator = true
	self.aggressionMultiplier = 1.3

	-- Set initial behavior
	self:SetBehavior("Patrol")

	return self
end

--[[
	Check if in water
]]
function Spinosaurus:IsInWater(position: Vector3?): boolean
	local checkPos = position or self.position
	local waterLevel = 25
	return checkPos.Y < waterLevel
end

--[[
	Check if submerged (deeper water)
]]
function Spinosaurus:IsSubmerged(position: Vector3?): boolean
	local checkPos = position or self.position
	local deepWaterLevel = 15
	return checkPos.Y < deepWaterLevel
end

--[[
	Update water state
]]
function Spinosaurus:UpdateWaterState()
	local now = tick()
	if now - self.spinoState.lastWaterCheck < 0.5 then return end

	self.spinoState.lastWaterCheck = now
	self.spinoState.isInWater = self:IsInWater()
	self.spinoState.isSubmerged = self:IsSubmerged()

	-- Adjust speed based on water depth
	if self.spinoState.isSubmerged then
		self.currentSpeed = Spinosaurus.Stats.swimSpeed
	elseif self.spinoState.isInWater then
		self.currentSpeed = (Spinosaurus.Stats.swimSpeed + Spinosaurus.Stats.runSpeed) / 2
	else
		self.currentSpeed = self.isRunning and Spinosaurus.Stats.runSpeed or Spinosaurus.Stats.walkSpeed
	end
end

--[[
	Tail swipe attack - hits multiple targets
]]
function Spinosaurus:TailSwipe()
	if tick() - self.spinoState.tailSwipeCooldown < 5 then return false end

	self.spinoState.tailSwipeCooldown = tick()

	-- Get all targets in tail swipe range
	local nearbyTargets = self:GetNearbyTargets(Spinosaurus.Stats.tailSwipeRange)
	local hitTargets = {}

	-- Tail swipe hits targets behind and to the sides
	for _, target in ipairs(nearbyTargets) do
		local targetPos = target.position or target.Position
		local toTarget = (targetPos - self.position).Unit
		local forward = self.facing or Vector3.new(0, 0, 1)

		local dot = toTarget:Dot(forward)

		-- Hit targets that are not directly in front (sides and behind)
		if dot < 0.5 then
			table.insert(hitTargets, target)
		end
	end

	-- Apply damage to all hit targets
	for _, target in ipairs(hitTargets) do
		if self.onAttack then
			self.onAttack(target, Spinosaurus.Stats.tailSwipeDamage, "TailSwipe", {
				knockback = ((target.position or target.Position) - self.position).Unit * 20,
			})
		end
	end

	return #hitTargets > 0
end

--[[
	Dominance roar - intimidates other dinosaurs and players
]]
function Spinosaurus:DominanceRoar()
	if tick() - self.spinoState.lastRoarTime < 30 then return end

	self.spinoState.lastRoarTime = tick()
	self.spinoState.dominanceDisplay = true

	-- Play roar
	if self.onRoar then
		self.onRoar("DominanceRoar")
	end

	-- Affect nearby entities
	local nearbyTargets = self:GetNearbyTargets(80)
	for _, target in ipairs(nearbyTargets) do
		-- Other dinosaurs flee
		if target.isDinosaur and not target.isApexPredator then
			if target.SetBehavior then
				target:SetBehavior("Flee")
				target.fleeTarget = self.position
			end
		end

		-- Players get intimidation debuff
		if target.isPlayer and self.onIntimidation then
			self.onIntimidation(target, {
				fearEffect = true,
				accuracyDebuff = 0.7,
				duration = 5,
			})
		end
	end

	task.delay(3, function()
		self.spinoState.dominanceDisplay = false
	end)
end

--[[
	Override patrol - territory patrol with water preference
]]
function Spinosaurus:Patrol()
	self:UpdateWaterState()

	-- Check territory boundaries
	local distFromTerritory = (self.position - self.spinoState.territoryCenter).Magnitude

	if distFromTerritory > Spinosaurus.Stats.territoryRadius * 0.8 then
		-- Return toward territory center
		self:MoveTo(self.spinoState.territoryCenter)
		return
	end

	-- Prefer patrolling near water
	if not self.spinoState.isInWater and math.random() < 0.3 then
		-- Move toward water
		local waterOffset = Vector3.new(
			math.random(-50, 50),
			-10, -- Move toward lower elevation (water)
			math.random(-50, 50)
		)
		self:MoveTo(self.spinoState.territoryCenter + waterOffset)
	else
		-- Standard patrol
		local patrolPoint = self.spinoState.territoryCenter + Vector3.new(
			math.random(-100, 100),
			0,
			math.random(-100, 100)
		)
		self:MoveTo(patrolPoint)
	end

	-- Occasional dominance display
	if math.random() < 0.01 then
		self:DominanceRoar()
	end
end

--[[
	Override attack - powerful bite with occasional tail swipe
]]
function Spinosaurus:Attack(target: any)
	if not self:CanAttack() then return end

	local targetPos = target.position or target.Position
	local distToTarget = (self.position - targetPos).Magnitude

	-- Use tail swipe if target is close but not directly in front
	if distToTarget < Spinosaurus.Stats.tailSwipeRange then
		local toTarget = (targetPos - self.position).Unit
		local forward = self.facing or Vector3.new(0, 0, 1)
		local dot = toTarget:Dot(forward)

		if dot < 0.3 and math.random() < 0.5 then
			if self:TailSwipe() then
				return
			end
		end
	end

	-- Standard bite attack
	local damage = Spinosaurus.Stats.damage

	-- Bonus damage in water
	if self.spinoState.isInWater then
		damage = damage * 1.2
	end

	-- Extra damage if target is in water (death roll style)
	if self:IsInWater(targetPos) then
		damage = damage * 1.3
	end

	self.lastAttackTime = tick()

	-- Fire attack event
	if self.onAttack then
		self.onAttack(target, damage, "Bite", {
			grab = self.spinoState.isInWater, -- Can grab and drag in water
		})
	end

	return damage
end

--[[
	Override chase - powerful but not as fast on land
]]
function Spinosaurus:Chase(target: any)
	self:UpdateWaterState()

	local targetPos = target.position or target.Position
	local distToTarget = (self.position - targetPos).Magnitude

	-- Check if target is entering territory
	local targetDistFromTerritory = (targetPos - self.spinoState.territoryCenter).Magnitude
	if targetDistFromTerritory < Spinosaurus.Stats.territoryRadius then
		self.spinoState.isDefendingTerritory = true
	end

	-- More aggressive pursuit in water
	if self.spinoState.isInWater or self:IsInWater(targetPos) then
		self.isRunning = true
		self.currentSpeed = Spinosaurus.Stats.swimSpeed
	else
		-- Slightly slower on pure land
		self.isRunning = true
		self.currentSpeed = Spinosaurus.Stats.runSpeed
	end

	self:MoveTo(targetPos)

	-- Attack if in range
	if distToTarget <= Spinosaurus.Stats.attackRange then
		self:Attack(target)
	elseif distToTarget <= Spinosaurus.Stats.tailSwipeRange and math.random() < 0.3 then
		self:TailSwipe()
	end
end

--[[
	Override detection - water detection bonus
]]
function Spinosaurus:DetectTargets(): { any }
	local targets = DinosaurBase.DetectTargets(self)

	-- Enhanced detection for targets in water
	if self.spinoState.isInWater then
		-- Would add water-based detection here
		-- For now, just increase detection range in water
	end

	-- Auto-aggro on territory intruders
	for _, target in ipairs(targets) do
		local targetPos = target.position or target.Position
		local distFromTerritory = (targetPos - self.spinoState.territoryCenter).Magnitude

		if distFromTerritory < Spinosaurus.Stats.territoryRadius * 0.5 then
			-- Intruder in core territory - attack
			if self.currentBehavior ~= "Chase" then
				self:SetBehavior("Chase")
				self.currentTarget = target
				self.spinoState.isDefendingTerritory = true
				self:DominanceRoar()
				break
			end
		end
	end

	return targets
end

--[[
	Override update
]]
function Spinosaurus:Update(deltaTime: number)
	self:UpdateWaterState()

	-- Reset territory defense if no threats
	if self.spinoState.isDefendingTerritory and self.currentBehavior == "Patrol" then
		self.spinoState.isDefendingTerritory = false
	end

	DinosaurBase.Update(self, deltaTime)
end

--[[
	Override take damage - extremely aggressive when hurt
]]
function Spinosaurus:TakeDamage(amount: number, source: any?)
	DinosaurBase.TakeDamage(self, amount, source)

	-- Enrage
	self.aggressionMultiplier = math.min(2.0, self.aggressionMultiplier + 0.15)

	-- Immediate dominance roar
	if math.random() < 0.5 then
		self:DominanceRoar()
	end

	-- Chase attacker
	if source then
		self.currentTarget = source
		self:SetBehavior("Chase")
		self.spinoState.isDefendingTerritory = true
	end
end

--[[
	Get display info
]]
function Spinosaurus:GetDisplayInfo(): any
	local baseInfo = DinosaurBase.GetDisplayInfo(self)
	baseInfo.isInWater = self.spinoState.isInWater
	baseInfo.isSubmerged = self.spinoState.isSubmerged
	baseInfo.isDefendingTerritory = self.spinoState.isDefendingTerritory
	baseInfo.dominanceDisplay = self.spinoState.dominanceDisplay
	return baseInfo
end

return Spinosaurus
