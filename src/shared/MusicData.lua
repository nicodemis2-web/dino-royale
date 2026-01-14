--!strict
--[[
	MusicData.lua
	=============
	Adaptive music configuration
	Based on GDD: Dynamic Audio System
]]

export type MusicLayer = {
	id: string,
	name: string,
	assetId: string,
	volume: number,
	fadeInTime: number,
	fadeOutTime: number,
}

export type MusicTrack = {
	id: string,
	name: string,
	context: string, -- "Lobby", "Deployment", "Exploration", "Combat", "Tension", "Victory", "Defeat"
	bpm: number,
	layers: { MusicLayer },
	loopEnabled: boolean,
}

export type IntensityLevel = {
	level: number, -- 0-5
	name: string,
	activeLayers: { string }, -- Layer IDs to play at this intensity
	transitionTime: number,
}

local MusicData = {}

-- Music contexts
MusicData.Contexts = {
	"Lobby",
	"Deployment",
	"Exploration",
	"Tension",
	"Combat",
	"Victory",
	"Defeat",
	"Storm",
}

-- Intensity levels (affects layer mixing)
MusicData.IntensityLevels: { IntensityLevel } = {
	{
		level = 0,
		name = "Silent",
		activeLayers = {},
		transitionTime = 2,
	},
	{
		level = 1,
		name = "Ambient",
		activeLayers = { "ambient", "pad" },
		transitionTime = 3,
	},
	{
		level = 2,
		name = "Calm",
		activeLayers = { "ambient", "pad", "melody_soft" },
		transitionTime = 2.5,
	},
	{
		level = 3,
		name = "Alert",
		activeLayers = { "ambient", "pad", "melody_soft", "percussion_light" },
		transitionTime = 2,
	},
	{
		level = 4,
		name = "Danger",
		activeLayers = { "pad", "melody_intense", "percussion_light", "percussion_heavy" },
		transitionTime = 1.5,
	},
	{
		level = 5,
		name = "Combat",
		activeLayers = { "melody_intense", "percussion_heavy", "bass", "stinger" },
		transitionTime = 1,
	},
}

-- Main gameplay track with adaptive layers
MusicData.Tracks: { MusicTrack } = {
	{
		id = "MainTheme",
		name = "Isla Primordial",
		context = "Exploration",
		bpm = 100,
		loopEnabled = true,
		layers = {
			{
				id = "ambient",
				name = "Ambient Nature",
				assetId = "rbxassetid://main_ambient",
				volume = 0.4,
				fadeInTime = 3,
				fadeOutTime = 2,
			},
			{
				id = "pad",
				name = "Atmospheric Pad",
				assetId = "rbxassetid://main_pad",
				volume = 0.35,
				fadeInTime = 2.5,
				fadeOutTime = 2,
			},
			{
				id = "melody_soft",
				name = "Soft Melody",
				assetId = "rbxassetid://main_melody_soft",
				volume = 0.3,
				fadeInTime = 2,
				fadeOutTime = 1.5,
			},
			{
				id = "melody_intense",
				name = "Intense Melody",
				assetId = "rbxassetid://main_melody_intense",
				volume = 0.5,
				fadeInTime = 1.5,
				fadeOutTime = 1,
			},
			{
				id = "percussion_light",
				name = "Light Percussion",
				assetId = "rbxassetid://main_perc_light",
				volume = 0.35,
				fadeInTime = 1.5,
				fadeOutTime = 1,
			},
			{
				id = "percussion_heavy",
				name = "Heavy Drums",
				assetId = "rbxassetid://main_perc_heavy",
				volume = 0.55,
				fadeInTime = 1,
				fadeOutTime = 0.5,
			},
			{
				id = "bass",
				name = "Combat Bass",
				assetId = "rbxassetid://main_bass",
				volume = 0.45,
				fadeInTime = 1,
				fadeOutTime = 0.5,
			},
			{
				id = "stinger",
				name = "Action Stinger",
				assetId = "rbxassetid://main_stinger",
				volume = 0.4,
				fadeInTime = 0.5,
				fadeOutTime = 0.5,
			},
		},
	},
	{
		id = "LobbyTheme",
		name = "Preparation",
		context = "Lobby",
		bpm = 85,
		loopEnabled = true,
		layers = {
			{
				id = "ambient",
				name = "Lobby Ambient",
				assetId = "rbxassetid://lobby_ambient",
				volume = 0.4,
				fadeInTime = 2,
				fadeOutTime = 2,
			},
			{
				id = "pad",
				name = "Lobby Pad",
				assetId = "rbxassetid://lobby_pad",
				volume = 0.35,
				fadeInTime = 2,
				fadeOutTime = 1.5,
			},
			{
				id = "melody_soft",
				name = "Lobby Melody",
				assetId = "rbxassetid://lobby_melody",
				volume = 0.3,
				fadeInTime = 1.5,
				fadeOutTime = 1.5,
			},
		},
	},
	{
		id = "DeploymentTheme",
		name = "Descent",
		context = "Deployment",
		bpm = 110,
		loopEnabled = true,
		layers = {
			{
				id = "ambient",
				name = "Wind Rush",
				assetId = "rbxassetid://deploy_wind",
				volume = 0.5,
				fadeInTime = 1,
				fadeOutTime = 1,
			},
			{
				id = "pad",
				name = "Epic Pad",
				assetId = "rbxassetid://deploy_pad",
				volume = 0.4,
				fadeInTime = 1.5,
				fadeOutTime = 1,
			},
			{
				id = "percussion_heavy",
				name = "Battle Drums",
				assetId = "rbxassetid://deploy_drums",
				volume = 0.45,
				fadeInTime = 1,
				fadeOutTime = 0.5,
			},
		},
	},
	{
		id = "VictoryTheme",
		name = "Apex Predator",
		context = "Victory",
		bpm = 120,
		loopEnabled = false,
		layers = {
			{
				id = "full",
				name = "Victory Fanfare",
				assetId = "rbxassetid://victory_full",
				volume = 0.6,
				fadeInTime = 0.5,
				fadeOutTime = 2,
			},
		},
	},
	{
		id = "DefeatTheme",
		name = "Extinction",
		context = "Defeat",
		bpm = 70,
		loopEnabled = false,
		layers = {
			{
				id = "full",
				name = "Defeat Theme",
				assetId = "rbxassetid://defeat_full",
				volume = 0.4,
				fadeInTime = 1,
				fadeOutTime = 2,
			},
		},
	},
	{
		id = "StormTheme",
		name = "Extinction Wave",
		context = "Storm",
		bpm = 130,
		loopEnabled = true,
		layers = {
			{
				id = "ambient",
				name = "Storm Ambient",
				assetId = "rbxassetid://storm_ambient",
				volume = 0.5,
				fadeInTime = 1.5,
				fadeOutTime = 1,
			},
			{
				id = "pad",
				name = "Danger Pad",
				assetId = "rbxassetid://storm_pad",
				volume = 0.45,
				fadeInTime = 1,
				fadeOutTime = 1,
			},
			{
				id = "percussion_heavy",
				name = "Urgent Drums",
				assetId = "rbxassetid://storm_drums",
				volume = 0.5,
				fadeInTime = 0.5,
				fadeOutTime = 0.5,
			},
		},
	},
}

-- Stinger sounds for events
MusicData.Stingers = {
	DinosaurNearby = {
		assetId = "rbxassetid://stinger_dino",
		volume = 0.5,
		duration = 2,
	},
	PlayerEliminated = {
		assetId = "rbxassetid://stinger_kill",
		volume = 0.4,
		duration = 1.5,
	},
	LowHealth = {
		assetId = "rbxassetid://stinger_danger",
		volume = 0.35,
		duration = 3,
	},
	Top10 = {
		assetId = "rbxassetid://stinger_top10",
		volume = 0.4,
		duration = 2,
	},
	BossSpawn = {
		assetId = "rbxassetid://stinger_boss",
		volume = 0.55,
		duration = 3,
	},
}

-- Get track by context
function MusicData.GetTrackForContext(context: string): MusicTrack?
	for _, track in ipairs(MusicData.Tracks) do
		if track.context == context then
			return track
		end
	end
	return nil
end

-- Get track by ID
function MusicData.GetTrack(trackId: string): MusicTrack?
	for _, track in ipairs(MusicData.Tracks) do
		if track.id == trackId then
			return track
		end
	end
	return nil
end

-- Get intensity level data
function MusicData.GetIntensityLevel(level: number): IntensityLevel
	for _, intensityData in ipairs(MusicData.IntensityLevels) do
		if intensityData.level == level then
			return intensityData
		end
	end
	return MusicData.IntensityLevels[1]
end

-- Get stinger by event
function MusicData.GetStinger(event: string): { assetId: string, volume: number, duration: number }?
	return MusicData.Stingers[event]
end

return MusicData
