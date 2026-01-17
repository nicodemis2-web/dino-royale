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
local _isInitialized = false
local currentGameState = "Loading"

--[[
	Safely require a module with error handling
]]
local function safeRequire(module, name: string): any
	local success, result = pcall(function()
		return require(module)
	end)
	if success then
		print(`[Client] Loaded: {name}`)
		return result
	else
		warn(`[Client] FAILED to load {name}: {result}`)
		return nil
	end
end

--[[
	Load all client modules
]]
local function loadModules()
	print("[Client] Loading modules...")

	local Controllers = script.Parent.Controllers
	local UI = script.Parent.UI
	local Audio = script.Parent.Audio

	-- Controllers
	WeaponController = safeRequire(Controllers.WeaponController, "WeaponController")
	InventoryController = safeRequire(Controllers.InventoryController, "InventoryController")
	VehicleController = safeRequire(Controllers.VehicleController, "VehicleController")
	DeploymentController = safeRequire(Controllers.DeploymentController, "DeploymentController")
	MovementController = safeRequire(Controllers.MovementController, "MovementController")
	SpectatorController = safeRequire(Controllers.SpectatorController, "SpectatorController")
	StormController = safeRequire(Controllers.StormController, "StormController")

	-- UI
	HUDController = safeRequire(UI.HUDController, "HUDController")
	MinimapController = safeRequire(UI.Map.MinimapController, "MinimapController")
	RevivalUI = safeRequire(UI.Revival.RevivalUI, "RevivalUI")
	LootUI = safeRequire(UI.Inventory.LootUI, "LootUI")
	VictoryScreen = safeRequire(UI.Components.VictoryScreen, "VictoryScreen")
	LobbyScreen = safeRequire(UI.Components.LobbyScreen, "LobbyScreen")
	Compass = safeRequire(UI.Components.Compass, "Compass")
	BattlePassUI = safeRequire(UI.Components.BattlePassUI, "BattlePassUI")
	ShopUI = safeRequire(UI.Components.ShopUI, "ShopUI")
	TutorialUI = safeRequire(UI.Components.TutorialUI, "TutorialUI")
	PartyUI = safeRequire(UI.Components.PartyUI, "PartyUI")
	RankedUI = safeRequire(UI.Components.RankedUI, "RankedUI")
	AccessibilityUI = safeRequire(UI.Components.AccessibilityUI, "AccessibilityUI")
	DinosaurTargeting = safeRequire(UI.Components.DinosaurTargeting, "DinosaurTargeting")

	-- Audio
	AudioController = safeRequire(Audio.AudioController, "AudioController")

	-- Effects
	local Effects = script.Parent.Effects
	CameraShake = safeRequire(Effects.CameraShake, "CameraShake")
	ScreenEffects = safeRequire(Effects.ScreenEffects, "ScreenEffects")

	-- Additional UI components
	local Components = UI.Components
	FeedbackNotifications = safeRequire(Components.FeedbackNotifications, "FeedbackNotifications")

	print("[Client] Modules loaded")
end

--[[
	Safely initialize a module with error handling
]]
local function safeInit(module: any, name: string)
	if not module then
		warn(`[Client] Cannot initialize {name} - module not loaded`)
		return
	end
	if not module.Initialize then
		warn(`[Client] {name} has no Initialize function`)
		return
	end
	local success, err = pcall(function()
		module.Initialize()
	end)
	if success then
		print(`[Client] Initialized: {name}`)
	else
		warn(`[Client] FAILED to initialize {name}: {err}`)
	end
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

	-- Initialize in order with error handling
	safeInit(AudioController, "AudioController")
	safeInit(HUDController, "HUDController")
	safeInit(MinimapController, "MinimapController")
	safeInit(RevivalUI, "RevivalUI")
	safeInit(LootUI, "LootUI")
	safeInit(VictoryScreen, "VictoryScreen")
	safeInit(LobbyScreen, "LobbyScreen")
	safeInit(Compass, "Compass")
	safeInit(WeaponController, "WeaponController")
	safeInit(InventoryController, "InventoryController")
	safeInit(VehicleController, "VehicleController")
	safeInit(DeploymentController, "DeploymentController")
	safeInit(MovementController, "MovementController")
	safeInit(SpectatorController, "SpectatorController")
	safeInit(StormController, "StormController")
	safeInit(BattlePassUI, "BattlePassUI")
	safeInit(ShopUI, "ShopUI")
	safeInit(TutorialUI, "TutorialUI")
	safeInit(PartyUI, "PartyUI")
	safeInit(RankedUI, "RankedUI")
	safeInit(AccessibilityUI, "AccessibilityUI")
	safeInit(DinosaurTargeting, "DinosaurTargeting")

	-- Initialize effects systems
	safeInit(CameraShake, "CameraShake")
	safeInit(ScreenEffects, "ScreenEffects")
	safeInit(FeedbackNotifications, "FeedbackNotifications")

	print("[Client] Systems initialized")
end

--[[
	Handle game state changes
]]
local function handleStateChange(newState: string)
	if newState == "Lobby" then
		-- Show lobby UI
		if HUDController then
			HUDController.OnGameStateChanged("Lobby")
		end

	elseif newState == "Loading" then
		-- Loading screen
		if HUDController then
			HUDController.OnGameStateChanged("Loading")
		end

	elseif newState == "Deploying" then
		-- Start deployment
		if HUDController then
			HUDController.OnGameStateChanged("Deploying")
		end
		if DeploymentController then
			DeploymentController.Enable()
		end

	elseif newState == "Playing" then
		-- Full gameplay
		if HUDController then
			HUDController.OnGameStateChanged("Playing")
		end
		if DeploymentController then
			DeploymentController.Disable()
		end
		if MovementController then
			MovementController.Enable()
		end
		if WeaponController then
			WeaponController.SetEnabled(true)
		end

	elseif newState == "Ending" then
		-- Match results
		if HUDController then
			HUDController.OnGameStateChanged("Ending")
		end
		if MovementController then
			MovementController.Disable()
		end
		if WeaponController then
			WeaponController.SetEnabled(false)
		end

	elseif newState == "Spectating" then
		-- Spectator mode
		if WeaponController then
			WeaponController.SetEnabled(false)
		end
		-- Enable spectator camera
	end
end

--[[
	Handle local player death
]]
local function _handleDeath(_data: any)
	if WeaponController then
		WeaponController.Disable()
	end
	if VehicleController then
		VehicleController.Cleanup()
	end

	-- Play death sound
	if AudioController then
		AudioController.PlayUISound("Death")
	end

	-- Show elimination UI
end

--[[
	Handle local player respawn
]]
local function _handleRespawn()
	if WeaponController then
		WeaponController.Enable()
	end

	-- Play respawn sound
	if AudioController then
		AudioController.PlayUISound("Heal")
	end
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
	frame.Size = UDim2.fromOffset(300, 150)
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
	title.Size = UDim2.fromScale(1, 0.4)
	title.Position = UDim2.fromOffset(0, 0)
	title.BackgroundTransparency = 1
	title.Text = "MATCH STARTING IN"
	title.TextColor3 = Color3.fromRGB(255, 200, 50)
	title.TextSize = 24
	title.Font = Enum.Font.GothamBold
	title.Parent = frame

	countdownLabel = Instance.new("TextLabel")
	countdownLabel.Name = "Countdown"
	countdownLabel.Size = UDim2.fromScale(1, 0.6)
	countdownLabel.Position = UDim2.fromScale(0, 0.4)
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
	frame.Size = UDim2.fromOffset(500, 400)
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
	title.Position = UDim2.fromOffset(0, 20)
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
	message.Position = UDim2.fromOffset(20, 80)
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
	controlsLabel.Position = UDim2.fromOffset(0, 140)
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
	controlsFrame.Position = UDim2.fromOffset(30, 175)
	controlsFrame.BackgroundTransparency = 1
	controlsFrame.Parent = frame

	local listLayout = Instance.new("UIGridLayout")
	listLayout.CellSize = UDim2.new(0.5, -10, 0, 25)
	listLayout.CellPadding = UDim2.fromOffset(10, 5)
	listLayout.Parent = controlsFrame

	if data.controls then
		for _, ctrl in ipairs(data.controls) do
			local ctrlLabel = Instance.new("TextLabel")
			ctrlLabel.Size = UDim2.fromOffset(200, 25)
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
	closeButton.Size = UDim2.fromOffset(200, 50)
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
	Events.OnClientEvent("Combat", "DamageTaken", function(data)
		local damage = data.amount or 10

		-- Screen damage flash
		if ScreenEffects then
			ScreenEffects.FlashDamage(math.clamp(damage / 50, 0.2, 1))
		end

		-- Camera shake based on damage
		if CameraShake then
			CameraShake.ShakeForDamage(damage)
		end

		-- Update health for low health effects
		if ScreenEffects and data.health and data.maxHealth then
			ScreenEffects.UpdateHealth(data.health, data.maxHealth)
		end
	end)

	-- Player killed someone - show feedback
	Events.OnClientEvent("Combat", "PlayerKill", function(data)
		local victimName = data.victimName or "Enemy"
		local isHeadshot = data.isHeadshot
		local weaponName = data.weaponName
		local xpGained = data.xpGained or 100

		if FeedbackNotifications then
			FeedbackNotifications.ShowKill(victimName, isHeadshot, weaponName)
			FeedbackNotifications.ShowXPGain(xpGained, isHeadshot and "Headshot Kill" or "Elimination")
		end

		-- Camera bump for kill confirmation
		if CameraShake then
			CameraShake.ShakePreset("Bump")
		end
	end)

	-- Kill streak notification
	Events.OnClientEvent("Combat", "KillStreak", function(data)
		local streakCount = data.count or 2
		if FeedbackNotifications then
			FeedbackNotifications.ShowKillStreak(streakCount)
		end
	end)

	-- Dinosaur killed
	Events.OnClientEvent("Combat", "DinosaurKill", function(data)
		local dinoName = data.species or "Dinosaur"
		local tier = data.tier or "Common"
		local xpGained = data.xpGained or 50

		if FeedbackNotifications then
			FeedbackNotifications.ShowDinoKill(dinoName, tier, xpGained)
			FeedbackNotifications.ShowXPGain(xpGained, "Dinosaur Kill")
		end
	end)

	-- Player healed
	Events.OnClientEvent("Inventory", "ItemUsed", function(data)
		local itemType = data.itemType
		if ScreenEffects then
			if itemType == "Bandage" or itemType == "MedKit" then
				ScreenEffects.FlashHeal()
			elseif itemType == "MiniShield" or itemType == "BigShield" then
				ScreenEffects.FlashShield()
			end
		end
	end)

	-- Loot pickup
	Events.OnClientEvent("Inventory", "ItemPickup", function(data)
		local itemName = data.name or "Item"
		local rarity = data.rarity
		local quantity = data.quantity

		if FeedbackNotifications then
			FeedbackNotifications.ShowLootPickup(itemName, rarity, quantity)
		end
	end)

	-- Explosion nearby
	Events.OnClientEvent("Combat", "Explosion", function(data)
		local position = data.position
		local character = localPlayer.Character
		if character and position and CameraShake then
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
		if character and position and CameraShake then
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
		if FeedbackNotifications then
			FeedbackNotifications.ShowAchievement(achievementName, description)
		end
	end)

	-- Level up
	Events.OnClientEvent("Progression", "LevelUp", function(data)
		local newLevel = data.level or 2
		if FeedbackNotifications then
			FeedbackNotifications.ShowLevelUp(newLevel)
		end
	end)

	-- XP gained
	Events.OnClientEvent("Progression", "XPGained", function(data)
		local amount = data.amount or 10
		local reason = data.reason
		if FeedbackNotifications then
			FeedbackNotifications.ShowXPGain(amount, reason)
		end
	end)

	-- Biome changed - update color grading
	Events.OnClientEvent("Map", "BiomeChanged", function(data)
		local biomeName = data.biome or "Plains"
		if ScreenEffects then
			ScreenEffects.SetBiomeColorGrade(biomeName)
		end
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

	_isInitialized = true

	print("[Client] Ready!")
	print("==========================================")
end

-- Run
main()
