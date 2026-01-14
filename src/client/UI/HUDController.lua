--!strict
--[[
	HUDController.lua
	=================
	Main HUD manager that coordinates all UI components
	Handles visibility, state changes, and event routing
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Events = require(game.ReplicatedStorage.Shared.Events)

-- Import components (lazy loaded)
local HealthDisplay: any = nil
local AmmoDisplay: any = nil
local WeaponSlots: any = nil
local Minimap: any = nil
local KillFeed: any = nil
local MatchInfo: any = nil
local DamageIndicator: any = nil
local InteractionPrompt: any = nil
local InventoryScreen: any = nil

local HUDController = {}

-- Local player
local localPlayer = Players.LocalPlayer

-- Component instances
local healthDisplay: any = nil
local ammoDisplay: any = nil
local weaponSlots: any = nil
local minimap: any = nil
local killFeed: any = nil
local matchInfo: any = nil
local damageIndicator: any = nil
local interactionPrompt: any = nil
local inventoryScreen: any = nil

-- Main HUD ScreenGui
local hudGui: ScreenGui? = nil

-- State
local isInitialized = false
local isHUDVisible = true
local currentGameState = "Lobby"

-- Connections
local connections = {} :: { RBXScriptConnection }

--[[
	Load component modules
]]
local function loadComponents()
	local Components = script.Parent.Components

	HealthDisplay = require(Components.HealthDisplay)
	AmmoDisplay = require(Components.AmmoDisplay)
	WeaponSlots = require(Components.WeaponSlots)
	Minimap = require(Components.Minimap)
	KillFeed = require(Components.KillFeed)
	MatchInfo = require(Components.MatchInfo)
	DamageIndicator = require(Components.DamageIndicator)
	InteractionPrompt = require(Components.InteractionPrompt)
	InventoryScreen = require(Components.InventoryScreen)
end

--[[
	Create the main HUD screen
]]
local function createHUDScreen()
	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

	hudGui = Instance.new("ScreenGui")
	hudGui.Name = "GameHUD"
	hudGui.ResetOnSpawn = false
	hudGui.IgnoreGuiInset = true
	hudGui.DisplayOrder = 10
	hudGui.Parent = playerGui

	return hudGui
end

--[[
	Create all HUD components
]]
local function createComponents()
	if not hudGui then
		return
	end

	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

	-- Health display (bottom left)
	healthDisplay = HealthDisplay.new(hudGui, UDim2.new(0, 20, 1, -30))

	-- Ammo display (bottom right)
	ammoDisplay = AmmoDisplay.new(hudGui, UDim2.new(1, -170, 1, -70))

	-- Weapon slots (bottom center)
	weaponSlots = WeaponSlots.new(hudGui, UDim2.new(0.5, 0, 1, -20))

	-- Minimap (top right)
	minimap = Minimap.new(hudGui, UDim2.new(1, -220, 0, 20))

	-- Kill feed (top right, below minimap)
	killFeed = KillFeed.new(hudGui, UDim2.new(1, -370, 0, 240), localPlayer.UserId)

	-- Match info (top center)
	matchInfo = MatchInfo.new(hudGui, UDim2.new(0.5, 0, 0, 10))

	-- Damage indicators (fullscreen)
	damageIndicator = DamageIndicator.new(hudGui)

	-- Interaction prompt (bottom center, above weapon slots)
	interactionPrompt = InteractionPrompt.new(hudGui, UDim2.new(0.5, 0, 1, -100))

	-- Inventory screen (separate ScreenGui)
	inventoryScreen = InventoryScreen.new(playerGui, 20)
end

--[[
	Setup event listeners
]]
local function setupEvents()
	-- Player health updates
	local healthConn = Events.OnClientEvent("Player", "HealthUpdate", function(data)
		if healthDisplay then
			healthDisplay:Update(data.health, data.maxHealth, data.shield, data.maxShield)
		end
	end)
	table.insert(connections, healthConn)

	-- Damage taken
	local damageConn = Events.OnClientEvent("Combat", "DamageTaken", function(data)
		if healthDisplay then
			healthDisplay:ShowDamage(data.amount)
		end
		if damageIndicator and data.sourcePosition then
			damageIndicator:ShowDamageFrom(data.sourcePosition, data.amount)
		end
	end)
	table.insert(connections, damageConn)

	-- Heal received
	local healConn = Events.OnClientEvent("Combat", "HealReceived", function(data)
		if healthDisplay then
			healthDisplay:ShowHeal(data.amount)
		end
	end)
	table.insert(connections, healConn)

	-- Weapon equipped
	local equipConn = Events.OnClientEvent("Weapon", "Equipped", function(data)
		if weaponSlots then
			weaponSlots:SetSlot(data.slotIndex, {
				weaponId = data.weaponId,
				weaponName = data.weaponName,
				rarity = data.rarity,
				ammo = data.currentAmmo,
				maxAmmo = data.maxAmmo,
				icon = data.icon,
			})
			weaponSlots:SelectSlot(data.slotIndex)
		end
	end)
	table.insert(connections, equipConn)

	-- Weapon unequipped
	local unequipConn = Events.OnClientEvent("Weapon", "Unequipped", function(data)
		if weaponSlots then
			weaponSlots:ClearSlot(data.slotIndex)
		end
	end)
	table.insert(connections, unequipConn)

	-- Ammo update
	local ammoConn = Events.OnClientEvent("Weapon", "AmmoUpdate", function(data)
		if ammoDisplay then
			ammoDisplay:Update(data.currentMag, data.maxMag, data.reserve)
		end
		if weaponSlots then
			weaponSlots:UpdateAmmo(data.slotIndex, data.currentMag)
		end
	end)
	table.insert(connections, ammoConn)

	-- Reload start
	local reloadStartConn = Events.OnClientEvent("Weapon", "ReloadStart", function(data)
		if ammoDisplay then
			ammoDisplay:StartReload(data.duration)
		end
	end)
	table.insert(connections, reloadStartConn)

	-- Reload cancel
	local reloadCancelConn = Events.OnClientEvent("Weapon", "ReloadCancel", function()
		if ammoDisplay then
			ammoDisplay:CancelReload()
		end
	end)
	table.insert(connections, reloadCancelConn)

	-- Hit marker
	local hitConn = Events.OnClientEvent("Combat", "HitConfirm", function(data)
		if damageIndicator then
			damageIndicator:ShowHitMarker(data.isHeadshot, data.isKill)
		end
	end)
	table.insert(connections, hitConn)

	-- Kill event
	local killConn = Events.OnClientEvent("Combat", "PlayerKilled", function(data)
		if killFeed then
			killFeed:AddKill({
				killerName = data.killerName,
				killerId = data.killerId,
				victimName = data.victimName,
				victimId = data.victimId,
				weapon = data.weapon,
				killType = data.killType,
				isLocalKiller = data.killerId == localPlayer.UserId,
				isLocalVictim = data.victimId == localPlayer.UserId,
			})
		end

		-- Update kill count if local player got the kill
		if data.killerId == localPlayer.UserId and matchInfo then
			-- Match info will receive separate update
		end
	end)
	table.insert(connections, killConn)

	-- Dinosaur kill
	local dinoKillConn = Events.OnClientEvent("Dinosaur", "DinosaurKill", function(data)
		if killFeed then
			killFeed:AddDinosaurKill(data.dinoName, data.victimName, data.victimId)
		end
	end)
	table.insert(connections, dinoKillConn)

	-- Storm kill
	local stormKillConn = Events.OnClientEvent("Storm", "StormKill", function(data)
		if killFeed then
			killFeed:AddStormKill(data.victimName, data.victimId)
		end
	end)
	table.insert(connections, stormKillConn)

	-- Match state updates
	local matchConn = Events.OnClientEvent("GameState", "MatchUpdate", function(data)
		if matchInfo then
			if data.playersAlive then
				matchInfo:UpdatePlayersAlive(data.playersAlive)
			end
			if data.personalKills then
				matchInfo:UpdateKills(data.personalKills)
			end
		end
	end)
	table.insert(connections, matchConn)

	-- Storm timer
	local stormTimerConn = Events.OnClientEvent("Storm", "TimerUpdate", function(data)
		if matchInfo then
			matchInfo:UpdateStormTimer(data.timeRemaining)
		end
		if minimap then
			if data.stormCenter and data.stormRadius then
				minimap:SetStormCircle(data.stormCenter, data.stormRadius)
			end
			if data.safeCenter and data.safeRadius then
				minimap:SetSafeZone(data.safeCenter, data.safeRadius)
			end
		end
	end)
	table.insert(connections, stormTimerConn)

	-- Storm damage
	local stormDamageConn = Events.OnClientEvent("Storm", "StormDamage", function(data)
		if damageIndicator then
			damageIndicator:ShowStormDamage()
		end
	end)
	table.insert(connections, stormDamageConn)

	-- Interaction prompt
	local interactShowConn = Events.OnClientEvent("Interaction", "ShowPrompt", function(data)
		if interactionPrompt then
			interactionPrompt:Show({
				actionText = data.actionText,
				objectText = data.objectText,
				keyCode = data.keyCode,
				holdDuration = data.holdDuration,
				rarity = data.rarity,
			})
		end
	end)
	table.insert(connections, interactShowConn)

	local interactHideConn = Events.OnClientEvent("Interaction", "HidePrompt", function()
		if interactionPrompt then
			interactionPrompt:Hide()
		end
	end)
	table.insert(connections, interactHideConn)

	-- Inventory updates
	local inventoryConn = Events.OnClientEvent("Inventory", "Update", function(data)
		if inventoryScreen then
			inventoryScreen:SetItems(data.items)
		end
	end)
	table.insert(connections, inventoryConn)

	-- Game state changes
	local gameStateConn = Events.OnClientEvent("GameState", "StateChanged", function(data)
		HUDController.OnGameStateChanged(data.newState)
	end)
	table.insert(connections, gameStateConn)

	-- Match end
	local matchEndConn = Events.OnClientEvent("GameState", "MatchEnd", function(data)
		if matchInfo then
			if data.isWinner then
				matchInfo:ShowVictory()
			else
				matchInfo:ShowPlacement(data.placement)
			end
		end
	end)
	table.insert(connections, matchEndConn)
end

--[[
	Setup input handling
]]
local function setupInput()
	-- Minimap expand (M key)
	local expandConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.KeyCode == Enum.KeyCode.M and minimap then
			minimap:SetExpanded(true)
		end
	end)
	table.insert(connections, expandConn)

	local collapseConn = UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.M and minimap then
			minimap:SetExpanded(false)
		end
	end)
	table.insert(connections, collapseConn)

	-- Ping (middle mouse button)
	local pingConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton3 then
			-- Get world position from mouse
			local camera = workspace.CurrentCamera
			if camera then
				local mousePos = UserInputService:GetMouseLocation()
				local ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)
				local result = workspace:Raycast(ray.Origin, ray.Direction * 1000)
				if result and minimap then
					minimap:AddPing(result.Position)
				end
			end
		end
	end)
	table.insert(connections, pingConn)
end

--[[
	Update loop for minimap
]]
local function setupUpdateLoop()
	local updateConn = RunService.Heartbeat:Connect(function()
		if not isHUDVisible then
			return
		end

		-- Update minimap with player position
		if minimap and localPlayer.Character then
			local rootPart = localPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if rootPart then
				local rotation = rootPart.CFrame:ToEulerAnglesYXZ()
				minimap:Update(rootPart.Position, rotation)
			end
		end
	end)
	table.insert(connections, updateConn)
end

--[[
	Handle game state changes
]]
function HUDController.OnGameStateChanged(newState: string)
	currentGameState = newState

	if newState == "Lobby" then
		HUDController.SetHUDVisible(false)
	elseif newState == "Loading" then
		HUDController.SetHUDVisible(false)
	elseif newState == "Deploying" then
		-- Show minimal HUD during deployment
		HUDController.SetHUDVisible(true)
		if ammoDisplay then
			ammoDisplay:SetVisible(false)
		end
		if weaponSlots then
			weaponSlots.frame.Visible = false
		end
	elseif newState == "Playing" then
		HUDController.SetHUDVisible(true)
		if ammoDisplay then
			ammoDisplay:SetVisible(true)
		end
		if weaponSlots then
			weaponSlots.frame.Visible = true
		end
	elseif newState == "Ending" then
		-- Keep HUD visible for results
	end
end

--[[
	Set overall HUD visibility
]]
function HUDController.SetHUDVisible(visible: boolean)
	isHUDVisible = visible

	if hudGui then
		hudGui.Enabled = visible
	end
end

--[[
	Get a component instance
]]
function HUDController.GetComponent(name: string): any
	if name == "HealthDisplay" then
		return healthDisplay
	elseif name == "AmmoDisplay" then
		return ammoDisplay
	elseif name == "WeaponSlots" then
		return weaponSlots
	elseif name == "Minimap" then
		return minimap
	elseif name == "KillFeed" then
		return killFeed
	elseif name == "MatchInfo" then
		return matchInfo
	elseif name == "DamageIndicator" then
		return damageIndicator
	elseif name == "InteractionPrompt" then
		return interactionPrompt
	elseif name == "InventoryScreen" then
		return inventoryScreen
	end
	return nil
end

--[[
	Initialize the HUD controller
]]
function HUDController.Initialize()
	if isInitialized then
		return
	end

	loadComponents()
	createHUDScreen()
	createComponents()
	setupEvents()
	setupInput()
	setupUpdateLoop()

	-- Start with HUD hidden (lobby state)
	HUDController.SetHUDVisible(false)

	isInitialized = true
	print("[HUDController] Initialized")
end

--[[
	Cleanup
]]
function HUDController.Cleanup()
	isInitialized = false

	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	connections = {}

	-- Destroy components
	if healthDisplay then
		healthDisplay:Destroy()
	end
	if ammoDisplay then
		ammoDisplay:Destroy()
	end
	if weaponSlots then
		weaponSlots:Destroy()
	end
	if minimap then
		minimap:Destroy()
	end
	if killFeed then
		killFeed:Destroy()
	end
	if matchInfo then
		matchInfo:Destroy()
	end
	if damageIndicator then
		damageIndicator:Destroy()
	end
	if interactionPrompt then
		interactionPrompt:Destroy()
	end
	if inventoryScreen then
		inventoryScreen:Destroy()
	end

	if hudGui then
		hudGui:Destroy()
		hudGui = nil
	end
end

return HUDController
