--!strict
--[[
	InventoryUI.lua
	===============
	Client-side inventory interface
	Weapon slots HUD, full inventory screen, ground loot panel
]]

local Players = game:GetService("Players")
local _TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")

local Events = require(game.ReplicatedStorage.Shared.Events)
local WeaponData = require(game.ReplicatedStorage.Shared.Config.WeaponData)
local ItemData = require(game.ReplicatedStorage.Shared.Config.ItemData)

local InventoryUI = {}

-- Local player reference
local localPlayer = Players.LocalPlayer
local playerGui: PlayerGui = nil

-- UI Elements
local mainGui: ScreenGui = nil
local weaponSlotsFrame: Frame = nil
local fullInventoryFrame: Frame = nil
local tooltipFrame: Frame = nil

-- State
local isInventoryOpen = false
local currentInventory: any = nil
local weaponSlotButtons = {} :: { [number]: Frame }
local currentSlot = 1

-- Connections for cleanup
local connections: { RBXScriptConnection } = {}

-- Rarity colors
local RARITY_COLORS = {
	Common = Color3.fromRGB(150, 150, 150),
	Uncommon = Color3.fromRGB(50, 200, 50),
	Rare = Color3.fromRGB(50, 100, 255),
	Epic = Color3.fromRGB(150, 50, 255),
	Legendary = Color3.fromRGB(255, 200, 50),
}

--[[
	Initialize the inventory UI
]]
function InventoryUI.Initialize()
	playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

	-- Create main GUI
	InventoryUI.CreateMainGUI()

	-- Create weapon slots HUD
	InventoryUI.CreateWeaponSlotsHUD()

	-- Create full inventory screen
	InventoryUI.CreateFullInventoryScreen()

	-- Create tooltip
	InventoryUI.CreateTooltip()

	-- Listen for inventory updates
	local eventConn = Events.OnClientEvent("Inventory", "InventoryUpdate", function(data)
		InventoryUI.OnInventoryUpdate(data)
	end)
	table.insert(connections, eventConn)

	-- Bind toggle key using ContextActionService
	ContextActionService:BindAction("ToggleInventory", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			InventoryUI.ToggleFullInventory()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.Tab, Enum.KeyCode.I)
end

--[[
	Create the main screen GUI
]]
function InventoryUI.CreateMainGUI()
	mainGui = Instance.new("ScreenGui")
	mainGui.Name = "InventoryUI"
	mainGui.ResetOnSpawn = false
	mainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	mainGui.Parent = playerGui
end

--[[
	Create weapon slots HUD (always visible at bottom of screen)
]]
function InventoryUI.CreateWeaponSlotsHUD()
	weaponSlotsFrame = Instance.new("Frame")
	weaponSlotsFrame.Name = "WeaponSlots"
	weaponSlotsFrame.AnchorPoint = Vector2.new(0.5, 1)
	weaponSlotsFrame.Position = UDim2.new(0.5, 0, 1, -20)
	weaponSlotsFrame.Size = UDim2.fromOffset(400, 80)
	weaponSlotsFrame.BackgroundTransparency = 1
	weaponSlotsFrame.Parent = mainGui

	-- Layout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.Parent = weaponSlotsFrame

	-- Create 5 weapon slots
	for i = 1, 5 do
		local slot = InventoryUI.CreateWeaponSlot(i)
		slot.Parent = weaponSlotsFrame
		weaponSlotButtons[i] = slot
	end
end

--[[
	Create a single weapon slot
	@param slotNumber The slot number (1-5)
	@return The slot frame
]]
function InventoryUI.CreateWeaponSlot(slotNumber: number): Frame
	local slot = Instance.new("Frame")
	slot.Name = `Slot{slotNumber}`
	slot.Size = UDim2.fromOffset(70, 70)
	slot.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	slot.BackgroundTransparency = 0.3
	slot.BorderSizePixel = 0

	-- Rounded corners
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = slot

	-- Border stroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(80, 80, 80)
	stroke.Thickness = 2
	stroke.Parent = slot

	-- Weapon icon (placeholder)
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.4)
	icon.Size = UDim2.fromOffset(40, 40)
	icon.BackgroundTransparency = 1
	icon.Image = ""
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = slot

	-- Weapon name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "WeaponName"
	nameLabel.AnchorPoint = Vector2.new(0.5, 1)
	nameLabel.Position = UDim2.new(0.5, 0, 1, -18)
	nameLabel.Size = UDim2.new(1, -8, 0, 14)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = ""
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextSize = 10
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Parent = slot

	-- Ammo counter
	local ammoLabel = Instance.new("TextLabel")
	ammoLabel.Name = "Ammo"
	ammoLabel.AnchorPoint = Vector2.new(0.5, 1)
	ammoLabel.Position = UDim2.new(0.5, 0, 1, -4)
	ammoLabel.Size = UDim2.new(1, -8, 0, 12)
	ammoLabel.BackgroundTransparency = 1
	ammoLabel.Text = ""
	ammoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	ammoLabel.TextSize = 10
	ammoLabel.Font = Enum.Font.Gotham
	ammoLabel.Parent = slot

	-- Slot number
	local slotLabel = Instance.new("TextLabel")
	slotLabel.Name = "SlotNumber"
	slotLabel.Position = UDim2.fromOffset(4, 4)
	slotLabel.Size = UDim2.fromOffset(16, 16)
	slotLabel.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	slotLabel.Text = tostring(slotNumber)
	slotLabel.TextColor3 = Color3.new(1, 1, 1)
	slotLabel.TextSize = 12
	slotLabel.Font = Enum.Font.GothamBold
	slotLabel.Parent = slot

	local slotCorner = Instance.new("UICorner")
	slotCorner.CornerRadius = UDim.new(0, 4)
	slotCorner.Parent = slotLabel

	-- Click handler
	local button = Instance.new("TextButton")
	button.Name = "Button"
	button.Size = UDim2.fromScale(1, 1)
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Parent = slot

	button.MouseButton1Click:Connect(function()
		InventoryUI.SelectSlot(slotNumber)
	end)

	return slot
end

--[[
	Create full inventory screen (toggled with Tab)
]]
function InventoryUI.CreateFullInventoryScreen()
	fullInventoryFrame = Instance.new("Frame")
	fullInventoryFrame.Name = "FullInventory"
	fullInventoryFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	fullInventoryFrame.Position = UDim2.fromScale(0.5, 0.5)
	fullInventoryFrame.Size = UDim2.fromOffset(600, 400)
	fullInventoryFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	fullInventoryFrame.BackgroundTransparency = 0.1
	fullInventoryFrame.BorderSizePixel = 0
	fullInventoryFrame.Visible = false
	fullInventoryFrame.Parent = mainGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = fullInventoryFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(100, 100, 100)
	stroke.Thickness = 2
	stroke.Parent = fullInventoryFrame

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Position = UDim2.fromOffset(20, 15)
	title.Size = UDim2.new(1, -40, 0, 30)
	title.BackgroundTransparency = 1
	title.Text = "INVENTORY"
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextSize = 20
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = fullInventoryFrame

	-- Weapons section
	local weaponsSection = Instance.new("Frame")
	weaponsSection.Name = "WeaponsSection"
	weaponsSection.Position = UDim2.fromOffset(20, 60)
	weaponsSection.Size = UDim2.new(0.5, -30, 0, 150)
	weaponsSection.BackgroundTransparency = 1
	weaponsSection.Parent = fullInventoryFrame

	local weaponsTitle = Instance.new("TextLabel")
	weaponsTitle.Position = UDim2.fromOffset(0, 0)
	weaponsTitle.Size = UDim2.new(1, 0, 0, 20)
	weaponsTitle.BackgroundTransparency = 1
	weaponsTitle.Text = "Weapons"
	weaponsTitle.TextColor3 = Color3.fromRGB(180, 180, 180)
	weaponsTitle.TextSize = 14
	weaponsTitle.Font = Enum.Font.GothamBold
	weaponsTitle.TextXAlignment = Enum.TextXAlignment.Left
	weaponsTitle.Parent = weaponsSection

	-- Consumables section
	local consumablesSection = Instance.new("Frame")
	consumablesSection.Name = "ConsumablesSection"
	consumablesSection.Position = UDim2.new(0.5, 10, 0, 60)
	consumablesSection.Size = UDim2.new(0.5, -30, 0, 150)
	consumablesSection.BackgroundTransparency = 1
	consumablesSection.Parent = fullInventoryFrame

	local consumablesTitle = Instance.new("TextLabel")
	consumablesTitle.Position = UDim2.fromOffset(0, 0)
	consumablesTitle.Size = UDim2.new(1, 0, 0, 20)
	consumablesTitle.BackgroundTransparency = 1
	consumablesTitle.Text = "Consumables"
	consumablesTitle.TextColor3 = Color3.fromRGB(180, 180, 180)
	consumablesTitle.TextSize = 14
	consumablesTitle.Font = Enum.Font.GothamBold
	consumablesTitle.TextXAlignment = Enum.TextXAlignment.Left
	consumablesTitle.Parent = consumablesSection

	-- Ammo section
	local ammoSection = Instance.new("Frame")
	ammoSection.Name = "AmmoSection"
	ammoSection.Position = UDim2.fromOffset(20, 230)
	ammoSection.Size = UDim2.new(1, -40, 0, 150)
	ammoSection.BackgroundTransparency = 1
	ammoSection.Parent = fullInventoryFrame

	local ammoTitle = Instance.new("TextLabel")
	ammoTitle.Position = UDim2.fromOffset(0, 0)
	ammoTitle.Size = UDim2.new(1, 0, 0, 20)
	ammoTitle.BackgroundTransparency = 1
	ammoTitle.Text = "Ammunition"
	ammoTitle.TextColor3 = Color3.fromRGB(180, 180, 180)
	ammoTitle.TextSize = 14
	ammoTitle.Font = Enum.Font.GothamBold
	ammoTitle.TextXAlignment = Enum.TextXAlignment.Left
	ammoTitle.Parent = ammoSection

	-- Close button
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "Close"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -10, 0, 10)
	closeButton.Size = UDim2.fromOffset(30, 30)
	closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	closeButton.Text = "X"
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.TextSize = 16
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Parent = fullInventoryFrame

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 6)
	closeCorner.Parent = closeButton

	closeButton.MouseButton1Click:Connect(function()
		InventoryUI.ToggleFullInventory()
	end)
end

--[[
	Create tooltip for item hover
]]
function InventoryUI.CreateTooltip()
	tooltipFrame = Instance.new("Frame")
	tooltipFrame.Name = "Tooltip"
	tooltipFrame.Size = UDim2.fromOffset(200, 120)
	tooltipFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	tooltipFrame.BackgroundTransparency = 0.1
	tooltipFrame.BorderSizePixel = 0
	tooltipFrame.Visible = false
	tooltipFrame.ZIndex = 100
	tooltipFrame.Parent = mainGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = tooltipFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(100, 100, 100)
	stroke.Thickness = 1
	stroke.Parent = tooltipFrame

	-- Item name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Position = UDim2.fromOffset(10, 10)
	nameLabel.Size = UDim2.new(1, -20, 0, 20)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = "Item Name"
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextSize = 14
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.ZIndex = 101
	nameLabel.Parent = tooltipFrame

	-- Rarity
	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "Rarity"
	rarityLabel.Position = UDim2.fromOffset(10, 32)
	rarityLabel.Size = UDim2.new(1, -20, 0, 16)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text = "Common"
	rarityLabel.TextColor3 = RARITY_COLORS.Common
	rarityLabel.TextSize = 12
	rarityLabel.Font = Enum.Font.Gotham
	rarityLabel.TextXAlignment = Enum.TextXAlignment.Left
	rarityLabel.ZIndex = 101
	rarityLabel.Parent = tooltipFrame

	-- Stats
	local statsLabel = Instance.new("TextLabel")
	statsLabel.Name = "Stats"
	statsLabel.Position = UDim2.fromOffset(10, 55)
	statsLabel.Size = UDim2.new(1, -20, 0, 60)
	statsLabel.BackgroundTransparency = 1
	statsLabel.Text = "Damage: 30\nFire Rate: 5.5"
	statsLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	statsLabel.TextSize = 11
	statsLabel.Font = Enum.Font.Gotham
	statsLabel.TextXAlignment = Enum.TextXAlignment.Left
	statsLabel.TextYAlignment = Enum.TextYAlignment.Top
	statsLabel.ZIndex = 101
	statsLabel.Parent = tooltipFrame
end

--[[
	Handle inventory update from server
	@param data Inventory data
]]
function InventoryUI.OnInventoryUpdate(data: any)
	currentInventory = data

	-- Update weapon slots HUD
	InventoryUI.UpdateWeaponSlots(data.weapons, data.currentWeaponSlot)

	-- Update full inventory if open
	if isInventoryOpen then
		InventoryUI.UpdateFullInventory(data)
	end
end

--[[
	Update weapon slots display
	@param weapons Weapon data array
	@param selectedSlot Currently selected slot
]]
function InventoryUI.UpdateWeaponSlots(weapons: { [number]: any }?, selectedSlot: number)
	currentSlot = selectedSlot or 1

	for i = 1, 5 do
		local slot = weaponSlotButtons[i]
		if not slot then
			continue
		end

		local weaponData = weapons and weapons[i]
		local stroke = slot:FindFirstChildOfClass("UIStroke")
		local icon = slot:FindFirstChild("Icon") :: ImageLabel?
		local nameLabel = slot:FindFirstChild("WeaponName") :: TextLabel?
		local ammoLabel = slot:FindFirstChild("Ammo") :: TextLabel?

		if weaponData then
			-- Has weapon
			local weaponDef = WeaponData.GetWeapon(weaponData.id)

			if nameLabel then
				nameLabel.Text = weaponDef and weaponDef.name or weaponData.id
			end

			if ammoLabel then
				ammoLabel.Text = `{weaponData.currentAmmo}/{weaponData.reserveAmmo}`
			end

			-- Set rarity color
			local rarityColor = RARITY_COLORS[weaponData.rarity] or RARITY_COLORS.Common
			if stroke then
				stroke.Color = rarityColor
			end

			slot.BackgroundTransparency = 0.3
		else
			-- Empty slot
			if nameLabel then
				nameLabel.Text = ""
			end
			if ammoLabel then
				ammoLabel.Text = ""
			end
			if stroke then
				stroke.Color = Color3.fromRGB(60, 60, 60)
			end
			slot.BackgroundTransparency = 0.6
		end

		-- Highlight selected slot
		if i == currentSlot then
			slot.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
			if stroke then
				stroke.Thickness = 3
			end
		else
			slot.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
			if stroke then
				stroke.Thickness = 2
			end
		end
	end
end

--[[
	Update full inventory display
	@param data Full inventory data
]]
function InventoryUI.UpdateFullInventory(data: any)
	-- Update consumables display
	local consumablesSection = fullInventoryFrame:FindFirstChild("ConsumablesSection")
	if consumablesSection then
		-- Clear existing
		for _, child in ipairs(consumablesSection:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end

		-- Add consumable items
		local yOffset = 25
		if data.consumables then
			for itemId, count in pairs(data.consumables) do
				local itemFrame = InventoryUI.CreateConsumableSlot(itemId, count)
				itemFrame.Position = UDim2.fromOffset(0, yOffset)
				itemFrame.Parent = consumablesSection
				yOffset = yOffset + 35
			end
		end
	end

	-- Update ammo display
	local ammoSection = fullInventoryFrame:FindFirstChild("AmmoSection")
	if ammoSection then
		-- Clear existing
		for _, child in ipairs(ammoSection:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end

		-- Add ammo types
		local xOffset = 0
		if data.ammo then
			for ammoType, count in pairs(data.ammo) do
				if count > 0 then
					local ammoFrame = InventoryUI.CreateAmmoDisplay(ammoType, count)
					ammoFrame.Position = UDim2.fromOffset(xOffset, 25)
					ammoFrame.Parent = ammoSection
					xOffset = xOffset + 110
				end
			end
		end
	end
end

--[[
	Create a consumable slot display
	@param itemId The item ID
	@param count Item count
	@return The slot frame
]]
function InventoryUI.CreateConsumableSlot(itemId: string, count: number): Frame
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 30)
	frame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
	frame.BackgroundTransparency = 0.5

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = frame

	local itemDef = ItemData.GetItem(itemId)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Position = UDim2.fromOffset(10, 0)
	nameLabel.Size = UDim2.new(1, -60, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = itemDef and itemDef.name or itemId
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextSize = 12
	nameLabel.Font = Enum.Font.Gotham
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = frame

	local countLabel = Instance.new("TextLabel")
	countLabel.AnchorPoint = Vector2.new(1, 0.5)
	countLabel.Position = UDim2.new(1, -10, 0.5, 0)
	countLabel.Size = UDim2.fromOffset(40, 20)
	countLabel.BackgroundTransparency = 1
	countLabel.Text = `x{count}`
	countLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	countLabel.TextSize = 12
	countLabel.Font = Enum.Font.GothamBold
	countLabel.TextXAlignment = Enum.TextXAlignment.Right
	countLabel.Parent = frame

	-- Double-click to use
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromScale(1, 1)
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Parent = frame

	local lastClick = 0
	button.MouseButton1Click:Connect(function()
		local now = tick()
		if now - lastClick < 0.3 then
			-- Double click - use item
			Events.FireServer("Inventory", "UseItem", { itemId = itemId })
		end
		lastClick = now
	end)

	return frame
end

--[[
	Create ammo display
	@param ammoType The ammo type
	@param count Ammo count
	@return The display frame
]]
function InventoryUI.CreateAmmoDisplay(ammoType: string, count: number): Frame
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(100, 50)
	frame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
	frame.BackgroundTransparency = 0.5

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	local ammoDef = ItemData.Ammo[ammoType]

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Position = UDim2.fromOffset(8, 5)
	nameLabel.Size = UDim2.new(1, -16, 0, 16)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = ammoDef and ammoDef.name or ammoType
	nameLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	nameLabel.TextSize = 10
	nameLabel.Font = Enum.Font.Gotham
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = frame

	local countLabel = Instance.new("TextLabel")
	countLabel.Position = UDim2.fromOffset(8, 25)
	countLabel.Size = UDim2.new(1, -16, 0, 20)
	countLabel.BackgroundTransparency = 1
	countLabel.Text = tostring(count)
	countLabel.TextColor3 = Color3.new(1, 1, 1)
	countLabel.TextSize = 18
	countLabel.Font = Enum.Font.GothamBold
	countLabel.TextXAlignment = Enum.TextXAlignment.Left
	countLabel.Parent = frame

	return frame
end

--[[
	Select a weapon slot
	@param slot The slot number
]]
function InventoryUI.SelectSlot(slot: number)
	currentSlot = slot

	-- Update visuals
	if currentInventory then
		InventoryUI.UpdateWeaponSlots(currentInventory.weapons, slot)
	end

	-- Could notify weapon controller here
end

--[[
	Toggle full inventory screen
]]
function InventoryUI.ToggleFullInventory()
	isInventoryOpen = not isInventoryOpen
	fullInventoryFrame.Visible = isInventoryOpen

	if isInventoryOpen and currentInventory then
		InventoryUI.UpdateFullInventory(currentInventory)
	end
end

--[[
	Show tooltip for an item
	@param itemType The item type
	@param itemId The item ID
	@param rarity Optional rarity
	@param position Screen position
]]
function InventoryUI.ShowTooltip(itemType: string, itemId: string, rarity: string?, position: Vector2)
	local nameLabel = tooltipFrame:FindFirstChild("Name") :: TextLabel?
	local rarityLabel = tooltipFrame:FindFirstChild("Rarity") :: TextLabel?
	local statsLabel = tooltipFrame:FindFirstChild("Stats") :: TextLabel?

	if itemType == "Weapon" then
		local weaponDef = WeaponData.GetWeapon(itemId)
		if weaponDef and nameLabel and rarityLabel and statsLabel then
			nameLabel.Text = weaponDef.name
			rarityLabel.Text = rarity or "Common"
			rarityLabel.TextColor3 = RARITY_COLORS[rarity or "Common"] or RARITY_COLORS.Common

			local stats = WeaponData.GetStatsWithRarity(itemId, (rarity or "Common") :: any)
			if stats then
				statsLabel.Text = `Damage: {math.floor(stats.damage)}\nFire Rate: {stats.fireRate}/s\nMag Size: {stats.magSize}\nReload: {stats.reloadTime}s`
			end
		end
	else
		local itemDef = ItemData.GetItem(itemId)
		if itemDef and nameLabel and statsLabel then
			nameLabel.Text = itemDef.name
			if rarityLabel then
				rarityLabel.Text = ""
			end
			statsLabel.Text = ""
		end
	end

	tooltipFrame.Position = UDim2.fromOffset(position.X + 15, position.Y + 15)
	tooltipFrame.Visible = true
end

--[[
	Hide tooltip
]]
function InventoryUI.HideTooltip()
	tooltipFrame.Visible = false
end

--[[
	Check if inventory is open
	@return Whether inventory screen is open
]]
function InventoryUI.IsOpen(): boolean
	return isInventoryOpen
end

--[[
	Cleanup the UI
]]
function InventoryUI.Cleanup()
	-- Disconnect all connections
	for _, conn in ipairs(connections) do
		conn:Disconnect()
	end
	connections = {}

	-- Unbind context actions
	ContextActionService:UnbindAction("ToggleInventory")

	-- Destroy GUI
	if mainGui then
		mainGui:Destroy()
	end
end

return InventoryUI
