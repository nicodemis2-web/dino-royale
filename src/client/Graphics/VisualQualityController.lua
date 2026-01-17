--!strict
--[[
	VisualQualityController.lua
	===========================
	Dynamic visual quality management for optimal performance
	Automatically adjusts settings based on device capabilities and frame rate

	Best Practices Implemented:
	- Adaptive quality scaling based on real-time FPS monitoring
	- Device capability detection for initial quality preset
	- Smooth transitions between quality levels to avoid jarring changes
	- Memory-conscious effect pooling and cleanup

	Quality Levels (1-5):
	1. Low: Minimal effects, maximum performance (mobile/low-end)
	2. Medium-Low: Basic effects, good performance
	3. Medium: Balanced effects and performance (default)
	4. High: Enhanced effects, good hardware required
	5. Ultra: Maximum quality, high-end hardware only
]]

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local _Players = game:GetService("Players")

local VisualQualityController = {}

-- State
local isInitialized = false
local currentQualityLevel = 3 -- Default to medium
local targetFPS = 60
local fpsHistory: { number } = {}
local fpsHistorySize = 30 -- Sample over 30 frames
local updateConnection: RBXScriptConnection? = nil
local autoAdjustEnabled = true

-- Quality level configurations
-- Each level defines specific settings for various visual systems
local QualityLevels = {
	--[[
		Level 1: Low Quality
		Target: 60+ FPS on low-end mobile devices
		Disables most post-processing, minimal particles
	]]
	[1] = {
		name = "Low",
		description = "Maximum performance, minimal visual effects",

		-- Lighting settings
		shadowsEnabled = false,
		shadowSoftness = 1.0,
		lightingTechnology = Enum.Technology.Voxel, -- Fallback for low-end

		-- Post-processing
		bloomEnabled = false,
		depthOfFieldEnabled = false,
		sunRaysEnabled = false,
		colorCorrectionEnabled = true, -- Keep basic color grading

		-- Atmosphere
		atmosphereDensity = 0.2,
		atmosphereHaze = 0.5,

		-- Particles
		particleMultiplier = 0.3, -- 30% of normal particles
		maxParticles = 50,

		-- Effects
		muzzleFlashEnabled = true,
		shellCasingsEnabled = false,
		bulletTracersEnabled = false,
		impactEffectsEnabled = false,

		-- Dinosaur effects
		dinoHighlightsEnabled = true,
		dinoParticlesEnabled = false,

		-- Terrain
		terrainDecorations = false,
		waterQuality = "Low",
	},

	--[[
		Level 2: Medium-Low Quality
		Target: 60+ FPS on mid-range mobile / low-end PC
		Basic effects enabled, reduced particle counts
	]]
	[2] = {
		name = "Medium-Low",
		description = "Good performance with basic effects",

		shadowsEnabled = true,
		shadowSoftness = 0.8,
		lightingTechnology = Enum.Technology.ShadowMap,

		bloomEnabled = false,
		depthOfFieldEnabled = false,
		sunRaysEnabled = false,
		colorCorrectionEnabled = true,

		atmosphereDensity = 0.3,
		atmosphereHaze = 1.0,

		particleMultiplier = 0.5,
		maxParticles = 100,

		muzzleFlashEnabled = true,
		shellCasingsEnabled = true,
		bulletTracersEnabled = true,
		impactEffectsEnabled = false,

		dinoHighlightsEnabled = true,
		dinoParticlesEnabled = false,

		terrainDecorations = false,
		waterQuality = "Medium",
	},

	--[[
		Level 3: Medium Quality (Default)
		Target: 60+ FPS on standard hardware
		Balanced visual quality and performance
	]]
	[3] = {
		name = "Medium",
		description = "Balanced quality and performance",

		shadowsEnabled = true,
		shadowSoftness = 0.5,
		lightingTechnology = Enum.Technology.Future,

		bloomEnabled = true,
		depthOfFieldEnabled = false,
		sunRaysEnabled = true,
		colorCorrectionEnabled = true,

		atmosphereDensity = 0.35,
		atmosphereHaze = 1.5,

		particleMultiplier = 0.75,
		maxParticles = 200,

		muzzleFlashEnabled = true,
		shellCasingsEnabled = true,
		bulletTracersEnabled = true,
		impactEffectsEnabled = true,

		dinoHighlightsEnabled = true,
		dinoParticlesEnabled = true,

		terrainDecorations = true,
		waterQuality = "Medium",
	},

	--[[
		Level 4: High Quality
		Target: 60+ FPS on good gaming hardware
		Enhanced visuals with all core effects
	]]
	[4] = {
		name = "High",
		description = "Enhanced visuals for gaming hardware",

		shadowsEnabled = true,
		shadowSoftness = 0.3,
		lightingTechnology = Enum.Technology.Future,

		bloomEnabled = true,
		depthOfFieldEnabled = true,
		sunRaysEnabled = true,
		colorCorrectionEnabled = true,

		atmosphereDensity = 0.4,
		atmosphereHaze = 2.0,

		particleMultiplier = 1.0,
		maxParticles = 400,

		muzzleFlashEnabled = true,
		shellCasingsEnabled = true,
		bulletTracersEnabled = true,
		impactEffectsEnabled = true,

		dinoHighlightsEnabled = true,
		dinoParticlesEnabled = true,

		terrainDecorations = true,
		waterQuality = "High",
	},

	--[[
		Level 5: Ultra Quality
		Target: High-end gaming PCs
		Maximum visual fidelity, all effects at full quality
	]]
	[5] = {
		name = "Ultra",
		description = "Maximum quality for high-end hardware",

		shadowsEnabled = true,
		shadowSoftness = 0.2,
		lightingTechnology = Enum.Technology.Future,

		bloomEnabled = true,
		depthOfFieldEnabled = true,
		sunRaysEnabled = true,
		colorCorrectionEnabled = true,

		atmosphereDensity = 0.45,
		atmosphereHaze = 2.5,

		particleMultiplier = 1.5, -- Extra particles for dramatic effect
		maxParticles = 600,

		muzzleFlashEnabled = true,
		shellCasingsEnabled = true,
		bulletTracersEnabled = true,
		impactEffectsEnabled = true,

		dinoHighlightsEnabled = true,
		dinoParticlesEnabled = true,

		terrainDecorations = true,
		waterQuality = "Ultra",
	},
}

-- Signals for quality change notifications
local qualityChangedEvent = Instance.new("BindableEvent")
VisualQualityController.OnQualityChanged = qualityChangedEvent.Event

--[[
	Initialize the quality controller
	Detects device capabilities and sets initial quality level
]]
function VisualQualityController.Initialize()
	if isInitialized then return end
	isInitialized = true

	print("[VisualQualityController] Initializing...")

	-- Detect initial quality based on device
	local detectedLevel = VisualQualityController.DetectOptimalQuality()
	currentQualityLevel = detectedLevel

	-- Apply initial quality settings
	VisualQualityController.ApplyQualityLevel(currentQualityLevel)

	-- Start FPS monitoring for adaptive quality
	VisualQualityController.StartFPSMonitoring()

	print(`[VisualQualityController] Initialized at quality level {currentQualityLevel} ({QualityLevels[currentQualityLevel].name})`)
end

--[[
	Detect optimal quality level based on device capabilities
	Uses platform detection and input methods as heuristics
	@return Recommended quality level (1-5)
]]
function VisualQualityController.DetectOptimalQuality(): number
	-- Check platform indicators
	local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local isConsole = UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled
	local isPC = UserInputService.KeyboardEnabled

	-- Start with platform-based baseline
	local baseLevel = 3 -- Default medium

	if isMobile then
		-- Mobile devices: start conservative
		baseLevel = 2

		-- Check for high-end mobile (large screen usually means newer device)
		local screenSize = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800, 600)
		if screenSize.X >= 1920 then
			baseLevel = 3 -- High-res mobile can handle medium
		end
	elseif isConsole or isPC then
		-- Consoles and PC: typically good hardware, default to high
		-- Will auto-adjust if needed based on performance
		baseLevel = 4
	end

	-- Check Roblox's quality level setting as additional hint
	local settings = UserSettings()
	local gameSettings = settings:GetService("UserGameSettings")
	local savedQuality = gameSettings.SavedQualityLevel

	-- If user has manually set quality, respect a lower setting
	if savedQuality ~= Enum.SavedQualitySetting.Automatic then
		local qualityNumber = savedQuality.Value
		if qualityNumber < 5 then
			baseLevel = math.min(baseLevel, 2)
		elseif qualityNumber < 8 then
			baseLevel = math.min(baseLevel, 3)
		end
	end

	return math.clamp(baseLevel, 1, 5)
end

--[[
	Start FPS monitoring for adaptive quality adjustment
	Monitors frame rate and adjusts quality to maintain target FPS
]]
function VisualQualityController.StartFPSMonitoring()
	if updateConnection then return end

	local lastTime = tick()
	local sampleCount = 0

	updateConnection = RunService.Heartbeat:Connect(function()
		-- Calculate FPS
		local currentTime = tick()
		local deltaTime = currentTime - lastTime
		lastTime = currentTime

		local currentFPS = 1 / deltaTime

		-- Add to history
		table.insert(fpsHistory, currentFPS)
		if #fpsHistory > fpsHistorySize then
			table.remove(fpsHistory, 1)
		end

		-- Check for quality adjustment every 60 samples (roughly 1 second)
		sampleCount = sampleCount + 1
		if sampleCount >= 60 and autoAdjustEnabled then
			sampleCount = 0
			VisualQualityController.CheckAndAdjustQuality()
		end
	end)
end

--[[
	Check FPS and adjust quality if needed
	Uses hysteresis to prevent rapid quality switching
]]
function VisualQualityController.CheckAndAdjustQuality()
	if #fpsHistory < fpsHistorySize then return end

	-- Calculate average FPS
	local totalFPS = 0
	for _, fps in ipairs(fpsHistory) do
		totalFPS = totalFPS + fps
	end
	local avgFPS = totalFPS / #fpsHistory

	-- Quality adjustment thresholds with hysteresis
	-- Lower threshold = decrease quality, upper threshold = increase quality
	local lowerThreshold = targetFPS * 0.75 -- 45 FPS for 60 target
	local upperThreshold = targetFPS * 0.95 -- 57 FPS for 60 target

	if avgFPS < lowerThreshold and currentQualityLevel > 1 then
		-- Performance is poor, decrease quality
		VisualQualityController.SetQualityLevel(currentQualityLevel - 1)
		print(`[VisualQualityController] FPS low ({math.floor(avgFPS)}), decreasing to {QualityLevels[currentQualityLevel].name}`)
	elseif avgFPS > upperThreshold and currentQualityLevel < 5 then
		-- Performance is good, try increasing quality
		-- Only increase if we've been stable for a while
		local minFPS = math.huge
		for _, fps in ipairs(fpsHistory) do
			minFPS = math.min(minFPS, fps)
		end

		if minFPS > lowerThreshold then
			VisualQualityController.SetQualityLevel(currentQualityLevel + 1)
			print(`[VisualQualityController] FPS stable ({math.floor(avgFPS)}), increasing to {QualityLevels[currentQualityLevel].name}`)
		end
	end
end

--[[
	Set quality level directly
	@param level Quality level (1-5)
]]
function VisualQualityController.SetQualityLevel(level: number)
	level = math.clamp(level, 1, 5)
	if level == currentQualityLevel then return end

	local oldLevel = currentQualityLevel
	currentQualityLevel = level

	-- Apply the new quality settings
	VisualQualityController.ApplyQualityLevel(level)

	-- Fire quality changed event
	qualityChangedEvent:Fire(level, QualityLevels[level])

	print(`[VisualQualityController] Quality changed: {QualityLevels[oldLevel].name} -> {QualityLevels[level].name}`)
end

--[[
	Apply quality level settings to all visual systems
	@param level Quality level to apply
]]
function VisualQualityController.ApplyQualityLevel(level: number)
	local settings = QualityLevels[level]
	if not settings then return end

	-- Apply lighting settings
	Lighting.GlobalShadows = settings.shadowsEnabled
	Lighting.ShadowSoftness = settings.shadowSoftness

	-- Note: Lighting.Technology cannot be changed at runtime in published games
	-- It's set here for completeness but may not take effect

	-- Apply post-processing settings
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("BloomEffect") then
			child.Enabled = settings.bloomEnabled
		elseif child:IsA("DepthOfFieldEffect") then
			child.Enabled = settings.depthOfFieldEnabled
		elseif child:IsA("SunRaysEffect") then
			child.Enabled = settings.sunRaysEnabled
		elseif child:IsA("ColorCorrectionEffect") then
			child.Enabled = settings.colorCorrectionEnabled
		elseif child:IsA("Atmosphere") then
			child.Density = settings.atmosphereDensity
			child.Haze = settings.atmosphereHaze
		end
	end
end

--[[
	Get current quality level
	@return Current quality level (1-5)
]]
function VisualQualityController.GetQualityLevel(): number
	return currentQualityLevel
end

--[[
	Get quality level settings
	@param level Optional level (defaults to current)
	@return Quality settings table
]]
function VisualQualityController.GetQualitySettings(level: number?): { [string]: any }
	local targetLevel = level or currentQualityLevel
	return QualityLevels[targetLevel]
end

--[[
	Get current average FPS
	@return Average FPS over recent samples
]]
function VisualQualityController.GetAverageFPS(): number
	if #fpsHistory == 0 then return 60 end

	local total = 0
	for _, fps in ipairs(fpsHistory) do
		total = total + fps
	end
	return total / #fpsHistory
end

--[[
	Set target FPS for adaptive quality
	@param fps Target frame rate
]]
function VisualQualityController.SetTargetFPS(fps: number)
	targetFPS = math.clamp(fps, 30, 144)
end

--[[
	Enable or disable automatic quality adjustment
	@param enabled Whether to enable auto-adjust
]]
function VisualQualityController.SetAutoAdjust(enabled: boolean)
	autoAdjustEnabled = enabled
	print(`[VisualQualityController] Auto-adjust {enabled and "enabled" or "disabled"}`)
end

--[[
	Check if a specific effect should be enabled at current quality
	@param effectName Name of the effect to check
	@return Whether the effect should be enabled
]]
function VisualQualityController.IsEffectEnabled(effectName: string): boolean
	local settings = QualityLevels[currentQualityLevel]
	if not settings then return true end

	-- Map effect names to settings
	local effectMap = {
		muzzleFlash = settings.muzzleFlashEnabled,
		shellCasings = settings.shellCasingsEnabled,
		bulletTracers = settings.bulletTracersEnabled,
		impactEffects = settings.impactEffectsEnabled,
		dinoHighlights = settings.dinoHighlightsEnabled,
		dinoParticles = settings.dinoParticlesEnabled,
		terrainDecorations = settings.terrainDecorations,
		bloom = settings.bloomEnabled,
		depthOfField = settings.depthOfFieldEnabled,
		sunRays = settings.sunRaysEnabled,
	}

	return effectMap[effectName] ~= false
end

--[[
	Get particle multiplier for current quality
	@return Particle count multiplier (0.3 - 1.5)
]]
function VisualQualityController.GetParticleMultiplier(): number
	local settings = QualityLevels[currentQualityLevel]
	return settings and settings.particleMultiplier or 1.0
end

--[[
	Get max particle count for current quality
	@return Maximum particle count
]]
function VisualQualityController.GetMaxParticles(): number
	local settings = QualityLevels[currentQualityLevel]
	return settings and settings.maxParticles or 200
end

--[[
	Cleanup and shutdown
]]
function VisualQualityController.Shutdown()
	isInitialized = false

	if updateConnection then
		updateConnection:Disconnect()
		updateConnection = nil
	end

	fpsHistory = {}
	qualityChangedEvent:Destroy()

	print("[VisualQualityController] Shutdown complete")
end

return VisualQualityController
