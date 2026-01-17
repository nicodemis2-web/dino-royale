--!strict
--[[
	SniperRifle.lua
	===============
	Sniper rifle weapon class
	Single shot with scope, sway, and hold breath mechanic
]]

local WeaponBase = require(script.Parent.WeaponBase)
local Types = require(script.Parent.Parent.Types)

local SniperRifle = {}
SniperRifle.__index = SniperRifle
setmetatable(SniperRifle, { __index = WeaponBase })

export type SniperInstance = WeaponBase.WeaponInstance & {
	_isScoped: boolean,
	_isHoldingBreath: boolean,
	_breathHoldTime: number,
	_swayOffset: Vector2,
	_swayTime: number,
}

-- Sway configuration
local SWAY_FREQUENCY = 1.5 -- Cycles per second
local SWAY_AMPLITUDE = 0.02 -- Base sway amount
local BREATH_HOLD_DURATION = 5 -- Seconds can hold breath
local _BREATH_HOLD_COOLDOWN = 3 -- Seconds before can hold again (reserved for future use)

--[[
	Create a new sniper rifle instance
	@param weaponId The weapon ID
	@param rarity The weapon rarity
	@return New SniperInstance
]]
function SniperRifle.new(weaponId: string, rarity: Types.Rarity): SniperInstance
	local base = WeaponBase.new(weaponId, rarity)
	local self = setmetatable(base, SniperRifle) :: any

	self._isScoped = false
	self._isHoldingBreath = false
	self._breathHoldTime = 0
	self._swayOffset = Vector2.new(0, 0)
	self._swayTime = 0

	return self :: SniperInstance
end

--[[
	Override fire with sniper-specific behavior
]]
function SniperRifle.Fire(self: SniperInstance, origin: Vector3, direction: Vector3): WeaponBase.FireResult
	if not WeaponBase.CanFire(self) then
		return {
			success = false,
			reason = self.state.isReloading and "Reloading" or self.state.currentAmmo <= 0 and "NoAmmo" or "FireRate",
		}
	end

	-- Apply sway to direction if scoped and not holding breath
	local finalDirection = direction
	if self._isScoped and not self._isHoldingBreath then
		finalDirection = SniperRifle.ApplySway(self, direction)
	end

	-- Scoped snipers have perfect accuracy when still and holding breath
	local spreadVector = finalDirection
	if not self._isScoped or not self._isHoldingBreath then
		spreadVector = WeaponBase.CalculateSpread(self, finalDirection)
	end

	-- Update state
	self.state.currentAmmo = self.state.currentAmmo - 1
	self.state.lastFireTime = tick()

	-- Unscope after firing (bolt action feel)
	if self._isScoped then
		self._isScoped = false
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
	Apply scope sway to direction
]]
function SniperRifle.ApplySway(self: SniperInstance, direction: Vector3): Vector3
	local swayX = self._swayOffset.X * SWAY_AMPLITUDE
	local swayY = self._swayOffset.Y * SWAY_AMPLITUDE

	local swayCFrame = CFrame.new(Vector3.zero, direction) * CFrame.Angles(swayY, swayX, 0)

	return swayCFrame.LookVector
end

--[[
	Update sway (should be called every frame when scoped)
	@param dt Delta time
]]
function SniperRifle.UpdateSway(self: SniperInstance, dt: number)
	self._swayTime = self._swayTime + dt

	-- Figure-8 pattern sway
	local t = self._swayTime * SWAY_FREQUENCY * math.pi * 2
	self._swayOffset = Vector2.new(math.sin(t), math.sin(t * 2) * 0.5)
end

--[[
	Enter scope mode
]]
function SniperRifle.Scope(self: SniperInstance)
	self._isScoped = true
	self._swayTime = 0
end

--[[
	Exit scope mode
]]
function SniperRifle.Unscope(self: SniperInstance)
	self._isScoped = false
	self._isHoldingBreath = false
end

--[[
	Start holding breath (steadies aim)
	@return Whether breath hold started
]]
function SniperRifle.HoldBreath(self: SniperInstance): boolean
	if not self._isScoped then
		return false
	end

	self._isHoldingBreath = true
	self._breathHoldTime = tick()
	return true
end

--[[
	Release breath
]]
function SniperRifle.ReleaseBreath(self: SniperInstance)
	self._isHoldingBreath = false
end

--[[
	Check if breath hold has expired
	@return Whether breath hold is still active
]]
function SniperRifle.CheckBreathHold(self: SniperInstance): boolean
	if not self._isHoldingBreath then
		return false
	end

	local holdDuration = tick() - self._breathHoldTime
	if holdDuration >= BREATH_HOLD_DURATION then
		self._isHoldingBreath = false
		return false
	end

	return true
end

--[[
	Get remaining breath hold time
	@return Seconds remaining
]]
function SniperRifle.GetBreathHoldRemaining(self: SniperInstance): number
	if not self._isHoldingBreath then
		return BREATH_HOLD_DURATION
	end

	local holdDuration = tick() - self._breathHoldTime
	return math.max(0, BREATH_HOLD_DURATION - holdDuration)
end

--[[
	Check if scoped
	@return Whether currently scoped
]]
function SniperRifle.IsScoped(self: SniperInstance): boolean
	return self._isScoped
end

--[[
	Get scope zoom level
	@return Zoom multiplier
]]
function SniperRifle.GetScopeZoom(self: SniperInstance): number
	return self.definition.scopeZoom or 4
end

--[[
	Get current sway offset (for UI)
	@return Vector2 sway offset
]]
function SniperRifle.GetSwayOffset(self: SniperInstance): Vector2
	if self._isHoldingBreath then
		return Vector2.new(0, 0)
	end
	return self._swayOffset
end

--[[
	Check if weapon is automatic
	@return Always false for sniper
]]
function SniperRifle.IsAutomatic(_self: SniperInstance): boolean
	return false
end

--[[
	Get recoil for sniper (high vertical kick)
	@return Vector2 recoil
]]
function SniperRifle.GetRecoil(_self: SniperInstance): Vector2
	return Vector2.new((math.random() - 0.5) * 0.2, 3.0 + (math.random() * 0.5))
end

return SniperRifle
