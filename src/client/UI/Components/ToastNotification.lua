--!strict
--[[
	ToastNotification.lua
	====================
	Toast notification system for displaying feedback messages
	Supports success, error, warning, and info toasts
]]

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local ToastNotification = {}

-- Types
export type ToastType = "success" | "error" | "warning" | "info"

export type ToastConfig = {
	message: string,
	toastType: ToastType?,
	duration: number?,
	icon: string?,
}

-- Settings
local MAX_TOASTS = 5
local DEFAULT_DURATION = 3
local TOAST_HEIGHT = 50
local TOAST_WIDTH = 300
local TOAST_PADDING = 8
local ANIMATION_DURATION = 0.25

-- Colors by type
local TOAST_COLORS = {
	success = {
		background = Color3.fromRGB(40, 120, 60),
		border = Color3.fromRGB(60, 180, 80),
		icon = "✓",
	},
	error = {
		background = Color3.fromRGB(140, 40, 40),
		border = Color3.fromRGB(200, 60, 60),
		icon = "✕",
	},
	warning = {
		background = Color3.fromRGB(140, 100, 30),
		border = Color3.fromRGB(220, 160, 50),
		icon = "⚠",
	},
	info = {
		background = Color3.fromRGB(40, 80, 140),
		border = Color3.fromRGB(60, 120, 200),
		icon = "ℹ",
	},
}

-- State
local player = Players.LocalPlayer
local screenGui: ScreenGui? = nil
local containerFrame: Frame? = nil
local activeToasts: { Frame } = {}
local isInitialized = false

--[[
	Initialize the toast system
]]
function ToastNotification.Initialize()
	if isInitialized then
		return
	end

	local playerGui = player:WaitForChild("PlayerGui")

	-- Create screen gui
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ToastNotificationGui"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 100 -- Above most UI
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui

	-- Create container for toasts (top center)
	containerFrame = Instance.new("Frame")
	containerFrame.Name = "ToastContainer"
	containerFrame.Size = UDim2.new(0, TOAST_WIDTH, 1, 0)
	containerFrame.Position = UDim2.new(0.5, 0, 0, 20)
	containerFrame.AnchorPoint = Vector2.new(0.5, 0)
	containerFrame.BackgroundTransparency = 1
	containerFrame.Parent = screenGui

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, TOAST_PADDING)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = containerFrame

	isInitialized = true
	print("[ToastNotification] Initialized")
end

--[[
	Create a toast element
]]
local function createToastElement(config: ToastConfig): Frame
	local toastType = config.toastType or "info"
	local colors = TOAST_COLORS[toastType]

	local toast = Instance.new("Frame")
	toast.Name = "Toast"
	toast.Size = UDim2.new(1, 0, 0, TOAST_HEIGHT)
	toast.BackgroundColor3 = colors.background
	toast.BackgroundTransparency = 0.1
	toast.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = toast

	local stroke = Instance.new("UIStroke")
	stroke.Color = colors.border
	stroke.Thickness = 2
	stroke.Transparency = 0.3
	stroke.Parent = toast

	-- Icon
	local iconLabel = Instance.new("TextLabel")
	iconLabel.Name = "Icon"
	iconLabel.Size = UDim2.new(0, 40, 1, 0)
	iconLabel.Position = UDim2.fromOffset(0, 0)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = config.icon or colors.icon
	iconLabel.TextColor3 = Color3.new(1, 1, 1)
	iconLabel.TextSize = 20
	iconLabel.Font = Enum.Font.GothamBold
	iconLabel.Parent = toast

	-- Message
	local messageLabel = Instance.new("TextLabel")
	messageLabel.Name = "Message"
	messageLabel.Size = UDim2.new(1, -50, 1, 0)
	messageLabel.Position = UDim2.fromOffset(40, 0)
	messageLabel.BackgroundTransparency = 1
	messageLabel.Text = config.message
	messageLabel.TextColor3 = Color3.new(1, 1, 1)
	messageLabel.TextSize = 14
	messageLabel.Font = Enum.Font.GothamMedium
	messageLabel.TextXAlignment = Enum.TextXAlignment.Left
	messageLabel.TextWrapped = true
	messageLabel.TextTruncate = Enum.TextTruncate.AtEnd
	messageLabel.Parent = toast

	-- Add text size constraint for scaling
	local textConstraint = Instance.new("UITextSizeConstraint")
	textConstraint.MinTextSize = 10
	textConstraint.MaxTextSize = 16
	textConstraint.Parent = messageLabel

	return toast
end

--[[
	Show a toast notification
]]
function ToastNotification.Show(config: ToastConfig)
	if not isInitialized then
		ToastNotification.Initialize()
	end

	if not containerFrame then
		return
	end

	-- Remove oldest toast if at max
	while #activeToasts >= MAX_TOASTS do
		local oldestToast = table.remove(activeToasts, 1)
		if oldestToast then
			oldestToast:Destroy()
		end
	end

	-- Create toast
	local toast = createToastElement(config)
	toast.LayoutOrder = tick() -- Use timestamp for ordering
	toast.Parent = containerFrame

	-- Start hidden (for animation)
	toast.Position = UDim2.new(-1, 0, 0, 0)
	toast.BackgroundTransparency = 1

	-- Get stroke for animation
	local stroke = toast:FindFirstChildOfClass("UIStroke")

	-- Animate in
	local tweenIn = TweenService:Create(toast, TweenInfo.new(ANIMATION_DURATION, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 0.1,
	})
	tweenIn:Play()

	table.insert(activeToasts, toast)

	-- Schedule removal
	local duration = config.duration or DEFAULT_DURATION

	task.delay(duration, function()
		-- Animate out
		local tweenOut = TweenService:Create(toast, TweenInfo.new(ANIMATION_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(1, 0, 0, 0),
			BackgroundTransparency = 1,
		})
		tweenOut:Play()

		-- Use Once to avoid connection leak
		tweenOut.Completed:Once(function()
			local index = table.find(activeToasts, toast)
			if index then
				table.remove(activeToasts, index)
			end
			toast:Destroy()
		end)
	end)
end

--[[
	Convenience methods for different toast types
]]
function ToastNotification.Success(message: string, duration: number?)
	ToastNotification.Show({
		message = message,
		toastType = "success",
		duration = duration,
	})
end

function ToastNotification.Error(message: string, duration: number?)
	ToastNotification.Show({
		message = message,
		toastType = "error",
		duration = duration,
	})
end

function ToastNotification.Warning(message: string, duration: number?)
	ToastNotification.Show({
		message = message,
		toastType = "warning",
		duration = duration,
	})
end

function ToastNotification.Info(message: string, duration: number?)
	ToastNotification.Show({
		message = message,
		toastType = "info",
		duration = duration,
	})
end

--[[
	Clear all active toasts
]]
function ToastNotification.ClearAll()
	for _, toast in ipairs(activeToasts) do
		toast:Destroy()
	end
	activeToasts = {}
end

return ToastNotification
