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
local DinosaurTargeting: any = nil

-- Effects modules
local CameraShake: any = nil
local ScreenEffects: any = nil
local FeedbackNotifications: any = nil

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
	DinosaurTargeting = require(UI.Components.DinosaurTargeting)

	-- Audio
	AudioController = require(Audio.AudioController)

	-- Effects
	local Effects = script.Parent.Effects
	CameraShake = require(Effects.CameraShake)
	ScreenEffects = require(Effects.ScreenEffects)

	-- Additional UI components
	local Components = UI.Components
	FeedbackNotifications = require(Components.FeedbackNotifications)

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
	DinosaurTargeting.Initialize()

	-- Initialize effects systems
	CameraShake.Initialize()
	ScreenEffects.Initialize()
	FeedbackNotifications.Initialize()

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

-- Countdown UI reference
local countdownGui: ScreenGui? = nil
local countdownLabel: TextLabel? = nil

--[[
	Create countdown UI
]]
local function createCountdownUI()
	if countdownGui then return end

	countdownGui = Instance.new("ScreenGui")
	countdownGui.Name = "CountdownGui"
	countdownGui.ResetOnSpawn = false
	countdownGui.Parent = localPlayer:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "CountdownFrame"
	frame.Size = UDim2.new(0, 300, 0, 150)
	frame.Position = UDim2.new(0.5, -150, 0.3, 0)
	frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	frame.BackgroundTransparency = 0.5
	frame.BorderSizePixel = 0
	frame.Parent = countdownGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0.4, 0)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "MATCH STARTING IN"
	title.TextColor3 = Color3.fromRGB(255, 200, 50)
	title.TextSize = 24
	title.Font = Enum.Font.GothamBold
	title.Parent = frame

	countdownLabel = Instance.new("TextLabel")
	countdownLabel.Name = "Countdown"
	countdownLabel.Size = UDim2.new(1, 0, 0.6, 0)
	countdownLabel.Position = UDim2.new(0, 0, 0.4, 0)
	countdownLabel.BackgroundTransparency = 1
	countdownLabel.Text = "10"
	countdownLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	countdownLabel.TextSize = 72
	countdownLabel.Font = Enum.Font.GothamBold
	countdownLabel.Parent = frame

	print("[Client] Countdown UI created")
end

--[[
	Update countdown display
]]
local function updateCountdown(remaining: number)
	if not countdownLabel then
		createCountdownUI()
	end

	if countdownLabel and countdownGui then
		countdownLabel.Text = tostring(remaining)
		countdownGui.Enabled = true

		-- Flash effect on low numbers
		if remaining <= 3 then
			countdownLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
			countdownLabel.TextSize = 84
		else
			countdownLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			countdownLabel.TextSize = 72
		end
	end
end

--[[
	Hide countdown UI
]]
local function hideCountdown()
	if countdownGui then
		countdownGui.Enabled = false
	end
end

-- Welcome screen GUI reference
local welcomeGui: ScreenGui? = nil

--[[
	Create and show welcome message
]]
local function showWelcomeMessage(data: any)
	if not data then return end

	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

	-- Remove existing welcome if any
	if welcomeGui then
		welcomeGui:Destroy()
	end

	welcomeGui = Instance.new("ScreenGui")
	welcomeGui.Name = "WelcomeGui"
	welcomeGui.ResetOnSpawn = false
	welcomeGui.DisplayOrder = 100
	welcomeGui.Parent = playerGui

	-- Main frame with semi-transparent background
	local frame = Instance.new("Frame")
	frame.Name = "WelcomeFrame"
	frame.Size = UDim2.new(0, 500, 0, 400)
	frame.Position = UDim2.new(0.5, -250, 0.5, -200)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Parent = welcomeGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = frame

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 60)
	title.Position = UDim2.new(0, 0, 0, 20)
	title.BackgroundTransparency = 1
	title.Text = data.title or "WELCOME"
	title.TextColor3 = Color3.fromRGB(255, 150, 50)
	title.TextSize = 36
	title.Font = Enum.Font.GothamBlack
	title.Parent = frame

	-- Message
	local message = Instance.new("TextLabel")
	message.Name = "Message"
	message.Size = UDim2.new(1, -40, 0, 50)
	message.Position = UDim2.new(0, 20, 0, 80)
	message.BackgroundTransparency = 1
	message.Text = data.message or ""
	message.TextColor3 = Color3.fromRGB(200, 200, 200)
	message.TextSize = 16
	message.Font = Enum.Font.Gotham
	message.TextWrapped = true
	message.Parent = frame

	-- Controls section
	local controlsLabel = Instance.new("TextLabel")
	controlsLabel.Name = "ControlsLabel"
	controlsLabel.Size = UDim2.new(1, 0, 0, 30)
	controlsLabel.Position = UDim2.new(0, 0, 0, 140)
	controlsLabel.BackgroundTransparency = 1
	controlsLabel.Text = "CONTROLS"
	controlsLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
	controlsLabel.TextSize = 20
	controlsLabel.Font = Enum.Font.GothamBold
	controlsLabel.Parent = frame

	-- Controls list
	local controlsFrame = Instance.new("Frame")
	controlsFrame.Name = "Controls"
	controlsFrame.Size = UDim2.new(1, -60, 0, 150)
	controlsFrame.Position = UDim2.new(0, 30, 0, 175)
	controlsFrame.BackgroundTransparency = 1
	controlsFrame.Parent = frame

	local listLayout = Instance.new("UIGridLayout")
	listLayout.CellSize = UDim2.new(0.5, -10, 0, 25)
	listLayout.CellPadding = UDim2.new(0, 10, 0, 5)
	listLayout.Parent = controlsFrame

	if data.controls then
		for _, ctrl in ipairs(data.controls) do
			local ctrlLabel = Instance.new("TextLabel")
			ctrlLabel.Size = UDim2.new(0, 200, 0, 25)
			ctrlLabel.BackgroundTransparency = 1
			ctrlLabel.Text = `[{ctrl.key}] {ctrl.action}`
			ctrlLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
			ctrlLabel.TextSize = 14
			ctrlLabel.Font = Enum.Font.Gotham
			ctrlLabel.TextXAlignment = Enum.TextXAlignment.Left
			ctrlLabel.Parent = controlsFrame
		end
	end

	-- Close button
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 200, 0, 50)
	closeButton.Position = UDim2.new(0.5, -100, 1, -70)
	closeButton.BackgroundColor3 = Color3.fromRGB(80, 180, 80)
	closeButton.BorderSizePixel = 0
	closeButton.Text = "LET'S GO!"
	closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeButton.TextSize = 20
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Parent = frame

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent = closeButton

	closeButton.MouseButton1Click:Connect(function()
		if welcomeGui then
			welcomeGui:Destroy()
			welcomeGui = nil
		end
	end)

	-- Auto-dismiss after 10 seconds
	task.delay(10, function()
		if welcomeGui then
			welcomeGui:Destroy()
			welcomeGui = nil
		end
	end)

	print("[Client] Welcome message displayed")
end

--[[
	Setup event handlers
]]
local function setupEventHandlers()
	-- Welcome message from server
	Events.OnClientEvent("GameState", "WelcomeMessage", function(data)
		showWelcomeMessage(data)
	end)

	-- Game state changes
	Events.OnClientEvent("GameState", "MatchStateChanged", function(data)
		local newState = data.newState
		print(`[Client] Game state: {currentGameState} -> {newState}`)
		currentGameState = newState

		-- Hide countdown when leaving lobby
		if newState ~= "Lobby" then
			hideCountdown()
		end

		-- Hide welcome message when game starts
		if newState == "Playing" and welcomeGui then
			welcomeGui:Destroy()
			welcomeGui = nil
		end

		handleStateChange(newState)
	end)

	-- Countdown started
	Events.OnClientEvent("GameState", "CountdownStarted", function(data)
		print(`[Client] Countdown started: {data.duration} seconds`)
		createCountdownUI()
		updateCountdown(data.duration)
	end)

	-- Countdown update
	Events.OnClientEvent("GameState", "CountdownUpdate", function(data)
		updateCountdown(data.remaining)
	end)

	-- ===== EFFECTS INTEGRATION =====

	-- Player took damage - trigger screen effects and camera shake
	Events.OnClientEvent("Combat", "PlayerDamaged", function(data)
		local damage = data.damage or 10
		local attacker = data.attacker

		-- Screen damage flash
		ScreenEffects.FlashDamage(math.clamp(damage / 50, 0.2, 1))

		-- Camera shake based on damage
		CameraShake.ShakeForDamage(damage)

		-- Update health for low health effects
		if data.currentHealth and data.maxHealth then
			ScreenEffects.UpdateHealth(data.currentHealth, data.maxHealth)
		end
	end)

	-- Player killed someone - show feedback
	Events.OnClientEvent("Combat", "PlayerKill", function(data)
		local victimName = data.victimName or "Enemy"
		local isHeadshot = data.isHeadshot
		local weaponName = data.weaponName
		local xpGained = data.xpGained or 100

		FeedbackNotifications.ShowKill(victimName, isHeadshot, weaponName)
		FeedbackNotifications.ShowXPGain(xpGained, isHeadshot and "Headshot Kill" or "Elimination")

		-- Camera bump for kill confirmation
		CameraShake.ShakePreset("Bump")
	end)

	-- Kill streak notification
	Events.OnClientEvent("Combat", "KillStreak", function(data)
		local streakCount = data.count or 2
		FeedbackNotifications.ShowKillStreak(streakCount)
	end)

	-- Dinosaur killed
	Events.OnClientEvent("Combat", "DinosaurKill", function(data)
		local dinoName = data.species or "Dinosaur"
		local tier = data.tier or "Common"
		local xpGained = data.xpGained or 50

		FeedbackNotifications.ShowDinoKill(dinoName, tier, xpGained)
		FeedbackNotifications.ShowXPGain(xpGained, "Dinosaur Kill")
	end)

	-- Player healed
	Events.OnClientEvent("Inventory", "ItemUsed", function(data)
		local itemType = data.itemType
		if itemType == "Bandage" or itemType == "MedKit" then
			ScreenEffects.FlashHeal()
		elseif itemType == "MiniShield" or itemType == "BigShield" then
			ScreenEffects.FlashShield()
		end
	end)

	-- Loot pickup
	Events.OnClientEvent("Inventory", "ItemPickup", function(data)
		local itemName = data.name or "Item"
		local rarity = data.rarity
		local quantity = data.quantity

		FeedbackNotifications.ShowLootPickup(itemName, rarity, quantity)
	end)

	-- Explosion nearby
	Events.OnClientEvent("Combat", "Explosion", function(data)
		local position = data.position
		local character = localPlayer.Character
		if character and position then
			local rootPart = character:FindFirstChild("HumanoidRootPart")
			if rootPart then
				local distance = (rootPart.Position - position).Magnitude
				CameraShake.ShakeForExplosion(distance)
			end
		end
	end)

	-- Dinosaur roar nearby
	Events.OnClientEvent("Dinosaur", "Roar", function(data)
		local position = data.position
		local character = localPlayer.Character
		if character and position then
			local rootPart = character:FindFirstChild("HumanoidRootPart")
			if rootPart then
				local distance = (rootPart.Position - position).Magnitude
				CameraShake.ShakeForDinosaur("Roar", distance)
			end
		end
	end)

	-- Achievement unlocked
	Events.OnClientEvent("Progression", "AchievementUnlocked", function(data)
		local achievementName = data.name or "Achievement"
		local description = data.description
		FeedbackNotifications.ShowAchievement(achievementName, description)
	end)

	-- Level up
	Events.OnClientEvent("Progression", "LevelUp", function(data)
		local newLevel = data.level or 2
		FeedbackNotifications.ShowLevelUp(newLevel)
	end)

	-- XP gained
	Events.OnClientEvent("Progression", "XPGained", function(data)
		local amount = data.amount or 10
		local reason = data.reason
		FeedbackNotifications.ShowXPGain(amount, reason)
	end)

	-- Biome changed - update color grading
	Events.OnClientEvent("Map", "BiomeChanged", function(data)
		local biomeName = data.biome or "Plains"
		ScreenEffects.SetBiomeColorGrade(biomeName)
	end)

	-- Note: MatchStateChanged above handles all state transitions
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
