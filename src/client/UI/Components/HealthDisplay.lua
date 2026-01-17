--!strict
--[[
	HealthDisplay.lua
	=================
	Professional FPS health and shield display following AAA best practices.

	FEATURES:
	- Animated health bar with smooth tweening
	- Ghost bar showing previous health (damage visualization)
	- Segmented shield display with crack effects
	- Critical health vignette and pulse effects
	- Floating damage/heal numbers
	- Color transitions based on health percentage

	DESIGN PRINCIPLES (from GDD 12.4):
	- Glanceable and instantly understandable
	- High contrast for readability in any lighting
	- Immediate visual feedback for all state changes
	- Consistent with game's amber/fossil theme

	@client
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local HealthDisplay = {}
HealthDisplay.__index = HealthDisplay

--------------------------------------------------------------------------------
-- CONFIGURATION
--------------------------------------------------------------------------------

-- Bar dimensions
local HEALTH_BAR_WIDTH = 250
local HEALTH_BAR_HEIGHT = 24
local SHIELD_BAR_HEIGHT = 10
local SHIELD_SEGMENT_COUNT = 4
local CORNER_RADIUS = 6

-- Thresholds
local LOW_HEALTH_THRESHOLD = 25
local CRITICAL_HEALTH_THRESHOLD = 15
local _MEDIUM_HEALTH_THRESHOLD = 50

-- Animation timings
local HEALTH_TWEEN_TIME = 0.3
local GHOST_BAR_DELAY = 0.5
local GHOST_BAR_TWEEN_TIME = 0.8
local DAMAGE_FLASH_DURATION = 0.2
local PULSE_SPEED = 2.5
local NUMBER_FLOAT_DURATION = 1.0

-- Colors (from GDD 12.4)
local COLORS = {
	-- Health states
	HealthFull = Color3.fromRGB(50, 200, 50),       -- #32C832 - Bright green
	HealthMedium = Color3.fromRGB(255, 200, 50),    -- #FFC832 - Amber yellow
	HealthLow = Color3.fromRGB(255, 50, 50),        -- #FF3232 - Warning red
	HealthCritical = Color3.fromRGB(200, 30, 30),   -- Deeper red for critical

	-- Shield
	Shield = Color3.fromRGB(50, 150, 255),          -- #3296FF - Blue
	ShieldDepleted = Color3.fromRGB(30, 80, 150),   -- Darker blue

	-- Ghost bar
	GhostBar = Color3.fromRGB(255, 255, 255),       -- White ghost

	-- Background
	Background = Color3.fromRGB(20, 20, 20),
	BackgroundBorder = Color3.fromRGB(40, 40, 40),

	-- Damage/Heal numbers
	DamageNumber = Color3.fromRGB(255, 80, 80),
	HealNumber = Color3.fromRGB(80, 255, 80),

	-- Vignette
	CriticalVignette = Color3.fromRGB(200, 0, 0),
}

--------------------------------------------------------------------------------
-- TYPES
--------------------------------------------------------------------------------

export type HealthDisplayInstance = {
	frame: Frame,
	healthBarContainer: Frame,
	healthBar: Frame,
	ghostBar: Frame,
	healthLabel: TextLabel,
	healthIcon: ImageLabel,
	shieldBarContainer: Frame,
	shieldSegments: { Frame },
	shieldLabel: TextLabel,
	vignetteFrame: Frame?,

	-- State
	currentHealth: number,
	maxHealth: number,
	previousHealth: number,
	currentShield: number,
	maxShield: number,
	isLowHealth: boolean,
	isCriticalHealth: boolean,

	-- Connections
	pulseConnection: RBXScriptConnection?,
	ghostBarTween: Tween?,

	-- Methods
	Update: (self: HealthDisplayInstance, health: number, maxHealth: number, shield: number?, maxShield: number?) -> (),
	ShowDamage: (self: HealthDisplayInstance, amount: number) -> (),
	ShowHeal: (self: HealthDisplayInstance, amount: number) -> (),
	SetVisible: (self: HealthDisplayInstance, visible: boolean) -> (),
	Destroy: (self: HealthDisplayInstance) -> (),
}

--------------------------------------------------------------------------------
-- HELPER FUNCTIONS
--------------------------------------------------------------------------------

--[[
	Get health color based on percentage
]]
local function getHealthColor(healthPercent: number): Color3
	if healthPercent > 0.75 then
		return COLORS.HealthFull
	elseif healthPercent > 0.5 then
		-- Lerp from full to medium
		local t = (healthPercent - 0.5) / 0.25
		return COLORS.HealthMedium:Lerp(COLORS.HealthFull, t)
	elseif healthPercent > 0.25 then
		-- Lerp from medium to low
		local t = (healthPercent - 0.25) / 0.25
		return COLORS.HealthLow:Lerp(COLORS.HealthMedium, t)
	else
		return COLORS.HealthLow
	end
end

--[[
	Create a rounded corner instance
]]
local function addCorner(parent: GuiObject, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or CORNER_RADIUS)
	corner.Parent = parent
	return corner
end

--[[
	Create a stroke/border
]]
local function addStroke(parent: GuiObject, color: Color3, thickness: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

--------------------------------------------------------------------------------
-- CONSTRUCTOR
--------------------------------------------------------------------------------

--[[
	Create a new professional health display
	@param parent Parent GUI element
	@param position UDim2 position (anchor point is bottom-left)
	@return HealthDisplayInstance
]]
function HealthDisplay.new(parent: GuiObject, position: UDim2): HealthDisplayInstance
	local self = setmetatable({}, HealthDisplay) :: any

	-- Initialize state
	self.currentHealth = 100
	self.maxHealth = 100
	self.previousHealth = 100
	self.currentShield = 0
	self.maxShield = 100
	self.isLowHealth = false
	self.isCriticalHealth = false
	self.pulseConnection = nil
	self.ghostBarTween = nil
	self.shieldSegments = {}

	-- Main container frame
	self.frame = Instance.new("Frame")
	self.frame.Name = "HealthDisplay"
	self.frame.Position = position
	self.frame.AnchorPoint = Vector2.new(0, 1) -- Anchor bottom-left
	self.frame.Size = UDim2.fromOffset(HEALTH_BAR_WIDTH + 20, HEALTH_BAR_HEIGHT + SHIELD_BAR_HEIGHT + 30)
	self.frame.BackgroundTransparency = 1
	self.frame.Parent = parent

	-- Create shield bar container (above health)
	self:CreateShieldBar()

	-- Create health bar
	self:CreateHealthBar()

	-- Create critical vignette (fullscreen overlay)
	self:CreateVignette(parent)

	return self
end

--------------------------------------------------------------------------------
-- UI CREATION METHODS
--------------------------------------------------------------------------------

--[[
	Create the health bar components
]]
function HealthDisplay:CreateHealthBar()
	-- Health bar container with background
	self.healthBarContainer = Instance.new("Frame")
	self.healthBarContainer.Name = "HealthBarContainer"
	self.healthBarContainer.Position = UDim2.new(0, 10, 1, -(HEALTH_BAR_HEIGHT + 10))
	self.healthBarContainer.Size = UDim2.fromOffset(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)
	self.healthBarContainer.BackgroundColor3 = COLORS.Background
	self.healthBarContainer.BorderSizePixel = 0
	self.healthBarContainer.Parent = self.frame

	addCorner(self.healthBarContainer)
	addStroke(self.healthBarContainer, COLORS.BackgroundBorder, 2)

	-- Ghost bar (shows previous health, trails behind current)
	self.ghostBar = Instance.new("Frame")
	self.ghostBar.Name = "GhostBar"
	self.ghostBar.Position = UDim2.fromScale(0, 0)
	self.ghostBar.Size = UDim2.fromScale(1, 1)
	self.ghostBar.BackgroundColor3 = COLORS.GhostBar
	self.ghostBar.BackgroundTransparency = 0.7
	self.ghostBar.BorderSizePixel = 0
	self.ghostBar.ZIndex = 1
	self.ghostBar.Parent = self.healthBarContainer

	addCorner(self.ghostBar)

	-- Current health bar
	self.healthBar = Instance.new("Frame")
	self.healthBar.Name = "HealthBar"
	self.healthBar.Position = UDim2.fromScale(0, 0)
	self.healthBar.Size = UDim2.fromScale(1, 1)
	self.healthBar.BackgroundColor3 = COLORS.HealthFull
	self.healthBar.BorderSizePixel = 0
	self.healthBar.ZIndex = 2
	self.healthBar.Parent = self.healthBarContainer

	addCorner(self.healthBar)

	-- Health icon (heart)
	self.healthIcon = Instance.new("ImageLabel")
	self.healthIcon.Name = "HealthIcon"
	self.healthIcon.Position = UDim2.fromOffset(-25, 2)
	self.healthIcon.Size = UDim2.fromOffset(20, 20)
	self.healthIcon.BackgroundTransparency = 1
	self.healthIcon.Image = "rbxassetid://6031094678" -- Heart icon
	self.healthIcon.ImageColor3 = COLORS.HealthFull
	self.healthIcon.ZIndex = 3
	self.healthIcon.Parent = self.healthBarContainer

	-- Health text label
	self.healthLabel = Instance.new("TextLabel")
	self.healthLabel.Name = "HealthLabel"
	self.healthLabel.Position = UDim2.fromScale(0.5, 0.5)
	self.healthLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	self.healthLabel.Size = UDim2.fromScale(1, 1)
	self.healthLabel.BackgroundTransparency = 1
	self.healthLabel.Text = "100"
	self.healthLabel.TextColor3 = Color3.new(1, 1, 1)
	self.healthLabel.TextSize = 16
	self.healthLabel.Font = Enum.Font.GothamBold
	self.healthLabel.TextStrokeTransparency = 0.5
	self.healthLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	self.healthLabel.ZIndex = 4
	self.healthLabel.Parent = self.healthBarContainer
end

--[[
	Create segmented shield bar
]]
function HealthDisplay:CreateShieldBar()
	-- Shield bar container
	self.shieldBarContainer = Instance.new("Frame")
	self.shieldBarContainer.Name = "ShieldBarContainer"
	self.shieldBarContainer.Position = UDim2.new(0, 10, 1, -(HEALTH_BAR_HEIGHT + SHIELD_BAR_HEIGHT + 14))
	self.shieldBarContainer.Size = UDim2.fromOffset(HEALTH_BAR_WIDTH, SHIELD_BAR_HEIGHT)
	self.shieldBarContainer.BackgroundColor3 = COLORS.Background
	self.shieldBarContainer.BackgroundTransparency = 0.5
	self.shieldBarContainer.BorderSizePixel = 0
	self.shieldBarContainer.Visible = false
	self.shieldBarContainer.Parent = self.frame

	addCorner(self.shieldBarContainer, 4)

	-- Create shield segments
	local segmentWidth = (HEALTH_BAR_WIDTH - (SHIELD_SEGMENT_COUNT - 1) * 2) / SHIELD_SEGMENT_COUNT

	for i = 1, SHIELD_SEGMENT_COUNT do
		local segment = Instance.new("Frame")
		segment.Name = `ShieldSegment{i}`
		segment.Position = UDim2.fromOffset((i - 1) * (segmentWidth + 2), 0)
		segment.Size = UDim2.new(0, segmentWidth, 1, 0)
		segment.BackgroundColor3 = COLORS.Shield
		segment.BorderSizePixel = 0
		segment.Parent = self.shieldBarContainer

		addCorner(segment, 3)

		-- Add glow effect
		local glow = Instance.new("ImageLabel")
		glow.Name = "Glow"
		glow.Size = UDim2.new(1, 4, 1, 4)
		glow.Position = UDim2.fromOffset(-2, -2)
		glow.BackgroundTransparency = 1
		glow.Image = "rbxassetid://5028857084" -- Glow texture
		glow.ImageColor3 = COLORS.Shield
		glow.ImageTransparency = 0.7
		glow.ScaleType = Enum.ScaleType.Slice
		glow.SliceCenter = Rect.new(12, 12, 12, 12)
		glow.Parent = segment

		table.insert(self.shieldSegments, segment)
	end

	-- Shield label
	self.shieldLabel = Instance.new("TextLabel")
	self.shieldLabel.Name = "ShieldLabel"
	self.shieldLabel.Position = UDim2.new(1, 5, 0.5, 0)
	self.shieldLabel.AnchorPoint = Vector2.new(0, 0.5)
	self.shieldLabel.Size = UDim2.fromOffset(40, SHIELD_BAR_HEIGHT)
	self.shieldLabel.BackgroundTransparency = 1
	self.shieldLabel.Text = ""
	self.shieldLabel.TextColor3 = COLORS.Shield
	self.shieldLabel.TextSize = 12
	self.shieldLabel.Font = Enum.Font.GothamBold
	self.shieldLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.shieldLabel.Parent = self.shieldBarContainer
end

--[[
	Create critical health vignette effect
]]
function HealthDisplay:CreateVignette(_parent: GuiObject)
	-- Get the PlayerGui for fullscreen effect
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui

	-- Create vignette ScreenGui
	local vignetteGui = Instance.new("ScreenGui")
	vignetteGui.Name = "HealthVignette"
	vignetteGui.ResetOnSpawn = false
	vignetteGui.IgnoreGuiInset = true
	vignetteGui.DisplayOrder = 5
	vignetteGui.Parent = playerGui

	-- Vignette frame (red gradient around edges)
	self.vignetteFrame = Instance.new("Frame")
	self.vignetteFrame.Name = "Vignette"
	self.vignetteFrame.Size = UDim2.fromScale(1, 1)
	self.vignetteFrame.Position = UDim2.fromScale(0.5, 0.5)
	self.vignetteFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	self.vignetteFrame.BackgroundTransparency = 1
	self.vignetteFrame.Visible = false
	self.vignetteFrame.Parent = vignetteGui

	-- Create vignette gradient (4 edge frames)
	local edges = {
		{ name = "Top", pos = UDim2.fromScale(0.5, 0), anchor = Vector2.new(0.5, 0), size = UDim2.new(1, 0, 0.2, 0), rot = 180 },
		{ name = "Bottom", pos = UDim2.fromScale(0.5, 1), anchor = Vector2.new(0.5, 1), size = UDim2.new(1, 0, 0.2, 0), rot = 0 },
		{ name = "Left", pos = UDim2.fromScale(0, 0.5), anchor = Vector2.new(0, 0.5), size = UDim2.new(0.15, 0, 1, 0), rot = 90 },
		{ name = "Right", pos = UDim2.fromScale(1, 0.5), anchor = Vector2.new(1, 0.5), size = UDim2.new(0.15, 0, 1, 0), rot = -90 },
	}

	for _, edge in ipairs(edges) do
		local edgeFrame = Instance.new("Frame")
		edgeFrame.Name = edge.name
		edgeFrame.Position = edge.pos
		edgeFrame.AnchorPoint = edge.anchor
		edgeFrame.Size = edge.size
		edgeFrame.BackgroundTransparency = 1
		edgeFrame.Parent = self.vignetteFrame

		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new(COLORS.CriticalVignette)
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(0.5, 0.8),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Rotation = edge.rot
		gradient.Parent = edgeFrame

		edgeFrame.BackgroundColor3 = COLORS.CriticalVignette
		edgeFrame.BackgroundTransparency = 0
	end
end

--------------------------------------------------------------------------------
-- UPDATE METHODS
--------------------------------------------------------------------------------

--[[
	Update health and shield values with animations
]]
function HealthDisplay:Update(health: number, maxHealth: number, shield: number?, maxShield: number?)
	local previousHealth = self.currentHealth
	self.previousHealth = previousHealth
	self.currentHealth = health
	self.maxHealth = maxHealth
	self.currentShield = shield or 0
	self.maxShield = maxShield or 100

	-- Calculate health percentage
	local healthPercent = math.clamp(health / maxHealth, 0, 1)

	-- Update health bar with smooth tween
	local healthTweenInfo = TweenInfo.new(HEALTH_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local healthTween = TweenService:Create(self.healthBar, healthTweenInfo, {
		Size = UDim2.new(healthPercent, 0, 1, 0),
	})
	healthTween:Play()

	-- Update ghost bar (delayed, shows damage taken)
	if health < previousHealth then
		-- Cancel existing ghost tween
		if self.ghostBarTween then
			self.ghostBarTween:Cancel()
		end

		-- Delay before ghost bar catches up
		task.delay(GHOST_BAR_DELAY, function()
			if self.ghostBar then
				local ghostTweenInfo = TweenInfo.new(GHOST_BAR_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				self.ghostBarTween = TweenService:Create(self.ghostBar, ghostTweenInfo, {
					Size = UDim2.new(healthPercent, 0, 1, 0),
				})
				self.ghostBarTween:Play()
			end
		end)
	else
		-- Healing - ghost bar moves with health bar
		self.ghostBar.Size = UDim2.new(healthPercent, 0, 1, 0)
	end

	-- Update health label
	self.healthLabel.Text = tostring(math.floor(health))

	-- Update health color
	local healthColor = getHealthColor(healthPercent)
	TweenService:Create(self.healthBar, healthTweenInfo, {
		BackgroundColor3 = healthColor,
	}):Play()
	self.healthIcon.ImageColor3 = healthColor

	-- Check health states
	local wasLowHealth = self.isLowHealth
	local wasCritical = self.isCriticalHealth

	self.isLowHealth = health <= LOW_HEALTH_THRESHOLD and health > 0
	self.isCriticalHealth = health <= CRITICAL_HEALTH_THRESHOLD and health > 0

	-- Start/stop pulse effect
	if self.isLowHealth and not wasLowHealth then
		self:StartLowHealthPulse()
	elseif not self.isLowHealth and wasLowHealth then
		self:StopLowHealthPulse()
	end

	-- Show/hide critical vignette
	if self.isCriticalHealth and not wasCritical then
		self:ShowCriticalVignette(true)
	elseif not self.isCriticalHealth and wasCritical then
		self:ShowCriticalVignette(false)
	end

	-- Update shield
	self:UpdateShield()
end

--[[
	Update shield segments
]]
function HealthDisplay:UpdateShield()
	local hasShield = self.currentShield > 0
	self.shieldBarContainer.Visible = hasShield

	if not hasShield then
		return
	end

	-- Calculate shield per segment
	local shieldPerSegment = self.maxShield / SHIELD_SEGMENT_COUNT
	local remainingShield = self.currentShield

	for _, segment in ipairs(self.shieldSegments) do
		local segmentShield = math.clamp(remainingShield, 0, shieldPerSegment)
		local fillPercent = segmentShield / shieldPerSegment
		remainingShield = remainingShield - shieldPerSegment

		if fillPercent >= 1 then
			-- Full segment
			segment.BackgroundColor3 = COLORS.Shield
			segment.BackgroundTransparency = 0
		elseif fillPercent > 0 then
			-- Partial segment (cracked appearance)
			segment.BackgroundColor3 = COLORS.ShieldDepleted
			segment.BackgroundTransparency = 0.3
		else
			-- Empty segment
			segment.BackgroundColor3 = COLORS.ShieldDepleted
			segment.BackgroundTransparency = 0.7
		end
	end

	-- Update shield label
	self.shieldLabel.Text = tostring(math.floor(self.currentShield))
end

--------------------------------------------------------------------------------
-- EFFECT METHODS
--------------------------------------------------------------------------------

--[[
	Start low health pulse animation
]]
function HealthDisplay:StartLowHealthPulse()
	if self.pulseConnection then
		return
	end

	self.pulseConnection = RunService.Heartbeat:Connect(function()
		local pulse = (math.sin(tick() * PULSE_SPEED * math.pi) + 1) / 2
		local transparency = 0.2 * pulse

		-- Pulse health bar and icon
		self.healthBar.BackgroundTransparency = transparency
		self.healthIcon.ImageTransparency = transparency * 0.5
	end)
end

--[[
	Stop low health pulse animation
]]
function HealthDisplay:StopLowHealthPulse()
	if self.pulseConnection then
		self.pulseConnection:Disconnect()
		self.pulseConnection = nil
	end

	-- Reset transparency
	self.healthBar.BackgroundTransparency = 0
	self.healthIcon.ImageTransparency = 0
end

--[[
	Show/hide critical health vignette
]]
function HealthDisplay:ShowCriticalVignette(show: boolean)
	if not self.vignetteFrame then
		return
	end

	if show then
		self.vignetteFrame.Visible = true

		-- Pulse the vignette
		for _, child in ipairs(self.vignetteFrame:GetChildren()) do
			if child:IsA("Frame") then
				local tween = TweenService:Create(child, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
					BackgroundTransparency = 0.5,
				})
				tween:Play()
			end
		end
	else
		self.vignetteFrame.Visible = false

		-- Stop all tweens
		for _, child in ipairs(self.vignetteFrame:GetChildren()) do
			if child:IsA("Frame") then
				child.BackgroundTransparency = 0
			end
		end
	end
end

--[[
	Show damage taken effect with floating number
]]
function HealthDisplay:ShowDamage(amount: number)
	-- Flash red on health bar
	local flash = Instance.new("Frame")
	flash.Name = "DamageFlash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = COLORS.DamageNumber
	flash.BackgroundTransparency = 0.3
	flash.ZIndex = 10
	flash.Parent = self.healthBarContainer

	addCorner(flash)

	-- Fade out flash
	local flashTween = TweenService:Create(flash, TweenInfo.new(DAMAGE_FLASH_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	})
	flashTween:Play()
	flashTween.Completed:Once(function()
		flash:Destroy()
	end)

	-- Create floating damage number
	local damageLabel = Instance.new("TextLabel")
	damageLabel.Name = "DamageNumber"
	damageLabel.Position = UDim2.new(0.5, math.random(-20, 20), 0, -10)
	damageLabel.AnchorPoint = Vector2.new(0.5, 1)
	damageLabel.Size = UDim2.fromOffset(60, 24)
	damageLabel.BackgroundTransparency = 1
	damageLabel.Text = `-{amount}`
	damageLabel.TextColor3 = COLORS.DamageNumber
	damageLabel.TextSize = 18
	damageLabel.Font = Enum.Font.GothamBold
	damageLabel.TextStrokeTransparency = 0.3
	damageLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	damageLabel.ZIndex = 15
	damageLabel.Parent = self.healthBarContainer

	-- Float up and fade
	local floatTween = TweenService:Create(damageLabel, TweenInfo.new(NUMBER_FLOAT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, math.random(-30, 30), 0, -50),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	floatTween:Play()
	floatTween.Completed:Once(function()
		damageLabel:Destroy()
	end)
end

--[[
	Show heal received effect with floating number
]]
function HealthDisplay:ShowHeal(amount: number)
	-- Flash green on health bar
	local flash = Instance.new("Frame")
	flash.Name = "HealFlash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = COLORS.HealNumber
	flash.BackgroundTransparency = 0.3
	flash.ZIndex = 10
	flash.Parent = self.healthBarContainer

	addCorner(flash)

	-- Fade out flash
	local flashTween = TweenService:Create(flash, TweenInfo.new(DAMAGE_FLASH_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	})
	flashTween:Play()
	flashTween.Completed:Once(function()
		flash:Destroy()
	end)

	-- Create floating heal number
	local healLabel = Instance.new("TextLabel")
	healLabel.Name = "HealNumber"
	healLabel.Position = UDim2.new(0.5, math.random(-20, 20), 0, -10)
	healLabel.AnchorPoint = Vector2.new(0.5, 1)
	healLabel.Size = UDim2.fromOffset(60, 24)
	healLabel.BackgroundTransparency = 1
	healLabel.Text = `+{amount}`
	healLabel.TextColor3 = COLORS.HealNumber
	healLabel.TextSize = 18
	healLabel.Font = Enum.Font.GothamBold
	healLabel.TextStrokeTransparency = 0.3
	healLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	healLabel.ZIndex = 15
	healLabel.Parent = self.healthBarContainer

	-- Float up and fade
	local floatTween = TweenService:Create(healLabel, TweenInfo.new(NUMBER_FLOAT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, math.random(-30, 30), 0, -50),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	floatTween:Play()
	floatTween.Completed:Once(function()
		healLabel:Destroy()
	end)
end

--[[
	Set visibility with optional fade
]]
function HealthDisplay:SetVisible(visible: boolean)
	self.frame.Visible = visible

	if not visible then
		self:ShowCriticalVignette(false)
	end
end

--[[
	Cleanup and destroy
]]
function HealthDisplay:Destroy()
	self:StopLowHealthPulse()
	self:ShowCriticalVignette(false)

	if self.ghostBarTween then
		self.ghostBarTween:Cancel()
	end

	-- Destroy vignette GUI
	if self.vignetteFrame and self.vignetteFrame.Parent then
		self.vignetteFrame.Parent:Destroy()
	end

	self.frame:Destroy()
end

return HealthDisplay
