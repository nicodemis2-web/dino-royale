--!strict
--[[
	ShopUI.lua
	==========
	Client-side Item Shop display
	Based on GDD Section 8.3: Shop Structure
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Events = require(ReplicatedStorage.Shared.Events)
local ShopData = require(ReplicatedStorage.Shared.ShopData)

local ShopUI = {}

-- State
local player = Players.LocalPlayer
local screenGui: ScreenGui? = nil
local mainFrame: Frame? = nil
local contentContainer: Frame? = nil
local isVisible = false

-- Data
local featuredItems: { any } = {}
local dailyItems: { any } = {}
local specialItems: { any } = {}
local ownedItems: { [string]: boolean } = {}
local nextRotation = 0

-- Constants
local ITEM_WIDTH = 180
local ITEM_HEIGHT = 220
local BUNDLE_WIDTH = 280

--[[
	Initialize the shop UI
]]
function ShopUI.Initialize()
	print("[ShopUI] Initializing...")

	ShopUI.CreateUI()
	ShopUI.SetupEventListeners()

	print("[ShopUI] Initialized")
end

--[[
	Create UI elements
]]
function ShopUI.CreateUI()
	local playerGui = player:WaitForChild("PlayerGui")

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ShopGui"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Enabled = false
	screenGui.Parent = playerGui

	-- Dark overlay
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.5
	overlay.BorderSizePixel = 0
	overlay.Parent = screenGui

	overlay.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			ShopUI.Hide()
		end
	end)

	-- Main container
	mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(0.9, 0, 0.9, 0)
	mainFrame.Position = UDim2.fromScale(0.5, 0.5)
	mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	mainFrame.BorderSizePixel = 0
	mainFrame.Parent = screenGui

	local mainCorner = Instance.new("UICorner")
	mainCorner.CornerRadius = UDim.new(0, 12)
	mainCorner.Parent = mainFrame

	-- Header
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 60)
	header.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	header.BorderSizePixel = 0
	header.Parent = mainFrame

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 12)
	headerCorner.Parent = header

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(0.5, 0, 1, 0)
	titleLabel.Position = UDim2.fromOffset(20, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextSize = 28
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = "ITEM SHOP"
	titleLabel.Parent = header

	-- Rotation timer
	local timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "Timer"
	timerLabel.Size = UDim2.new(0.3, 0, 1, 0)
	timerLabel.Position = UDim2.new(0.5, 0, 0, 0)
	timerLabel.BackgroundTransparency = 1
	timerLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
	timerLabel.TextSize = 14
	timerLabel.Font = Enum.Font.Gotham
	timerLabel.Text = "Resets in: 00:00:00"
	timerLabel.Parent = header

	-- Close button
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "Close"
	closeButton.Size = UDim2.fromOffset(40, 40)
	closeButton.Position = UDim2.new(1, -50, 0, 10)
	closeButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
	closeButton.BorderSizePixel = 0
	closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeButton.TextSize = 24
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Text = "X"
	closeButton.Parent = mainFrame

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeButton

	closeButton.MouseButton1Click:Connect(function()
		ShopUI.Hide()
	end)

	-- Content scroll container
	contentContainer = Instance.new("ScrollingFrame")
	contentContainer.Name = "Content"
	contentContainer.Size = UDim2.new(1, -40, 1, -80)
	contentContainer.Position = UDim2.fromOffset(20, 70)
	contentContainer.BackgroundTransparency = 1
	contentContainer.ScrollBarThickness = 8
	contentContainer.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
	contentContainer.CanvasSize = UDim2.fromOffset(0, 0)
	contentContainer.Parent = mainFrame
end

--[[
	Setup event listeners
]]
function ShopUI.SetupEventListeners()
	-- Listen for shop data updates
	Events.OnClientEvent("Shop", "DataUpdate", function(data)
		ShopUI.OnDataUpdate(data)
	end)

	-- Listen for inventory updates
	Events.OnClientEvent("Shop", "InventoryUpdate", function(data)
		ShopUI.OnInventoryUpdate(data)
	end)

	-- Listen for purchase success
	Events.OnClientEvent("Shop", "PurchaseSuccess", function(data)
		ShopUI.OnPurchaseSuccess(data)
	end)

	-- Listen for purchase failure
	Events.OnClientEvent("Shop", "PurchaseFailed", function(data)
		ShopUI.OnPurchaseFailed(data)
	end)

	-- Update timer
	task.spawn(function()
		while true do
			ShopUI.UpdateTimer()
			task.wait(1)
		end
	end)
end

--[[
	Handle data update
]]
function ShopUI.OnDataUpdate(data: any)
	featuredItems = data.featured or {}
	dailyItems = data.daily or {}
	specialItems = data.special or {}
	nextRotation = data.nextRotation or 0

	ShopUI.RebuildContent()
end

--[[
	Handle inventory update
]]
function ShopUI.OnInventoryUpdate(data: any)
	ownedItems = {}
	for _, itemId in ipairs(data.ownedItems or {}) do
		ownedItems[itemId] = true
	end

	ShopUI.RebuildContent()
end

--[[
	Handle purchase success
]]
function ShopUI.OnPurchaseSuccess(data: any)
	ownedItems[data.itemId] = true
	ShopUI.RebuildContent()

	-- Show success notification
	print(`[ShopUI] Purchase successful: {data.itemId}`)
end

--[[
	Handle purchase failed
]]
function ShopUI.OnPurchaseFailed(data: any)
	-- Show error notification
	warn(`[ShopUI] Purchase failed: {data.reason}`)
end

--[[
	Rebuild content display
]]
function ShopUI.RebuildContent()
	if not contentContainer then return end

	-- Clear existing content
	for _, child in ipairs(contentContainer:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local yOffset = 0

	-- Featured section
	if #featuredItems > 0 then
		yOffset = ShopUI.CreateSection("FEATURED", featuredItems, yOffset, true)
	end

	-- Bundles/Special section
	if #specialItems > 0 then
		yOffset = ShopUI.CreateSection("BUNDLES & DEALS", specialItems, yOffset, false, true)
	end

	-- Daily section
	if #dailyItems > 0 then
		yOffset = ShopUI.CreateSection("DAILY ITEMS", dailyItems, yOffset, false)
	end

	-- Update canvas size
	contentContainer.CanvasSize = UDim2.new(0, 0, 0, yOffset + 20)
end

--[[
	Create a section of items
]]
function ShopUI.CreateSection(title: string, items: { any }, yOffset: number, isFeatured: boolean, isBundle: boolean?): number
	if not contentContainer then return yOffset end

	-- Section header
	local sectionHeader = Instance.new("TextLabel")
	sectionHeader.Name = `Header_{title}`
	sectionHeader.Size = UDim2.new(1, 0, 0, 30)
	sectionHeader.Position = UDim2.fromOffset(0, yOffset)
	sectionHeader.BackgroundTransparency = 1
	sectionHeader.TextColor3 = Color3.fromRGB(200, 200, 200)
	sectionHeader.TextSize = 18
	sectionHeader.Font = Enum.Font.GothamBold
	sectionHeader.TextXAlignment = Enum.TextXAlignment.Left
	sectionHeader.Text = title
	sectionHeader.Parent = contentContainer

	yOffset = yOffset + 40

	-- Items container
	local itemsContainer = Instance.new("Frame")
	itemsContainer.Name = `Items_{title}`
	itemsContainer.Size = UDim2.new(1, 0, 0, ITEM_HEIGHT + 10)
	itemsContainer.Position = UDim2.fromOffset(0, yOffset)
	itemsContainer.BackgroundTransparency = 1
	itemsContainer.Parent = contentContainer

	local itemLayout = Instance.new("UIListLayout")
	itemLayout.FillDirection = Enum.FillDirection.Horizontal
	itemLayout.Padding = UDim.new(0, 15)
	itemLayout.Parent = itemsContainer

	-- Create item cards
	for _, itemData in ipairs(items) do
		local width = isBundle and BUNDLE_WIDTH or (isFeatured and ITEM_WIDTH + 40 or ITEM_WIDTH)
		ShopUI.CreateItemCard(itemsContainer, itemData, width, isFeatured)
	end

	return yOffset + ITEM_HEIGHT + 30
end

--[[
	Create an item card
]]
function ShopUI.CreateItemCard(parent: Frame, itemData: any, width: number, _isFeatured: boolean)
	local rarityColor = ShopData.GetRarityColor(itemData.rarity)
	local isOwned = ownedItems[itemData.id] or itemData.isOwned

	local card = Instance.new("Frame")
	card.Name = `Item_{itemData.id}`
	card.Size = UDim2.new(0, width, 0, ITEM_HEIGHT)
	card.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
	card.BorderSizePixel = 0
	card.Parent = parent

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 8)
	cardCorner.Parent = card

	-- Rarity border
	local rarityBorder = Instance.new("UIStroke")
	rarityBorder.Color = rarityColor
	rarityBorder.Thickness = 2
	rarityBorder.Parent = card

	-- Preview area
	local preview = Instance.new("Frame")
	preview.Name = "Preview"
	preview.Size = UDim2.new(1, -10, 0, 100)
	preview.Position = UDim2.fromOffset(5, 5)
	preview.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	preview.BorderSizePixel = 0
	preview.Parent = card

	local previewCorner = Instance.new("UICorner")
	previewCorner.CornerRadius = UDim.new(0, 6)
	previewCorner.Parent = preview

	-- Item type icon placeholder
	local typeLabel = Instance.new("TextLabel")
	typeLabel.Name = "Type"
	typeLabel.Size = UDim2.fromScale(1, 1)
	typeLabel.BackgroundTransparency = 1
	typeLabel.TextColor3 = Color3.fromRGB(100, 100, 100)
	typeLabel.TextSize = 32
	typeLabel.Font = Enum.Font.GothamBold
	typeLabel.Text = ShopUI.GetTypeIcon(itemData.itemType)
	typeLabel.Parent = preview

	-- Item name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(1, -10, 0, 20)
	nameLabel.Position = UDim2.fromOffset(5, 110)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextSize = 14
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Text = itemData.name
	nameLabel.Parent = card

	-- Rarity label
	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Name = "Rarity"
	rarityLabel.Size = UDim2.new(1, -10, 0, 15)
	rarityLabel.Position = UDim2.fromOffset(5, 130)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.TextColor3 = rarityColor
	rarityLabel.TextSize = 11
	rarityLabel.Font = Enum.Font.Gotham
	rarityLabel.TextXAlignment = Enum.TextXAlignment.Left
	rarityLabel.Text = itemData.rarity:upper()
	rarityLabel.Parent = card

	-- Sale indicator
	if itemData.isOnSale and itemData.originalPrice then
		local saleLabel = Instance.new("TextLabel")
		saleLabel.Name = "Sale"
		saleLabel.Size = UDim2.fromOffset(50, 20)
		saleLabel.Position = UDim2.new(1, -55, 0, 5)
		saleLabel.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
		saleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		saleLabel.TextSize = 10
		saleLabel.Font = Enum.Font.GothamBold
		saleLabel.Text = "SALE"
		saleLabel.Parent = card

		local saleCorner = Instance.new("UICorner")
		saleCorner.CornerRadius = UDim.new(0, 4)
		saleCorner.Parent = saleLabel
	end

	-- Price / Purchase button
	local priceButton = Instance.new("TextButton")
	priceButton.Name = "PriceButton"
	priceButton.Size = UDim2.new(1, -10, 0, 35)
	priceButton.Position = UDim2.new(0, 5, 1, -40)
	priceButton.BorderSizePixel = 0
	priceButton.TextSize = 14
	priceButton.Font = Enum.Font.GothamBold
	priceButton.Parent = card

	local priceCorner = Instance.new("UICorner")
	priceCorner.CornerRadius = UDim.new(0, 6)
	priceCorner.Parent = priceButton

	if isOwned then
		priceButton.BackgroundColor3 = Color3.fromRGB(60, 100, 60)
		priceButton.TextColor3 = Color3.fromRGB(150, 200, 150)
		priceButton.Text = "OWNED"
	else
		priceButton.BackgroundColor3 = Color3.fromRGB(80, 150, 255)
		priceButton.TextColor3 = Color3.fromRGB(255, 255, 255)

		local priceText = `{itemData.price} R$`
		if itemData.isOnSale and itemData.originalPrice then
			priceText = `{itemData.price} R$ (was {itemData.originalPrice})`
		end
		priceButton.Text = priceText

		priceButton.MouseButton1Click:Connect(function()
			ShopUI.OnPurchaseClicked(itemData.id)
		end)

		-- Hover effect
		priceButton.MouseEnter:Connect(function()
			TweenService:Create(priceButton, TweenInfo.new(0.2), {
				BackgroundColor3 = Color3.fromRGB(100, 170, 255)
			}):Play()
		end)

		priceButton.MouseLeave:Connect(function()
			TweenService:Create(priceButton, TweenInfo.new(0.2), {
				BackgroundColor3 = Color3.fromRGB(80, 150, 255)
			}):Play()
		end)
	end

	-- Bundle contents (if applicable)
	if itemData.bundleContents then
		local contentsLabel = Instance.new("TextLabel")
		contentsLabel.Name = "Contents"
		contentsLabel.Size = UDim2.new(1, -10, 0, 30)
		contentsLabel.Position = UDim2.fromOffset(5, 145)
		contentsLabel.BackgroundTransparency = 1
		contentsLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
		contentsLabel.TextSize = 10
		contentsLabel.Font = Enum.Font.Gotham
		contentsLabel.TextXAlignment = Enum.TextXAlignment.Left
		contentsLabel.TextWrapped = true
		contentsLabel.Text = `{#itemData.bundleContents} items • Save {itemData.savings or 0} R$`
		contentsLabel.Parent = card
	end
end

--[[
	Get icon for item type
]]
function ShopUI.GetTypeIcon(itemType: string): string
	local icons = {
		Skin = "👤",
		Emote = "💃",
		Glider = "🪂",
		BackBling = "🎒",
		WeaponSkin = "🔫",
		Bundle = "📦",
		Trail = "✨",
		Pickaxe = "⛏️",
	}
	return icons[itemType] or "❓"
end

--[[
	Handle purchase click
]]
function ShopUI.OnPurchaseClicked(itemId: string)
	Events.FireServer("Shop", "Purchase", { itemId = itemId })
end

--[[
	Update rotation timer
]]
function ShopUI.UpdateTimer()
	if not mainFrame or not isVisible then return end

	local header = mainFrame:FindFirstChild("Header") :: Frame?
	if not header then return end

	local timerLabel = header:FindFirstChild("Timer") :: TextLabel?
	if not timerLabel then return end

	local timeLeft = math.max(0, nextRotation - os.time())
	local hours = math.floor(timeLeft / 3600)
	local minutes = math.floor((timeLeft % 3600) / 60)
	local seconds = timeLeft % 60

	timerLabel.Text = string.format("Resets in: %02d:%02d:%02d", hours, minutes, seconds)
end

--[[
	Show the shop UI
]]
function ShopUI.Show()
	if not screenGui then return end
	if isVisible then return end

	isVisible = true
	screenGui.Enabled = true

	-- Request latest data
	Events.FireServer("Shop", "RequestData", {})
	Events.FireServer("Shop", "RequestInventory", {})
end

--[[
	Hide the shop UI
]]
function ShopUI.Hide()
	if not screenGui then return end
	if not isVisible then return end

	isVisible = false
	screenGui.Enabled = false
end

--[[
	Toggle visibility
]]
function ShopUI.Toggle()
	if isVisible then
		ShopUI.Hide()
	else
		ShopUI.Show()
	end
end

--[[
	Check if visible
]]
function ShopUI.IsVisible(): boolean
	return isVisible
end

return ShopUI
