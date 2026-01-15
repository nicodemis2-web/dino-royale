--!strict
--[[
	AmberLauncher.lua
	=================
	Legendary special weapon - fires explosive amber projectiles
	Creates sticky zones that slow enemies
	Based on GDD Section 4.4: Special Weapons
]]

local WeaponBase = require(script.Parent.WeaponBase)

local AmberLauncher = {}
AmberLauncher.__index = AmberLauncher
setmetatable(AmberLauncher, { __index = WeaponBase })

AmberLauncher.Stats = {
	name = "AmberLauncher",
	displayName = "Amber Launcher",
	description = "Fires explosive amber projectiles that create sticky zones",
	category = "Special",
	rarity = "Legendary",

	-- Damage
	baseDamage = 50, -- Direct hit damage
	splashDamage = 25, -- Splash damage
	headshotMultiplier = 1.0,

	-- Fire rate
	fireRate = 0.8, -- Slow fire rate
	fireMode = "Single",

	-- Magazine
	magazineSize = 4,
	reserveAmmo = 8,
	ammoType = "Special",

	-- Reload
	reloadTime = 3.5,

	-- Accuracy
	baseSpread = 0.03,
	adsSpread = 0.02,

	-- Range
	effectiveRange = 60,
	maxRange = 80,

	-- Projectile
	projectileSpeed = 60,
	isProjectile = true,
	projectileGravity = 15, -- Arcs slightly

	-- Amber zone effect
	amberEffect = {
		zoneRadius = 4, -- 4m radius sticky zone
		zoneDuration = 10, -- Lasts 10 seconds
		slowPercent = 0.7, -- 70% slow
		damagePerSecond = 5, -- Tick damage while in zone
	},

	-- Sounds
	sounds = {
		fire = "AmberLauncherFire",
		reload = "AmberLauncherReload",
		impact = "AmberSplash",
		zoneActive = "AmberBubble",
	},
}

--[[
	Create new Amber Launcher
	Note: Does not call WeaponBase.new() as it uses its own Stats table
]]
function AmberLauncher.new(config: any?): any
	local self = setmetatable({}, AmberLauncher)

	-- Initialize base weapon properties using our own Stats
	self.id = AmberLauncher.Stats.name
	self.rarity = (config and config.rarity) or AmberLauncher.Stats.rarity
	self.stats = AmberLauncher.Stats
	self.definition = AmberLauncher.Stats
	self.owner = config and config.owner or nil

	-- Initialize weapon state
	self.state = {
		currentAmmo = AmberLauncher.Stats.magazineSize,
		reserveAmmo = AmberLauncher.Stats.reserveAmmo,
		isReloading = false,
		lastFireTime = 0,
	}

	-- Track active amber zones
	self.activeZones = {} :: { AmberZone }

	return self
end

export type AmberZone = {
	position: Vector3,
	radius: number,
	startTime: number,
	endTime: number,
	owner: any?,
}

--[[
	Override fire to create amber projectile
]]
function AmberLauncher:Fire(origin: Vector3, direction: Vector3): any
	if not self:CanFire() then return nil end

	self:ConsumeAmmo(1)
	self.lastFireTime = tick()

	-- Create projectile with arc
	local projectile = {
		type = "AmberProjectile",
		origin = origin,
		direction = direction,
		speed = AmberLauncher.Stats.projectileSpeed,
		gravity = AmberLauncher.Stats.projectileGravity,
		maxDistance = AmberLauncher.Stats.maxRange,
		owner = self.owner,
		weaponStats = AmberLauncher.Stats,
	}

	return projectile
end

--[[
	Handle amber impact - creates sticky zone
]]
function AmberLauncher.OnImpact(hitPosition: Vector3, hitTarget: any?, weaponStats: any, owner: any?): any
	local effects = {
		position = hitPosition,
		directHit = hitTarget ~= nil,
		damage = 0,
		zone = nil,
	}

	-- Direct hit damage
	if hitTarget then
		effects.damage = weaponStats.baseDamage
		effects.directHitTarget = hitTarget
	end

	-- Splash damage to nearby targets would be calculated by server

	-- Create amber zone
	effects.zone = {
		position = hitPosition,
		radius = weaponStats.amberEffect.zoneRadius,
		duration = weaponStats.amberEffect.zoneDuration,
		slowPercent = weaponStats.amberEffect.slowPercent,
		damagePerSecond = weaponStats.amberEffect.damagePerSecond,
		startTime = tick(),
		owner = owner,
	}

	return effects
end

--[[
	Check if position is in any active amber zone
]]
function AmberLauncher:IsInAmberZone(position: Vector3): (boolean, AmberZone?)
	local now = tick()

	for i = #self.activeZones, 1, -1 do
		local zone = self.activeZones[i]

		-- Remove expired zones
		if now > zone.endTime then
			table.remove(self.activeZones, i)
			continue
		end

		-- Check if position is in zone
		local distance = (position - zone.position).Magnitude
		if distance <= zone.radius then
			return true, zone
		end
	end

	return false, nil
end

--[[
	Add active zone (called when projectile impacts)
]]
function AmberLauncher:AddZone(zoneData: any)
	local zone: AmberZone = {
		position = zoneData.position,
		radius = zoneData.radius,
		startTime = zoneData.startTime or tick(),
		endTime = (zoneData.startTime or tick()) + zoneData.duration,
		owner = zoneData.owner,
	}

	table.insert(self.activeZones, zone)
end

--[[
	Get all active zones
]]
function AmberLauncher:GetActiveZones(): { AmberZone }
	local now = tick()
	local validZones = {}

	for _, zone in ipairs(self.activeZones) do
		if now <= zone.endTime then
			table.insert(validZones, zone)
		end
	end

	return validZones
end

--[[
	Calculate projectile trajectory (for prediction)
]]
function AmberLauncher:CalculateTrajectory(origin: Vector3, direction: Vector3, time: number): Vector3
	local horizontalVelocity = Vector3.new(direction.X, 0, direction.Z).Unit * AmberLauncher.Stats.projectileSpeed
	local verticalVelocity = direction.Y * AmberLauncher.Stats.projectileSpeed

	local x = origin.X + horizontalVelocity.X * time
	local z = origin.Z + horizontalVelocity.Z * time
	local y = origin.Y + verticalVelocity * time - 0.5 * AmberLauncher.Stats.projectileGravity * time * time

	return Vector3.new(x, y, z)
end

--[[
	Get weapon info for UI
]]
function AmberLauncher:GetWeaponInfo(): any
	local baseInfo = WeaponBase.GetWeaponInfo(self)
	baseInfo.specialEffect = "Creates 4m sticky zone (70% slow) for 10s"
	baseInfo.activeZones = #self:GetActiveZones()
	baseInfo.hasArc = true
	return baseInfo
end

return AmberLauncher
