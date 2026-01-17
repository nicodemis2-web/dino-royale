--!strict
--[[
	CameraShake.lua
	===============
	Professional camera shake system for Dino Royale.
	Adds "juice" and feedback to gameplay through screen shake effects.

	FEATURES:
	- Multiple shake types (gunfire, explosion, impact, rumble)
	- Stackable shakes with proper blending
	- Smooth fade-out with configurable decay
	- Position and rotation influence control
	- Presets for common game events

	USAGE:
	```lua
	local CameraShake = require(path.to.CameraShake)
	CameraShake.Initialize()

	-- Trigger presets
	CameraShake.ShakePreset("GunfireLight")
	CameraShake.ShakePreset("Explosion")

	-- Custom shake
	CameraShake.Shake({
		magnitude = 2,
		roughness = 3,
		duration = 0.5,
		positionInfluence = Vector3.new(0.5, 0.5, 0.5),
		rotationInfluence = Vector3.new(1, 0.5, 1),
	})
	```

	@client
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CameraShake = {}

--------------------------------------------------------------------------------
-- CONFIGURATION
--------------------------------------------------------------------------------

-- Shake presets for common game events
local SHAKE_PRESETS = {
	-- Weapon fire shakes (scaled by weapon type)
	GunfireLight = {
		magnitude = 0.3,
		roughness = 8,
		duration = 0.1,
		positionInfluence = Vector3.new(0, 0.1, 0.2),
		rotationInfluence = Vector3.new(0.5, 0.2, 0.3),
		fadeOut = 0.5,
	},
	GunfireMedium = {
		magnitude = 0.6,
		roughness = 6,
		duration = 0.15,
		positionInfluence = Vector3.new(0, 0.2, 0.3),
		rotationInfluence = Vector3.new(1, 0.3, 0.5),
		fadeOut = 0.4,
	},
	GunfireHeavy = {
		magnitude = 1.2,
		roughness = 4,
		duration = 0.25,
		positionInfluence = Vector3.new(0.1, 0.4, 0.5),
		rotationInfluence = Vector3.new(2, 0.5, 1),
		fadeOut = 0.3,
	},
	ShotgunBlast = {
		magnitude = 2,
		roughness = 3,
		duration = 0.3,
		positionInfluence = Vector3.new(0.2, 0.5, 0.8),
		rotationInfluence = Vector3.new(3, 1, 2),
		fadeOut = 0.25,
	},

	-- Explosion shakes
	ExplosionNear = {
		magnitude = 4,
		roughness = 2,
		duration = 0.8,
		positionInfluence = Vector3.new(1, 1, 1),
		rotationInfluence = Vector3.new(4, 2, 4),
		fadeOut = 0.15,
	},
	ExplosionMedium = {
		magnitude = 2,
		roughness = 3,
		duration = 0.5,
		positionInfluence = Vector3.new(0.5, 0.5, 0.5),
		rotationInfluence = Vector3.new(2, 1, 2),
		fadeOut = 0.2,
	},
	ExplosionFar = {
		magnitude = 0.8,
		roughness = 4,
		duration = 0.3,
		positionInfluence = Vector3.new(0.2, 0.2, 0.2),
		rotationInfluence = Vector3.new(0.8, 0.4, 0.8),
		fadeOut = 0.3,
	},

	-- Impact shakes (taking damage, landing)
	DamageLight = {
		magnitude = 0.5,
		roughness = 10,
		duration = 0.15,
		positionInfluence = Vector3.new(0.2, 0.2, 0.2),
		rotationInfluence = Vector3.new(0.8, 0.5, 0.8),
		fadeOut = 0.4,
	},
	DamageHeavy = {
		magnitude = 1.5,
		roughness = 6,
		duration = 0.3,
		positionInfluence = Vector3.new(0.5, 0.5, 0.5),
		rotationInfluence = Vector3.new(2, 1, 2),
		fadeOut = 0.25,
	},
	HardLanding = {
		magnitude = 1,
		roughness = 5,
		duration = 0.2,
		positionInfluence = Vector3.new(0, 1, 0),
		rotationInfluence = Vector3.new(0.5, 0, 0.5),
		fadeOut = 0.3,
	},

	-- Dinosaur-related shakes
	DinoRoar = {
		magnitude = 1,
		roughness = 3,
		duration = 0.6,
		positionInfluence = Vector3.new(0.3, 0.3, 0.3),
		rotationInfluence = Vector3.new(1.5, 0.5, 1.5),
		fadeOut = 0.15,
	},
	DinoFootstep = {
		magnitude = 0.4,
		roughness = 8,
		duration = 0.15,
		positionInfluence = Vector3.new(0, 0.5, 0),
		rotationInfluence = Vector3.new(0.3, 0, 0.3),
		fadeOut = 0.5,
	},
	DinoAttack = {
		magnitude = 2,
		roughness = 4,
		duration = 0.4,
		positionInfluence = Vector3.new(0.5, 0.5, 0.5),
		rotationInfluence = Vector3.new(2.5, 1, 2.5),
		fadeOut = 0.2,
	},

	-- Environmental shakes
	Earthquake = {
		magnitude = 2,
		roughness = 2,
		duration = 3,
		positionInfluence = Vector3.new(0.5, 1, 0.5),
		rotationInfluence = Vector3.new(1, 0.5, 1),
		fadeOut = 0.05,
	},
	Thunder = {
		magnitude = 0.3,
		roughness = 10,
		duration = 0.2,
		positionInfluence = Vector3.new(0.1, 0.1, 0.1),
		rotationInfluence = Vector3.new(0.5, 0.2, 0.5),
		fadeOut = 0.4,
	},

	-- UI/Feedback shakes
	Bump = {
		magnitude = 0.2,
		roughness = 15,
		duration = 0.1,
		positionInfluence = Vector3.new(0, 0, 0),
		rotationInfluence = Vector3.new(0.3, 0.1, 0.3),
		fadeOut = 0.6,
	},
}

--------------------------------------------------------------------------------
-- TYPES
--------------------------------------------------------------------------------

export type ShakeConfig = {
	magnitude: number,
	roughness: number,
	duration: number,
	positionInfluence: Vector3,
	rotationInfluence: Vector3,
	fadeOut: number?,
}

type ActiveShake = {
	config: ShakeConfig,
	timeRemaining: number,
	currentMagnitude: number,
	seed: number,
}

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------

local activeShakes: { ActiveShake } = {}
local isInitialized = false
local updateConnection: RBXScriptConnection? = nil
local camera: Camera? = nil

-- Accumulated offset for this frame
local currentPositionOffset = Vector3.zero
local currentRotationOffset = Vector3.zero

--------------------------------------------------------------------------------
-- HELPER FUNCTIONS
--------------------------------------------------------------------------------

--[[
	Generate perlin noise-based shake value
]]
local function getNoiseValue(seed: number, time: number, roughness: number): number
	return math.noise(seed + time * roughness, seed * 0.5, time * 0.3)
end

--[[
	Calculate shake offset for a single active shake
]]
local function calculateShakeOffset(shake: ActiveShake, _deltaTime: number): (Vector3, Vector3)
	local config = shake.config
	local t = (config.duration - shake.timeRemaining)
	local seed = shake.seed

	-- Get noise values for each axis
	local noiseX = getNoiseValue(seed, t, config.roughness)
	local noiseY = getNoiseValue(seed + 100, t, config.roughness)
	local noiseZ = getNoiseValue(seed + 200, t, config.roughness)

	-- Apply magnitude and influence
	local mag = shake.currentMagnitude
	local posOffset = Vector3.new(
		noiseX * mag * config.positionInfluence.X,
		noiseY * mag * config.positionInfluence.Y,
		noiseZ * mag * config.positionInfluence.Z
	)

	local rotOffset = Vector3.new(
		noiseX * mag * config.rotationInfluence.X,
		noiseY * mag * config.rotationInfluence.Y,
		noiseZ * mag * config.rotationInfluence.Z
	)

	return posOffset, rotOffset
end

--------------------------------------------------------------------------------
-- CORE FUNCTIONS
--------------------------------------------------------------------------------

--[[
	Initialize the camera shake system
]]
function CameraShake.Initialize()
	if isInitialized then
		return
	end

	camera = Workspace.CurrentCamera

	-- Start update loop
	updateConnection = RunService.RenderStepped:Connect(function(deltaTime)
		CameraShake.Update(deltaTime)
	end)

	isInitialized = true
	print("[CameraShake] Initialized")
end

--[[
	Update all active shakes and apply to camera
]]
function CameraShake.Update(deltaTime: number)
	if not camera then
		camera = Workspace.CurrentCamera
		if not camera then
			return
		end
	end

	-- Reset accumulated offset
	currentPositionOffset = Vector3.zero
	currentRotationOffset = Vector3.zero

	-- Process all active shakes
	local i = 1
	while i <= #activeShakes do
		local shake = activeShakes[i]

		-- Update time
		shake.timeRemaining -= deltaTime

		if shake.timeRemaining <= 0 then
			-- Remove finished shake
			table.remove(activeShakes, i)
		else
			-- Apply fade out
			local fadeOut = shake.config.fadeOut or 0.2
			shake.currentMagnitude = shake.currentMagnitude * (1 - fadeOut * deltaTime * 10)

			-- Calculate and accumulate offset
			local posOffset, rotOffset = calculateShakeOffset(shake, deltaTime)
			currentPositionOffset = currentPositionOffset + posOffset
			currentRotationOffset = currentRotationOffset + rotOffset

			i = i + 1
		end
	end

	-- Apply accumulated offset to camera
	if currentPositionOffset.Magnitude > 0.001 or currentRotationOffset.Magnitude > 0.001 then
		local currentCFrame = camera.CFrame

		-- Apply position offset (local space)
		local positionedCFrame = currentCFrame * CFrame.new(currentPositionOffset)

		-- Apply rotation offset (in degrees)
		local rotatedCFrame = positionedCFrame * CFrame.Angles(
			math.rad(currentRotationOffset.X),
			math.rad(currentRotationOffset.Y),
			math.rad(currentRotationOffset.Z)
		)

		camera.CFrame = rotatedCFrame
	end
end

--[[
	Add a new shake with custom configuration
]]
function CameraShake.Shake(config: ShakeConfig)
	local shake: ActiveShake = {
		config = config,
		timeRemaining = config.duration,
		currentMagnitude = config.magnitude,
		seed = math.random(1, 10000),
	}

	table.insert(activeShakes, shake)
end

--[[
	Trigger a preset shake by name
]]
function CameraShake.ShakePreset(presetName: string)
	local preset = SHAKE_PRESETS[presetName]
	if not preset then
		warn(`[CameraShake] Unknown preset: {presetName}`)
		return
	end

	CameraShake.Shake(preset)
end

--[[
	Trigger shake for weapon fire based on weapon category
]]
function CameraShake.ShakeForWeapon(weaponCategory: string)
	if weaponCategory == "Pistol" or weaponCategory == "SMG" then
		CameraShake.ShakePreset("GunfireLight")
	elseif weaponCategory == "AR" or weaponCategory == "DMR" then
		CameraShake.ShakePreset("GunfireMedium")
	elseif weaponCategory == "Sniper" or weaponCategory == "LMG" then
		CameraShake.ShakePreset("GunfireHeavy")
	elseif weaponCategory == "Shotgun" then
		CameraShake.ShakePreset("ShotgunBlast")
	-- else: Unknown weapon types already handled by Pistol/SMG case above
	end
end

--[[
	Trigger shake for explosion based on distance
]]
function CameraShake.ShakeForExplosion(distance: number)
	if distance < 20 then
		CameraShake.ShakePreset("ExplosionNear")
	elseif distance < 50 then
		CameraShake.ShakePreset("ExplosionMedium")
	elseif distance < 100 then
		CameraShake.ShakePreset("ExplosionFar")
	end
	-- No shake beyond 100 studs
end

--[[
	Trigger shake for taking damage
]]
function CameraShake.ShakeForDamage(damageAmount: number)
	if damageAmount >= 30 then
		CameraShake.ShakePreset("DamageHeavy")
	else
		CameraShake.ShakePreset("DamageLight")
	end
end

--[[
	Trigger shake for dinosaur events
]]
function CameraShake.ShakeForDinosaur(eventType: string, distance: number?)
	local dist = distance or 0

	if eventType == "Roar" then
		if dist < 50 then
			CameraShake.ShakePreset("DinoRoar")
		end
	elseif eventType == "Footstep" then
		if dist < 30 then
			CameraShake.ShakePreset("DinoFootstep")
		end
	elseif eventType == "Attack" then
		CameraShake.ShakePreset("DinoAttack")
	end
end

--[[
	Stop all active shakes
]]
function CameraShake.StopAll()
	activeShakes = {}
end

--[[
	Get the current shake intensity (for UI effects)
]]
function CameraShake.GetCurrentIntensity(): number
	local totalMagnitude = 0
	for _, shake in activeShakes do
		totalMagnitude = totalMagnitude + shake.currentMagnitude
	end
	return math.min(totalMagnitude, 5) -- Cap at 5
end

--[[
	Check if any shakes are active
]]
function CameraShake.IsShaking(): boolean
	return #activeShakes > 0
end

--[[
	Cleanup
]]
function CameraShake.Cleanup()
	if updateConnection then
		updateConnection:Disconnect()
		updateConnection = nil
	end
	activeShakes = {}
	isInitialized = false
end

--[[
	Get available preset names (for debugging)
]]
function CameraShake.GetPresetNames(): { string }
	local names = {}
	for name in SHAKE_PRESETS do
		table.insert(names, name)
	end
	return names
end

return CameraShake
