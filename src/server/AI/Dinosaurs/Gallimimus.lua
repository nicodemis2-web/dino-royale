--!strict
--[[
	Gallimimus.lua
	==============
	Fast herd runners (3-6 per group)
	Peaceful grazers that stampede when threatened
	Can outrun sprinting players
]]

local DinosaurBase = require(script.Parent.Parent.DinosaurBase)
local BehaviorTree = require(script.Parent.Parent.BehaviorTree)

local Gallimimus = {}
Gallimimus.__index = Gallimimus
setmetatable(Gallimimus, { __index = DinosaurBase })

-- Herd settings
local HERD_RADIUS = 20
local STAMPEDE_SPEED_MULTIPLIER = 1.5
local STAMPEDE_DURATION = 8 -- Seconds
local STAMPEDE_DAMAGE = 10
local STAMPEDE_KNOCKBACK = 30
local GRAZE_DURATION = { 3, 8 } -- Random between min/max

-- Type for herd reference
type GalliHerd = {
	members: { any },
	leader: any?,
	center: Vector3,
	isStampeding: boolean,
	stampedeDirection: Vector3,
	stampedeEndTime: number,
}

--[[
	Create a new Gallimimus
	@param position Spawn position
	@return Gallimimus instance
]]
function Gallimimus.new(position: Vector3): any
	local self = setmetatable(DinosaurBase.new("Gallimimus", position), Gallimimus) :: any

	-- Override stats
	self.stats.speed = 35 -- Very fast
	self.stats.damage = 10 -- Stampede damage

	-- Galli-specific state
	self.isGrazing = false
	self.grazeEndTime = 0
	self.herd = nil :: GalliHerd?
	self.isLeader = false
	self.alertCallCooldown = 0

	return self
end

--[[
	Create galli-specific behavior tree
]]
function Gallimimus:CreateDefaultBehaviorTree(): any
	local tree = BehaviorTree.Selector({
		-- Stampede if herd is stampeding
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return self.herd and self.herd.isStampeding
			end, "HerdStampeding"),
			BehaviorTree.Action(function(ctx)
				return self:StampedeAction(ctx)
			end, "Stampede"),
		}, "StampedeSequence"),

		-- Flee if threatened (seen or damaged)
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return ctx.target ~= nil or ctx.alertLevel > 2
			end, "IsThreatened"),
			BehaviorTree.Action(function(ctx)
				return self:TriggerStampede(ctx)
			end, "TriggerStampede"),
		}, "FleeSequence"),

		-- Alert on gunfire nearby
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return ctx.alertLevel > 0
			end, "HeardGunfire"),
			BehaviorTree.Action(function(ctx)
				return self:AlertAction(ctx)
			end, "Alert"),
		}, "AlertSequence"),

		-- Default: Graze peacefully
		BehaviorTree.Action(function(ctx)
			return self:GrazeAction(ctx)
		end, "Graze"),
	}, "GalliRoot")

	return BehaviorTree.new(tree, self)
end

--[[
	Get nearby herd members
]]
function Gallimimus:GetNearbyHerdMembers(): { any }
	local nearby = {} :: { any }

	if self.herd and self.herd.members then
		for _, member in ipairs(self.herd.members) do
			if member ~= self and member.isAlive then
				local distance = (member.currentPosition - self.currentPosition).Magnitude
				if distance <= HERD_RADIUS then
					table.insert(nearby, member)
				end
			end
		end
	end

	return nearby
end

--[[
	Grazing action - peaceful wandering
]]
function Gallimimus:GrazeAction(context: any): string
	self:SetState("Idle")

	local now = tick()

	-- Check if currently grazing (stationary)
	if self.isGrazing then
		if now < self.grazeEndTime then
			-- Still grazing, stay still
			return "Success"
		else
			-- Done grazing, will move next frame
			self.isGrazing = false
		end
	end

	-- Random chance to start grazing
	if math.random() < 0.02 then -- 2% chance per frame
		self.isGrazing = true
		self.grazeEndTime = now + math.random(GRAZE_DURATION[1], GRAZE_DURATION[2])
		return "Success"
	end

	-- Move toward herd center or wander
	local targetPos: Vector3

	if self.herd then
		-- Calculate herd center
		local center = Vector3.zero
		local count = 0
		for _, member in ipairs(self.herd.members) do
			if member.isAlive then
				center = center + member.currentPosition
				count = count + 1
			end
		end

		if count > 0 then
			center = center / count
			self.herd.center = center
		end

		-- If leader, wander; otherwise follow leader
		if self.isLeader then
			local wanderOffset = Vector3.new(
				(math.random() - 0.5) * 10,
				0,
				(math.random() - 0.5) * 10
			)
			targetPos = self.homePosition + wanderOffset
		else
			-- Follow center with slight offset
			local offset = Vector3.new(
				(math.random() - 0.5) * 5,
				0,
				(math.random() - 0.5) * 5
			)
			targetPos = center + offset
		end
	else
		-- Solo wander
		local wanderOffset = Vector3.new(
			(math.random() - 0.5) * 10,
			0,
			(math.random() - 0.5) * 10
		)
		targetPos = self.homePosition + wanderOffset
	end

	self:MoveTo(targetPos)

	-- Scan for threats while grazing
	if self:ScanForTargets() then
		context.alertLevel = 3
	end

	return "Success"
end

--[[
	Alert action - heard something, prepare to flee
]]
function Gallimimus:AlertAction(context: any): string
	self:SetState("Alert")

	-- Alert call to warn nearby Gallimimus
	if self.alertCallCooldown <= 0 then
		self:AlertCall()
		self.alertCallCooldown = 2 -- Cooldown between calls
	else
		self.alertCallCooldown = self.alertCallCooldown - context.dt
	end

	-- Decrease alert over time
	context.alertLevel = context.alertLevel - context.dt * 0.5

	-- If very alert, might trigger stampede
	if context.alertLevel > 2 then
		return self:TriggerStampede(context)
	end

	return "Running"
end

--[[
	Alert call - warn nearby Gallimimus
]]
function Gallimimus:AlertCall()
	local nearby = self:GetNearbyHerdMembers()

	for _, galli in ipairs(nearby) do
		if galli.behaviorTree then
			galli.behaviorTree.context.alertLevel = math.max(galli.behaviorTree.context.alertLevel, 2)
		end
	end

	-- Could play alert sound here
	print(`[Gallimimus] {self.id} alert call!`)
end

--[[
	Trigger herd stampede
]]
function Gallimimus:TriggerStampede(context: any): string
	if not self.herd then
		-- Solo flee
		return self:FleeAction(context)
	end

	-- Already stampeding
	if self.herd.isStampeding then
		return self:StampedeAction(context)
	end

	-- Start stampede
	self.herd.isStampeding = true
	self.herd.stampedeEndTime = tick() + STAMPEDE_DURATION

	-- Determine stampede direction (away from threat)
	if context.lastTargetPosition then
		self.herd.stampedeDirection = (self.herd.center - context.lastTargetPosition).Unit
	else
		-- Random direction
		local angle = math.random() * math.pi * 2
		self.herd.stampedeDirection = Vector3.new(math.cos(angle), 0, math.sin(angle))
	end

	print(`[Gallimimus] Herd stampede triggered!`)

	return self:StampedeAction(context)
end

--[[
	Stampede action - run fast in herd direction
]]
function Gallimimus:StampedeAction(context: any): string
	self:SetState("Flee")

	if not self.herd then
		return "Failure"
	end

	-- Check if stampede should end
	if tick() >= self.herd.stampedeEndTime then
		self.herd.isStampeding = false
		context.alertLevel = 0
		return "Success"
	end

	-- Increase speed during stampede
	if self.model then
		local humanoid = self.model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = self.stats.speed * STAMPEDE_SPEED_MULTIPLIER
		end
	end

	-- Run in stampede direction
	local targetPos = self.currentPosition + self.herd.stampedeDirection * 20
	self:MoveTo(targetPos)

	-- Check for collisions with players (stampede damage)
	self:CheckStampedeCollisions()

	return "Running"
end

--[[
	Check for stampede collisions with players
]]
function Gallimimus:CheckStampedeCollisions()
	local Players = game:GetService("Players")

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if rootPart then
				local distance = (rootPart.Position - self.currentPosition).Magnitude

				if distance < 5 then -- Collision range
					-- Apply stampede damage
					local humanoid = character:FindFirstChildOfClass("Humanoid")
					if humanoid then
						humanoid:TakeDamage(STAMPEDE_DAMAGE)

						-- Apply knockback
						local knockbackDir = (rootPart.Position - self.currentPosition).Unit
						rootPart.AssemblyLinearVelocity = knockbackDir * STAMPEDE_KNOCKBACK + Vector3.new(0, 10, 0)
					end
				end
			end
		end
	end
end

--[[
	Override TakeDamage to trigger flight response
]]
function Gallimimus:TakeDamage(amount: number, source: Player?)
	-- Call base damage
	DinosaurBase.TakeDamage(self, amount, source)

	-- Trigger stampede on damage
	if self.behaviorTree then
		self.behaviorTree.context.alertLevel = 5 -- Maximum alert
		if source then
			self.behaviorTree:SetTarget(source)
		end
	end
end

--[[
	Create a herd of Gallimimus
	@param position Center position
	@param count Number of gallis (3-6)
	@return Herd data
]]
function Gallimimus.CreateHerd(position: Vector3, count: number?): GalliHerd
	local herdSize = count or math.random(3, 6)
	local herd: GalliHerd = {
		members = {},
		leader = nil,
		center = position,
		isStampeding = false,
		stampedeDirection = Vector3.zero,
		stampedeEndTime = 0,
	}

	for i = 1, herdSize do
		local offset = Vector3.new(
			(math.random() - 0.5) * 15,
			0,
			(math.random() - 0.5) * 15
		)
		local spawnPos = position + offset

		local galli = Gallimimus.new(spawnPos)
		galli.herd = herd
		table.insert(herd.members, galli)

		-- First one is leader
		if i == 1 then
			galli.isLeader = true
			herd.leader = galli
		end
	end

	return herd
end

return Gallimimus
