--!strict
--[[
	InventoryScreen.lua
	==================
	Full inventory management UI
	Shows backpack contents, equipment, and allows reorganization
]]

local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")

local InventoryScreen = {}
InventoryScreen.__index = InventoryScreen

-- Display settings
local SCREEN_PADDING = 50
local SLOT_SIZE = 70
local SLOT_SPACING = 8
local GRID_COLUMNS = 5

-- Colors
local BACKGROUND_COLOR = Color3.fromRGB(20, 20, 20)
local SLOT_COLOR = Color3.fromRGB(40, 40, 40)
local SELECTED_COLOR = Color3.fromRGB(60, 60, 60)
local HOVER_COLOR = Color3.fromRGB(50, 50, 50)

-- Rarity colors
local RARITY_COLORS = {
	Common = Color3.fromRGB(180, 180, 180),
	Uncommon = Color3.fromRGB(50, 200, 50),
	Rare = Color3.fromRGB(50, 150, 255),
	Epic = Color3.fromRGB(180, 50, 255),
	Legendary = Color3.fromRGB(255, 150, 50),
}

-- Category colors
local CATEGORY_COLORS = {
	Weapons = Color3.fromRGB(255, 100, 100),
	Healing = Color3.fromRGB(100, 255, 100),
	Ammo = Color3.fromRGB(255, 200, 100),
	Equipment = Color3.fromRGB(100, 200, 255),
	Materials = Color3.fromRGB(200, 150, 100),
}

export type ItemData = {
	id: string,
	name: string,
	category: string,
	rarity: string?,
	quantity: number?,
	maxStack: number?,
	icon: string?,
	description: string?,
}

export type InventoryScreenInstance = {
	screenGui: ScreenGui,
	mainFrame: Frame,
	slots: { Frame },
	items: { [number]: ItemData },
	selectedSlot: number?,
	hoveredSlot: number?,
	isOpen: boolean,
	connections: { RBXScriptConnection },
	instanceId: string,
	onItemSelect: ((ItemData?, number) -> ())?,
	onItemDrop: ((ItemData, number) -> ())?,
	onItemUse: ((ItemData, number) -> ())?,

	Open: (self: InventoryScreenInstance) -> (),
	Close: (self: InventoryScreenInstance) -> (),
	Toggle: (self: InventoryScreenInstance) -> (),
	SetItems: (self: InventoryScreenInstance, items: { [number]: ItemData }) -> (),
	UpdateSlot: (self: InventoryScreenInstance, slotIndex: number, item: ItemData?) -> (),
	SelectSlot: (self: InventoryScreenInstance, slotIndex: number?) -> (),
	Destroy: (self: InventoryScreenInstance) -> (),
}

--[[
	Create new inventory screen
	@param playerGui PlayerGui to parent to
	@param slotCount Number of inventory slots
	@return InventoryScreenInstance
]]
function InventoryScreen.new(playerGui: PlayerGui, slotCount: number?): InventoryScreenInstance
	local self = setmetatable({}, InventoryScreen) :: any

	-- State
	local totalSlots = slotCount or 20
	self.slots = {}
	self.items = {}
	self.selectedSlot = nil
	self.hoveredSlot = nil
	self.isOpen = false
	self.connections = {}
	self.instanceId = tostring(math.random(100000, 999999))
	self.onItemSelect = nil
	self.onItemDrop = nil
	self.onItemUse = nil

	-- Screen GUI
	self.screenGui = Instance.new("ScreenGui")
	self.screenGui.Name = "InventoryScreen"
	self.screenGui.ResetOnSpawn = false
	self.screenGui.Enabled = false
	self.screenGui.DisplayOrder = 100
	self.screenGui.Parent = playerGui

	-- Blur background
	local blur = Instance.new("Frame")
	blur.Name = "Blur"
	blur.Size = UDim2.fromScale(1, 1)
	blur.BackgroundColor3 = Color3.new(0, 0, 0)
	blur.BackgroundTransparency = 0.5
	blur.Parent = self.screenGui

	blur.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			self:Close()
		end
	end)

	-- Main frame
	local gridWidth = (SLOT_SIZE * GRID_COLUMNS) + (SLOT_SPACING * (GRID_COLUMNS - 1))
	local gridRows = math.ceil(totalSlots / GRID_COLUMNS)
	local gridHeight = (SLOT_SIZE * gridRows) + (SLOT_SPACING * (gridRows - 1))

	self.mainFrame = Instance.new("Frame")
	self.mainFrame.Name = "MainFrame"
	self.mainFrame.Position = UDim2.fromScale(0.5, 0.5)
	self.mainFrame.Size = UDim2.fromOffset(gridWidth + 40, gridHeight + 100)
	self.mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	self.mainFrame.BackgroundColor3 = BACKGROUND_COLOR
	self.mainFrame.BorderSizePixel = 0
	self.mainFrame.Parent = self.screenGui

	local mainCorner = Instance.new("UICorner")
	mainCorner.CornerRadius = UDim.new(0, 12)
	mainCorner.Parent = self.mainFrame

	-- Title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Position = UDim2.fromOffset(20, 15)
	titleLabel.Size = UDim2.new(1, -40, 0, 30)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "INVENTORY"
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextSize = 24
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = self.mainFrame

	-- Close button
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "Close"
	closeButton.Position = UDim2.new(1, -45, 0, 15)
	closeButton.Size = UDim2.fromOffset(30, 30)
	closeButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
	closeButton.Text = "X"
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.TextSize = 16
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Parent = self.mainFrame

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 6)
	closeCorner.Parent = closeButton

	closeButton.MouseButton1Click:Connect(function()
		self:Close()
	end)

	-- Grid container
	local gridFrame = Instance.new("Frame")
	gridFrame.Name = "Grid"
	gridFrame.Position = UDim2.fromOffset(20, 55)
	gridFrame.Size = UDim2.fromOffset(gridWidth, gridHeight)
	gridFrame.BackgroundTransparency = 1
	gridFrame.Parent = self.mainFrame

	-- Create slots
	for i = 1, totalSlots do
		local slot = self:CreateSlot(i, gridFrame)
		self.slots[i] = slot
	end

	-- Item info panel
	local infoPanel = Instance.new("Frame")
	infoPanel.Name = "InfoPanel"
	infoPanel.Position = UDim2.new(0, 20, 1, -40)
	infoPanel.Size = UDim2.new(1, -40, 0, 30)
	infoPanel.BackgroundTransparency = 1
	infoPanel.Parent = self.mainFrame

	local infoLabel = Instance.new("TextLabel")
	infoLabel.Name = "Info"
	infoLabel.Size = UDim2.fromScale(1, 1)
	infoLabel.BackgroundTransparency = 1
	infoLabel.Text = "Select an item to view details"
	infoLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
	infoLabel.TextSize = 14
	infoLabel.Font = Enum.Font.Gotham
	infoLabel.TextXAlignment = Enum.TextXAlignment.Left
	infoLabel.Parent = infoPanel

	-- Input handling
	self:SetupInput()

	return self
end

--[[
	Create a single inventory slot
]]
function InventoryScreen:CreateSlot(index: number, parent: Frame): Frame
	local row = math.floor((index - 1) / GRID_COLUMNS)
	local col = (index - 1) % GRID_COLUMNS

	local x = col * (SLOT_SIZE + SLOT_SPACING)
	local y = row * (SLOT_SIZE + SLOT_SPACING)

	local slot = Instance.new("Frame")
	slot.Name = `Slot{index}`
	slot.Position = UDim2.fromOffset(x, y)
	slot.Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE)
	slot.BackgroundColor3 = SLOT_COLOR
	slot.BorderSizePixel = 0
	slot.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = slot

	-- Rarity border
	local rarityStroke = Instance.new("UIStroke")
	rarityStroke.Name = "RarityStroke"
	rarityStroke.Color = Color3.fromRGB(60, 60, 60)
	rarityStroke.Thickness = 2
	rarityStroke.Transparency = 0.5
	rarityStroke.Parent = slot

	-- Item icon
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.Position = UDim2.fromOffset(5, 5)
	icon.Size = UDim2.new(1, -10, 1, -25)
	icon.BackgroundTransparency = 1
	icon.Image = ""
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = slot

	-- Quantity label
	local quantityLabel = Instance.new("TextLabel")
	quantityLabel.Name = "Quantity"
	quantityLabel.Position = UDim2.new(0, 4, 1, -18)
	quantityLabel.Size = UDim2.new(1, -8, 0, 16)
	quantityLabel.BackgroundTransparency = 1
	quantityLabel.Text = ""
	quantityLabel.TextColor3 = Color3.new(1, 1, 1)
	quantityLabel.TextSize = 12
	quantityLabel.Font = Enum.Font.GothamBold
	quantityLabel.TextXAlignment = Enum.TextXAlignment.Right
	quantityLabel.Parent = slot

	-- Slot number (small)
	local numberLabel = Instance.new("TextLabel")
	numberLabel.Name = "Number"
	numberLabel.Position = UDim2.fromOffset(4, 4)
	numberLabel.Size = UDim2.fromOffset(12, 12)
	numberLabel.BackgroundTransparency = 1
	numberLabel.Text = tostring(index)
	numberLabel.TextColor3 = Color3.fromRGB(100, 100, 100)
	numberLabel.TextSize = 10
	numberLabel.Font = Enum.Font.Gotham
	numberLabel.Parent = slot

	-- Hover/click detection
	local button = Instance.new("TextButton")
	button.Name = "Button"
	button.Size = UDim2.fromScale(1, 1)
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Parent = slot

	button.MouseEnter:Connect(function()
		self.hoveredSlot = index
		if index ~= self.selectedSlot then
			slot.BackgroundColor3 = HOVER_COLOR
		end
		self:UpdateInfoPanel(index)
	end)

	button.MouseLeave:Connect(function()
		self.hoveredSlot = nil
		if index ~= self.selectedSlot then
			slot.BackgroundColor3 = SLOT_COLOR
		end
	end)

	button.MouseButton1Click:Connect(function()
		self:SelectSlot(index)
	end)

	button.MouseButton2Click:Connect(function()
		-- Right click to use/drop
		local item = self.items[index]
		if item then
			self:ShowContextMenu(index, item)
		end
	end)

	return slot
end

--[[
	Setup keyboard input
]]
function InventoryScreen:SetupInput()
	local toggleActionName = `InventoryToggle_{self.instanceId}`
	local closeActionName = `InventoryClose_{self.instanceId}`

	ContextActionService:BindAction(toggleActionName, function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			self:Toggle()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.Tab, Enum.KeyCode.I)

	ContextActionService:BindAction(closeActionName, function(_, inputState)
		if inputState == Enum.UserInputState.Begin and self.isOpen then
			self:Close()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.Escape)
end

--[[
	Open the inventory
]]
function InventoryScreen:Open()
	if self.isOpen then
		return
	end

	self.isOpen = true
	self.screenGui.Enabled = true

	-- Animate in
	self.mainFrame.Position = UDim2.new(0.5, 0, 0.6, 0)
	TweenService:Create(self.mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, 0.5),
	}):Play()
end

--[[
	Close the inventory
]]
function InventoryScreen:Close()
	if not self.isOpen then
		return
	end

	self.isOpen = false
	self:SelectSlot(nil)

	-- Animate out
	TweenService:Create(self.mainFrame, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.new(0.5, 0, 0.6, 0),
	}):Play()

	task.delay(0.15, function()
		if not self.isOpen then
			self.screenGui.Enabled = false
		end
	end)
end

--[[
	Toggle inventory
]]
function InventoryScreen:Toggle()
	if self.isOpen then
		self:Close()
	else
		self:Open()
	end
end

--[[
	Set all items
]]
function InventoryScreen:SetItems(items: { [number]: ItemData })
	self.items = items

	for i, slot in ipairs(self.slots) do
		self:UpdateSlotVisual(i, items[i])
	end
end

--[[
	Update a single slot
]]
function InventoryScreen:UpdateSlot(slotIndex: number, item: ItemData?)
	self.items[slotIndex] = item
	self:UpdateSlotVisual(slotIndex, item)
end

--[[
	Update slot visual
]]
function InventoryScreen:UpdateSlotVisual(slotIndex: number, item: ItemData?)
	local slot = self.slots[slotIndex]
	if not slot then
		return
	end

	local icon = slot:FindFirstChild("Icon") :: ImageLabel?
	local quantityLabel = slot:FindFirstChild("Quantity") :: TextLabel?
	local rarityStroke = slot:FindFirstChild("RarityStroke") :: UIStroke?

	if item then
		if icon then
			icon.Image = item.icon or ""
			icon.Visible = true
		end

		if quantityLabel then
			if item.quantity and item.quantity > 1 then
				quantityLabel.Text = tostring(item.quantity)
				quantityLabel.Visible = true
			else
				quantityLabel.Visible = false
			end
		end

		if rarityStroke and item.rarity then
			rarityStroke.Color = RARITY_COLORS[item.rarity] or Color3.fromRGB(60, 60, 60)
			rarityStroke.Transparency = 0
		end
	else
		if icon then
			icon.Image = ""
			icon.Visible = false
		end

		if quantityLabel then
			quantityLabel.Visible = false
		end

		if rarityStroke then
			rarityStroke.Color = Color3.fromRGB(60, 60, 60)
			rarityStroke.Transparency = 0.5
		end
	end
end

--[[
	Select a slot
]]
function InventoryScreen:SelectSlot(slotIndex: number?)
	-- Deselect previous
	if self.selectedSlot then
		local prevSlot = self.slots[self.selectedSlot]
		if prevSlot then
			prevSlot.BackgroundColor3 = SLOT_COLOR
		end
	end

	self.selectedSlot = slotIndex

	-- Select new
	if slotIndex then
		local newSlot = self.slots[slotIndex]
		if newSlot then
			newSlot.BackgroundColor3 = SELECTED_COLOR
		end

		local item = self.items[slotIndex]
		if self.onItemSelect then
			self.onItemSelect(item, slotIndex)
		end
	end

	self:UpdateInfoPanel(slotIndex)
end

--[[
	Update info panel
]]
function InventoryScreen:UpdateInfoPanel(slotIndex: number?)
	local infoPanel = self.mainFrame:FindFirstChild("InfoPanel")
	if not infoPanel then
		return
	end

	local infoLabel = infoPanel:FindFirstChild("Info") :: TextLabel?
	if not infoLabel then
		return
	end

	if slotIndex and self.items[slotIndex] then
		local item = self.items[slotIndex]
		local text = item.name
		if item.description then
			text = text .. " - " .. item.description
		end
		infoLabel.Text = text
		infoLabel.TextColor3 = RARITY_COLORS[item.rarity or "Common"] or Color3.new(1, 1, 1)
	else
		infoLabel.Text = "Select an item to view details"
		infoLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
	end
end

--[[
	Show context menu for slot
]]
function InventoryScreen:ShowContextMenu(slotIndex: number, item: ItemData)
	-- Simple implementation - just use the item
	if self.onItemUse then
		self.onItemUse(item, slotIndex)
	end
end

--[[
	Destroy the screen
]]
function InventoryScreen:Destroy()
	-- Disconnect all connections
	for _, conn in ipairs(self.connections) do
		conn:Disconnect()
	end
	self.connections = {}

	-- Unbind actions
	ContextActionService:UnbindAction(`InventoryToggle_{self.instanceId}`)
	ContextActionService:UnbindAction(`InventoryClose_{self.instanceId}`)

	self.screenGui:Destroy()
end

return InventoryScreen
