--!strict
--[[
	ConfirmDialog.lua
	=================
	Reusable confirmation dialog for destructive actions
	Supports customizable title, message, and button labels
]]

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local ConfirmDialog = {}

-- Types
export type DialogConfig = {
	title: string?,
	message: string,
	confirmText: string?,
	cancelText: string?,
	confirmColor: Color3?,
	onConfirm: (() -> ())?,
	onCancel: (() -> ())?,
}

-- Settings
local ANIMATION_DURATION = 0.2
local DIALOG_WIDTH = 400
local DIALOG_HEIGHT = 200

-- State
local player = Players.LocalPlayer
local screenGui: ScreenGui? = nil
local dialogFrame: Frame? = nil
local backdropFrame: Frame? = nil
local isVisible = false
local currentConfig: DialogConfig? = nil
local isInitialized = false

--[[
	Initialize the dialog system
]]
function ConfirmDialog.Initialize()
	if isInitialized then
		return
	end

	local playerGui = player:WaitForChild("PlayerGui")

	-- Create screen gui
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ConfirmDialogGui"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 200 -- Above everything
	screenGui.IgnoreGuiInset = true
	screenGui.Enabled = false
	screenGui.Parent = playerGui

	-- Create backdrop (darkens screen)
	backdropFrame = Instance.new("Frame")
	backdropFrame.Name = "Backdrop"
	backdropFrame.Size = UDim2.fromScale(1, 1)
	backdropFrame.BackgroundColor3 = Color3.new(0, 0, 0)
	backdropFrame.BackgroundTransparency = 1
	backdropFrame.Parent = screenGui

	-- Click backdrop to cancel
	local backdropButton = Instance.new("TextButton")
	backdropButton.Name = "BackdropButton"
	backdropButton.Size = UDim2.fromScale(1, 1)
	backdropButton.BackgroundTransparency = 1
	backdropButton.Text = ""
	backdropButton.Parent = backdropFrame

	backdropButton.MouseButton1Click:Connect(function()
		ConfirmDialog.Cancel()
	end)

	-- Create dialog frame
	dialogFrame = Instance.new("Frame")
	dialogFrame.Name = "Dialog"
	dialogFrame.Size = UDim2.fromOffset(DIALOG_WIDTH, DIALOG_HEIGHT)
	dialogFrame.Position = UDim2.fromScale(0.5, 0.5)
	dialogFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	dialogFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	dialogFrame.BorderSizePixel = 0
	dialogFrame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = dialogFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(60, 60, 70)
	stroke.Thickness = 2
	stroke.Parent = dialogFrame

	-- Title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, -40, 0, 40)
	titleLabel.Position = UDim2.fromOffset(20, 15)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
	titleLabel.TextSize = 20
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = "Confirm"
	titleLabel.Parent = dialogFrame

	local titleConstraint = Instance.new("UITextSizeConstraint")
	titleConstraint.MinTextSize = 14
	titleConstraint.MaxTextSize = 24
	titleConstraint.Parent = titleLabel

	-- Message
	local messageLabel = Instance.new("TextLabel")
	messageLabel.Name = "Message"
	messageLabel.Size = UDim2.new(1, -40, 0, 60)
	messageLabel.Position = UDim2.fromOffset(20, 55)
	messageLabel.BackgroundTransparency = 1
	messageLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	messageLabel.TextSize = 16
	messageLabel.Font = Enum.Font.Gotham
	messageLabel.TextXAlignment = Enum.TextXAlignment.Left
	messageLabel.TextYAlignment = Enum.TextYAlignment.Top
	messageLabel.TextWrapped = true
	messageLabel.Text = "Are you sure?"
	messageLabel.Parent = dialogFrame

	local messageConstraint = Instance.new("UITextSizeConstraint")
	messageConstraint.MinTextSize = 12
	messageConstraint.MaxTextSize = 18
	messageConstraint.Parent = messageLabel

	-- Button container
	local buttonContainer = Instance.new("Frame")
	buttonContainer.Name = "Buttons"
	buttonContainer.Size = UDim2.new(1, -40, 0, 50)
	buttonContainer.Position = UDim2.new(0, 20, 1, -65)
	buttonContainer.BackgroundTransparency = 1
	buttonContainer.Parent = dialogFrame

	local buttonLayout = Instance.new("UIListLayout")
	buttonLayout.FillDirection = Enum.FillDirection.Horizontal
	buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	buttonLayout.Padding = UDim.new(0, 10)
	buttonLayout.Parent = buttonContainer

	-- Cancel button
	local cancelButton = Instance.new("TextButton")
	cancelButton.Name = "Cancel"
	cancelButton.Size = UDim2.new(0, 120, 0, 45)
	cancelButton.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
	cancelButton.BorderSizePixel = 0
	cancelButton.TextColor3 = Color3.new(1, 1, 1)
	cancelButton.TextSize = 16
	cancelButton.Font = Enum.Font.GothamBold
	cancelButton.Text = "Cancel"
	cancelButton.LayoutOrder = 1
	cancelButton.Parent = buttonContainer

	local cancelCorner = Instance.new("UICorner")
	cancelCorner.CornerRadius = UDim.new(0, 8)
	cancelCorner.Parent = cancelButton

	local cancelConstraint = Instance.new("UITextSizeConstraint")
	cancelConstraint.MinTextSize = 12
	cancelConstraint.MaxTextSize = 18
	cancelConstraint.Parent = cancelButton

	-- Hover effect
	cancelButton.MouseEnter:Connect(function()
		TweenService:Create(cancelButton, TweenInfo.new(0.15), {
			BackgroundColor3 = Color3.fromRGB(80, 80, 85),
		}):Play()
	end)

	cancelButton.MouseLeave:Connect(function()
		TweenService:Create(cancelButton, TweenInfo.new(0.15), {
			BackgroundColor3 = Color3.fromRGB(60, 60, 65),
		}):Play()
	end)

	cancelButton.MouseButton1Click:Connect(function()
		ConfirmDialog.Cancel()
	end)

	-- Confirm button
	local confirmButton = Instance.new("TextButton")
	confirmButton.Name = "Confirm"
	confirmButton.Size = UDim2.new(0, 120, 0, 45)
	confirmButton.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
	confirmButton.BorderSizePixel = 0
	confirmButton.TextColor3 = Color3.new(1, 1, 1)
	confirmButton.TextSize = 16
	confirmButton.Font = Enum.Font.GothamBold
	confirmButton.Text = "Confirm"
	confirmButton.LayoutOrder = 2
	confirmButton.Parent = buttonContainer

	local confirmCorner = Instance.new("UICorner")
	confirmCorner.CornerRadius = UDim.new(0, 8)
	confirmCorner.Parent = confirmButton

	local confirmConstraint = Instance.new("UITextSizeConstraint")
	confirmConstraint.MinTextSize = 12
	confirmConstraint.MaxTextSize = 18
	confirmConstraint.Parent = confirmButton

	-- Hover effect
	confirmButton.MouseEnter:Connect(function()
		local baseColor = confirmButton.BackgroundColor3
		TweenService:Create(confirmButton, TweenInfo.new(0.15), {
			BackgroundColor3 = Color3.fromRGB(
				math.min(255, baseColor.R * 255 + 30),
				math.min(255, baseColor.G * 255 + 30),
				math.min(255, baseColor.B * 255 + 30)
			),
		}):Play()
	end)

	confirmButton.MouseLeave:Connect(function()
		if currentConfig and currentConfig.confirmColor then
			TweenService:Create(confirmButton, TweenInfo.new(0.15), {
				BackgroundColor3 = currentConfig.confirmColor,
			}):Play()
		else
			TweenService:Create(confirmButton, TweenInfo.new(0.15), {
				BackgroundColor3 = Color3.fromRGB(180, 60, 60),
			}):Play()
		end
	end)

	confirmButton.MouseButton1Click:Connect(function()
		ConfirmDialog.Confirm()
	end)

	isInitialized = true
	print("[ConfirmDialog] Initialized")
end

--[[
	Show the confirmation dialog
]]
function ConfirmDialog.Show(config: DialogConfig)
	if not isInitialized then
		ConfirmDialog.Initialize()
	end

	if not screenGui or not dialogFrame or not backdropFrame then
		return
	end

	currentConfig = config

	-- Update dialog content
	local titleLabel = dialogFrame:FindFirstChild("Title") :: TextLabel?
	local messageLabel = dialogFrame:FindFirstChild("Message") :: TextLabel?
	local buttonContainer = dialogFrame:FindFirstChild("Buttons") :: Frame?

	if titleLabel then
		titleLabel.Text = config.title or "Confirm"
	end

	if messageLabel then
		messageLabel.Text = config.message
	end

	if buttonContainer then
		local cancelButton = buttonContainer:FindFirstChild("Cancel") :: TextButton?
		local confirmButton = buttonContainer:FindFirstChild("Confirm") :: TextButton?

		if cancelButton then
			cancelButton.Text = config.cancelText or "Cancel"
		end

		if confirmButton then
			confirmButton.Text = config.confirmText or "Confirm"
			confirmButton.BackgroundColor3 = config.confirmColor or Color3.fromRGB(180, 60, 60)
		end
	end

	-- Show with animation
	screenGui.Enabled = true
	isVisible = true

	-- Backdrop fade in
	TweenService:Create(backdropFrame, TweenInfo.new(ANIMATION_DURATION), {
		BackgroundTransparency = 0.5,
	}):Play()

	-- Dialog scale in
	dialogFrame.Size = UDim2.fromOffset(DIALOG_WIDTH * 0.9, DIALOG_HEIGHT * 0.9)
	dialogFrame.BackgroundTransparency = 1

	TweenService:Create(dialogFrame, TweenInfo.new(ANIMATION_DURATION, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(DIALOG_WIDTH, DIALOG_HEIGHT),
		BackgroundTransparency = 0,
	}):Play()
end

--[[
	Hide the dialog
]]
local function hideDialog()
	if not screenGui or not dialogFrame or not backdropFrame then
		return
	end

	isVisible = false

	-- Backdrop fade out
	TweenService:Create(backdropFrame, TweenInfo.new(ANIMATION_DURATION), {
		BackgroundTransparency = 1,
	}):Play()

	-- Dialog scale out
	local hideTween = TweenService:Create(dialogFrame, TweenInfo.new(ANIMATION_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = UDim2.fromOffset(DIALOG_WIDTH * 0.9, DIALOG_HEIGHT * 0.9),
		BackgroundTransparency = 1,
	})

	hideTween:Play()
	-- Use Once to avoid connection leak on repeated show/hide
	hideTween.Completed:Once(function()
		if not isVisible and screenGui then
			screenGui.Enabled = false
		end
	end)
end

--[[
	Confirm action
]]
function ConfirmDialog.Confirm()
	if currentConfig and currentConfig.onConfirm then
		currentConfig.onConfirm()
	end
	hideDialog()
	currentConfig = nil
end

--[[
	Cancel action
]]
function ConfirmDialog.Cancel()
	if currentConfig and currentConfig.onCancel then
		currentConfig.onCancel()
	end
	hideDialog()
	currentConfig = nil
end

--[[
	Check if dialog is visible
]]
function ConfirmDialog.IsVisible(): boolean
	return isVisible
end

return ConfirmDialog
