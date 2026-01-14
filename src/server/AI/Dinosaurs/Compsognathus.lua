--!strict
--[[
	Compsognathus.lua
	=================
	Tiny pack scavengers (5-10 per group)
	Individually weak but dangerous in swarms
	Uses boids-like flocking behavior
]]

local DinosaurBase = require(script.Parent.Parent.DinosaurBase)
local BehaviorTree = require(script.Parent.Parent.BehaviorTree)

local Compsognathus = {}
Compsognathus.__index = Compsognathus
setmetatable(Compsognathus, { __index = DinosaurBase })

-- Boids settings
local SEPARATION_WEIGHT = 1.5
local ALIGNMENT_WEIGHT = 1.0
local COHESION_WEIGHT = 1.0
local SEPARATION_RADIUS = 3
local NEIGHBOR_RADIUS = 10

-- Swarm settings
local SWARM_ATTACK_THRESHOLD = 3 -- Need at least 3 to swarm attack
local SCATTER_DURATION = 3 -- Seconds to scatter when shot at
local REGROUP_DISTANCE = 20

-- Type for pack reference
type CompyPack = {
	members: { any },
	center: Vector3,
	velocity: Vector3,
	isScattered: boolean,
	scatterTime: number,
}

--[[
	Create a new Compsognathus
	@param position Spawn position
	@return Compsognathus instance
]]
function Compsognathus.new(position: Vector3): any
	local self = setmetatable(DinosaurBase.new("Compsognathus", position), Compsognathus) :: any

	-- Override stats for compys
	self.stats.damage = 5
	self.stats.attackRange = 3
	self.attackCooldown = 0.8 -- Faster attacks

	-- Compy-specific state
	self.flockVelocity = Vector3.zero
	self.isScattered = false
	self.scatterDirection = Vector3.zero
	self.scatterEndTime = 0

	return self
end

--[[
	Create compy-specific behavior tree
]]
function Compsognathus:CreateDefaultBehaviorTree(): any
	local tree = BehaviorTree.Selector({
		-- Scatter if recently shot at
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return self.isScattered and tick() < self.scatterEndTime
			end, "IsScattered"),
			BehaviorTree.Action(function(ctx)
				return self:ScatterAction(ctx)
			end, "Scatter"),
		}, "ScatterSequence"),

		-- Flee if very low health
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return ctx.dinosaur.stats.health < 5
			end, "CriticalHealth"),
			BehaviorTree.Action(function(ctx)
				return ctx.dinosaur:FleeAction(ctx)
			end, "Flee"),
		}, "FleeSequence"),

		-- Swarm attack if enough pack members nearby and target exists
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return ctx.target ~= nil and self:CanSwarmAttack()
			end, "CanSwarm"),
			BehaviorTree.Action(function(ctx)
				return self:SwarmAttackAction(ctx)
			end, "SwarmAttack"),
		}, "SwarmSequence"),

		-- Chase if has target but not enough for swarm
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return ctx.target ~= nil
			end, "HasTarget"),
			BehaviorTree.Action(function(ctx)
				return ctx.dinosaur:ChaseAction(ctx)
			end, "Chase"),
		}, "ChaseSequence"),

		-- Default: Flock wander
		BehaviorTree.Action(function(ctx)
			return self:FlockAction(ctx)
		end, "Flock"),
	}, "CompyRoot")

	return BehaviorTree.new(tree, self)
end

--[[
	Get nearby pack members
]]
function Compsognathus:GetNearbyPackMembers(): { any }
	local nearby = {} :: { any }

	if self.pack and self.pack.members then
		for _, member in ipairs(self.pack.members) do
			if member ~= self and member.isAlive then
				local distance = (member.currentPosition - self.currentPosition).Magnitude
				if distance <= NEIGHBOR_RADIUS then
					table.insert(nearby, member)
				end
			end
		end
	end

	return nearby
end

--[[
	Check if enough compys nearby for swarm attack
]]
function Compsognathus:CanSwarmAttack(): boolean
	local nearbyCount = #self:GetNearbyPackMembers() + 1 -- Include self
	return nearbyCount >= SWARM_ATTACK_THRESHOLD
end

--[[
	Calculate boids-like flocking steering
]]
function Compsognathus:CalculateFlockSteering(): Vector3
	local neighbors = self:GetNearbyPackMembers()

	if #neighbors == 0 then
		-- No neighbors, wander randomly
		return Vector3.new(math.random() - 0.5, 0, math.random() - 0.5).Unit
	end

	local separation = Vector3.zero
	local alignment = Vector3.zero
	local cohesion = Vector3.zero

	local separationCount = 0

	for _, neighbor in ipairs(neighbors) do
		local offset = self.currentPosition - neighbor.currentPosition
		local distance = offset.Magnitude

		-- Separation: Avoid crowding
		if distance < SEPARATION_RADIUS and distance > 0 then
			separation = separation + offset.Unit / distance
			separationCount = separationCount + 1
		end

		-- Alignment: Match velocity
		if neighbor.flockVelocity then
			alignment = alignment + neighbor.flockVelocity
		end

		-- Cohesion: Move toward center
		cohesion = cohesion + neighbor.currentPosition
	end

	-- Average and weight
	if separationCount > 0 then
		separation = separation / separationCount * SEPARATION_WEIGHT
	end

	alignment = alignment / #neighbors * ALIGNMENT_WEIGHT
	cohesion = (cohesion / #neighbors - self.currentPosition).Unit * COHESION_WEIGHT

	-- Combine steering forces
	local steering = separation + alignment + cohesion

	-- Normalize
	if steering.Magnitude > 0 then
		steering = steering.Unit
	end

	return steering
end

--[[
	Flock wandering action
]]
function Compsognathus:FlockAction(context: any): string
	self:SetState("Patrol")

	-- Calculate flock steering
	local steering = self:CalculateFlockSteering()

	-- Add home attraction
	local toHome = (self.homePosition - self.currentPosition)
	if toHome.Magnitude > 30 then
		steering = steering + toHome.Unit * 0.3
	end

	-- Add random wander
	local wander = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 0.2
	steering = steering + wander

	-- Normalize and store velocity
	if steering.Magnitude > 0 then
		self.flockVelocity = steering.Unit * self.stats.speed
	end

	-- Move
	local targetPos = self.currentPosition + steering.Unit * 5
	self:MoveTo(targetPos)

	-- Check for targets while flocking
	if self:ScanForTargets() then
		context.target = self.target
		if self.behaviorTree then
			self.behaviorTree:SetTarget(self.target)
		end
	end

	return "Success"
end

--[[
	Swarm attack action - all compys converge on target
]]
function Compsognathus:SwarmAttackAction(context: any): string
	self:SetState("Attack")

	if not context.target or not context.target.Character then
		return "Failure"
	end

	local targetRoot = context.target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not targetRoot then
		return "Failure"
	end

	local targetPos = targetRoot.Position

	-- Move toward target
	self:MoveTo(targetPos)

	-- Attack if in range
	if self:IsInAttackRange(context.target) then
		self:Attack(context.target)
	end

	return "Running"
end

--[[
	Scatter action - run away from threat
]]
function Compsognathus:ScatterAction(context: any): string
	self:SetState("Flee")

	-- Move in scatter direction
	local targetPos = self.currentPosition + self.scatterDirection * 10
	self:MoveTo(targetPos)

	-- Check if scatter time is over
	if tick() >= self.scatterEndTime then
		self.isScattered = false
	end

	return "Running"
end

--[[
	Override TakeDamage to trigger scatter
]]
function Compsognathus:TakeDamage(amount: number, source: Player?)
	-- Call base damage
	DinosaurBase.TakeDamage(self, amount, source)

	-- Trigger scatter
	self.isScattered = true
	self.scatterEndTime = tick() + SCATTER_DURATION

	-- Scatter direction away from damage source
	if source and source.Character then
		local sourceRoot = source.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if sourceRoot then
			self.scatterDirection = (self.currentPosition - sourceRoot.Position).Unit
		else
			self.scatterDirection = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5).Unit
		end
	else
		self.scatterDirection = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5).Unit
	end

	-- Alert nearby compys to scatter too
	local nearby = self:GetNearbyPackMembers()
	for _, compy in ipairs(nearby) do
		if not compy.isScattered then
			compy.isScattered = true
			compy.scatterEndTime = tick() + SCATTER_DURATION
			compy.scatterDirection = (compy.currentPosition - self.currentPosition).Unit
		end
	end
end

--[[
	Create a pack of Compsognathus
	@param position Center position
	@param count Number of compys (5-10)
	@return Pack data
]]
function Compsognathus.CreatePack(position: Vector3, count: number?): CompyPack
	local packSize = count or math.random(5, 10)
	local pack: CompyPack = {
		members = {},
		center = position,
		velocity = Vector3.zero,
		isScattered = false,
		scatterTime = 0,
	}

	for i = 1, packSize do
		local offset = Vector3.new(
			(math.random() - 0.5) * 8,
			0,
			(math.random() - 0.5) * 8
		)
		local spawnPos = position + offset

		local compy = Compsognathus.new(spawnPos)
		compy.pack = pack
		table.insert(pack.members, compy)
	end

	return pack
end

return Compsognathus
