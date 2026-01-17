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
local GameConfig = require(game.ReplicatedStorage.Shared.GameConfig)
local MatchConfig = require(game.ReplicatedStorage.Shared.Config.MatchConfig)

-- Type imports
type MatchState = "Lobby" | "Loading" | "Deploying" | "Playing" | "Ending" | "Resetting"
type GameMode = MatchConfig.GameMode

local GameManager = {}

-- Create state changed signal (BindableEvent for internal use)
local stateChangedEvent = Instance.new("BindableEvent")
GameManager.OnStateChanged = stateChangedEvent.Event

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
local mapManager: any = nil

-- Player tracking
local alivePlayers = {} :: { [number]: Player }
local totalPlayersInMatch = 0

-- Ready state tracking
local readyPlayers = {} :: { [number]: boolean }

-- Game mode and team tracking
local currentGameMode: GameMode = "Solo"
local teams = {} :: { [number]: { players: { Player }, teamId: number } }
local playerTeams = {} :: { [number]: number } -- playerId -> teamId
local nextTeamId = 1

-- Lobby state
local lobbyCountdown = 0
local isCountdownActive = false

-- Win condition mutex to prevent race conditions
local isCheckingWinCondition = false

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

-- Alias for GetCurrentState (used by Main.server.lua)
function GameManager.GetState(): MatchState
	return currentState
end

-- Alias for TransitionTo (used by Main.server.lua)
function GameManager.SetState(newState: MatchState, data: { [string]: any }?)
	GameManager.TransitionTo(newState, data)
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

--------------------------------------------------------------------------------
-- GAME MODE & TEAM FUNCTIONS
--------------------------------------------------------------------------------

--[[
	Set the game mode
]]
function GameManager.SetGameMode(mode: GameMode)
	if currentState ~= "Lobby" then
		warn("[GameManager] Cannot change mode outside of lobby")
		return false
	end

	currentGameMode = mode
	MatchConfig.SetMode(mode)

	-- Broadcast mode change to all clients
	Events.FireAllClients("GameState", "ModeChanged", {
		mode = mode,
		settings = MatchConfig.GetCurrentSettings(),
	})

	print(`[GameManager] Game mode set to: {mode}`)
	return true
end

--[[
	Get current game mode
]]
function GameManager.GetGameMode(): GameMode
	return currentGameMode
end

--[[
	Assign player to a team
]]
function GameManager.AssignPlayerToTeam(player: Player, teamId: number?)
	local settings = MatchConfig.GetCurrentSettings()

	-- Solo mode - no teams
	if settings.teamSize == 1 then
		playerTeams[player.UserId] = player.UserId -- Self-team
		return player.UserId
	end

	-- If specific team requested
	if teamId then
		local team = teams[teamId]
		if team and #team.players < settings.teamSize then
			table.insert(team.players, player)
			playerTeams[player.UserId] = teamId
			Events.FireClient("GameState", "TeamAssigned", player, {
				teamId = teamId,
				teammates = team.players,
			})
			return teamId
		end
	end

	-- Find existing team with space
	if settings.allowFillTeams then
		for tid, team in pairs(teams) do
			if #team.players < settings.teamSize then
				table.insert(team.players, player)
				playerTeams[player.UserId] = tid
				Events.FireClient("GameState", "TeamAssigned", player, {
					teamId = tid,
					teammates = team.players,
				})
				return tid
			end
		end
	end

	-- Create new team
	local newTeamId = nextTeamId
	nextTeamId = nextTeamId + 1
	teams[newTeamId] = {
		teamId = newTeamId,
		players = { player },
	}
	playerTeams[player.UserId] = newTeamId
	Events.FireClient("GameState", "TeamAssigned", player, {
		teamId = newTeamId,
		teammates = { player },
	})
	return newTeamId
end

--[[
	Get player's team
]]
function GameManager.GetPlayerTeam(player: Player): number?
	return playerTeams[player.UserId]
end

--[[
	Check if two players are on the same team
]]
function GameManager.AreTeammates(player1: Player, player2: Player): boolean
	local team1 = playerTeams[player1.UserId]
	local team2 = playerTeams[player2.UserId]
	return team1 ~= nil and team1 == team2
end

--[[
	Start the match (manual start from lobby)
]]
function GameManager.StartMatch()
	if currentState ~= "Lobby" then
		warn("[GameManager] Cannot start match - not in lobby")
		return false
	end

	local settings = MatchConfig.GetCurrentSettings()
	local playerCount = #Players:GetPlayers()

	-- Test mode can start with 1 player
	if settings.mode == "Test" then
		print("[GameManager] Starting TEST MODE match")
		GameManager.TransitionTo("Loading", { testMode = true })
		return true
	end

	-- Check minimum players
	if playerCount < settings.minPlayersToStart then
		warn(`[GameManager] Not enough players: {playerCount}/{settings.minPlayersToStart}`)
		return false
	end

	print(`[GameManager] Starting match with {playerCount} players in {settings.mode} mode`)
	GameManager.TransitionTo("Loading")
	return true
end

--[[
	Broadcast lobby state to all clients
]]
function GameManager.BroadcastLobbyState()
	local playerList = {}
	local readyCount = 0

	for _, player in ipairs(Players:GetPlayers()) do
		local isReady = readyPlayers[player.UserId] or false
		if isReady then
			readyCount = readyCount + 1
		end
		table.insert(playerList, {
			userId = player.UserId,
			name = player.Name,
			ready = isReady,
			teamId = playerTeams[player.UserId],
		})
	end

	Events.FireAllClients("GameState", "LobbyUpdate", {
		players = playerList,
		readyCount = readyCount,
		totalPlayers = #playerList,
		mode = currentGameMode,
		countdown = isCountdownActive and lobbyCountdown or nil,
		settings = MatchConfig.GetCurrentSettings(),
	})
end

--[[
	Set player ready state
]]
function GameManager.SetPlayerReady(player: Player, ready: boolean)
	readyPlayers[player.UserId] = ready

	-- Broadcast ready state to all clients
	Events.FireAllClients("GameState", "PlayerReadyUpdate", {
		playerId = player.UserId,
		playerName = player.Name,
		ready = ready,
	})

	print(`[GameManager] {player.Name} is {ready and "READY" or "NOT READY"}`)

	-- Check if all players are ready (in Lobby state)
	if currentState == "Lobby" and ready then
		GameManager.CheckAllPlayersReady()
	end
end

--[[
	Check if a player is ready
]]
function GameManager.IsPlayerReady(player: Player): boolean
	return readyPlayers[player.UserId] == true
end

--[[
	Get count of ready players
]]
function GameManager.GetReadyPlayerCount(): number
	local count = 0
	for _, isReady in pairs(readyPlayers) do
		if isReady then
			count = count + 1
		end
	end
	return count
end

--[[
	Check if all players are ready and start game if so
]]
function GameManager.CheckAllPlayersReady()
	local playerCount = #Players:GetPlayers()
	local readyCount = GameManager.GetReadyPlayerCount()

	print(`[GameManager] Ready check: {readyCount}/{playerCount} players ready`)

	if playerCount > 0 and readyCount >= playerCount then
		print("[GameManager] All players ready! Starting match...")

		-- Register all players as alive
		for _, player in ipairs(Players:GetPlayers()) do
			GameManager.RegisterAlivePlayer(player)
		end
		totalPlayersInMatch = playerCount

		-- Transition to Playing
		GameManager.TransitionTo("Playing", { allReady = true })
	end
end

--[[
	Check win condition (mutex protected to prevent race conditions)
]]
function GameManager.CheckWinCondition()
	-- Prevent concurrent win condition checks
	if isCheckingWinCondition then
		return
	end
	isCheckingWinCondition = true

	local aliveCount = GameManager.GetAlivePlayerCount()

	-- In solo debug mode, don't end game with 1 player (that's the only player!)
	-- Only trigger win when a player is eliminated and 1 remains
	if GameConfig.Debug.Enabled and GameConfig.Debug.SoloTestMode then
		-- Solo mode: Only end if totalPlayersInMatch > 1 and aliveCount <= 1
		-- This prevents auto-win when solo testing
		if totalPlayersInMatch > 1 and aliveCount <= 1 then
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
	else
		-- Normal multiplayer: End when 1 or fewer remain
		if aliveCount <= 1 then
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

	isCheckingWinCondition = false
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

	-- Fire internal state changed event
	stateChangedEvent:Fire(newState, previousState)

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
	Waiting for players to Ready Up before starting
]]
stateHandlers.Lobby = {
	OnEnter = function(_data)
		-- Reset player tracking
		alivePlayers = {}
		totalPlayersInMatch = 0
		readyPlayers = {}
		teams = {}
		playerTeams = {}
		nextTeamId = 1
		isCountdownActive = false
		lobbyCountdown = 0

		print("[GameManager] Entered Lobby state")
		print("[GameManager] Waiting for players to Ready Up...")

		-- Assign existing players to teams
		for _, player in ipairs(Players:GetPlayers()) do
			GameManager.AssignPlayerToTeam(player)
		end

		-- Notify all clients that lobby is ready
		local settings = MatchConfig.GetCurrentSettings()
		Events.FireAllClients("GameState", "LobbyReady", {
			message = "Select a mode and click READY to start!",
			mode = currentGameMode,
			settings = settings,
		})

		-- Broadcast initial lobby state
		GameManager.BroadcastLobbyState()
	end,

	OnUpdate = function(dt)
		local settings = MatchConfig.GetCurrentSettings()
		local playerCount = #Players:GetPlayers()

		-- Test mode: can start immediately with 1 player
		if settings.mode == "Test" then
			-- Don't auto-start, wait for manual start
			return
		end

		-- Count ready players
		local readyCount = 0
		for _, isReady in pairs(readyPlayers) do
			if isReady then
				readyCount = readyCount + 1
			end
		end

		-- Check if we should start countdown
		local shouldCountdown = playerCount >= settings.minPlayersToStart and readyCount >= playerCount

		if shouldCountdown then
			if not isCountdownActive then
				-- Start countdown
				isCountdownActive = true
				lobbyCountdown = settings.lobbyCountdown
				stateData.countdownStarted = true
				stateData.countdownStart = tick()
				print(`[GameManager] All {playerCount} players ready, starting {lobbyCountdown}s countdown`)
				Events.FireAllClients("GameState", "CountdownStarted", {
					duration = lobbyCountdown,
				})
			end

			-- Update countdown
			local elapsed = tick() - stateData.countdownStart
			local remaining = math.ceil(lobbyCountdown - elapsed)

			if remaining ~= stateData.lastCountdown then
				stateData.lastCountdown = remaining
				Events.FireAllClients("GameState", "CountdownUpdate", {
					remaining = remaining,
				})
			end

			if remaining <= 0 then
				GameManager.TransitionTo("Loading")
			end
		elseif isCountdownActive then
			-- Cancel countdown if conditions no longer met
			isCountdownActive = false
			stateData.countdownStarted = false
			print("[GameManager] Countdown cancelled - players not ready")
			Events.FireAllClients("GameState", "CountdownCancelled", {})
		end

		-- Periodic lobby state broadcast (every 2 seconds)
		stateData.broadcastTimer = (stateData.broadcastTimer or 0) + dt
		if stateData.broadcastTimer >= 2 then
			stateData.broadcastTimer = 0
			GameManager.BroadcastLobbyState()
		end
	end,

	OnExit = function()
		isCountdownActive = false
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

		-- ALWAYS skip helicopter - spawn directly on terrain
		-- Players are already positioned on terrain by Main.server.lua
		task.delay(1, function()
			if currentState == "Loading" then
				-- Go straight to playing - no helicopter deployment
				GameManager.TransitionTo("Playing", { directSpawn = true })
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
	DISABLED - No longer used, players spawn directly on terrain
	Kept as pass-through in case accidentally called
]]
stateHandlers.Deploying = {
	OnEnter = function(_data)
		print("[GameManager] Deploying state called - redirecting to Playing (helicopter disabled)")
		-- Immediately transition to Playing - no helicopter
		task.defer(function()
			GameManager.TransitionTo("Playing", { directSpawn = true })
		end)
	end,

	OnUpdate = function(_dt)
		-- No-op - should transition immediately
	end,

	OnExit = function()
		print("[GameManager] Deployment phase skipped")
	end,
}

--[[
	PLAYING STATE
	Main gameplay with storm
]]
stateHandlers.Playing = {
	OnEnter = function(data)
		print("[GameManager] Match started!")

		stateData.matchStartTime = tick()
		stateData.supplyDropTimer = 120 -- First supply drop after 2 minutes

		-- Direct spawn mode: players are already on terrain from Main.server.lua
		-- Just verify they're in valid positions
		if data and data.directSpawn then
			print("[GameManager] Direct spawn mode - players already on terrain")
			for _, player in ipairs(Players:GetPlayers()) do
				task.spawn(function()
					local character = player.Character
					if character then
						local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
						if rootPart then
							-- Check if player is at invalid position (falling/void)
							if rootPart.Position.Y < -10 or rootPart.Position.Y > 600 then
								-- Rescue player to terrain
								local rayResult = workspace:Raycast(
									Vector3.new(200, 500, 200),
									Vector3.new(0, -1000, 0)
								)
								local safeY = rayResult and (rayResult.Position.Y + 5) or 30
								rootPart.CFrame = CFrame.new(200, safeY, 200)
								rootPart.AssemblyLinearVelocity = Vector3.zero
								print(`[GameManager] Rescued {player.Name} to terrain`)
							else
								print(`[GameManager] {player.Name} already at valid position: {rootPart.Position}`)
							end
						end
					end
				end)
			end
		end

		-- Initialize map content (POIs, loot, etc.)
		if mapManager then
			mapManager.StartMatch()
			mapManager.OnMatchPhaseChanged("Playing")
		end

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
	-- Remove from ready players
	readyPlayers[player.UserId] = nil

	-- Remove from alive players if in match
	if alivePlayers[player.UserId] then
		GameManager.RemoveAlivePlayer(player)
		print(`[GameManager] {player.Name} left the match`)
	end
end

--[[
	Handle player jump request during deployment
	Note: Deploying state is currently disabled, but this is kept for future use
]]
function GameManager.OnPlayerJump(player: Player)
	if currentState ~= "Deploying" then
		return
	end

	-- Initialize jumpedPlayers if not already done
	if not stateData.jumpedPlayers then
		stateData.jumpedPlayers = {}
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

function GameManager.SetMapManager(manager: any)
	mapManager = manager
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

	-- Handle Ready Up events from clients
	Events.OnServerEvent("GameState", "ToggleReady", function(player, data)
		if currentState ~= "Lobby" then
			return -- Can only toggle ready in lobby
		end

		local isReady = data and data.ready or false
		GameManager.SetPlayerReady(player, isReady)
	end)

	-- Handle mode selection from clients
	Events.OnServerEvent("GameState", "SelectMode", function(player, data)
		if currentState ~= "Lobby" then
			return
		end

		-- For now, any player can change mode (could restrict to party leader)
		local mode = data and data.mode
		if mode and MatchConfig.Modes[mode] then
			GameManager.SetGameMode(mode)
			GameManager.BroadcastLobbyState()
		end
	end)

	-- Handle manual match start (for test mode or when all ready)
	Events.OnServerEvent("GameState", "StartMatch", function(player, _data)
		if currentState ~= "Lobby" then
			return
		end

		local settings = MatchConfig.GetCurrentSettings()

		-- Test mode: anyone can start
		if settings.mode == "Test" then
			print(`[GameManager] {player.Name} started TEST MODE`)
			GameManager.StartMatch()
			return
		end

		-- Normal modes: check if player is ready and enough players
		if readyPlayers[player.UserId] then
			local readyCount = 0
			for _, isReady in pairs(readyPlayers) do
				if isReady then
					readyCount = readyCount + 1
				end
			end

			if readyCount >= settings.minPlayersToStart then
				print(`[GameManager] {player.Name} initiated match start`)
				GameManager.StartMatch()
			end
		end
	end)

	-- Handle return to lobby request
	Events.OnServerEvent("GameState", "ReturnToLobby", function(player, _data)
		-- Only allow during certain states
		if currentState == "Ending" or currentState == "Resetting" then
			return
		end

		-- In test mode, allow instant return to lobby
		if MatchConfig.IsTestMode() then
			print(`[GameManager] {player.Name} returned to lobby (test mode)`)
			GameManager.Reset()
		end
	end)

	-- Handle spawn request
	Events.OnServerEvent("GameState", "RequestSpawn", function(player, _data)
		if currentState ~= "Playing" then
			return
		end

		local settings = MatchConfig.GetCurrentSettings()

		-- Check if respawn is allowed
		if not settings.respawnEnabled then
			return
		end

		-- Respawn the player (test mode feature)
		local character = player.Character
		if not character then
			player:LoadCharacter()
			GameManager.RegisterAlivePlayer(player)
			print(`[GameManager] Respawned {player.Name} (test mode)`)
		end
	end)

	-- Note: PlayerJumped event is handled in Main.server.lua to avoid duplicate handlers

	-- Handle existing players
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end

	isInitialized = true
	stateStartTime = tick()

	-- Manually trigger Lobby OnEnter since we start in Lobby state
	local lobbyHandler = stateHandlers.Lobby
	if lobbyHandler and lobbyHandler.OnEnter then
		lobbyHandler.OnEnter({})
	end

	print("[GameManager] Initialized, starting in Lobby state")
end

--[[
	Reset for new match (keeps connections, resets state)
]]
function GameManager.Reset()
	-- Reset state to Lobby
	currentState = "Lobby"
	stateData = {}
	stateStartTime = tick()

	-- Clear player tracking
	alivePlayers = {}
	totalPlayersInMatch = 0
	readyPlayers = {}

	-- Clear team tracking
	teams = {}
	playerTeams = {}
	nextTeamId = 1

	-- Reset countdown
	isCountdownActive = false
	lobbyCountdown = 0

	-- Trigger Lobby OnEnter
	local lobbyHandler = stateHandlers.Lobby
	if lobbyHandler and lobbyHandler.OnEnter then
		lobbyHandler.OnEnter({})
	end

	-- Notify clients of state change
	Events.FireAllClients("GameState", "StateChanged", {
		newState = "Lobby",
		previousState = "Resetting",
	})

	print("[GameManager] Reset to Lobby state")
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
