--!strict
--[[
	DinosaurBase.lua
	================
	Base class for all dinosaur AI
	Handles movement, sensing, attacking, and state management
]]

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")

local DinosaurData = require(game.ReplicatedStorage.Shared.Config.DinosaurData)
local Events = require(game.ReplicatedStorage.Shared.Events)
local DinosaurVisuals = require(script.Parent.DinosaurVisuals)

-- Forward declaration for BehaviorTree (to avoid cyclic import)
local BehaviorTree: any = nil

-- Type imports
type DinosaurState = "Idle" | "Patrol" | "Alert" | "Chase" | "Attack" | "Flee"

export type DinosaurStats = {
	health: number,
	maxHealth: number,
	damage: number,
	speed: number,
	detectionRange: number,
	attackRange: number,
	visionAngle: number,
	hearingRange: number,
}

export type DinosaurInstance = {
	id: string,
	species: string,
	model: Model?,
	stats: DinosaurStats,
	state: DinosaurState,
	target: Player?,
	homePosition: Vector3,
	currentPosition: Vector3,
	behaviorTree: any, -- BehaviorTreeInstance
	isAlive: boolean,
	lastAttackTime: number,
	attackCooldown: number,
	pack: any?, -- Pack reference for pack hunters

	-- Methods
	Update: (self: DinosaurInstance, dt: number) -> (),
	MoveTo: (self: DinosaurInstance, position: Vector3) -> boolean,
	CanSee: (self: DinosaurInstance, target: Player) -> boolean,
	CanHear: (self: DinosaurInstance, soundPosition: Vector3, soundRange: number) -> boolean,
	Attack: (self: DinosaurInstance, target: Player) -> boolean,
	TakeDamage: (self: DinosaurInstance, amount: number, source: Player?) -> (),
	Die: (self: DinosaurInstance) -> (),
	SetState: (self: DinosaurInstance, newState: DinosaurState) -> (),
	GetPosition: (self: DinosaurInstance) -> Vector3,
	Serialize: (self: DinosaurInstance) -> { [string]: any },
}

local DinosaurBase = {}
DinosaurBase.__index = DinosaurBase

-- Constants
local ATTACK_COOLDOWN = 1.5
local PATH_UPDATE_INTERVAL = 0.5
local VISION_CONE_ANGLE = 120 -- degrees

-- Unique ID counter
local nextId = 0

--[[
	Set BehaviorTree module reference (to avoid cyclic import)
]]
function DinosaurBase.SetBehaviorTreeModule(module: any)
	BehaviorTree = module
end

--[[
	Create a new dinosaur instance
	@param species Species name (must exist in DinosaurData)
	@param position Spawn position
	@return DinosaurInstance
]]
function DinosaurBase.new(species: string, position: Vector3): DinosaurInstance
	local speciesData = DinosaurData.AllDinosaurs[species]
	if not speciesData then
		error(`Unknown dinosaur species: {species}`)
	end

	nextId = nextId + 1

	local self = setmetatable({}, DinosaurBase) :: any

	self.id = `dino_{nextId}`
	self.species = species
	self.model = nil -- Created separately
	self.homePosition = position
	self.currentPosition = position
	self.isAlive = true
	self.lastAttackTime = 0
	self.attackCooldown = ATTACK_COOLDOWN
	self.pack = nil

	-- Initialize stats from species data
	self.stats = {
		health = speciesData.health,
		maxHealth = speciesData.health,
		damage = speciesData.damage,
		speed = speciesData.speed,
		detectionRange = speciesData.detectionRange,
		attackRange = speciesData.attackRange or 5,
		visionAngle = VISION_CONE_ANGLE,
		hearingRange = speciesData.detectionRange * 1.5,
	}

	self.state = "Idle" :: DinosaurState
	self.target = nil

	-- Path finding state
	self._path = nil
	self._pathIndex = 1
	self._lastPathUpdate = 0
	self._moveTarget = nil

	-- Patrol state (simple movement system)
	self._patrolTarget = nil
	self._lastPatrolTime = 0
	self._patrolInterval = 3 + math.random() * 4 -- 3-7 seconds between movements
	self._patrolRadius = 30 -- How far to wander from home

	return self
end

--[[
	Set the behavior tree for this dinosaur
	@param tree BehaviorTreeInstance
]]
function DinosaurBase:SetBehaviorTree(tree: any)
	self.behaviorTree = tree
end

--[[
	Create default behavior tree (can be overridden by subclasses)
]]
function DinosaurBase:CreateDefaultBehaviorTree(): any
	if not BehaviorTree then
		warn("[DinosaurBase] BehaviorTree module not set!")
		return nil
	end

	-- Default: Idle -> Alert -> Chase -> Attack -> Flee
	local tree = BehaviorTree.Selector({
		-- Flee if low health
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return ctx.dinosaur.stats.health < ctx.dinosaur.stats.maxHealth * 0.2
			end, "IsLowHealth"),
			BehaviorTree.Action(function(ctx)
				return ctx.dinosaur:FleeAction(ctx)
			end, "Flee"),
		}, "FleeSequence"),

		-- Attack if target in range
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return ctx.target ~= nil and ctx.dinosaur:IsInAttackRange(ctx.target)
			end, "TargetInAttackRange"),
			BehaviorTree.Action(function(ctx)
				return ctx.dinosaur:AttackAction(ctx)
			end, "Attack"),
		}, "AttackSequence"),

		-- Chase if has target
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return ctx.target ~= nil
			end, "HasTarget"),
			BehaviorTree.Action(function(ctx)
				return ctx.dinosaur:ChaseAction(ctx)
			end, "Chase"),
		}, "ChaseSequence"),

		-- Alert if heard something
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return ctx.alertLevel > 0
			end, "IsAlert"),
			BehaviorTree.Action(function(ctx)
				return ctx.dinosaur:AlertAction(ctx)
			end, "Alert"),
		}, "AlertSequence"),

		-- Default: Idle/Patrol
		BehaviorTree.Action(function(ctx)
			return ctx.dinosaur:IdleAction(ctx)
		end, "Idle"),
	}, "RootSelector")

	return BehaviorTree.new(tree, self)
end

--[[
	Update the dinosaur (called every frame)
	@param dt Delta time
]]
function DinosaurBase:Update(dt: number)
	if not self.isAlive then
		return
	end

	-- Update position tracking first (before AI)
	if self.model then
		local rootPart = self.model:FindFirstChild("HumanoidRootPart") :: BasePart?
			or self.model.PrimaryPart
		if rootPart then
			self.currentPosition = rootPart.Position
		end
	end

	-- Simple patrol system (always runs, doesn't depend on behavior tree)
	self:UpdatePatrol(dt)

	-- Update behavior tree (wrapped in pcall for safety)
	if self.behaviorTree then
		local success, err = pcall(function()
			self.behaviorTree:Run(dt)
		end)
		if not success then
			-- Disable behavior tree if it keeps erroring
			warn(`[DinosaurBase] Behavior tree error for {self.species}: {err}`)
			self.behaviorTree = nil
		end
	end
end

--[[
	Simple patrol system - makes dinosaurs wander around their home position
	This runs independently of the behavior tree for reliability
]]
function DinosaurBase:UpdatePatrol(dt: number)
	if not self.model then
		return
	end

	local humanoid = self.model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local now = tick()

	-- Check if it's time to pick a new patrol target
	if now - self._lastPatrolTime >= self._patrolInterval then
		self._lastPatrolTime = now
		self._patrolInterval = 3 + math.random() * 4 -- Randomize next interval

		-- Pick a random point within patrol radius of home
		local angle = math.random() * math.pi * 2
		local distance = math.random() * self._patrolRadius
		local offsetX = math.cos(angle) * distance
		local offsetZ = math.sin(angle) * distance

		self._patrolTarget = Vector3.new(
			self.homePosition.X + offsetX,
			self.currentPosition.Y,
			self.homePosition.Z + offsetZ
		)
	end

	-- Move toward patrol target if we have one
	if self._patrolTarget then
		local distanceToTarget = (Vector3.new(self.currentPosition.X, 0, self.currentPosition.Z) -
			Vector3.new(self._patrolTarget.X, 0, self._patrolTarget.Z)).Magnitude

		if distanceToTarget > 3 then
			-- Still moving to target
			humanoid:MoveTo(self._patrolTarget)
		else
			-- Reached target, clear it
			self._patrolTarget = nil
		end
	end
end

--[[
	Move toward a target position using pathfinding
	@param position Target position
	@return Whether movement is in progress
]]
function DinosaurBase:MoveTo(position: Vector3): boolean
	if not self.model then
		return false
	end

	local humanoid = self.model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end

	-- Check if we need to update path
	local now = tick()
	local needsNewPath = self._moveTarget == nil
		or (position - self._moveTarget).Magnitude > 5
		or now - self._lastPathUpdate > PATH_UPDATE_INTERVAL

	if needsNewPath then
		self._moveTarget = position
		self._lastPathUpdate = now

		-- Create new path
		local path = PathfindingService:CreatePath({
			AgentRadius = 2,
			AgentHeight = 5,
			AgentCanJump = false,
		})

		local success, err = pcall(function()
			path:ComputeAsync(self.currentPosition, position)
		end)

		if success and path.Status == Enum.PathStatus.Success then
			self._path = path:GetWaypoints()
			self._pathIndex = 1
		else
			-- Direct movement if pathfinding fails
			humanoid:MoveTo(position)
			return true
		end
	end

	-- Follow path
	if self._path and self._pathIndex <= #self._path then
		local waypoint = self._path[self._pathIndex]
		local distance = (self.currentPosition - waypoint.Position).Magnitude

		if distance < 3 then
			self._pathIndex = self._pathIndex + 1
		end

		if self._pathIndex <= #self._path then
			humanoid:MoveTo(self._path[self._pathIndex].Position)
		end

		return true
	end

	return false
end

--[[
	Check if the dinosaur can see a target player
	Uses vision cone and raycast
	@param target Target player
	@return Whether the target is visible
]]
function DinosaurBase:CanSee(target: Player): boolean
	local character = target.Character
	if not character then
		return false
	end

	local targetRoot = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not targetRoot then
		return false
	end

	local targetPosition = targetRoot.Position

	-- Check distance
	local distance = (targetPosition - self.currentPosition).Magnitude
	if distance > self.stats.detectionRange then
		return false
	end

	-- Check vision cone
	local toTarget = (targetPosition - self.currentPosition).Unit
	local forward = self:GetForwardVector()
	local dot = forward:Dot(toTarget)
	local angle = math.deg(math.acos(math.clamp(dot, -1, 1)))

	if angle > self.stats.visionAngle / 2 then
		return false
	end

	-- Raycast check
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { self.model }

	local result = workspace:Raycast(self.currentPosition + Vector3.new(0, 2, 0), toTarget * distance, rayParams)

	if result then
		-- Check if we hit the target
		local hitModel = result.Instance:FindFirstAncestorOfClass("Model")
		return hitModel == character
	end

	return true -- Nothing in the way
end

--[[
	Check if the dinosaur can hear a sound
	@param soundPosition Position of the sound
	@param soundRange How far the sound travels
	@return Whether the sound is audible
]]
function DinosaurBase:CanHear(soundPosition: Vector3, soundRange: number): boolean
	local distance = (soundPosition - self.currentPosition).Magnitude
	local effectiveRange = math.min(self.stats.hearingRange, soundRange)
	return distance <= effectiveRange
end

--[[
	Check if target is within attack range
	@param target Target player
	@return Whether target is in range
]]
function DinosaurBase:IsInAttackRange(target: Player): boolean
	local character = target.Character
	if not character then
		return false
	end

	local targetRoot = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not targetRoot then
		return false
	end

	local distance = (targetRoot.Position - self.currentPosition).Magnitude
	return distance <= self.stats.attackRange
end

--[[
	Attack a target player
	@param target Target player
	@return Whether the attack was executed
]]
function DinosaurBase:Attack(target: Player): boolean
	local now = tick()
	if now - self.lastAttackTime < self.attackCooldown then
		return false
	end

	if not self:IsInAttackRange(target) then
		return false
	end

	self.lastAttackTime = now

	-- Apply damage (through HealthManager would be ideal)
	local character = target.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:TakeDamage(self.stats.damage)
		end
	end

	-- Broadcast attack event
	Events.FireAllClients("Dinosaur", "DinosaurAttacked", {
		dinoId = self.id,
		targetId = target.UserId,
		damage = self.stats.damage,
	})

	return true
end

--[[
	Take damage from a source
	@param amount Damage amount
	@param source Source player (or nil for environmental)
]]
function DinosaurBase:TakeDamage(amount: number, source: Player?)
	if not self.isAlive then
		return
	end

	-- Apply armor reduction if any
	local actualDamage = amount

	self.stats.health = math.max(0, self.stats.health - actualDamage)

	-- Update model attribute for client-side health bar
	if self.model then
		self.model:SetAttribute("Health", self.stats.health)
	end

	-- Set source as target (aggro)
	if source and self.stats.health > 0 then
		self.target = source
		if self.behaviorTree then
			self.behaviorTree:SetTarget(source)
		end
	end

	-- Broadcast damage event
	Events.FireAllClients("Dinosaur", "DinosaurDamaged", {
		dinoId = self.id,
		damage = actualDamage,
		newHealth = self.stats.health,
		maxHealth = self.stats.maxHealth,
	})

	-- Check death
	if self.stats.health <= 0 then
		self:Die()
	end
end

--[[
	Handle dinosaur death
]]
function DinosaurBase:Die()
	if not self.isAlive then
		return
	end

	self.isAlive = false
	self.state = "Idle"

	-- Broadcast death event
	Events.FireAllClients("Dinosaur", "DinosaurKilled", {
		dinoId = self.id,
		species = self.species,
		position = self.currentPosition,
		killerId = self.target and self.target.UserId or nil,
	})

	-- Notify pack if any
	if self.pack and self.pack.HandleMemberDeath then
		self.pack:HandleMemberDeath(self)
	end

	-- Destroy model after delay (for death animation)
	task.delay(2, function()
		if self.model then
			self.model:Destroy()
			self.model = nil
		end
	end)
end

--[[
	Set the dinosaur's state
	@param newState New state
]]
function DinosaurBase:SetState(newState: DinosaurState)
	if self.state ~= newState then
		self.state = newState
	end
end

--[[
	Get current position
	@return Current position
]]
function DinosaurBase:GetPosition(): Vector3
	return self.currentPosition
end

--[[
	Get forward facing vector
	@return Forward vector
]]
function DinosaurBase:GetForwardVector(): Vector3
	if self.model then
		local rootPart = self.model:FindFirstChild("HumanoidRootPart") :: BasePart?
			or self.model.PrimaryPart
		if rootPart then
			return rootPart.CFrame.LookVector
		end
	end
	return Vector3.new(0, 0, -1)
end

--[[
	Serialize dinosaur data for network/storage
	@return Serialized data
]]
function DinosaurBase:Serialize(): { [string]: any }
	return {
		id = self.id,
		species = self.species,
		health = self.stats.health,
		maxHealth = self.stats.maxHealth,
		position = self.currentPosition,
		state = self.state,
		isAlive = self.isAlive,
	}
end

--[[
	==================
	BEHAVIOR ACTIONS
	==================
]]

--[[
	Idle/Patrol action
]]
function DinosaurBase:IdleAction(context: any): string
	self:SetState("Idle")

	-- Occasional wandering
	if math.random() < 0.01 then -- 1% chance per frame
		local wanderOffset = Vector3.new(math.random(-10, 10), 0, math.random(-10, 10))
		local wanderTarget = self.homePosition + wanderOffset
		self:MoveTo(wanderTarget)
	end

	return "Success"
end

--[[
	Alert action (heard something)
]]
function DinosaurBase:AlertAction(context: any): string
	self:SetState("Alert")

	-- Decrease alert over time
	context.alertLevel = context.alertLevel - context.dt * 0.5

	-- Look toward last known position
	if context.lastTargetPosition then
		self:MoveTo(context.lastTargetPosition)

		-- Check if we reached the position
		local distance = (self.currentPosition - context.lastTargetPosition).Magnitude
		if distance < 5 then
			context.alertLevel = 0
			context.lastTargetPosition = nil
		end
	end

	return "Running"
end

--[[
	Chase action
]]
function DinosaurBase:ChaseAction(context: any): string
	self:SetState("Chase")

	if not context.target or not context.target.Character then
		self.target = nil
		context.target = nil
		return "Failure"
	end

	local targetRoot = context.target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not targetRoot then
		return "Failure"
	end

	-- Update last known position
	context.lastTargetPosition = targetRoot.Position

	-- Move toward target
	self:MoveTo(targetRoot.Position)

	-- Check if we lost sight
	if not self:CanSee(context.target) then
		-- Keep chasing last known position for a bit
		context.alertLevel = 3
	end

	return "Running"
end

--[[
	Attack action
]]
function DinosaurBase:AttackAction(context: any): string
	self:SetState("Attack")

	if not context.target then
		return "Failure"
	end

	local attacked = self:Attack(context.target)
	return attacked and "Success" or "Running"
end

--[[
	Flee action
]]
function DinosaurBase:FleeAction(context: any): string
	self:SetState("Flee")

	-- Run away from target or home if no target
	local fleeFrom = context.lastTargetPosition or self.homePosition
	local fleeDirection = (self.currentPosition - fleeFrom).Unit
	local fleeTarget = self.currentPosition + fleeDirection * 50

	self:MoveTo(fleeTarget)

	return "Running"
end

--[[
	Set model for this dinosaur
	@param model Dinosaur model
]]
function DinosaurBase:SetModel(model: Model)
	self.model = model

	-- Set up humanoid
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = self.stats.speed
	end

	-- Position model
	if model.PrimaryPart then
		model:SetPrimaryPartCFrame(CFrame.new(self.currentPosition))
		-- IMPORTANT: Unanchor the root part so the dinosaur can move!
		model.PrimaryPart.Anchored = false
	end

	-- Unanchor all parts so physics/movement works
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Anchored = false
		end
	end

	-- Set attributes for client-side targeting UI
	local speciesData = DinosaurData.AllDinosaurs[self.species]
	local tier = speciesData and speciesData.tier or "Common"
	model:SetAttribute("Species", self.species)
	model:SetAttribute("Health", self.stats.health)
	model:SetAttribute("MaxHealth", self.stats.maxHealth)
	model:SetAttribute("Tier", tier)
	model:SetAttribute("DinosaurId", self.id)

	-- Add dinosaur tag for CollectionService queries
	model:AddTag("Dinosaur")

	-- Apply visual effects (glow, particles, neon markings based on tier/species)
	DinosaurVisuals.ApplyVisuals(model, self.species, tier)
end

--[[
	Find nearest player
	@return Nearest player or nil
]]
function DinosaurBase:FindNearestPlayer(): Player?
	local nearestPlayer: Player? = nil
	local nearestDistance = math.huge

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if rootPart then
				local distance = (rootPart.Position - self.currentPosition).Magnitude
				if distance < nearestDistance and distance <= self.stats.detectionRange then
					nearestDistance = distance
					nearestPlayer = player
				end
			end
		end
	end

	return nearestPlayer
end

--[[
	Check for visible players and acquire target
	@return Whether a target was found
]]
function DinosaurBase:ScanForTargets(): boolean
	for _, player in ipairs(Players:GetPlayers()) do
		if self:CanSee(player) then
			self.target = player
			if self.behaviorTree then
				self.behaviorTree:SetTarget(player)
			end
			return true
		end
	end
	return false
end

return DinosaurBase
