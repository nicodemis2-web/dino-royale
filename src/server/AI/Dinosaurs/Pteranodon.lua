--!strict
--[[
	Pteranodon.lua
	==============
	Flying predator that dive bombs targets
	Circles above scanning for prey
	Attracted to gunfire
]]

local DinosaurBase = require(script.Parent.Parent.DinosaurBase)
local BehaviorTree = require(script.Parent.Parent.BehaviorTree)
local Events = require(game.ReplicatedStorage.Shared.Events)

local Pteranodon = {}
Pteranodon.__index = Pteranodon
setmetatable(Pteranodon, { __index = DinosaurBase })

-- Flight settings
local FLIGHT_ALTITUDE = 50
local CIRCLE_RADIUS = 30
local CIRCLE_SPEED = 20
local DIVE_SPEED = 60
local DIVE_DAMAGE = 25
local DIVE_KNOCKBACK = 35
local DIVE_COOLDOWN = 6
local CLIMB_SPEED = 15

-- State enum
type FlyingState = "Circling" | "Diving" | "Climbing" | "Fleeing"

--[[
	Create a new Pteranodon
	@param position Spawn position
	@return Pteranodon instance
]]
function Pteranodon.new(position: Vector3): any
	-- Spawn at flight altitude
	local flightPosition = Vector3.new(position.X, position.Y + FLIGHT_ALTITUDE, position.Z)
	local self = setmetatable(DinosaurBase.new("Pteranodon", flightPosition), Pteranodon) :: any

	-- Override stats
	self.stats.health = 80
	self.stats.maxHealth = 80
	self.stats.damage = DIVE_DAMAGE
	self.stats.speed = CIRCLE_SPEED
	self.stats.detectionRange = 60

	-- Ptero-specific state
	self.flyingState = "Circling" :: FlyingState
	self.circleCenter = position
	self.circleAngle = math.random() * math.pi * 2
	self.targetAltitude = FLIGHT_ALTITUDE
	self.diveTarget = nil :: Player?
	self.diveStartPosition = Vector3.zero
	self.lastDiveTime = 0
	self.isGrounded = false

	return self
end

--[[
	Create ptero-specific behavior tree
]]
function Pteranodon:CreateDefaultBehaviorTree(): any
	local tree = BehaviorTree.Selector({
		-- Flee if low health
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return ctx.dinosaur.stats.health < ctx.dinosaur.stats.maxHealth * 0.25
			end, "LowHealth"),
			BehaviorTree.Action(function(ctx)
				return self:FlyAwayAction(ctx)
			end, "FlyAway"),
		}, "FleeSequence"),

		-- Continue dive if diving
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return self.flyingState == "Diving"
			end, "IsDiving"),
			BehaviorTree.Action(function(ctx)
				return self:DiveAction(ctx)
			end, "Dive"),
		}, "DiveSequence"),

		-- Climb back up after dive
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return self.flyingState == "Climbing"
			end, "IsClimbing"),
			BehaviorTree.Action(function(ctx)
				return self:ClimbAction(ctx)
			end, "Climb"),
		}, "ClimbSequence"),

		-- Start dive if target below
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return ctx.target ~= nil and self:CanDive(ctx.target)
			end, "CanDive"),
			BehaviorTree.Action(function(ctx)
				return self:StartDive(ctx)
			end, "StartDive"),
		}, "DiveStartSequence"),

		-- Default: Circle and scan
		BehaviorTree.Action(function(ctx)
			return self:CircleAction(ctx)
		end, "Circle"),
	}, "PteroRoot")

	return BehaviorTree.new(tree, self)
end

--[[
	Check if can dive at target (off cooldown, target below)
]]
function Pteranodon:CanDive(target: Player): boolean
	if tick() - self.lastDiveTime < DIVE_COOLDOWN then
		return false
	end

	local character = target.Character
	if not character then
		return false
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return false
	end

	-- Check if target is below us
	local altitudeDiff = self.currentPosition.Y - rootPart.Position.Y
	if altitudeDiff < 10 then
		return false
	end

	-- Check horizontal distance
	local horizontalDist = Vector3.new(
		rootPart.Position.X - self.currentPosition.X,
		0,
		rootPart.Position.Z - self.currentPosition.Z
	).Magnitude

	return horizontalDist < 40
end

--[[
	Circle action - fly in circles scanning for targets
]]
function Pteranodon:CircleAction(context: any): string
	self.flyingState = "Circling"
	self:SetState("Patrol")

	-- Update circle angle
	self.circleAngle = self.circleAngle + context.dt * (CIRCLE_SPEED / CIRCLE_RADIUS)

	-- Calculate circle position
	local targetX = self.circleCenter.X + math.cos(self.circleAngle) * CIRCLE_RADIUS
	local targetZ = self.circleCenter.Z + math.sin(self.circleAngle) * CIRCLE_RADIUS
	local targetY = self.circleCenter.Y + FLIGHT_ALTITUDE

	local targetPos = Vector3.new(targetX, targetY, targetZ)

	-- Move toward circle position
	self:FlyTo(targetPos)

	-- Scan for targets
	local foundTarget = self:ScanForTargets()
	if foundTarget then
		context.target = self.target
		if self.behaviorTree then
			self.behaviorTree:SetTarget(self.target)
		end
	end

	-- React to gunfire (in context from DinosaurManager)
	if context.alertLevel > 0 then
		-- Move circle center toward sound
		if context.lastTargetPosition then
			self.circleCenter = Vector3.new(
				context.lastTargetPosition.X,
				self.circleCenter.Y,
				context.lastTargetPosition.Z
			)
		end
	end

	return "Success"
end

--[[
	Start dive attack
]]
function Pteranodon:StartDive(context: any): string
	if not context.target or not context.target.Character then
		return "Failure"
	end

	local targetRoot = context.target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not targetRoot then
		return "Failure"
	end

	self.flyingState = "Diving"
	self.diveTarget = context.target
	self.diveStartPosition = self.currentPosition
	self.lastDiveTime = tick()

	-- Broadcast dive event
	Events.FireAllClients("Dinosaur", "PteranodonDive", {
		dinoId = self.id,
		targetPosition = targetRoot.Position,
	})

	print(`[Pteranodon] {self.id} diving!`)

	return self:DiveAction(context)
end

--[[
	Dive action - swoop down at target
]]
function Pteranodon:DiveAction(context: any): string
	self:SetState("Attack")

	if not self.diveTarget or not self.diveTarget.Character then
		self.flyingState = "Climbing"
		return "Failure"
	end

	local targetRoot = self.diveTarget.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not targetRoot then
		self.flyingState = "Climbing"
		return "Failure"
	end

	-- Dive toward target
	local targetPos = targetRoot.Position
	self:FlyTo(targetPos, DIVE_SPEED)

	-- Check for hit
	local distance = (self.currentPosition - targetPos).Magnitude
	if distance < 5 then
		-- Hit the target
		local humanoid = self.diveTarget.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:TakeDamage(DIVE_DAMAGE)

			-- Apply knockback
			local knockbackDir = (targetRoot.Position - self.currentPosition).Unit + Vector3.new(0, 0.5, 0)
			targetRoot.AssemblyLinearVelocity = knockbackDir.Unit * DIVE_KNOCKBACK

			print(`[Pteranodon] {self.id} hit {self.diveTarget.Name} with dive!`)
		end

		-- Start climbing
		self.flyingState = "Climbing"
		self.diveTarget = nil
		return "Success"
	end

	-- Check if we've gone too low (missed)
	if self.currentPosition.Y < 10 then
		self.flyingState = "Climbing"
		self.diveTarget = nil
		return "Failure"
	end

	return "Running"
end

--[[
	Climb action - return to flight altitude
]]
function Pteranodon:ClimbAction(context: any): string
	self:SetState("Patrol")

	local targetAltitude = self.circleCenter.Y + FLIGHT_ALTITUDE
	local targetPos = Vector3.new(self.currentPosition.X, targetAltitude, self.currentPosition.Z)

	self:FlyTo(targetPos, CLIMB_SPEED)

	-- Check if we've reached altitude
	if self.currentPosition.Y >= targetAltitude - 5 then
		self.flyingState = "Circling"
		return "Success"
	end

	return "Running"
end

--[[
	Fly away action (flee)
]]
function Pteranodon:FlyAwayAction(context: any): string
	self.flyingState = "Fleeing"
	self:SetState("Flee")

	-- Fly away from threat
	local fleeDir = Vector3.new(math.random() - 0.5, 0.5, math.random() - 0.5).Unit
	if context.lastTargetPosition then
		fleeDir = (self.currentPosition - context.lastTargetPosition)
		fleeDir = Vector3.new(fleeDir.X, 0.5, fleeDir.Z).Unit
	end

	local targetPos = self.currentPosition + fleeDir * 100

	self:FlyTo(targetPos, DIVE_SPEED)

	return "Running"
end

--[[
	Fly to a position (override ground movement)
]]
function Pteranodon:FlyTo(targetPos: Vector3, speed: number?)
	local flySpeed = speed or CIRCLE_SPEED

	if not self.model then
		return
	end

	local rootPart = self.model:FindFirstChild("HumanoidRootPart") :: BasePart?
		or self.model.PrimaryPart
	if not rootPart then
		return
	end

	-- Calculate direction
	local direction = (targetPos - self.currentPosition).Unit

	-- Apply velocity directly (flying doesn't use humanoid movement)
	rootPart.AssemblyLinearVelocity = direction * flySpeed

	-- Face movement direction
	local lookAt = self.currentPosition + Vector3.new(direction.X, 0, direction.Z)
	rootPart.CFrame = CFrame.new(rootPart.Position, lookAt)

	-- Update position tracking
	self.currentPosition = rootPart.Position
end

--[[
	Override MoveTo to use flying
]]
function Pteranodon:MoveTo(position: Vector3): boolean
	self:FlyTo(position)
	return true
end

--[[
	Override TakeDamage
]]
function Pteranodon:TakeDamage(amount: number, source: Player?)
	-- Call base damage
	DinosaurBase.TakeDamage(self, amount, source)

	-- Target attacker
	if source then
		self.target = source
		if self.behaviorTree then
			self.behaviorTree:SetTarget(source)
		end
	end
end

return Pteranodon
