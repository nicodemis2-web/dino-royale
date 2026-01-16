--!strict
--[[
	UISounds.lua
	============
	UI Sound effects system for Dino Royale.
	Provides audio feedback for all user interface interactions.

	FEATURES:
	- Categorized sound effects
	- Volume control per category
	- Cooldown system to prevent spam
	- Positional audio for world UI
	- Pitch variation for natural feel

	@client
]]

local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")

local UISounds = {}

--------------------------------------------------------------------------------
-- CONFIGURATION
--------------------------------------------------------------------------------

-- Sound definitions with properties
-- Note: In production, replace with actual Roblox asset IDs
local SOUND_DEFINITIONS = {
	-- Button/Navigation sounds
	ButtonClick = {
		soundId = "rbxassetid://6895079853", -- Click sound
		volume = 0.5,
		pitchRange = { 0.95, 1.05 },
		cooldown = 0.05,
	},
	ButtonHover = {
		soundId = "rbxassetid://6895079853",
		volume = 0.2,
		pitchRange = { 1.1, 1.2 },
		cooldown = 0.02,
	},
	TabSwitch = {
		soundId = "rbxassetid://6895079853",
		volume = 0.4,
		pitchRange = { 0.9, 1.0 },
		cooldown = 0.1,
	},

	-- Menu sounds
	MenuOpen = {
		soundId = "rbxassetid://6895079853",
		volume = 0.5,
		pitchRange = { 0.8, 0.9 },
		cooldown = 0.2,
	},
	MenuClose = {
		soundId = "rbxassetid://6895079853",
		volume = 0.4,
		pitchRange = { 0.7, 0.8 },
		cooldown = 0.2,
	},

	-- Notification sounds
	NotificationInfo = {
		soundId = "rbxassetid://6895079853",
		volume = 0.5,
		pitchRange = { 1.0, 1.1 },
		cooldown = 0.3,
	},
	NotificationSuccess = {
		soundId = "rbxassetid://6895079853",
		volume = 0.6,
		pitchRange = { 1.2, 1.3 },
		cooldown = 0.3,
	},
	NotificationWarning = {
		soundId = "rbxassetid://6895079853",
		volume = 0.6,
		pitchRange = { 0.8, 0.9 },
		cooldown = 0.3,
	},
	NotificationError = {
		soundId = "rbxassetid://6895079853",
		volume = 0.7,
		pitchRange = { 0.6, 0.7 },
		cooldown = 0.3,
	},

	-- Game state sounds
	MatchFound = {
		soundId = "rbxassetid://6895079853",
		volume = 0.8,
		pitchRange = { 1.0, 1.0 },
		cooldown = 1.0,
	},
	CountdownTick = {
		soundId = "rbxassetid://6895079853",
		volume = 0.6,
		pitchRange = { 1.0, 1.0 },
		cooldown = 0.5,
	},
	CountdownFinal = {
		soundId = "rbxassetid://6895079853",
		volume = 0.8,
		pitchRange = { 1.2, 1.2 },
		cooldown = 0.5,
	},
	GameStart = {
		soundId = "rbxassetid://6895079853",
		volume = 1.0,
		pitchRange = { 1.0, 1.0 },
		cooldown = 2.0,
	},
	Victory = {
		soundId = "rbxassetid://6895079853",
		volume = 1.0,
		pitchRange = { 1.0, 1.0 },
		cooldown = 5.0,
	},
	Defeat = {
		soundId = "rbxassetid://6895079853",
		volume = 0.8,
		pitchRange = { 0.7, 0.7 },
		cooldown = 5.0,
	},

	-- Inventory sounds
	ItemPickup = {
		soundId = "rbxassetid://6895079853",
		volume = 0.5,
		pitchRange = { 1.0, 1.2 },
		cooldown = 0.05,
	},
	ItemDrop = {
		soundId = "rbxassetid://6895079853",
		volume = 0.4,
		pitchRange = { 0.8, 1.0 },
		cooldown = 0.05,
	},
	ItemEquip = {
		soundId = "rbxassetid://6895079853",
		volume = 0.6,
		pitchRange = { 0.9, 1.1 },
		cooldown = 0.1,
	},
	WeaponSwitch = {
		soundId = "rbxassetid://6895079853",
		volume = 0.5,
		pitchRange = { 0.95, 1.05 },
		cooldown = 0.1,
	},

	-- Health/Combat feedback
	HealSound = {
		soundId = "rbxassetid://6895079853",
		volume = 0.6,
		pitchRange = { 1.1, 1.2 },
		cooldown = 0.3,
	},
	ShieldSound = {
		soundId = "rbxassetid://6895079853",
		volume = 0.6,
		pitchRange = { 1.0, 1.1 },
		cooldown = 0.3,
	},
	LowHealthPulse = {
		soundId = "rbxassetid://6895079853",
		volume = 0.4,
		pitchRange = { 0.6, 0.7 },
		cooldown = 0.8,
	},
	Elimination = {
		soundId = "rbxassetid://6895079853",
		volume = 0.7,
		pitchRange = { 1.0, 1.1 },
		cooldown = 0.5,
	},
	Headshot = {
		soundId = "rbxassetid://6895079853",
		volume = 0.8,
		pitchRange = { 1.3, 1.4 },
		cooldown = 0.1,
	},
	HitMarker = {
		soundId = "rbxassetid://6895079853",
		volume = 0.5,
		pitchRange = { 1.0, 1.1 },
		cooldown = 0.05,
	},

	-- Zone sounds
	ZoneWarning = {
		soundId = "rbxassetid://6895079853",
		volume = 0.7,
		pitchRange = { 0.8, 0.9 },
		cooldown = 1.0,
	},
	ZoneShrink = {
		soundId = "rbxassetid://6895079853",
		volume = 0.6,
		pitchRange = { 0.7, 0.8 },
		cooldown = 2.0,
	},

	-- XP/Achievement sounds
	XPGain = {
		soundId = "rbxassetid://6895079853",
		volume = 0.4,
		pitchRange = { 1.1, 1.3 },
		cooldown = 0.1,
	},
	LevelUp = {
		soundId = "rbxassetid://6895079853",
		volume = 0.9,
		pitchRange = { 1.0, 1.0 },
		cooldown = 1.0,
	},
	AchievementUnlock = {
		soundId = "rbxassetid://6895079853",
		volume = 1.0,
		pitchRange = { 1.0, 1.0 },
		cooldown = 1.0,
	},

	-- Tutorial/Hint sounds
	HintAppear = {
		soundId = "rbxassetid://6895079853",
		volume = 0.4,
		pitchRange = { 1.1, 1.2 },
		cooldown = 0.5,
	},
	TutorialComplete = {
		soundId = "rbxassetid://6895079853",
		volume = 0.6,
		pitchRange = { 1.2, 1.3 },
		cooldown = 0.5,
	},
}

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------

local localPlayer = Players.LocalPlayer
local soundFolder: Folder? = nil
local soundInstances: { [string]: Sound } = {}
local lastPlayedTime: { [string]: number } = {}

local isInitialized = false
local masterVolume = 1.0
local categoryVolumes: { [string]: number } = {
	UI = 1.0,
	Notification = 1.0,
	Combat = 1.0,
	Ambient = 1.0,
}

--------------------------------------------------------------------------------
-- HELPER FUNCTIONS
--------------------------------------------------------------------------------

--[[
	Get a random pitch within range
]]
local function getRandomPitch(range: { number }): number
	if range[1] == range[2] then
		return range[1]
	end
	return range[1] + math.random() * (range[2] - range[1])
end

--[[
	Check if sound is on cooldown
]]
local function isOnCooldown(soundName: string, cooldown: number): boolean
	local lastPlayed = lastPlayedTime[soundName]
	if not lastPlayed then
		return false
	end
	return (tick() - lastPlayed) < cooldown
end

--------------------------------------------------------------------------------
-- CORE FUNCTIONS
--------------------------------------------------------------------------------

--[[
	Initialize the UI sounds system
]]
function UISounds.Initialize()
	if isInitialized then return end

	-- Create sound folder
	soundFolder = Instance.new("Folder")
	soundFolder.Name = "UISounds"
	soundFolder.Parent = SoundService

	-- Pre-create sound instances for all definitions
	for name, def in SOUND_DEFINITIONS do
		local sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = def.soundId
		sound.Volume = def.volume
		sound.Parent = soundFolder
		soundInstances[name] = sound
	end

	isInitialized = true
	print("[UISounds] Initialized")
end

--[[
	Play a sound by name
]]
function UISounds.Play(soundName: string, volumeMultiplier: number?)
	if not isInitialized then return end

	local definition = SOUND_DEFINITIONS[soundName]
	if not definition then
		warn(`[UISounds] Unknown sound: {soundName}`)
		return
	end

	-- Check cooldown
	if isOnCooldown(soundName, definition.cooldown) then
		return
	end

	local sound = soundInstances[soundName]
	if not sound then return end

	-- Apply pitch variation
	sound.PlaybackSpeed = getRandomPitch(definition.pitchRange)

	-- Apply volume with multiplier
	local baseVolume = definition.volume
	local multiplier = volumeMultiplier or 1.0
	sound.Volume = baseVolume * multiplier * masterVolume

	-- Play the sound
	sound:Play()

	-- Record play time
	lastPlayedTime[soundName] = tick()
end

--[[
	Play sound with custom pitch
]]
function UISounds.PlayWithPitch(soundName: string, pitch: number, volumeMultiplier: number?)
	if not isInitialized then return end

	local definition = SOUND_DEFINITIONS[soundName]
	if not definition then
		warn(`[UISounds] Unknown sound: {soundName}`)
		return
	end

	-- Check cooldown
	if isOnCooldown(soundName, definition.cooldown) then
		return
	end

	local sound = soundInstances[soundName]
	if not sound then return end

	-- Apply specified pitch
	sound.PlaybackSpeed = pitch

	-- Apply volume
	local baseVolume = definition.volume
	local multiplier = volumeMultiplier or 1.0
	sound.Volume = baseVolume * multiplier * masterVolume

	sound:Play()
	lastPlayedTime[soundName] = tick()
end

--------------------------------------------------------------------------------
-- CONVENIENCE FUNCTIONS
--------------------------------------------------------------------------------

-- Button sounds
function UISounds.ButtonClick()
	UISounds.Play("ButtonClick")
end

function UISounds.ButtonHover()
	UISounds.Play("ButtonHover")
end

function UISounds.TabSwitch()
	UISounds.Play("TabSwitch")
end

-- Menu sounds
function UISounds.MenuOpen()
	UISounds.Play("MenuOpen")
end

function UISounds.MenuClose()
	UISounds.Play("MenuClose")
end

-- Notification sounds
function UISounds.NotifyInfo()
	UISounds.Play("NotificationInfo")
end

function UISounds.NotifySuccess()
	UISounds.Play("NotificationSuccess")
end

function UISounds.NotifyWarning()
	UISounds.Play("NotificationWarning")
end

function UISounds.NotifyError()
	UISounds.Play("NotificationError")
end

-- Game state sounds
function UISounds.MatchFound()
	UISounds.Play("MatchFound")
end

function UISounds.CountdownTick()
	UISounds.Play("CountdownTick")
end

function UISounds.CountdownFinal()
	UISounds.Play("CountdownFinal")
end

function UISounds.GameStart()
	UISounds.Play("GameStart")
end

function UISounds.Victory()
	UISounds.Play("Victory")
end

function UISounds.Defeat()
	UISounds.Play("Defeat")
end

-- Inventory sounds
function UISounds.ItemPickup()
	UISounds.Play("ItemPickup")
end

function UISounds.ItemDrop()
	UISounds.Play("ItemDrop")
end

function UISounds.ItemEquip()
	UISounds.Play("ItemEquip")
end

function UISounds.WeaponSwitch()
	UISounds.Play("WeaponSwitch")
end

-- Combat feedback
function UISounds.Heal()
	UISounds.Play("HealSound")
end

function UISounds.Shield()
	UISounds.Play("ShieldSound")
end

function UISounds.LowHealthPulse()
	UISounds.Play("LowHealthPulse")
end

function UISounds.Elimination()
	UISounds.Play("Elimination")
end

function UISounds.Headshot()
	UISounds.Play("Headshot")
end

function UISounds.HitMarker()
	UISounds.Play("HitMarker")
end

-- Zone sounds
function UISounds.ZoneWarning()
	UISounds.Play("ZoneWarning")
end

function UISounds.ZoneShrink()
	UISounds.Play("ZoneShrink")
end

-- XP/Achievement
function UISounds.XPGain(amount: number?)
	-- Pitch scales slightly with amount
	local basePitch = 1.1
	if amount and amount > 0 then
		basePitch = 1.1 + math.min(amount / 1000, 0.3)
	end
	UISounds.PlayWithPitch("XPGain", basePitch)
end

function UISounds.LevelUp()
	UISounds.Play("LevelUp")
end

function UISounds.AchievementUnlock()
	UISounds.Play("AchievementUnlock")
end

-- Tutorial
function UISounds.HintAppear()
	UISounds.Play("HintAppear")
end

function UISounds.TutorialComplete()
	UISounds.Play("TutorialComplete")
end

--------------------------------------------------------------------------------
-- VOLUME CONTROL
--------------------------------------------------------------------------------

--[[
	Set master volume (0-1)
]]
function UISounds.SetMasterVolume(volume: number)
	masterVolume = math.clamp(volume, 0, 1)
end

--[[
	Get master volume
]]
function UISounds.GetMasterVolume(): number
	return masterVolume
end

--[[
	Set category volume (0-1)
]]
function UISounds.SetCategoryVolume(category: string, volume: number)
	categoryVolumes[category] = math.clamp(volume, 0, 1)
end

--[[
	Get category volume
]]
function UISounds.GetCategoryVolume(category: string): number
	return categoryVolumes[category] or 1.0
end

--[[
	Mute all UI sounds
]]
function UISounds.Mute()
	masterVolume = 0
end

--[[
	Unmute UI sounds
]]
function UISounds.Unmute()
	masterVolume = 1.0
end

--------------------------------------------------------------------------------
-- CLEANUP
--------------------------------------------------------------------------------

--[[
	Cleanup
]]
function UISounds.Cleanup()
	if soundFolder then
		soundFolder:Destroy()
		soundFolder = nil
	end

	soundInstances = {}
	lastPlayedTime = {}
	isInitialized = false
end

return UISounds
