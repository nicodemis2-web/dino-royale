--!strict
--[[
	EquipmentBase.lua
	=================
	Base class for all tactical equipment
	Provides common functionality for throwables and deployables
]]

export type EquipmentStats = {
	name: string,
	displayName: string,
	description: string,
	category: string, -- "Throwable" | "Deployable" | "Consumable"
	rarity: string,

	-- Stack
	maxStack: number,

	-- Usage
	useTime: number, -- Time to use/throw
	cooldown: number, -- Cooldown between uses

	-- Throwable properties (if applicable)
	throwForce: number?,
	throwArc: number?,
	fuseTime: number?,

	-- Effect
	effectRadius: number?,
	effectDuration: number?,
}

local EquipmentBase = {}
EquipmentBase.__index = EquipmentBase

--[[
	Create new equipment instance
]]
function EquipmentBase.new(stats: EquipmentStats, config: any?): any
	local self = setmetatable({}, EquipmentBase)

	self.stats = stats
	self.owner = config and config.owner or nil
	self.count = config and config.count or 1
	self.lastUseTime = 0
	self.isUsing = false

	return self
end

--[[
	Check if can use equipment
]]
function EquipmentBase:CanUse(): boolean
	if self.count <= 0 then return false end
	if self.isUsing then return false end
	if tick() - self.lastUseTime < self.stats.cooldown then return false end

	return true
end

--[[
	Use equipment
]]
function EquipmentBase:Use(_origin: Vector3, _direction: Vector3): any
	if not self:CanUse() then return nil end

	self.isUsing = true
	self.lastUseTime = tick()

	-- Override in subclass
	return nil
end

--[[
	Complete use
]]
function EquipmentBase:OnUseComplete()
	self.isUsing = false
	self.count = self.count - 1
end

--[[
	Add to stack
]]
function EquipmentBase:AddToStack(amount: number): number
	local space = self.stats.maxStack - self.count
	local added = math.min(amount, space)
	self.count = self.count + added
	return added
end

--[[
	Get remaining cooldown
]]
function EquipmentBase:GetCooldownRemaining(): number
	return math.max(0, self.stats.cooldown - (tick() - self.lastUseTime))
end

--[[
	Get display info
]]
function EquipmentBase:GetDisplayInfo(): any
	return {
		name = self.stats.name,
		displayName = self.stats.displayName,
		description = self.stats.description,
		category = self.stats.category,
		rarity = self.stats.rarity,
		count = self.count,
		maxStack = self.stats.maxStack,
		cooldownRemaining = self:GetCooldownRemaining(),
		canUse = self:CanUse(),
	}
end

return EquipmentBase
