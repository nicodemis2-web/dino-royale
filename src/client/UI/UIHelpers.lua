--!strict
--[[
	UIHelpers.lua
	=============
	Utility functions for consistent UI creation
	Handles text scaling, transitions, and common patterns
]]

local TweenService = game:GetService("TweenService")

local UIHelpers = {}

-- Default text size constraints
local DEFAULT_MIN_TEXT_SIZE = 10
local DEFAULT_MAX_TEXT_SIZE = 24

-- Transition settings
local DEFAULT_FADE_DURATION = 0.2

--[[
	Add UITextSizeConstraint to a TextLabel or TextButton
	@param textElement The TextLabel or TextButton to add constraint to
	@param minSize Minimum text size (default 10)
	@param maxSize Maximum text size (default 24)
]]
function UIHelpers.AddTextConstraint(textElement: TextLabel | TextButton, minSize: number?, maxSize: number?): UITextSizeConstraint
	-- Remove existing constraint if any
	local existing = textElement:FindFirstChildOfClass("UITextSizeConstraint")
	if existing then
		existing:Destroy()
	end

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = minSize or DEFAULT_MIN_TEXT_SIZE
	constraint.MaxTextSize = maxSize or DEFAULT_MAX_TEXT_SIZE
	constraint.Parent = textElement

	return constraint
end

--[[
	Create a TextLabel with automatic text scaling
	@param config Configuration for the text label
]]
function UIHelpers.CreateScaledTextLabel(config: {
	name: string?,
	text: string?,
	textColor: Color3?,
	font: Enum.Font?,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	backgroundTransparency: number?,
	backgroundColor: Color3?,
	textXAlignment: Enum.TextXAlignment?,
	textYAlignment: Enum.TextYAlignment?,
	minTextSize: number?,
	maxTextSize: number?,
	parent: GuiObject?,
}): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = config.name or "TextLabel"
	label.Text = config.text or ""
	label.TextColor3 = config.textColor or Color3.new(1, 1, 1)
	label.Font = config.font or Enum.Font.Gotham
	label.Size = config.size or UDim2.fromScale(1, 1)
	label.Position = config.position or UDim2.fromScale(0, 0)
	label.AnchorPoint = config.anchorPoint or Vector2.zero
	label.BackgroundTransparency = config.backgroundTransparency or 1
	label.BackgroundColor3 = config.backgroundColor or Color3.new(0, 0, 0)
	label.TextXAlignment = config.textXAlignment or Enum.TextXAlignment.Center
	label.TextYAlignment = config.textYAlignment or Enum.TextYAlignment.Center
	label.TextScaled = true

	-- Add text size constraint
	UIHelpers.AddTextConstraint(label, config.minTextSize, config.maxTextSize)

	if config.parent then
		label.Parent = config.parent
	end

	return label
end

--[[
	Fade in a GUI element
	@param element The element to fade in
	@param duration Animation duration (default 0.2)
	@param properties Additional properties to tween
]]
function UIHelpers.FadeIn(element: GuiObject, duration: number?, properties: { [string]: any }?)
	local fadeTime = duration or DEFAULT_FADE_DURATION

	-- Set initial state
	element.Visible = true

	local tweenProps = properties or {}

	-- Handle different element types
	if element:IsA("Frame") or element:IsA("TextLabel") or element:IsA("TextButton") or element:IsA("ImageLabel") then
		if element.BackgroundTransparency == 1 then
			-- Already transparent, no background fade needed
			local _ = element -- Suppress warning
		else
			element.BackgroundTransparency = 1
			tweenProps.BackgroundTransparency = tweenProps.BackgroundTransparency or 0
		end
	end

	if element:IsA("TextLabel") or element:IsA("TextButton") then
		local textEl = element :: TextLabel
		textEl.TextTransparency = 1
		tweenProps.TextTransparency = tweenProps.TextTransparency or 0
	end

	if element:IsA("ImageLabel") or element:IsA("ImageButton") then
		local imageEl = element :: ImageLabel
		imageEl.ImageTransparency = 1
		tweenProps.ImageTransparency = tweenProps.ImageTransparency or 0
	end

	local tween = TweenService:Create(element, TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), tweenProps)
	tween:Play()

	return tween
end

--[[
	Fade out a GUI element
	@param element The element to fade out
	@param duration Animation duration (default 0.2)
	@param hideOnComplete Whether to set Visible = false after fade
]]
function UIHelpers.FadeOut(element: GuiObject, duration: number?, hideOnComplete: boolean?)
	local fadeTime = duration or DEFAULT_FADE_DURATION
	local tweenProps = {}

	-- Handle different element types
	if element:IsA("Frame") or element:IsA("TextLabel") or element:IsA("TextButton") or element:IsA("ImageLabel") then
		if element.BackgroundTransparency < 1 then
			tweenProps.BackgroundTransparency = 1
		end
	end

	if element:IsA("TextLabel") or element:IsA("TextButton") then
		tweenProps.TextTransparency = 1
	end

	if element:IsA("ImageLabel") or element:IsA("ImageButton") then
		tweenProps.ImageTransparency = 1
	end

	local tween = TweenService:Create(element, TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), tweenProps)
	tween:Play()

	if hideOnComplete ~= false then
		tween.Completed:Once(function()
			element.Visible = false
		end)
	end

	return tween
end

--[[
	Slide in a GUI element from a direction
	@param element The element to slide in
	@param direction Direction to slide from ("left", "right", "top", "bottom")
	@param duration Animation duration (default 0.2)
]]
function UIHelpers.SlideIn(element: GuiObject, direction: string, duration: number?)
	local fadeTime = duration or DEFAULT_FADE_DURATION

	local targetPosition = element.Position
	local startOffset = UDim2.fromOffset(0, 0)

	if direction == "left" then
		startOffset = UDim2.fromOffset(-element.AbsoluteSize.X - 50, 0)
	elseif direction == "right" then
		startOffset = UDim2.fromOffset(element.AbsoluteSize.X + 50, 0)
	elseif direction == "top" then
		startOffset = UDim2.fromOffset(0, -element.AbsoluteSize.Y - 50)
	elseif direction == "bottom" then
		startOffset = UDim2.fromOffset(0, element.AbsoluteSize.Y + 50)
	end

	element.Position = targetPosition + startOffset
	element.Visible = true

	local tween = TweenService:Create(element, TweenInfo.new(fadeTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = targetPosition,
	})
	tween:Play()

	return tween
end

--[[
	Slide out a GUI element to a direction
	@param element The element to slide out
	@param direction Direction to slide to ("left", "right", "top", "bottom")
	@param duration Animation duration (default 0.2)
	@param hideOnComplete Whether to set Visible = false after slide
]]
function UIHelpers.SlideOut(element: GuiObject, direction: string, duration: number?, hideOnComplete: boolean?)
	local fadeTime = duration or DEFAULT_FADE_DURATION

	local startPosition = element.Position
	local endOffset = UDim2.fromOffset(0, 0)

	if direction == "left" then
		endOffset = UDim2.fromOffset(-element.AbsoluteSize.X - 50, 0)
	elseif direction == "right" then
		endOffset = UDim2.fromOffset(element.AbsoluteSize.X + 50, 0)
	elseif direction == "top" then
		endOffset = UDim2.fromOffset(0, -element.AbsoluteSize.Y - 50)
	elseif direction == "bottom" then
		endOffset = UDim2.fromOffset(0, element.AbsoluteSize.Y + 50)
	end

	local tween = TweenService:Create(element, TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = startPosition + endOffset,
	})
	tween:Play()

	if hideOnComplete ~= false then
		tween.Completed:Once(function()
			element.Visible = false
			element.Position = startPosition -- Reset for next show
		end)
	end

	return tween
end

--[[
	Add a subtle pulse animation to draw attention
	@param element The element to pulse
	@param scale How much to scale (default 1.05)
	@param duration Duration of one pulse cycle (default 0.5)
]]
function UIHelpers.Pulse(element: GuiObject, scale: number?, duration: number?)
	local pulseScale = scale or 1.05
	local pulseDuration = duration or 0.5

	local originalSize = element.Size

	local growTween = TweenService:Create(element, TweenInfo.new(pulseDuration / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Size = UDim2.new(
			originalSize.X.Scale * pulseScale,
			originalSize.X.Offset * pulseScale,
			originalSize.Y.Scale * pulseScale,
			originalSize.Y.Offset * pulseScale
		),
	})

	local shrinkTween = TweenService:Create(element, TweenInfo.new(pulseDuration / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
		Size = originalSize,
	})

	growTween:Play()
	growTween.Completed:Once(function()
		shrinkTween:Play()
	end)

	return growTween
end

--[[
	Create a standard rounded frame
	@param config Configuration for the frame
]]
function UIHelpers.CreateRoundedFrame(config: {
	name: string?,
	size: UDim2?,
	position: UDim2?,
	anchorPoint: Vector2?,
	backgroundColor: Color3?,
	backgroundTransparency: number?,
	cornerRadius: number?,
	strokeColor: Color3?,
	strokeThickness: number?,
	parent: GuiObject?,
}): Frame
	local frame = Instance.new("Frame")
	frame.Name = config.name or "Frame"
	frame.Size = config.size or UDim2.fromScale(1, 1)
	frame.Position = config.position or UDim2.fromScale(0, 0)
	frame.AnchorPoint = config.anchorPoint or Vector2.zero
	frame.BackgroundColor3 = config.backgroundColor or Color3.fromRGB(30, 30, 35)
	frame.BackgroundTransparency = config.backgroundTransparency or 0
	frame.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, config.cornerRadius or 8)
	corner.Parent = frame

	if config.strokeColor then
		local stroke = Instance.new("UIStroke")
		stroke.Color = config.strokeColor
		stroke.Thickness = config.strokeThickness or 1
		stroke.Parent = frame
	end

	if config.parent then
		frame.Parent = config.parent
	end

	return frame
end

return UIHelpers
