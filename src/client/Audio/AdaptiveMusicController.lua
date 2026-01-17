--!strict
--[[
	AdaptiveMusicController.lua
	===========================
	Client-side adaptive music system
	Manages layered music that responds to gameplay
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Events = require(ReplicatedStorage.Shared.Events)
local MusicData = require(ReplicatedStorage.Shared.MusicData)

local AdaptiveMusicController = {}

-- Types
type MusicTrack = MusicData.MusicTrack
type MusicLayer = MusicData.MusicLayer

-- State
local _player = Players.LocalPlayer
local isInitialized = false
local currentTrack: MusicTrack? = nil
local currentContext = "Lobby"
local currentIntensity = 1
local targetIntensity = 1
local layerSounds: { [string]: Sound } = {}
local layerTweens: { [string]: Tween } = {}
local musicFolder: Folder? = nil
local _musicEnabled = true
local masterVolume = 1

-- Constants
local INTENSITY_BLEND_RATE = 0.5 -- How fast intensity changes
local DANGER_CHECK_INTERVAL = 0.5

-- Signals
local onIntensityChanged = Instance.new("BindableEvent")
AdaptiveMusicController.OnIntensityChanged = onIntensityChanged.Event

-- Thread tracking for cleanup
local intensityThread: thread? = nil

--[[
	Initialize the adaptive music controller
]]
function AdaptiveMusicController.Initialize()
	if isInitialized then return end
	isInitialized = true

	print("[AdaptiveMusicController] Initializing...")

	-- Create music folder in SoundService
	musicFolder = Instance.new("Folder")
	musicFolder.Name = "AdaptiveMusic"
	musicFolder.Parent = SoundService

	-- Setup event listeners
	AdaptiveMusicController.SetupEventListeners()

	-- Start intensity update loop
	intensityThread = task.spawn(AdaptiveMusicController.IntensityUpdateLoop)

	-- Start in lobby context
	AdaptiveMusicController.SetContext("Lobby")

	print("[AdaptiveMusicController] Initialized")
end

--[[
	Setup event listeners
]]
function AdaptiveMusicController.SetupEventListeners()
	-- Game state changes
	Events.OnClientEvent("GameState", "StateChanged", function(data)
		local newState = data.newState

		if newState == "Lobby" then
			AdaptiveMusicController.SetContext("Lobby")
			AdaptiveMusicController.SetIntensity(2)
		elseif newState == "Loading" then
			AdaptiveMusicController.FadeOut(2)
		elseif newState == "Deploying" then
			AdaptiveMusicController.SetContext("Deployment")
			AdaptiveMusicController.SetIntensity(4)
		elseif newState == "Playing" then
			AdaptiveMusicController.SetContext("Exploration")
			AdaptiveMusicController.SetIntensity(2)
		elseif newState == "Ending" then
			return -- Victory/Defeat music handled by separate events
		end
	end)

	-- Combat events
	Events.OnClientEvent("Combat", "PlayerKilled", function(data)
		if data.killerId == _player.UserId then
			-- We got a kill, play stinger
			AdaptiveMusicController.PlayStinger("PlayerEliminated")
		end
	end)

	-- Storm events
	Events.OnClientEvent("Storm", "PlayerInStorm", function(data)
		if data.isInStorm then
			AdaptiveMusicController.SetContext("Storm")
			AdaptiveMusicController.SetIntensity(4)
		else
			AdaptiveMusicController.SetContext("Exploration")
		end
	end)

	-- Match result
	Events.OnClientEvent("Match", "Victory", function()
		AdaptiveMusicController.SetContext("Victory")
		AdaptiveMusicController.SetIntensity(5)
	end)

	Events.OnClientEvent("Match", "Defeat", function()
		AdaptiveMusicController.SetContext("Defeat")
		AdaptiveMusicController.SetIntensity(2)
	end)

	-- Dinosaur proximity
	Events.OnClientEvent("AI", "DinosaurNearby", function(data)
		if data.isNearby then
			AdaptiveMusicController.IncreaseIntensity(2)
			AdaptiveMusicController.PlayStinger("DinosaurNearby")
		end
	end)

	-- Boss events
	Events.OnClientEvent("Boss", "Spawned", function()
		AdaptiveMusicController.PlayStinger("BossSpawn")
		AdaptiveMusicController.SetIntensity(5)
	end)

	-- Placement events
	Events.OnClientEvent("Match", "Top10", function()
		AdaptiveMusicController.PlayStinger("Top10")
	end)
end

--[[
	Set music context (changes the track)
]]
function AdaptiveMusicController.SetContext(context: string)
	if currentContext == context and currentTrack then return end

	currentContext = context

	local track = MusicData.GetTrackForContext(context)
	if not track then
		print(`[AdaptiveMusicController] No track for context: {context}`)
		return
	end

	-- Crossfade to new track
	AdaptiveMusicController.TransitionToTrack(track)
end

--[[
	Transition to a new track
]]
function AdaptiveMusicController.TransitionToTrack(track: MusicTrack)
	-- Fade out current layers
	for _layerId, sound in pairs(layerSounds) do
		local tween = TweenService:Create(sound, TweenInfo.new(1.5), {
			Volume = 0,
		})
		tween:Play()
		tween.Completed:Connect(function()
			sound:Destroy()
		end)
	end

	-- Clear state
	layerSounds = {}
	layerTweens = {}
	currentTrack = track

	-- Create new layer sounds
	if not musicFolder then return end

	for _, layer in ipairs(track.layers) do
		local sound = Instance.new("Sound")
		sound.Name = layer.id
		sound.SoundId = layer.assetId
		sound.Volume = 0 -- Start silent
		sound.Looped = track.loopEnabled
		sound.Parent = musicFolder

		layerSounds[layer.id] = sound

		-- Start playing (but at 0 volume)
		sound:Play()
	end

	-- Apply current intensity
	AdaptiveMusicController.ApplyIntensity()

	print(`[AdaptiveMusicController] Transitioned to track: {track.name}`)
end

--[[
	Set target intensity (0-5)
]]
function AdaptiveMusicController.SetIntensity(level: number)
	targetIntensity = math.clamp(level, 0, 5)
end

--[[
	Increase intensity by amount
]]
function AdaptiveMusicController.IncreaseIntensity(amount: number)
	targetIntensity = math.clamp(targetIntensity + amount, 0, 5)
end

--[[
	Decrease intensity by amount
]]
function AdaptiveMusicController.DecreaseIntensity(amount: number)
	targetIntensity = math.clamp(targetIntensity - amount, 0, 5)
end

--[[
	Intensity update loop - smoothly transitions intensity
]]
function AdaptiveMusicController.IntensityUpdateLoop()
	while isInitialized do
		task.wait(DANGER_CHECK_INTERVAL)

		-- Smoothly blend toward target intensity
		if currentIntensity ~= targetIntensity then
			local diff = targetIntensity - currentIntensity
			local step = math.sign(diff) * math.min(math.abs(diff), INTENSITY_BLEND_RATE)
			currentIntensity = currentIntensity + step

			-- Round to nearest 0.5 for layer decisions
			local roundedIntensity = math.floor(currentIntensity + 0.5)
			AdaptiveMusicController.ApplyIntensity(roundedIntensity)
		end

		-- Natural intensity decay when not in combat
		if currentContext == "Exploration" and targetIntensity > 2 then
			targetIntensity = math.max(2, targetIntensity - 0.1)
		end
	end
end

--[[
	Apply intensity level to layers
]]
function AdaptiveMusicController.ApplyIntensity(overrideLevel: number?)
	local level = overrideLevel or math.floor(currentIntensity + 0.5)
	local intensityData = MusicData.GetIntensityLevel(level)

	if not currentTrack then return end

	-- Determine which layers should be active
	local activeLayers = intensityData.activeLayers
	local _transitionTime = intensityData.transitionTime

	for _, layer in ipairs(currentTrack.layers) do
		local sound = layerSounds[layer.id]
		if not sound then continue end

		local shouldBeActive = table.find(activeLayers, layer.id) ~= nil
		local targetVolume = shouldBeActive and (layer.volume * masterVolume) or 0

		-- Cancel existing tween
		if layerTweens[layer.id] then
			layerTweens[layer.id]:Cancel()
		end

		-- Create new tween
		local fadeTime = shouldBeActive and layer.fadeInTime or layer.fadeOutTime
		local tween = TweenService:Create(sound, TweenInfo.new(fadeTime), {
			Volume = targetVolume,
		})

		layerTweens[layer.id] = tween
		tween:Play()
	end

	onIntensityChanged:Fire(level, intensityData.name)
end

--[[
	Play a one-shot stinger
]]
function AdaptiveMusicController.PlayStinger(event: string)
	local stingerData = MusicData.GetStinger(event)
	if not stingerData then return end
	if not musicFolder then return end

	local sound = Instance.new("Sound")
	sound.Name = `Stinger_{event}`
	sound.SoundId = stingerData.assetId
	sound.Volume = stingerData.volume * masterVolume
	sound.Looped = false
	sound.Parent = musicFolder

	sound:Play()

	-- Auto cleanup
	task.delay(stingerData.duration + 1, function()
		if sound then
			sound:Destroy()
		end
	end)

	print(`[AdaptiveMusicController] Playing stinger: {event}`)
end

--[[
	Fade out all music
]]
function AdaptiveMusicController.FadeOut(duration: number?)
	local fadeTime = duration or 2

	for _layerId, sound in pairs(layerSounds) do
		-- Cancel existing tween
		if layerTweens[_layerId] then
			layerTweens[_layerId]:Cancel()
		end

		local tween = TweenService:Create(sound, TweenInfo.new(fadeTime), {
			Volume = 0,
		})

		layerTweens[_layerId] = tween
		tween:Play()
	end
end

--[[
	Fade in current track
]]
function AdaptiveMusicController.FadeIn(_duration: number?)
	AdaptiveMusicController.ApplyIntensity()
end

--[[
	Stop all music immediately
]]
function AdaptiveMusicController.Stop()
	for _, sound in pairs(layerSounds) do
		sound:Stop()
	end
end

--[[
	Set master volume
]]
function AdaptiveMusicController.SetVolume(volume: number)
	masterVolume = math.clamp(volume, 0, 1)
	AdaptiveMusicController.ApplyIntensity()
end

--[[
	Enable/disable music
]]
function AdaptiveMusicController.SetEnabled(enabled: boolean)
	_musicEnabled = enabled

	if enabled then
		AdaptiveMusicController.FadeIn()
	else
		AdaptiveMusicController.FadeOut()
	end
end

--[[
	Get current intensity
]]
function AdaptiveMusicController.GetIntensity(): number
	return currentIntensity
end

--[[
	Get current context
]]
function AdaptiveMusicController.GetContext(): string
	return currentContext
end

--[[
	Check if music is playing
]]
function AdaptiveMusicController.IsPlaying(): boolean
	for _, sound in pairs(layerSounds) do
		if sound.IsPlaying then
			return true
		end
	end
	return false
end

--[[
	Combat started (called by combat systems)
]]
function AdaptiveMusicController.OnCombatStarted()
	AdaptiveMusicController.SetIntensity(5)
end

--[[
	Combat ended
]]
function AdaptiveMusicController.OnCombatEnded()
	-- Gradually decrease intensity
	task.delay(3, function()
		if currentIntensity >= 4 then
			AdaptiveMusicController.SetIntensity(3)
		end
	end)

	task.delay(8, function()
		if currentIntensity >= 3 then
			AdaptiveMusicController.SetIntensity(2)
		end
	end)
end

--[[
	Low health warning
]]
function AdaptiveMusicController.OnLowHealth()
	AdaptiveMusicController.PlayStinger("LowHealth")
	AdaptiveMusicController.IncreaseIntensity(1)
end

--[[
	Shutdown and cleanup resources
]]
function AdaptiveMusicController.Shutdown()
	isInitialized = false

	-- Cancel intensity update thread
	if intensityThread then
		task.cancel(intensityThread)
		intensityThread = nil
	end

	-- Stop and destroy all sounds
	for _, sound in pairs(layerSounds) do
		sound:Stop()
		sound:Destroy()
	end
	layerSounds = {}
	layerTweens = {}

	-- Destroy music folder
	if musicFolder then
		musicFolder:Destroy()
		musicFolder = nil
	end

	-- Destroy BindableEvent
	onIntensityChanged:Destroy()

	print("[AdaptiveMusicController] Shutdown complete")
end

return AdaptiveMusicController
