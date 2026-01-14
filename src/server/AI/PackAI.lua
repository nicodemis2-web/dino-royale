--!strict
--[[
	PackAI.lua
	==========
	Coordinates pack hunting behavior for Velociraptors
	Manages alpha/beta/scout roles and coordinated attacks
]]

local Events = require(game.ReplicatedStorage.Shared.Events)

local PackAI = {}

-- Pack role types
export type PackRole = "Alpha" | "Beta" | "Scout"

-- Pack structure
export type Pack = {
	id: string,
	species: string,
	members: { any }, -- Array of DinosaurInstances
	alpha: any?, -- DinosaurInstance
	betas: { any },
	scouts: { any },
	target: Player?,
	state: PackState,
	center: Vector3,
	homePosition: Vector3,
	isRetreating: boolean,
	lastCallTime: number,
}

export type PackState = "Idle" | "Patrolling" | "Hunting" | "Attacking" | "Retreating"

-- Settings
local MIN_PACK_SIZE_FOR_ATTACK = 2
local CALL_RANGE = 100
local CALL_COOLDOWN = 5
local FLANK_ANGLE = 120 -- degrees
local FORMATION_SPACING = 5

-- Unique ID counter
local nextPackId = 0

--[[
	Create a new pack
	@param species Species name
	@param position Center spawn position
	@param size Pack size
	@return Pack
]]
function PackAI.CreatePack(species: string, position: Vector3, size: number): Pack
	nextPackId = nextPackId + 1

	local pack: Pack = {
		id = `pack_{nextPackId}`,
		species = species,
		members = {},
		alpha = nil,
		betas = {},
		scouts = {},
		target = nil,
		state = "Idle",
		center = position,
		homePosition = position,
		isRetreating = false,
		lastCallTime = 0,
	}

	return pack
end

--[[
	Assign roles to pack members based on health and position
	@param pack The pack to assign roles to
]]
function PackAI.AssignRoles(pack: Pack)
	if #pack.members == 0 then
		return
	end

	-- Clear current roles
	pack.alpha = nil
	pack.betas = {}
	pack.scouts = {}

	-- Sort by health (highest health becomes alpha)
	local sortedMembers = {}
	for _, member in ipairs(pack.members) do
		if member.isAlive then
			table.insert(sortedMembers, member)
		end
	end

	table.sort(sortedMembers, function(a, b)
		return a.stats.health > b.stats.health
	end)

	-- Assign roles
	for i, member in ipairs(sortedMembers) do
		if i == 1 then
			-- Alpha - leader with highest health
			pack.alpha = member
			member.packRole = "Alpha"
		elseif i <= 2 or (#sortedMembers <= 3 and i == 2) then
			-- Scouts - fastest/most alert
			table.insert(pack.scouts, member)
			member.packRole = "Scout"
		else
			-- Betas - follow alpha
			table.insert(pack.betas, member)
			member.packRole = "Beta"
		end

		member.pack = pack
	end
end

--[[
	Update pack behavior
	@param pack The pack to update
	@param dt Delta time
]]
function PackAI.Update(pack: Pack, dt: number)
	if #pack.members == 0 then
		return
	end

	-- Update pack center
	pack.center = PackAI.CalculateCenter(pack)

	-- Check if pack should retreat (too few members)
	local aliveCount = PackAI.GetAliveCount(pack)
	if aliveCount < MIN_PACK_SIZE_FOR_ATTACK and pack.state == "Attacking" then
		PackAI.StartRetreat(pack)
	end

	-- Update based on state
	if pack.state == "Idle" then
		PackAI.UpdateIdle(pack, dt)
	elseif pack.state == "Patrolling" then
		PackAI.UpdatePatrol(pack, dt)
	elseif pack.state == "Hunting" then
		PackAI.UpdateHunting(pack, dt)
	elseif pack.state == "Attacking" then
		PackAI.UpdateAttacking(pack, dt)
	elseif pack.state == "Retreating" then
		PackAI.UpdateRetreating(pack, dt)
	end
end

--[[
	Get count of alive members
]]
function PackAI.GetAliveCount(pack: Pack): number
	local count = 0
	for _, member in ipairs(pack.members) do
		if member.isAlive then
			count = count + 1
		end
	end
	return count
end

--[[
	Calculate pack center position
]]
function PackAI.CalculateCenter(pack: Pack): Vector3
	local center = Vector3.zero
	local count = 0

	for _, member in ipairs(pack.members) do
		if member.isAlive then
			center = center + member.currentPosition
			count = count + 1
		end
	end

	if count > 0 then
		return center / count
	end
	return pack.homePosition
end

--[[
	Get formation position for a member
	@param pack The pack
	@param member The pack member
	@return Target position in formation
]]
function PackAI.GetFormationPosition(pack: Pack, member: any): Vector3
	if not pack.alpha or not pack.alpha.isAlive then
		return member.homePosition
	end

	local alphaPos = pack.alpha.currentPosition
	local alphaForward = pack.alpha:GetForwardVector()

	-- Triangle formation
	local role = member.packRole

	if role == "Alpha" then
		return alphaPos -- Alpha at front
	elseif role == "Scout" then
		-- Scouts ahead and to sides
		local scoutIndex = table.find(pack.scouts, member) or 1
		local angle = (scoutIndex - 1) * math.pi / 3 - math.pi / 6 -- -30 and +30 degrees
		local offset = CFrame.Angles(0, angle, 0):VectorToWorldSpace(Vector3.new(0, 0, -FORMATION_SPACING * 2))
		return alphaPos + offset
	else
		-- Betas behind alpha
		local betaIndex = table.find(pack.betas, member) or 1
		local angle = (betaIndex - 1) * math.pi / 4 - math.pi / 8
		local offset = CFrame.Angles(0, math.pi + angle, 0):VectorToWorldSpace(Vector3.new(0, 0, -FORMATION_SPACING))
		return alphaPos + offset
	end
end

--[[
	Get flanking position for attacking
	@param pack The pack
	@param member The pack member
	@param targetPos Target position
	@return Flanking position
]]
function PackAI.GetFlankPosition(pack: Pack, member: any, targetPos: Vector3): Vector3
	if not pack.alpha or not pack.alpha.isAlive then
		return targetPos
	end

	local role = member.packRole

	if role == "Alpha" then
		-- Alpha engages directly
		return targetPos
	else
		-- Others flank from angles
		local memberIndex = table.find(pack.betas, member) or table.find(pack.scouts, member) or 1
		local totalFlankers = #pack.betas + #pack.scouts

		-- Distribute around the target
		local angleOffset = (memberIndex / totalFlankers) * math.rad(FLANK_ANGLE) - math.rad(FLANK_ANGLE / 2)
		local alphaToTarget = (targetPos - pack.alpha.currentPosition).Unit
		local flankDir = CFrame.Angles(0, angleOffset + math.pi, 0):VectorToWorldSpace(alphaToTarget)

		return targetPos + flankDir * 8
	end
end

--[[
	Coordinate attack on target
	@param pack The pack
	@param target Target player
]]
function PackAI.CoordinateAttack(pack: Pack, target: Player)
	pack.target = target
	pack.state = "Attacking"

	-- Alert all members
	for _, member in ipairs(pack.members) do
		if member.isAlive and member.behaviorTree then
			member.behaviorTree:SetTarget(target)
		end
	end

	-- Broadcast attack event
	Events.FireAllClients("Dinosaur", "PackAttacking", {
		packId = pack.id,
		targetId = target.UserId,
	})

	print(`[PackAI] Pack {pack.id} attacking {target.Name}!`)
end

--[[
	Handle member death
	@param pack The pack
	@param member The dead member
]]
function PackAI.HandleMemberDeath(pack: Pack, member: any)
	-- Remove from role lists
	if pack.alpha == member then
		pack.alpha = nil
	end

	local scoutIndex = table.find(pack.scouts, member)
	if scoutIndex then
		table.remove(pack.scouts, scoutIndex)
	end

	local betaIndex = table.find(pack.betas, member)
	if betaIndex then
		table.remove(pack.betas, betaIndex)
	end

	-- Reassign roles
	PackAI.AssignRoles(pack)

	-- Check if should retreat
	local aliveCount = PackAI.GetAliveCount(pack)
	if aliveCount < MIN_PACK_SIZE_FOR_ATTACK then
		PackAI.StartRetreat(pack)
	end

	print(`[PackAI] Pack {pack.id} lost member, {aliveCount} remaining`)
end

--[[
	Pack call - alert nearby pack members
	@param pack The pack
	@param caller The member calling
]]
function PackAI.PackCall(pack: Pack, caller: any)
	local now = tick()
	if now - pack.lastCallTime < CALL_COOLDOWN then
		return
	end

	pack.lastCallTime = now

	-- Alert all members within range
	for _, member in ipairs(pack.members) do
		if member.isAlive and member ~= caller then
			local distance = (member.currentPosition - caller.currentPosition).Magnitude
			if distance <= CALL_RANGE then
				-- Set high alert
				if member.behaviorTree then
					member.behaviorTree.context.alertLevel = 5
					if pack.target then
						member.behaviorTree:SetTarget(pack.target)
					end
				end
			end
		end
	end

	-- Broadcast call event (for audio)
	Events.FireAllClients("Dinosaur", "PackCall", {
		packId = pack.id,
		position = caller.currentPosition,
	})
end

--[[
	Start pack retreat
]]
function PackAI.StartRetreat(pack: Pack)
	pack.state = "Retreating"
	pack.isRetreating = true
	pack.target = nil

	-- Clear all member targets
	for _, member in ipairs(pack.members) do
		if member.isAlive and member.behaviorTree then
			member.behaviorTree:SetTarget(nil)
			member.behaviorTree.context.alertLevel = 0
		end
	end

	print(`[PackAI] Pack {pack.id} retreating!`)
end

--[[
	Update idle state
]]
function PackAI.UpdateIdle(pack: Pack, dt: number)
	-- Occasionally start patrolling
	if math.random() < 0.01 then
		pack.state = "Patrolling"
	end
end

--[[
	Update patrol state
]]
function PackAI.UpdatePatrol(pack: Pack, dt: number)
	-- Members follow formation
	for _, member in ipairs(pack.members) do
		if member.isAlive then
			local formationPos = PackAI.GetFormationPosition(pack, member)
			member:MoveTo(formationPos)

			-- Scouts scan for targets
			if member.packRole == "Scout" then
				if member:ScanForTargets() then
					-- Found target - alert pack
					PackAI.PackCall(pack, member)
					pack.target = member.target
					pack.state = "Hunting"
					break
				end
			end
		end
	end

	-- Random direction changes for alpha
	if pack.alpha and pack.alpha.isAlive and math.random() < 0.005 then
		local wanderOffset = Vector3.new(
			(math.random() - 0.5) * 30,
			0,
			(math.random() - 0.5) * 30
		)
		pack.alpha.homePosition = pack.homePosition + wanderOffset
	end
end

--[[
	Update hunting state
]]
function PackAI.UpdateHunting(pack: Pack, dt: number)
	if not pack.target then
		pack.state = "Patrolling"
		return
	end

	local targetChar = pack.target.Character
	if not targetChar then
		pack.target = nil
		pack.state = "Patrolling"
		return
	end

	local targetRoot = targetChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not targetRoot then
		pack.target = nil
		pack.state = "Patrolling"
		return
	end

	local targetPos = targetRoot.Position

	-- Move pack toward target
	for _, member in ipairs(pack.members) do
		if member.isAlive then
			member:MoveTo(targetPos)
		end
	end

	-- Check if close enough to attack
	local distanceToTarget = (pack.center - targetPos).Magnitude
	if distanceToTarget < 30 then
		PackAI.CoordinateAttack(pack, pack.target)
	end
end

--[[
	Update attacking state
]]
function PackAI.UpdateAttacking(pack: Pack, dt: number)
	if not pack.target then
		pack.state = "Patrolling"
		return
	end

	local targetChar = pack.target.Character
	if not targetChar then
		pack.target = nil
		pack.state = "Patrolling"
		return
	end

	local targetRoot = targetChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not targetRoot then
		pack.target = nil
		pack.state = "Patrolling"
		return
	end

	local targetPos = targetRoot.Position

	-- Coordinate flanking attack
	for _, member in ipairs(pack.members) do
		if member.isAlive then
			local flankPos = PackAI.GetFlankPosition(pack, member, targetPos)
			member:MoveTo(flankPos)

			-- Alpha engages directly
			if member.packRole == "Alpha" then
				if member:IsInAttackRange(pack.target) then
					member:Attack(pack.target)
				end
			else
				-- Flankers attack when in position
				local distance = (member.currentPosition - flankPos).Magnitude
				if distance < 3 and member:IsInAttackRange(pack.target) then
					member:Attack(pack.target)
				end
			end
		end
	end
end

--[[
	Update retreating state
]]
function PackAI.UpdateRetreating(pack: Pack, dt: number)
	-- Run back to home
	for _, member in ipairs(pack.members) do
		if member.isAlive then
			member:MoveTo(pack.homePosition)
		end
	end

	-- Check if reached home
	local distanceToHome = (pack.center - pack.homePosition).Magnitude
	if distanceToHome < 20 then
		pack.state = "Idle"
		pack.isRetreating = false
	end
end

--[[
	Add member to pack
]]
function PackAI.AddMember(pack: Pack, member: any)
	table.insert(pack.members, member)
	member.pack = pack
	PackAI.AssignRoles(pack)
end

--[[
	Remove member from pack
]]
function PackAI.RemoveMember(pack: Pack, member: any)
	local index = table.find(pack.members, member)
	if index then
		table.remove(pack.members, index)
	end
	member.pack = nil
	PackAI.AssignRoles(pack)
end

return PackAI
