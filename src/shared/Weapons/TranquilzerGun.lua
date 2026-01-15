--!strict
--[[
	TranquilizerGun.lua
	===================
	Epic special weapon - fires tranquilizer darts
	Puts small dinos to sleep, slows players
	Based on GDD Section 4.4: Special Weapons
]]

local WeaponBase = require(script.Parent.WeaponBase)

local TranquilizerGun = {}
TranquilizerGun.__index = TranquilizerGun
setmetatable(TranquilizerGun, { __index = WeaponBase })

TranquilizerGun.Stats = {
	name = "TranquilizerGun",
	displayName = "Tranquilizer Dart Gun",
	description = "Fires tranquilizer darts that put small dinosaurs to sleep and slow players",
	category = "Special",
	rarity = "Epic",

	-- Damage (low damage, high utility)
	baseDamage = 15,
	headshotMultiplier = 1.5,

	-- Fire rate
	fireRate = 0.8,
	fireMode = "Single",

	-- Magazine
	magazineSize = 6,
	reserveAmmo = 18,
	ammoType = "Special",

	-- Reload
	reloadTime = 3.0,

	-- Accuracy (very accurate)
	baseSpread = 0.01,
	adsSpread = 0.005,
	adsZoom = 2.0,

	-- Range
	effectiveRange = 80,
	maxRange = 120,

	-- Projectile
	projectileSpeed = 150,
	isProjectile = true,

	-- Tranq effects
	tranqEffect = {
		-- Player effects
		playerSlowPercent = 0.6, -- 40% speed
		playerSlowDuration = 5.0,
		playerBlurDuration = 3.0, -- Vision blur

		-- Dinosaur effects by tier
		dinoEffects = {
			Common = { sleepDuration = 30, canSleep = true },
			Uncommon = { sleepDuration = 20, canSleep = true },
			Rare = { sleepDuration = 10, canSleep = true },
			Epic = { sleepDuration = 0, canSleep = false, slowDuration = 8, slowPercent = 0.5 },
			Legendary = { sleepDuration = 0, canSleep = false, slowDuration = 3, slowPercent = 0.7 },
		},

		-- Stack mechanic (multiple hits increase effect)
		stackable = true,
		maxStacks = 3,
		stackDurationBonus = 1.5, -- Each stack adds 50% duration
	},

	-- Sounds
	sounds = {
		fire = "TranqFire",
		reload = "TranqReload",
		impact = "TranqHit",
		sleep = "DinoSleep",
	},
}

-- Tranq stacks on targets
export type TranqStack = {
	target: any,
	stacks: number,
	lastHitTime: number,
	effectEndTime: number,
}

--[[
	Create new Tranquilizer Gun
	Note: Does not call WeaponBase.new() as it uses its own Stats table
]]
function TranquilizerGun.new(config: any?): any
	local self = setmetatable({}, TranquilizerGun)

	-- Initialize base weapon properties using our own Stats
	self.id = TranquilizerGun.Stats.name
	self.rarity = (config and config.rarity) or TranquilizerGun.Stats.rarity
	self.stats = TranquilizerGun.Stats
	self.definition = TranquilizerGun.Stats
	self.owner = config and config.owner or nil

	-- Initialize weapon state
	self.state = {
		currentAmmo = TranquilizerGun.Stats.magazineSize,
		reserveAmmo = TranquilizerGun.Stats.reserveAmmo,
		isReloading = false,
		lastFireTime = 0,
	}

	-- Track tranq stacks
	self.tranqStacks = {} :: { [any]: TranqStack }

	return self
end

--[[
	Override fire
]]
function TranquilizerGun:Fire(origin: Vector3, direction: Vector3): any
	if not self:CanFire() then return nil end

	self:ConsumeAmmo(1)
	self.lastFireTime = tick()

	local projectile = {
		type = "TranqDart",
		origin = origin,
		direction = direction,
		speed = TranquilizerGun.Stats.projectileSpeed,
		maxDistance = TranquilizerGun.Stats.maxRange,
		owner = self.owner,
		weaponStats = TranquilizerGun.Stats,
	}

	return projectile
end

--[[
	Handle dart impact
]]
function TranquilizerGun.OnImpact(hitTarget: any?, weaponStats: any, tranqStacks: { [any]: TranqStack }?): any
	if not hitTarget then return nil end

	local effects = {
		target = hitTarget,
		damage = weaponStats.baseDamage,
		effectType = "None",
		effectData = {},
	}

	-- Calculate stacks
	local currentStacks = 1
	if tranqStacks and tranqStacks[hitTarget] then
		local stackData = tranqStacks[hitTarget]
		-- Check if previous stacks still active
		if tick() < stackData.effectEndTime then
			currentStacks = math.min(weaponStats.tranqEffect.maxStacks, stackData.stacks + 1)
		end
	end

	local stackMultiplier = 1 + (currentStacks - 1) * (weaponStats.tranqEffect.stackDurationBonus - 1)

	if hitTarget.isPlayer then
		-- Player effect
		effects.effectType = "PlayerDrowsy"
		effects.effectData = {
			slowPercent = weaponStats.tranqEffect.playerSlowPercent,
			slowDuration = weaponStats.tranqEffect.playerSlowDuration * stackMultiplier,
			blurDuration = weaponStats.tranqEffect.playerBlurDuration * stackMultiplier,
			stacks = currentStacks,
		}

	elseif hitTarget.isDinosaur then
		-- Get dino tier
		local tier = hitTarget.tier or "Common"
		local dinoEffect = weaponStats.tranqEffect.dinoEffects[tier]

		if dinoEffect then
			if dinoEffect.canSleep then
				effects.effectType = "DinoSleep"
				effects.effectData = {
					sleepDuration = dinoEffect.sleepDuration * stackMultiplier,
					stacks = currentStacks,
				}
			else
				effects.effectType = "DinoSlow"
				effects.effectData = {
					slowPercent = dinoEffect.slowPercent,
					slowDuration = dinoEffect.slowDuration * stackMultiplier,
					stacks = currentStacks,
				}
			end
		end
	end

	-- Update stack tracking
	effects.newStackData = {
		target = hitTarget,
		stacks = currentStacks,
		lastHitTime = tick(),
		effectEndTime = tick() + (effects.effectData.slowDuration or effects.effectData.sleepDuration or 5),
	}

	return effects
end

--[[
	Update stack tracking
]]
function TranquilizerGun:UpdateStacks(target: any, stackData: TranqStack)
	self.tranqStacks[target] = stackData
end

--[[
	Clear expired stacks
]]
function TranquilizerGun:CleanupStacks()
	local now = tick()
	for target, stackData in pairs(self.tranqStacks) do
		if now > stackData.effectEndTime then
			self.tranqStacks[target] = nil
		end
	end
end

--[[
	Get stacks on target
]]
function TranquilizerGun:GetStacksOnTarget(target: any): number
	local stackData = self.tranqStacks[target]
	if stackData and tick() < stackData.effectEndTime then
		return stackData.stacks
	end
	return 0
end

--[[
	Get weapon info for UI
]]
function TranquilizerGun:GetWeaponInfo(): any
	local baseInfo = WeaponBase.GetWeaponInfo(self)
	baseInfo.specialEffect = "Sleeps small dinos, slows players. Stacks up to 3x."
	baseInfo.hasScope = true
	baseInfo.scopeZoom = TranquilizerGun.Stats.adsZoom
	return baseInfo
end

return TranquilizerGun
