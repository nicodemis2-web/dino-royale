--!strict
--[[
	AudioController.lua
	==================
	Main audio controller that coordinates SoundManager and MusicManager
	Handles settings persistence and global audio controls
]]

local Players = game:GetService("Players")

local SoundManager = require(script.Parent.SoundManager)
local MusicManager = require(script.Parent.MusicManager)
local AdaptiveMusicController = require(script.Parent.AdaptiveMusicController)

local AudioController = {}

-- Local player
local localPlayer = Players.LocalPlayer

-- Settings (would be loaded from data store)
local settings = {
	masterVolume = 1.0,
	musicVolume = 0.7,
	sfxVolume = 0.8,
	ambientVolume = 0.5,
	musicEnabled = true,
	sfxEnabled = true,
}

-- State
local isInitialized = false

--[[
	Load audio settings
]]
local function loadSettings()
	-- In a real implementation, load from data store
	-- For now, use defaults
end

--[[
	Save audio settings
]]
local function saveSettings()
	-- In a real implementation, save to data store
end

--[[
	Apply volume settings to managers
]]
local function applySettings()
	SoundManager.SetMasterVolume(settings.masterVolume)
	SoundManager.SetVolume("SFX", settings.sfxVolume)
	SoundManager.SetVolume("Weapons", settings.sfxVolume)
	SoundManager.SetVolume("Vehicles", settings.sfxVolume * 0.9)
	SoundManager.SetVolume("Dinosaurs", settings.sfxVolume)

	MusicManager.SetMusicVolume(settings.musicVolume)
	MusicManager.SetAmbientVolume(settings.ambientVolume)
	MusicManager.SetMusicEnabled(settings.musicEnabled)
end

--[[
	Set master volume
	@param volume Volume (0-1)
]]
function AudioController.SetMasterVolume(volume: number)
	settings.masterVolume = math.clamp(volume, 0, 1)
	SoundManager.SetMasterVolume(settings.masterVolume)
	saveSettings()
end

--[[
	Get master volume
]]
function AudioController.GetMasterVolume(): number
	return settings.masterVolume
end

--[[
	Set music volume
	@param volume Volume (0-1)
]]
function AudioController.SetMusicVolume(volume: number)
	settings.musicVolume = math.clamp(volume, 0, 1)
	MusicManager.SetMusicVolume(settings.musicVolume)
	saveSettings()
end

--[[
	Get music volume
]]
function AudioController.GetMusicVolume(): number
	return settings.musicVolume
end

--[[
	Set SFX volume
	@param volume Volume (0-1)
]]
function AudioController.SetSFXVolume(volume: number)
	settings.sfxVolume = math.clamp(volume, 0, 1)
	SoundManager.SetVolume("SFX", settings.sfxVolume)
	SoundManager.SetVolume("Weapons", settings.sfxVolume)
	SoundManager.SetVolume("Vehicles", settings.sfxVolume * 0.9)
	SoundManager.SetVolume("Dinosaurs", settings.sfxVolume)
	saveSettings()
end

--[[
	Get SFX volume
]]
function AudioController.GetSFXVolume(): number
	return settings.sfxVolume
end

--[[
	Set ambient volume
	@param volume Volume (0-1)
]]
function AudioController.SetAmbientVolume(volume: number)
	settings.ambientVolume = math.clamp(volume, 0, 1)
	MusicManager.SetAmbientVolume(settings.ambientVolume)
	saveSettings()
end

--[[
	Get ambient volume
]]
function AudioController.GetAmbientVolume(): number
	return settings.ambientVolume
end

--[[
	Enable/disable music
]]
function AudioController.SetMusicEnabled(enabled: boolean)
	settings.musicEnabled = enabled
	MusicManager.SetMusicEnabled(enabled)
	saveSettings()
end

--[[
	Is music enabled
]]
function AudioController.IsMusicEnabled(): boolean
	return settings.musicEnabled
end

--[[
	Enable/disable all SFX
]]
function AudioController.SetSFXEnabled(enabled: boolean)
	settings.sfxEnabled = enabled
	if enabled then
		SoundManager.SetVolume("SFX", settings.sfxVolume)
	else
		SoundManager.SetVolume("SFX", 0)
	end
	saveSettings()
end

--[[
	Is SFX enabled
]]
function AudioController.IsSFXEnabled(): boolean
	return settings.sfxEnabled
end

--[[
	Play a UI sound
	@param soundName Sound name
]]
function AudioController.PlayUISound(soundName: string)
	if not settings.sfxEnabled then
		return
	end
	SoundManager.PlayUI(soundName)
end

--[[
	Play a 3D sound effect
	@param category Sound category
	@param soundName Sound name
	@param position World position
]]
function AudioController.PlaySound3D(category: string, soundName: string, position: Vector3)
	if not settings.sfxEnabled then
		return
	end
	SoundManager.Play3D(category, soundName, position)
end

--[[
	Get all current settings
]]
function AudioController.GetSettings(): { [string]: any }
	return {
		masterVolume = settings.masterVolume,
		musicVolume = settings.musicVolume,
		sfxVolume = settings.sfxVolume,
		ambientVolume = settings.ambientVolume,
		musicEnabled = settings.musicEnabled,
		sfxEnabled = settings.sfxEnabled,
	}
end

--[[
	Set all settings at once
]]
function AudioController.SetSettings(newSettings: { [string]: any })
	if newSettings.masterVolume then
		settings.masterVolume = math.clamp(newSettings.masterVolume, 0, 1)
	end
	if newSettings.musicVolume then
		settings.musicVolume = math.clamp(newSettings.musicVolume, 0, 1)
	end
	if newSettings.sfxVolume then
		settings.sfxVolume = math.clamp(newSettings.sfxVolume, 0, 1)
	end
	if newSettings.ambientVolume then
		settings.ambientVolume = math.clamp(newSettings.ambientVolume, 0, 1)
	end
	if newSettings.musicEnabled ~= nil then
		settings.musicEnabled = newSettings.musicEnabled
	end
	if newSettings.sfxEnabled ~= nil then
		settings.sfxEnabled = newSettings.sfxEnabled
	end

	applySettings()
	saveSettings()
end

--[[
	Mute all audio
]]
function AudioController.MuteAll()
	SoundManager.SetMasterVolume(0)
	MusicManager.SetMusicVolume(0)
	MusicManager.SetAmbientVolume(0)
end

--[[
	Unmute all audio (restore to settings)
]]
function AudioController.UnmuteAll()
	applySettings()
end

--[[
	Initialize the audio controller
]]
function AudioController.Initialize()
	if isInitialized then
		return
	end

	loadSettings()

	SoundManager.Initialize()
	MusicManager.Initialize()
	AdaptiveMusicController.Initialize()

	applySettings()

	isInitialized = true
	print("[AudioController] Initialized")
end

--[[
	Cleanup
]]
function AudioController.Cleanup()
	isInitialized = false

	SoundManager.Cleanup()
	MusicManager.Cleanup()
end

--[[
	Get the adaptive music controller for direct access
]]
function AudioController.GetAdaptiveMusicController()
	return AdaptiveMusicController
end

--[[
	Set adaptive music intensity
]]
function AudioController.SetMusicIntensity(level: number)
	AdaptiveMusicController.SetIntensity(level)
end

--[[
	Notify combat started (for adaptive music)
]]
function AudioController.OnCombatStarted()
	AdaptiveMusicController.OnCombatStarted()
end

--[[
	Notify combat ended (for adaptive music)
]]
function AudioController.OnCombatEnded()
	AdaptiveMusicController.OnCombatEnded()
end

return AudioController
