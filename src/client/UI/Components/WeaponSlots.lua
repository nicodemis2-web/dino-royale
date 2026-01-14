--!strict
--[[
	WeaponSlots.lua
	===============
	Weapon hotbar display
	Shows equipped weapons and selection state
]]

local TweenService = game:GetService("TweenService")

local WeaponSlots = {}
WeaponSlots.__index = WeaponSlots

-- Display settings
local SLOT_SIZE = 60
local SLOT_SPACING = 5
local MAX_SLOTS = 5
local SELECTION_SCALE = 1.15

-- Colors
local SLOT_BACKGROUND = Color3.fromRGB(40, 40, 40)
local SLOT_BORDER = Color3.fromRGB(80, 80, 80)
local SELECTED_BORDER = Color3.fromRGB(255, 200, 50)
local EMPTY_TEXT_COLOR = Color3.fromRGB(100, 100, 100)

-- Rarity colors
local RARITY_COLORS = {
	Common = Color3.fromRGB(180, 180, 180),
	Uncommon = Color3.fromRGB(50, 200, 50),
	Rare = Color3.fromRGB(50, 150, 255),
	Epic = Color3.fromRGB(180, 50, 255),
	Legendary = Color3.fromRGB(255, 150, 50),
}

export type SlotData = {
	weaponId: string?,
	weaponName: string?,
	rarity: string?,
	ammo: number?,
	maxAmmo: number?,
	icon: string?,
}

export type WeaponSlotsInstance = {
	frame: Frame,
	slots: { Frame },
	slotData: { SlotData },
	selectedSlot: number,

	SetSlot: (self: WeaponSlotsInstance, index: number, data: SlotData?) -> (),
	SelectSlot: (self: WeaponSlotsInstance, index: number) -> (),
	UpdateAmmo: (self: WeaponSlotsInstance, index: number, ammo: number) -> (),
	ClearSlot: (self: WeaponSlotsInstance, index: number) -> (),
	ClearAll: (self: WeaponSlotsInstance) -> (),
	Destroy: (self: WeaponSlotsInstance) -> (),
}

--[[
	Create a new weapon slots display
	@param parent Parent GUI element
	@param position UDim2 position
	@return WeaponSlotsInstance
]]
function WeaponSlots.new(parent: GuiObject, position: UDim2): WeaponSlotsInstance
	local self = setmetatable({}, WeaponSlots) :: any

	-- State
	self.selectedSlot = 1
	self.slotData = {}
	self.slots = {}

	-- Calculate total width
	local totalWidth = (SLOT_SIZE * MAX_SLOTS) + (SLOT_SPACING * (MAX_SLOTS - 1))

	-- Main frame
	self.frame = Instance.new("Frame")
	self.frame.Name = "WeaponSlots"
	self.frame.Position = position
	self.frame.Size = UDim2.fromOffset(totalWidth, SLOT_SIZE)
	self.frame.AnchorPoint = Vector2.new(0.5, 1)
	self.frame.BackgroundTransparency = 1
	self.frame.Parent = parent

	-- Create slots
	for i = 1, MAX_SLOTS do
		local slot = self:CreateSlot(i)
		self.slots[i] = slot
		self.slotData[i] = {}
	end

	-- Select first slot
	self:SelectSlot(1)

	return self
end

--[[
	Create a single weapon slot
]]
function WeaponSlots:CreateSlot(index: number): Frame
	local x = (index - 1) * (SLOT_SIZE + SLOT_SPACING)

	local slot = Instance.new("Frame")
	slot.Name = `Slot{index}`
	slot.Position = UDim2.fromOffset(x, 0)
	slot.Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE)
	slot.BackgroundColor3 = SLOT_BACKGROUND
	slot.BorderSizePixel = 0
	slot.Parent = self.frame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = slot

	-- Border (using UIStroke)
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Border"
	stroke.Color = SLOT_BORDER
	stroke.Thickness = 2
	stroke.Parent = slot

	-- Rarity indicator bar at top
	local rarityBar = Instance.new("Frame")
	rarityBar.Name = "RarityBar"
	rarityBar.Position = UDim2.fromOffset(4, 4)
	rarityBar.Size = UDim2.new(1, -8, 0, 3)
	rarityBar.BackgroundColor3 = RARITY_COLORS.Common
	rarityBar.BorderSizePixel = 0
	rarityBar.Visible = false
	rarityBar.Parent = slot

	local rarityCorner = Instance.new("UICorner")
	rarityCorner.CornerRadius = UDim.new(0, 2)
	rarityCorner.Parent = rarityBar

	-- Weapon icon
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.Position = UDim2.fromOffset(5, 10)
	icon.Size = UDim2.new(1, -10, 1, -25)
	icon.BackgroundTransparency = 1
	icon.Image = ""
	icon.ImageColor3 = Color3.new(1, 1, 1)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = slot

	-- Ammo counter
	local ammoLabel = Instance.new("TextLabel")
	ammoLabel.Name = "AmmoLabel"
	ammoLabel.Position = UDim2.new(0, 4, 1, -18)
	ammoLabel.Size = UDim2.new(1, -8, 0, 16)
	ammoLabel.BackgroundTransparency = 1
	ammoLabel.Text = ""
	ammoLabel.TextColor3 = Color3.new(1, 1, 1)
	ammoLabel.TextSize = 12
	ammoLabel.Font = Enum.Font.GothamBold
	ammoLabel.TextXAlignment = Enum.TextXAlignment.Center
	ammoLabel.Parent = slot

	-- Slot number
	local numberLabel = Instance.new("TextLabel")
	numberLabel.Name = "NumberLabel"
	numberLabel.Position = UDim2.fromOffset(4, 4)
	numberLabel.Size = UDim2.fromOffset(14, 14)
	numberLabel.BackgroundTransparency = 1
	numberLabel.Text = tostring(index)
	numberLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
	numberLabel.TextSize = 10
	numberLabel.Font = Enum.Font.GothamBold
	numberLabel.Parent = slot

	-- Empty text
	local emptyLabel = Instance.new("TextLabel")
	emptyLabel.Name = "EmptyLabel"
	emptyLabel.Size = UDim2.fromScale(1, 1)
	emptyLabel.BackgroundTransparency = 1
	emptyLabel.Text = ""
	emptyLabel.TextColor3 = EMPTY_TEXT_COLOR
	emptyLabel.TextSize = 10
	emptyLabel.Font = Enum.Font.Gotham
	emptyLabel.Parent = slot

	return slot
end

--[[
	Set weapon data for a slot
]]
function WeaponSlots:SetSlot(index: number, data: SlotData?)
	if index < 1 or index > MAX_SLOTS then
		return
	end

	local slot = self.slots[index]
	if not slot then
		return
	end

	self.slotData[index] = data or {}

	local icon = slot:FindFirstChild("Icon") :: ImageLabel?
	local ammoLabel = slot:FindFirstChild("AmmoLabel") :: TextLabel?
	local rarityBar = slot:FindFirstChild("RarityBar") :: Frame?
	local emptyLabel = slot:FindFirstChild("EmptyLabel") :: TextLabel?

	if data and data.weaponId then
		-- Show weapon
		if icon then
			icon.Image = data.icon or ""
			icon.Visible = true
		end

		if ammoLabel and data.ammo then
			ammoLabel.Text = tostring(data.ammo)
			ammoLabel.Visible = true
		end

		if rarityBar and data.rarity then
			rarityBar.BackgroundColor3 = RARITY_COLORS[data.rarity] or RARITY_COLORS.Common
			rarityBar.Visible = true
		end

		if emptyLabel then
			emptyLabel.Visible = false
		end
	else
		-- Empty slot
		if icon then
			icon.Image = ""
			icon.Visible = false
		end

		if ammoLabel then
			ammoLabel.Visible = false
		end

		if rarityBar then
			rarityBar.Visible = false
		end

		if emptyLabel then
			emptyLabel.Text = ""
			emptyLabel.Visible = true
		end
	end
end

--[[
	Select a slot
]]
function WeaponSlots:SelectSlot(index: number)
	if index < 1 or index > MAX_SLOTS then
		return
	end

	-- Deselect previous
	local prevSlot = self.slots[self.selectedSlot]
	if prevSlot then
		local stroke = prevSlot:FindFirstChild("Border") :: UIStroke?
		if stroke then
			stroke.Color = SLOT_BORDER
			stroke.Thickness = 2
		end

		-- Animate scale down
		TweenService:Create(prevSlot, TweenInfo.new(0.1), {
			Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE),
		}):Play()
	end

	self.selectedSlot = index

	-- Select new
	local newSlot = self.slots[index]
	if newSlot then
		local stroke = newSlot:FindFirstChild("Border") :: UIStroke?
		if stroke then
			stroke.Color = SELECTED_BORDER
			stroke.Thickness = 3
		end

		-- Animate scale up
		local scaledSize = math.floor(SLOT_SIZE * SELECTION_SCALE)
		TweenService:Create(newSlot, TweenInfo.new(0.1), {
			Size = UDim2.fromOffset(scaledSize, scaledSize),
		}):Play()
	end
end

--[[
	Update ammo for a slot
]]
function WeaponSlots:UpdateAmmo(index: number, ammo: number)
	if index < 1 or index > MAX_SLOTS then
		return
	end

	local slot = self.slots[index]
	if not slot then
		return
	end

	if self.slotData[index] then
		self.slotData[index].ammo = ammo
	end

	local ammoLabel = slot:FindFirstChild("AmmoLabel") :: TextLabel?
	if ammoLabel then
		ammoLabel.Text = tostring(ammo)

		-- Flash if low
		if self.slotData[index] and self.slotData[index].maxAmmo then
			local maxAmmo = self.slotData[index].maxAmmo :: number
			if ammo <= maxAmmo * 0.25 then
				ammoLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
			elseif ammo == 0 then
				ammoLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
			else
				ammoLabel.TextColor3 = Color3.new(1, 1, 1)
			end
		end
	end
end

--[[
	Clear a single slot
]]
function WeaponSlots:ClearSlot(index: number)
	self:SetSlot(index, nil)
end

--[[
	Clear all slots
]]
function WeaponSlots:ClearAll()
	for i = 1, MAX_SLOTS do
		self:ClearSlot(i)
	end
end

--[[
	Destroy the display
]]
function WeaponSlots:Destroy()
	self.frame:Destroy()
end

return WeaponSlots
