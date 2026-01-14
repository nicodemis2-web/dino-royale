--!strict
--[[
	HealthDisplay.lua
	=================
	Player health and shield display
	Shows current HP, shield, and damage indicators
]]

local TweenService = game:GetService("TweenService")

local HealthDisplay = {}
HealthDisplay.__index = HealthDisplay

-- Display settings
local HEALTH_BAR_WIDTH = 200
local HEALTH_BAR_HEIGHT = 20
local SHIELD_BAR_HEIGHT = 8
local DAMAGE_FLASH_DURATION = 0.3
local LOW_HEALTH_THRESHOLD = 25
local LOW_HEALTH_PULSE_SPEED = 2

-- Colors
local HEALTH_COLORS = {
	high = Color3.fromRGB(50, 200, 50),
	medium = Color3.fromRGB(255, 200, 50),
	low = Color3.fromRGB(255, 50, 50),
}

local SHIELD_COLOR = Color3.fromRGB(50, 150, 255)
local BACKGROUND_COLOR = Color3.fromRGB(30, 30, 30)

export type HealthDisplayInstance = {
	frame: Frame,
	healthBar: Frame,
	healthLabel: TextLabel,
	shieldBar: Frame?,
	shieldLabel: TextLabel?,
	currentHealth: number,
	maxHealth: number,
	currentShield: number,
	maxShield: number,
	isLowHealth: boolean,
	pulseConnection: RBXScriptConnection?,

	Update: (self: HealthDisplayInstance, health: number, maxHealth: number, shield: number?, maxShield: number?) -> (),
	ShowDamage: (self: HealthDisplayInstance, amount: number) -> (),
	ShowHeal: (self: HealthDisplayInstance, amount: number) -> (),
	Destroy: (self: HealthDisplayInstance) -> (),
}

--[[
	Create a new health display
	@param parent Parent GUI element
	@param position UDim2 position
	@return HealthDisplayInstance
]]
function HealthDisplay.new(parent: GuiObject, position: UDim2): HealthDisplayInstance
	local self = setmetatable({}, HealthDisplay) :: any

	-- State
	self.currentHealth = 100
	self.maxHealth = 100
	self.currentShield = 0
	self.maxShield = 100
	self.isLowHealth = false
	self.pulseConnection = nil

	-- Main frame
	self.frame = Instance.new("Frame")
	self.frame.Name = "HealthDisplay"
	self.frame.Position = position
	self.frame.Size = UDim2.fromOffset(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT + SHIELD_BAR_HEIGHT + 4)
	self.frame.BackgroundTransparency = 1
	self.frame.Parent = parent

	-- Health bar background
	local healthBg = Instance.new("Frame")
	healthBg.Name = "HealthBackground"
	healthBg.Position = UDim2.fromOffset(0, SHIELD_BAR_HEIGHT + 4)
	healthBg.Size = UDim2.fromOffset(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)
	healthBg.BackgroundColor3 = BACKGROUND_COLOR
	healthBg.BorderSizePixel = 0
	healthBg.Parent = self.frame

	local healthBgCorner = Instance.new("UICorner")
	healthBgCorner.CornerRadius = UDim.new(0, 4)
	healthBgCorner.Parent = healthBg

	-- Health bar fill
	self.healthBar = Instance.new("Frame")
	self.healthBar.Name = "HealthBar"
	self.healthBar.Size = UDim2.fromScale(1, 1)
	self.healthBar.BackgroundColor3 = HEALTH_COLORS.high
	self.healthBar.BorderSizePixel = 0
	self.healthBar.Parent = healthBg

	local healthBarCorner = Instance.new("UICorner")
	healthBarCorner.CornerRadius = UDim.new(0, 4)
	healthBarCorner.Parent = self.healthBar

	-- Health label
	self.healthLabel = Instance.new("TextLabel")
	self.healthLabel.Name = "HealthLabel"
	self.healthLabel.Size = UDim2.fromScale(1, 1)
	self.healthLabel.BackgroundTransparency = 1
	self.healthLabel.Text = "100"
	self.healthLabel.TextColor3 = Color3.new(1, 1, 1)
	self.healthLabel.TextSize = 14
	self.healthLabel.Font = Enum.Font.GothamBold
	self.healthLabel.Parent = healthBg

	-- Shield bar background
	local shieldBg = Instance.new("Frame")
	shieldBg.Name = "ShieldBackground"
	shieldBg.Position = UDim2.fromOffset(0, 0)
	shieldBg.Size = UDim2.fromOffset(HEALTH_BAR_WIDTH, SHIELD_BAR_HEIGHT)
	shieldBg.BackgroundColor3 = BACKGROUND_COLOR
	shieldBg.BorderSizePixel = 0
	shieldBg.Visible = false
	shieldBg.Parent = self.frame

	local shieldBgCorner = Instance.new("UICorner")
	shieldBgCorner.CornerRadius = UDim.new(0, 2)
	shieldBgCorner.Parent = shieldBg

	-- Shield bar fill
	self.shieldBar = Instance.new("Frame")
	self.shieldBar.Name = "ShieldBar"
	self.shieldBar.Size = UDim2.fromScale(0, 1)
	self.shieldBar.BackgroundColor3 = SHIELD_COLOR
	self.shieldBar.BorderSizePixel = 0
	self.shieldBar.Parent = shieldBg

	local shieldBarCorner = Instance.new("UICorner")
	shieldBarCorner.CornerRadius = UDim.new(0, 2)
	shieldBarCorner.Parent = self.shieldBar

	-- Shield label
	self.shieldLabel = Instance.new("TextLabel")
	self.shieldLabel.Name = "ShieldLabel"
	self.shieldLabel.Size = UDim2.fromScale(1, 1)
	self.shieldLabel.BackgroundTransparency = 1
	self.shieldLabel.Text = ""
	self.shieldLabel.TextColor3 = Color3.new(1, 1, 1)
	self.shieldLabel.TextSize = 10
	self.shieldLabel.Font = Enum.Font.GothamBold
	self.shieldLabel.Parent = shieldBg

	return self
end

--[[
	Update health and shield display
]]
function HealthDisplay:Update(health: number, maxHealth: number, shield: number?, maxShield: number?)
	self.currentHealth = health
	self.maxHealth = maxHealth
	self.currentShield = shield or 0
	self.maxShield = maxShield or 100

	-- Update health bar
	local healthPercent = math.clamp(health / maxHealth, 0, 1)
	self.healthBar.Size = UDim2.fromScale(healthPercent, 1)
	self.healthLabel.Text = tostring(math.floor(health))

	-- Update health color
	if healthPercent > 0.5 then
		self.healthBar.BackgroundColor3 = HEALTH_COLORS.high
	elseif healthPercent > 0.25 then
		self.healthBar.BackgroundColor3 = HEALTH_COLORS.medium
	else
		self.healthBar.BackgroundColor3 = HEALTH_COLORS.low
	end

	-- Low health pulse effect
	local wasLowHealth = self.isLowHealth
	self.isLowHealth = health <= LOW_HEALTH_THRESHOLD and health > 0

	if self.isLowHealth and not wasLowHealth then
		self:StartLowHealthPulse()
	elseif not self.isLowHealth and wasLowHealth then
		self:StopLowHealthPulse()
	end

	-- Update shield bar
	local shieldBg = self.shieldBar and self.shieldBar.Parent :: Frame?
	if shieldBg then
		if self.currentShield > 0 then
			shieldBg.Visible = true
			local shieldPercent = math.clamp(self.currentShield / self.maxShield, 0, 1)
			self.shieldBar.Size = UDim2.fromScale(shieldPercent, 1)
			if self.shieldLabel then
				self.shieldLabel.Text = tostring(math.floor(self.currentShield))
			end
		else
			shieldBg.Visible = false
		end
	end
end

--[[
	Start low health pulse animation
]]
function HealthDisplay:StartLowHealthPulse()
	if self.pulseConnection then
		return
	end

	local RunService = game:GetService("RunService")
	self.pulseConnection = RunService.Heartbeat:Connect(function()
		local pulse = (math.sin(tick() * LOW_HEALTH_PULSE_SPEED * math.pi) + 1) / 2
		local transparency = 0.3 * pulse
		self.healthBar.BackgroundTransparency = transparency
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
	self.healthBar.BackgroundTransparency = 0
end

--[[
	Show damage indicator
]]
function HealthDisplay:ShowDamage(amount: number)
	-- Flash red
	local flash = Instance.new("Frame")
	flash.Name = "DamageFlash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
	flash.BackgroundTransparency = 0.5
	flash.ZIndex = 10
	flash.Parent = self.frame

	local flashCorner = Instance.new("UICorner")
	flashCorner.CornerRadius = UDim.new(0, 4)
	flashCorner.Parent = flash

	-- Fade out
	local tweenInfo = TweenInfo.new(DAMAGE_FLASH_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(flash, tweenInfo, { BackgroundTransparency = 1 })
	tween:Play()
	tween.Completed:Connect(function()
		flash:Destroy()
	end)

	-- Show damage number
	local damageLabel = Instance.new("TextLabel")
	damageLabel.Name = "DamageNumber"
	damageLabel.Position = UDim2.new(0.5, 0, 0, -20)
	damageLabel.Size = UDim2.fromOffset(50, 20)
	damageLabel.AnchorPoint = Vector2.new(0.5, 1)
	damageLabel.BackgroundTransparency = 1
	damageLabel.Text = `-{amount}`
	damageLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
	damageLabel.TextSize = 16
	damageLabel.Font = Enum.Font.GothamBold
	damageLabel.Parent = self.frame

	-- Float up and fade
	local floatTween = TweenService:Create(damageLabel, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, -50),
		TextTransparency = 1,
	})
	floatTween:Play()
	floatTween.Completed:Connect(function()
		damageLabel:Destroy()
	end)
end

--[[
	Show heal indicator
]]
function HealthDisplay:ShowHeal(amount: number)
	-- Flash green
	local flash = Instance.new("Frame")
	flash.Name = "HealFlash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(50, 255, 50)
	flash.BackgroundTransparency = 0.5
	flash.ZIndex = 10
	flash.Parent = self.frame

	local flashCorner = Instance.new("UICorner")
	flashCorner.CornerRadius = UDim.new(0, 4)
	flashCorner.Parent = flash

	-- Fade out
	local tweenInfo = TweenInfo.new(DAMAGE_FLASH_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(flash, tweenInfo, { BackgroundTransparency = 1 })
	tween:Play()
	tween.Completed:Connect(function()
		flash:Destroy()
	end)

	-- Show heal number
	local healLabel = Instance.new("TextLabel")
	healLabel.Name = "HealNumber"
	healLabel.Position = UDim2.new(0.5, 0, 0, -20)
	healLabel.Size = UDim2.fromOffset(50, 20)
	healLabel.AnchorPoint = Vector2.new(0.5, 1)
	healLabel.BackgroundTransparency = 1
	healLabel.Text = `+{amount}`
	healLabel.TextColor3 = Color3.fromRGB(50, 255, 50)
	healLabel.TextSize = 16
	healLabel.Font = Enum.Font.GothamBold
	healLabel.Parent = self.frame

	-- Float up and fade
	local floatTween = TweenService:Create(healLabel, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, -50),
		TextTransparency = 1,
	})
	floatTween:Play()
	floatTween.Completed:Connect(function()
		healLabel:Destroy()
	end)
end

--[[
	Destroy the display
]]
function HealthDisplay:Destroy()
	self:StopLowHealthPulse()
	self.frame:Destroy()
end

return HealthDisplay
