--!strict
--[[
	AccessibilityUI.lua
	===================
	Client-side accessibility settings UI
	Based on GDD Section 9.3: Accessibility Options
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local AccessibilityData = require(ReplicatedStorage.Shared.AccessibilityData)

local AccessibilityUI = {}

-- Forward declarations
local AccessibilityController: any = nil

-- State
local player = Players.LocalPlayer
local screenGui: ScreenGui? = nil
local mainFrame: Frame? = nil
local isVisible = false

-- Constants
local SETTING_HEIGHT = 45

--[[
	Initialize the accessibility UI
]]
function AccessibilityUI.Initialize()
	print("[AccessibilityUI] Initializing...")

	-- Get controller reference
	local Controllers = script.Parent.Parent.Parent.Controllers
	AccessibilityController = require(Controllers.AccessibilityController)
	AccessibilityController.Initialize()

	AccessibilityUI.CreateUI()

	print("[AccessibilityUI] Initialized")
end

--[[
	Create UI elements
]]
function AccessibilityUI.CreateUI()
	local playerGui = player:WaitForChild("PlayerGui")

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "AccessibilityGui"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	-- Main settings panel
	mainFrame = Instance.new("Frame")
	mainFrame.Name = "AccessibilityPanel"
	mainFrame.Size = UDim2.new(0, 550, 0, 600)
	mainFrame.Position = UDim2.fromScale(0.5, 0.5)
	mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	mainFrame.BorderSizePixel = 0
	mainFrame.Visible = false
	mainFrame.Parent = screenGui

	local mainCorner = Instance.new("UICorner")
	mainCorner.CornerRadius = UDim.new(0, 12)
	mainCorner.Parent = mainFrame

	-- Header
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 50)
	header.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	header.BorderSizePixel = 0
	header.Parent = mainFrame

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 12)
	headerCorner.Parent = header

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -100, 1, 0)
	title.Position = UDim2.fromOffset(15, 0)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(255, 200, 50)
	title.TextSize = 20
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "ACCESSIBILITY"
	title.Parent = header

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "Close"
	closeButton.Size = UDim2.new(0, 30, 0, 30)
	closeButton.Position = UDim2.new(1, -40, 0.5, -15)
	closeButton.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
	closeButton.BorderSizePixel = 0
	closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeButton.TextSize = 18
	closeButton.Font = Enum.Font.GothamBold
	closeButton.Text = "X"
	closeButton.Parent = header

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 6)
	closeCorner.Parent = closeButton

	closeButton.MouseButton1Click:Connect(function()
		AccessibilityUI.Hide()
	end)

	-- Tab buttons
	local tabFrame = Instance.new("Frame")
	tabFrame.Name = "Tabs"
	tabFrame.Size = UDim2.new(1, -20, 0, 35)
	tabFrame.Position = UDim2.new(0, 10, 0, 55)
	tabFrame.BackgroundTransparency = 1
	tabFrame.Parent = mainFrame

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 5)
	tabLayout.Parent = tabFrame

	-- Content scroll frame
	local contentScroll = Instance.new("ScrollingFrame")
	contentScroll.Name = "Content"
	contentScroll.Size = UDim2.new(1, -20, 1, -150)
	contentScroll.Position = UDim2.new(0, 10, 0, 95)
	contentScroll.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	contentScroll.BorderSizePixel = 0
	contentScroll.ScrollBarThickness = 6
	contentScroll.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
	contentScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	contentScroll.Parent = mainFrame

	local contentCorner = Instance.new("UICorner")
	contentCorner.CornerRadius = UDim.new(0, 8)
	contentCorner.Parent = contentScroll

	local contentPadding = Instance.new("UIPadding")
	contentPadding.PaddingTop = UDim.new(0, 10)
	contentPadding.PaddingBottom = UDim.new(0, 10)
	contentPadding.PaddingLeft = UDim.new(0, 10)
	contentPadding.PaddingRight = UDim.new(0, 10)
	contentPadding.Parent = contentScroll

	local contentLayout = Instance.new("UIListLayout")
	contentLayout.Padding = UDim.new(0, 8)
	contentLayout.Parent = contentScroll

	-- Create tabs for each category
	for i, category in ipairs(AccessibilityData.Categories) do
		local tabBtn = Instance.new("TextButton")
		tabBtn.Name = category.id
		tabBtn.Size = UDim2.new(0, 120, 1, 0)
		tabBtn.BackgroundColor3 = i == 1 and Color3.fromRGB(60, 120, 180) or Color3.fromRGB(40, 40, 45)
		tabBtn.BorderSizePixel = 0
		tabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		tabBtn.TextSize = 12
		tabBtn.Font = Enum.Font.GothamBold
		tabBtn.Text = category.name
		tabBtn.LayoutOrder = i
		tabBtn.Parent = tabFrame

		local tabCorner = Instance.new("UICorner")
		tabCorner.CornerRadius = UDim.new(0, 6)
		tabCorner.Parent = tabBtn

		tabBtn.MouseButton1Click:Connect(function()
			AccessibilityUI.SelectCategory(category.id)
		end)
	end

	-- Bottom buttons
	local resetButton = Instance.new("TextButton")
	resetButton.Name = "Reset"
	resetButton.Size = UDim2.new(0, 150, 0, 40)
	resetButton.Position = UDim2.new(0.5, -80, 1, -55)
	resetButton.BackgroundColor3 = Color3.fromRGB(180, 80, 80)
	resetButton.BorderSizePixel = 0
	resetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	resetButton.TextSize = 14
	resetButton.Font = Enum.Font.GothamBold
	resetButton.Text = "Reset to Defaults"
	resetButton.Parent = mainFrame

	local resetCorner = Instance.new("UICorner")
	resetCorner.CornerRadius = UDim.new(0, 8)
	resetCorner.Parent = resetButton

	resetButton.MouseButton1Click:Connect(function()
		AccessibilityController.ResetToDefaults()
		AccessibilityUI.RefreshContent()
	end)

	-- Load first category
	AccessibilityUI.SelectCategory("Visual")
end

--[[
	Select a category tab
]]
function AccessibilityUI.SelectCategory(categoryId: string)
	if not mainFrame then return end

	local tabFrame = mainFrame:FindFirstChild("Tabs") :: Frame?
	local contentScroll = mainFrame:FindFirstChild("Content") :: ScrollingFrame?
	if not tabFrame or not contentScroll then return end

	-- Update tab visuals
	for _, child in ipairs(tabFrame:GetChildren()) do
		if child:IsA("TextButton") then
			child.BackgroundColor3 = child.Name == categoryId
				and Color3.fromRGB(60, 120, 180)
				or Color3.fromRGB(40, 40, 45)
		end
	end

	-- Clear content
	for _, child in ipairs(contentScroll:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	-- Find category
	local category = nil
	for _, cat in ipairs(AccessibilityData.Categories) do
		if cat.id == categoryId then
			category = cat
			break
		end
	end

	if not category then return end

	-- Create settings for this category
	local settings = AccessibilityController.GetSettings()
	local totalHeight = 0

	for i, setting in ipairs(category.settings) do
		local frame = AccessibilityUI.CreateSettingRow(setting, settings[setting.id])
		frame.LayoutOrder = i
		frame.Parent = contentScroll
		totalHeight = totalHeight + SETTING_HEIGHT + 8
	end

	contentScroll.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
end

--[[
	Create a setting row
]]
function AccessibilityUI.CreateSettingRow(setting: any, currentValue: any): Frame
	local frame = Instance.new("Frame")
	frame.Name = setting.id
	frame.Size = UDim2.new(1, 0, 0, SETTING_HEIGHT)
	frame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
	frame.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(0.5, -10, 1, 0)
	nameLabel.Position = UDim2.fromOffset(15, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
	nameLabel.TextSize = 14
	nameLabel.Font = Enum.Font.GothamMedium
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Text = setting.name
	nameLabel.Parent = frame

	if setting.type == "toggle" then
		local toggle = AccessibilityUI.CreateToggle(setting.id, currentValue)
		toggle.Position = UDim2.new(1, -70, 0.5, -15)
		toggle.Parent = frame

	elseif setting.type == "slider" then
		local slider = AccessibilityUI.CreateSlider(setting.id, currentValue, setting.min, setting.max, setting.step)
		slider.Position = UDim2.new(0.5, 0, 0.5, -10)
		slider.Parent = frame

	elseif setting.type == "dropdown" then
		local dropdown = AccessibilityUI.CreateDropdown(setting.id, currentValue, setting.options)
		dropdown.Position = UDim2.new(0.5, 0, 0.5, -15)
		dropdown.Parent = frame
	end

	return frame
end

--[[
	Create a toggle button
]]
function AccessibilityUI.CreateToggle(settingId: string, isOn: boolean): Frame
	local container = Instance.new("Frame")
	container.Name = "Toggle"
	container.Size = UDim2.new(0, 55, 0, 30)
	container.BackgroundColor3 = isOn and Color3.fromRGB(60, 180, 80) or Color3.fromRGB(80, 80, 85)
	container.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = container

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.Size = UDim2.new(0, 24, 0, 24)
	knob.Position = isOn and UDim2.new(1, -27, 0.5, -12) or UDim2.new(0, 3, 0.5, -12)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	knob.Parent = container

	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(0.5, 0)
	knobCorner.Parent = knob

	local button = Instance.new("TextButton")
	button.Name = "Button"
	button.Size = UDim2.new(1, 0, 1, 0)
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Parent = container

	button.MouseButton1Click:Connect(function()
		local newValue = not AccessibilityController.GetSetting(settingId)
		AccessibilityController.SetSetting(settingId, newValue)

		-- Animate toggle
		container.BackgroundColor3 = newValue and Color3.fromRGB(60, 180, 80) or Color3.fromRGB(80, 80, 85)
		TweenService:Create(knob, TweenInfo.new(0.15), {
			Position = newValue and UDim2.new(1, -27, 0.5, -12) or UDim2.new(0, 3, 0.5, -12),
		}):Play()
	end)

	return container
end

--[[
	Create a slider
]]
function AccessibilityUI.CreateSlider(settingId: string, currentValue: number, minVal: number, maxVal: number, step: number?): Frame
	local container = Instance.new("Frame")
	container.Name = "Slider"
	container.Size = UDim2.new(0.45, 0, 0, 20)
	container.BackgroundTransparency = 1

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = UDim2.new(1, -50, 0, 8)
	track.Position = UDim2.new(0, 0, 0.5, -4)
	track.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
	track.BorderSizePixel = 0
	track.Parent = container

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, 4)
	trackCorner.Parent = track

	local normalizedValue = (currentValue - minVal) / (maxVal - minVal)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(normalizedValue, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(60, 180, 80)
	fill.BorderSizePixel = 0
	fill.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = fill

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.Size = UDim2.new(0, 16, 0, 16)
	knob.Position = UDim2.new(normalizedValue, -8, 0.5, -8)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	knob.Parent = track

	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(0.5, 0)
	knobCorner.Parent = knob

	local valueLabel = Instance.new("TextLabel")
	valueLabel.Name = "Value"
	valueLabel.Size = UDim2.new(0, 45, 1, 0)
	valueLabel.Position = UDim2.new(1, -45, 0, 0)
	valueLabel.BackgroundTransparency = 1
	valueLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	valueLabel.TextSize = 12
	valueLabel.Font = Enum.Font.GothamMedium
	valueLabel.Text = string.format("%.2f", currentValue)
	valueLabel.Parent = container

	-- Make track clickable
	local button = Instance.new("TextButton")
	button.Name = "Button"
	button.Size = UDim2.new(1, 0, 0, 20)
	button.Position = UDim2.new(0, 0, 0.5, -10)
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Parent = track

	local isDragging = false

	local function updateSlider(inputPos: Vector2)
		local trackAbsPos = track.AbsolutePosition
		local trackAbsSize = track.AbsoluteSize

		local relativeX = math.clamp((inputPos.X - trackAbsPos.X) / trackAbsSize.X, 0, 1)

		-- Apply step if specified
		if step then
			local range = maxVal - minVal
			local steps = math.floor(range / step)
			relativeX = math.round(relativeX * steps) / steps
		end

		local newValue = minVal + relativeX * (maxVal - minVal)
		newValue = math.clamp(newValue, minVal, maxVal)

		-- Update visuals
		fill.Size = UDim2.new(relativeX, 0, 1, 0)
		knob.Position = UDim2.new(relativeX, -8, 0.5, -8)
		valueLabel.Text = string.format("%.2f", newValue)

		-- Update setting
		AccessibilityController.SetSetting(settingId, newValue)
	end

	button.MouseButton1Down:Connect(function()
		isDragging = true
	end)

	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			isDragging = false
		end
	end)

	button.MouseButton1Click:Connect(function()
		local mouse = player:GetMouse()
		updateSlider(Vector2.new(mouse.X, mouse.Y))
	end)

	return container
end

--[[
	Create a dropdown
]]
function AccessibilityUI.CreateDropdown(settingId: string, currentValue: string, options: { string }): Frame
	local container = Instance.new("Frame")
	container.Name = "Dropdown"
	container.Size = UDim2.new(0.45, 0, 0, 30)
	container.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
	container.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = container

	local selectedLabel = Instance.new("TextLabel")
	selectedLabel.Name = "Selected"
	selectedLabel.Size = UDim2.new(1, -30, 1, 0)
	selectedLabel.Position = UDim2.fromOffset(10, 0)
	selectedLabel.BackgroundTransparency = 1
	selectedLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
	selectedLabel.TextSize = 12
	selectedLabel.Font = Enum.Font.GothamMedium
	selectedLabel.TextXAlignment = Enum.TextXAlignment.Left
	selectedLabel.Text = currentValue
	selectedLabel.Parent = container

	local arrow = Instance.new("TextLabel")
	arrow.Name = "Arrow"
	arrow.Size = UDim2.new(0, 20, 1, 0)
	arrow.Position = UDim2.new(1, -25, 0, 0)
	arrow.BackgroundTransparency = 1
	arrow.TextColor3 = Color3.fromRGB(150, 150, 150)
	arrow.TextSize = 12
	arrow.Font = Enum.Font.GothamBold
	arrow.Text = "v"
	arrow.Parent = container

	-- Dropdown list
	local dropdownList = Instance.new("Frame")
	dropdownList.Name = "List"
	dropdownList.Size = UDim2.new(1, 0, 0, #options * 28 + 10)
	dropdownList.Position = UDim2.new(0, 0, 1, 5)
	dropdownList.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
	dropdownList.BorderSizePixel = 0
	dropdownList.ZIndex = 10
	dropdownList.Visible = false
	dropdownList.Parent = container

	local listCorner = Instance.new("UICorner")
	listCorner.CornerRadius = UDim.new(0, 6)
	listCorner.Parent = dropdownList

	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingTop = UDim.new(0, 5)
	listPadding.PaddingBottom = UDim.new(0, 5)
	listPadding.Parent = dropdownList

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 2)
	listLayout.Parent = dropdownList

	for i, option in ipairs(options) do
		local optionBtn = Instance.new("TextButton")
		optionBtn.Name = option
		optionBtn.Size = UDim2.new(1, -10, 0, 26)
		optionBtn.Position = UDim2.fromOffset(5, 0)
		optionBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 60)
		optionBtn.BackgroundTransparency = option == currentValue and 0 or 1
		optionBtn.BorderSizePixel = 0
		optionBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
		optionBtn.TextSize = 12
		optionBtn.Font = Enum.Font.Gotham
		optionBtn.Text = option
		optionBtn.LayoutOrder = i
		optionBtn.ZIndex = 11
		optionBtn.Parent = dropdownList

		local optionCorner = Instance.new("UICorner")
		optionCorner.CornerRadius = UDim.new(0, 4)
		optionCorner.Parent = optionBtn

		optionBtn.MouseButton1Click:Connect(function()
			AccessibilityController.SetSetting(settingId, option)
			selectedLabel.Text = option
			dropdownList.Visible = false

			-- Update highlight
			for _, child in ipairs(dropdownList:GetChildren()) do
				if child:IsA("TextButton") then
					child.BackgroundTransparency = child.Name == option and 0 or 1
				end
			end
		end)
	end

	-- Toggle dropdown
	local button = Instance.new("TextButton")
	button.Name = "Button"
	button.Size = UDim2.new(1, 0, 1, 0)
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Parent = container

	button.MouseButton1Click:Connect(function()
		dropdownList.Visible = not dropdownList.Visible
	end)

	return container
end

--[[
	Refresh content with current settings
]]
function AccessibilityUI.RefreshContent()
	-- Re-select current category
	if mainFrame then
		local tabFrame = mainFrame:FindFirstChild("Tabs") :: Frame?
		if tabFrame then
			for _, child in ipairs(tabFrame:GetChildren()) do
				if child:IsA("TextButton") and child.BackgroundColor3 == Color3.fromRGB(60, 120, 180) then
					AccessibilityUI.SelectCategory(child.Name)
					break
				end
			end
		end
	end
end

--[[
	Show accessibility UI
]]
function AccessibilityUI.Show()
	if not mainFrame then return end
	isVisible = true
	mainFrame.Visible = true
end

--[[
	Hide accessibility UI
]]
function AccessibilityUI.Hide()
	if not mainFrame then return end
	isVisible = false
	mainFrame.Visible = false
end

--[[
	Toggle accessibility UI
]]
function AccessibilityUI.Toggle()
	if isVisible then
		AccessibilityUI.Hide()
	else
		AccessibilityUI.Show()
	end
end

return AccessibilityUI
