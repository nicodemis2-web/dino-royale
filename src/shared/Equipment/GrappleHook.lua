--!strict
--[[
	GrappleHook.lua
	===============
	Mobility equipment for quick traversal and escaping dinosaurs
	Based on GDD Section 6.2: Tactical Equipment
]]

local EquipmentBase = require(script.Parent.EquipmentBase)

local GrappleHook = {}
GrappleHook.__index = GrappleHook
setmetatable(GrappleHook, { __index = EquipmentBase })

GrappleHook.Stats = {
	name = "GrappleHook",
	displayName = "Grapple Hook",
	description = "50m range grapple for quick traversal and escaping dinosaurs",
	category = "Deployable",
	rarity = "Rare",

	maxStack = 3,
	useTime = 0.2, -- Quick deploy
	cooldown = 1.0,

	-- Grapple properties
	maxRange = 50,
	hookSpeed = 100, -- Hook travel speed
	pullSpeed = 40, -- Player pull speed
	minAttachAngle = 30, -- Minimum angle from horizontal to attach

	-- Requirements
	requiresSolidTarget = true,
	canAttachToTerrain = true,
	canAttachToBuildings = true,
	canAttachToVehicles = false,

	-- Interruption
	canBeInterrupted = true,
	interruptOnDamage = 10, -- Interrupt if taking 10+ damage

	sounds = {
		fire = "GrappleFire",
		attach = "GrappleAttach",
		pull = "GrapplePull",
		detach = "GrappleDetach",
		fail = "GrappleFail",
	},
}

-- Grapple state
export type GrappleState = {
	isActive: boolean,
	hookPosition: Vector3?,
	attachPoint: Vector3?,
	isPulling: boolean,
	startTime: number,
}

--[[
	Create new grapple hook
]]
function GrappleHook.new(config: any?): any
	local self = EquipmentBase.new(GrappleHook.Stats, config)
	setmetatable(self, GrappleHook)

	self.grappleState = {
		isActive = false,
		hookPosition = nil,
		attachPoint = nil,
		isPulling = false,
		startTime = 0,
	} :: GrappleState

	return self
end

--[[
	Fire grapple hook
]]
function GrappleHook:Use(origin: Vector3, direction: Vector3): any
	if not self:CanUse() then return nil end
	if self.grappleState.isActive then return nil end

	self.isUsing = true
	self.lastUseTime = tick()

	self.grappleState.isActive = true
	self.grappleState.hookPosition = origin
	self.grappleState.startTime = tick()

	local grappleData = {
		type = "GrappleHook",
		origin = origin,
		direction = direction,
		maxRange = GrappleHook.Stats.maxRange,
		hookSpeed = GrappleHook.Stats.hookSpeed,
		owner = self.owner,
	}

	return grappleData
end

--[[
	Handle hook attachment
]]
function GrappleHook:OnAttach(attachPoint: Vector3)
	self.grappleState.attachPoint = attachPoint
	self.grappleState.isPulling = true
end

--[[
	Handle hook miss (no valid target)
]]
function GrappleHook:OnMiss()
	self:Cancel()
	-- Don't consume on miss
	self.count = self.count + 1
end

--[[
	Update grapple pull
]]
function GrappleHook:UpdatePull(playerPosition: Vector3, deltaTime: number): Vector3?
	if not self.grappleState.isPulling or not self.grappleState.attachPoint then
		return nil
	end

	local toAttach = self.grappleState.attachPoint - playerPosition
	local distance = toAttach.Magnitude

	-- Check if reached destination
	if distance < 2 then
		self:Complete()
		return nil
	end

	-- Calculate pull movement
	local pullDirection = toAttach.Unit
	local pullDistance = GrappleHook.Stats.pullSpeed * deltaTime

	return playerPosition + pullDirection * pullDistance
end

--[[
	Cancel grapple
]]
function GrappleHook:Cancel()
	self.grappleState.isActive = false
	self.grappleState.hookPosition = nil
	self.grappleState.attachPoint = nil
	self.grappleState.isPulling = false
	self.isUsing = false
end

--[[
	Complete grapple successfully
]]
function GrappleHook:Complete()
	self:Cancel()
	self:OnUseComplete()
end

--[[
	Handle damage while grappling
]]
function GrappleHook:OnDamage(amount: number): boolean
	if self.grappleState.isPulling and amount >= GrappleHook.Stats.interruptOnDamage then
		self:Cancel()
		return true -- Was interrupted
	end
	return false
end

--[[
	Check if target is valid grapple point
]]
function GrappleHook.IsValidTarget(targetType: string, angle: number): boolean
	-- Check angle (must be going upward somewhat)
	if angle < GrappleHook.Stats.minAttachAngle then
		return false
	end

	-- Check target type
	if targetType == "Terrain" and GrappleHook.Stats.canAttachToTerrain then
		return true
	elseif targetType == "Building" and GrappleHook.Stats.canAttachToBuildings then
		return true
	elseif targetType == "Vehicle" and GrappleHook.Stats.canAttachToVehicles then
		return true
	end

	return false
end

--[[
	Get display info
]]
function GrappleHook:GetDisplayInfo(): any
	local baseInfo = EquipmentBase.GetDisplayInfo(self)
	baseInfo.isGrappling = self.grappleState.isActive
	baseInfo.isPulling = self.grappleState.isPulling
	return baseInfo
end

return GrappleHook
