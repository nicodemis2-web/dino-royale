--!strict
--[[
	Triceratops.lua
	===============
	Protective, peaceful grazer that charges when threatened
	High health, powerful charge attack
]]

local DinosaurBase = require(script.Parent.Parent.DinosaurBase)
local BehaviorTree = require(script.Parent.Parent.BehaviorTree)
local Events = require(game.ReplicatedStorage.Shared.Events)

local Triceratops = {}
Triceratops.__index = Triceratops
setmetatable(Triceratops, { __index = DinosaurBase })

-- Charge settings
local CHARGE_SPEED = 30
local CHARGE_DAMAGE = 40
local CHARGE_KNOCKBACK = 50
local CHARGE_DURATION = 3
local CHARGE_COOLDOWN = 8
local WARNING_DURATION = 2
local PERSONAL_SPACE = 10 -- Aggro if player stays this close too long
local PERSONAL_SPACE_TOLERANCE = 3 -- Seconds before aggro

--[[
	Create a new Triceratops
	@param position Spawn position
	@return Triceratops instance
]]
function Triceratops.new(position: Vector3): any
	local self = setmetatable(DinosaurBase.new("Triceratops", position), Triceratops) :: any

	-- Override stats
	self.stats.health = 300
	self.stats.maxHealth = 300
	self.stats.damage = CHARGE_DAMAGE
	self.stats.speed = 22
	self.stats.attackRange = 6

	-- Trike-specific state
	self.isCharging = false
	self.chargeDirection = Vector3.zero
	self.chargeEndTime = 0
	self.lastChargeTime = 0

	self.isWarning = false
	self.warningEndTime = 0

	self.personalSpaceInvader = nil :: Player?
	self.personalSpaceTime = 0

	return self
end

--[[
	Create trike-specific behavior tree
]]
function Triceratops:CreateDefaultBehaviorTree(): any
	local tree = BehaviorTree.Selector({
		-- Continue charging if currently charging
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return self.isCharging
			end, "IsCharging"),
			BehaviorTree.Action(function(ctx)
				return self:ChargeAction(ctx)
			end, "Charge"),
		}, "ChargeSequence"),

		-- Instant charge if attacked
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return ctx.target ~= nil and ctx.alertLevel > 3
			end, "WasAttacked"),
			BehaviorTree.Action(function(ctx)
				return self:StartCharge(ctx)
			end, "StartChargeFromAttack"),
		}, "AttackResponseSequence"),

		-- Warning if player too close
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return self:HasPersonalSpaceInvader() and not self.isWarning
			end, "PersonalSpaceInvaded"),
			BehaviorTree.Action(function(ctx)
				return self:StartWarning(ctx)
			end, "StartWarning"),
		}, "WarningStartSequence"),

		-- Continue warning
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return self.isWarning
			end, "IsWarning"),
			BehaviorTree.Action(function(ctx)
				return self:WarningAction(ctx)
			end, "Warning"),
		}, "WarningSequence"),

		-- Charge if has target and warning finished
		BehaviorTree.Sequence({
			BehaviorTree.Condition(function(ctx)
				return ctx.target ~= nil and self:CanCharge()
			end, "CanCharge"),
			BehaviorTree.Action(function(ctx)
				return self:StartCharge(ctx)
			end, "StartCharge"),
		}, "ChargeStartSequence"),

		-- Default: Graze peacefully
		BehaviorTree.Action(function(ctx)
			return self:GrazeAction(ctx)
		end, "Graze"),
	}, "TrikeRoot")

	return BehaviorTree.new(tree, self)
end

--[[
	Check if player is invading personal space
]]
function Triceratops:HasPersonalSpaceInvader(): boolean
	local Players = game:GetService("Players")

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if rootPart then
				local distance = (rootPart.Position - self.currentPosition).Magnitude
				if distance <= PERSONAL_SPACE then
					-- Track how long they've been close
					if self.personalSpaceInvader == player then
						self.personalSpaceTime = self.personalSpaceTime + 0.1 -- Approximate frame time
					else
						self.personalSpaceInvader = player
						self.personalSpaceTime = 0
					end

					-- Check if they've been too close too long
					if self.personalSpaceTime >= PERSONAL_SPACE_TOLERANCE then
						return true
					end
				end
			end
		end
	end

	return false
end

--[[
	Check if can charge (off cooldown)
]]
function Triceratops:CanCharge(): boolean
	return tick() - self.lastChargeTime >= CHARGE_COOLDOWN
end

--[[
	Start warning display
]]
function Triceratops:StartWarning(context: any): string
	self:SetState("Alert")
	self.isWarning = true
	self.warningEndTime = tick() + WARNING_DURATION

	-- Target the invader
	if self.personalSpaceInvader then
		self.target = self.personalSpaceInvader
		if self.behaviorTree then
			self.behaviorTree:SetTarget(self.personalSpaceInvader)
		end
	end

	-- Broadcast warning
	Events.FireAllClients("Dinosaur", "DinosaurWarning", {
		dinoId = self.id,
		type = "HeadShake",
		duration = WARNING_DURATION,
	})

	print(`[Triceratops] {self.id} warning - head shake and snort!`)

	return "Success"
end

--[[
	Warning action - head shake and snort
]]
function Triceratops:WarningAction(context: any): string
	self:SetState("Alert")

	if tick() >= self.warningEndTime then
		self.isWarning = false

		-- Check if invader is still close
		if self.personalSpaceInvader then
			local character = self.personalSpaceInvader.Character
			if character then
				local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if rootPart then
					local distance = (rootPart.Position - self.currentPosition).Magnitude
					if distance <= PERSONAL_SPACE * 1.5 then
						-- They didn't leave - charge!
						context.target = self.personalSpaceInvader
						print(`[Triceratops] {self.id} charging - invader didn't leave!`)
					end
				end
			end
		end

		return "Success"
	end

	-- Face the invader
	if self.personalSpaceInvader and self.personalSpaceInvader.Character then
		local targetRoot = self.personalSpaceInvader.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
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
	Start charge attack
]]
function Triceratops:StartCharge(context: any): string
	if not context.target or not context.target.Character then
		return "Failure"
	end

	local targetRoot = context.target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not targetRoot then
		return "Failure"
	end

	self.isCharging = true
	self.chargeEndTime = tick() + CHARGE_DURATION
	self.lastChargeTime = tick()

	-- Lock charge direction toward target
	local direction = (targetRoot.Position - self.currentPosition)
	direction = Vector3.new(direction.X, 0, direction.Z).Unit
	self.chargeDirection = direction

	-- Set charge speed
	if self.model then
		local humanoid = self.model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = CHARGE_SPEED
		end
	end

	-- Broadcast charge event
	Events.FireAllClients("Dinosaur", "DinosaurCharge", {
		dinoId = self.id,
		direction = self.chargeDirection,
	})

	print(`[Triceratops] {self.id} charging!`)

	return self:ChargeAction(context)
end

--[[
	Charge action - run in locked direction
]]
function Triceratops:ChargeAction(context: any): string
	self:SetState("Attack")

	-- Check if charge should end
	if tick() >= self.chargeEndTime then
		self.isCharging = false

		-- Reset speed
		if self.model then
			local humanoid = self.model:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.WalkSpeed = self.stats.speed
			end
		end

		return "Success"
	end

	-- Move in charge direction
	local targetPos = self.currentPosition + self.chargeDirection * 20
	self:MoveTo(targetPos)

	-- Check for collisions
	self:CheckChargeCollisions()

	-- Check for destructible objects
	self:CheckDestructibles()

	return "Running"
end

--[[
	Check for charge collisions with players
]]
function Triceratops:CheckChargeCollisions()
	local Players = game:GetService("Players")

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if rootPart then
				local distance = (rootPart.Position - self.currentPosition).Magnitude

				if distance < 6 then -- Collision range
					-- Apply charge damage
					local humanoid = character:FindFirstChildOfClass("Humanoid")
					if humanoid then
						humanoid:TakeDamage(CHARGE_DAMAGE)

						-- Apply knockback
						local knockbackDir = self.chargeDirection + Vector3.new(0, 0.3, 0)
						rootPart.AssemblyLinearVelocity = knockbackDir.Unit * CHARGE_KNOCKBACK

						print(`[Triceratops] {self.id} hit {player.Name} with charge!`)

						-- Only hit once per charge
						self.chargeEndTime = tick() -- End charge on hit
					end
				end
			end
		end
	end
end

--[[
	Check for destructible objects to break through
]]
function Triceratops:CheckDestructibles()
	-- Check for parts tagged as destructible
	local CollectionService = game:GetService("CollectionService")
	local destructibles = CollectionService:GetTagged("Destructible")

	for _, part in ipairs(destructibles) do
		if part:IsA("BasePart") then
			local distance = (part.Position - self.currentPosition).Magnitude
			if distance < 8 then
				-- Destroy the part
				part:Destroy()
				print(`[Triceratops] {self.id} destroyed cover!`)
			end
		end
	end
end

--[[
	Graze action - peaceful wandering
]]
function Triceratops:GrazeAction(context: any): string
	self:SetState("Idle")

	-- Reset personal space tracking when peaceful
	self.personalSpaceInvader = nil
	self.personalSpaceTime = 0

	-- Random wandering
	if math.random() < 0.01 then
		local wanderOffset = Vector3.new(
			(math.random() - 0.5) * 20,
			0,
			(math.random() - 0.5) * 20
		)
		local targetPos = self.homePosition + wanderOffset
		self:MoveTo(targetPos)
	end

	return "Success"
end

--[[
	Override TakeDamage to trigger instant charge
]]
function Triceratops:TakeDamage(amount: number, source: Player?)
	-- Call base damage
	DinosaurBase.TakeDamage(self, amount, source)

	-- Set high alert for immediate charge response
	if source then
		self.target = source
		if self.behaviorTree then
			self.behaviorTree:SetTarget(source)
			self.behaviorTree.context.alertLevel = 5 -- Maximum alert
		end
	end
end

return Triceratops
