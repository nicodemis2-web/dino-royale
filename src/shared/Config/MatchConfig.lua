--!strict
--[[
	MatchConfig.lua
	===============
	Configuration for different game modes and match settings.

	Supports:
	- Test Mode (single player, instant start)
	- Solo (100 players, no teams)
	- Duos (50 teams of 2)
	- Trios (33 teams of 3)
	- Quads (25 teams of 4)
]]

export type GameMode = "Test" | "Solo" | "Duos" | "Trios" | "Quads"

export type MatchSettings = {
	mode: GameMode,
	maxPlayers: number,
	teamSize: number,
	maxTeams: number,
	minPlayersToStart: number,
	lobbyCountdown: number,
	allowFillTeams: boolean,
	friendlyFire: boolean,
	reviveEnabled: boolean,
	reviveTime: number,
	respawnEnabled: boolean,
}

local MatchConfig = {}

-- Game mode configurations
MatchConfig.Modes: { [GameMode]: MatchSettings } = {
	Test = {
		mode = "Test",
		maxPlayers = 1,
		teamSize = 1,
		maxTeams = 1,
		minPlayersToStart = 1,
		lobbyCountdown = 3, -- Quick start for testing
		allowFillTeams = false,
		friendlyFire = false,
		reviveEnabled = false,
		reviveTime = 0,
		respawnEnabled = true, -- Allow respawn in test mode
	},

	Solo = {
		mode = "Solo",
		maxPlayers = 100,
		teamSize = 1,
		maxTeams = 100,
		minPlayersToStart = 2, -- At least 2 for a real match
		lobbyCountdown = 60,
		allowFillTeams = false,
		friendlyFire = false,
		reviveEnabled = false,
		reviveTime = 0,
		respawnEnabled = false,
	},

	Duos = {
		mode = "Duos",
		maxPlayers = 100,
		teamSize = 2,
		maxTeams = 50,
		minPlayersToStart = 4,
		lobbyCountdown = 60,
		allowFillTeams = true,
		friendlyFire = false,
		reviveEnabled = true,
		reviveTime = 10,
		respawnEnabled = false,
	},

	Trios = {
		mode = "Trios",
		maxPlayers = 99,
		teamSize = 3,
		maxTeams = 33,
		minPlayersToStart = 6,
		lobbyCountdown = 60,
		allowFillTeams = true,
		friendlyFire = false,
		reviveEnabled = true,
		reviveTime = 10,
		respawnEnabled = false,
	},

	Quads = {
		mode = "Quads",
		maxPlayers = 100,
		teamSize = 4,
		maxTeams = 25,
		minPlayersToStart = 8,
		lobbyCountdown = 60,
		allowFillTeams = true,
		friendlyFire = false,
		reviveEnabled = true,
		reviveTime = 10,
		respawnEnabled = false,
	},
}

-- Default mode
MatchConfig.DefaultMode: GameMode = "Solo"

-- Current match settings (mutable at runtime)
local currentSettings: MatchSettings = MatchConfig.Modes.Solo

--[[
	Get settings for a specific game mode
]]
function MatchConfig.GetModeSettings(mode: GameMode): MatchSettings
	return MatchConfig.Modes[mode] or MatchConfig.Modes.Solo
end

--[[
	Set the current match mode
]]
function MatchConfig.SetMode(mode: GameMode)
	local settings = MatchConfig.Modes[mode]
	if settings then
		currentSettings = settings
		print(`[MatchConfig] Mode set to: {mode}`)
	else
		warn(`[MatchConfig] Unknown mode: {mode}, defaulting to Solo`)
		currentSettings = MatchConfig.Modes.Solo
	end
end

--[[
	Get current match settings
]]
function MatchConfig.GetCurrentSettings(): MatchSettings
	return currentSettings
end

--[[
	Check if current mode is a team mode
]]
function MatchConfig.IsTeamMode(): boolean
	return currentSettings.teamSize > 1
end

--[[
	Check if current mode is test mode
]]
function MatchConfig.IsTestMode(): boolean
	return currentSettings.mode == "Test"
end

--[[
	Get the team size for current mode
]]
function MatchConfig.GetTeamSize(): number
	return currentSettings.teamSize
end

--[[
	Check if enough players to start
]]
function MatchConfig.HasEnoughPlayers(playerCount: number): boolean
	return playerCount >= currentSettings.minPlayersToStart
end

--[[
	Get list of available modes for UI
]]
function MatchConfig.GetAvailableModes(): { GameMode }
	return { "Test", "Solo", "Duos", "Trios", "Quads" }
end

--[[
	Get display name for a mode
]]
function MatchConfig.GetModeDisplayName(mode: GameMode): string
	local displayNames = {
		Test = "Test Mode (Solo)",
		Solo = "Solo (100 Players)",
		Duos = "Duos (2-Player Teams)",
		Trios = "Trios (3-Player Teams)",
		Quads = "Squads (4-Player Teams)",
	}
	return displayNames[mode] or mode
end

return MatchConfig
