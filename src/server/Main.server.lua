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
local MapManager: any = nil
local EnvironmentalEventManager: any = nil
local RevivalManager: any = nil
local RebootBeaconManager: any = nil
local ProgressionManager: any = nil
local PingManager: any = nil
local LootManager: any = nil
local CombatManager: any = nil
local HealingManager: any = nil
local BattlePassManager: any = nil
local ShopManager: any = nil
local TutorialManager: any = nil
local PartyManager: any = nil
local RankedManager: any = nil
local AccessibilityManager: any = nil
local AdminConsole: any = nil

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
	local Map = script.Parent.Map

	-- Core systems
	GameManager = require(Core.GameManager)
	StormManager = require(Core.StormManager)
	DeploymentManager = require(Core.DeploymentManager)
	AdminConsole = require(Core.AdminConsole)

	-- Map systems
	MapManager = require(Map.MapManager)
	EnvironmentalEventManager = require(Map.EnvironmentalEventManager)

	-- Player systems
	WeaponManager = require(Weapons.WeaponManager)
	InventoryManager = require(Player.InventoryManager)
	EliminationManager = require(Player.EliminationManager)
	RevivalManager = require(Player.RevivalManager)
	RebootBeaconManager = require(Player.RebootBeaconManager)
	ProgressionManager = require(Player.ProgressionManager)
	PingManager = require(Player.PingManager)

	-- AI systems
	DinosaurManager = require(AI.DinosaurManager)
	BossEventManager = require(EventsFolder.BossEventManager)

	-- Vehicle system
	VehicleManager = require(Vehicles.VehicleManager)

	-- Loot system
	local Loot = script.Parent.Loot
	LootManager = require(Loot.LootManager)

	-- Combat system
	local Combat = script.Parent.Combat
	CombatManager = require(Combat.CombatManager)
	HealingManager = require(Combat.HealingManager)

	-- Meta-game systems
	BattlePassManager = require(Player.BattlePassManager)
	ShopManager = require(Player.ShopManager)
	TutorialManager = require(Player.TutorialManager)
	PartyManager = require(Player.PartyManager)
	RankedManager = require(Player.RankedManager)
	AccessibilityManager = require(Player.AccessibilityManager)

	print("[Server] Modules loaded")
end

--[[
	Initialize all server systems
]]
local function initializeSystems()
	print("[Server] Initializing systems...")

	-- Initialize events system first (creates RemoteEvents)
	Events.Initialize()

	-- Initialize in dependency order
	GameManager.Initialize()
	MapManager.Initialize() -- Map must init before storm/dinos
	WeaponManager.Initialize()
	InventoryManager.Initialize()
	EliminationManager.Initialize()
	RevivalManager.Initialize()
	RebootBeaconManager.Initialize()
	ProgressionManager.Initialize()
	PingManager.Initialize()
	DinosaurManager.Initialize()
	BossEventManager.Initialize()
	VehicleManager.Initialize()
	EnvironmentalEventManager.Initialize()
	LootManager.Initialize()
	CombatManager.Initialize()
	HealingManager.Initialize()
	BattlePassManager.Initialize()
	ShopManager.Initialize()
	TutorialManager.Initialize()
	PartyManager.Initialize()
	RankedManager.Initialize()
	AccessibilityManager.Initialize()

	-- Set manager references on GameManager
	GameManager.SetStormManager(StormManager)
	GameManager.SetDeploymentManager(DeploymentManager)
	GameManager.SetEliminationManager(EliminationManager)

	-- Set CombatManager reference on StormManager for damage dealing
	StormManager.SetCombatManager(CombatManager)

	-- Set dependencies on EliminationManager
	EliminationManager.SetGameManager(GameManager)
	EliminationManager.SetInventoryManager(InventoryManager)
	EliminationManager.SetCombatManager(CombatManager)

	-- Initialize StormManager with map parameters
	local mapCenter = Vector3.new(0, 0, 0)
	local mapRadius = 2000 -- Match BiomeData.MapSize
	StormManager.Initialize(mapCenter, mapRadius)

	-- Admin console (debug/testing)
	AdminConsole.SetGameManager(GameManager)
	AdminConsole.Initialize()

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
			MapManager.Reset()
			StormManager.Reset()
			DinosaurManager.Reset()
			VehicleManager.Reset()
			EliminationManager.Reset()
			EnvironmentalEventManager.Reset()
			RevivalManager.Reset()
			RebootBeaconManager.Reset()
			PingManager.Reset()
			LootManager.Reset()
			CombatManager.Reset()
			HealingManager.Reset()
			InventoryManager.Reset()
			DeploymentManager.Reset()

		elseif newState == "Deploying" then
			-- Start deployment phase
			MapManager.StartMatch() -- Initialize POIs and map content
			-- Note: DeploymentManager.StartDeployment is called by GameManager with flight path
			-- Dinosaurs spawn during DinosaurManager.Initialize()
			-- Vehicles spawn during VehicleManager.Initialize() via spawnInitialVehicles()
			LootManager.SpawnPOILoot() -- Spawn loot at all POIs

		elseif newState == "Playing" then
			-- Start the storm (phase 1)
			StormManager.StartPhase(1)
			-- BossEventManager tracks triggers via CheckEventTriggers
			MapManager.OnMatchPhaseChanged("Playing")

		elseif newState == "Ending" then
			-- Match ended
			-- StormManager doesn't have Stop(), it uses Reset() for cleanup

		elseif newState == "Resetting" then
			-- Prepare for next match
			task.delay(10, function()
				GameManager.SetState("Lobby")
			end)
		end
	end)

	-- Storm manager updates (if StormManager has this signal)
	if StormManager.OnPhaseChanged then
		StormManager.OnPhaseChanged:Connect(function(phase, circleData)
			-- Broadcast to clients using GameState.StormUpdate event
			Events.FireAllClients("GameState", "StormUpdate", {
				phase = phase,
				center = circleData.center,
				radius = circleData.radius,
				nextRadius = circleData.nextRadius,
				timeRemaining = circleData.timeRemaining,
			})

			-- Check boss spawn triggers
			if BossEventManager.CheckEventTriggers then
				BossEventManager.CheckEventTriggers({
					currentPhase = phase,
					aliveCount = EliminationManager.GetAliveCount(),
				})
			end
		end)
	end

	-- Elimination tracking (if EliminationManager has this signal)
	if EliminationManager.OnPlayerEliminated then
		EliminationManager.OnPlayerEliminated:Connect(function(victim, killer, source)
			-- Update game manager
			GameManager.RemoveAlivePlayer(victim)

			-- Broadcast using Combat.PlayerEliminated event
			Events.FireAllClients("Combat", "PlayerEliminated", {
				victimId = victim.UserId,
				killerId = killer and killer.UserId or nil,
				weapon = source,
				placement = GameManager.GetAlivePlayerCount() + 1,
			})
		end)
	end

	-- Player count tracking
	Players.PlayerRemoving:Connect(function(player)
		if EliminationManager.IsPlayerAlive and EliminationManager.IsPlayerAlive(player) then
			if EliminationManager.HandleDisconnect then
				EliminationManager.HandleDisconnect(player)
			end
		end
	end)

	-- Deployment events (jump and glider input)
	Events.OnServerEvent("GameState", "PlayerJumped", function(player, _data)
		-- Let GameManager handle jump tracking and forward to DeploymentManager
		GameManager.OnPlayerJump(player)
	end)

	Events.OnServerEvent("GameState", "GliderInput", function(player, data)
		if DeploymentManager and DeploymentManager.IsActive() and DeploymentManager.IsPlayerGliding(player) then
			DeploymentManager.ValidateGliderInput(player, data)
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
			Events.FireClient("GameState", "MatchStateChanged", player, {
				newState = "Spectating",
				isLateJoin = true,
			})
		elseif currentState == "Lobby" then
			-- Add to lobby
			Events.FireClient("GameState", "MatchStateChanged", player, {
				newState = "Lobby",
				playerCount = GameManager.GetAlivePlayerCount(),
			})
		end
	end)

	-- Handle players leaving
	Players.PlayerRemoving:Connect(function(player)
		print(`[Server] Player left: {player.Name}`)

		-- Cleanup player
		InventoryManager.CleanupPlayer(player)
		WeaponManager.CleanupPlayer(player)
		RevivalManager.CleanupPlayer(player)
		RebootBeaconManager.CleanupPlayer(player)
		PingManager.CleanupPlayer(player)
		CombatManager.CleanupPlayer(player)
		HealingManager.CleanupPlayer(player)
		BattlePassManager.CleanupPlayer(player)
		ShopManager.CleanupPlayer(player)
		TutorialManager.CleanupPlayer(player)
		PartyManager.CleanupPlayer(player)
		RankedManager.CleanupPlayer(player)
		AccessibilityManager.CleanupPlayer(player)

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
