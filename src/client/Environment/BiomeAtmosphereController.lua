--!strict
--[[
	BiomeAtmosphereController.lua
	=============================
	Handles dynamic atmosphere, lighting, and fog effects based on player's current biome.

	Features:
	- Smooth transitions between biome atmospheres
	- Time-of-day integration
	- Weather effect overlays
	- Performance-optimized updates

	Based on map design best practices for visual cohesion and atmosphere.
]]

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local _TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local BiomeData = require(game.ReplicatedStorage.Shared.BiomeData)

local BiomeAtmosphereController = {}
BiomeAtmosphereController.__index = BiomeAtmosphereController

-- Configuration
local CONFIG = {
	-- How often to check player's biome (seconds)
	UpdateInterval = 0.5,

	-- Transition duration between biomes (seconds)
	TransitionDuration = 2.0,

	-- Distance from biome center to start transition
	TransitionStartDistance = 300,

	-- Default biome when outside all biomes
	DefaultBiome = "Plains",

	-- Blend distance for biome edges
	BlendDistance = 150,
}

-- State
local currentBiome: string? = nil
local targetBiome: string? = nil
local transitionProgress: number = 1.0
local lastUpdateTime: number = 0
local isTransitioning: boolean = false

-- Cached lighting objects
local atmosphere: Atmosphere? = nil
local colorCorrection: ColorCorrectionEffect? = nil
local bloom: BloomEffect? = nil
local depthOfField: DepthOfFieldEffect? = nil
local sunRays: SunRaysEffect? = nil

-- Forward declarations for local functions
local applyBiomeAtmosphere: (biomeConfig: any, influence: number) -> ()
local blendBiomeAtmospheres: (fromBiome: string, toBiome: string, t: number) -> ()

-- Biome center positions (matching BiomeData sectors)
local BIOME_CENTERS = {
	Jungle = Vector3.new(0, 25, 0),
	Desert = Vector3.new(-1200, 30, -800),
	Mountains = Vector3.new(800, 80, -1200),
	Plains = Vector3.new(-1200, 20, 0),
	Volcanic = Vector3.new(0, 50, -1400),
	Swamp = Vector3.new(1200, 12, 0),
	Coast = Vector3.new(0, 10, 1400),
	Research = Vector3.new(-800, 35, 800),
}

-- Biome influence radii
local BIOME_RADII = {
	Jungle = 800,
	Desert = 600,
	Mountains = 700,
	Plains = 900,
	Volcanic = 500,
	Swamp = 600,
	Coast = 700,
	Research = 400,
}

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

function BiomeAtmosphereController.Initialize()
	-- Get or create atmosphere
	atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end

	-- Get or create color correction
	colorCorrection = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if not colorCorrection then
		colorCorrection = Instance.new("ColorCorrectionEffect")
		colorCorrection.Name = "BiomeColorCorrection"
		colorCorrection.Parent = Lighting
	end

	-- Get or create bloom
	bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Name = "BiomeBloom"
		bloom.Parent = Lighting
	end

	-- Get or create depth of field (disabled by default)
	depthOfField = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
	if not depthOfField then
		depthOfField = Instance.new("DepthOfFieldEffect")
		depthOfField.Name = "BiomeDepthOfField"
		depthOfField.Enabled = false
		depthOfField.Parent = Lighting
	end

	-- Get or create sun rays
	sunRays = Lighting:FindFirstChildOfClass("SunRaysEffect")
	if not sunRays then
		sunRays = Instance.new("SunRaysEffect")
		sunRays.Name = "BiomeSunRays"
		sunRays.Parent = Lighting
	end

	-- Apply default biome
	local defaultBiomeConfig = BiomeData.Biomes[CONFIG.DefaultBiome]
	if defaultBiomeConfig then
		applyBiomeAtmosphere(defaultBiomeConfig, 1.0)
		currentBiome = CONFIG.DefaultBiome
	end

	-- Start update loop
	RunService.Heartbeat:Connect(function(deltaTime)
		BiomeAtmosphereController.Update(deltaTime)
	end)

	print("[BiomeAtmosphereController] Initialized")
end

--------------------------------------------------------------------------------
-- BIOME DETECTION
--------------------------------------------------------------------------------

local function getPlayerPosition(): Vector3?
	local player = Players.LocalPlayer
	if not player then return nil end

	local character = player.Character
	if not character then return nil end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then return nil end

	return rootPart.Position
end

local function calculateBiomeInfluence(position: Vector3, biomeName: string): number
	local center = BIOME_CENTERS[biomeName]
	local radius = BIOME_RADII[biomeName]

	if not center or not radius then
		return 0
	end

	-- Calculate horizontal distance (ignore Y for biome detection)
	local horizontalDistance = (Vector3.new(position.X, 0, position.Z) - Vector3.new(center.X, 0, center.Z)).Magnitude

	-- Full influence inside radius, gradual falloff outside
	if horizontalDistance <= radius then
		return 1.0
	elseif horizontalDistance <= radius + CONFIG.BlendDistance then
		return 1.0 - ((horizontalDistance - radius) / CONFIG.BlendDistance)
	else
		return 0
	end
end

local function detectCurrentBiome(position: Vector3): (string, number)
	local bestBiome = CONFIG.DefaultBiome
	local bestInfluence = 0

	for biomeName, _ in pairs(BIOME_CENTERS) do
		local influence = calculateBiomeInfluence(position, biomeName)
		if influence > bestInfluence then
			bestInfluence = influence
			bestBiome = biomeName
		end
	end

	return bestBiome, bestInfluence
end

--------------------------------------------------------------------------------
-- ATMOSPHERE APPLICATION
--------------------------------------------------------------------------------

local function lerpColor3(a: Color3, b: Color3, t: number): Color3
	return Color3.new(
		a.R + (b.R - a.R) * t,
		a.G + (b.G - a.G) * t,
		a.B + (b.B - a.B) * t
	)
end

local function lerpNumber(a: number, b: number, t: number): number
	return a + (b - a) * t
end

applyBiomeAtmosphere = function(biomeConfig: BiomeData.BiomeConfig, influence: number)
	if not atmosphere or not colorCorrection or not bloom then
		return
	end

	local atm = biomeConfig.atmosphere
	local light = biomeConfig.lighting

	-- Apply atmosphere settings
	atmosphere.Density = atm.density * influence
	atmosphere.Offset = atm.offset
	atmosphere.Color = lerpColor3(Color3.new(1, 1, 1), atm.color, influence)
	atmosphere.Decay = lerpColor3(Color3.new(1, 1, 1), atm.decay, influence)
	atmosphere.Glare = atm.glare * influence
	atmosphere.Haze = atm.haze * influence

	-- Apply lighting settings
	Lighting.Ambient = lerpColor3(Color3.fromRGB(127, 127, 127), light.ambient, influence)
	Lighting.OutdoorAmbient = lerpColor3(Color3.fromRGB(127, 127, 127), light.outdoorAmbient, influence)
	Lighting.Brightness = lerpNumber(2, light.brightness, influence)
	Lighting.ColorShift_Top = lerpColor3(Color3.new(0, 0, 0), light.colorShift_Top, influence)
	Lighting.ColorShift_Bottom = lerpColor3(Color3.new(0, 0, 0), light.colorShift_Bottom, influence)
	Lighting.EnvironmentDiffuseScale = light.environmentDiffuseScale
	Lighting.EnvironmentSpecularScale = light.environmentSpecularScale
	Lighting.GlobalShadows = light.globalShadows
	Lighting.ShadowSoftness = light.shadowSoftness

	-- Apply fog settings
	if biomeConfig.fogEnabled then
		Lighting.FogStart = biomeConfig.fogStart
		Lighting.FogEnd = biomeConfig.fogEnd
		Lighting.FogColor = biomeConfig.fogColor
	else
		Lighting.FogStart = 0
		Lighting.FogEnd = 100000
	end

	-- Apply color correction based on biome palette
	local palette = biomeConfig.colorPalette
	if palette then
		-- Subtle tint toward biome's primary color
		colorCorrection.TintColor = lerpColor3(Color3.new(1, 1, 1), palette.primary, influence * 0.15)
		colorCorrection.Saturation = lerpNumber(0, 0.1, influence)
		colorCorrection.Contrast = lerpNumber(0, 0.05, influence)
	end

	-- Apply bloom based on biome
	bloom.Intensity = lerpNumber(0.5, 0.8, influence)
	bloom.Size = 24
	bloom.Threshold = 1.5

	-- Apply sun rays based on biome
	if sunRays then
		if biomeConfig.name == "Volcanic" then
			sunRays.Intensity = 0.1
			sunRays.Spread = 0.5
		elseif biomeConfig.name == "Swamp" then
			sunRays.Intensity = 0.05
			sunRays.Spread = 0.8
		else
			sunRays.Intensity = lerpNumber(0.1, 0.25, influence)
			sunRays.Spread = 1.0
		end
	end
end

blendBiomeAtmospheres = function(fromBiome: string, toBiome: string, t: number)
	local fromConfig = BiomeData.Biomes[fromBiome]
	local toConfig = BiomeData.Biomes[toBiome]

	if not fromConfig or not toConfig then
		return
	end

	if not atmosphere or not colorCorrection or not bloom then
		return
	end

	local fromAtm = fromConfig.atmosphere
	local toAtm = toConfig.atmosphere
	local fromLight = fromConfig.lighting
	local toLight = toConfig.lighting

	-- Blend atmosphere
	atmosphere.Density = lerpNumber(fromAtm.density, toAtm.density, t)
	atmosphere.Offset = lerpNumber(fromAtm.offset, toAtm.offset, t)
	atmosphere.Color = lerpColor3(fromAtm.color, toAtm.color, t)
	atmosphere.Decay = lerpColor3(fromAtm.decay, toAtm.decay, t)
	atmosphere.Glare = lerpNumber(fromAtm.glare, toAtm.glare, t)
	atmosphere.Haze = lerpNumber(fromAtm.haze, toAtm.haze, t)

	-- Blend lighting
	Lighting.Ambient = lerpColor3(fromLight.ambient, toLight.ambient, t)
	Lighting.OutdoorAmbient = lerpColor3(fromLight.outdoorAmbient, toLight.outdoorAmbient, t)
	Lighting.Brightness = lerpNumber(fromLight.brightness, toLight.brightness, t)
	Lighting.ColorShift_Top = lerpColor3(fromLight.colorShift_Top, toLight.colorShift_Top, t)
	Lighting.ColorShift_Bottom = lerpColor3(fromLight.colorShift_Bottom, toLight.colorShift_Bottom, t)

	-- Blend fog
	local fogEnabled = fromConfig.fogEnabled or toConfig.fogEnabled
	if fogEnabled then
		Lighting.FogStart = lerpNumber(fromConfig.fogStart, toConfig.fogStart, t)
		Lighting.FogEnd = lerpNumber(fromConfig.fogEnd, toConfig.fogEnd, t)
		Lighting.FogColor = lerpColor3(fromConfig.fogColor, toConfig.fogColor, t)
	end

	-- Blend color correction
	local fromPalette = fromConfig.colorPalette
	local toPalette = toConfig.colorPalette
	if fromPalette and toPalette then
		local blendedTint = lerpColor3(fromPalette.primary, toPalette.primary, t)
		colorCorrection.TintColor = lerpColor3(Color3.new(1, 1, 1), blendedTint, 0.15)
	end

	-- Blend bloom
	bloom.Intensity = lerpNumber(0.6, 0.9, t)
end

--------------------------------------------------------------------------------
-- TIME OF DAY INTEGRATION
--------------------------------------------------------------------------------

local function getTimeOfDayMultiplier(): number
	local clockTime = Lighting.ClockTime

	-- Dawn: 5-7, Dusk: 17-19
	if clockTime >= 5 and clockTime <= 7 then
		-- Dawn - warm colors
		return 0.8
	elseif clockTime >= 17 and clockTime <= 19 then
		-- Dusk - warm colors
		return 0.85
	elseif clockTime >= 7 and clockTime <= 17 then
		-- Day - full brightness
		return 1.0
	else
		-- Night - reduced
		return 0.6
	end
end

local function applyTimeOfDayModifiers()
	local _multiplier = getTimeOfDayMultiplier()

	if colorCorrection then
		-- Warm tint at dawn/dusk
		local clockTime = Lighting.ClockTime
		if (clockTime >= 5 and clockTime <= 7) or (clockTime >= 17 and clockTime <= 19) then
			local warmth = 0.1
			colorCorrection.TintColor = lerpColor3(
				colorCorrection.TintColor,
				Color3.fromRGB(255, 220, 180),
				warmth
			)
		end
	end

	if bloom then
		-- Increased bloom at dawn/dusk
		local clockTime = Lighting.ClockTime
		if (clockTime >= 5 and clockTime <= 7) or (clockTime >= 17 and clockTime <= 19) then
			bloom.Intensity = bloom.Intensity * 1.2
		end
	end
end

--------------------------------------------------------------------------------
-- WEATHER EFFECTS
--------------------------------------------------------------------------------

local activeWeatherEffects: { [string]: any } = {}

function BiomeAtmosphereController.ApplyWeatherEffect(effectName: string, intensity: number)
	if effectName == "Rain" then
		-- Increase fog, reduce visibility
		if atmosphere then
			atmosphere.Density = atmosphere.Density + (0.2 * intensity)
			atmosphere.Haze = atmosphere.Haze + (2 * intensity)
		end
		Lighting.FogEnd = Lighting.FogEnd * (1 - 0.3 * intensity)

	elseif effectName == "Fog" then
		-- Heavy fog
		if atmosphere then
			atmosphere.Density = atmosphere.Density + (0.4 * intensity)
			atmosphere.Haze = 10 * intensity
		end
		Lighting.FogStart = 0
		Lighting.FogEnd = 200 / intensity

	elseif effectName == "Storm" then
		-- Dark, dramatic
		if atmosphere then
			atmosphere.Density = atmosphere.Density + (0.3 * intensity)
			atmosphere.Color = lerpColor3(atmosphere.Color, Color3.fromRGB(100, 100, 120), intensity)
		end
		Lighting.Brightness = Lighting.Brightness * (1 - 0.4 * intensity)

	elseif effectName == "VolcanicAsh" then
		-- Orange/red tint, reduced visibility
		if atmosphere then
			atmosphere.Density = atmosphere.Density + (0.3 * intensity)
			atmosphere.Color = lerpColor3(atmosphere.Color, Color3.fromRGB(180, 100, 80), intensity)
		end
		if colorCorrection then
			colorCorrection.TintColor = lerpColor3(colorCorrection.TintColor, Color3.fromRGB(255, 180, 150), intensity * 0.3)
		end

	elseif effectName == "SwampMist" then
		-- Green tint, low fog
		if atmosphere then
			atmosphere.Haze = atmosphere.Haze + (3 * intensity)
		end
		Lighting.FogStart = 0
		Lighting.FogEnd = 400 / intensity
		Lighting.FogColor = lerpColor3(Lighting.FogColor, Color3.fromRGB(150, 170, 140), intensity)
	end

	activeWeatherEffects[effectName] = intensity
end

function BiomeAtmosphereController.ClearWeatherEffect(effectName: string)
	activeWeatherEffects[effectName] = nil

	-- Reapply current biome to reset effects
	if currentBiome then
		local biomeConfig = BiomeData.Biomes[currentBiome]
		if biomeConfig then
			applyBiomeAtmosphere(biomeConfig, 1.0)
		end
	end
end

function BiomeAtmosphereController.ClearAllWeatherEffects()
	activeWeatherEffects = {}

	if currentBiome then
		local biomeConfig = BiomeData.Biomes[currentBiome]
		if biomeConfig then
			applyBiomeAtmosphere(biomeConfig, 1.0)
		end
	end
end

--------------------------------------------------------------------------------
-- UPDATE LOOP
--------------------------------------------------------------------------------

function BiomeAtmosphereController.Update(deltaTime: number)
	lastUpdateTime = lastUpdateTime + deltaTime

	-- Only check biome periodically
	if lastUpdateTime < CONFIG.UpdateInterval then
		-- But still update transitions smoothly
		if isTransitioning and currentBiome and targetBiome then
			transitionProgress = transitionProgress + (deltaTime / CONFIG.TransitionDuration)

			if transitionProgress >= 1.0 then
				transitionProgress = 1.0
				isTransitioning = false
				currentBiome = targetBiome
				targetBiome = nil

				local biomeConfig = BiomeData.Biomes[currentBiome]
				if biomeConfig then
					applyBiomeAtmosphere(biomeConfig, 1.0)
				end
			else
				blendBiomeAtmospheres(currentBiome, targetBiome, transitionProgress)
			end
		end
		return
	end

	lastUpdateTime = 0

	-- Get player position
	local position = getPlayerPosition()
	if not position then
		return
	end

	-- Detect current biome
	local detectedBiome, _influence = detectCurrentBiome(position)

	-- Check if biome changed
	if detectedBiome ~= currentBiome and not isTransitioning then
		-- Start transition to new biome
		targetBiome = detectedBiome
		isTransitioning = true
		transitionProgress = 0

		print("[BiomeAtmosphereController] Transitioning from", currentBiome, "to", targetBiome)
	end

	-- Apply time of day modifiers
	applyTimeOfDayModifiers()
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

function BiomeAtmosphereController.GetCurrentBiome(): string?
	return currentBiome
end

function BiomeAtmosphereController.IsTransitioning(): boolean
	return isTransitioning
end

function BiomeAtmosphereController.GetTransitionProgress(): number
	return transitionProgress
end

function BiomeAtmosphereController.ForceSetBiome(biomeName: string)
	local biomeConfig = BiomeData.Biomes[biomeName]
	if not biomeConfig then
		warn("[BiomeAtmosphereController] Unknown biome:", biomeName)
		return
	end

	currentBiome = biomeName
	targetBiome = nil
	isTransitioning = false
	transitionProgress = 1.0

	applyBiomeAtmosphere(biomeConfig, 1.0)
	print("[BiomeAtmosphereController] Force set biome to:", biomeName)
end

function BiomeAtmosphereController.SetTransitionDuration(duration: number)
	CONFIG.TransitionDuration = math.max(0.1, duration)
end

function BiomeAtmosphereController.SetUpdateInterval(interval: number)
	CONFIG.UpdateInterval = math.max(0.1, interval)
end

-- Reset to default state
function BiomeAtmosphereController.Reset()
	currentBiome = nil
	targetBiome = nil
	isTransitioning = false
	transitionProgress = 1.0
	activeWeatherEffects = {}

	local defaultBiomeConfig = BiomeData.Biomes[CONFIG.DefaultBiome]
	if defaultBiomeConfig then
		applyBiomeAtmosphere(defaultBiomeConfig, 1.0)
		currentBiome = CONFIG.DefaultBiome
	end

	print("[BiomeAtmosphereController] Reset to default state")
end

return BiomeAtmosphereController
