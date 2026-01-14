--!strict
--[[
	RevivalUI.lua
	=============
	Client UI for revival and reboot systems
	Shows downed state, revive progress, reboot card indicators
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Events = require(ReplicatedStorage.Shared.Events)
local TeamData = require(ReplicatedStorage.Shared.TeamData)

local RevivalUI = {}

-- State
local player = Players.LocalPlayer
local screenGui: ScreenGui? = nil
local downedOverlay: Frame? = nil
local reviveProgressBar: Frame? = nil
local rebootCardIndicator: Frame? = nil
local teammateMarkers: { [number]: Frame } = {}

local isInitialized = false
local isDowned = false
local bleedOutTime = 0
local currentReviveProgress = 0

-- Constants
local DOWNED_COLOR = Color3.fromRGB(150, 0, 0)
local REVIVE_COLOR = Color3.fromRGB(0, 200, 100)
local CARD_COLOR = Color3.fromRGB(255, 200, 0)

--[[
	Initialize the revival UI
]]
function RevivalUI.Initialize()
	if isInitialized then return end
	isInitialized = true

	print("[RevivalUI] Initializing...")

	RevivalUI.CreateUI()
	RevivalUI.SetupEventListeners()

	RunService.RenderStepped:Connect(function()
		RevivalUI.Update()
	end)

	print("[RevivalUI] Initialized")
end

--[[
	Create all UI elements
]]
function RevivalUI.CreateUI()
	local playerGui = player:WaitForChild("PlayerGui")

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "RevivalUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	-- Downed state overlay
	RevivalUI.CreateDownedOverlay()

	-- Revive progress indicator
	RevivalUI.CreateReviveProgressUI()

	-- Reboot card indicator
	RevivalUI.CreateRebootCardUI()

	-- Teammate downed indicators
	RevivalUI.CreateTeammateIndicators()
end

--[[
	Create downed state overlay
]]
function RevivalUI.CreateDownedOverlay()
	if not screenGui then return end

	downedOverlay = Instance.new("Frame")
	downedOverlay.Name = "DownedOverlay"
	downedOverlay.Size = UDim2.fromScale(1, 1)
	downedOverlay.Position = UDim2.fromScale(0.5, 0.5)
	downedOverlay.AnchorPoint = Vector2.new(0.5, 0.5)
	downedOverlay.BackgroundColor3 = DOWNED_COLOR
	downedOverlay.BackgroundTransparency = 1
	downedOverlay.BorderSizePixel = 0
	downedOverlay.Visible = false
	downedOverlay.Parent = screenGui

	-- Vignette effect
	local vignette = Instance.new("ImageLabel")
	vignette.Name = "Vignette"
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.BackgroundTransparency = 1
	vignette.Image = "rbxassetid://0" -- Would use actual vignette asset
	vignette.ImageColor3 = Color3.fromRGB(0, 0, 0)
	vignette.Parent = downedOverlay

	-- "DOWNED" text
	local downedText = Instance.new("TextLabel")
	downedText.Name = "DownedText"
	downedText.Size = UDim2.new(0.5, 0, 0, 60)
	downedText.Position = UDim2.fromScale(0.5, 0.3)
	downedText.AnchorPoint = Vector2.new(0.5, 0.5)
	downedText.BackgroundTransparency = 1
	downedText.Text = "DOWNED"
	downedText.TextColor3 = Color3.fromRGB(255, 50, 50)
	downedText.TextSize = 48
	downedText.Font = Enum.Font.GothamBlack
	downedText.Parent = downedOverlay

	-- Bleed out timer
	local bleedOutFrame = Instance.new("Frame")
	bleedOutFrame.Name = "BleedOutFrame"
	bleedOutFrame.Size = UDim2.new(0.3, 0, 0, 30)
	bleedOutFrame.Position = UDim2.fromScale(0.5, 0.4)
	bleedOutFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	bleedOutFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	bleedOutFrame.BorderSizePixel = 0
	bleedOutFrame.Parent = downedOverlay

	local bleedOutCorner = Instance.new("UICorner")
	bleedOutCorner.CornerRadius = UDim.new(0, 8)
	bleedOutCorner.Parent = bleedOutFrame

	local bleedOutBar = Instance.new("Frame")
	bleedOutBar.Name = "Bar"
	bleedOutBar.Size = UDim2.fromScale(1, 1)
	bleedOutBar.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	bleedOutBar.BorderSizePixel = 0
	bleedOutBar.Parent = bleedOutFrame

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 8)
	barCorner.Parent = bleedOutBar

	local bleedOutText = Instance.new("TextLabel")
	bleedOutText.Name = "Timer"
	bleedOutText.Size = UDim2.fromScale(1, 1)
	bleedOutText.BackgroundTransparency = 1
	bleedOutText.Text = "30s"
	bleedOutText.TextColor3 = Color3.fromRGB(255, 255, 255)
	bleedOutText.TextSize = 18
	bleedOutText.Font = Enum.Font.GothamBold
	bleedOutText.ZIndex = 2
	bleedOutText.Parent = bleedOutFrame

	-- Help text
	local helpText = Instance.new("TextLabel")
	helpText.Name = "HelpText"
	helpText.Size = UDim2.new(0.5, 0, 0, 30)
	helpText.Position = UDim2.fromScale(0.5, 0.5)
	helpText.AnchorPoint = Vector2.new(0.5, 0.5)
	helpText.BackgroundTransparency = 1
	helpText.Text = "Wait for a teammate to revive you!"
	helpText.TextColor3 = Color3.fromRGB(200, 200, 200)
	helpText.TextSize = 16
	helpText.Font = Enum.Font.Gotham
	helpText.Parent = downedOverlay

	-- Being revived indicator
	local revivingFrame = Instance.new("Frame")
	revivingFrame.Name = "RevivingFrame"
	revivingFrame.Size = UDim2.new(0.3, 0, 0, 40)
	revivingFrame.Position = UDim2.fromScale(0.5, 0.6)
	revivingFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	revivingFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	revivingFrame.BackgroundTransparency = 0.3
	revivingFrame.BorderSizePixel = 0
	revivingFrame.Visible = false
	revivingFrame.Parent = downedOverlay

	local revivingCorner = Instance.new("UICorner")
	revivingCorner.CornerRadius = UDim.new(0, 8)
	revivingCorner.Parent = revivingFrame

	local revivingBar = Instance.new("Frame")
	revivingBar.Name = "Bar"
	revivingBar.Size = UDim2.fromScale(0, 1)
	revivingBar.BackgroundColor3 = REVIVE_COLOR
	revivingBar.BorderSizePixel = 0
	revivingBar.Parent = revivingFrame

	local revivingBarCorner = Instance.new("UICorner")
	revivingBarCorner.CornerRadius = UDim.new(0, 8)
	revivingBarCorner.Parent = revivingBar

	local revivingText = Instance.new("TextLabel")
	revivingText.Name = "Text"
	revivingText.Size = UDim2.fromScale(1, 1)
	revivingText.BackgroundTransparency = 1
	revivingText.Text = "Being revived..."
	revivingText.TextColor3 = Color3.fromRGB(255, 255, 255)
	revivingText.TextSize = 16
	revivingText.Font = Enum.Font.GothamBold
	revivingText.ZIndex = 2
	revivingText.Parent = revivingFrame
end

--[[
	Create revive progress UI (when reviving someone else)
]]
function RevivalUI.CreateReviveProgressUI()
	if not screenGui then return end

	reviveProgressBar = Instance.new("Frame")
	reviveProgressBar.Name = "ReviveProgressBar"
	reviveProgressBar.Size = UDim2.new(0.25, 0, 0, 35)
	reviveProgressBar.Position = UDim2.fromScale(0.5, 0.7)
	reviveProgressBar.AnchorPoint = Vector2.new(0.5, 0.5)
	reviveProgressBar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	reviveProgressBar.BackgroundTransparency = 0.3
	reviveProgressBar.BorderSizePixel = 0
	reviveProgressBar.Visible = false
	reviveProgressBar.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = reviveProgressBar

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Size = UDim2.fromScale(0, 1)
	bar.BackgroundColor3 = REVIVE_COLOR
	bar.BorderSizePixel = 0
	bar.Parent = reviveProgressBar

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 8)
	barCorner.Parent = bar

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "Reviving..."
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = 16
	label.Font = Enum.Font.GothamBold
	label.ZIndex = 2
	label.Parent = reviveProgressBar
end

--[[
	Create reboot card UI
]]
function RevivalUI.CreateRebootCardUI()
	if not screenGui then return end

	rebootCardIndicator = Instance.new("Frame")
	rebootCardIndicator.Name = "RebootCardIndicator"
	rebootCardIndicator.Size = UDim2.new(0, 200, 0, 50)
	rebootCardIndicator.Position = UDim2.new(0, 20, 0.5, 0)
	rebootCardIndicator.AnchorPoint = Vector2.new(0, 0.5)
	rebootCardIndicator.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	rebootCardIndicator.BackgroundTransparency = 0.3
	rebootCardIndicator.BorderSizePixel = 0
	rebootCardIndicator.Visible = false
	rebootCardIndicator.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = rebootCardIndicator

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(0, 40, 0, 40)
	icon.Position = UDim2.new(0, 5, 0.5, 0)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.BackgroundTransparency = 1
	icon.Image = "rbxassetid://0" -- Card icon
	icon.ImageColor3 = CARD_COLOR
	icon.Parent = rebootCardIndicator

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(1, -55, 0.5, 0)
	nameLabel.Position = UDim2.new(0, 50, 0, 5)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = "Player's Card"
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextSize = 14
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = rebootCardIndicator

	local timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "Timer"
	timerLabel.Size = UDim2.new(1, -55, 0.5, 0)
	timerLabel.Position = UDim2.new(0, 50, 0.5, 0)
	timerLabel.BackgroundTransparency = 1
	timerLabel.Text = "Expires in 90s"
	timerLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	timerLabel.TextSize = 12
	timerLabel.Font = Enum.Font.Gotham
	timerLabel.TextXAlignment = Enum.TextXAlignment.Left
	timerLabel.Parent = rebootCardIndicator
end

--[[
	Create teammate downed indicators
]]
function RevivalUI.CreateTeammateIndicators()
	-- These will be created dynamically when teammates go down
end

--[[
	Setup event listeners
]]
function RevivalUI.SetupEventListeners()
	Events.OnClientEvent("Revival", function(action, data)
		if action == "PlayerDowned" then
			if data.playerId == player.UserId then
				RevivalUI.ShowDowned(data.bleedOutTime)
			else
				RevivalUI.ShowTeammateDowned(data.playerId, data.playerName, data.position)
			end

		elseif action == "PlayerRevived" then
			if data.targetId == player.UserId then
				RevivalUI.HideDowned()
			else
				RevivalUI.HideTeammateDowned(data.targetId)
			end

		elseif action == "PlayerBledOut" then
			if data.playerId == player.UserId then
				RevivalUI.HideDowned()
			else
				RevivalUI.HideTeammateDowned(data.playerId)
			end

		elseif action == "ReviveStarted" then
			if data.targetId == player.UserId then
				RevivalUI.ShowBeingRevived()
			elseif data.reviverId == player.UserId then
				RevivalUI.ShowReviving(data.reviveTime)
			end

		elseif action == "ReviveCancelled" then
			if data.targetId == player.UserId then
				RevivalUI.HideBeingRevived()
			elseif data.reviverId == player.UserId then
				RevivalUI.HideReviving()
			end

		elseif action == "ReviveProgress" then
			currentReviveProgress = data.progress

		elseif action == "BeingRevived" then
			RevivalUI.UpdateBeingRevived(data.progress)
		end
	end)

	Events.OnClientEvent("Reboot", function(action, data)
		if action == "CardCollected" then
			if data.collectorId == player.UserId then
				RevivalUI.ShowRebootCard(data.cardPlayerName)
			end

		elseif action == "RebootCompleted" then
			if data.rebootedId == player.UserId then
				RevivalUI.ShowRebooted()
			end
			RevivalUI.HideRebootCard(data.rebootedId)
		end
	end)
end

--[[
	Show downed overlay
]]
function RevivalUI.ShowDowned(bleedTime: number)
	isDowned = true
	bleedOutTime = bleedTime

	if downedOverlay then
		downedOverlay.Visible = true
		downedOverlay.BackgroundTransparency = 0.7

		-- Animate in
		local tween = TweenService:Create(
			downedOverlay,
			TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 0.5 }
		)
		tween:Play()
	end
end

--[[
	Hide downed overlay
]]
function RevivalUI.HideDowned()
	isDowned = false

	if downedOverlay then
		local tween = TweenService:Create(
			downedOverlay,
			TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 1 }
		)
		tween:Play()
		tween.Completed:Connect(function()
			if downedOverlay then
				downedOverlay.Visible = false
			end
		end)
	end
end

--[[
	Show teammate downed indicator
]]
function RevivalUI.ShowTeammateDowned(playerId: number, playerName: string, position: Vector3)
	-- Would create a world-space UI or screen indicator pointing to downed teammate
	print(`[RevivalUI] Teammate {playerName} is down!`)
end

--[[
	Hide teammate downed indicator
]]
function RevivalUI.HideTeammateDowned(playerId: number)
	local marker = teammateMarkers[playerId]
	if marker then
		marker:Destroy()
		teammateMarkers[playerId] = nil
	end
end

--[[
	Show being revived UI
]]
function RevivalUI.ShowBeingRevived()
	if downedOverlay then
		local revivingFrame = downedOverlay:FindFirstChild("RevivingFrame")
		if revivingFrame then
			revivingFrame.Visible = true
		end
	end
end

--[[
	Hide being revived UI
]]
function RevivalUI.HideBeingRevived()
	if downedOverlay then
		local revivingFrame = downedOverlay:FindFirstChild("RevivingFrame")
		if revivingFrame then
			revivingFrame.Visible = false
			local bar = revivingFrame:FindFirstChild("Bar") :: Frame?
			if bar then
				bar.Size = UDim2.fromScale(0, 1)
			end
		end
	end
end

--[[
	Update being revived progress
]]
function RevivalUI.UpdateBeingRevived(progress: number)
	if downedOverlay then
		local revivingFrame = downedOverlay:FindFirstChild("RevivingFrame")
		if revivingFrame then
			local bar = revivingFrame:FindFirstChild("Bar") :: Frame?
			if bar then
				bar.Size = UDim2.fromScale(progress, 1)
			end
		end
	end
end

--[[
	Show reviving progress (when you're reviving someone)
]]
function RevivalUI.ShowReviving(reviveTime: number)
	if reviveProgressBar then
		reviveProgressBar.Visible = true
		currentReviveProgress = 0
	end
end

--[[
	Hide reviving progress
]]
function RevivalUI.HideReviving()
	if reviveProgressBar then
		reviveProgressBar.Visible = false
		local bar = reviveProgressBar:FindFirstChild("Bar") :: Frame?
		if bar then
			bar.Size = UDim2.fromScale(0, 1)
		end
	end
end

--[[
	Show reboot card indicator
]]
function RevivalUI.ShowRebootCard(playerName: string)
	if rebootCardIndicator then
		rebootCardIndicator.Visible = true
		local nameLabel = rebootCardIndicator:FindFirstChild("Name") :: TextLabel?
		if nameLabel then
			nameLabel.Text = `{playerName}'s Card`
		end
	end
end

--[[
	Hide reboot card indicator
]]
function RevivalUI.HideRebootCard(playerId: number)
	-- Would check if this is the card we're holding
	if rebootCardIndicator then
		rebootCardIndicator.Visible = false
	end
end

--[[
	Show rebooted notification
]]
function RevivalUI.ShowRebooted()
	-- Flash effect and "REBOOTED" text
	print("[RevivalUI] You have been rebooted!")
end

--[[
	Update loop
]]
function RevivalUI.Update()
	-- Update revive progress bar
	if reviveProgressBar and reviveProgressBar.Visible then
		local bar = reviveProgressBar:FindFirstChild("Bar") :: Frame?
		if bar then
			bar.Size = UDim2.fromScale(currentReviveProgress, 1)
		end
	end

	-- Update bleed out timer (would need actual timer data)
end

--[[
	Cleanup
]]
function RevivalUI.Cleanup()
	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
	teammateMarkers = {}
end

return RevivalUI
