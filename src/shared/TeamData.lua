--!strict
--[[
	TeamData.lua
	============
	Team mode configurations for Dino Royale
	Based on GDD Section 4.5: Team Modes
]]

export type TeamMode = "Solos" | "Duos" | "Squads"

export type TeamModeConfig = {
	name: string,
	displayName: string,
	teamSize: number,
	maxTeams: number,

	-- Revival settings
	canRevive: boolean,
	downedDuration: number, -- Seconds before bleed out
	reviveTime: number, -- Seconds to revive
	reviveHealthPercent: number, -- Health after revive

	-- Reboot settings
	canReboot: boolean,
	rebootCardDuration: number, -- Seconds card lasts after death
	rebootTime: number, -- Seconds to use beacon
	rebootHealthPercent: number, -- Health after reboot
	rebootCooldown: number, -- Beacon cooldown after use

	-- Team features
	canPingEnemies: boolean,
	sharedLoot: boolean,
	teamVoiceChat: boolean,
}

local TeamData = {}

TeamData.Modes = {
	Solos = {
		name = "Solos",
		displayName = "Solo",
		teamSize = 1,
		maxTeams = 100,

		canRevive = false,
		downedDuration = 0,
		reviveTime = 0,
		reviveHealthPercent = 0,

		canReboot = false,
		rebootCardDuration = 0,
		rebootTime = 0,
		rebootHealthPercent = 0,
		rebootCooldown = 0,

		canPingEnemies = false,
		sharedLoot = false,
		teamVoiceChat = false,
	},

	Duos = {
		name = "Duos",
		displayName = "Duos",
		teamSize = 2,
		maxTeams = 50,

		canRevive = true,
		downedDuration = 30,
		reviveTime = 5,
		reviveHealthPercent = 0.3,

		canReboot = true,
		rebootCardDuration = 90,
		rebootTime = 10,
		rebootHealthPercent = 0.5,
		rebootCooldown = 120,

		canPingEnemies = true,
		sharedLoot = false,
		teamVoiceChat = true,
	},

	Squads = {
		name = "Squads",
		displayName = "Squads",
		teamSize = 4,
		maxTeams = 25,

		canRevive = true,
		downedDuration = 45,
		reviveTime = 4,
		reviveHealthPercent = 0.3,

		canReboot = true,
		rebootCardDuration = 120,
		rebootTime = 8,
		rebootHealthPercent = 0.5,
		rebootCooldown = 90,

		canPingEnemies = true,
		sharedLoot = false,
		teamVoiceChat = true,
	},
}

-- Get team mode config
function TeamData.GetModeConfig(mode: TeamMode): TeamModeConfig
	return TeamData.Modes[mode]
end

-- Calculate max players for mode
function TeamData.GetMaxPlayers(mode: TeamMode): number
	local config = TeamData.Modes[mode]
	return config.teamSize * config.maxTeams
end

-- Check if mode supports revival
function TeamData.SupportsRevival(mode: TeamMode): boolean
	return TeamData.Modes[mode].canRevive
end

-- Check if mode supports reboot
function TeamData.SupportsReboot(mode: TeamMode): boolean
	return TeamData.Modes[mode].canReboot
end

return TeamData
