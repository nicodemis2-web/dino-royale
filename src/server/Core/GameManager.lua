--!strict
--[[
	GameManager.lua
	===============
	Central match state machine for Dino Royale
	Handles match flow: Lobby → Loading → Deploying → Playing → Ending → Resetting
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Constants = require(game.ReplicatedStorage.Shared.Constants)
local Events = require(game.ReplicatedStorage.Shared.Events)

-- Type imports
type MatchState = "Lobby" | "Loading" | "Deploying" | "Playing" | "Ending" | "Resetting"

local GameManager = {}

-- Current state
local currentState: MatchState = "Lobby"
local stateData = {} :: { [string]: any }
local stateStartTime = 0
local isInitialized = false

-- Connections
local connections = {} :: { RBXScriptConnection }

-- External system references (set via dependency injection)
local stormManager: any = nil
local deploymentManager: any = nil
local eliminationManager: any = nil

-- Player tracking
local alivePlayers = {} :: { [number]: Player }
local totalPlayersInMatch = 0

--[[
	State handler definitions
]]
local stateHandlers = {} :: {
	[MatchState]: {
		OnEnter: ((data: { [string]: any }?) -> ())?,
		OnUpdate: ((dt: number) -> ())?,
		OnExit: (() -> ())?,
	},
}

--[[
	Get current match state
]]
function GameManager.GetCurrentState(): MatchState
	return currentState
end

--[[
	Get state data
]]
function GameManager.GetStateData(): { [string]: any }
	return stateData
end

--[[
	Get time elapsed in current state
]]
function GameManager.GetStateTime(): number
	return tick() - stateStartTime
end

--[[
	Get alive player count
]]
function GameManager.GetAlivePlayerCount(): number
	local count = 0
	for _ in pairs(alivePlayers) do
		count = count + 1
	end
	return count
end

--[[
	Get total players in match
]]
function GameManager.GetTotalPlayersInMatch(): number
	return totalPlayersInMatch
end

--[[
	Check if a player is alive
]]
function GameManager.IsPlayerAlive(player: Player): boolean
	return alivePlayers[player.UserId] ~= nil
end

--[[
	Register a player as alive in the match
]]
function GameManager.RegisterAlivePlayer(player: Player)
	alivePlayers[player.UserId] = player
	GameManager.BroadcastPlayerCount()
end

--[[
	Remove a player from alive list
]]
function GameManager.RemoveAlivePlayer(player: Player)
	alivePlayers[player.UserId] = nil
	GameManager.BroadcastPlayerCount()

	-- Check win condition if in Playing state
	if currentState == "Playing" then
		GameManager.CheckWinCondition()
	end
end

--[[
	Broadcast player count to all clients
]]
function GameManager.BroadcastPlayerCount()
	local aliveCount = GameManager.GetAlivePlayerCount()
	Events.FireAllClients("GameState", "PlayerCountUpdate", {
		alivePlayers = aliveCount,
		totalPlayers = totalPlayersInMatch,
	})
end

--[[
	Check win condition
]]
function GameManager.CheckWinCondition()
	local aliveCount = GameManager.GetAlivePlayerCount()

	if aliveCount <= 1 then
		-- Find winner
		local winner: Player? = nil
		for _, player in pairs(alivePlayers) do
			winner = player
			break
		end

		GameManager.TransitionTo("Ending", {
			winner = winner,
			placement = 1,
		})
	end
end

--[[
	Transition to a new state
]]
function GameManager.TransitionTo(newState: MatchState, data: { [string]: any }?)
	if currentState == newState then
		return
	end

	-- Call exit handler for current state
	local currentHandler = stateHandlers[currentState]
	if currentHandler and currentHandler.OnExit then
		currentHandler.OnExit()
	end

	-- Update state
	local previousState = currentState
	currentState = newState
	stateData = data or {}
	stateStartTime = tick()

	-- Call enter handler for new state
	local newHandler = stateHandlers[newState]
	if newHandler and newHandler.OnEnter then
		newHandler.OnEnter(stateData)
	end

	-- Broadcast state change
	Events.FireAllClients("GameState", "MatchStateChanged", {
		newState = newState,
		previousState = previousState,
		data = stateData,
	})

	print(`[GameManager] State transition: {previousState} → {newState}`)
end

--[[
	Update function called every heartbeat
]]
function GameManager.Update(dt: number)
	if not isInitialized then
		return
	end

	local handler = stateHandlers[currentState]
	if handler and handler.OnUpdate then
		handler.OnUpdate(dt)
	end
end

--[[
	LOBBY STATE
	Waiting for players, countdown when enough players
]]
stateHandlers.Lobby = {
	OnEnter = function(_data)
		-- Reset player tracking
		alivePlayers = {}
		totalPlayersInMatch = 0
		stateData.countdown = nil
		stateData.countdownStarted = false

		print("[GameManager] Entered Lobby state, waiting for players...")
	end,

	OnUpdate = function(_dt)
		local playerCount = #Players:GetPlayers()
		stateData.playerCount = playerCount

		-- Check if we have enough players
		if playerCount >= Constants.MATCH.MIN_PLAYERS then
			-- Start countdown if not started
			if not stateData.countdownStarted then
				stateData.countdownStarted = true
				stateData.countdownStart = tick()
				print(`[GameManager] {playerCount} players, starting {Constants.MATCH.LOBBY_WAIT_TIME}s countdown`)
			end

			-- Force start at max players
			if playerCount >= Constants.MATCH.MAX_PLAYERS then
				GameManager.TransitionTo("Loading")
				return
			end

			-- Check countdown
			local elapsed = tick() - stateData.countdownStart
			local remaining = Constants.MATCH.LOBBY_WAIT_TIME - elapsed
			stateData.countdown = math.ceil(remaining)

			if remaining <= 0 then
				GameManager.TransitionTo("Loading")
			end
		else
			-- Cancel countdown if players dropped
			if stateData.countdownStarted then
				stateData.countdownStarted = false
				stateData.countdown = nil
				print(`[GameManager] Players dropped below {Constants.MATCH.MIN_PLAYERS}, countdown cancelled`)
			end
		end
	end,

	OnExit = function()
		print("[GameManager] Exiting Lobby state")
	end,
}

--[[
	LOADING STATE
	Initialize match systems, teleport players
]]
stateHandlers.Loading = {
	OnEnter = function(_data)
		print("[GameManager] Loading match...")

		-- Record players in match
		totalPlayersInMatch = #Players:GetPlayers()

		-- Register all players as alive
		for _, player in ipairs(Players:GetPlayers()) do
			GameManager.RegisterAlivePlayer(player)
		end

		-- Initialize storm (if manager available)
		if stormManager then
			local mapCenter = Vector3.new(0, 0, 0) -- Would come from map configuration
			local mapRadius = 2000 -- Would come from map configuration
			stormManager.Initialize(mapCenter, mapRadius)
		end

		-- Short delay then transition to deploying
		task.delay(3, function()
			if currentState == "Loading" then
				GameManager.TransitionTo("Deploying")
			end
		end)
	end,

	OnUpdate = function(_dt)
		-- Loading animations/progress could go here
	end,

	OnExit = function()
		print("[GameManager] Loading complete")
	end,
}

--[[
	DEPLOYING STATE
	Helicopter flight, players can jump
]]
stateHandlers.Deploying = {
	OnEnter = function(_data)
		print("[GameManager] Deployment phase started")

		-- Generate flight path
		local flightPath = {
			startPoint = Vector3.new(-2000, 500, 0),
			endPoint = Vector3.new(2000, 500, 0),
			duration = Constants.MATCH.DEPLOY_TIME,
		}

		stateData.flightPath = flightPath
		stateData.deployStartTime = tick()
		stateData.jumpedPlayers = {} :: { [number]: boolean }

		-- Broadcast flight path to clients
		Events.FireAllClients("GameState", "DeployReady", {
			flightPath = flightPath,
		})

		-- Initialize deployment manager if available
		if deploymentManager then
			deploymentManager.StartDeployment(flightPath)
		end
	end,

	OnUpdate = function(_dt)
		local elapsed = tick() - stateData.deployStartTime
		local remaining = Constants.MATCH.DEPLOY_TIME - elapsed

		stateData.timeRemaining = remaining

		-- Auto-eject remaining players at end
		if remaining <= 0 then
			-- Force eject any players still on helicopter
			if deploymentManager then
				deploymentManager.ForceEjectAll()
			end

			GameManager.TransitionTo("Playing")
		end
	end,

	OnExit = function()
		print("[GameManager] Deployment phase ended")
	end,
}

--[[
	PLAYING STATE
	Main gameplay with storm
]]
stateHandlers.Playing = {
	OnEnter = function(_data)
		print("[GameManager] Match started!")

		stateData.matchStartTime = tick()
		stateData.supplyDropTimer = 120 -- First supply drop after 2 minutes

		-- Start storm if manager available
		if stormManager then
			stormManager.StartPhase(1)
		end
	end,

	OnUpdate = function(dt)
		-- Update storm
		if stormManager then
			stormManager.Update(dt)
		end

		-- Supply drop timer
		stateData.supplyDropTimer = stateData.supplyDropTimer - dt
		if stateData.supplyDropTimer <= 0 then
			GameManager.SpawnSupplyDrop()
			stateData.supplyDropTimer = 180 -- Next drop in 3 minutes
		end
	end,

	OnExit = function()
		print("[GameManager] Match ended")
	end,
}

--[[
	ENDING STATE
	Winner celebration
]]
stateHandlers.Ending = {
	OnEnter = function(data)
		local winner = data and data.winner
		local winnerName = winner and winner.Name or "No one"

		print(`[GameManager] Winner: {winnerName}!`)

		stateData.endTime = tick()
		stateData.celebrationDuration = 10

		-- Broadcast winner
		Events.FireAllClients("GameState", "MatchStateChanged", {
			newState = "Ending",
			winner = winner and winner.Name or nil,
			winnerId = winner and winner.UserId or nil,
		})
	end,

	OnUpdate = function(_dt)
		local elapsed = tick() - stateData.endTime
		if elapsed >= stateData.celebrationDuration then
			GameManager.TransitionTo("Resetting")
		end
	end,

	OnExit = function()
		print("[GameManager] Ending celebration complete")
	end,
}

--[[
	RESETTING STATE
	Cleanup and return to lobby
]]
stateHandlers.Resetting = {
	OnEnter = function(_data)
		print("[GameManager] Resetting match...")

		-- Cleanup systems
		if stormManager then
			stormManager.Reset()
		end

		if deploymentManager then
			deploymentManager.Reset()
		end

		if eliminationManager then
			eliminationManager.Reset()
		end

		-- Clear alive players
		alivePlayers = {}
		totalPlayersInMatch = 0

		-- Short delay before returning to lobby
		task.delay(2, function()
			if currentState == "Resetting" then
				GameManager.TransitionTo("Lobby")
			end
		end)
	end,

	OnUpdate = function(_dt)
		-- Reset progress could go here
	end,

	OnExit = function()
		print("[GameManager] Reset complete")
	end,
}

--[[
	Spawn a supply drop at a random position in safe zone
]]
function GameManager.SpawnSupplyDrop()
	if not stormManager then
		return
	end

	local circle = stormManager.GetCurrentCircle()
	if not circle then
		return
	end

	-- Random position within safe zone
	local angle = math.random() * math.pi * 2
	local distance = math.random() * circle.radius * 0.8 -- Stay within 80% of safe zone
	local x = circle.center.X + math.cos(angle) * distance
	local z = circle.center.Z + math.sin(angle) * distance
	local position = Vector3.new(x, 500, z) -- Drop from high altitude

	-- Broadcast supply drop location
	Events.FireAllClients("GameState", "SupplyDropIncoming", {
		position = position,
	})

	print(`[GameManager] Supply drop incoming at {position}`)
end

--[[
	Handle player joining during match
]]
local function onPlayerAdded(player: Player)
	if currentState == "Lobby" then
		-- Player can join lobby
		print(`[GameManager] {player.Name} joined lobby`)
	elseif currentState == "Playing" or currentState == "Deploying" then
		-- Player joins as spectator
		print(`[GameManager] {player.Name} joined as spectator (match in progress)`)
	end
end

--[[
	Handle player leaving
]]
local function onPlayerRemoving(player: Player)
	-- Remove from alive players if in match
	if alivePlayers[player.UserId] then
		GameManager.RemoveAlivePlayer(player)
		print(`[GameManager] {player.Name} left the match`)
	end
end

--[[
	Handle player jump request during deployment
]]
function GameManager.OnPlayerJump(player: Player)
	if currentState ~= "Deploying" then
		return
	end

	if stateData.jumpedPlayers[player.UserId] then
		return -- Already jumped
	end

	stateData.jumpedPlayers[player.UserId] = true

	-- Notify deployment manager
	if deploymentManager then
		deploymentManager.OnPlayerJump(player)
	end

	print(`[GameManager] {player.Name} jumped from helicopter`)
end

--[[
	Set external system references
]]
function GameManager.SetStormManager(manager: any)
	stormManager = manager
end

function GameManager.SetDeploymentManager(manager: any)
	deploymentManager = manager
end

function GameManager.SetEliminationManager(manager: any)
	eliminationManager = manager
end

--[[
	Initialize the game manager
]]
function GameManager.Initialize()
	if isInitialized then
		return
	end

	-- Connect to player events
	table.insert(connections, Players.PlayerAdded:Connect(onPlayerAdded))
	table.insert(connections, Players.PlayerRemoving:Connect(onPlayerRemoving))

	-- Connect to heartbeat
	table.insert(connections, RunService.Heartbeat:Connect(function(dt)
		GameManager.Update(dt)
	end))

	-- Listen for player jump events
	local jumpConnection = Events.OnServerEvent("GameState", "PlayerJumped", function(player, _data)
		GameManager.OnPlayerJump(player)
	end)
	table.insert(connections, jumpConnection)

	-- Handle existing players
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end

	isInitialized = true
	stateStartTime = tick()

	print("[GameManager] Initialized, starting in Lobby state")
end

--[[
	Cleanup
]]
function GameManager.Cleanup()
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	connections = {}
	isInitialized = false
end

return GameManager
