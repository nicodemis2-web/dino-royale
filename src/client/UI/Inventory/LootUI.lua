--!strict
--[[
	LootUI.lua
	==========
	Client UI for loot pickups, chests, and drops
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local Events = require(ReplicatedStorage.Shared.Events)
local LootData = require(ReplicatedStorage.Shared.LootData)

local LootUI = {}

-- Types
export type LootDisplay = {
	id: string,
	itemId: string,
	itemName: string,
	amount: number,
	rarity: string,
	category: string,
	position: Vector3,
	frame: BillboardGui?,
}

-- State
local player = Players.LocalPlayer
local screenGui: ScreenGui? = nil
local pickupPrompt: Frame? = nil
local nearbyLoot: { [string]: LootDisplay } = {}
local closestLoot: LootDisplay? = nil
local isInitialized = false

-- Connections for cleanup
local connections: { RBXScriptConnection } = {}

-- Constants
local PICKUP_RANGE = 8
local PICKUP_KEY = Enum.KeyCode.E

--[[
	Initialize the loot UI
]]
function LootUI.Initialize()
	if isInitialized then return end
	isInitialized = true

	print("[LootUI] Initializing...")

	LootUI.CreateUI()
	LootUI.SetupEventListeners()
	LootUI.SetupInputHandling()

	local renderConn = RunService.RenderStepped:Connect(function()
		LootUI.Update()
	end)
	table.insert(connections, renderConn)

	print("[LootUI] Initialized")
end

--[[
	Create UI elements
]]
function LootUI.CreateUI()
	local playerGui = player:WaitForChild("PlayerGui")

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "LootUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	-- Pickup prompt
	pickupPrompt = Instance.new("Frame")
	pickupPrompt.Name = "PickupPrompt"
	pickupPrompt.Size = UDim2.new(0, 200, 0, 60)
	pickupPrompt.Position = UDim2.fromScale(0.5, 0.65)
	pickupPrompt.AnchorPoint = Vector2.new(0.5, 0.5)
	pickupPrompt.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	pickupPrompt.BackgroundTransparency = 0.2
	pickupPrompt.BorderSizePixel = 0
	pickupPrompt.Visible = false
	pickupPrompt.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = pickupPrompt

	local itemName = Instance.new("TextLabel")
	itemName.Name = "ItemName"
	itemName.Size = UDim2.new(1, -20, 0, 25)
	itemName.Position = UDim2.new(0, 10, 0, 5)
	itemName.BackgroundTransparency = 1
	itemName.TextColor3 = Color3.fromRGB(255, 255, 255)
	itemName.TextSize = 16
	itemName.Font = Enum.Font.GothamBold
	itemName.TextXAlignment = Enum.TextXAlignment.Left
	itemName.Text = "Item Name"
	itemName.Parent = pickupPrompt

	local itemAmount = Instance.new("TextLabel")
	itemAmount.Name = "ItemAmount"
	itemAmount.Size = UDim2.new(0, 50, 0, 25)
	itemAmount.Position = UDim2.new(1, -60, 0, 5)
	itemAmount.BackgroundTransparency = 1
	itemAmount.TextColor3 = Color3.fromRGB(200, 200, 200)
	itemAmount.TextSize = 14
	itemAmount.Font = Enum.Font.Gotham
	itemAmount.TextXAlignment = Enum.TextXAlignment.Right
	itemAmount.Text = "x1"
	itemAmount.Parent = pickupPrompt

	local keyHint = Instance.new("TextLabel")
	keyHint.Name = "KeyHint"
	keyHint.Size = UDim2.new(1, 0, 0, 20)
	keyHint.Position = UDim2.new(0, 0, 1, -25)
	keyHint.BackgroundTransparency = 1
	keyHint.TextColor3 = Color3.fromRGB(150, 150, 150)
	keyHint.TextSize = 12
	keyHint.Font = Enum.Font.Gotham
	keyHint.Text = "[E] Pick up"
	keyHint.Parent = pickupPrompt

	-- Rarity indicator bar
	local rarityBar = Instance.new("Frame")
	rarityBar.Name = "RarityBar"
	rarityBar.Size = UDim2.new(1, 0, 0, 3)
	rarityBar.Position = UDim2.fromScale(0, 0)
	rarityBar.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
	rarityBar.BorderSizePixel = 0
	rarityBar.Parent = pickupPrompt

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 2)
	barCorner.Parent = rarityBar
end

--[[
	Setup event listeners
]]
function LootUI.SetupEventListeners()
	Events.OnClientEvent("Loot", function(action, data)
		if action == "LootSpawned" or action == "LootDropped" then
			LootUI.AddLootDisplay(data)

		elseif action == "LootPickedUp" then
			LootUI.RemoveLootDisplay(data.id)

		elseif action == "ChestSpawned" then
			-- Would add chest marker
			LootUI.AddChestDisplay(data)

		elseif action == "ChestOpened" then
			-- Add all contents to nearby loot
			for _, item in ipairs(data.contents) do
				LootUI.AddLootDisplay(item)
			end

		elseif action == "ItemAcquired" then
			LootUI.ShowItemAcquired(data)
		end
	end)
end

--[[
	Setup input handling
]]
function LootUI.SetupInputHandling()
	ContextActionService:BindAction("LootPickup", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			LootUI.TryPickup()
		end
		return Enum.ContextActionResult.Pass
	end, false, PICKUP_KEY)
end

--[[
	Add loot display
]]
function LootUI.AddLootDisplay(data: any)
	local display: LootDisplay = {
		id = data.id,
		itemId = data.itemId,
		itemName = data.itemName,
		amount = data.amount,
		rarity = data.rarity,
		category = data.category,
		position = data.position,
		frame = nil,
	}

	-- Create world-space billboard
	local billboard = Instance.new("BillboardGui")
	billboard.Name = `Loot_{data.id}`
	billboard.Size = UDim2.new(0, 80, 0, 40)
	billboard.StudsOffset = Vector3.new(0, 1, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 30

	-- Create attachment point
	local part = Instance.new("Part")
	part.Name = `LootAnchor_{data.id}`
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Size = Vector3.new(0.5, 0.5, 0.5)
	part.Position = data.position
	part.Parent = workspace

	billboard.Adornee = part
	billboard.Parent = part

	-- Background
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	bg.BackgroundTransparency = 0.3
	bg.BorderSizePixel = 0
	bg.Parent = billboard

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 4)
	bgCorner.Parent = bg

	-- Rarity bar
	local rarityColor = LootData.GetRarityColor(data.rarity)
	local rarityBar = Instance.new("Frame")
	rarityBar.Size = UDim2.new(1, 0, 0, 2)
	rarityBar.Position = UDim2.fromScale(0, 0)
	rarityBar.BackgroundColor3 = rarityColor
	rarityBar.BorderSizePixel = 0
	rarityBar.Parent = bg

	-- Item name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -4, 0.6, 0)
	nameLabel.Position = UDim2.new(0, 2, 0, 4)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = rarityColor
	nameLabel.TextSize = 10
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = data.itemName
	nameLabel.TextScaled = true
	nameLabel.Parent = bg

	-- Amount
	if data.amount > 1 then
		local amountLabel = Instance.new("TextLabel")
		amountLabel.Size = UDim2.new(1, -4, 0.3, 0)
		amountLabel.Position = UDim2.new(0, 2, 0.65, 0)
		amountLabel.BackgroundTransparency = 1
		amountLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
		amountLabel.TextSize = 8
		amountLabel.Font = Enum.Font.Gotham
		amountLabel.Text = `x{data.amount}`
		amountLabel.Parent = bg
	end

	display.frame = billboard
	nearbyLoot[data.id] = display
end

--[[
	Remove loot display
]]
function LootUI.RemoveLootDisplay(id: string)
	local display = nearbyLoot[id]
	if display then
		if display.frame then
			local part = display.frame.Adornee
			display.frame:Destroy()
			if part then
				part:Destroy()
			end
		end
		nearbyLoot[id] = nil
	end

	if closestLoot and closestLoot.id == id then
		closestLoot = nil
	end
end

--[[
	Add chest display
]]
function LootUI.AddChestDisplay(data: any)
	-- Would create chest marker in world
end

--[[
	Show item acquired notification
]]
function LootUI.ShowItemAcquired(data: any)
	-- Would show popup notification
	print(`[LootUI] Acquired: {data.itemName} x{data.amount}`)
end

--[[
	Try to pickup closest loot
]]
function LootUI.TryPickup()
	if closestLoot then
		Events.FireServer("Loot", "PickupLoot", {
			lootId = closestLoot.id,
		})
	end
end

--[[
	Update loop
]]
function LootUI.Update()
	local character = player.Character
	if not character then
		if pickupPrompt then
			pickupPrompt.Visible = false
		end
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		if pickupPrompt then
			pickupPrompt.Visible = false
		end
		return
	end

	local playerPos = rootPart.Position
	local closest: LootDisplay? = nil
	local closestDist = PICKUP_RANGE

	-- Find closest loot
	for _, display in pairs(nearbyLoot) do
		local dist = (display.position - playerPos).Magnitude
		if dist < closestDist then
			closestDist = dist
			closest = display
		end
	end

	closestLoot = closest

	-- Update pickup prompt
	if pickupPrompt then
		if closest then
			pickupPrompt.Visible = true

			local itemName = pickupPrompt:FindFirstChild("ItemName") :: TextLabel?
			local itemAmount = pickupPrompt:FindFirstChild("ItemAmount") :: TextLabel?
			local rarityBar = pickupPrompt:FindFirstChild("RarityBar") :: Frame?

			if itemName then
				itemName.Text = closest.itemName
				itemName.TextColor3 = LootData.GetRarityColor(closest.rarity :: LootData.Rarity)
			end

			if itemAmount then
				itemAmount.Text = closest.amount > 1 and `x{closest.amount}` or ""
			end

			if rarityBar then
				rarityBar.BackgroundColor3 = LootData.GetRarityColor(closest.rarity :: LootData.Rarity)
			end
		else
			pickupPrompt.Visible = false
		end
	end
end

--[[
	Cleanup
]]
function LootUI.Cleanup()
	-- Disconnect all connections
	for _, conn in ipairs(connections) do
		conn:Disconnect()
	end
	connections = {}

	-- Unbind actions
	ContextActionService:UnbindAction("LootPickup")

	-- Remove loot displays
	for id in pairs(nearbyLoot) do
		LootUI.RemoveLootDisplay(id)
	end

	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end

	isInitialized = false
end

return LootUI
