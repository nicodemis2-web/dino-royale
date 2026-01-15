--!strict
--[[
	Main.client.lua
	===============
	Client entry point for Dino Royale
	Initializes all client systems and UI
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

-- Wait for shared modules
ReplicatedStorage:WaitForChild("Shared")

-- Local player
local localPlayer = Players.LocalPlayer

-- Import shared modules
local Events = require(ReplicatedStorage.Shared.Events)

-- Client modules (lazy loaded)
local WeaponController: any = nil
local InventoryController: any = nil
local VehicleController: any = nil
local DeploymentController: any = nil
local MovementController: any = nil
local HUDController: any = nil
local AudioController: any = nil
local MinimapController: any = nil
local RevivalUI: any = nil
local LootUI: any = nil
local SpectatorController: any = nil
local VictoryScreen: any = nil
local LobbyScreen: any = nil
local StormController: any = nil
local Compass: any = nil
local BattlePassUI: any = nil
local ShopUI: any = nil
local TutorialUI: any = nil
local PartyUI: any = nil
local RankedUI: any = nil
local AccessibilityUI: any = nil

-- State
local isInitialized = false
local currentGameState = "Loading"

--[[
	Load all client modules
]]
local function loadModules()
	print("[Client] Loading modules...")

	local Controllers = script.Parent.Controllers
	local UI = script.Parent.UI
	local Audio = script.Parent.Audio

	-- Controllers
	WeaponController = require(Controllers.WeaponController)
	InventoryController = require(Controllers.InventoryController)
	VehicleController = require(Controllers.VehicleController)
	DeploymentController = require(Controllers.DeploymentController)
	MovementController = require(Controllers.MovementController)
	SpectatorController = require(Controllers.SpectatorController)
	StormController = require(Controllers.StormController)

	-- UI
	HUDController = require(UI.HUDController)
	MinimapController = require(UI.Map.MinimapController)
	RevivalUI = require(UI.Revival.RevivalUI)
	LootUI = require(UI.Inventory.LootUI)
	VictoryScreen = require(UI.Components.VictoryScreen)
	LobbyScreen = require(UI.Components.LobbyScreen)
	Compass = require(UI.Components.Compass)
	BattlePassUI = require(UI.Components.BattlePassUI)
	ShopUI = require(UI.Components.ShopUI)
	TutorialUI = require(UI.Components.TutorialUI)
	PartyUI = require(UI.Components.PartyUI)
	RankedUI = require(UI.Components.RankedUI)
	AccessibilityUI = require(UI.Components.AccessibilityUI)

	-- Audio
	AudioController = require(Audio.AudioController)

	print("[Client] Modules loaded")
end

--[[
	Initialize all client systems
]]
local function initializeSystems()
	print("[Client] Initializing systems...")

	-- Disable default Roblox UI elements
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)

	-- Initialize in order
	AudioController.Initialize()
	HUDController.Initialize()
	MinimapController.Initialize()
	RevivalUI.Initialize()
	LootUI.Initialize()
	VictoryScreen.Initialize()
	LobbyScreen.Initialize()
	Compass.Initialize()
	WeaponController.Initialize()
	InventoryController.Initialize()
	VehicleController.Initialize()
	DeploymentController.Initialize()
	MovementController.Initialize()
	SpectatorController.Initialize()
	StormController.Initialize()
	BattlePassUI.Initialize()
	ShopUI.Initialize()
	TutorialUI.Initialize()
	PartyUI.Initialize()
	RankedUI.Initialize()
	AccessibilityUI.Initialize()

	print("[Client] Systems initialized")
end

--[[
	Handle game state changes
]]
local function handleStateChange(newState: string)
	if newState == "Lobby" then
		-- Show lobby UI
		HUDController.OnGameStateChanged("Lobby")

	elseif newState == "Loading" then
		-- Loading screen
		HUDController.OnGameStateChanged("Loading")

	elseif newState == "Deploying" then
		-- Start deployment
		HUDController.OnGameStateChanged("Deploying")
		DeploymentController.Enable()

	elseif newState == "Playing" then
		-- Full gameplay
		HUDController.OnGameStateChanged("Playing")
		DeploymentController.Disable()
		MovementController.Enable()
		WeaponController.Enable()

	elseif newState == "Ending" then
		-- Match results
		HUDController.OnGameStateChanged("Ending")
		MovementController.Disable()
		WeaponController.Disable()

	elseif newState == "Spectating" then
		-- Spectator mode
		WeaponController.Disable()
		-- Enable spectator camera
	end
end

--[[
	Handle local player death
]]
local function handleDeath(data: any)
	WeaponController.Disable()
	VehicleController.Cleanup()

	-- Play death sound
	AudioController.PlayUISound("Death")

	-- Show elimination UI
end

--[[
	Handle local player respawn
]]
local function handleRespawn()
	WeaponController.Enable()

	-- Play respawn sound
	AudioController.PlayUISound("Heal")
end

--[[
	Setup event handlers
]]
local function setupEventHandlers()
	-- Game state changes
	Events.OnClientEvent("GameState", "MatchStateChanged", function(data)
		local newState = data.newState
		print(`[Client] Game state: {currentGameState} -> {newState}`)
		currentGameState = newState

		handleStateChange(newState)
	end)

	-- Note: Removed broken event listeners for non-existent events
	-- MatchStateChanged above handles all state transitions
end

--[[
	Wait for character
]]
local function waitForCharacter()
	local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()

	-- Setup character-specific things
	local humanoid = character:WaitForChild("Humanoid")

	-- Track death (handled by server EliminationManager)
	humanoid.Died:Connect(function()
		print("[Client] Player died")
	end)

	return character
end

--[[
	Main initialization
]]
local function main()
	print("==========================================")
	print("  DINO ROYALE - Client Starting")
	print("==========================================")

	-- Wait for player GUI
	localPlayer:WaitForChild("PlayerGui")

	loadModules()
	initializeSystems()
	setupEventHandlers()

	-- Wait for character
	waitForCharacter()

	-- Listen for respawns
	localPlayer.CharacterAdded:Connect(function()
		waitForCharacter()
	end)

	isInitialized = true

	print("[Client] Ready!")
	print("==========================================")
end

-- Run
main()
