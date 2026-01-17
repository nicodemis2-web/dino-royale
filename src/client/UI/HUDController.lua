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
local TweenService = game:GetService("TweenService")

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
local ToastNotification: any = nil
local ConfirmDialog: any = nil
local UIHelpers: any = nil
local Crosshair: any = nil
local WorldHealthBar: any = nil

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
local crosshair: any = nil

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
	ToastNotification = require(Components.ToastNotification)
	ConfirmDialog = require(Components.ConfirmDialog)
	UIHelpers = require(script.Parent.UIHelpers)
	Crosshair = require(Components.Crosshair)
	WorldHealthBar = require(Components.WorldHealthBar)
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

	-- Weapon slots (bottom right)
	weaponSlots = WeaponSlots.new(hudGui, UDim2.new(1, -340, 1, -20))

	-- Minimap (top right)
	minimap = Minimap.new(hudGui, UDim2.new(1, -220, 0, 20))

	-- Kill feed (top right, below minimap)
	killFeed = KillFeed.new(hudGui, UDim2.new(1, -370, 0, 240), localPlayer.UserId)

	-- Match info (top center)
	matchInfo = MatchInfo.new(hudGui, UDim2.new(0.5, 0, 0, 10))

	-- Damage indicators (fullscreen)
	damageIndicator = DamageIndicator.new(hudGui)

	-- Crosshair (center screen)
	crosshair = Crosshair.new(hudGui)

	-- Interaction prompt (bottom center, above weapon slots)
	interactionPrompt = InteractionPrompt.new(hudGui, UDim2.new(0.5, 0, 1, -100))

	-- Inventory screen (separate ScreenGui)
	inventoryScreen = InventoryScreen.new(playerGui, 20)

	-- Start world health bar update loop
	WorldHealthBar.StartUpdateLoop()
end

--[[
	Setup event listeners
]]
local function setupEvents()
	-- Player health updates
	local healthConn = Events.OnClientEvent("Combat", "HealthUpdate", function(data)
		if healthDisplay then
			healthDisplay:Update(data.health, data.maxHealth, data.armor or 0, data.maxArmor or 100)
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

	-- Note: Weapon slot updates and ammo updates are handled through Inventory.InventoryUpdate
	-- The following functionality is now integrated there:
	-- - Weapon equipped/unequipped -> Updates weapon slots from inventory.weapons
	-- - Ammo update -> Updates ammo display from inventory.weapons and inventory.ammo

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

	-- Storm update (from GameState category)
	local stormUpdateConn = Events.OnClientEvent("GameState", "StormUpdate", function(data)
		if matchInfo then
			matchInfo:UpdateStormTimer(data.timeRemaining)
		end
		if minimap then
			if data.center and data.radius then
				minimap:SetStormCircle(data.center, data.radius)
			end
			if data.nextRadius then
				minimap:SetSafeZone(data.center, data.nextRadius)
			end
		end
	end)
	table.insert(connections, stormUpdateConn)

	-- Damage taken from storm (via DamageTaken with sourceType check)
	-- Note: Storm damage is handled in DamageTaken listener above via sourceType field

	-- Note: Interaction prompts are handled via Roblox ProximityPrompt instances
	-- which fire local events on the client, not through remote events

	-- Inventory updates (main weapon/ammo data source)
	local inventoryConn = Events.OnClientEvent("Inventory", "InventoryUpdate", function(data)
		print("[HUDController] Received inventory update")

		if inventoryScreen then
			inventoryScreen:SetItems(data)
		end

		-- Update weapon slots from inventory data
		if weaponSlots and data and data.weapons then
			print("[HUDController] Updating weapon slots with " .. tostring(#data.weapons) .. " potential weapons")
			-- Clear and repopulate all slots
			for slot = 1, 5 do
				local weaponData = data.weapons[slot]
				if weaponData then
					print("[HUDController] Slot " .. slot .. ": " .. tostring(weaponData.id) .. " (" .. tostring(weaponData.rarity) .. ")")
					weaponSlots:SetSlot(slot, {
						weaponId = weaponData.id,
						weaponName = weaponData.id,
						rarity = weaponData.rarity,
						ammo = weaponData.currentAmmo or 0,
						maxAmmo = 30,
						icon = "",
					})
				else
					weaponSlots:ClearSlot(slot)
				end
			end
		else
			print("[HUDController] No weapon data in inventory update")
		end

		-- Update ammo display for currently selected weapon
		if ammoDisplay and data.weapons and data.currentWeaponSlot then
			local currentWeapon = data.weapons[data.currentWeaponSlot]
			if currentWeapon then
				-- Get reserve ammo from inventory ammo pool
				local WeaponData = require(game.ReplicatedStorage.Shared.Config.WeaponData)
				local ammoType = WeaponData.GetAmmoType(currentWeapon.id)
				local reserveAmmo = ammoType and data.ammo and data.ammo[ammoType] or currentWeapon.reserveAmmo or 0
				ammoDisplay:Update(currentWeapon.currentAmmo, 30, reserveAmmo)
			else
				ammoDisplay:Update(0, 0, 0)
			end
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
	Handle game state changes with smooth transitions
]]
function HUDController.OnGameStateChanged(newState: string)
	local previousState = currentGameState
	currentGameState = newState

	print(`[HUDController] State changed: {previousState} -> {newState}`)

	-- Transition duration
	local FADE_DURATION = 0.2

	if newState == "Lobby" then
		-- Show full HUD in lobby (for testing and immediate gameplay)
		HUDController.SetHUDVisible(true, FADE_DURATION)
		if ammoDisplay then
			ammoDisplay:SetVisible(true)
		end
		if weaponSlots then
			weaponSlots.frame.Visible = true
		end

	elseif newState == "Loading" then
		HUDController.SetHUDVisible(false, FADE_DURATION)
		if ToastNotification then
			ToastNotification.Info("Loading match...")
		end

	elseif newState == "Deploying" then
		-- Show minimal HUD during deployment with fade
		HUDController.SetHUDVisible(true, FADE_DURATION)
		if ammoDisplay then
			ammoDisplay:SetVisible(false)
		end
		if weaponSlots then
			weaponSlots.frame.Visible = false
		end
		if ToastNotification then
			ToastNotification.Info("Get ready to deploy!")
		end

	elseif newState == "Playing" then
		HUDController.SetHUDVisible(true, FADE_DURATION)
		if ammoDisplay then
			ammoDisplay:SetVisible(true)
		end
		if weaponSlots then
			weaponSlots.frame.Visible = true
		end
		if ToastNotification then
			ToastNotification.Success("Match started - Good luck!")
		end

	elseif newState == "Ending" then
		-- Keep HUD visible for results
		if ToastNotification then
			ToastNotification.Info("Match ended")
		end

	elseif newState == "Spectating" then
		if ToastNotification then
			ToastNotification.Info("You are now spectating")
		end
	end
end

--[[
	Set overall HUD visibility with optional fade transition
	@param visible Whether to show or hide
	@param fadeDuration Optional fade duration (instant if nil)
]]
function HUDController.SetHUDVisible(visible: boolean, fadeDuration: number?)
	isHUDVisible = visible

	if not hudGui then
		return
	end

	if not fadeDuration or fadeDuration <= 0 then
		-- Instant visibility change
		hudGui.Enabled = visible
		return
	end

	if visible then
		-- Fade in
		hudGui.Enabled = true

		-- Fade all direct children
		for _, child in ipairs(hudGui:GetChildren()) do
			if child:IsA("GuiObject") then
				-- Store original transparency if not stored
				local originalTransparency = child:GetAttribute("OriginalTransparency")
				if originalTransparency == nil then
					if child:IsA("Frame") then
						child:SetAttribute("OriginalTransparency", child.BackgroundTransparency)
					end
				end

				-- Start transparent
				if child:IsA("Frame") then
					child.BackgroundTransparency = 1
				end

				-- Fade in
				TweenService:Create(child, TweenInfo.new(fadeDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					BackgroundTransparency = originalTransparency or 0,
				}):Play()
			end
		end
	else
		-- Fade out
		local fadeTween: Tween? = nil

		for _, child in ipairs(hudGui:GetChildren()) do
			if child:IsA("GuiObject") and child:IsA("Frame") then
				-- Store original transparency
				child:SetAttribute("OriginalTransparency", child.BackgroundTransparency)

				-- Fade out
				fadeTween = TweenService:Create(child, TweenInfo.new(fadeDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					BackgroundTransparency = 1,
				})
				fadeTween:Play()
			end
		end

		-- Disable after fade completes
		if fadeTween then
			-- Use Once to avoid connection leak on repeated fade operations
			fadeTween.Completed:Once(function()
				if not isHUDVisible and hudGui then
					hudGui.Enabled = false
				end
			end)
		else
			hudGui.Enabled = false
		end
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
	elseif name == "Crosshair" then
		return crosshair
	elseif name == "WorldHealthBar" then
		return WorldHealthBar
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

	-- Initialize toast and dialog systems
	if ToastNotification then
		ToastNotification.Initialize()
	end
	if ConfirmDialog then
		ConfirmDialog.Initialize()
	end

	-- Start with HUD visible for immediate feedback
	-- Individual components will be shown/hidden based on game state
	HUDController.SetHUDVisible(true)

	-- Show crosshair immediately
	if crosshair then
		crosshair:SetVisible(true)
	end

	-- Show health display immediately
	if healthDisplay then
		healthDisplay:Update(100, 100, 0, 100)
	end

	-- Show weapon slots and ammo display immediately (for testing and Lobby state)
	if weaponSlots then
		weaponSlots.frame.Visible = true
	end
	if ammoDisplay then
		ammoDisplay:SetVisible(true)
	end

	isInitialized = true
	print("[HUDController] Initialized - HUD visible with all components")
end

--[[
	Show a toast notification (convenience method)
	@param message The message to display
	@param toastType Type: "success", "error", "warning", "info"
	@param duration Optional duration in seconds
]]
function HUDController.ShowToast(message: string, toastType: string?, duration: number?)
	if not ToastNotification then
		return
	end

	ToastNotification.Show({
		message = message,
		toastType = toastType or "info",
		duration = duration,
	})
end

--[[
	Show a confirmation dialog
	@param config Dialog configuration
]]
function HUDController.ShowConfirmDialog(config: {
	title: string?,
	message: string,
	confirmText: string?,
	cancelText: string?,
	confirmColor: Color3?,
	onConfirm: (() -> ())?,
	onCancel: (() -> ())?,
})
	if not ConfirmDialog then
		return
	end

	ConfirmDialog.Show(config)
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

	-- Stop world health bar updates
	if WorldHealthBar then
		WorldHealthBar.StopUpdateLoop()
		WorldHealthBar.ClearAll()
	end

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
	if crosshair then
		crosshair:Destroy()
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
