--!strict
--[[
	Velociraptor.lua
	================
	Pack hunter with coordinated attacks
	Uses PackAI for pack coordination
	Fast, deadly, and intelligent
]]

local DinosaurBase = require(script.Parent.Parent.DinosaurBase)
local BehaviorTree = require(script.Parent.Parent.BehaviorTree)
local PackAI = require(script.Parent.Parent.PackAI)
local Events = require(game.ReplicatedStorage.Shared.Events)

local Velociraptor = {}
Velociraptor.__index = Velociraptor
setmetatable(Velociraptor, { __index = DinosaurBase })

-- Raptor settings
local RAPTOR_SPEED = 28 -- Faster than player sprint!
local RAPTOR_DAMAGE = 30
local LEAP_RANGE = 10
local LEAP_COOLDOWN = 4
local LEAP_DAMAGE_MULTIPLIER = 1.5
local CALL_COOLDOWN = 3

--[[
	Create a new Velociraptor
	@param position Spawn position
	@return Velociraptor instance
]]
function Velociraptor.new(position: Vector3): any
	local self = setmetatable(DinosaurBase.new("Velociraptor", position), Velociraptor) :: any

	-- Override stats
	self.stats.health = 100
	self.stats.maxHealth = 100
	self.stats.damage = RAPTOR_DAMAGE
	self.stats.speed = RAPTOR_SPEED
	self.stats.detectionRange = 50
	self.stats.attackRange = 4

	-- Raptor-specific state
	self.packRole = nil :: PackAI.PackRole?
	self.lastLeapTime = 0
	self.lastCallTime = 0
	self.isLeaping = false
	self.leapTarget = nil :: Player?

	return self
end

--[[
	Create raptor-specific behavior tree
]]
function Velociraptor:CreateDefaultBehaviorTree(): any
	local tree = BehaviorTree.Selector({
		-- Pack retreating - flee
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return self.pack and self.pack.isRetreating
			end, "PackRetreating"),
			BehaviorTree.Action(function(ctx)
				return self:RetreatAction(ctx)
			end, "Retreat"),
		}, "RetreatSequence"),

		-- Continue leap if leaping
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return self.isLeaping
			end, "IsLeaping"),
			BehaviorTree.Action(function(ctx)
				return self:LeapAction(ctx)
			end, "Leap"),
		}, "LeapSequence"),

		-- Alpha behavior - engage and distract
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return self.packRole == "Alpha" and ctx.target ~= nil
			end, "IsAlphaWithTarget"),
			BehaviorTree.Action(function(ctx)
				return self:AlphaAttackAction(ctx)
			end, "AlphaAttack"),
		}, "AlphaSequence"),

		-- Flanker behavior - circle behind target
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return (self.packRole == "Beta" or self.packRole == "Scout")
					and ctx.target ~= nil
					and self.pack
					and self.pack.alpha
					and self.pack.alpha.target ~= nil
			end, "IsFlankerWithEngagedAlpha"),
			BehaviorTree.Action(function(ctx)
				return self:FlankAction(ctx)
			end, "Flank"),
		}, "FlankSequence"),

		-- Scout behavior - patrol ahead and alert
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return self.packRole == "Scout" and not ctx.target
			end, "IsScoutNoTarget"),
			BehaviorTree.Action(function(ctx)
				return self:ScoutAction(ctx)
			end, "Scout"),
		}, "ScoutSequence"),

		-- Generic chase if has target but no role
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return ctx.target ~= nil
			end, "HasTarget"),
			BehaviorTree.Action(function(ctx)
				return ctx.dinosaur:ChaseAction(ctx)
			end, "Chase"),
		}, "ChaseSequence"),

		-- Default: Follow pack formation
		BehaviorTree.Action(function(ctx)
			return self:FollowPackAction(ctx)
		end, "FollowPack"),
	}, "RaptorRoot")

	return BehaviorTree.new(tree, self)
end

--[[
	Check if can leap at target
]]
function Velociraptor:CanLeap(target: Player): boolean
	if tick() - self.lastLeapTime < LEAP_COOLDOWN then
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

	local distance = (rootPart.Position - self.currentPosition).Magnitude
	return distance <= LEAP_RANGE and distance > self.stats.attackRange
end

--[[
	Start leap attack
]]
function Velociraptor:StartLeap(target: Player): boolean
	if not self:CanLeap(target) then
		return false
	end

	self.isLeaping = true
	self.leapTarget = target
	self.lastLeapTime = tick()

	-- Broadcast leap event
	Events.FireAllClients("Dinosaur", "RaptorLeap", {
		dinoId = self.id,
		targetId = target.UserId,
	})

	return true
end

--[[
	Leap action - jump at target
]]
function Velociraptor:LeapAction(context: any): string
	self:SetState("Attack")

	if not self.leapTarget or not self.leapTarget.Character then
		self.isLeaping = false
		self.leapTarget = nil
		return "Failure"
	end

	local targetRoot = self.leapTarget.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not targetRoot then
		self.isLeaping = false
		self.leapTarget = nil
		return "Failure"
	end

	-- Apply leap velocity
	if self.model then
		local rootPart = self.model:FindFirstChild("HumanoidRootPart") :: BasePart?
			or self.model.PrimaryPart
		if rootPart then
			local direction = (targetRoot.Position - self.currentPosition).Unit
			local leapVelocity = direction * 40 + Vector3.new(0, 15, 0)
			rootPart.AssemblyLinearVelocity = leapVelocity
		end
	end

	-- Check for hit
	local distance = (self.currentPosition - targetRoot.Position).Magnitude
	if distance < 4 then
		-- Hit!
		local humanoid = self.leapTarget.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:TakeDamage(self.stats.damage * LEAP_DAMAGE_MULTIPLIER)
		end

		self.isLeaping = false
		self.leapTarget = nil
		return "Success"
	end

	-- Check if leap ended (on ground)
	if self.model then
		local rootPart = self.model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if rootPart and rootPart.AssemblyLinearVelocity.Y < 0 and self.currentPosition.Y < targetRoot.Position.Y + 2 then
			self.isLeaping = false
			self.leapTarget = nil
			return "Failure"
		end
	end

	return "Running"
end

--[[
	Alpha attack action - engage directly, distract target
]]
function Velociraptor:AlphaAttackAction(context: any): string
	self:SetState("Attack")

	if not context.target or not context.target.Character then
		return "Failure"
	end

	local targetRoot = context.target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not targetRoot then
		return "Failure"
	end

	-- Try to leap if in range
	if self:CanLeap(context.target) then
		self:StartLeap(context.target)
		return "Running"
	end

	-- Move toward target
	self:MoveTo(targetRoot.Position)

	-- Attack if in melee range
	if self:IsInAttackRange(context.target) then
		self:Attack(context.target)
	end

	-- Call pack periodically
	if tick() - self.lastCallTime >= CALL_COOLDOWN then
		self.lastCallTime = tick()
		if self.pack then
			PackAI.PackCall(self.pack, self)
		end
	end

	return "Running"
end

--[[
	Flank action - circle behind target while alpha distracts
]]
function Velociraptor:FlankAction(context: any): string
	self:SetState("Chase")

	if not context.target or not context.target.Character then
		return "Failure"
	end

	local targetRoot = context.target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not targetRoot then
		return "Failure"
	end

	-- Get flank position from PackAI
	local flankPos = targetRoot.Position

	if self.pack then
		flankPos = PackAI.GetFlankPosition(self.pack, self, targetRoot.Position)
	end

	-- Move to flank position
	self:MoveTo(flankPos)

	-- Check if in position
	local distanceToFlank = (self.currentPosition - flankPos).Magnitude
	local distanceToTarget = (self.currentPosition - targetRoot.Position).Magnitude

	-- Attack from flank if in position
	if distanceToFlank < 3 and distanceToTarget <= self.stats.attackRange then
		self:SetState("Attack")
		self:Attack(context.target)
	elseif distanceToFlank < 5 and self:CanLeap(context.target) then
		-- Leap from flank position
		self:StartLeap(context.target)
	end

	return "Running"
end

--[[
	Scout action - patrol ahead of pack, alert on sighting
]]
function Velociraptor:ScoutAction(context: any): string
	self:SetState("Patrol")

	-- Get scout position ahead of alpha
	local scoutPos = self.homePosition

	if self.pack and self.pack.alpha and self.pack.alpha.isAlive then
		local alphaForward = self.pack.alpha:GetForwardVector()
		scoutPos = self.pack.alpha.currentPosition + alphaForward * 15

		-- Offset to side based on scout index
		local scoutIndex = table.find(self.pack.scouts, self) or 1
		local sideOffset = (scoutIndex == 1) and -5 or 5
		scoutPos = scoutPos + CFrame.Angles(0, math.pi / 2, 0):VectorToWorldSpace(alphaForward) * sideOffset
	end

	-- Move to scout position
	self:MoveTo(scoutPos)

	-- Scan for targets
	if self:ScanForTargets() then
		-- Alert pack!
		if self.pack then
			PackAI.PackCall(self.pack, self)
			self.pack.target = self.target
		end

		-- Set context target
		context.target = self.target
		if self.behaviorTree then
			self.behaviorTree:SetTarget(self.target)
		end

		print(`[Velociraptor] Scout {self.id} spotted target!`)
	end

	return "Success"
end

--[[
	Follow pack action - maintain formation
]]
function Velociraptor:FollowPackAction(context: any): string
	self:SetState("Patrol")

	if not self.pack then
		-- No pack, wander
		if math.random() < 0.01 then
			local wanderOffset = Vector3.new(
				(math.random() - 0.5) * 20,
				0,
				(math.random() - 0.5) * 20
			)
			self:MoveTo(self.homePosition + wanderOffset)
		end
		return "Success"
	end

	-- Get formation position
	local formationPos = PackAI.GetFormationPosition(self.pack, self)
	self:MoveTo(formationPos)

	return "Success"
end

--[[
	Retreat action - flee to home
]]
function Velociraptor:RetreatAction(context: any): string
	self:SetState("Flee")

	local retreatTarget = self.homePosition

	if self.pack then
		retreatTarget = self.pack.homePosition
	end

	self:MoveTo(retreatTarget)

	return "Running"
end

--[[
	Override TakeDamage to alert pack
]]
function Velociraptor:TakeDamage(amount: number, source: Player?)
	-- Call base damage
	DinosaurBase.TakeDamage(self, amount, source)

	-- Alert pack
	if source and self.pack then
		PackAI.PackCall(self.pack, self)

		-- Set pack target
		self.pack.target = source
		PackAI.CoordinateAttack(self.pack, source)
	end
end

--[[
	Create a pack of Velociraptors
	@param position Center spawn position
	@param count Pack size (3-5)
	@return Pack
]]
function Velociraptor.CreatePack(position: Vector3, count: number?): PackAI.Pack
	local packSize = count or math.random(3, 5)
	local pack = PackAI.CreatePack("Velociraptor", position, packSize)

	-- Create raptors
	for i = 1, packSize do
		local offset = Vector3.new(
			(math.random() - 0.5) * 10,
			0,
			(math.random() - 0.5) * 10
		)
		local spawnPos = position + offset

		local raptor = Velociraptor.new(spawnPos)
		PackAI.AddMember(pack, raptor)
	end

	-- Assign roles
	PackAI.AssignRoles(pack)

	print(`[Velociraptor] Created pack with {packSize} members`)

	return pack
end

return Velociraptor
