--!strict
--[[
	AtmosphereController.lua
	========================
	Dynamic atmosphere and lighting system for Dino Royale.
	Controls time of day, weather, biome-specific atmospheres, and mood lighting.

	FEATURES:
	- Dynamic day/night cycle
	- Biome-specific lighting presets
	- Weather effects (rain, fog, storm)
	- Storm zone atmosphere changes
	- Smooth transitions between states
	- Performance-optimized particle systems

	@client
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local AtmosphereController = {}

--------------------------------------------------------------------------------
-- CONFIGURATION
--------------------------------------------------------------------------------

-- Time of day presets (ClockTime values 0-24)
local TIME_PRESETS = {
	Dawn = 6,
	Morning = 9,
	Noon = 12,
	Afternoon = 15,
	Dusk = 18,
	Evening = 20,
	Night = 0,
	Midnight = 24,
}

-- Lighting presets for different times
local LIGHTING_PRESETS = {
	Dawn = {
		Ambient = Color3.fromRGB(180, 140, 120),
		OutdoorAmbient = Color3.fromRGB(200, 160, 140),
		Brightness = 1.5,
		ColorShift_Top = Color3.fromRGB(255, 180, 140),
		ColorShift_Bottom = Color3.fromRGB(100, 80, 100),
		EnvironmentDiffuseScale = 0.8,
		EnvironmentSpecularScale = 0.8,
	},
	Day = {
		Ambient = Color3.fromRGB(150, 150, 150),
		OutdoorAmbient = Color3.fromRGB(180, 180, 180),
		Brightness = 2,
		ColorShift_Top = Color3.fromRGB(255, 255, 255),
		ColorShift_Bottom = Color3.fromRGB(150, 150, 150),
		EnvironmentDiffuseScale = 1,
		EnvironmentSpecularScale = 1,
	},
	Dusk = {
		Ambient = Color3.fromRGB(150, 100, 80),
		OutdoorAmbient = Color3.fromRGB(180, 120, 100),
		Brightness = 1.5,
		ColorShift_Top = Color3.fromRGB(255, 140, 100),
		ColorShift_Bottom = Color3.fromRGB(80, 60, 80),
		EnvironmentDiffuseScale = 0.7,
		EnvironmentSpecularScale = 0.6,
	},
	Night = {
		Ambient = Color3.fromRGB(60, 70, 100),
		OutdoorAmbient = Color3.fromRGB(40, 50, 80),
		Brightness = 0.5,
		ColorShift_Top = Color3.fromRGB(80, 100, 150),
		ColorShift_Bottom = Color3.fromRGB(20, 30, 50),
		EnvironmentDiffuseScale = 0.3,
		EnvironmentSpecularScale = 0.2,
	},
}

-- Biome atmosphere presets
local BIOME_ATMOSPHERES = {
	Jungle = {
		Density = 0.35,
		Offset = 0.1,
		Color = Color3.fromRGB(180, 210, 180),
		Decay = Color3.fromRGB(100, 130, 100),
		Glare = 0.3,
		Haze = 1.5,
	},
	Plains = {
		Density = 0.25,
		Offset = 0,
		Color = Color3.fromRGB(220, 230, 240),
		Decay = Color3.fromRGB(180, 190, 200),
		Glare = 0.5,
		Haze = 0.8,
	},
	Swamp = {
		Density = 0.5,
		Offset = 0.2,
		Color = Color3.fromRGB(150, 170, 140),
		Decay = Color3.fromRGB(80, 100, 70),
		Glare = 0.1,
		Haze = 2.5,
	},
	Volcanic = {
		Density = 0.4,
		Offset = 0.15,
		Color = Color3.fromRGB(220, 180, 160),
		Decay = Color3.fromRGB(150, 100, 80),
		Glare = 0.6,
		Haze = 1.8,
	},
	Coastal = {
		Density = 0.2,
		Offset = 0,
		Color = Color3.fromRGB(230, 240, 255),
		Decay = Color3.fromRGB(200, 220, 240),
		Glare = 0.8,
		Haze = 0.5,
	},
}

-- Weather presets
local WEATHER_PRESETS = {
	Clear = {
		fogStart = 1000,
		fogEnd = 10000,
		fogColor = Color3.fromRGB(200, 210, 220),
		atmosphereDensity = 0.25,
		brightness = 2,
		rainIntensity = 0,
	},
	Cloudy = {
		fogStart = 500,
		fogEnd = 5000,
		fogColor = Color3.fromRGB(180, 180, 190),
		atmosphereDensity = 0.35,
		brightness = 1.5,
		rainIntensity = 0,
	},
	Rainy = {
		fogStart = 200,
		fogEnd = 2000,
		fogColor = Color3.fromRGB(150, 155, 165),
		atmosphereDensity = 0.5,
		brightness = 1.2,
		rainIntensity = 0.7,
	},
	Storm = {
		fogStart = 100,
		fogEnd = 1000,
		fogColor = Color3.fromRGB(100, 105, 115),
		atmosphereDensity = 0.7,
		brightness = 0.8,
		rainIntensity = 1.0,
	},
	Foggy = {
		fogStart = 50,
		fogEnd = 500,
		fogColor = Color3.fromRGB(200, 200, 200),
		atmosphereDensity = 0.8,
		brightness = 1.3,
		rainIntensity = 0,
	},
}

-- Storm zone atmosphere (for battle royale zone)
local STORM_ATMOSPHERE = {
	insideZone = {
		atmosphereDensity = 0.3,
		atmosphereColor = Color3.fromRGB(200, 210, 220),
	},
	outsideZone = {
		atmosphereDensity = 0.7,
		atmosphereColor = Color3.fromRGB(150, 100, 180), -- Purple tint
	},
}

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------

local atmosphere: Atmosphere? = nil
local skybox: Sky? = nil
local sunRays: SunRaysEffect? = nil
local bloom: BloomEffect? = nil
local colorCorrection: ColorCorrectionEffect? = nil
local depthOfField: DepthOfFieldEffect? = nil

local currentBiome = "Plains"
local currentWeather = "Clear"
local currentTimeOfDay = 12
local isInStormZone = true

local isInitialized = false
local updateConnection: RBXScriptConnection? = nil

-- Day/night cycle settings
local dayNightEnabled = false
local dayLengthMinutes = 20 -- Full day cycle in real minutes
local cycleStartTime = 0

--------------------------------------------------------------------------------
-- HELPER FUNCTIONS
--------------------------------------------------------------------------------

--[[
	Lerp between Color3 values
]]
local function lerpColor3(a: Color3, b: Color3, t: number): Color3
	return Color3.new(
		a.R + (b.R - a.R) * t,
		a.G + (b.G - a.G) * t,
		a.B + (b.B - a.B) * t
	)
end

--[[
	Get lighting preset based on clock time
]]
local function getLightingForTime(clockTime: number): { [string]: any }
	if clockTime >= 5 and clockTime < 8 then
		-- Dawn
		local t = (clockTime - 5) / 3
		return {
			preset = "Dawn",
			blend = t,
		}
	elseif clockTime >= 8 and clockTime < 17 then
		-- Day
		return {
			preset = "Day",
			blend = 1,
		}
	elseif clockTime >= 17 and clockTime < 20 then
		-- Dusk
		local t = (clockTime - 17) / 3
		return {
			preset = "Dusk",
			blend = t,
		}
	else
		-- Night
		return {
			preset = "Night",
			blend = 1,
		}
	end
end

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

--[[
	Create or get lighting effects
]]
local function setupLightingEffects()
	-- Atmosphere
	atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end

	-- Sky
	skybox = Lighting:FindFirstChildOfClass("Sky")
	if not skybox then
		skybox = Instance.new("Sky")
		skybox.Parent = Lighting
	end

	-- Sun rays
	sunRays = Lighting:FindFirstChildOfClass("SunRaysEffect")
	if not sunRays then
		sunRays = Instance.new("SunRaysEffect")
		sunRays.Intensity = 0.1
		sunRays.Spread = 0.5
		sunRays.Parent = Lighting
	end

	-- Bloom
	bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Intensity = 0.2
		bloom.Size = 24
		bloom.Threshold = 1.5
		bloom.Parent = Lighting
	end

	-- Color correction
	colorCorrection = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if not colorCorrection then
		colorCorrection = Instance.new("ColorCorrectionEffect")
		colorCorrection.Brightness = 0
		colorCorrection.Contrast = 0.1
		colorCorrection.Saturation = 0.1
		colorCorrection.Parent = Lighting
	end

	-- Depth of field (subtle)
	depthOfField = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
	if not depthOfField then
		depthOfField = Instance.new("DepthOfFieldEffect")
		depthOfField.FarIntensity = 0.1
		depthOfField.FocusDistance = 50
		depthOfField.InFocusRadius = 30
		depthOfField.NearIntensity = 0
		depthOfField.Parent = Lighting
	end
end

--[[
	Apply a lighting preset
]]
local function applyLightingPreset(preset: { [string]: any }, transitionTime: number?)
	local duration = transitionTime or 2

	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

	TweenService:Create(Lighting, tweenInfo, {
		Ambient = preset.Ambient,
		OutdoorAmbient = preset.OutdoorAmbient,
		Brightness = preset.Brightness,
		ColorShift_Top = preset.ColorShift_Top,
		ColorShift_Bottom = preset.ColorShift_Bottom,
		EnvironmentDiffuseScale = preset.EnvironmentDiffuseScale,
		EnvironmentSpecularScale = preset.EnvironmentSpecularScale,
	}):Play()
end

--[[
	Apply atmosphere settings
]]
local function applyAtmosphere(settings: { [string]: any }, transitionTime: number?)
	if not atmosphere then return end

	local duration = transitionTime or 2
	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

	TweenService:Create(atmosphere, tweenInfo, {
		Density = settings.Density,
		Offset = settings.Offset,
		Color = settings.Color,
		Decay = settings.Decay,
		Glare = settings.Glare,
		Haze = settings.Haze,
	}):Play()
end

--------------------------------------------------------------------------------
-- UPDATE LOOP
--------------------------------------------------------------------------------

--[[
	Update function for day/night cycle
]]
local function onUpdate(deltaTime: number)
	if not dayNightEnabled then return end

	-- Calculate current time based on cycle
	local elapsed = tick() - cycleStartTime
	local cycleProgress = (elapsed / (dayLengthMinutes * 60)) % 1
	local clockTime = cycleProgress * 24

	-- Update lighting clock time
	Lighting.ClockTime = clockTime
	currentTimeOfDay = clockTime

	-- Get and apply appropriate lighting
	local lightingData = getLightingForTime(clockTime)
	local preset = LIGHTING_PRESETS[lightingData.preset]
	if preset then
		-- Apply immediately (small delta time for smooth transition)
		applyLightingPreset(preset, 0.1)
	end
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

--[[
	Initialize the atmosphere controller
]]
function AtmosphereController.Initialize()
	if isInitialized then return end

	setupLightingEffects()

	-- Set default state
	AtmosphereController.SetTimeOfDay(12)
	AtmosphereController.SetBiome("Plains")
	AtmosphereController.SetWeather("Clear")

	-- Start update loop
	updateConnection = RunService.Heartbeat:Connect(onUpdate)

	isInitialized = true
	print("[AtmosphereController] Initialized")
end

--[[
	Set time of day (0-24)
]]
function AtmosphereController.SetTimeOfDay(clockTime: number, transitionTime: number?)
	currentTimeOfDay = clockTime % 24
	Lighting.ClockTime = currentTimeOfDay

	local lightingData = getLightingForTime(currentTimeOfDay)
	local preset = LIGHTING_PRESETS[lightingData.preset]
	if preset then
		applyLightingPreset(preset, transitionTime)
	end
end

--[[
	Set time of day by preset name
]]
function AtmosphereController.SetTimePreset(presetName: string, transitionTime: number?)
	local clockTime = TIME_PRESETS[presetName]
	if clockTime then
		AtmosphereController.SetTimeOfDay(clockTime, transitionTime)
	end
end

--[[
	Get current time of day
]]
function AtmosphereController.GetTimeOfDay(): number
	return currentTimeOfDay
end

--[[
	Enable/disable day-night cycle
]]
function AtmosphereController.SetDayNightCycle(enabled: boolean, cycleLengthMinutes: number?)
	dayNightEnabled = enabled

	if enabled then
		dayLengthMinutes = cycleLengthMinutes or 20
		cycleStartTime = tick() - (currentTimeOfDay / 24 * dayLengthMinutes * 60)
	end
end

--[[
	Set biome atmosphere
]]
function AtmosphereController.SetBiome(biomeName: string, transitionTime: number?)
	local biomeAtmosphere = BIOME_ATMOSPHERES[biomeName]
	if not biomeAtmosphere then
		warn(`[AtmosphereController] Unknown biome: {biomeName}`)
		return
	end

	currentBiome = biomeName
	applyAtmosphere(biomeAtmosphere, transitionTime)
end

--[[
	Get current biome
]]
function AtmosphereController.GetCurrentBiome(): string
	return currentBiome
end

--[[
	Set weather
]]
function AtmosphereController.SetWeather(weatherName: string, transitionTime: number?)
	local weatherPreset = WEATHER_PRESETS[weatherName]
	if not weatherPreset then
		warn(`[AtmosphereController] Unknown weather: {weatherName}`)
		return
	end

	currentWeather = weatherName
	local duration = transitionTime or 3

	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

	-- Apply fog settings
	TweenService:Create(Lighting, tweenInfo, {
		FogStart = weatherPreset.fogStart,
		FogEnd = weatherPreset.fogEnd,
		FogColor = weatherPreset.fogColor,
	}):Play()

	-- Apply atmosphere density
	if atmosphere then
		TweenService:Create(atmosphere, tweenInfo, {
			Density = weatherPreset.atmosphereDensity,
		}):Play()
	end

	-- Adjust brightness
	TweenService:Create(Lighting, tweenInfo, {
		Brightness = weatherPreset.brightness,
	}):Play()

	-- TODO: Add rain particle effects when rainIntensity > 0
end

--[[
	Get current weather
]]
function AtmosphereController.GetCurrentWeather(): string
	return currentWeather
end

--[[
	Set storm zone state (for battle royale zone effects)
]]
function AtmosphereController.SetStormZoneState(insideZone: boolean, transitionTime: number?)
	isInStormZone = insideZone

	local settings = insideZone and STORM_ATMOSPHERE.insideZone or STORM_ATMOSPHERE.outsideZone
	local duration = transitionTime or 1

	if atmosphere then
		local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(atmosphere, tweenInfo, {
			Density = settings.atmosphereDensity,
			Color = settings.atmosphereColor,
		}):Play()
	end

	-- Add purple color correction when outside zone
	if colorCorrection then
		local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		if insideZone then
			TweenService:Create(colorCorrection, tweenInfo, {
				TintColor = Color3.new(1, 1, 1),
				Saturation = 0.1,
			}):Play()
		else
			TweenService:Create(colorCorrection, tweenInfo, {
				TintColor = Color3.fromRGB(220, 200, 255),
				Saturation = -0.2,
			}):Play()
		end
	end
end

--[[
	Check if player is in storm zone
]]
function AtmosphereController.IsInStormZone(): boolean
	return isInStormZone
end

--[[
	Flash lightning effect
]]
function AtmosphereController.FlashLightning()
	local originalBrightness = Lighting.Brightness

	-- Flash bright
	Lighting.Brightness = originalBrightness * 3

	-- Return to normal
	TweenService:Create(Lighting, TweenInfo.new(0.3, Enum.EasingStyle.Expo, Enum.EasingDirection.Out), {
		Brightness = originalBrightness,
	}):Play()
end

--[[
	Set sun rays intensity
]]
function AtmosphereController.SetSunRays(intensity: number, spread: number?)
	if sunRays then
		sunRays.Intensity = intensity
		if spread then
			sunRays.Spread = spread
		end
	end
end

--[[
	Set bloom settings
]]
function AtmosphereController.SetBloom(intensity: number, size: number?, threshold: number?)
	if bloom then
		bloom.Intensity = intensity
		if size then bloom.Size = size end
		if threshold then bloom.Threshold = threshold end
	end
end

--[[
	Set color correction
]]
function AtmosphereController.SetColorCorrection(brightness: number, contrast: number, saturation: number)
	if colorCorrection then
		colorCorrection.Brightness = brightness
		colorCorrection.Contrast = contrast
		colorCorrection.Saturation = saturation
	end
end

--[[
	Set depth of field
]]
function AtmosphereController.SetDepthOfField(enabled: boolean, focusDistance: number?, inFocusRadius: number?)
	if depthOfField then
		if enabled then
			depthOfField.FarIntensity = 0.3
			depthOfField.FocusDistance = focusDistance or 50
			depthOfField.InFocusRadius = inFocusRadius or 30
		else
			depthOfField.FarIntensity = 0
		end
	end
end

--[[
	Apply dramatic effect (for special moments)
]]
function AtmosphereController.ApplyDramaticEffect(duration: number?)
	local effectDuration = duration or 3

	-- Desaturate and darken
	if colorCorrection then
		TweenService:Create(colorCorrection, TweenInfo.new(0.5), {
			Saturation = -0.5,
			Brightness = -0.1,
			Contrast = 0.2,
		}):Play()

		-- Return to normal
		task.delay(effectDuration, function()
			if colorCorrection then
				TweenService:Create(colorCorrection, TweenInfo.new(1), {
					Saturation = 0.1,
					Brightness = 0,
					Contrast = 0.1,
				}):Play()
			end
		end)
	end
end

--[[
	Apply victory atmosphere (golden glow)
]]
function AtmosphereController.ApplyVictoryEffect()
	if colorCorrection then
		TweenService:Create(colorCorrection, TweenInfo.new(1), {
			TintColor = Color3.fromRGB(255, 245, 220),
			Saturation = 0.3,
			Brightness = 0.1,
		}):Play()
	end

	if bloom then
		TweenService:Create(bloom, TweenInfo.new(1), {
			Intensity = 0.5,
		}):Play()
	end
end

--[[
	Reset all effects to defaults
]]
function AtmosphereController.ResetToDefaults(transitionTime: number?)
	AtmosphereController.SetTimeOfDay(12, transitionTime)
	AtmosphereController.SetBiome("Plains", transitionTime)
	AtmosphereController.SetWeather("Clear", transitionTime)
	AtmosphereController.SetStormZoneState(true, transitionTime)

	if colorCorrection then
		TweenService:Create(colorCorrection, TweenInfo.new(transitionTime or 2), {
			TintColor = Color3.new(1, 1, 1),
			Saturation = 0.1,
			Brightness = 0,
			Contrast = 0.1,
		}):Play()
	end

	if bloom then
		TweenService:Create(bloom, TweenInfo.new(transitionTime or 2), {
			Intensity = 0.2,
		}):Play()
	end
end

--[[
	Cleanup
]]
function AtmosphereController.Cleanup()
	if updateConnection then
		updateConnection:Disconnect()
		updateConnection = nil
	end

	dayNightEnabled = false
	isInitialized = false
end

return AtmosphereController
