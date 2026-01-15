--!strict
--[[
	DinoCall.lua
	============
	Rare utility item - attracts dinosaurs to target location
	Based on GDD Section 4.4: Special Weapons
]]

local WeaponBase = require(script.Parent.WeaponBase)

local DinoCall = {}
DinoCall.__index = DinoCall
setmetatable(DinoCall, { __index = WeaponBase })

DinoCall.Stats = {
	name = "DinoCall",
	displayName = "Dino Call",
	description = "Emits sounds that attract nearby dinosaurs to a targeted location",
	category = "Special",
	rarity = "Rare",

	-- Not a damage weapon
	baseDamage = 0,
	headshotMultiplier = 1.0,

	-- Uses
	magazineSize = 5, -- 5 uses per item
	reserveAmmo = 0,
	ammoType = "None", -- Doesn't use ammo

	-- Cooldown
	fireRate = 0.067, -- 15 second cooldown
	reloadTime = 0, -- No reload

	-- Range
	effectiveRange = 100, -- Can target 100m away
	maxRange = 100,

	-- Accuracy
	baseSpread = 0,
	adsSpread = 0,

	-- Call effects
	callEffect = {
		attractRadius = 80, -- Attracts dinos within 80m of target
		attractDuration = 20, -- Dinos move to location for 20s
		dinoTypesAttracted = { "All" }, -- Attracts all types
	},

	-- Variants (different call types)
	variants = {
		Carnivore = {
			name = "Carnivore Call",
			dinoTypesAttracted = { "Velociraptor", "Dilophosaurus", "Carnotaurus", "Baryonyx" },
			soundId = "CarnivoreCall",
		},
		Herbivore = {
			name = "Herbivore Call",
			dinoTypesAttracted = { "Triceratops", "Gallimimus" },
			soundId = "HerbivoreCall",
		},
		Apex = {
			name = "Apex Call",
			dinoTypesAttracted = { "TRex", "Spinosaurus" },
			soundId = "ApexCall",
			rarity = "Epic", -- Rarer variant
		},
		Flying = {
			name = "Flying Call",
			dinoTypesAttracted = { "Pteranodon", "Dimorphodon" },
			soundId = "FlyingCall",
		},
	},

	-- Sounds
	sounds = {
		use = "DinoCallUse",
		attract = "DinoCallAttract",
	},
}

-- Current variant
export type DinoCallState = {
	variant: string,
	usesRemaining: number,
	lastUseTime: number,
	activeCall: ActiveCall?,
}

export type ActiveCall = {
	targetPosition: Vector3,
	startTime: number,
	duration: number,
	attractedDinos: { any },
}

--[[
	Create new Dino Call
	Note: Does not call WeaponBase.new() as it uses its own Stats table
]]
function DinoCall.new(variant: string?, config: any?): any
	local self = setmetatable({}, DinoCall)

	-- Initialize base weapon properties using our own Stats
	self.id = DinoCall.Stats.name
	self.rarity = (config and config.rarity) or DinoCall.Stats.rarity
	self.stats = DinoCall.Stats
	self.definition = DinoCall.Stats
	self.owner = config and config.owner or nil

	-- Initialize weapon state (DinoCall uses charges instead of ammo)
	self.state = {
		currentAmmo = DinoCall.Stats.magazineSize,
		reserveAmmo = DinoCall.Stats.reserveAmmo,
		isReloading = false,
		lastFireTime = 0,
	}

	self.callState = {
		variant = variant or "Carnivore",
		usesRemaining = DinoCall.Stats.magazineSize,
		lastUseTime = 0,
		activeCall = nil,
	} :: DinoCallState

	return self
end

--[[
	Check if can use
]]
function DinoCall:CanUse(): boolean
	if self.callState.usesRemaining <= 0 then return false end
	if tick() - self.callState.lastUseTime < 15 then return false end -- 15s cooldown

	return true
end

--[[
	Use the call at target position
]]
function DinoCall:Use(targetPosition: Vector3): any
	if not self:CanUse() then return nil end

	self.callState.usesRemaining = self.callState.usesRemaining - 1
	self.callState.lastUseTime = tick()

	local variantData = DinoCall.Stats.variants[self.callState.variant]
	local attractDuration = DinoCall.Stats.callEffect.attractDuration

	self.callState.activeCall = {
		targetPosition = targetPosition,
		startTime = tick(),
		duration = attractDuration,
		attractedDinos = {},
	}

	-- Return call data for server to process
	return {
		type = "DinoCall",
		variant = self.callState.variant,
		targetPosition = targetPosition,
		attractRadius = DinoCall.Stats.callEffect.attractRadius,
		duration = attractDuration,
		dinoTypes = variantData and variantData.dinoTypesAttracted or { "All" },
		soundId = variantData and variantData.soundId or "DinoCallUse",
	}
end

--[[
	Get attracted dino types for current variant
]]
function DinoCall:GetAttractedTypes(): { string }
	local variantData = DinoCall.Stats.variants[self.callState.variant]
	if variantData then
		return variantData.dinoTypesAttracted
	end
	return { "All" }
end

--[[
	Get cooldown remaining
]]
function DinoCall:GetCooldownRemaining(): number
	local elapsed = tick() - self.callState.lastUseTime
	return math.max(0, 15 - elapsed)
end

--[[
	Override fire to use the call
]]
function DinoCall:Fire(origin: Vector3, direction: Vector3): any
	-- Calculate target position based on direction and max range
	local targetPosition = origin + direction * DinoCall.Stats.effectiveRange

	return self:Use(targetPosition)
end

--[[
	Get current ammo (uses remaining)
]]
function DinoCall:GetCurrentAmmo(): number
	return self.callState.usesRemaining
end

--[[
	Get weapon info for UI
]]
function DinoCall:GetWeaponInfo(): any
	local variantData = DinoCall.Stats.variants[self.callState.variant]
	local displayName = variantData and variantData.name or DinoCall.Stats.displayName

	return {
		name = DinoCall.Stats.name,
		displayName = displayName,
		description = DinoCall.Stats.description,
		rarity = variantData and variantData.rarity or DinoCall.Stats.rarity,
		category = DinoCall.Stats.category,
		currentAmmo = self.callState.usesRemaining,
		maxAmmo = DinoCall.Stats.magazineSize,
		cooldownRemaining = self:GetCooldownRemaining(),
		specialEffect = "Attracts " .. table.concat(self:GetAttractedTypes(), ", ") .. " to target",
		isUtility = true,
		variant = self.callState.variant,
	}
end

return DinoCall
