--!strict
--[[
	Shotgun.lua
	===========
	Shotgun weapon class
	Single shot with multiple pellets
]]

local WeaponBase = require(script.Parent.WeaponBase)
local Types = require(script.Parent.Parent.Types)

local Shotgun = {}
Shotgun.__index = Shotgun
setmetatable(Shotgun, { __index = WeaponBase })

export type PelletResult = {
	direction: Vector3,
	damage: number,
}

export type ShotgunFireResult = WeaponBase.FireResult & {
	pellets: { PelletResult }?,
}

export type ShotgunInstance = WeaponBase.WeaponInstance & {
	_shellsToReload: number,
	_isShellByShellReload: boolean,
}

--[[
	Create a new shotgun instance
	@param weaponId The weapon ID
	@param rarity The weapon rarity
	@return New ShotgunInstance
]]
function Shotgun.new(weaponId: string, rarity: Types.Rarity): ShotgunInstance
	local base = WeaponBase.new(weaponId, rarity)
	local self = setmetatable(base, Shotgun) :: any

	self._shellsToReload = 0
	self._isShellByShellReload = true -- Shotguns reload one shell at a time

	return self :: ShotgunInstance
end

--[[
	Override fire to cast multiple rays
]]
function Shotgun.Fire(self: ShotgunInstance, origin: Vector3, direction: Vector3): ShotgunFireResult
	if not WeaponBase.CanFire(self) then
		return {
			success = false,
			reason = self.state.isReloading and "Reloading" or self.state.currentAmmo <= 0 and "NoAmmo" or "FireRate",
		}
	end

	-- Calculate pellets
	local pelletCount = self.definition.pellets or 8
	local damagePerPellet = self.stats.damage / pelletCount
	local pellets = {} :: { PelletResult }

	for i = 1, pelletCount do
		local pelletSpread = Shotgun.CalculatePelletSpread(self, direction)
		table.insert(pellets, {
			direction = pelletSpread,
			damage = damagePerPellet,
		})
	end

	-- Update state
	self.state.currentAmmo = self.state.currentAmmo - 1
	self.state.lastFireTime = tick()

	return {
		success = true,
		origin = origin,
		direction = direction,
		spread = direction, -- Main direction
		damage = self.stats.damage, -- Total damage
		pellets = pellets,
	}
end

--[[
	Calculate spread for a single pellet
]]
function Shotgun.CalculatePelletSpread(self: ShotgunInstance, direction: Vector3): Vector3
	local spreadAmount = self.stats.spread

	-- Random spread within cone
	local angle = math.random() * math.pi * 2
	local distance = math.random() * spreadAmount

	local spreadX = math.cos(angle) * distance
	local spreadY = math.sin(angle) * distance

	local spreadCFrame = CFrame.new(Vector3.zero, direction) * CFrame.Angles(spreadY, spreadX, 0)

	return spreadCFrame.LookVector
end

--[[
	Override reload for shell-by-shell
]]
function Shotgun.Reload(self: ShotgunInstance): boolean
	if self.state.isReloading then
		return false
	end

	if self.state.currentAmmo >= self.definition.magSize then
		return false
	end

	if self.state.reserveAmmo <= 0 then
		return false
	end

	self.state.isReloading = true
	self._shellsToReload = self.definition.magSize - self.state.currentAmmo

	return true
end

--[[
	Load a single shell (called repeatedly during reload)
	@return Whether more shells need to be loaded
]]
function Shotgun.LoadShell(self: ShotgunInstance): boolean
	if not self.state.isReloading then
		return false
	end

	if self.state.reserveAmmo <= 0 or self._shellsToReload <= 0 then
		self.state.isReloading = false
		return false
	end

	self.state.currentAmmo = self.state.currentAmmo + 1
	self.state.reserveAmmo = self.state.reserveAmmo - 1
	self._shellsToReload = self._shellsToReload - 1

	-- Check if reload complete
	if self._shellsToReload <= 0 or self.state.currentAmmo >= self.definition.magSize then
		self.state.isReloading = false
		return false
	end

	return true -- More shells to load
end

--[[
	Get time per shell reload
	@return Time in seconds per shell
]]
function Shotgun.GetShellReloadTime(self: ShotgunInstance): number
	-- Total reload time divided by mag size
	return self.stats.reloadTime / self.definition.magSize
end

--[[
	Cancel reload and keep current shells
]]
function Shotgun.CancelReload(self: ShotgunInstance)
	self.state.isReloading = false
	self._shellsToReload = 0
end

--[[
	Check if weapon is automatic
	@return Always false for shotgun
]]
function Shotgun.IsAutomatic(self: ShotgunInstance): boolean
	return false
end

--[[
	Get recoil for shotgun (high kick)
	@return Vector2 recoil
]]
function Shotgun.GetRecoil(self: ShotgunInstance): Vector2
	local vertical = 2.0 + (math.random() * 0.5)
	local horizontal = (math.random() - 0.5) * 0.6
	return Vector2.new(horizontal, vertical)
end

return Shotgun
