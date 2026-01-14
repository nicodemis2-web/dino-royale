--!strict
--[[
	Carnotaurus.lua
	===============
	Epic tier aggressive pursuit predator
	Known for relentless chasing and high speed
	Based on GDD Section 5.1: Dinosaur Roster
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DinosaurBase = require(script.Parent.Parent.DinosaurBase)

local Carnotaurus = {}
Carnotaurus.__index = Carnotaurus
setmetatable(Carnotaurus, { __index = DinosaurBase })

-- Carnotaurus stats
Carnotaurus.Stats = {
	name = "Carnotaurus",
	displayName = "Carnotaurus",
	tier = "Epic",

	-- Health
	maxHealth = 800,

	-- Combat
	damage = 60,
	attackRange = 10,
	attackCooldown = 2.0,
	chargeRange = 40, -- Can charge attack
	chargeDamage = 90, -- Damage on charge hit

	-- Movement
	walkSpeed = 16,
	runSpeed = 34, -- Very fast runner
	chargeSpeed = 45, -- Even faster when charging

	-- Detection
	visionRange = 120,
	visionAngle = 100, -- Narrow forward vision (small arms, relies on speed)
	hearingRange = 80,

	-- Behavior
	aggroRange = 80,
	territoryRadius = 200,
	pursuitDuration = 30, -- Will chase for 30 seconds
	fleeHealthPercent = 0.1, -- Rarely flees

	-- Loot
	lootTable = {
		{ item = "EpicWeapon", chance = 0.5 },
		{ item = "Ammo_Heavy", chance = 0.7 },
		{ item = "MegaSerum", chance = 0.4 },
		{ item = "DinoAdrenaline", chance = 0.3 },
	},
	xpReward = 50,
}

-- Pursuit state
export type CarnotaurusState = {
	isCharging: boolean,
	chargeStartTime: number,
	chargeDirection: Vector3?,
	pursuitStartTime: number,
	pursuitTarget: any?,
	chargesCooldown: number,
	stamina: number,
	maxStamina: number,
	isExhausted: boolean,
}

--[[
	Create a new Carnotaurus
]]
function Carnotaurus.new(position: Vector3, config: any?): any
	local self = DinosaurBase.new(position, Carnotaurus.Stats, config)
	setmetatable(self, Carnotaurus)

	-- Carnotaurus-specific state
	self.carnoState = {
		isCharging = false,
		chargeStartTime = 0,
		chargeDirection = nil,
		pursuitStartTime = 0,
		pursuitTarget = nil,
		chargesCooldown = 0,
		stamina = 100,
		maxStamina = 100,
		isExhausted = false,
	} :: CarnotaurusState

	-- High aggression
	self.aggressionMultiplier = 1.5

	-- Set initial behavior
	self:SetBehavior("Patrol")

	return self
end

--[[
	Check if can initiate charge
]]
function Carnotaurus:CanCharge(): boolean
	if self.carnoState.isCharging then return false end
	if self.carnoState.isExhausted then return false end
	if tick() - self.carnoState.chargesCooldown < 8 then return false end
	if self.carnoState.stamina < 30 then return false end

	return true
end

--[[
	Start charge attack
]]
function Carnotaurus:StartCharge(targetPosition: Vector3)
	if not self:CanCharge() then return false end

	self.carnoState.isCharging = true
	self.carnoState.chargeStartTime = tick()
	self.carnoState.chargeDirection = (targetPosition - self.position).Unit

	-- Consume stamina
	self.carnoState.stamina = self.carnoState.stamina - 30

	-- Play charge roar
	if self.onRoar then
		self.onRoar("ChargeRoar")
	end

	return true
end

--[[
	Update charge attack
]]
function Carnotaurus:UpdateCharge(deltaTime: number)
	if not self.carnoState.isCharging then return end

	local chargeDuration = tick() - self.carnoState.chargeStartTime
	local maxChargeDuration = 2.5 -- Charge for up to 2.5 seconds

	-- End charge after max duration
	if chargeDuration >= maxChargeDuration then
		self:EndCharge()
		return
	end

	-- Move in charge direction at charge speed
	if self.carnoState.chargeDirection then
		local chargeMovement = self.carnoState.chargeDirection * Carnotaurus.Stats.chargeSpeed * deltaTime
		self.position = self.position + chargeMovement

		-- Check for collision with targets
		local nearbyTargets = self:GetNearbyTargets(Carnotaurus.Stats.attackRange)
		for _, target in ipairs(nearbyTargets) do
			local dist = (self.position - (target.position or target.Position)).Magnitude
			if dist < Carnotaurus.Stats.attackRange then
				self:ChargeHit(target)
				self:EndCharge()
				return
			end
		end
	end
end

--[[
	Handle charge hit
]]
function Carnotaurus:ChargeHit(target: any)
	-- Deal charge damage
	local damage = Carnotaurus.Stats.chargeDamage

	-- Fire attack event with knockback
	if self.onAttack then
		self.onAttack(target, damage, "Charge", {
			knockback = self.carnoState.chargeDirection * 30,
			stun = 1.5, -- Stun for 1.5 seconds
		})
	end
end

--[[
	End charge
]]
function Carnotaurus:EndCharge()
	self.carnoState.isCharging = false
	self.carnoState.chargeDirection = nil
	self.carnoState.chargesCooldown = tick()

	-- Brief recovery period
	self.carnoState.stamina = math.max(0, self.carnoState.stamina - 10)
end

--[[
	Update stamina
]]
function Carnotaurus:UpdateStamina(deltaTime: number)
	if self.carnoState.isCharging then return end

	-- Regenerate stamina when not charging
	local regenRate = 5 -- Per second
	if self.currentBehavior == "Idle" or self.currentBehavior == "Patrol" then
		regenRate = 10 -- Faster regen when calm
	end

	self.carnoState.stamina = math.min(
		self.carnoState.maxStamina,
		self.carnoState.stamina + regenRate * deltaTime
	)

	-- Check exhaustion
	if self.carnoState.stamina <= 0 then
		self.carnoState.isExhausted = true
	elseif self.carnoState.stamina >= 50 then
		self.carnoState.isExhausted = false
	end
end

--[[
	Override chase - relentless pursuit
]]
function Carnotaurus:Chase(target: any)
	local targetPos = target.position or target.Position
	local distToTarget = (self.position - targetPos).Magnitude

	-- Start pursuit tracking
	if not self.carnoState.pursuitTarget or self.carnoState.pursuitTarget ~= target then
		self.carnoState.pursuitTarget = target
		self.carnoState.pursuitStartTime = tick()
	end

	-- Check pursuit duration
	local pursuitTime = tick() - self.carnoState.pursuitStartTime
	if pursuitTime > Carnotaurus.Stats.pursuitDuration then
		-- Give up pursuit after max time
		self:SetBehavior("Patrol")
		self.carnoState.pursuitTarget = nil
		return
	end

	-- Attempt charge if in range and can charge
	if distToTarget > 15 and distToTarget < Carnotaurus.Stats.chargeRange then
		if self:CanCharge() and math.random() < 0.4 then
			self:StartCharge(targetPos)
			return
		end
	end

	-- Standard chase with high speed
	self.isRunning = true
	self.currentSpeed = Carnotaurus.Stats.runSpeed

	-- Predict target movement for interception
	local targetVelocity = target.velocity or Vector3.zero
	local predictedPos = targetPos + targetVelocity * 0.5

	self:MoveTo(predictedPos)

	-- Attack if in range
	if distToTarget <= Carnotaurus.Stats.attackRange then
		self:Attack(target)
	end
end

--[[
	Override attack - powerful bite
]]
function Carnotaurus:Attack(target: any)
	if not self:CanAttack() then return end
	if self.carnoState.isCharging then return end -- Don't bite while charging

	local damage = Carnotaurus.Stats.damage

	-- Bonus damage on weakened targets
	if target.health and target.maxHealth then
		local targetHealthPercent = target.health / target.maxHealth
		if targetHealthPercent < 0.3 then
			damage = damage * 1.25 -- 25% bonus on low health targets
		end
	end

	self.lastAttackTime = tick()

	-- Consume some stamina on attack
	self.carnoState.stamina = math.max(0, self.carnoState.stamina - 5)

	-- Fire attack event
	if self.onAttack then
		self.onAttack(target, damage, "Bite")
	end

	return damage
end

--[[
	Roar behavior - intimidation
]]
function Carnotaurus:Roar()
	if self.onRoar then
		self.onRoar("IntimidationRoar")
	end

	-- Roar can cause nearby players to have reduced accuracy
	local nearbyTargets = self:GetNearbyTargets(30)
	for _, target in ipairs(nearbyTargets) do
		if self.onIntimidation then
			self.onIntimidation(target, {
				accuracyDebuff = 0.8,
				duration = 3,
			})
		end
	end
end

--[[
	Override update
]]
function Carnotaurus:Update(deltaTime: number)
	-- Update stamina
	self:UpdateStamina(deltaTime)

	-- Update charge if charging
	if self.carnoState.isCharging then
		self:UpdateCharge(deltaTime)
		return
	end

	-- Occasional roar when patrolling
	if self.currentBehavior == "Patrol" and math.random() < 0.002 then
		self:Roar()
	end

	-- If exhausted, switch to recovery
	if self.carnoState.isExhausted and self.currentBehavior == "Chase" then
		self:SetBehavior("Idle")
		return
	end

	DinosaurBase.Update(self, deltaTime)
end

--[[
	Override detection - high aggression
]]
function Carnotaurus:DetectTargets(): { any }
	local targets = DinosaurBase.DetectTargets(self)

	-- Carnotaurus is more likely to aggro
	for _, target in ipairs(targets) do
		local dist = (self.position - (target.position or target.Position)).Magnitude

		-- Automatically aggro on targets within aggro range
		if dist < Carnotaurus.Stats.aggroRange and not self.carnoState.isExhausted then
			if self.currentBehavior ~= "Chase" then
				self:SetBehavior("Chase")
				self.currentTarget = target
				self.carnoState.pursuitTarget = target
				self.carnoState.pursuitStartTime = tick()
				break
			end
		end
	end

	return targets
end

--[[
	Override take damage - enrages when hurt
]]
function Carnotaurus:TakeDamage(amount: number, source: any?)
	DinosaurBase.TakeDamage(self, amount, source)

	-- Enrage on taking damage
	self.aggressionMultiplier = math.min(2.0, self.aggressionMultiplier + 0.1)

	-- If source is known, prioritize that target
	if source and self.currentBehavior ~= "Flee" then
		self.currentTarget = source
		self:SetBehavior("Chase")
		self.carnoState.pursuitTarget = source
		self.carnoState.pursuitStartTime = tick()
	end
end

--[[
	Get display info
]]
function Carnotaurus:GetDisplayInfo(): any
	local baseInfo = DinosaurBase.GetDisplayInfo(self)
	baseInfo.isCharging = self.carnoState.isCharging
	baseInfo.stamina = self.carnoState.stamina
	baseInfo.isExhausted = self.carnoState.isExhausted
	baseInfo.pursuitTime = self.carnoState.pursuitTarget and (tick() - self.carnoState.pursuitStartTime) or 0
	return baseInfo
end

return Carnotaurus
