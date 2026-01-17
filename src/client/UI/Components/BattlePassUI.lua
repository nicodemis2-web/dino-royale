--!strict
--[[
	BattlePassUI.lua
	================
	Client-side Battle Pass display and interaction
	Based on GDD Section 8.1: Battle Pass System
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Events = require(ReplicatedStorage.Shared.Events)
local BattlePassData = require(ReplicatedStorage.Shared.BattlePassData)

local BattlePassUI = {}

-- State
local player = Players.LocalPlayer
local screenGui: ScreenGui? = nil
local mainFrame: Frame? = nil
local tierContainer: ScrollingFrame? = nil
local isVisible = false

-- Data
local currentXP = 0
local currentTier = 0
local isPremium = false
local claimedRewards: { [string]: boolean } = {}

-- Constants
local TIER_WIDTH = 120
local TIER_HEIGHT = 180
local VISIBLE_TIERS = 7

--[[
	Initialize the battle pass UI
]]
function BattlePassUI.Initialize()
	print("[BattlePassUI] Initializing...")

	BattlePassUI.CreateUI()
	BattlePassUI.SetupEventListeners()

	-- Request initial data
	Events.FireServer("BattlePass", "RequestData", {})

	print("[BattlePassUI] Initialized")
end

--[[
	Create UI elements
]]
function BattlePassUI.CreateUI()
	local playerGui = player:WaitForChild("PlayerGui")

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BattlePassGui"
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
			BattlePassUI.Hide()
		end
	end)

	-- Main container
	mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(0, 900, 0, 600)
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
	header.Size = UDim2.new(1, 0, 0, 80)
	header.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	header.BorderSizePixel = 0
	header.Parent = mainFrame

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 12)
	headerCorner.Parent = header

	-- Season title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(0.5, 0, 0, 30)
	titleLabel.Position = UDim2.fromOffset(20, 15)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
	titleLabel.TextSize = 24
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Text = "SEASON 1: WELCOME TO THE PARK"
	titleLabel.Parent = header

	-- Tier display
	local tierLabel = Instance.new("TextLabel")
	tierLabel.Name = "Tier"
	tierLabel.Size = UDim2.new(0, 150, 0, 30)
	tierLabel.Position = UDim2.new(1, -170, 0, 15)
	tierLabel.BackgroundTransparency = 1
	tierLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	tierLabel.TextSize = 20
	tierLabel.Font = Enum.Font.GothamBold
	tierLabel.TextXAlignment = Enum.TextXAlignment.Right
	tierLabel.Text = "TIER 0"
	tierLabel.Parent = header

	-- XP Progress bar
	local progressBg = Instance.new("Frame")
	progressBg.Name = "ProgressBg"
	progressBg.Size = UDim2.new(0.7, 0, 0, 20)
	progressBg.Position = UDim2.new(0, 20, 0, 50)
	progressBg.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
	progressBg.BorderSizePixel = 0
	progressBg.Parent = header

	local progressCorner = Instance.new("UICorner")
	progressCorner.CornerRadius = UDim.new(0, 10)
	progressCorner.Parent = progressBg

	local progressFill = Instance.new("Frame")
	progressFill.Name = "Fill"
	progressFill.Size = UDim2.new(0, 0, 1, 0)
	progressFill.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressBg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 10)
	fillCorner.Parent = progressFill

	local xpLabel = Instance.new("TextLabel")
	xpLabel.Name = "XPLabel"
	xpLabel.Size = UDim2.new(0.25, -30, 0, 20)
	xpLabel.Position = UDim2.new(0.75, 0, 0, 50)
	xpLabel.BackgroundTransparency = 1
	xpLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
	xpLabel.TextSize = 14
	xpLabel.Font = Enum.Font.Gotham
	xpLabel.TextXAlignment = Enum.TextXAlignment.Right
	xpLabel.Text = "0 / 1000 XP"
	xpLabel.Parent = header

	-- Close button
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "Close"
	closeButton.Size = UDim2.new(0, 40, 0, 40)
	closeButton.Position = UDim2.new(1, -50, 0, 20)
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
		BattlePassUI.Hide()
	end)

	-- Tier container
	tierContainer = Instance.new("ScrollingFrame")
	tierContainer.Name = "TierContainer"
	tierContainer.Size = UDim2.new(1, -40, 0, 400)
	tierContainer.Position = UDim2.new(0, 20, 0, 100)
	tierContainer.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	tierContainer.BorderSizePixel = 0
	tierContainer.ScrollBarThickness = 8
	tierContainer.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
	tierContainer.ScrollingDirection = Enum.ScrollingDirection.X
	tierContainer.CanvasSize = UDim2.new(0, TIER_WIDTH * 100, 0, 0)
	tierContainer.Parent = mainFrame

	local tierContainerCorner = Instance.new("UICorner")
	tierContainerCorner.CornerRadius = UDim.new(0, 8)
	tierContainerCorner.Parent = tierContainer

	-- Create tier frames
	BattlePassUI.CreateTierFrames()

	-- Premium purchase button
	local premiumButton = Instance.new("TextButton")
	premiumButton.Name = "PremiumButton"
	premiumButton.Size = UDim2.new(0, 200, 0, 50)
	premiumButton.Position = UDim2.new(0.5, 0, 1, -70)
	premiumButton.AnchorPoint = Vector2.new(0.5, 0)
	premiumButton.BackgroundColor3 = Color3.fromRGB(255, 180, 50)
	premiumButton.BorderSizePixel = 0
	premiumButton.TextColor3 = Color3.fromRGB(30, 30, 30)
	premiumButton.TextSize = 16
	premiumButton.Font = Enum.Font.GothamBold
	premiumButton.Text = "GET PREMIUM - 950 R$"
	premiumButton.Parent = mainFrame

	local premiumCorner = Instance.new("UICorner")
	premiumCorner.CornerRadius = UDim.new(0, 8)
	premiumCorner.Parent = premiumButton

	premiumButton.MouseButton1Click:Connect(function()
		if not isPremium then
			Events.FireServer("BattlePass", "PurchasePremium", {})
		end
	end)
end

--[[
	Create all tier frames
]]
function BattlePassUI.CreateTierFrames()
	if not tierContainer then return end

	for tier = 1, 100 do
		local tierData = BattlePassData.Tiers[tier]

		local tierFrame = Instance.new("Frame")
		tierFrame.Name = `Tier_{tier}`
		tierFrame.Size = UDim2.new(0, TIER_WIDTH - 10, 0, TIER_HEIGHT)
		tierFrame.Position = UDim2.new(0, (tier - 1) * TIER_WIDTH + 5, 0, 10)
		tierFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
		tierFrame.BorderSizePixel = 0
		tierFrame.Parent = tierContainer

		local tierCorner = Instance.new("UICorner")
		tierCorner.CornerRadius = UDim.new(0, 6)
		tierCorner.Parent = tierFrame

		-- Tier number
		local tierNum = Instance.new("TextLabel")
		tierNum.Name = "TierNum"
		tierNum.Size = UDim2.new(1, 0, 0, 25)
		tierNum.BackgroundTransparency = 1
		tierNum.TextColor3 = Color3.fromRGB(150, 150, 150)
		tierNum.TextSize = 14
		tierNum.Font = Enum.Font.GothamBold
		tierNum.Text = `TIER {tier}`
		tierNum.Parent = tierFrame

		-- Free reward section
		local freeSection = Instance.new("Frame")
		freeSection.Name = "FreeReward"
		freeSection.Size = UDim2.new(1, -10, 0, 60)
		freeSection.Position = UDim2.new(0, 5, 0, 30)
		freeSection.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
		freeSection.BorderSizePixel = 0
		freeSection.Parent = tierFrame

		local freeSectionCorner = Instance.new("UICorner")
		freeSectionCorner.CornerRadius = UDim.new(0, 4)
		freeSectionCorner.Parent = freeSection

		local freeLabel = Instance.new("TextLabel")
		freeLabel.Name = "Label"
		freeLabel.Size = UDim2.fromScale(1, 0.5)
		freeLabel.BackgroundTransparency = 1
		freeLabel.TextColor3 = Color3.fromRGB(100, 100, 100)
		freeLabel.TextSize = 10
		freeLabel.Font = Enum.Font.Gotham
		freeLabel.Text = "FREE"
		freeLabel.Parent = freeSection

		local freeName = Instance.new("TextLabel")
		freeName.Name = "Name"
		freeName.Size = UDim2.fromScale(1, 0.5)
		freeName.Position = UDim2.fromScale(0, 0.5)
		freeName.BackgroundTransparency = 1
		freeName.TextColor3 = Color3.fromRGB(200, 200, 200)
		freeName.TextSize = 11
		freeName.TextWrapped = true
		freeName.Font = Enum.Font.Gotham
		freeName.Text = tierData.freeReward and tierData.freeReward.name or "-"
		freeName.Parent = freeSection

		-- Premium reward section
		local premiumSection = Instance.new("Frame")
		premiumSection.Name = "PremiumReward"
		premiumSection.Size = UDim2.new(1, -10, 0, 60)
		premiumSection.Position = UDim2.new(0, 5, 0, 95)
		premiumSection.BackgroundColor3 = Color3.fromRGB(60, 50, 30)
		premiumSection.BorderSizePixel = 0
		premiumSection.Parent = tierFrame

		local premiumSectionCorner = Instance.new("UICorner")
		premiumSectionCorner.CornerRadius = UDim.new(0, 4)
		premiumSectionCorner.Parent = premiumSection

		local premiumLabel = Instance.new("TextLabel")
		premiumLabel.Name = "Label"
		premiumLabel.Size = UDim2.fromScale(1, 0.5)
		premiumLabel.BackgroundTransparency = 1
		premiumLabel.TextColor3 = Color3.fromRGB(200, 150, 50)
		premiumLabel.TextSize = 10
		premiumLabel.Font = Enum.Font.GothamBold
		premiumLabel.Text = "PREMIUM"
		premiumLabel.Parent = premiumSection

		local premiumName = Instance.new("TextLabel")
		premiumName.Name = "Name"
		premiumName.Size = UDim2.fromScale(1, 0.5)
		premiumName.Position = UDim2.fromScale(0, 0.5)
		premiumName.BackgroundTransparency = 1
		premiumName.TextColor3 = Color3.fromRGB(255, 200, 100)
		premiumName.TextSize = 11
		premiumName.TextWrapped = true
		premiumName.Font = Enum.Font.Gotham
		premiumName.Text = tierData.premiumReward and tierData.premiumReward.name or "-"
		premiumName.Parent = premiumSection

		-- Lock indicator (for premium)
		local lockIcon = Instance.new("TextLabel")
		lockIcon.Name = "Lock"
		lockIcon.Size = UDim2.new(0, 20, 0, 20)
		lockIcon.Position = UDim2.new(1, -22, 0, 2)
		lockIcon.BackgroundTransparency = 1
		lockIcon.TextColor3 = Color3.fromRGB(150, 100, 50)
		lockIcon.TextSize = 14
		lockIcon.Font = Enum.Font.GothamBold
		lockIcon.Text = "🔒"
		lockIcon.Parent = premiumSection

		-- Claim button
		local claimButton = Instance.new("TextButton")
		claimButton.Name = "ClaimButton"
		claimButton.Size = UDim2.new(1, -10, 0, 25)
		claimButton.Position = UDim2.new(0, 5, 1, -30)
		claimButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
		claimButton.BorderSizePixel = 0
		claimButton.TextColor3 = Color3.fromRGB(150, 150, 150)
		claimButton.TextSize = 12
		claimButton.Font = Enum.Font.GothamBold
		claimButton.Text = "LOCKED"
		claimButton.Parent = tierFrame

		local claimCorner = Instance.new("UICorner")
		claimCorner.CornerRadius = UDim.new(0, 4)
		claimCorner.Parent = claimButton

		claimButton.MouseButton1Click:Connect(function()
			BattlePassUI.OnClaimClicked(tier)
		end)
	end
end

--[[
	Setup event listeners
]]
function BattlePassUI.SetupEventListeners()
	-- Listen for data updates
	Events.OnClientEvent("BattlePass", "DataUpdate", function(data)
		BattlePassUI.OnDataUpdate(data)
	end)

	-- Listen for XP gained
	Events.OnClientEvent("BattlePass", "XPGained", function(data)
		BattlePassUI.OnXPGained(data)
	end)

	-- Listen for tier up
	Events.OnClientEvent("BattlePass", "TierUp", function(data)
		BattlePassUI.OnTierUp(data)
	end)

	-- Listen for reward claimed
	Events.OnClientEvent("BattlePass", "RewardClaimed", function(data)
		BattlePassUI.OnRewardClaimed(data)
	end)

	-- Listen for premium purchased
	Events.OnClientEvent("BattlePass", "PremiumPurchased", function()
		BattlePassUI.OnPremiumPurchased()
	end)
end

--[[
	Handle data update
]]
function BattlePassUI.OnDataUpdate(data: any)
	currentXP = data.xp or 0
	currentTier = data.tier or 0
	isPremium = data.isPremium or false
	claimedRewards = data.claimedRewards or {}

	BattlePassUI.UpdateDisplay()
end

--[[
	Handle XP gained
]]
function BattlePassUI.OnXPGained(data: any)
	currentXP = data.total or currentXP
	currentTier = data.tier or currentTier

	BattlePassUI.UpdateDisplay()
end

--[[
	Handle tier up
]]
function BattlePassUI.OnTierUp(data: any)
	currentTier = data.tier or currentTier

	BattlePassUI.UpdateDisplay()

	-- Scroll to current tier
	BattlePassUI.ScrollToTier(currentTier)
end

--[[
	Handle reward claimed
]]
function BattlePassUI.OnRewardClaimed(data: any)
	local claimKey = `{data.tier}_{data.isPremium and "premium" or "free"}`
	claimedRewards[claimKey] = true

	BattlePassUI.UpdateTierDisplay(data.tier)
end

--[[
	Handle premium purchased
]]
function BattlePassUI.OnPremiumPurchased()
	isPremium = true
	BattlePassUI.UpdateDisplay()
end

--[[
	Update the display
]]
function BattlePassUI.UpdateDisplay()
	if not mainFrame then return end

	-- Update header
	local header = mainFrame:FindFirstChild("Header") :: Frame?
	if header then
		local tierLabel = header:FindFirstChild("Tier") :: TextLabel?
		if tierLabel then
			tierLabel.Text = `TIER {currentTier}`
		end

		local progressBg = header:FindFirstChild("ProgressBg") :: Frame?
		if progressBg then
			local fill = progressBg:FindFirstChild("Fill") :: Frame?
			if fill then
				local progress = BattlePassData.GetTierProgress(currentXP)
				TweenService:Create(fill, TweenInfo.new(0.3), {
					Size = UDim2.new(progress, 0, 1, 0)
				}):Play()
			end
		end

		local xpLabel = header:FindFirstChild("XPLabel") :: TextLabel?
		if xpLabel then
			local nextTierXP = currentTier < 100 and BattlePassData.GetXPForTier(currentTier + 1) or BattlePassData.GetMaxXP()
			local currentTierXP = currentTier > 0 and BattlePassData.GetXPForTier(currentTier) or 0
			local xpIntoTier = currentXP - currentTierXP
			local xpNeeded = nextTierXP - currentTierXP
			xpLabel.Text = `{xpIntoTier} / {xpNeeded} XP`
		end
	end

	-- Update premium button
	local premiumButton = mainFrame:FindFirstChild("PremiumButton") :: TextButton?
	if premiumButton then
		if isPremium then
			premiumButton.Text = "PREMIUM ACTIVE"
			premiumButton.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
		else
			premiumButton.Text = `GET PREMIUM - {BattlePassData.CurrentSeason.premiumPrice} R$`
			premiumButton.BackgroundColor3 = Color3.fromRGB(255, 180, 50)
		end
	end

	-- Update all tier displays
	for tier = 1, 100 do
		BattlePassUI.UpdateTierDisplay(tier)
	end
end

--[[
	Update a single tier display
]]
function BattlePassUI.UpdateTierDisplay(tier: number)
	if not tierContainer then return end

	local tierFrame = tierContainer:FindFirstChild(`Tier_{tier}`) :: Frame?
	if not tierFrame then return end

	local isUnlocked = tier <= currentTier
	local freeClaimKey = `{tier}_free`
	local premiumClaimKey = `{tier}_premium`
	local freeClaimed = claimedRewards[freeClaimKey]
	local premiumClaimed = claimedRewards[premiumClaimKey]

	local tierData = BattlePassData.Tiers[tier]

	-- Update background based on unlock state
	if isUnlocked then
		tierFrame.BackgroundColor3 = Color3.fromRGB(45, 50, 45)
	else
		tierFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
	end

	-- Update free reward section
	local freeSection = tierFrame:FindFirstChild("FreeReward") :: Frame?
	if freeSection and tierData.freeReward then
		if freeClaimed then
			freeSection.BackgroundColor3 = Color3.fromRGB(40, 60, 40)
		elseif isUnlocked then
			freeSection.BackgroundColor3 = Color3.fromRGB(60, 80, 60)
		else
			freeSection.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
		end
	end

	-- Update premium reward section
	local premiumSection = tierFrame:FindFirstChild("PremiumReward") :: Frame?
	if premiumSection then
		local lockIcon = premiumSection:FindFirstChild("Lock") :: TextLabel?
		if lockIcon then
			lockIcon.Visible = not isPremium
		end

		if tierData.premiumReward then
			if premiumClaimed then
				premiumSection.BackgroundColor3 = Color3.fromRGB(60, 50, 30)
			elseif isUnlocked and isPremium then
				premiumSection.BackgroundColor3 = Color3.fromRGB(80, 70, 40)
			else
				premiumSection.BackgroundColor3 = Color3.fromRGB(50, 40, 25)
			end
		end
	end

	-- Update claim button
	local claimButton = tierFrame:FindFirstChild("ClaimButton") :: TextButton?
	if claimButton then
		local hasUnclaimedFree = tierData.freeReward and not freeClaimed
		local hasUnclaimedPremium = tierData.premiumReward and isPremium and not premiumClaimed
		local hasUnclaimed = hasUnclaimedFree or hasUnclaimedPremium

		if not isUnlocked then
			claimButton.Text = "LOCKED"
			claimButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
			claimButton.TextColor3 = Color3.fromRGB(100, 100, 100)
		elseif hasUnclaimed then
			claimButton.Text = "CLAIM"
			claimButton.BackgroundColor3 = Color3.fromRGB(80, 180, 80)
			claimButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		else
			claimButton.Text = "CLAIMED"
			claimButton.BackgroundColor3 = Color3.fromRGB(60, 100, 60)
			claimButton.TextColor3 = Color3.fromRGB(150, 150, 150)
		end
	end
end

--[[
	Handle claim button clicked
]]
function BattlePassUI.OnClaimClicked(tier: number)
	if tier > currentTier then return end

	local tierData = BattlePassData.Tiers[tier]
	local freeClaimKey = `{tier}_free`
	local premiumClaimKey = `{tier}_premium`

	-- Claim free reward if available
	if tierData.freeReward and not claimedRewards[freeClaimKey] then
		Events.FireServer("BattlePass", "ClaimReward", { tier = tier, isPremium = false })
	end

	-- Claim premium reward if available
	if tierData.premiumReward and isPremium and not claimedRewards[premiumClaimKey] then
		Events.FireServer("BattlePass", "ClaimReward", { tier = tier, isPremium = true })
	end
end

--[[
	Scroll to specific tier
]]
function BattlePassUI.ScrollToTier(tier: number)
	if not tierContainer then return end

	local targetPosition = (tier - 1) * TIER_WIDTH - (tierContainer.AbsoluteSize.X / 2) + (TIER_WIDTH / 2)
	targetPosition = math.max(0, targetPosition)

	TweenService:Create(tierContainer, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
		CanvasPosition = Vector2.new(targetPosition, 0)
	}):Play()
end

--[[
	Show the battle pass UI
]]
function BattlePassUI.Show()
	if not screenGui then return end
	if isVisible then return end

	isVisible = true
	screenGui.Enabled = true

	-- Scroll to current tier
	BattlePassUI.ScrollToTier(currentTier)

	-- Request latest data
	Events.FireServer("BattlePass", "RequestData", {})
end

--[[
	Hide the battle pass UI
]]
function BattlePassUI.Hide()
	if not screenGui then return end
	if not isVisible then return end

	isVisible = false
	screenGui.Enabled = false
end

--[[
	Toggle visibility
]]
function BattlePassUI.Toggle()
	if isVisible then
		BattlePassUI.Hide()
	else
		BattlePassUI.Show()
	end
end

--[[
	Check if visible
]]
function BattlePassUI.IsVisible(): boolean
	return isVisible
end

return BattlePassUI
