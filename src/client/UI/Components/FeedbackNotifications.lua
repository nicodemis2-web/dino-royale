--!strict
--[[
	FeedbackNotifications.lua
	=========================
	Player feedback notification system for Dino Royale.
	Shows XP gains, level ups, achievements, and other rewards.

	FEATURES:
	- XP gain popups with animated counters
	- Level up celebration effect
	- Achievement unlock banners
	- Kill reward notifications
	- Streak notifications (double kill, triple kill, etc.)
	- Loot pickup confirmations

	@client
]]

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local FeedbackNotifications = {}

--------------------------------------------------------------------------------
-- CONFIGURATION
--------------------------------------------------------------------------------

local COLORS = {
	XP = Color3.fromRGB(255, 215, 0), -- Gold
	LevelUp = Color3.fromRGB(255, 200, 50),
	Achievement = Color3.fromRGB(150, 100, 255), -- Purple
	Kill = Color3.fromRGB(255, 50, 50), -- Red
	Headshot = Color3.fromRGB(255, 100, 50), -- Orange
	Streak = Color3.fromRGB(255, 150, 0), -- Orange
	Loot = Color3.fromRGB(100, 255, 100), -- Green
	Rare = Color3.fromRGB(50, 150, 255), -- Blue
	Epic = Color3.fromRGB(180, 50, 255), -- Purple
	Legendary = Color3.fromRGB(255, 180, 50), -- Gold
}

local STREAK_NAMES = {
	[2] = "DOUBLE KILL",
	[3] = "TRIPLE KILL",
	[4] = "QUAD KILL",
	[5] = "PENTA KILL",
	[6] = "MEGA KILL",
	[7] = "ULTRA KILL",
	[8] = "MONSTER KILL",
}

local FONTS = {
	Title = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
	Body = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
}

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------

local localPlayer = Players.LocalPlayer
local playerGui: PlayerGui? = nil
local screenGui: ScreenGui? = nil
local notificationContainer: Frame? = nil
local xpContainer: Frame? = nil
local levelUpOverlay: Frame? = nil

local isInitialized = false
local activeNotifications: { Frame } = {}
local pendingXP: { { amount: number, reason: string } } = {}
local isProcessingXP = false

--------------------------------------------------------------------------------
-- UI CREATION
--------------------------------------------------------------------------------

local function createScreenGui()
	playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "FeedbackNotifications"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 50
	screenGui.Parent = playerGui

	-- Main notification container (right side, stacks up)
	notificationContainer = Instance.new("Frame")
	notificationContainer.Name = "NotificationContainer"
	notificationContainer.Size = UDim2.new(0, 350, 1, -200)
	notificationContainer.Position = UDim2.new(1, -370, 0, 100)
	notificationContainer.BackgroundTransparency = 1
	notificationContainer.Parent = screenGui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = notificationContainer

	-- XP notification container (center-right, for XP popups)
	xpContainer = Instance.new("Frame")
	xpContainer.Name = "XPContainer"
	xpContainer.Size = UDim2.new(0, 200, 0, 300)
	xpContainer.Position = UDim2.new(1, -220, 0.5, -150)
	xpContainer.BackgroundTransparency = 1
	xpContainer.Parent = screenGui

	-- Level up overlay (fullscreen celebration)
	levelUpOverlay = Instance.new("Frame")
	levelUpOverlay.Name = "LevelUpOverlay"
	levelUpOverlay.Size = UDim2.fromScale(1, 1)
	levelUpOverlay.BackgroundTransparency = 1
	levelUpOverlay.Visible = false
	levelUpOverlay.Parent = screenGui
end

--[[
	Create a notification banner
]]
local function createNotificationBanner(
	title: string,
	subtitle: string?,
	icon: string?,
	color: Color3,
	duration: number?
): Frame
	local banner = Instance.new("Frame")
	banner.Name = "Notification"
	banner.Size = UDim2.new(1, 0, 0, 60)
	banner.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	banner.BackgroundTransparency = 0.1
	banner.BorderSizePixel = 0
	banner.LayoutOrder = -tick() -- Newest at bottom
	banner.Parent = notificationContainer

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = banner

	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 2
	stroke.Transparency = 0.3
	stroke.Parent = banner

	-- Accent bar on left
	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.Size = UDim2.new(0, 4, 1, -8)
	accent.Position = UDim2.new(0, 4, 0, 4)
	accent.BackgroundColor3 = color
	accent.BorderSizePixel = 0
	accent.Parent = banner

	local accentCorner = Instance.new("UICorner")
	accentCorner.CornerRadius = UDim.new(0, 2)
	accentCorner.Parent = accent

	-- Icon (if provided)
	local contentOffset = 16
	if icon then
		local iconLabel = Instance.new("ImageLabel")
		iconLabel.Name = "Icon"
		iconLabel.Size = UDim2.new(0, 36, 0, 36)
		iconLabel.Position = UDim2.new(0, 16, 0.5, -18)
		iconLabel.BackgroundTransparency = 1
		iconLabel.Image = icon
		iconLabel.ImageColor3 = color
		iconLabel.Parent = banner
		contentOffset = 60
	end

	-- Title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, -contentOffset - 16, 0, subtitle and 24 or 40)
	titleLabel.Position = UDim2.new(0, contentOffset, 0, subtitle and 8 or 10)
	titleLabel.BackgroundTransparency = 1
	titleLabel.FontFace = FONTS.Title
	titleLabel.TextSize = subtitle and 16 or 18
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = title
	titleLabel.Parent = banner

	-- Subtitle (if provided)
	if subtitle then
		local subtitleLabel = Instance.new("TextLabel")
		subtitleLabel.Name = "Subtitle"
		subtitleLabel.Size = UDim2.new(1, -contentOffset - 16, 0, 20)
		subtitleLabel.Position = UDim2.new(0, contentOffset, 0, 32)
		subtitleLabel.BackgroundTransparency = 1
		subtitleLabel.FontFace = FONTS.Body
		subtitleLabel.TextSize = 14
		subtitleLabel.TextColor3 = color
		subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
		subtitleLabel.Text = subtitle
		subtitleLabel.Parent = banner
	end

	-- Animate in
	banner.Position = UDim2.new(1, 50, 0, 0)
	banner.GroupTransparency = 1

	TweenService:Create(banner, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 0, 0),
		GroupTransparency = 0,
	}):Play()

	-- Auto-remove after duration
	local actualDuration = duration or 4
	task.delay(actualDuration, function()
		if banner and banner.Parent then
			TweenService:Create(banner, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(1, 50, 0, 0),
				GroupTransparency = 1,
			}):Play()

			task.delay(0.3, function()
				if banner and banner.Parent then
					banner:Destroy()
				end
			end)
		end
	end)

	return banner
end

--[[
	Create floating XP text
]]
local function createXPPopup(amount: number, reason: string?)
	if not xpContainer then return end

	local popup = Instance.new("TextLabel")
	popup.Name = "XPPopup"
	popup.Size = UDim2.new(1, 0, 0, 30)
	popup.Position = UDim2.new(0, 0, 1, 0)
	popup.BackgroundTransparency = 1
	popup.FontFace = FONTS.Title
	popup.TextSize = 20
	popup.TextColor3 = COLORS.XP
	popup.TextStrokeTransparency = 0.5
	popup.TextStrokeColor3 = Color3.new(0, 0, 0)
	popup.Text = `+{amount} XP`
	if reason then
		popup.Text = `+{amount} XP ({reason})`
	end
	popup.Parent = xpContainer

	-- Animate up and fade
	TweenService:Create(popup, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 0.3, 0),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()

	task.delay(1.5, function()
		if popup and popup.Parent then
			popup:Destroy()
		end
	end)
end

--------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
--------------------------------------------------------------------------------

--[[
	Show XP gain notification
]]
function FeedbackNotifications.ShowXPGain(amount: number, reason: string?)
	createXPPopup(amount, reason)
end

--[[
	Show level up celebration
]]
function FeedbackNotifications.ShowLevelUp(newLevel: number)
	if not levelUpOverlay then return end

	levelUpOverlay.Visible = true

	-- Create level up text
	local levelText = Instance.new("TextLabel")
	levelText.Name = "LevelUpText"
	levelText.Size = UDim2.new(1, 0, 0, 100)
	levelText.Position = UDim2.new(0, 0, 0.4, 0)
	levelText.BackgroundTransparency = 1
	levelText.FontFace = FONTS.Title
	levelText.TextSize = 72
	levelText.TextColor3 = COLORS.LevelUp
	levelText.TextStrokeTransparency = 0
	levelText.TextStrokeColor3 = Color3.new(0, 0, 0)
	levelText.Text = "LEVEL UP!"
	levelText.TextTransparency = 1
	levelText.Parent = levelUpOverlay

	local levelNumber = Instance.new("TextLabel")
	levelNumber.Name = "LevelNumber"
	levelNumber.Size = UDim2.new(1, 0, 0, 60)
	levelNumber.Position = UDim2.new(0, 0, 0.5, 20)
	levelNumber.BackgroundTransparency = 1
	levelNumber.FontFace = FONTS.Title
	levelNumber.TextSize = 48
	levelNumber.TextColor3 = Color3.new(1, 1, 1)
	levelNumber.TextStrokeTransparency = 0
	levelNumber.TextStrokeColor3 = Color3.new(0, 0, 0)
	levelNumber.Text = `Level {newLevel}`
	levelNumber.TextTransparency = 1
	levelNumber.Parent = levelUpOverlay

	-- Animate
	TweenService:Create(levelText, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		TextTransparency = 0,
		TextSize = 80,
	}):Play()

	task.delay(0.3, function()
		TweenService:Create(levelNumber, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			TextTransparency = 0,
		}):Play()
	end)

	-- Fade out after delay
	task.delay(3, function()
		TweenService:Create(levelText, TweenInfo.new(0.5), {
			TextTransparency = 1,
		}):Play()
		TweenService:Create(levelNumber, TweenInfo.new(0.5), {
			TextTransparency = 1,
		}):Play()

		task.delay(0.5, function()
			levelText:Destroy()
			levelNumber:Destroy()
			if levelUpOverlay then
				levelUpOverlay.Visible = false
			end
		end)
	end)
end

--[[
	Show achievement unlock
]]
function FeedbackNotifications.ShowAchievement(name: string, description: string?, icon: string?)
	createNotificationBanner(
		name,
		description or "Achievement Unlocked!",
		icon or "rbxassetid://6031071053", -- Trophy icon
		COLORS.Achievement,
		5
	)
end

--[[
	Show kill notification
]]
function FeedbackNotifications.ShowKill(victimName: string, isHeadshot: boolean?, weaponName: string?)
	local title = isHeadshot and "HEADSHOT!" or "ELIMINATED"
	local subtitle = victimName
	if weaponName then
		subtitle = `{victimName} [{weaponName}]`
	end

	createNotificationBanner(
		title,
		subtitle,
		nil,
		isHeadshot and COLORS.Headshot or COLORS.Kill,
		3
	)
end

--[[
	Show kill streak notification
]]
function FeedbackNotifications.ShowKillStreak(streakCount: number)
	local streakName = STREAK_NAMES[streakCount] or `{streakCount}X KILL`

	if not levelUpOverlay then return end

	local streakText = Instance.new("TextLabel")
	streakText.Name = "StreakText"
	streakText.Size = UDim2.new(1, 0, 0, 80)
	streakText.Position = UDim2.new(0, 0, 0.35, 0)
	streakText.BackgroundTransparency = 1
	streakText.FontFace = FONTS.Title
	streakText.TextSize = 56
	streakText.TextColor3 = COLORS.Streak
	streakText.TextStrokeTransparency = 0
	streakText.TextStrokeColor3 = Color3.new(0, 0, 0)
	streakText.Text = streakName
	streakText.TextTransparency = 1
	streakText.Parent = levelUpOverlay

	levelUpOverlay.Visible = true

	-- Animate
	TweenService:Create(streakText, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		TextTransparency = 0,
		TextSize = 64,
	}):Play()

	-- Fade out
	task.delay(2, function()
		TweenService:Create(streakText, TweenInfo.new(0.3), {
			TextTransparency = 1,
		}):Play()

		task.delay(0.3, function()
			streakText:Destroy()
			-- Only hide overlay if no other children
			if levelUpOverlay and #levelUpOverlay:GetChildren() == 0 then
				levelUpOverlay.Visible = false
			end
		end)
	end)
end

--[[
	Show dinosaur kill notification
]]
function FeedbackNotifications.ShowDinoKill(dinoName: string, tier: string, xpReward: number?)
	local tierColor = COLORS.Kill
	if tier == "Rare" then
		tierColor = COLORS.Rare
	elseif tier == "Epic" then
		tierColor = COLORS.Epic
	elseif tier == "Legendary" then
		tierColor = COLORS.Legendary
	end

	local subtitle = tier
	if xpReward then
		subtitle = `{tier} (+{xpReward} XP)`
	end

	createNotificationBanner(
		`{dinoName} SLAIN`,
		subtitle,
		nil,
		tierColor,
		4
	)
end

--[[
	Show loot pickup notification
]]
function FeedbackNotifications.ShowLootPickup(itemName: string, rarity: string?, quantity: number?)
	local color = COLORS.Loot
	if rarity == "Rare" then
		color = COLORS.Rare
	elseif rarity == "Epic" then
		color = COLORS.Epic
	elseif rarity == "Legendary" then
		color = COLORS.Legendary
	end

	local title = itemName
	if quantity and quantity > 1 then
		title = `{itemName} x{quantity}`
	end

	createNotificationBanner(
		title,
		rarity or "Common",
		nil,
		color,
		2
	)
end

--[[
	Show generic notification
]]
function FeedbackNotifications.ShowNotification(title: string, subtitle: string?, color: Color3?, duration: number?)
	createNotificationBanner(
		title,
		subtitle,
		nil,
		color or Color3.new(1, 1, 1),
		duration or 4
	)
end

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

function FeedbackNotifications.Initialize()
	if isInitialized then return end

	createScreenGui()

	isInitialized = true
	print("[FeedbackNotifications] Initialized")
end

function FeedbackNotifications.Cleanup()
	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
	isInitialized = false
end

return FeedbackNotifications
