--!strict
--[[
	PingManager.lua
	===============
	Server-side ping management for team communication
	Based on GDD Section 4.5: Team Modes
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Events = require(ReplicatedStorage.Shared.Events)
local PingData = require(ReplicatedStorage.Shared.PingData)

local PingManager = {}

-- Types
export type ActivePing = {
	id: string,
	pingType: PingData.PingType,
	position: Vector3,
	owner: Player,
	teamId: string,
	createdTime: number,
	expiresTime: number,
	targetEntity: string?, -- Optional: name of pinged entity
}

-- State
local activePings: { [string]: ActivePing } = {}
local playerTeams: { [Player]: string } = {}
local pingCooldowns: { [Player]: number } = {}
local isInitialized = false

-- Constants
local PING_COOLDOWN = 1.0 -- Seconds between pings
local MAX_PINGS_PER_TEAM = 10

-- Signals
local onPingCreated = Instance.new("BindableEvent")
local onPingExpired = Instance.new("BindableEvent")

PingManager.OnPingCreated = onPingCreated.Event
PingManager.OnPingExpired = onPingExpired.Event

--[[
	Initialize the ping manager
]]
function PingManager.Initialize()
	if isInitialized then return end
	isInitialized = true

	print("[PingManager] Initializing...")

	-- Setup client events
	Events.OnServerEvent("Ping", "CreatePing", function(player, data)
		if typeof(data) == "table" and typeof(data.position) == "Vector3" then
			PingManager.CreatePing(player, data.pingType, data.position, data.targetEntity)
		end
	end)

	Events.OnServerEvent("Ping", "RemovePing", function(player, data)
		if typeof(data) == "table" and typeof(data.pingId) == "string" then
			PingManager.RemovePing(data.pingId, player)
		end
	end)

	-- Start update loop
	task.spawn(function()
		while true do
			PingManager.Update()
			task.wait(1)
		end
	end)

	print("[PingManager] Initialized")
end

--[[
	Register player to team (called by RevivalManager or TeamManager)
]]
function PingManager.RegisterPlayerTeam(player: Player, teamId: string)
	playerTeams[player] = teamId
end

--[[
	Create a new ping
]]
function PingManager.CreatePing(player: Player, pingType: PingData.PingType, position: Vector3, targetEntity: string?)
	-- Check cooldown
	local lastPing = pingCooldowns[player] or 0
	if tick() - lastPing < PING_COOLDOWN then
		return
	end

	local teamId = playerTeams[player]
	if not teamId then
		-- Solo mode - just ping for self
		teamId = `solo_{player.UserId}`
	end

	-- Check max pings
	local teamPingCount = 0
	for _, ping in pairs(activePings) do
		if ping.teamId == teamId then
			teamPingCount = teamPingCount + 1
		end
	end

	if teamPingCount >= MAX_PINGS_PER_TEAM then
		-- Remove oldest ping
		local oldestPing: ActivePing? = nil
		local oldestTime = math.huge
		for _, ping in pairs(activePings) do
			if ping.teamId == teamId and ping.createdTime < oldestTime then
				oldestTime = ping.createdTime
				oldestPing = ping
			end
		end
		if oldestPing then
			PingManager.RemovePing(oldestPing.id, nil)
		end
	end

	local pingConfig = PingData.GetPingConfig(pingType)
	local pingId = `{player.UserId}_{tick()}`

	local ping: ActivePing = {
		id = pingId,
		pingType = pingType,
		position = position,
		owner = player,
		teamId = teamId,
		createdTime = tick(),
		expiresTime = tick() + pingConfig.duration,
		targetEntity = targetEntity,
	}

	activePings[pingId] = ping
	pingCooldowns[player] = tick()

	-- Notify team members
	for _, teamPlayer in ipairs(Players:GetPlayers()) do
		local playerTeam = playerTeams[teamPlayer]
		if playerTeam == teamId or teamPlayer == player then
			Events.FireClient(teamPlayer, "Ping", "PingCreated", {
				id = pingId,
				pingType = pingType,
				position = position,
				ownerName = player.Name,
				ownerId = player.UserId,
				targetEntity = targetEntity,
				duration = pingConfig.duration,
				color = { r = pingConfig.color.R * 255, g = pingConfig.color.G * 255, b = pingConfig.color.B * 255 },
				voiceLine = pingConfig.voiceLine,
			})
		end
	end

	onPingCreated:Fire(ping)
	print(`[PingManager] {player.Name} pinged {pingType} at {position}`)
end

--[[
	Remove a ping
]]
function PingManager.RemovePing(pingId: string, requestingPlayer: Player?)
	local ping = activePings[pingId]
	if not ping then return end

	-- Check permission if player requested
	if requestingPlayer then
		local playerTeam = playerTeams[requestingPlayer]
		if playerTeam ~= ping.teamId and requestingPlayer ~= ping.owner then
			return -- Can't remove other team's pings
		end
	end

	activePings[pingId] = nil

	-- Notify team
	for _, teamPlayer in ipairs(Players:GetPlayers()) do
		local playerTeam = playerTeams[teamPlayer]
		if playerTeam == ping.teamId or teamPlayer == ping.owner then
			Events.FireClient(teamPlayer, "Ping", "PingRemoved", {
				id = pingId,
			})
		end
	end

	onPingExpired:Fire(ping)
end

--[[
	Update loop - check for expired pings
]]
function PingManager.Update()
	local currentTime = tick()
	local expiredPings: { string } = {}

	for pingId, ping in pairs(activePings) do
		if currentTime >= ping.expiresTime then
			table.insert(expiredPings, pingId)
		end
	end

	for _, pingId in ipairs(expiredPings) do
		PingManager.RemovePing(pingId, nil)
	end
end

--[[
	Get active pings for a team
]]
function PingManager.GetTeamPings(teamId: string): { ActivePing }
	local result = {}
	for _, ping in pairs(activePings) do
		if ping.teamId == teamId then
			table.insert(result, ping)
		end
	end
	return result
end

--[[
	Get ping by ID
]]
function PingManager.GetPing(pingId: string): ActivePing?
	return activePings[pingId]
end

--[[
	Reset for new match
]]
function PingManager.Reset()
	activePings = {}
	pingCooldowns = {}
	-- Don't reset playerTeams - handled by team system
	print("[PingManager] Reset")
end

--[[
	Cleanup player
]]
function PingManager.CleanupPlayer(player: Player)
	-- Remove player's pings
	local toRemove: { string } = {}
	for pingId, ping in pairs(activePings) do
		if ping.owner == player then
			table.insert(toRemove, pingId)
		end
	end

	for _, pingId in ipairs(toRemove) do
		PingManager.RemovePing(pingId, nil)
	end

	pingCooldowns[player] = nil
	playerTeams[player] = nil
end

return PingManager
