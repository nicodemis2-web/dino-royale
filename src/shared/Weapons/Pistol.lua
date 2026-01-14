--!strict
--[[
	Pistol.lua
	==========
	Pistol weapon class
	Semi-automatic with fast weapon switch time
]]

local WeaponBase = require(script.Parent.WeaponBase)
local Types = require(script.Parent.Parent.Types)

local Pistol = {}
Pistol.__index = Pistol
setmetatable(Pistol, { __index = WeaponBase })

export type PistolInstance = WeaponBase.WeaponInstance & {
	_lastTriggerPull: number,
}

-- Pistol-specific configuration
local FAST_SWITCH_TIME = 0.3 -- Seconds to switch to/from pistol
local TRIGGER_RESET_TIME = 0.05 -- Minimum time between trigger pulls

--[[
	Create a new pistol instance
	@param weaponId The weapon ID
	@param rarity The weapon rarity
	@return New PistolInstance
]]
function Pistol.new(weaponId: string, rarity: Types.Rarity): PistolInstance
	local base = WeaponBase.new(weaponId, rarity)
	local self = setmetatable(base, Pistol) :: any

	self._lastTriggerPull = 0

	return self :: PistolInstance
end

--[[
	Override fire for semi-auto behavior
]]
function Pistol.Fire(self: PistolInstance, origin: Vector3, direction: Vector3): WeaponBase.FireResult
	-- Check trigger reset (prevent spam clicking faster than fire rate)
	local currentTime = tick()
	if currentTime - self._lastTriggerPull < TRIGGER_RESET_TIME then
		return {
			success = false,
			reason = "TriggerReset",
		}
	end
	self._lastTriggerPull = currentTime

	if not WeaponBase.CanFire(self) then
		return {
			success = false,
			reason = self.state.isReloading and "Reloading" or self.state.currentAmmo <= 0 and "NoAmmo" or "FireRate",
		}
	end

	-- Calculate spread
	local spreadVector = WeaponBase.CalculateSpread(self, direction)

	-- Update state
	self.state.currentAmmo = self.state.currentAmmo - 1
	self.state.lastFireTime = tick()

	-- Pistols have moderate bloom buildup
	self._spreadBloom = math.min(1.0, self._spreadBloom + 0.15)

	return {
		success = true,
		origin = origin,
		direction = direction,
		spread = spreadVector,
		damage = self.stats.damage,
	}
end

--[[
	Get weapon switch time (faster for pistols)
	@return Switch time in seconds
]]
function Pistol.GetSwitchTime(self: PistolInstance): number
	return FAST_SWITCH_TIME
end

--[[
	Check if weapon is automatic
	@return Always false for pistol
]]
function Pistol.IsAutomatic(self: PistolInstance): boolean
	return false
end

--[[
	Get recoil for pistol (moderate kick)
	@return Vector2 recoil
]]
function Pistol.GetRecoil(self: PistolInstance): Vector2
	local vertical = 0.8 + (math.random() * 0.3)
	local horizontal = (math.random() - 0.5) * 0.3
	return Vector2.new(horizontal, vertical)
end

--[[
	Check if this is a sidearm (for slot logic)
	@return Always true for pistol
]]
function Pistol.IsSidearm(self: PistolInstance): boolean
	return true
end

return Pistol
