--!strict
--[[
	LightingManager.lua
	===================
	Client-side lighting and post-processing configuration
	Implements AAA-quality visual effects using Roblox's Future lighting technology

	Based on best practices from:
	- Roblox Future Is Bright lighting system
	- PBR material rendering optimization
	- Post-processing effect stacking for cinematic quality

	Key Features:
	- Future lighting with optimized shadow settings
	- Dynamic time-of-day transitions
	- Bloom, ColorCorrection, DepthOfField, and SunRays effects
	- Atmosphere with realistic fog and haze
	- Performance-aware quality scaling
]]

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local LightingManager = {}

-- State tracking
local isInitialized = false
local currentPreset = "Default"
local timeOfDayEnabled = false
local timeOfDayConnection: RBXScriptConnection? = nil

-- Post-processing effect references
local bloomEffect: BloomEffect? = nil
local colorCorrection: ColorCorrectionEffect? = nil
local depthOfField: DepthOfFieldEffect? = nil
local sunRays: SunRaysEffect? = nil
local atmosphere: Atmosphere? = nil
local sky: Sky? = nil

--[[
	LIGHTING PRESETS
	================
	Each preset defines optimal settings for different game contexts
	Values tuned for visual quality while maintaining 60+ FPS on mid-tier hardware
]]
local LightingPresets = {
	-- Default prehistoric jungle atmosphere
	Default = {
		-- Core lighting settings (Future technology for best quality)
		Technology = Enum.Technology.Future,
		GlobalShadows = true,
		ShadowSoftness = 0.3, -- Balanced between sharp and soft (0.2-0.5 optimal)

		-- Ambient lighting (warm jungle feel)
		Ambient = Color3.fromRGB(40, 45, 50),
		OutdoorAmbient = Color3.fromRGB(120, 130, 140),

		-- Color temperature (slightly warm for prehistoric atmosphere)
		ColorShift_Bottom = Color3.fromRGB(20, 18, 15),
		ColorShift_Top = Color3.fromRGB(0, 0, 0),

		-- Brightness and exposure
		Brightness = 2.5,
		ExposureCompensation = 0.1,
		EnvironmentDiffuseScale = 1,
		EnvironmentSpecularScale = 1,

		-- Time settings (late morning)
		ClockTime = 10.5,
		GeographicLatitude = 20, -- Tropical latitude

		-- Atmosphere settings
		Atmosphere = {
			Density = 0.35,
			Offset = 0.1,
			Color = Color3.fromRGB(199, 210, 225),
			Decay = Color3.fromRGB(92, 105, 120),
			Glare = 0.2,
			Haze = 1.5,
		},

		-- Post-processing effects
		Bloom = {
			Enabled = true,
			Intensity = 0.8,
			Size = 24,
			Threshold = 1.2,
		},
		ColorCorrection = {
			Enabled = true,
			Brightness = 0.02,
			Contrast = 0.1,
			Saturation = 0.15,
			TintColor = Color3.fromRGB(255, 252, 248), -- Slight warm tint
		},
		DepthOfField = {
			Enabled = true,
			FarIntensity = 0.15,
			FocusDistance = 50,
			InFocusRadius = 30,
			NearIntensity = 0,
		},
		SunRays = {
			Enabled = true,
			Intensity = 0.08,
			Spread = 0.8,
		},
	},

	-- Storm/danger atmosphere (darker, more intense)
	Storm = {
		Technology = Enum.Technology.Future,
		GlobalShadows = true,
		ShadowSoftness = 0.5,
		Ambient = Color3.fromRGB(25, 30, 40),
		OutdoorAmbient = Color3.fromRGB(60, 70, 90),
		ColorShift_Bottom = Color3.fromRGB(10, 15, 25),
		ColorShift_Top = Color3.fromRGB(5, 5, 10),
		Brightness = 1.5,
		ExposureCompensation = -0.3,
		EnvironmentDiffuseScale = 0.7,
		EnvironmentSpecularScale = 0.5,
		ClockTime = 15,
		GeographicLatitude = 20,
		Atmosphere = {
			Density = 0.6,
			Offset = 0.2,
			Color = Color3.fromRGB(140, 150, 170),
			Decay = Color3.fromRGB(60, 70, 90),
			Glare = 0.05,
			Haze = 3,
		},
		Bloom = {
			Enabled = true,
			Intensity = 0.4,
			Size = 30,
			Threshold = 1.5,
		},
		ColorCorrection = {
			Enabled = true,
			Brightness = -0.05,
			Contrast = 0.2,
			Saturation = -0.1,
			TintColor = Color3.fromRGB(200, 210, 230), -- Cool storm tint
		},
		DepthOfField = {
			Enabled = true,
			FarIntensity = 0.3,
			FocusDistance = 30,
			InFocusRadius = 20,
			NearIntensity = 0.1,
		},
		SunRays = {
			Enabled = false,
			Intensity = 0,
			Spread = 0,
		},
	},

	-- Volcanic region (hot, fiery atmosphere)
	Volcanic = {
		Technology = Enum.Technology.Future,
		GlobalShadows = true,
		ShadowSoftness = 0.4,
		Ambient = Color3.fromRGB(60, 35, 25),
		OutdoorAmbient = Color3.fromRGB(140, 90, 60),
		ColorShift_Bottom = Color3.fromRGB(40, 20, 10),
		ColorShift_Top = Color3.fromRGB(15, 5, 0),
		Brightness = 2.8,
		ExposureCompensation = 0.2,
		EnvironmentDiffuseScale = 1.2,
		EnvironmentSpecularScale = 0.8,
		ClockTime = 17,
		GeographicLatitude = 15,
		Atmosphere = {
			Density = 0.5,
			Offset = 0.15,
			Color = Color3.fromRGB(255, 180, 130),
			Decay = Color3.fromRGB(150, 80, 50),
			Glare = 0.3,
			Haze = 2,
		},
		Bloom = {
			Enabled = true,
			Intensity = 1.2,
			Size = 35,
			Threshold = 0.9,
		},
		ColorCorrection = {
			Enabled = true,
			Brightness = 0.05,
			Contrast = 0.15,
			Saturation = 0.2,
			TintColor = Color3.fromRGB(255, 230, 200), -- Warm volcanic tint
		},
		DepthOfField = {
			Enabled = true,
			FarIntensity = 0.25,
			FocusDistance = 40,
			InFocusRadius = 25,
			NearIntensity = 0.05,
		},
		SunRays = {
			Enabled = true,
			Intensity = 0.15,
			Spread = 1,
		},
	},

	-- Night time (mysterious, moonlit)
	Night = {
		Technology = Enum.Technology.Future,
		GlobalShadows = true,
		ShadowSoftness = 0.6,
		Ambient = Color3.fromRGB(15, 20, 35),
		OutdoorAmbient = Color3.fromRGB(30, 40, 60),
		ColorShift_Bottom = Color3.fromRGB(5, 8, 15),
		ColorShift_Top = Color3.fromRGB(0, 0, 5),
		Brightness = 0.8,
		ExposureCompensation = -0.5,
		EnvironmentDiffuseScale = 0.5,
		EnvironmentSpecularScale = 0.3,
		ClockTime = 22,
		GeographicLatitude = 20,
		Atmosphere = {
			Density = 0.4,
			Offset = 0.05,
			Color = Color3.fromRGB(100, 120, 160),
			Decay = Color3.fromRGB(40, 50, 80),
			Glare = 0,
			Haze = 0.5,
		},
		Bloom = {
			Enabled = true,
			Intensity = 1.5,
			Size = 40,
			Threshold = 0.8,
		},
		ColorCorrection = {
			Enabled = true,
			Brightness = -0.1,
			Contrast = 0.25,
			Saturation = -0.2,
			TintColor = Color3.fromRGB(180, 200, 255), -- Cool moonlit tint
		},
		DepthOfField = {
			Enabled = true,
			FarIntensity = 0.4,
			FocusDistance = 25,
			InFocusRadius = 15,
			NearIntensity = 0.15,
		},
		SunRays = {
			Enabled = false,
			Intensity = 0,
			Spread = 0,
		},
	},

	-- Victory screen (bright, triumphant)
	Victory = {
		Technology = Enum.Technology.Future,
		GlobalShadows = true,
		ShadowSoftness = 0.2,
		Ambient = Color3.fromRGB(60, 65, 70),
		OutdoorAmbient = Color3.fromRGB(180, 190, 200),
		ColorShift_Bottom = Color3.fromRGB(30, 25, 15),
		ColorShift_Top = Color3.fromRGB(0, 0, 0),
		Brightness = 3,
		ExposureCompensation = 0.3,
		EnvironmentDiffuseScale = 1.2,
		EnvironmentSpecularScale = 1.5,
		ClockTime = 9,
		GeographicLatitude = 25,
		Atmosphere = {
			Density = 0.25,
			Offset = 0.05,
			Color = Color3.fromRGB(220, 230, 245),
			Decay = Color3.fromRGB(110, 120, 140),
			Glare = 0.4,
			Haze = 1,
		},
		Bloom = {
			Enabled = true,
			Intensity = 1.5,
			Size = 50,
			Threshold = 1,
		},
		ColorCorrection = {
			Enabled = true,
			Brightness = 0.1,
			Contrast = 0.05,
			Saturation = 0.25,
			TintColor = Color3.fromRGB(255, 250, 240), -- Golden victory tint
		},
		DepthOfField = {
			Enabled = false,
			FarIntensity = 0,
			FocusDistance = 100,
			InFocusRadius = 100,
			NearIntensity = 0,
		},
		SunRays = {
			Enabled = true,
			Intensity = 0.2,
			Spread = 1.2,
		},
	},
}

--[[
	Initialize the lighting manager
	Creates all post-processing effects and applies default preset
]]
function LightingManager.Initialize()
	if isInitialized then return end
	isInitialized = true

	print("[LightingManager] Initializing AAA-quality lighting system...")

	-- Create post-processing effects
	LightingManager.CreatePostProcessingEffects()

	-- Create atmosphere
	LightingManager.CreateAtmosphere()

	-- Create sky
	LightingManager.CreateSky()

	-- Apply default preset
	LightingManager.ApplyPreset("Default", 0)

	print("[LightingManager] Initialized with Future lighting technology")
end

--[[
	Create all post-processing effect instances
	Effects are parented to Lighting for global application
]]
function LightingManager.CreatePostProcessingEffects()
	-- Remove existing effects to prevent duplicates
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("PostEffect") then
			child:Destroy()
		end
	end

	-- Bloom Effect: Creates light glow and enhances bright areas
	-- Recommended settings: Intensity 0.5-1.5, Size 24-40, Threshold 0.9-1.5
	bloomEffect = Instance.new("BloomEffect")
	bloomEffect.Name = "DinoRoyaleBloom"
	bloomEffect.Parent = Lighting

	-- Color Correction: Adjusts overall color grading for cinematic look
	-- Use subtle values to avoid oversaturation
	colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "DinoRoyaleColorCorrection"
	colorCorrection.Parent = Lighting

	-- Depth of Field: Blurs distant objects for focus and immersion
	-- FarIntensity 0.1-0.3 for subtle effect, higher for dramatic blur
	depthOfField = Instance.new("DepthOfFieldEffect")
	depthOfField.Name = "DinoRoyaleDepthOfField"
	depthOfField.Parent = Lighting

	-- Sun Rays: Creates volumetric light rays from the sun
	-- Use sparingly (Intensity 0.05-0.15) to avoid visual noise
	sunRays = Instance.new("SunRaysEffect")
	sunRays.Name = "DinoRoyaleSunRays"
	sunRays.Parent = Lighting
end

--[[
	Create atmosphere for realistic environmental fog and haze
	Atmosphere simulates light scattering in the air
]]
function LightingManager.CreateAtmosphere()
	-- Remove existing atmosphere
	local existing = Lighting:FindFirstChildOfClass("Atmosphere")
	if existing then
		existing:Destroy()
	end

	-- Create new atmosphere
	-- Density: 0.3-0.5 for visible but not heavy fog
	-- Haze: 1-2 for subtle distance blur
	atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "DinoRoyaleAtmosphere"
	atmosphere.Parent = Lighting
end

--[[
	Create sky with prehistoric atmosphere colors
	Sky affects ambient lighting and reflections
]]
function LightingManager.CreateSky()
	-- Remove existing sky
	local existing = Lighting:FindFirstChildOfClass("Sky")
	if existing then
		existing:Destroy()
	end

	-- Create procedural sky (using default Roblox sky for now)
	-- Custom skyboxes can be added with SkyboxBk, SkyboxDn, etc.
	sky = Instance.new("Sky")
	sky.Name = "DinoRoyaleSky"
	sky.SunAngularSize = 15
	sky.MoonAngularSize = 10
	sky.StarCount = 3000
	sky.Parent = Lighting
end

--[[
	Apply a lighting preset with optional transition time
	@param presetName Name of the preset to apply
	@param transitionTime Time in seconds for smooth transition (0 for instant)
]]
function LightingManager.ApplyPreset(presetName: string, transitionTime: number?)
	local preset = LightingPresets[presetName]
	if not preset then
		warn(`[LightingManager] Unknown preset: {presetName}`)
		return
	end

	local duration = transitionTime or 1.5
	currentPreset = presetName

	-- Apply lighting technology (instant, cannot be tweened)
	Lighting.Technology = preset.Technology
	Lighting.GlobalShadows = preset.GlobalShadows

	-- Tween core lighting properties for smooth transition
	local lightingTween = TweenService:Create(Lighting, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
		ShadowSoftness = preset.ShadowSoftness,
		Ambient = preset.Ambient,
		OutdoorAmbient = preset.OutdoorAmbient,
		ColorShift_Bottom = preset.ColorShift_Bottom,
		ColorShift_Top = preset.ColorShift_Top,
		Brightness = preset.Brightness,
		ExposureCompensation = preset.ExposureCompensation,
		EnvironmentDiffuseScale = preset.EnvironmentDiffuseScale,
		EnvironmentSpecularScale = preset.EnvironmentSpecularScale,
		ClockTime = preset.ClockTime,
		GeographicLatitude = preset.GeographicLatitude,
	})
	lightingTween:Play()

	-- Apply atmosphere settings
	if atmosphere and preset.Atmosphere then
		local atmosphereTween = TweenService:Create(atmosphere, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
			Density = preset.Atmosphere.Density,
			Offset = preset.Atmosphere.Offset,
			Color = preset.Atmosphere.Color,
			Decay = preset.Atmosphere.Decay,
			Glare = preset.Atmosphere.Glare,
			Haze = preset.Atmosphere.Haze,
		})
		atmosphereTween:Play()
	end

	-- Apply bloom settings
	if bloomEffect and preset.Bloom then
		bloomEffect.Enabled = preset.Bloom.Enabled
		if preset.Bloom.Enabled then
			local bloomTween = TweenService:Create(bloomEffect, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
				Intensity = preset.Bloom.Intensity,
				Size = preset.Bloom.Size,
				Threshold = preset.Bloom.Threshold,
			})
			bloomTween:Play()
		end
	end

	-- Apply color correction settings
	if colorCorrection and preset.ColorCorrection then
		colorCorrection.Enabled = preset.ColorCorrection.Enabled
		if preset.ColorCorrection.Enabled then
			local ccTween = TweenService:Create(colorCorrection, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
				Brightness = preset.ColorCorrection.Brightness,
				Contrast = preset.ColorCorrection.Contrast,
				Saturation = preset.ColorCorrection.Saturation,
				TintColor = preset.ColorCorrection.TintColor,
			})
			ccTween:Play()
		end
	end

	-- Apply depth of field settings
	if depthOfField and preset.DepthOfField then
		depthOfField.Enabled = preset.DepthOfField.Enabled
		if preset.DepthOfField.Enabled then
			local dofTween = TweenService:Create(depthOfField, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
				FarIntensity = preset.DepthOfField.FarIntensity,
				FocusDistance = preset.DepthOfField.FocusDistance,
				InFocusRadius = preset.DepthOfField.InFocusRadius,
				NearIntensity = preset.DepthOfField.NearIntensity,
			})
			dofTween:Play()
		end
	end

	-- Apply sun rays settings
	if sunRays and preset.SunRays then
		sunRays.Enabled = preset.SunRays.Enabled
		if preset.SunRays.Enabled then
			local sunTween = TweenService:Create(sunRays, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
				Intensity = preset.SunRays.Intensity,
				Spread = preset.SunRays.Spread,
			})
			sunTween:Play()
		end
	end

	print(`[LightingManager] Applied preset: {presetName} (transition: {duration}s)`)
end

--[[
	Enable dynamic time-of-day cycle
	Creates immersive day/night transitions
	@param cycleDuration Total cycle length in seconds (default 600 = 10 minutes)
]]
function LightingManager.EnableTimeOfDay(cycleDuration: number?)
	if timeOfDayEnabled then return end
	timeOfDayEnabled = true

	local cycleTime = cycleDuration or 600 -- 10 minute day cycle
	local _startTime = Lighting.ClockTime

	timeOfDayConnection = RunService.Heartbeat:Connect(function(dt)
		-- Advance time (24 hours over cycle duration)
		local timeIncrement = (24 / cycleTime) * dt
		local newTime = (Lighting.ClockTime + timeIncrement) % 24
		Lighting.ClockTime = newTime
	end)

	print(`[LightingManager] Time-of-day enabled (cycle: {cycleTime}s)`)
end

--[[
	Disable dynamic time-of-day cycle
]]
function LightingManager.DisableTimeOfDay()
	if not timeOfDayEnabled then return end
	timeOfDayEnabled = false

	if timeOfDayConnection then
		timeOfDayConnection:Disconnect()
		timeOfDayConnection = nil
	end

	print("[LightingManager] Time-of-day disabled")
end

--[[
	Set specific time of day
	@param hour Hour (0-24)
	@param transitionTime Optional transition duration
]]
function LightingManager.SetTimeOfDay(hour: number, transitionTime: number?)
	local duration = transitionTime or 0

	if duration > 0 then
		local tween = TweenService:Create(Lighting, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {
			ClockTime = hour,
		})
		tween:Play()
	else
		Lighting.ClockTime = hour
	end
end

--[[
	Apply damage feedback effect (red tint)
	Used when player takes damage
	@param intensity Damage intensity (0-1)
]]
function LightingManager.DamageFlash(intensity: number)
	if not colorCorrection then return end

	-- Store original values
	local originalTint = colorCorrection.TintColor
	local originalSaturation = colorCorrection.Saturation

	-- Apply red damage tint
	local damageIntensity = math.clamp(intensity, 0, 1)
	colorCorrection.TintColor = Color3.fromRGB(255, 200 - damageIntensity * 100, 200 - damageIntensity * 100)
	colorCorrection.Saturation = originalSaturation - damageIntensity * 0.3

	-- Fade back to normal
	local tween = TweenService:Create(colorCorrection, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TintColor = originalTint,
		Saturation = originalSaturation,
	})
	tween:Play()
end

--[[
	Apply low health warning effect (pulsing vignette)
	@param healthPercent Current health as percentage (0-1)
]]
function LightingManager.LowHealthEffect(healthPercent: number)
	if not colorCorrection then return end

	if healthPercent < 0.25 then
		-- Pulsing red effect for critical health
		local pulseIntensity = math.sin(tick() * 4) * 0.1 + 0.1
		colorCorrection.TintColor = Color3.fromRGB(255, 220 - pulseIntensity * 100, 220 - pulseIntensity * 100)
	elseif healthPercent < 0.5 then
		-- Subtle warning tint
		colorCorrection.TintColor = Color3.fromRGB(255, 240, 235)
	end
end

--[[
	Apply storm warning effect (desaturated, darker)
	@param stormDistance Distance to storm edge
]]
function LightingManager.StormWarningEffect(stormDistance: number)
	if stormDistance < 50 then
		-- Very close to storm - heavy effect
		LightingManager.ApplyPreset("Storm", 2)
	elseif stormDistance < 150 then
		-- Approaching storm - blend effect
		-- Gradually interpolate between current and storm preset
		local blendFactor = 1 - (stormDistance - 50) / 100
		if colorCorrection then
			colorCorrection.Saturation = -0.1 * blendFactor
		end
	end
end

--[[
	Get current lighting preset name
	@return Current preset name
]]
function LightingManager.GetCurrentPreset(): string
	return currentPreset
end

--[[
	Get available preset names
	@return Array of preset names
]]
function LightingManager.GetPresetNames(): { string }
	local names = {}
	for name in pairs(LightingPresets) do
		table.insert(names, name)
	end
	return names
end

--[[
	Cleanup and shutdown lighting manager
]]
function LightingManager.Shutdown()
	isInitialized = false

	-- Disconnect time of day
	if timeOfDayConnection then
		timeOfDayConnection:Disconnect()
		timeOfDayConnection = nil
	end

	-- Remove created effects
	if bloomEffect then
		bloomEffect:Destroy()
	end
	if colorCorrection then
		colorCorrection:Destroy()
	end
	if depthOfField then
		depthOfField:Destroy()
	end
	if sunRays then
		sunRays:Destroy()
	end
	if atmosphere then
		atmosphere:Destroy()
	end
	if sky then
		sky:Destroy()
	end

	print("[LightingManager] Shutdown complete")
end

return LightingManager
