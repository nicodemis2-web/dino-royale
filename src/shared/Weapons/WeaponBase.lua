--!strict
--[[
	WeaponBase.lua
	==============
	Base class for all weapons in Dino Royale using OOP pattern.

	DESIGN PATTERN:
	Uses metatables to create weapon instances with shared methods.
	Each weapon instance contains:
	- Static data (definition, stats) from WeaponData
	- Dynamic state (ammo, reload status, bloom)
	- Methods for firing, reloading, damage calculation

	SPREAD SYSTEM:
	Weapon accuracy uses a bloom system that increases spread:
	1. Base spread: Defined per weapon in WeaponData
	2. Bloom: Increases with each shot, decays over time
	3. Modifiers: Movement, crouching, ADS affect final spread
	Final spread = baseSpread * (1 + bloom) * modifiers

	DAMAGE CALCULATION:
	Damage varies by:
	- Base damage from weapon stats
	- Rarity multiplier (Common 1.0x to Legendary 1.2x)
	- Headshot multiplier (2.0x for most weapons)
	- Distance falloff (optional, per weapon)

	SERIALIZATION:
	Weapons can be serialized for:
	- Network transmission (client-server sync)
	- Inventory storage
	- Save data persistence

	USAGE:
	```lua
	local weapon = WeaponBase.new("RangerAR", "Rare")
	if weapon:CanFire() then
		local result = weapon:Fire(origin, direction)
	end
	weapon:Reload()
	```

	@shared (used by both client and server)
]]

local Types = require(script.Parent.Parent.Types)
local Constants = require(script.Parent.Parent.Constants)
local WeaponData = require(script.Parent.Parent.Config.WeaponData)

--------------------------------------------------------------------------------
-- MODULE DECLARATION
--------------------------------------------------------------------------------

local WeaponBase = {}
WeaponBase.__index = WeaponBase

--------------------------------------------------------------------------------
-- EXPORTED TYPES
--------------------------------------------------------------------------------

--[[
	FireResult: Returned by Fire() method
	- success: Whether the weapon successfully fired
	- origin: World position the shot originated from
	- direction: Direction vector of the shot (with spread applied)
	- spread: The actual spread vector applied
	- damage: Base damage of this shot
	- reason: If failed, why (e.g., "No ammo", "Reloading")
]]
export type FireResult = {
	success: boolean,
	origin: Vector3?,
	direction: Vector3?,
	spread: Vector3?,
	damage: number?,
	reason: string?,
}

--[[
	SerializedWeapon: Minimal weapon data for network/storage
	Contains only the data needed to reconstruct weapon state
]]
export type SerializedWeapon = {
	id: string,
	rarity: Types.Rarity,
	currentAmmo: number,
	reserveAmmo: number,
}

--[[
	WeaponInstance: Full weapon object with methods
	This is the main type used throughout the codebase
]]
export type WeaponInstance = {
	-- Identity
	id: string,                              -- Weapon ID (e.g., "RangerAR")
	rarity: Types.Rarity,                    -- Rarity tier affects damage

	-- Configuration (read-only after creation)
	stats: Types.WeaponStats,                -- Calculated stats with rarity
	definition: WeaponData.WeaponDefinition, -- Base weapon definition
	owner: Player?,                          -- Owning player (server-side)

	-- Dynamic state
	state: Types.WeaponState,                -- Ammo, reload status, etc.

	-- Public methods
	CanFire: (self: WeaponInstance) -> boolean,
	Fire: (self: WeaponInstance, origin: Vector3, direction: Vector3) -> FireResult,
	Reload: (self: WeaponInstance) -> boolean,
	CancelReload: (self: WeaponInstance) -> (),
	GetDamage: (self: WeaponInstance, hitPart: string?) -> number,
	AddAmmo: (self: WeaponInstance, amount: number) -> number,
	Serialize: (self: WeaponInstance) -> SerializedWeapon,

	-- Internal state (prefix with _ to indicate private)
	_spreadBloom: number,        -- Current bloom accumulation (0 to MAX_BLOOM)
	_lastBloomDecayTime: number, -- Last time bloom was updated
}

--------------------------------------------------------------------------------
-- SPREAD & BLOOM CONFIGURATION
--------------------------------------------------------------------------------

--[[
	Spread modifiers applied based on player state.
	Multiplied together: moving while ADS = 1.5 * 0.6 = 0.9x spread
]]
local SPREAD_MODIFIERS = {
	Moving = 1.5,    -- +50% spread when moving (walking/running)
	Crouching = 0.75, -- -25% spread when crouching (more stable)
	Prone = 0.5,     -- -50% spread when prone (most stable)
	ADS = 0.6,       -- -40% spread when aiming down sights
}

--[[
	Bloom system: Accuracy decreases with rapid fire, recovers when not firing.
	This rewards controlled bursts over spraying.
]]
local BLOOM_PER_SHOT = 0.1   -- +10% spread added per shot fired
local BLOOM_DECAY_RATE = 0.5 -- Bloom decreases by 50% per second when not firing
local MAX_BLOOM = 1.0        -- Maximum bloom (caps at +100% spread)

--[[
	Create a new weapon instance
	@param weaponId The weapon ID (e.g., "RangerAR")
	@param rarity The weapon rarity
	@return New WeaponInstance
]]
function WeaponBase.new(weaponId: string, rarity: Types.Rarity): WeaponInstance
	local definition = WeaponData.GetWeapon(weaponId)
	if not definition then
		error(`Unknown weapon ID: {weaponId}`)
	end

	local stats = WeaponData.GetStatsWithRarity(weaponId, rarity)
	if not stats then
		error(`Failed to get stats for weapon: {weaponId}`)
	end

	local self = setmetatable({}, WeaponBase) :: any

	self.id = weaponId
	self.rarity = rarity
	self.stats = stats
	self.definition = definition
	self.owner = nil

	self.state = {
		currentAmmo = definition.magSize,
		reserveAmmo = definition.magSize * 3, -- Start with 3 extra mags
		isReloading = false,
		lastFireTime = 0,
	}

	self._spreadBloom = 0
	self._lastBloomDecayTime = tick()

	return self :: WeaponInstance
end

--[[
	Check if the weapon can fire
	@return Whether the weapon can fire
]]
function WeaponBase.CanFire(self: WeaponInstance): boolean
	-- Can't fire while reloading
	if self.state.isReloading then
		return false
	end

	-- Need ammo
	if self.state.currentAmmo <= 0 then
		return false
	end

	-- Check fire rate
	local currentTime = tick()
	local timeSinceLastFire = currentTime - self.state.lastFireTime
	local fireInterval = 1 / self.stats.fireRate

	if timeSinceLastFire < fireInterval then
		return false
	end

	return true
end

--[[
	Fire the weapon
	@param origin The fire origin position
	@param direction The fire direction
	@return FireResult
]]
function WeaponBase.Fire(self: WeaponInstance, origin: Vector3, direction: Vector3): FireResult
	if not self:CanFire() then
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

	-- Add bloom
	self._spreadBloom = math.min(MAX_BLOOM, self._spreadBloom + BLOOM_PER_SHOT)

	return {
		success = true,
		origin = origin,
		direction = direction,
		spread = spreadVector,
		damage = self.stats.damage,
	}
end

--[[
	Calculate spread for a shot
	@param direction Base direction
	@return Spread-adjusted direction
]]
function WeaponBase.CalculateSpread(self: WeaponInstance, direction: Vector3): Vector3
	-- Decay bloom since last shot
	local currentTime = tick()
	local timeSinceLastDecay = currentTime - self._lastBloomDecayTime
	self._spreadBloom = math.max(0, self._spreadBloom - (BLOOM_DECAY_RATE * timeSinceLastDecay))
	self._lastBloomDecayTime = currentTime

	-- Calculate total spread
	local baseSpread = self.stats.spread
	local bloomMultiplier = 1 + self._spreadBloom
	local totalSpread = baseSpread * bloomMultiplier

	-- Apply random spread
	local spreadX = (math.random() - 0.5) * 2 * totalSpread
	local spreadY = (math.random() - 0.5) * 2 * totalSpread

	-- Create spread rotation
	local spreadCFrame = CFrame.new(Vector3.zero, direction)
		* CFrame.Angles(spreadY, spreadX, 0)

	return spreadCFrame.LookVector
end

--[[
	Start reloading
	@return Whether reload started successfully
]]
function WeaponBase.Reload(self: WeaponInstance): boolean
	-- Already reloading
	if self.state.isReloading then
		return false
	end

	-- Magazine is full
	if self.state.currentAmmo >= self.definition.magSize then
		return false
	end

	-- No reserve ammo
	if self.state.reserveAmmo <= 0 then
		return false
	end

	self.state.isReloading = true

	-- Note: Actual reload completion is handled by server/client after timer
	return true
end

--[[
	Complete the reload (transfer ammo)
	Should be called after reload timer completes
]]
function WeaponBase.CompleteReload(self: WeaponInstance)
	if not self.state.isReloading then
		return
	end

	local ammoNeeded = self.definition.magSize - self.state.currentAmmo
	local ammoToTransfer = math.min(ammoNeeded, self.state.reserveAmmo)

	self.state.currentAmmo = self.state.currentAmmo + ammoToTransfer
	self.state.reserveAmmo = self.state.reserveAmmo - ammoToTransfer
	self.state.isReloading = false
end

--[[
	Cancel the current reload
]]
function WeaponBase.CancelReload(self: WeaponInstance)
	self.state.isReloading = false
end

--[[
	Get damage for a specific hit part
	@param hitPart The body part hit (optional)
	@return Calculated damage
]]
function WeaponBase.GetDamage(self: WeaponInstance, hitPart: string?): number
	local baseDamage = self.stats.damage

	if not hitPart then
		return baseDamage
	end

	local hitPartLower = string.lower(hitPart)
	local multiplier = Constants.COMBAT.BODY_MULTIPLIER

	if hitPartLower == "head" then
		multiplier = Constants.COMBAT.HEADSHOT_MULTIPLIER
	elseif
		string.find(hitPartLower, "arm")
		or string.find(hitPartLower, "leg")
		or string.find(hitPartLower, "hand")
		or string.find(hitPartLower, "foot")
	then
		multiplier = Constants.COMBAT.LIMB_MULTIPLIER
	end

	return baseDamage * multiplier
end

--[[
	Add ammo to reserve
	@param amount Amount of ammo to add
	@return Overflow amount (couldn't fit)
]]
function WeaponBase.AddAmmo(self: WeaponInstance, amount: number): number
	local maxReserve = self.definition.magSize * 10 -- Max 10 mags reserve
	local currentReserve = self.state.reserveAmmo
	local spaceAvailable = maxReserve - currentReserve

	local ammoToAdd = math.min(amount, spaceAvailable)
	self.state.reserveAmmo = currentReserve + ammoToAdd

	return amount - ammoToAdd -- Overflow
end

--[[
	Serialize the weapon for network transmission
	@return Serialized weapon data
]]
function WeaponBase.Serialize(self: WeaponInstance): SerializedWeapon
	return {
		id = self.id,
		rarity = self.rarity,
		currentAmmo = self.state.currentAmmo,
		reserveAmmo = self.state.reserveAmmo,
	}
end

--[[
	Deserialize a weapon from network data
	@param data Serialized weapon data
	@return Reconstructed WeaponInstance
]]
function WeaponBase.Deserialize(data: SerializedWeapon): WeaponInstance
	local weapon = WeaponBase.new(data.id, data.rarity)
	weapon.state.currentAmmo = data.currentAmmo
	weapon.state.reserveAmmo = data.reserveAmmo
	return weapon
end

--[[
	Get the ammo type for this weapon
	@return Ammo type string
]]
function WeaponBase.GetAmmoType(self: WeaponInstance): string
	return WeaponData.GetAmmoType(self.id) or "MediumAmmo"
end

--[[
	Apply spread modifier based on player state
	@param modifier The modifier key
	@return Modified spread value
]]
function WeaponBase.ApplySpreadModifier(self: WeaponInstance, modifier: string): number
	local mod = SPREAD_MODIFIERS[modifier] or 1.0
	return self.stats.spread * mod
end

--[[
	Check if weapon has scope
	@return Whether weapon has scope
]]
function WeaponBase.HasScope(self: WeaponInstance): boolean
	return self.definition.scopeZoom ~= nil and self.definition.scopeZoom > 0
end

--[[
	Get scope zoom level
	@return Scope zoom multiplier or 1 if no scope
]]
function WeaponBase.GetScopeZoom(self: WeaponInstance): number
	return self.definition.scopeZoom or 1
end

--[[
	Get pellet count (for shotguns)
	@return Number of pellets or 1 for non-shotguns
]]
function WeaponBase.GetPelletCount(self: WeaponInstance): number
	return self.definition.pellets or 1
end

--[[
	Clone the weapon instance
	@return New weapon with same state
]]
function WeaponBase.Clone(self: WeaponInstance): WeaponInstance
	local clone = WeaponBase.new(self.id, self.rarity)
	clone.state.currentAmmo = self.state.currentAmmo
	clone.state.reserveAmmo = self.state.reserveAmmo
	clone.owner = self.owner
	return clone
end

return WeaponBase
