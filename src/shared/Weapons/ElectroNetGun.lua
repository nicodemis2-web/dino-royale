--!strict
--[[
	ElectroNetGun.lua
	=================
	Epic special weapon - fires electrified nets
	Slows players and stuns dinosaurs
	Based on GDD Section 4.4: Special Weapons
]]

local WeaponBase = require(script.Parent.WeaponBase)

local ElectroNetGun = {}
ElectroNetGun.__index = ElectroNetGun
setmetatable(ElectroNetGun, { __index = WeaponBase })

ElectroNetGun.Stats = {
	name = "ElectroNetGun",
	displayName = "Electro Net Gun",
	description = "Fires an electrified net that slows players and stuns dinosaurs",
	category = "Special",
	rarity = "Epic",

	-- Damage
	baseDamage = 15,
	headshotMultiplier = 1.0, -- No headshot bonus

	-- Fire rate
	fireRate = 0.5, -- Slow fire rate
	fireMode = "Single",

	-- Magazine
	magazineSize = 3,
	reserveAmmo = 6,
	ammoType = "Special",

	-- Reload
	reloadTime = 4.0,

	-- Accuracy
	baseSpread = 0.05,
	adsSpread = 0.03,

	-- Range
	effectiveRange = 30,
	maxRange = 50,

	-- Special
	projectileSpeed = 80,
	isProjectile = true,

	-- Net effect
	netEffect = {
		playerSlowPercent = 0.5, -- 50% slow
		playerSlowDuration = 3.0,
		dinoStunDuration = 5.0,
		vehicleDisableDuration = 4.0,
		netRadius = 3, -- AOE on impact
	},

	-- Sounds
	sounds = {
		fire = "ElectroNetFire",
		reload = "ElectroNetReload",
		impact = "ElectroNetImpact",
		electric = "ElectricShock",
	},
}

--[[
	Create new Electro Net Gun
]]
function ElectroNetGun.new(config: any?): any
	local self = WeaponBase.new(ElectroNetGun.Stats, config)
	setmetatable(self, ElectroNetGun)

	return self
end

--[[
	Override fire to create net projectile
]]
function ElectroNetGun:Fire(origin: Vector3, direction: Vector3): any
	if not self:CanFire() then return nil end

	self:ConsumeAmmo(1)
	self.lastFireTime = tick()

	-- Create projectile data
	local projectile = {
		type = "ElectroNet",
		origin = origin,
		direction = direction,
		speed = ElectroNetGun.Stats.projectileSpeed,
		maxDistance = ElectroNetGun.Stats.maxRange,
		owner = self.owner,
		weaponStats = ElectroNetGun.Stats,
	}

	return projectile
end

--[[
	Handle net impact
]]
function ElectroNetGun.OnImpact(hitPosition: Vector3, hitTarget: any?, weaponStats: any): any
	local effects = {
		position = hitPosition,
		radius = weaponStats.netEffect.netRadius,
		affectedTargets = {},
	}

	-- Direct hit effects
	if hitTarget then
		if hitTarget.isPlayer then
			table.insert(effects.affectedTargets, {
				target = hitTarget,
				effectType = "PlayerSlow",
				slowPercent = weaponStats.netEffect.playerSlowPercent,
				duration = weaponStats.netEffect.playerSlowDuration,
				damage = weaponStats.baseDamage,
			})
		elseif hitTarget.isDinosaur then
			table.insert(effects.affectedTargets, {
				target = hitTarget,
				effectType = "DinoStun",
				duration = weaponStats.netEffect.dinoStunDuration,
				damage = weaponStats.baseDamage,
			})
		elseif hitTarget.isVehicle then
			table.insert(effects.affectedTargets, {
				target = hitTarget,
				effectType = "VehicleDisable",
				duration = weaponStats.netEffect.vehicleDisableDuration,
			})
		end
	end

	return effects
end

--[[
	Get weapon info for UI
]]
function ElectroNetGun:GetWeaponInfo(): any
	local baseInfo = WeaponBase.GetWeaponInfo(self)
	baseInfo.specialEffect = "Slows players 50% for 3s, stuns dinos for 5s"
	baseInfo.isUtility = true
	return baseInfo
end

return ElectroNetGun
