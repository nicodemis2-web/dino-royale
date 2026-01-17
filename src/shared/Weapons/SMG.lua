--!strict
--[[
	SMG.lua
	=======
	SMG weapon class
	Automatic fire with higher spread and faster fire rate
]]

local WeaponBase = require(script.Parent.WeaponBase)
local Types = require(script.Parent.Parent.Types)

local SMG = {}
SMG.__index = SMG
setmetatable(SMG, { __index = WeaponBase })

export type SMGInstance = WeaponBase.WeaponInstance & {
	_burstFired: number,
}

-- SMG-specific recoil (less than AR, more horizontal)
local RECOIL_MULTIPLIER = 0.7
local HORIZONTAL_SWAY = 0.15

--[[
	Create a new SMG instance
	@param weaponId The weapon ID
	@param rarity The weapon rarity
	@return New SMGInstance
]]
function SMG.new(weaponId: string, rarity: Types.Rarity): SMGInstance
	local base = WeaponBase.new(weaponId, rarity)
	local self = setmetatable(base, SMG) :: any

	self._burstFired = 0

	return self :: SMGInstance
end

--[[
	Override fire with SMG-specific behavior
]]
function SMG.Fire(self: SMGInstance, origin: Vector3, direction: Vector3): WeaponBase.FireResult
	if not WeaponBase.CanFire(self) then
		return {
			success = false,
			reason = self.state.isReloading and "Reloading" or self.state.currentAmmo <= 0 and "NoAmmo" or "FireRate",
		}
	end

	-- SMGs have more horizontal spread variation
	local spreadVector = SMG.CalculateSpread(self, direction)

	-- Update state
	self.state.currentAmmo = self.state.currentAmmo - 1
	self.state.lastFireTime = tick()
	self._burstFired = self._burstFired + 1

	-- Add bloom (faster buildup, faster decay for SMGs)
	self._spreadBloom = math.min(1.0, self._spreadBloom + 0.08)

	return {
		success = true,
		origin = origin,
		direction = direction,
		spread = spreadVector,
		damage = self.stats.damage,
	}
end

--[[
	Override spread calculation for SMG
]]
function SMG.CalculateSpread(self: SMGInstance, direction: Vector3): Vector3
	-- Decay bloom faster for SMGs
	local currentTime = tick()
	local timeSinceLastDecay = currentTime - self._lastBloomDecayTime
	self._spreadBloom = math.max(0, self._spreadBloom - (0.7 * timeSinceLastDecay))
	self._lastBloomDecayTime = currentTime

	-- Calculate total spread with SMG characteristics
	local baseSpread = self.stats.spread
	local bloomMultiplier = 1 + self._spreadBloom
	local totalSpread = baseSpread * bloomMultiplier

	-- SMGs have more horizontal sway
	local spreadX = (math.random() - 0.5) * 2 * totalSpread * (1 + HORIZONTAL_SWAY)
	local spreadY = (math.random() - 0.5) * 2 * totalSpread

	local spreadCFrame = CFrame.new(Vector3.zero, direction) * CFrame.Angles(spreadY, spreadX, 0)

	return spreadCFrame.LookVector
end

--[[
	Get recoil for SMG (less vertical kick)
	@return Vector2 recoil
]]
function SMG.GetRecoil(_self: SMGInstance): Vector2
	local vertical = 0.3 + (math.random() * 0.2)
	local horizontal = (math.random() - 0.5) * 0.4
	return Vector2.new(horizontal, vertical) * RECOIL_MULTIPLIER
end

--[[
	Check if weapon is automatic
	@return Always true for SMG
]]
function SMG.IsAutomatic(_self: SMGInstance): boolean
	return true
end

--[[
	Reset burst counter
]]
function SMG.ResetBurst(self: SMGInstance)
	self._burstFired = 0
end

return SMG
