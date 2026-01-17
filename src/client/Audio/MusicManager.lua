--!strict
--[[
	MusicManager.lua
	================
	Manages background music and ambient audio
	Handles transitions, layering, and dynamic music
]]

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Events = require(game.ReplicatedStorage.Shared.Events)

local MusicManager = {}

-- Music tracks
local MusicTracks = {
	-- Main menu/lobby
	Lobby = {
		id = "rbxassetid://0",
		volume = 0.5,
		looped = true,
	},

	-- Pre-game/deployment
	Deployment = {
		id = "rbxassetid://0",
		volume = 0.4,
		looped = true,
	},

	-- In-game - calm exploration
	Exploration = {
		id = "rbxassetid://0",
		volume = 0.3,
		looped = true,
	},

	-- In-game - danger/combat
	Combat = {
		id = "rbxassetid://0",
		volume = 0.5,
		looped = true,
	},

	-- Final circle intensity
	FinalCircle = {
		id = "rbxassetid://0",
		volume = 0.6,
		looped = true,
	},

	-- Victory
	Victory = {
		id = "rbxassetid://0",
		volume = 0.7,
		looped = false,
	},

	-- Defeat
	Defeat = {
		id = "rbxassetid://0",
		volume = 0.6,
		looped = false,
	},

	-- Boss encounter
	BossEncounter = {
		id = "rbxassetid://0",
		volume = 0.6,
		looped = true,
	},
}

-- Ambient tracks
local AmbientTracks = {
	-- Nature ambience
	Forest = {
		id = "rbxassetid://0",
		volume = 0.3,
		looped = true,
	},

	Beach = {
		id = "rbxassetid://0",
		volume = 0.3,
		looped = true,
	},

	Cave = {
		id = "rbxassetid://0",
		volume = 0.25,
		looped = true,
	},

	-- Weather
	Rain = {
		id = "rbxassetid://0",
		volume = 0.4,
		looped = true,
	},

	Wind = {
		id = "rbxassetid://0",
		volume = 0.2,
		looped = true,
	},

	-- Storm ambience
	Storm = {
		id = "rbxassetid://0",
		volume = 0.5,
		looped = true,
	},
}

-- State
local currentMusic: Sound? = nil
local currentMusicName: string? = nil
local currentAmbient: Sound? = nil
local currentAmbientName: string? = nil

local musicVolume = 0.7
local ambientVolume = 0.5
local isMusicEnabled = true
local isAmbientEnabled = true

local musicSoundGroup: SoundGroup? = nil
local ambientSoundGroup: SoundGroup? = nil

local isInitialized = false
local connections = {} :: { RBXScriptConnection }

-- Combat intensity tracking
local combatIntensity = 0
local combatDecayRate = 0.1
local combatThreshold = 0.3 -- Switch to combat music above this

--[[
	Create sound groups
]]
local function createSoundGroups()
	-- Music group
	musicSoundGroup = Instance.new("SoundGroup")
	musicSoundGroup.Name = "Music"
	musicSoundGroup.Volume = musicVolume
	musicSoundGroup.Parent = SoundService

	-- Ambient group
	ambientSoundGroup = Instance.new("SoundGroup")
	ambientSoundGroup.Name = "Ambient"
	ambientSoundGroup.Volume = ambientVolume
	ambientSoundGroup.Parent = SoundService
end

--[[
	Create a sound from track definition
]]
local function createTrackSound(trackDef: { id: string, volume: number, looped: boolean }, isMusic: boolean): Sound
	local sound = Instance.new("Sound")
	sound.SoundId = trackDef.id
	sound.Volume = trackDef.volume
	sound.Looped = trackDef.looped
	sound.Parent = SoundService

	if isMusic and musicSoundGroup then
		sound.SoundGroup = musicSoundGroup
	elseif not isMusic and ambientSoundGroup then
		sound.SoundGroup = ambientSoundGroup
	end

	return sound
end

--[[
	Crossfade between two sounds
]]
local function crossfade(fromSound: Sound?, toSound: Sound, _duration: number)
	local fadeTime = duration or 1.0

	-- Start new sound at 0 volume
	local targetVolume = toSound.Volume
	toSound.Volume = 0
	toSound:Play()

	-- Fade in new sound
	TweenService:Create(toSound, TweenInfo.new(fadeTime), {
		Volume = targetVolume,
	}):Play()

	-- Fade out old sound
	if fromSound and fromSound.IsPlaying then
		TweenService:Create(fromSound, TweenInfo.new(fadeTime), {
			Volume = 0,
		}):Play()

		task.delay(fadeTime, function()
			fromSound:Stop()
			fromSound:Destroy()
		end)
	end
end

--[[
	Play a music track
	@param trackName Name of track from MusicTracks
	@param fadeTime Crossfade duration
]]
function MusicManager.PlayMusic(trackName: string, fadeTime: number?)
	if not isInitialized or not isMusicEnabled then
		return
	end

	-- Same track already playing
	if currentMusicName == trackName and currentMusic and currentMusic.IsPlaying then
		return
	end

	local track = MusicTracks[trackName]
	if not track then
		warn(`[MusicManager] Unknown track: {trackName}`)
		return
	end

	local newMusic = createTrackSound(track, true)
	crossfade(currentMusic, newMusic, fadeTime or 1.0)

	currentMusic = newMusic
	currentMusicName = trackName
end

--[[
	Stop current music
	@param fadeTime Fade out duration
]]
function MusicManager.StopMusic(fadeTime: number?)
	if not currentMusic then
		return
	end

	local fade = fadeTime or 1.0

	TweenService:Create(currentMusic, TweenInfo.new(fade), {
		Volume = 0,
	}):Play()

	local musicToStop = currentMusic
	task.delay(fade, function()
		musicToStop:Stop()
		musicToStop:Destroy()
	end)

	currentMusic = nil
	currentMusicName = nil
end

--[[
	Play ambient track
	@param trackName Name of track from AmbientTracks
	@param fadeTime Crossfade duration
]]
function MusicManager.PlayAmbient(trackName: string, fadeTime: number?)
	if not isInitialized or not isAmbientEnabled then
		return
	end

	-- Same ambient already playing
	if currentAmbientName == trackName and currentAmbient and currentAmbient.IsPlaying then
		return
	end

	local track = AmbientTracks[trackName]
	if not track then
		warn(`[MusicManager] Unknown ambient: {trackName}`)
		return
	end

	local newAmbient = createTrackSound(track, false)
	crossfade(currentAmbient, newAmbient, fadeTime or 2.0)

	currentAmbient = newAmbient
	currentAmbientName = trackName
end

--[[
	Stop ambient track
	@param fadeTime Fade out duration
]]
function MusicManager.StopAmbient(fadeTime: number?)
	if not currentAmbient then
		return
	end

	local fade = fadeTime or 2.0

	TweenService:Create(currentAmbient, TweenInfo.new(fade), {
		Volume = 0,
	}):Play()

	local ambientToStop = currentAmbient
	task.delay(fade, function()
		ambientToStop:Stop()
		ambientToStop:Destroy()
	end)

	currentAmbient = nil
	currentAmbientName = nil
end

--[[
	Add combat intensity
	@param amount Amount to add (0-1)
]]
function MusicManager.AddCombatIntensity(amount: number)
	combatIntensity = math.clamp(combatIntensity + amount, 0, 1)
end

--[[
	Update combat music based on intensity
]]
local function updateCombatMusic(dt: number)
	-- Decay intensity over time
	combatIntensity = math.max(0, combatIntensity - combatDecayRate * dt)

	-- Check for music transition
	local isInCombat = combatIntensity > combatThreshold

	if isInCombat then
		if currentMusicName == "Exploration" then
			MusicManager.PlayMusic("Combat", 0.5)
		end
	else
		if currentMusicName == "Combat" then
			MusicManager.PlayMusic("Exploration", 2.0)
		end
	end
end

--[[
	Set music volume
]]
function MusicManager.SetMusicVolume(volume: number)
	musicVolume = math.clamp(volume, 0, 1)
	if musicSoundGroup then
		musicSoundGroup.Volume = musicVolume
	end
end

--[[
	Set ambient volume
]]
function MusicManager.SetAmbientVolume(volume: number)
	ambientVolume = math.clamp(volume, 0, 1)
	if ambientSoundGroup then
		ambientSoundGroup.Volume = ambientVolume
	end
end

--[[
	Enable/disable music
]]
function MusicManager.SetMusicEnabled(enabled: boolean)
	isMusicEnabled = enabled
	if not enabled then
		MusicManager.StopMusic(0.5)
	end
end

--[[
	Enable/disable ambient
]]
function MusicManager.SetAmbientEnabled(enabled: boolean)
	isAmbientEnabled = enabled
	if not enabled then
		MusicManager.StopAmbient(0.5)
	end
end

--[[
	Handle game state changes
]]
local function onGameStateChanged(newState: string)
	if newState == "Lobby" then
		MusicManager.PlayMusic("Lobby")
		MusicManager.PlayAmbient("Forest")
	elseif newState == "Loading" then
		return -- Keep lobby music playing
	elseif newState == "Deploying" then
		MusicManager.PlayMusic("Deployment")
	elseif newState == "Playing" then
		MusicManager.PlayMusic("Exploration")
	elseif newState == "Ending" then
		return -- Victory/Defeat music handled by separate events
	end
end

--[[
	Setup event listeners
]]
local function setupEvents()
	-- Game state changes
	local stateConn = Events.OnClientEvent("GameState", "StateChanged", function(data)
		onGameStateChanged(data.newState)
	end)
	table.insert(connections, stateConn)

	-- Combat events
	local combatConn = Events.OnClientEvent("Combat", "DamageTaken", function()
		MusicManager.AddCombatIntensity(0.3)
	end)
	table.insert(connections, combatConn)

	local killConn = Events.OnClientEvent("Combat", "HitConfirm", function()
		MusicManager.AddCombatIntensity(0.2)
	end)
	table.insert(connections, killConn)

	-- Boss events
	local bossConn = Events.OnClientEvent("Dinosaur", "BossSpawned", function()
		MusicManager.PlayMusic("BossEncounter", 1.0)
	end)
	table.insert(connections, bossConn)

	local bossKillConn = Events.OnClientEvent("Dinosaur", "BossKilled", function()
		MusicManager.PlayMusic("Exploration", 2.0)
	end)
	table.insert(connections, bossKillConn)

	-- Match end
	local victoryConn = Events.OnClientEvent("GameState", "MatchEnd", function(data)
		if data.isWinner then
			MusicManager.PlayMusic("Victory", 0.5)
		else
			MusicManager.PlayMusic("Defeat", 0.5)
		end
	end)
	table.insert(connections, victoryConn)

	-- Storm proximity
	local stormConn = Events.OnClientEvent("Storm", "InStorm", function(data)
		if data.inStorm then
			MusicManager.PlayAmbient("Storm", 1.0)
		else
			MusicManager.PlayAmbient("Forest", 2.0)
		end
	end)
	table.insert(connections, stormConn)

	-- Final circle
	local circleConn = Events.OnClientEvent("Storm", "FinalCircle", function()
		MusicManager.PlayMusic("FinalCircle", 1.0)
	end)
	table.insert(connections, circleConn)
end

--[[
	Setup update loop
]]
local function setupUpdateLoop()
	local updateConn = RunService.Heartbeat:Connect(function(dt)
		updateCombatMusic(dt)
	end)
	table.insert(connections, updateConn)
end

--[[
	Initialize the music manager
]]
function MusicManager.Initialize()
	if isInitialized then
		return
	end

	createSoundGroups()
	setupEvents()
	setupUpdateLoop()

	-- Start with lobby music
	MusicManager.PlayMusic("Lobby")
	MusicManager.PlayAmbient("Forest")

	isInitialized = true
	print("[MusicManager] Initialized")
end

--[[
	Cleanup
]]
function MusicManager.Cleanup()
	isInitialized = false

	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	connections = {}

	MusicManager.StopMusic(0)
	MusicManager.StopAmbient(0)

	if musicSoundGroup then
		musicSoundGroup:Destroy()
		musicSoundGroup = nil
	end

	if ambientSoundGroup then
		ambientSoundGroup:Destroy()
		ambientSoundGroup = nil
	end
end

return MusicManager
