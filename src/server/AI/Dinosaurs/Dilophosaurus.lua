--!strict
--[[
	Dilophosaurus.lua
	=================
	Territorial, defensive dinosaur that spits venom
	Warns intruders before attacking
]]

local DinosaurBase = require(script.Parent.Parent.DinosaurBase)
local BehaviorTree = require(script.Parent.Parent.BehaviorTree)
local Events = require(game.ReplicatedStorage.Shared.Events)

local Dilophosaurus = {}
Dilophosaurus.__index = Dilophosaurus
setmetatable(Dilophosaurus, { __index = DinosaurBase })

-- Territory settings
local TERRITORY_RADIUS = 30
local WARNING_DURATION = 3 -- Seconds to leave before attack
local SPIT_RANGE = 15
local SPIT_DAMAGE = 15
local SPIT_BLIND_DURATION = 5
local SPIT_COOLDOWN = 4
local MELEE_RANGE = 4

--[[
	Create a new Dilophosaurus
	@param position Spawn position
	@return Dilophosaurus instance
]]
function Dilophosaurus.new(position: Vector3): any
	local self = setmetatable(DinosaurBase.new("Dilophosaurus", position), Dilophosaurus) :: any

	-- Override stats
	self.stats.damage = 15
	self.stats.attackRange = MELEE_RANGE

	-- Dilo-specific state
	self.territoryCenter = position
	self.isWarning = false
	self.warningTarget = nil :: Player?
	self.warningEndTime = 0
	self.lastSpitTime = 0
	self.spitCooldown = SPIT_COOLDOWN

	return self
end

--[[
	Create dilo-specific behavior tree
]]
function Dilophosaurus:CreateDefaultBehaviorTree(): any
	local tree = BehaviorTree.Selector({
		-- Flee if very low health
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return ctx.dinosaur.stats.health < ctx.dinosaur.stats.maxHealth * 0.15
			end, "VeryLowHealth"),
			BehaviorTree.Action(function(ctx)
				return ctx.dinosaur:FleeAction(ctx)
			end, "Flee"),
		}, "FleeSequence"),

		-- Melee attack if in melee range
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return ctx.target ~= nil and self:IsInMeleeRange(ctx.target)
			end, "InMeleeRange"),
			BehaviorTree.Action(function(ctx)
				return ctx.dinosaur:AttackAction(ctx)
			end, "MeleeAttack"),
		}, "MeleeSequence"),

		-- Venom spit if target in spit range but not too close
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return ctx.target ~= nil and self:CanSpit(ctx.target)
			end, "CanSpit"),
			BehaviorTree.Action(function(ctx)
				return self:SpitAction(ctx)
			end, "VenomSpit"),
		}, "SpitSequence"),

		-- Warning display if player in territory
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return self:HasIntruder() and not self.isWarning
			end, "HasIntruder"),
			BehaviorTree.Action(function(ctx)
				return self:StartWarning(ctx)
			end, "StartWarning"),
		}, "WarningStartSequence"),

		-- Continue warning (frill display)
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return self.isWarning
			end, "IsWarning"),
			BehaviorTree.Action(function(ctx)
				return self:WarningAction(ctx)
			end, "WarningDisplay"),
		}, "WarningSequence"),

		-- Chase if has target (player didn't leave after warning)
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
			return self:PatrolTerritoryAction(ctx)
		end, "PatrolTerritory"),
	}, "DiloRoot")

	return BehaviorTree.new(tree, self)
end

--[[
	Check if player is in melee range
]]
function Dilophosaurus:IsInMeleeRange(target: Player): boolean
	local character = target.Character
	if not character then
		return false
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return false
	end

	local distance = (rootPart.Position - self.currentPosition).Magnitude
	return distance <= MELEE_RANGE
end

--[[
	Check if can spit at target (in range, not too close, off cooldown)
]]
function Dilophosaurus:CanSpit(target: Player): boolean
	local character = target.Character
	if not character then
		return false
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return false
	end

	local distance = (rootPart.Position - self.currentPosition).Magnitude

	-- Check range and cooldown
	return distance <= SPIT_RANGE
		and distance > MELEE_RANGE
		and tick() - self.lastSpitTime >= self.spitCooldown
end

--[[
	Check if there's an intruder in territory
]]
function Dilophosaurus:HasIntruder(): boolean
	local Players = game:GetService("Players")

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if rootPart then
				local distance = (rootPart.Position - self.territoryCenter).Magnitude
				if distance <= TERRITORY_RADIUS then
					return true
				end
			end
		end
	end

	return false
end

--[[
	Find the nearest intruder in territory
]]
function Dilophosaurus:FindIntruder(): Player?
	local Players = game:GetService("Players")
	local nearestPlayer: Player? = nil
	local nearestDistance = math.huge

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if rootPart then
				local distanceToTerritory = (rootPart.Position - self.territoryCenter).Magnitude
				local distanceToSelf = (rootPart.Position - self.currentPosition).Magnitude

				if distanceToTerritory <= TERRITORY_RADIUS and distanceToSelf < nearestDistance then
					nearestDistance = distanceToSelf
					nearestPlayer = player
				end
			end
		end
	end

	return nearestPlayer
end

--[[
	Start warning display
]]
function Dilophosaurus:StartWarning(context: any): string
	local intruder = self:FindIntruder()
	if not intruder then
		return "Failure"
	end

	self:SetState("Alert")
	self.isWarning = true
	self.warningTarget = intruder
	self.warningEndTime = tick() + WARNING_DURATION

	-- Broadcast warning event (for client visual effects)
	Events.FireAllClients("Dinosaur", "DinosaurWarning", {
		dinoId = self.id,
		targetId = intruder.UserId,
		duration = WARNING_DURATION,
	})

	print(`[Dilophosaurus] {self.id} warning {intruder.Name}!`)

	return "Success"
end

--[[
	Warning action - frill display, facing intruder
]]
function Dilophosaurus:WarningAction(context: any): string
	self:SetState("Alert")

	-- Check if warning period is over
	if tick() >= self.warningEndTime then
		self.isWarning = false

		-- Check if intruder is still in territory
		if self.warningTarget then
			local character = self.warningTarget.Character
			if character then
				local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if rootPart then
					local distance = (rootPart.Position - self.territoryCenter).Magnitude
					if distance <= TERRITORY_RADIUS then
						-- They didn't leave - attack!
						self.target = self.warningTarget
						if self.behaviorTree then
							self.behaviorTree:SetTarget(self.warningTarget)
						end
						print(`[Dilophosaurus] {self.id} attacking - intruder didn't leave!`)
					end
				end
			end
		end

		self.warningTarget = nil
		return "Success"
	end

	-- Face the intruder
	if self.warningTarget and self.warningTarget.Character then
		local targetRoot = self.warningTarget.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if targetRoot and self.model then
			local rootPart = self.model:FindFirstChild("HumanoidRootPart") :: BasePart?
				or self.model.PrimaryPart
			if rootPart then
				local lookAt = Vector3.new(targetRoot.Position.X, rootPart.Position.Y, targetRoot.Position.Z)
				rootPart.CFrame = CFrame.new(rootPart.Position, lookAt)
			end
		end
	end

	return "Running"
end

--[[
	Venom spit action
]]
function Dilophosaurus:SpitAction(context: any): string
	self:SetState("Attack")

	if not context.target or not context.target.Character then
		return "Failure"
	end

	local targetRoot = context.target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not targetRoot then
		return "Failure"
	end

	-- Perform spit attack
	self.lastSpitTime = tick()

	-- Apply damage
	local humanoid = context.target.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:TakeDamage(SPIT_DAMAGE)
	end

	-- Apply blind effect (client-side)
	Events.FireClient(context.target, "Combat", "StatusEffect", {
		effect = "Blind",
		duration = SPIT_BLIND_DURATION,
		source = "Dilophosaurus",
	})

	-- Broadcast spit event for visual effects
	Events.FireAllClients("Dinosaur", "DilosaurSpit", {
		dinoId = self.id,
		origin = self.currentPosition,
		target = targetRoot.Position,
	})

	print(`[Dilophosaurus] {self.id} spit at {context.target.Name}!`)

	return "Success"
end

--[[
	Patrol territory action
]]
function Dilophosaurus:PatrolTerritoryAction(context: any): string
	self:SetState("Patrol")

	-- Wander within territory
	local angle = math.random() * math.pi * 2
	local distance = math.random() * TERRITORY_RADIUS * 0.7
	local targetPos = self.territoryCenter + Vector3.new(
		math.cos(angle) * distance,
		0,
		math.sin(angle) * distance
	)

	self:MoveTo(targetPos)

	-- Scan for intruders
	local intruder = self:FindIntruder()
	if intruder then
		context.alertLevel = 2
	end

	return "Success"
end

--[[
	Override TakeDamage to immediately aggro
]]
function Dilophosaurus:TakeDamage(amount: number, source: Player?)
	-- Call base damage
	DinosaurBase.TakeDamage(self, amount, source)

	-- Cancel warning and immediately attack
	if source then
		self.isWarning = false
		self.warningTarget = nil
		self.target = source
		if self.behaviorTree then
			self.behaviorTree:SetTarget(source)
		end
	end
end

return Dilophosaurus
