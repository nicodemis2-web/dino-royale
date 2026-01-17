--!strict
--[[
	DMR.lua
	=======
	Designated Marksman Rifle weapon class
	Semi-automatic with medium scope
]]

local WeaponBase = require(script.Parent.WeaponBase)
local Types = require(script.Parent.Parent.Types)

local DMR = {}
DMR.__index = DMR
setmetatable(DMR, { __index = WeaponBase })

export type DMRInstance = WeaponBase.WeaponInstance & {
	_isScoped: boolean,
	_consecutiveShots: number,
}

-- DMR-specific configuration
local SCOPE_SPREAD_REDUCTION = 0.5 -- 50% less spread when scoped
local MAX_FIRE_RATE_PENALTY = 0.3 -- Penalty for firing at max rate

--[[
	Create a new DMR instance
	@param weaponId The weapon ID
	@param rarity The weapon rarity
	@return New DMRInstance
]]
function DMR.new(weaponId: string, rarity: Types.Rarity): DMRInstance
	local base = WeaponBase.new(weaponId, rarity)
	local self = setmetatable(base, DMR) :: any

	self._isScoped = false
	self._consecutiveShots = 0

	return self :: DMRInstance
end

--[[
	Override fire with DMR-specific behavior
]]
function DMR.Fire(self: DMRInstance, origin: Vector3, direction: Vector3): WeaponBase.FireResult
	if not WeaponBase.CanFire(self) then
		return {
			success = false,
			reason = self.state.isReloading and "Reloading" or self.state.currentAmmo <= 0 and "NoAmmo" or "FireRate",
		}
	end

	-- Track consecutive shots for accuracy penalty
	local timeSinceLastFire = tick() - self.state.lastFireTime
	local fireInterval = 1 / self.stats.fireRate

	if timeSinceLastFire < fireInterval * 1.5 then
		self._consecutiveShots = self._consecutiveShots + 1
	else
		self._consecutiveShots = 0
	end

	-- Calculate spread with scope and consecutive fire penalties
	local spreadMultiplier = 1.0

	if self._isScoped then
		spreadMultiplier = spreadMultiplier * SCOPE_SPREAD_REDUCTION
	end

	-- Penalty for rapid fire
	if self._consecutiveShots > 2 then
		spreadMultiplier = spreadMultiplier * (1 + MAX_FIRE_RATE_PENALTY * math.min(self._consecutiveShots - 2, 5))
	end

	local originalSpread = self.stats.spread
	self.stats.spread = originalSpread * spreadMultiplier

	local spreadVector = WeaponBase.CalculateSpread(self, direction)

	self.stats.spread = originalSpread -- Restore

	-- Update state
	self.state.currentAmmo = self.state.currentAmmo - 1
	self.state.lastFireTime = tick()

	-- DMR has moderate bloom
	self._spreadBloom = math.min(1.0, self._spreadBloom + 0.12)

	return {
		success = true,
		origin = origin,
		direction = direction,
		spread = spreadVector,
		damage = self.stats.damage,
	}
end

--[[
	Enter scope mode
]]
function DMR.Scope(self: DMRInstance)
	self._isScoped = true
end

--[[
	Exit scope mode
]]
function DMR.Unscope(self: DMRInstance)
	self._isScoped = false
end

--[[
	Check if scoped
	@return Whether currently scoped
]]
function DMR.IsScoped(self: DMRInstance): boolean
	return self._isScoped
end

--[[
	Get scope zoom level
	@return Zoom multiplier
]]
function DMR.GetScopeZoom(self: DMRInstance): number
	return self.definition.scopeZoom or 2
end

--[[
	Check if weapon is automatic
	@return Always false for DMR
]]
function DMR.IsAutomatic(_self: DMRInstance): boolean
	return false
end

--[[
	Get recoil for DMR (moderate-high kick)
	@return Vector2 recoil
]]
function DMR.GetRecoil(_self: DMRInstance): Vector2
	local vertical = 1.2 + (math.random() * 0.3)
	local horizontal = (math.random() - 0.5) * 0.25
	return Vector2.new(horizontal, vertical)
end

--[[
	Reset consecutive shot counter
]]
function DMR.ResetConsecutive(self: DMRInstance)
	self._consecutiveShots = 0
end

return DMR
