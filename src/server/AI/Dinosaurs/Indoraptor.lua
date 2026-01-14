--!strict
--[[
	Indoraptor.lua
	==============
	Stealth hunter boss dinosaur
	Stalks prey, can open doors, uses echolocation
	Spawns during power outage or final 10 players
]]

local Players = game:GetService("Players")

local DinosaurBase = require(script.Parent.Parent.DinosaurBase)
local BehaviorTree = require(script.Parent.Parent.BehaviorTree)
local Events = require(game.ReplicatedStorage.Shared.Events)

local Indoraptor = {}
Indoraptor.__index = Indoraptor
setmetatable(Indoraptor, { __index = DinosaurBase })

-- Boss stats
local BOSS_HEALTH = 1500
local BOSS_DAMAGE = 80
local BOSS_SPEED = 30

-- Ability settings
local ECHOLOCATION_RANGE = 50
local ECHOLOCATION_COOLDOWN = 20
local ECHOLOCATION_DURATION = 3

local STALK_SPEED_MULTIPLIER = 0.5
local STALK_DETECTION_REDUCTION = 0.5 -- 50% harder to detect

local AMBUSH_DAMAGE_MULTIPLIER = 1.5
local DOOR_OPEN_RANGE = 5

--[[
	Create a new Indoraptor boss
	@param position Spawn position
	@return Indoraptor instance
]]
function Indoraptor.new(position: Vector3): any
	local self = setmetatable(DinosaurBase.new("Indoraptor", position), Indoraptor) :: any

	-- Override stats for boss
	self.stats.health = BOSS_HEALTH
	self.stats.maxHealth = BOSS_HEALTH
	self.stats.damage = BOSS_DAMAGE
	self.stats.speed = BOSS_SPEED
	self.stats.detectionRange = 80
	self.stats.attackRange = 5

	-- Indoraptor-specific state
	self.isStalking = true
	self.isDetected = false
	self.lastEcholocationTime = 0
	self.echoTargets = {} :: { Player }
	self.preferredTarget = nil :: Player?

	return self
end

--[[
	Create Indoraptor behavior tree
]]
function Indoraptor:CreateDefaultBehaviorTree(): any
	local tree = BehaviorTree.Selector({
		-- Direct attack if detected
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return self.isDetected and ctx.target ~= nil
			end, "IsDetectedWithTarget"),
			BehaviorTree.Action(function(ctx)
				return self:DirectAttackAction(ctx)
			end, "DirectAttack"),
		}, "DirectAttackSequence"),

		-- Open doors if blocked
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return self:HasDoorInWay()
			end, "DoorBlocking"),
			BehaviorTree.Action(function(ctx)
				return self:OpenDoorAction(ctx)
			end, "OpenDoor"),
		}, "DoorSequence"),

		-- Echolocation to find targets
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return self:CanEcholocate()
			end, "CanEcholocate"),
			BehaviorTree.Action(function(ctx)
				return self:EcholocationAction(ctx)
			end, "Echolocation"),
		}, "EchoSequence"),

		-- Stalk if not detected and has target
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return not self.isDetected and ctx.target ~= nil
			end, "CanStalk"),
			BehaviorTree.Action(function(ctx)
				return self:StalkAction(ctx)
			end, "Stalk"),
		}, "StalkSequence"),

		-- Ambush attack from behind
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return not self.isDetected and self:CanAmbush(ctx.target)
			end, "CanAmbush"),
			BehaviorTree.Action(function(ctx)
				return self:AmbushAction(ctx)
			end, "Ambush"),
		}, "AmbushSequence"),

		-- Hunt based on echolocation
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return #self.echoTargets > 0
			end, "HasEchoTargets"),
			BehaviorTree.Action(function(ctx)
				return self:HuntEchoTargetAction(ctx)
			end, "HuntEchoTarget"),
		}, "HuntSequence"),

		-- Default: Patrol in shadows
		BehaviorTree.Action(function(ctx)
			return self:ShadowPatrolAction(ctx)
		end, "ShadowPatrol"),
	}, "IndoraptorRoot")

	return BehaviorTree.new(tree, self)
end

--[[
	Check if can use echolocation
]]
function Indoraptor:CanEcholocate(): boolean
	return tick() - self.lastEcholocationTime >= ECHOLOCATION_COOLDOWN
end

--[[
	Echolocation action - reveal all players in range
]]
function Indoraptor:EcholocationAction(context: any): string
	self.lastEcholocationTime = tick()
	self.echoTargets = {}

	-- Broadcast echolocation event (for audio/visual)
	Events.FireAllClients("Dinosaur", "IndoraptorEcho", {
		dinoId = self.id,
		position = self.currentPosition,
		radius = ECHOLOCATION_RANGE,
	})

	-- Find all players in range (through walls)
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if rootPart then
				local distance = (rootPart.Position - self.currentPosition).Magnitude
				if distance <= ECHOLOCATION_RANGE then
					table.insert(self.echoTargets, player)

					-- Warn player they were detected
					Events.FireClient(player, "Combat", "EcholocationDetected", {
						position = self.currentPosition,
					})
				end
			end
		end
	end

	-- Select preferred target (nearest)
	if #self.echoTargets > 0 then
		local nearestDistance = math.huge
		for _, player in ipairs(self.echoTargets) do
			local character = player.Character
			if character then
				local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if rootPart then
					local distance = (rootPart.Position - self.currentPosition).Magnitude
					if distance < nearestDistance then
						nearestDistance = distance
						self.preferredTarget = player
					end
				end
			end
		end
	end

	print(`[Indoraptor] Echolocation detected {#self.echoTargets} players!`)

	return "Success"
end

--[[
	Stalk action - slowly approach target from shadows
]]
function Indoraptor:StalkAction(context: any): string
	self:SetState("Chase")
	self.isStalking = true

	if not context.target or not context.target.Character then
		return "Failure"
	end

	local targetRoot = context.target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not targetRoot then
		return "Failure"
	end

	-- Move slowly toward target
	if self.model then
		local humanoid = self.model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = self.stats.speed * STALK_SPEED_MULTIPLIER
		end
	end

	-- Try to approach from behind
	local targetForward = targetRoot.CFrame.LookVector
	local behindPosition = targetRoot.Position - targetForward * 10

	self:MoveTo(behindPosition)

	-- Check if player is looking at us
	local toIndoraptor = (self.currentPosition - targetRoot.Position).Unit
	local dot = targetForward:Dot(toIndoraptor)
	if dot > 0.5 then -- Player is facing us
		self.isDetected = true
		print(`[Indoraptor] Detected by {context.target.Name}!`)
	end

	return "Running"
end

--[[
	Check if can ambush target
]]
function Indoraptor:CanAmbush(target: Player?): boolean
	if not target or not target.Character then
		return false
	end

	local targetRoot = target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not targetRoot then
		return false
	end

	-- Check distance
	local distance = (targetRoot.Position - self.currentPosition).Magnitude
	if distance > self.stats.attackRange then
		return false
	end

	-- Check if behind target
	local targetForward = targetRoot.CFrame.LookVector
	local toIndoraptor = (self.currentPosition - targetRoot.Position).Unit
	local dot = targetForward:Dot(toIndoraptor)

	-- Behind = negative dot
	return dot < -0.3
end

--[[
	Ambush action - surprise attack from behind
]]
function Indoraptor:AmbushAction(context: any): string
	self:SetState("Attack")

	if not context.target or not context.target.Character then
		return "Failure"
	end

	-- Apply ambush damage
	local humanoid = context.target.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local ambushDamage = self.stats.damage * AMBUSH_DAMAGE_MULTIPLIER
		humanoid:TakeDamage(ambushDamage)

		-- Broadcast ambush event
		Events.FireAllClients("Dinosaur", "IndoraptorAmbush", {
			dinoId = self.id,
			targetId = context.target.UserId,
			damage = ambushDamage,
		})

		print(`[Indoraptor] Ambush attack on {context.target.Name} for {ambushDamage} damage!`)
	end

	-- Now detected
	self.isDetected = true

	return "Success"
end

--[[
	Direct attack action - aggressive pursuit
]]
function Indoraptor:DirectAttackAction(context: any): string
	self:SetState("Attack")
	self.isStalking = false

	-- Full speed
	if self.model then
		local humanoid = self.model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = self.stats.speed
		end
	end

	if not context.target or not context.target.Character then
		-- Lost target, go back to stalking
		self.isDetected = false
		return "Failure"
	end

	local targetRoot = context.target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not targetRoot then
		return "Failure"
	end

	-- Chase and attack
	self:MoveTo(targetRoot.Position)

	if self:IsInAttackRange(context.target) then
		self:Attack(context.target)
	end

	return "Running"
end

--[[
	Hunt echo target action
]]
function Indoraptor:HuntEchoTargetAction(context: any): string
	self:SetState("Chase")

	-- Clean up invalid targets
	local validTargets = {}
	for _, player in ipairs(self.echoTargets) do
		if player.Character then
			table.insert(validTargets, player)
		end
	end
	self.echoTargets = validTargets

	if #self.echoTargets == 0 then
		return "Failure"
	end

	-- Use preferred target or first valid
	local target = self.preferredTarget or self.echoTargets[1]
	if not target or not target.Character then
		return "Failure"
	end

	self.target = target
	if self.behaviorTree then
		self.behaviorTree:SetTarget(target)
	end
	context.target = target

	local targetRoot = target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if targetRoot then
		self:MoveTo(targetRoot.Position)
	end

	return "Running"
end

--[[
	Check if there's a door blocking path
]]
function Indoraptor:HasDoorInWay(): boolean
	-- Check for doors in front
	local CollectionService = game:GetService("CollectionService")
	local doors = CollectionService:GetTagged("Door")

	local forward = self:GetForwardVector()

	for _, door in ipairs(doors) do
		if door:IsA("BasePart") or door:IsA("Model") then
			local doorPos = door:IsA("Model") and door:GetPivot().Position or door.Position
			local toDoor = (doorPos - self.currentPosition)

			if toDoor.Magnitude <= DOOR_OPEN_RANGE then
				local dot = forward:Dot(toDoor.Unit)
				if dot > 0.5 then -- Door is in front
					return true
				end
			end
		end
	end

	return false
end

--[[
	Open door action
]]
function Indoraptor:OpenDoorAction(context: any): string
	self:SetState("Alert")

	local CollectionService = game:GetService("CollectionService")
	local doors = CollectionService:GetTagged("Door")

	for _, door in ipairs(doors) do
		if door:IsA("BasePart") or door:IsA("Model") then
			local doorPos = door:IsA("Model") and door:GetPivot().Position or door.Position
			local distance = (doorPos - self.currentPosition).Magnitude

			if distance <= DOOR_OPEN_RANGE then
				-- "Open" the door (destroy or move)
				if door:IsA("Model") then
					local doorPart = door.PrimaryPart or door:FindFirstChildWhichIsA("BasePart")
					if doorPart then
						doorPart.CanCollide = false
						doorPart.Transparency = 0.8
					end
				else
					door.CanCollide = false
					door.Transparency = 0.8
				end

				-- Broadcast door open event
				Events.FireAllClients("Dinosaur", "IndoraptorOpenDoor", {
					dinoId = self.id,
					doorPosition = doorPos,
				})

				print(`[Indoraptor] Opened door!`)
				return "Success"
			end
		end
	end

	return "Failure"
end

--[[
	Shadow patrol action - stick to dark areas
]]
function Indoraptor:ShadowPatrolAction(context: any): string
	self:SetState("Patrol")
	self.isStalking = true
	self.isDetected = false

	-- Slow patrol speed
	if self.model then
		local humanoid = self.model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = self.stats.speed * 0.6
		end
	end

	-- Random patrol
	if math.random() < 0.01 then
		local wanderOffset = Vector3.new(
			(math.random() - 0.5) * 40,
			0,
			(math.random() - 0.5) * 40
		)
		self:MoveTo(self.homePosition + wanderOffset)
	end

	-- Scan for targets
	if self:ScanForTargets() then
		context.target = self.target
		if self.behaviorTree then
			self.behaviorTree:SetTarget(self.target)
		end
	end

	return "Success"
end

--[[
	Override CanSee to account for night vision
]]
function Indoraptor:CanSee(target: Player): boolean
	-- Indoraptor has night vision - always can see in dark
	-- For now, just use base implementation
	-- In full implementation, would ignore lighting conditions
	return DinosaurBase.CanSee(self, target)
end

return Indoraptor
