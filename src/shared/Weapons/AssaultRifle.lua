--!strict
--[[
	AssaultRifle.lua
	================
	Assault rifle weapon class
	Automatic fire mode with recoil pattern and first shot accuracy
]]

local WeaponBase = require(script.Parent.WeaponBase)
local Types = require(script.Parent.Parent.Types)

local AssaultRifle = {}
AssaultRifle.__index = AssaultRifle
setmetatable(AssaultRifle, { __index = WeaponBase })

export type AssaultRifleInstance = WeaponBase.WeaponInstance & {
	_consecutiveShots: number,
	_recoilPattern: { Vector2 },
	_recoilIndex: number,
}

-- Recoil pattern (vertical climb + slight horizontal drift)
local RECOIL_PATTERN = {
	Vector2.new(0, 0.5), -- First shot minimal
	Vector2.new(0.1, 1.0),
	Vector2.new(-0.1, 1.2),
	Vector2.new(0.15, 1.3),
	Vector2.new(-0.05, 1.4),
	Vector2.new(0.1, 1.5),
	Vector2.new(-0.15, 1.4),
	Vector2.new(0.05, 1.3),
	Vector2.new(0.1, 1.2),
	Vector2.new(-0.1, 1.1),
}

-- First shot accuracy bonus
local FIRST_SHOT_SPREAD_MULTIPLIER = 0.25

--[[
	Create a new assault rifle instance
	@param weaponId The weapon ID
	@param rarity The weapon rarity
	@return New AssaultRifleInstance
]]
function AssaultRifle.new(weaponId: string, rarity: Types.Rarity): AssaultRifleInstance
	local base = WeaponBase.new(weaponId, rarity)
	local self = setmetatable(base, AssaultRifle) :: any

	self._consecutiveShots = 0
	self._recoilPattern = RECOIL_PATTERN
	self._recoilIndex = 1

	return self :: AssaultRifleInstance
end

--[[
	Override fire to add recoil pattern
]]
function AssaultRifle.Fire(self: AssaultRifleInstance, origin: Vector3, direction: Vector3): WeaponBase.FireResult
	if not WeaponBase.CanFire(self) then
		return {
			success = false,
			reason = self.state.isReloading and "Reloading" or self.state.currentAmmo <= 0 and "NoAmmo" or "FireRate",
		}
	end

	-- Check if this is the first shot (for accuracy bonus)
	local timeSinceLastFire = tick() - self.state.lastFireTime
	local isFirstShot = timeSinceLastFire > 0.5 -- Reset after 0.5s pause

	if isFirstShot then
		self._consecutiveShots = 0
		self._recoilIndex = 1
	else
		self._consecutiveShots = self._consecutiveShots + 1
	end

	-- Calculate spread with first shot bonus
	local spreadMultiplier = isFirstShot and FIRST_SHOT_SPREAD_MULTIPLIER or 1.0
	local originalSpread = self.stats.spread
	self.stats.spread = originalSpread * spreadMultiplier

	local spreadVector = WeaponBase.CalculateSpread(self, direction)

	self.stats.spread = originalSpread -- Restore

	-- Update state
	self.state.currentAmmo = self.state.currentAmmo - 1
	self.state.lastFireTime = tick()

	-- Add bloom
	self._spreadBloom = math.min(1.0, self._spreadBloom + 0.1)

	-- Advance recoil pattern
	self._recoilIndex = ((self._recoilIndex - 1) % #self._recoilPattern) + 1 + 1
	if self._recoilIndex > #self._recoilPattern then
		self._recoilIndex = #self._recoilPattern
	end

	return {
		success = true,
		origin = origin,
		direction = direction,
		spread = spreadVector,
		damage = self.stats.damage,
	}
end

--[[
	Get current recoil offset
	@return Vector2 recoil (horizontal, vertical)
]]
function AssaultRifle.GetRecoil(self: AssaultRifleInstance): Vector2
	local pattern = self._recoilPattern[self._recoilIndex] or Vector2.new(0, 0)
	-- Add some randomization
	local randomX = (math.random() - 0.5) * 0.2
	local randomY = math.random() * 0.1
	return Vector2.new(pattern.X + randomX, pattern.Y + randomY)
end

--[[
	Reset recoil (for when stopping fire)
]]
function AssaultRifle.ResetRecoil(self: AssaultRifleInstance)
	self._consecutiveShots = 0
	self._recoilIndex = 1
end

--[[
	Check if weapon is automatic
	@return Always true for AR
]]
function AssaultRifle.IsAutomatic(self: AssaultRifleInstance): boolean
	return true
end

return AssaultRifle
