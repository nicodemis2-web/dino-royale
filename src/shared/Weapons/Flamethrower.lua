--!strict
--[[
	Flamethrower.lua
	================
	Legendary special weapon - continuous fire stream
	High damage over time, creates fire patches
	Based on GDD Section 4.4: Special Weapons
]]

local WeaponBase = require(script.Parent.WeaponBase)

local Flamethrower = {}
Flamethrower.__index = Flamethrower
setmetatable(Flamethrower, { __index = WeaponBase })

Flamethrower.Stats = {
	name = "Flamethrower",
	displayName = "Flamethrower",
	description = "Short-range continuous fire weapon that deals burn damage over time",
	category = "Special",
	rarity = "Legendary",

	-- Damage
	baseDamage = 12, -- Per tick
	burnDamage = 5, -- DOT per second
	burnDuration = 4, -- Seconds
	headshotMultiplier = 1.0, -- No headshots

	-- Fire rate (continuous)
	fireRate = 10, -- Ticks per second
	fireMode = "Automatic",

	-- Fuel (instead of ammo)
	magazineSize = 100, -- Fuel units
	reserveAmmo = 100,
	ammoType = "Fuel",
	fuelDrainRate = 10, -- Units per second when firing

	-- Reload (refuel)
	reloadTime = 5.0,

	-- Range (short)
	effectiveRange = 15,
	maxRange = 20,

	-- Spread (cone of fire)
	baseSpread = 0.15,
	adsSpread = 0.12,
	coneAngle = 25, -- Degrees

	-- Fire patch effect
	firePatch = {
		radius = 3,
		duration = 5,
		damagePerSecond = 8,
		createChance = 0.3, -- 30% chance per second of firing
	},

	-- Dinosaur effectiveness
	dinoMultiplier = 1.5, -- 50% more damage to dinos

	-- Sounds
	sounds = {
		fireStart = "FlamethrowerStart",
		fireLoop = "FlamethrowerLoop",
		fireEnd = "FlamethrowerEnd",
		reload = "FlamethrowerRefuel",
		burn = "BurningSound",
	},
}

-- Flamethrower state
export type FlamethrowerState = {
	isFiring: boolean,
	fireStartTime: number,
	currentFuel: number,
	burningTargets: { [any]: BurnEffect },
	activeFirePatches: { FirePatch },
}

export type BurnEffect = {
	target: any,
	startTime: number,
	endTime: number,
	damagePerTick: number,
	tickInterval: number,
	lastTickTime: number,
}

export type FirePatch = {
	position: Vector3,
	radius: number,
	startTime: number,
	endTime: number,
	damagePerSecond: number,
}

--[[
	Create new Flamethrower
]]
function Flamethrower.new(config: any?): any
	local self = WeaponBase.new(Flamethrower.Stats, config)
	setmetatable(self, Flamethrower)

	self.flameState = {
		isFiring = false,
		fireStartTime = 0,
		currentFuel = Flamethrower.Stats.magazineSize,
		burningTargets = {},
		activeFirePatches = {},
	} :: FlamethrowerState

	return self
end

--[[
	Start firing
]]
function Flamethrower:StartFiring()
	if self.flameState.currentFuel <= 0 then return false end

	self.flameState.isFiring = true
	self.flameState.fireStartTime = tick()

	return true
end

--[[
	Stop firing
]]
function Flamethrower:StopFiring()
	self.flameState.isFiring = false
end

--[[
	Override fire for continuous stream
]]
function Flamethrower:Fire(origin: Vector3, direction: Vector3): any
	if self.flameState.currentFuel <= 0 then
		self:StopFiring()
		return nil
	end

	if not self.flameState.isFiring then
		self:StartFiring()
	end

	-- Drain fuel
	local drainAmount = Flamethrower.Stats.fuelDrainRate / Flamethrower.Stats.fireRate
	self.flameState.currentFuel = math.max(0, self.flameState.currentFuel - drainAmount)

	-- Create flame stream data
	local flameData = {
		type = "FlameStream",
		origin = origin,
		direction = direction,
		range = Flamethrower.Stats.effectiveRange,
		coneAngle = Flamethrower.Stats.coneAngle,
		damage = Flamethrower.Stats.baseDamage,
		burnDamage = Flamethrower.Stats.burnDamage,
		burnDuration = Flamethrower.Stats.burnDuration,
		owner = self.owner,
	}

	-- Chance to create fire patch
	if math.random() < Flamethrower.Stats.firePatch.createChance / Flamethrower.Stats.fireRate then
		local patchDistance = math.random(5, Flamethrower.Stats.effectiveRange)
		local patchPosition = origin + direction * patchDistance

		self:CreateFirePatch(patchPosition)
	end

	return flameData
end

--[[
	Create fire patch on ground
]]
function Flamethrower:CreateFirePatch(position: Vector3)
	local patch: FirePatch = {
		position = position,
		radius = Flamethrower.Stats.firePatch.radius,
		startTime = tick(),
		endTime = tick() + Flamethrower.Stats.firePatch.duration,
		damagePerSecond = Flamethrower.Stats.firePatch.damagePerSecond,
	}

	table.insert(self.flameState.activeFirePatches, patch)
end

--[[
	Apply burn effect to target
]]
function Flamethrower:ApplyBurn(target: any)
	local burnEffect: BurnEffect = {
		target = target,
		startTime = tick(),
		endTime = tick() + Flamethrower.Stats.burnDuration,
		damagePerTick = Flamethrower.Stats.burnDamage,
		tickInterval = 1,
		lastTickTime = tick(),
	}

	self.flameState.burningTargets[target] = burnEffect
end

--[[
	Update burn effects
]]
function Flamethrower:UpdateBurns(): { { target: any, damage: number } }
	local now = tick()
	local damageEvents = {}

	for target, burn in pairs(self.flameState.burningTargets) do
		-- Remove expired burns
		if now > burn.endTime then
			self.flameState.burningTargets[target] = nil
			continue
		end

		-- Apply tick damage
		if now - burn.lastTickTime >= burn.tickInterval then
			burn.lastTickTime = now
			table.insert(damageEvents, {
				target = target,
				damage = burn.damagePerTick,
			})
		end
	end

	return damageEvents
end

--[[
	Update fire patches
]]
function Flamethrower:UpdateFirePatches(): { FirePatch }
	local now = tick()
	local activePatches = {}

	for i = #self.flameState.activeFirePatches, 1, -1 do
		local patch = self.flameState.activeFirePatches[i]

		if now > patch.endTime then
			table.remove(self.flameState.activeFirePatches, i)
		else
			table.insert(activePatches, patch)
		end
	end

	return activePatches
end

--[[
	Check if position is in fire patch
]]
function Flamethrower:IsInFirePatch(position: Vector3): (boolean, FirePatch?)
	for _, patch in ipairs(self.flameState.activeFirePatches) do
		local distance = (position - patch.position).Magnitude
		if distance <= patch.radius then
			return true, patch
		end
	end

	return false, nil
end

--[[
	Handle hit on target
]]
function Flamethrower.OnHit(hitTarget: any?, weaponStats: any): any
	if not hitTarget then return nil end

	local effects = {
		target = hitTarget,
		damage = weaponStats.baseDamage,
		applyBurn = true,
		burnDamage = weaponStats.burnDamage,
		burnDuration = weaponStats.burnDuration,
	}

	-- Bonus damage to dinosaurs
	if hitTarget.isDinosaur then
		effects.damage = effects.damage * weaponStats.dinoMultiplier
		effects.burnDamage = effects.burnDamage * weaponStats.dinoMultiplier
	end

	return effects
end

--[[
	Override reload (refuel)
]]
function Flamethrower:Reload()
	if self.flameState.isFiring then
		self:StopFiring()
	end

	WeaponBase.Reload(self)
end

--[[
	Override reload complete
]]
function Flamethrower:OnReloadComplete()
	self.flameState.currentFuel = Flamethrower.Stats.magazineSize
	WeaponBase.OnReloadComplete(self)
end

--[[
	Get current ammo (fuel)
]]
function Flamethrower:GetCurrentAmmo(): number
	return math.floor(self.flameState.currentFuel)
end

--[[
	Override can fire
]]
function Flamethrower:CanFire(): boolean
	return self.flameState.currentFuel > 0 and not self.isReloading
end

--[[
	Get weapon info for UI
]]
function Flamethrower:GetWeaponInfo(): any
	local baseInfo = WeaponBase.GetWeaponInfo(self)
	baseInfo.currentAmmo = self:GetCurrentAmmo()
	baseInfo.isFiring = self.flameState.isFiring
	baseInfo.activeBurns = 0
	for _ in pairs(self.flameState.burningTargets) do
		baseInfo.activeBurns = baseInfo.activeBurns + 1
	end
	baseInfo.activePatches = #self.flameState.activeFirePatches
	baseInfo.specialEffect = "Burns targets, creates fire patches. +50% vs dinos."
	baseInfo.fuelBased = true
	return baseInfo
end

return Flamethrower
