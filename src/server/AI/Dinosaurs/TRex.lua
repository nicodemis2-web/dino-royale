--!strict
--[[
	TRex.lua
	========
	Apex predator boss dinosaur
	Multi-phase combat with special abilities
	Extremely dangerous, drops legendary loot
]]

local Players = game:GetService("Players")

local DinosaurBase = require(script.Parent.Parent.DinosaurBase)
local BehaviorTree = require(script.Parent.Parent.BehaviorTree)
local Events = require(game.ReplicatedStorage.Shared.Events)

local TRex = {}
TRex.__index = TRex
setmetatable(TRex, { __index = DinosaurBase })

-- Boss stats
local BOSS_HEALTH = 2000
local BOSS_DAMAGE = 100
local BOSS_SPEED = 25
local ARMOR_REDUCTION = 0.3 -- 30% damage reduction

-- Ability settings
local STOMP_DAMAGE = 50
local STOMP_RADIUS = 15
local STOMP_COOLDOWN = 8

local TAIL_SWIPE_DAMAGE = 60
local TAIL_SWIPE_ANGLE = 180 -- Behind the rex
local TAIL_SWIPE_RANGE = 12
local TAIL_SWIPE_COOLDOWN = 5

local ROAR_COOLDOWN = 15
local ROAR_FEAR_DURATION = 4
local ROAR_SLOW_AMOUNT = 0.5 -- 50% speed reduction

local SMELL_WOUNDED_RANGE = 50
local SMELL_WOUNDED_THRESHOLD = 50 -- HP

-- Phase thresholds
local PHASE_2_THRESHOLD = 0.66 -- 66% HP
local PHASE_3_THRESHOLD = 0.33 -- 33% HP

-- Phase enum (1 = Hunting, 2 = Enraged, 3 = Rampage)
type BossPhase = number

--[[
	Create a new T-Rex boss
	@param position Spawn position
	@return TRex instance
]]
function TRex.new(position: Vector3): any
	local self = setmetatable(DinosaurBase.new("TRex", position), TRex) :: any

	-- Override stats for boss
	self.stats.health = BOSS_HEALTH
	self.stats.maxHealth = BOSS_HEALTH
	self.stats.damage = BOSS_DAMAGE
	self.stats.speed = BOSS_SPEED
	self.stats.detectionRange = 100
	self.stats.attackRange = 8

	-- Boss-specific state
	self.currentPhase = 1 :: BossPhase
	self.lastStompTime = 0
	self.lastTailSwipeTime = 0
	self.lastRoarTime = 0
	self.territoryCenter = position
	self.territoryRadius = 150

	-- Track wounded players
	self.woundedTargets = {} :: { Player }

	return self
end

--[[
	Override TakeDamage to apply armor
]]
function TRex:TakeDamage(amount: number, source: Player?)
	-- Apply armor reduction
	local reducedDamage = amount * (1 - ARMOR_REDUCTION)

	-- Call base with reduced damage
	DinosaurBase.TakeDamage(self, reducedDamage, source)

	-- Check phase transitions
	self:CheckPhaseTransition()
end

--[[
	Check and handle phase transitions
]]
function TRex:CheckPhaseTransition()
	local healthPercent = self.stats.health / self.stats.maxHealth

	local newPhase: BossPhase = 1

	if healthPercent <= PHASE_3_THRESHOLD then
		newPhase = 3
	elseif healthPercent <= PHASE_2_THRESHOLD then
		newPhase = 2
	end

	if newPhase ~= self.currentPhase then
		self.currentPhase = newPhase
		self:OnPhaseChange(newPhase)
	end
end

--[[
	Handle phase change
]]
function TRex:OnPhaseChange(newPhase: BossPhase)
	-- Broadcast phase change
	Events.FireAllClients("Dinosaur", "BossPhaseChange", {
		dinoId = self.id,
		phase = newPhase,
	})

	-- Phase-specific effects
	if newPhase == 2 then
		-- Enraged - speed boost
		self.stats.speed = BOSS_SPEED * 1.2
		print(`[TRex] {self.id} entering Phase 2 - ENRAGED!`)
	elseif newPhase == 3 then
		-- Rampage - even faster
		self.stats.speed = BOSS_SPEED * 1.4
		print(`[TRex] {self.id} entering Phase 3 - RAMPAGE!`)
	end

	-- Roar on phase change
	self:Roar()
end

--[[
	Create T-Rex behavior tree
]]
function TRex:CreateDefaultBehaviorTree(): any
	local tree = BehaviorTree.Selector({
		-- Phase 3: Rampage - attack everything
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return self.currentPhase == 3
			end, "IsPhase3"),
			BehaviorTree.Action(function(ctx)
				return self:RampageAction(ctx)
			end, "Rampage"),
		}, "RampageSequence"),

		-- Smell wounded - hunt low HP players
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return self:CanSmellWounded()
			end, "CanSmellWounded"),
			BehaviorTree.Action(function(ctx)
				return self:HuntWoundedAction(ctx)
			end, "HuntWounded"),
		}, "SmellSequence"),

		-- Stomp if players nearby
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return self:CanStomp()
			end, "CanStomp"),
			BehaviorTree.Action(function(ctx)
				return self:StompAction(ctx)
			end, "Stomp"),
		}, "StompSequence"),

		-- Tail swipe if players behind
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return self:CanTailSwipe()
			end, "CanTailSwipe"),
			BehaviorTree.Action(function(ctx)
				return self:TailSwipeAction(ctx)
			end, "TailSwipe"),
		}, "TailSwipeSequence"),

		-- Roar to fear enemies
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return self:CanRoar() and ctx.target ~= nil
			end, "CanRoar"),
			BehaviorTree.Action(function(ctx)
				return self:RoarAction(ctx)
			end, "Roar"),
		}, "RoarSequence"),

		-- Bite attack if target in melee range
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return ctx.target ~= nil and self:IsInAttackRange(ctx.target)
			end, "TargetInMeleeRange"),
			BehaviorTree.Action(function(ctx)
				return self:BiteAction(ctx)
			end, "Bite"),
		}, "BiteSequence"),

		-- Chase target
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return ctx.target ~= nil
			end, "HasTarget"),
			BehaviorTree.Action(function(ctx)
				return ctx.dinosaur:ChaseAction(ctx)
			end, "Chase"),
		}, "ChaseSequence"),

		-- Default: Patrol territory
		BehaviorTree.Action(function(ctx)
			return self:PatrolAction(ctx)
		end, "Patrol"),
	}, "TRexRoot")

	return BehaviorTree.new(tree, self)
end

--[[
	Check if can smell wounded players
]]
function TRex:CanSmellWounded(): boolean
	self.woundedTargets = {}

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?

			if humanoid and rootPart and humanoid.Health < SMELL_WOUNDED_THRESHOLD then
				local distance = (rootPart.Position - self.currentPosition).Magnitude
				if distance <= SMELL_WOUNDED_RANGE then
					table.insert(self.woundedTargets, player)
				end
			end
		end
	end

	return #self.woundedTargets > 0
end

--[[
	Hunt wounded action - track wounded player through walls
]]
function TRex:HuntWoundedAction(context: any): string
	self:SetState("Chase")

	if #self.woundedTargets == 0 then
		return "Failure"
	end

	-- Target lowest HP wounded player
	local lowestHP = math.huge
	local targetPlayer: Player? = nil

	for _, player in ipairs(self.woundedTargets) do
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health < lowestHP then
				lowestHP = humanoid.Health
				targetPlayer = player
			end
		end
	end

	if targetPlayer then
		self.target = targetPlayer
		if self.behaviorTree then
			self.behaviorTree:SetTarget(targetPlayer)
		end
		context.target = targetPlayer

		local targetRoot = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if targetRoot then
			self:MoveTo(targetRoot.Position)
		end
	end

	return "Running"
end

--[[
	Check if can stomp
]]
function TRex:CanStomp(): boolean
	if tick() - self.lastStompTime < STOMP_COOLDOWN then
		return false
	end

	-- Check if players in stomp radius
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if rootPart then
				local distance = (rootPart.Position - self.currentPosition).Magnitude
				if distance <= STOMP_RADIUS then
					return true
				end
			end
		end
	end

	return false
end

--[[
	Ground stomp action - AoE damage
]]
function TRex:StompAction(context: any): string
	self:SetState("Attack")
	self.lastStompTime = tick()

	-- Broadcast stomp event
	Events.FireAllClients("Dinosaur", "TRexStomp", {
		dinoId = self.id,
		position = self.currentPosition,
		radius = STOMP_RADIUS,
	})

	-- Apply damage and stagger to all players in radius
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if rootPart then
				local distance = (rootPart.Position - self.currentPosition).Magnitude
				if distance <= STOMP_RADIUS then
					-- Apply damage
					local humanoid = character:FindFirstChildOfClass("Humanoid")
					if humanoid then
						humanoid:TakeDamage(STOMP_DAMAGE)
					end

					-- Apply stagger (launch up and stun)
					rootPart.AssemblyLinearVelocity = Vector3.new(0, 30, 0)

					-- Fire stagger effect
					Events.FireClient(player, "Combat", "StatusEffect", {
						effect = "Stagger",
						duration = 1.5,
					})
				end
			end
		end
	end

	print(`[TRex] {self.id} STOMP!`)

	return "Success"
end

--[[
	Check if can tail swipe
]]
function TRex:CanTailSwipe(): boolean
	if tick() - self.lastTailSwipeTime < TAIL_SWIPE_COOLDOWN then
		return false
	end

	-- Check for players behind
	local forward = self:GetForwardVector()

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if rootPart then
				local toPlayer = (rootPart.Position - self.currentPosition)
				local distance = toPlayer.Magnitude

				if distance <= TAIL_SWIPE_RANGE then
					-- Check if behind (negative dot product)
					local dot = forward:Dot(toPlayer.Unit)
					if dot < 0 then
						return true
					end
				end
			end
		end
	end

	return false
end

--[[
	Tail swipe action - cone attack behind
]]
function TRex:TailSwipeAction(context: any): string
	self:SetState("Attack")
	self.lastTailSwipeTime = tick()

	-- Broadcast tail swipe event
	Events.FireAllClients("Dinosaur", "TRexTailSwipe", {
		dinoId = self.id,
		position = self.currentPosition,
	})

	local forward = self:GetForwardVector()

	-- Hit all players in cone behind
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if rootPart then
				local toPlayer = (rootPart.Position - self.currentPosition)
				local distance = toPlayer.Magnitude

				if distance <= TAIL_SWIPE_RANGE then
					local dot = forward:Dot(toPlayer.Unit)
					-- Behind = negative dot, check if within angle
					local angle = math.deg(math.acos(math.clamp(dot, -1, 1)))
					if angle > (180 - TAIL_SWIPE_ANGLE / 2) then
						-- Hit!
						local humanoid = character:FindFirstChildOfClass("Humanoid")
						if humanoid then
							humanoid:TakeDamage(TAIL_SWIPE_DAMAGE)
						end

						-- Knockback
						local knockbackDir = toPlayer.Unit + Vector3.new(0, 0.3, 0)
						rootPart.AssemblyLinearVelocity = knockbackDir.Unit * 40

						print(`[TRex] Tail swipe hit {player.Name}!`)
					end
				end
			end
		end
	end

	return "Success"
end

--[[
	Check if can roar
]]
function TRex:CanRoar(): boolean
	return tick() - self.lastRoarTime >= ROAR_COOLDOWN
end

--[[
	Roar action - fear effect on nearby players
]]
function TRex:RoarAction(context: any): string
	self:Roar()
	return "Success"
end

--[[
	Perform roar
]]
function TRex:Roar()
	self:SetState("Alert")
	self.lastRoarTime = tick()

	-- Broadcast roar event
	Events.FireAllClients("Dinosaur", "TRexRoar", {
		dinoId = self.id,
		position = self.currentPosition,
	})

	-- Apply fear effect to all players in range
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if rootPart then
				local distance = (rootPart.Position - self.currentPosition).Magnitude
				if distance <= self.stats.detectionRange then
					-- Apply fear (slow)
					Events.FireClient(player, "Combat", "StatusEffect", {
						effect = "Fear",
						duration = ROAR_FEAR_DURATION,
						slowAmount = ROAR_SLOW_AMOUNT,
					})

					-- Reveal on minimap
					Events.FireClient(player, "Combat", "RevealPosition", {
						position = self.currentPosition,
						duration = 5,
					})
				end
			end
		end
	end

	print(`[TRex] {self.id} ROAR!`)
end

--[[
	Bite attack action
]]
function TRex:BiteAction(context: any): string
	self:SetState("Attack")

	if not context.target then
		return "Failure"
	end

	local attacked = self:Attack(context.target)
	return attacked and "Success" or "Running"
end

--[[
	Rampage action - attack nearest anything
]]
function TRex:RampageAction(context: any): string
	self:SetState("Attack")

	-- Find nearest player
	local nearestPlayer = self:FindNearestPlayer()
	if nearestPlayer then
		context.target = nearestPlayer
		self.target = nearestPlayer
		if self.behaviorTree then
			self.behaviorTree:SetTarget(nearestPlayer)
		end
	end

	-- Use abilities more frequently in rampage
	if self:CanStomp() and math.random() < 0.3 then
		return self:StompAction(context)
	end

	if self:CanTailSwipe() and math.random() < 0.3 then
		return self:TailSwipeAction(context)
	end

	-- Chase and attack
	if context.target then
		return self:ChaseAction(context)
	end

	return "Running"
end

--[[
	Patrol territory action
]]
function TRex:PatrolAction(context: any): string
	self:SetState("Patrol")

	-- Wander within territory
	local angle = math.random() * math.pi * 2
	local distance = math.random() * self.territoryRadius * 0.5
	local targetPos = self.territoryCenter + Vector3.new(
		math.cos(angle) * distance,
		0,
		math.sin(angle) * distance
	)

	self:MoveTo(targetPos)

	-- Scan for targets
	if self:ScanForTargets() then
		context.target = self.target
		if self.behaviorTree then
			self.behaviorTree:SetTarget(self.target)
		end
	end

	return "Success"
end

return TRex
