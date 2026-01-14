--!strict
--[[
	PingData.lua
	============
	Ping types and configurations for team communication
	Based on GDD Section 4.5: Team Modes
]]

export type PingType = "Generic" | "Enemy" | "Loot" | "Danger" | "GoHere" | "Defending" | "NeedHelp" | "Watching"

export type PingConfig = {
	name: string,
	displayName: string,
	icon: string,
	color: Color3,
	sound: string,
	duration: number,
	showOnMinimap: boolean,
	voiceLine: string?,
}

local PingData = {}

PingData.Pings: { [PingType]: PingConfig } = {
	Generic = {
		name = "Generic",
		displayName = "Ping",
		icon = "rbxassetid://0",
		color = Color3.fromRGB(255, 255, 255),
		sound = "PingGeneric",
		duration = 5,
		showOnMinimap = true,
		voiceLine = "Over here!",
	},

	Enemy = {
		name = "Enemy",
		displayName = "Enemy Spotted",
		icon = "rbxassetid://0",
		color = Color3.fromRGB(255, 80, 80),
		sound = "PingEnemy",
		duration = 8,
		showOnMinimap = true,
		voiceLine = "Enemy spotted!",
	},

	Loot = {
		name = "Loot",
		displayName = "Loot Here",
		icon = "rbxassetid://0",
		color = Color3.fromRGB(255, 200, 0),
		sound = "PingLoot",
		duration = 10,
		showOnMinimap = true,
		voiceLine = "Loot here!",
	},

	Danger = {
		name = "Danger",
		displayName = "Danger",
		icon = "rbxassetid://0",
		color = Color3.fromRGB(255, 0, 0),
		sound = "PingDanger",
		duration = 8,
		showOnMinimap = true,
		voiceLine = "Watch out!",
	},

	GoHere = {
		name = "GoHere",
		displayName = "Go Here",
		icon = "rbxassetid://0",
		color = Color3.fromRGB(0, 200, 255),
		sound = "PingGoHere",
		duration = 15,
		showOnMinimap = true,
		voiceLine = "Let's go here!",
	},

	Defending = {
		name = "Defending",
		displayName = "Defending",
		icon = "rbxassetid://0",
		color = Color3.fromRGB(100, 150, 255),
		sound = "PingDefending",
		duration = 20,
		showOnMinimap = true,
		voiceLine = "Holding this position!",
	},

	NeedHelp = {
		name = "NeedHelp",
		displayName = "Need Help",
		icon = "rbxassetid://0",
		color = Color3.fromRGB(255, 150, 0),
		sound = "PingHelp",
		duration = 10,
		showOnMinimap = true,
		voiceLine = "I need help!",
	},

	Watching = {
		name = "Watching",
		displayName = "Watching",
		icon = "rbxassetid://0",
		color = Color3.fromRGB(150, 100, 255),
		sound = "PingWatching",
		duration = 15,
		showOnMinimap = true,
		voiceLine = "I'm watching this area.",
	},
}

-- Get ping config
function PingData.GetPingConfig(pingType: PingType): PingConfig
	return PingData.Pings[pingType]
end

-- Get all ping types
function PingData.GetAllTypes(): { PingType }
	local types: { PingType } = {}
	for pingType in pairs(PingData.Pings) do
		table.insert(types, pingType)
	end
	return types
end

return PingData
