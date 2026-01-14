--!strict
--[[
	Main.server.lua
	===============
	Server entry point for Dino Royale
	Initializes all server systems and manages game lifecycle
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for shared modules
ReplicatedStorage:WaitForChild("Shared")

-- Import modules
local Events = require(ReplicatedStorage.Shared.Events)

-- Server modules (lazy loaded)
local GameManager: any = nil
local StormManager: any = nil
local DeploymentManager: any = nil
local WeaponManager: any = nil
local InventoryManager: any = nil
local EliminationManager: any = nil
local DinosaurManager: any = nil
local BossEventManager: any = nil
local VehicleManager: any = nil

-- State
local isInitialized = false

--[[
	Load all server modules
]]
local function loadModules()
	print("[Server] Loading modules...")

	local Core = script.Parent.Core
	local Player = script.Parent.Player
	local Weapons = script.Parent.Weapons
	local AI = script.Parent.AI
	local Vehicles = script.Parent.Vehicles
	local EventsFolder = script.Parent.Events

	-- Core systems
	GameManager = require(Core.GameManager)
	StormManager = require(Core.StormManager)
	DeploymentManager = require(Core.DeploymentManager)

	-- Player systems
	WeaponManager = require(Weapons.WeaponManager)
	InventoryManager = require(Player.InventoryManager)
	EliminationManager = require(Player.EliminationManager)

	-- AI systems
	DinosaurManager = require(AI.DinosaurManager)
	BossEventManager = require(EventsFolder.BossEventManager)

	-- Vehicle system
	VehicleManager = require(Vehicles.VehicleManager)

	print("[Server] Modules loaded")
end

--[[
	Initialize all server systems
]]
local function initializeSystems()
	print("[Server] Initializing systems...")

	-- Initialize in dependency order
	GameManager.Initialize()
	StormManager.Initialize()
	DeploymentManager.Initialize()
	WeaponManager.Initialize()
	InventoryManager.Initialize()
	EliminationManager.Initialize()
	DinosaurManager.Initialize()
	BossEventManager.Initialize()
	VehicleManager.Initialize()

	-- Connect systems
	connectSystems()

	print("[Server] Systems initialized")
end

--[[
	Connect systems together
]]
local function connectSystems()
	-- GameManager controls match flow
	GameManager.OnStateChanged:Connect(function(newState, oldState)
		print(`[Server] Game state: {oldState} -> {newState}`)

		if newState == "Loading" then
			-- Reset all systems for new match
			StormManager.Reset()
			DinosaurManager.Reset()
			VehicleManager.Reset()
			EliminationManager.Reset()

		elseif newState == "Deploying" then
			-- Start deployment phase
			DeploymentManager.StartDeployment()
			DinosaurManager.SpawnInitial()
			VehicleManager.Initialize() -- Spawns vehicles

		elseif newState == "Playing" then
			-- Start the storm
			StormManager.Start()
			BossEventManager.Initialize()

		elseif newState == "Ending" then
			-- Match ended
			StormManager.Stop()
			DinosaurManager.StopSpawning()

		elseif newState == "Resetting" then
			-- Prepare for next match
			task.delay(10, function()
				GameManager.SetState("Lobby")
			end)
		end
	end)

	-- Storm manager updates
	StormManager.OnPhaseChanged:Connect(function(phase, circleData)
		-- Broadcast to clients
		Events.FireAllClients("Storm", "PhaseChanged", {
			phase = phase,
			center = circleData.center,
			radius = circleData.radius,
			shrinkTime = circleData.shrinkTime,
		})

		-- Check boss spawn triggers
		BossEventManager.CheckEventTriggers({
			currentPhase = phase,
			aliveCount = EliminationManager.GetAliveCount(),
		})
	end)

	-- Elimination tracking
	EliminationManager.OnPlayerEliminated:Connect(function(victim, killer, source)
		-- Update game manager
		GameManager.OnPlayerEliminated(victim)

		-- Broadcast
		Events.FireAllClients("Combat", "PlayerKilled", {
			victimName = victim.Name,
			victimId = victim.UserId,
			killerName = killer and killer.Name or source,
			killerId = killer and killer.UserId or nil,
			weapon = source,
		})
	end)

	-- Player count tracking
	Players.PlayerRemoving:Connect(function(player)
		local isAlive = EliminationManager.IsPlayerAlive(player)
		if isAlive then
			EliminationManager.HandleDisconnect(player)
		end
	end)
end

--[[
	Setup player handling
]]
local function setupPlayerHandling()
	-- Handle new players
	Players.PlayerAdded:Connect(function(player)
		print(`[Server] Player joined: {player.Name}`)

		-- Initialize player systems
		InventoryManager.InitializePlayer(player)
		WeaponManager.InitializePlayer(player)

		-- If match in progress, spectate
		local currentState = GameManager.GetState()
		if currentState == "Playing" then
			-- Late joiner becomes spectator
			Events.FireClient(player, "GameState", "Spectate", {})
		elseif currentState == "Lobby" then
			-- Add to lobby
			Events.FireClient(player, "GameState", "JoinLobby", {})
		end
	end)

	-- Handle players leaving
	Players.PlayerRemoving:Connect(function(player)
		print(`[Server] Player left: {player.Name}`)

		-- Cleanup player
		InventoryManager.CleanupPlayer(player)
		WeaponManager.CleanupPlayer(player)

		-- Handle vehicle exit
		local vehicle = VehicleManager.GetPlayerVehicle(player)
		if vehicle then
			vehicle:Exit(player)
		end
	end)

	-- Handle existing players
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			InventoryManager.InitializePlayer(player)
			WeaponManager.InitializePlayer(player)
		end)
	end
end

--[[
	Main initialization
]]
local function main()
	print("==========================================")
	print("  DINO ROYALE - Server Starting")
	print("==========================================")

	loadModules()
	initializeSystems()
	setupPlayerHandling()

	isInitialized = true

	print("[Server] Ready!")
	print("==========================================")

	-- Start in lobby state
	GameManager.SetState("Lobby")
end

-- Run
main()
