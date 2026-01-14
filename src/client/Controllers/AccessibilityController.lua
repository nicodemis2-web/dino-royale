--!strict
--[[
	AccessibilityController.lua
	===========================
	Client-side accessibility settings management
	Based on GDD Section 9.3: Accessibility Options
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")

local Events = require(ReplicatedStorage.Shared.Events)
local AccessibilityData = require(ReplicatedStorage.Shared.AccessibilityData)

local AccessibilityController = {}

-- State
local player = Players.LocalPlayer
local currentSettings: AccessibilityData.AccessibilitySettings = AccessibilityData.Defaults
local isInitialized = false

-- Signals
local onSettingChanged = Instance.new("BindableEvent")
AccessibilityController.OnSettingChanged = onSettingChanged.Event

--[[
	Initialize the accessibility controller
]]
function AccessibilityController.Initialize()
	if isInitialized then return end
	isInitialized = true

	print("[AccessibilityController] Initializing...")

	-- Load saved settings
	AccessibilityController.LoadSettings()

	-- Setup event listeners
	AccessibilityController.SetupEventListeners()

	-- Apply current settings
	AccessibilityController.ApplyAllSettings()

	print("[AccessibilityController] Initialized")
end

--[[
	Setup event listeners
]]
function AccessibilityController.SetupEventListeners()
	Events.OnClientEvent("Accessibility", function(action, data)
		if action == "SettingsLoaded" then
			currentSettings = AccessibilityData.Validate(data.settings)
			AccessibilityController.ApplyAllSettings()
		end
	end)
end

--[[
	Load settings from local storage
]]
function AccessibilityController.LoadSettings()
	-- Try to load from local storage (plugin data)
	local success, savedData = pcall(function()
		-- In a real implementation, this would use plugin:GetSetting or DataStore
		return nil
	end)

	if success and savedData then
		currentSettings = AccessibilityData.Validate(savedData)
	else
		currentSettings = AccessibilityData.Defaults
	end

	-- Request settings from server (for persistence across devices)
	Events.FireServer("Accessibility", "RequestSettings", {})
end

--[[
	Save settings
]]
function AccessibilityController.SaveSettings()
	-- Save locally
	pcall(function()
		-- In a real implementation, this would use plugin:SetSetting
	end)

	-- Save to server for cross-device sync
	Events.FireServer("Accessibility", "SaveSettings", {
		settings = currentSettings,
	})
end

--[[
	Apply all current settings
]]
function AccessibilityController.ApplyAllSettings()
	AccessibilityController.ApplyVisualSettings()
	AccessibilityController.ApplyAudioSettings()
	AccessibilityController.ApplyControlSettings()
end

--[[
	Apply visual accessibility settings
]]
function AccessibilityController.ApplyVisualSettings()
	-- Apply colorblind mode colors (broadcast to other systems)
	onSettingChanged:Fire("colorblindMode", currentSettings.colorblindMode)

	-- High contrast UI
	onSettingChanged:Fire("highContrastUI", currentSettings.highContrastUI)

	-- Reduced motion
	onSettingChanged:Fire("reducedMotion", currentSettings.reducedMotion)

	-- Screen shake
	onSettingChanged:Fire("screenShakeIntensity", currentSettings.screenShakeIntensity)

	-- Subtitles
	onSettingChanged:Fire("subtitlesEnabled", currentSettings.subtitlesEnabled)
	onSettingChanged:Fire("subtitleSize", currentSettings.subtitleSize)
	onSettingChanged:Fire("subtitleBackground", currentSettings.subtitleBackground)

	-- UI Scale
	onSettingChanged:Fire("uiScale", currentSettings.uiScale)
end

--[[
	Apply audio settings
]]
function AccessibilityController.ApplyAudioSettings()
	-- Set sound group volumes
	pcall(function()
		local masterGroup = SoundService:FindFirstChild("Master")
		if masterGroup and masterGroup:IsA("SoundGroup") then
			masterGroup.Volume = currentSettings.masterVolume
		end

		local musicGroup = SoundService:FindFirstChild("Music")
		if musicGroup and musicGroup:IsA("SoundGroup") then
			musicGroup.Volume = currentSettings.musicVolume
		end

		local sfxGroup = SoundService:FindFirstChild("SFX")
		if sfxGroup and sfxGroup:IsA("SoundGroup") then
			sfxGroup.Volume = currentSettings.sfxVolume
		end

		local voiceGroup = SoundService:FindFirstChild("Voice")
		if voiceGroup and voiceGroup:IsA("SoundGroup") then
			voiceGroup.Volume = currentSettings.voiceVolume
		end
	end)

	-- Mono audio (broadcast to audio controller)
	onSettingChanged:Fire("monoAudio", currentSettings.monoAudio)

	-- Visual sound indicators
	onSettingChanged:Fire("visualSoundIndicators", currentSettings.visualSoundIndicators)
end

--[[
	Apply control settings
]]
function AccessibilityController.ApplyControlSettings()
	-- Mouse sensitivity
	UserInputService.MouseDeltaSensitivity = currentSettings.mouseSensitivity * 2

	-- Broadcast control settings
	onSettingChanged:Fire("aimAssist", currentSettings.aimAssist)
	onSettingChanged:Fire("autoSprint", currentSettings.autoSprint)
	onSettingChanged:Fire("toggleCrouch", currentSettings.toggleCrouch)
	onSettingChanged:Fire("toggleAim", currentSettings.toggleAim)
	onSettingChanged:Fire("invertY", currentSettings.invertY)
	onSettingChanged:Fire("controllerVibration", currentSettings.controllerVibration)

	-- Gameplay assists
	onSettingChanged:Fire("simplifiedCombat", currentSettings.simplifiedCombat)
	onSettingChanged:Fire("extendedTimers", currentSettings.extendedTimers)
	onSettingChanged:Fire("autoPickupItems", currentSettings.autoPickupItems)
	onSettingChanged:Fire("pingHighlight", currentSettings.pingHighlight)
end

--[[
	Get a specific setting
]]
function AccessibilityController.GetSetting(key: string): any
	return currentSettings[key]
end

--[[
	Set a specific setting
]]
function AccessibilityController.SetSetting(key: string, value: any)
	if currentSettings[key] == nil then
		warn(`[AccessibilityController] Unknown setting: {key}`)
		return
	end

	local oldValue = currentSettings[key]
	currentSettings[key] = value

	-- Apply the specific setting
	if key == "masterVolume" or key == "musicVolume" or key == "sfxVolume" or key == "voiceVolume" then
		AccessibilityController.ApplyAudioSettings()
	elseif key == "mouseSensitivity" then
		UserInputService.MouseDeltaSensitivity = value * 2
	else
		onSettingChanged:Fire(key, value)
	end

	-- Auto-save
	AccessibilityController.SaveSettings()

	print(`[AccessibilityController] {key}: {oldValue} -> {value}`)
end

--[[
	Get all current settings
]]
function AccessibilityController.GetSettings(): AccessibilityData.AccessibilitySettings
	return currentSettings
end

--[[
	Reset settings to defaults
]]
function AccessibilityController.ResetToDefaults()
	currentSettings = table.clone(AccessibilityData.Defaults)
	AccessibilityController.ApplyAllSettings()
	AccessibilityController.SaveSettings()
	print("[AccessibilityController] Reset to defaults")
end

--[[
	Get color with colorblind correction
]]
function AccessibilityController.GetColor(colorKey: string): Color3
	return AccessibilityData.GetColor(colorKey, currentSettings.colorblindMode)
end

--[[
	Check if reduced motion is enabled
]]
function AccessibilityController.IsReducedMotion(): boolean
	return currentSettings.reducedMotion
end

--[[
	Get screen shake multiplier
]]
function AccessibilityController.GetScreenShakeMultiplier(): number
	return currentSettings.screenShakeIntensity
end

--[[
	Check if subtitles are enabled
]]
function AccessibilityController.AreSubtitlesEnabled(): boolean
	return currentSettings.subtitlesEnabled
end

--[[
	Get subtitle text size
]]
function AccessibilityController.GetSubtitleSize(): number
	return AccessibilityData.GetSubtitleSize(currentSettings.subtitleSize)
end

--[[
	Check if visual sound indicators are enabled
]]
function AccessibilityController.ShowVisualSoundIndicators(): boolean
	return currentSettings.visualSoundIndicators
end

--[[
	Check if auto pickup is enabled
]]
function AccessibilityController.IsAutoPickupEnabled(): boolean
	return currentSettings.autoPickupItems
end

--[[
	Check if aim assist is enabled
]]
function AccessibilityController.IsAimAssistEnabled(): boolean
	return currentSettings.aimAssist
end

--[[
	Get UI scale
]]
function AccessibilityController.GetUIScale(): number
	return currentSettings.uiScale
end

return AccessibilityController
