--!strict
--[[
	RankedUI.lua
	============
	Client-side ranked mode display
	Based on GDD Section 7.2: Ranked Leagues
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Events = require(ReplicatedStorage.Shared.Events)
local RankedData = require(ReplicatedStorage.Shared.RankedData)

local RankedUI = {}

-- State
local player = Players.LocalPlayer
local screenGui: ScreenGui? = nil
local mainFrame: Frame? = nil
local rankBadge: Frame? = nil
local resultPopup: Frame? = nil
local currentRank: RankedData.PlayerRank? = nil
local isVisible = false

--[[
	Initialize the ranked UI
]]
function RankedUI.Initialize()
	print("[RankedUI] Initializing...")

	RankedUI.CreateUI()
	RankedUI.SetupEventListeners()

	-- Request initial data
	Events.FireServer("Ranked", "RequestData", {})

	print("[RankedUI] Initialized")
end

--[[
	Create UI elements
]]
function RankedUI.CreateUI()
	local playerGui = player:WaitForChild("PlayerGui")

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "RankedGui"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	-- Rank badge (always visible in ranked mode)
	rankBadge = Instance.new("Frame")
	rankBadge.Name = "RankBadge"
	rankBadge.Size = UDim2.new(0, 180, 0, 50)
	rankBadge.Position = UDim2.new(0.5, -90, 0, 10)
	rankBadge.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	rankBadge.BackgroundTransparency = 0.2
	rankBadge.BorderSizePixel = 0
	rankBadge.Visible = false
	rankBadge.Parent = screenGui

	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(0, 8)
	badgeCorner.Parent = rankBadge

	local rankIcon = Instance.new("Frame")
	rankIcon.Name = "Icon"
	rankIcon.Size = UDim2.new(0, 40, 0, 40)
	rankIcon.Position = UDim2.new(0, 5, 0.5, -20)
	rankIcon.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
	rankIcon.Parent = rankBadge

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(0.5, 0)
	iconCorner.Parent = rankIcon

	local rankName = Instance.new("TextLabel")
	rankName.Name = "RankName"
	rankName.Size = UDim2.new(0, 100, 0, 20)
	rankName.Position = UDim2.new(0, 50, 0, 5)
	rankName.BackgroundTransparency = 1
	rankName.TextColor3 = Color3.fromRGB(255, 215, 0)
	rankName.TextSize = 14
	rankName.Font = Enum.Font.GothamBold
	rankName.TextXAlignment = Enum.TextXAlignment.Left
	rankName.Text = "Gold II"
	rankName.Parent = rankBadge

	local rpLabel = Instance.new("TextLabel")
	rpLabel.Name = "RP"
	rpLabel.Size = UDim2.new(0, 100, 0, 16)
	rpLabel.Position = UDim2.new(0, 50, 0, 27)
	rpLabel.BackgroundTransparency = 1
	rpLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	rpLabel.TextSize = 12
	rpLabel.Font = Enum.Font.Gotham
	rpLabel.TextXAlignment = Enum.TextXAlignment.Left
	rpLabel.Text = "2,750 RP"
	rpLabel.Parent = rankBadge

	-- Main ranked panel
	mainFrame = Instance.new("Frame")
	mainFrame.Name = "RankedPanel"
	mainFrame.Size = UDim2.new(0, 450, 0, 550)
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
	title.Size = UDim2.new(1, -50, 1, 0)
	title.Position = UDim2.fromOffset(15, 0)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(255, 200, 50)
	title.TextSize = 20
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "RANKED LEAGUES"
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
		RankedUI.Hide()
	end)

	-- Rank display (large)
	local rankDisplay = Instance.new("Frame")
	rankDisplay.Name = "RankDisplay"
	rankDisplay.Size = UDim2.new(1, -40, 0, 180)
	rankDisplay.Position = UDim2.new(0, 20, 0, 70)
	rankDisplay.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	rankDisplay.BorderSizePixel = 0
	rankDisplay.Parent = mainFrame

	local displayCorner = Instance.new("UICorner")
	displayCorner.CornerRadius = UDim.new(0, 8)
	displayCorner.Parent = rankDisplay

	local largeIcon = Instance.new("Frame")
	largeIcon.Name = "LargeIcon"
	largeIcon.Size = UDim2.new(0, 80, 0, 80)
	largeIcon.Position = UDim2.new(0.5, -40, 0, 20)
	largeIcon.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
	largeIcon.Parent = rankDisplay

	local largeIconCorner = Instance.new("UICorner")
	largeIconCorner.CornerRadius = UDim.new(0.5, 0)
	largeIconCorner.Parent = largeIcon

	local largeRankName = Instance.new("TextLabel")
	largeRankName.Name = "RankName"
	largeRankName.Size = UDim2.new(1, 0, 0, 30)
	largeRankName.Position = UDim2.new(0, 0, 0, 105)
	largeRankName.BackgroundTransparency = 1
	largeRankName.TextColor3 = Color3.fromRGB(255, 215, 0)
	largeRankName.TextSize = 22
	largeRankName.Font = Enum.Font.GothamBold
	largeRankName.Text = "Gold II"
	largeRankName.Parent = rankDisplay

	local rpProgress = Instance.new("Frame")
	rpProgress.Name = "RPProgress"
	rpProgress.Size = UDim2.new(0.8, 0, 0, 20)
	rpProgress.Position = UDim2.new(0.1, 0, 0, 145)
	rpProgress.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
	rpProgress.BorderSizePixel = 0
	rpProgress.Parent = rankDisplay

	local progressCorner = Instance.new("UICorner")
	progressCorner.CornerRadius = UDim.new(0, 4)
	progressCorner.Parent = rpProgress

	local progressFill = Instance.new("Frame")
	progressFill.Name = "Fill"
	progressFill.Size = UDim2.new(0.65, 0, 1, 0)
	progressFill.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
	progressFill.BorderSizePixel = 0
	progressFill.Parent = rpProgress

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = progressFill

	-- Stats section
	local statsFrame = Instance.new("Frame")
	statsFrame.Name = "Stats"
	statsFrame.Size = UDim2.new(1, -40, 0, 120)
	statsFrame.Position = UDim2.new(0, 20, 0, 265)
	statsFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	statsFrame.BorderSizePixel = 0
	statsFrame.Parent = mainFrame

	local statsCorner = Instance.new("UICorner")
	statsCorner.CornerRadius = UDim.new(0, 8)
	statsCorner.Parent = statsFrame

	local statsTitle = Instance.new("TextLabel")
	statsTitle.Name = "Title"
	statsTitle.Size = UDim2.new(1, 0, 0, 30)
	statsTitle.BackgroundTransparency = 1
	statsTitle.TextColor3 = Color3.fromRGB(200, 200, 200)
	statsTitle.TextSize = 14
	statsTitle.Font = Enum.Font.GothamBold
	statsTitle.Text = "SEASON STATS"
	statsTitle.Parent = statsFrame

	-- Stats grid
	local statsGrid = Instance.new("Frame")
	statsGrid.Name = "Grid"
	statsGrid.Size = UDim2.new(1, -20, 0, 80)
	statsGrid.Position = UDim2.new(0, 10, 0, 35)
	statsGrid.BackgroundTransparency = 1
	statsGrid.Parent = statsFrame

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0.25, -5, 0.5, -5)
	gridLayout.CellPadding = UDim2.new(0, 5, 0, 5)
	gridLayout.Parent = statsGrid

	-- Create stat displays
	local statNames = { "Matches", "Wins", "Top 10s", "Avg Place", "Win Rate", "Peak Rank", "Total RP", "Kill/Match" }
	for i, statName in ipairs(statNames) do
		local statFrame = Instance.new("Frame")
		statFrame.Name = statName
		statFrame.BackgroundTransparency = 1
		statFrame.LayoutOrder = i
		statFrame.Parent = statsGrid

		local value = Instance.new("TextLabel")
		value.Name = "Value"
		value.Size = UDim2.new(1, 0, 0.6, 0)
		value.BackgroundTransparency = 1
		value.TextColor3 = Color3.fromRGB(255, 255, 255)
		value.TextSize = 16
		value.Font = Enum.Font.GothamBold
		value.Text = "0"
		value.Parent = statFrame

		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.new(1, 0, 0.4, 0)
		label.Position = UDim2.new(0, 0, 0.6, 0)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.fromRGB(120, 120, 120)
		label.TextSize = 10
		label.Font = Enum.Font.Gotham
		label.Text = statName
		label.Parent = statFrame
	end

	-- Season info
	local seasonFrame = Instance.new("Frame")
	seasonFrame.Name = "Season"
	seasonFrame.Size = UDim2.new(1, -40, 0, 60)
	seasonFrame.Position = UDim2.new(0, 20, 0, 400)
	seasonFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	seasonFrame.BorderSizePixel = 0
	seasonFrame.Parent = mainFrame

	local seasonCorner = Instance.new("UICorner")
	seasonCorner.CornerRadius = UDim.new(0, 8)
	seasonCorner.Parent = seasonFrame

	local seasonName = Instance.new("TextLabel")
	seasonName.Name = "SeasonName"
	seasonName.Size = UDim2.new(1, 0, 0, 25)
	seasonName.Position = UDim2.fromOffset(0, 8)
	seasonName.BackgroundTransparency = 1
	seasonName.TextColor3 = Color3.fromRGB(255, 200, 50)
	seasonName.TextSize = 14
	seasonName.Font = Enum.Font.GothamBold
	seasonName.Text = "Season 1: Primordial Dawn"
	seasonName.Parent = seasonFrame

	local timeRemaining = Instance.new("TextLabel")
	timeRemaining.Name = "TimeRemaining"
	timeRemaining.Size = UDim2.new(1, 0, 0, 20)
	timeRemaining.Position = UDim2.new(0, 0, 0, 32)
	timeRemaining.BackgroundTransparency = 1
	timeRemaining.TextColor3 = Color3.fromRGB(150, 150, 150)
	timeRemaining.TextSize = 12
	timeRemaining.Font = Enum.Font.Gotham
	timeRemaining.Text = "45 days remaining"
	timeRemaining.Parent = seasonFrame

	-- Leaderboard button
	local leaderboardBtn = Instance.new("TextButton")
	leaderboardBtn.Name = "LeaderboardButton"
	leaderboardBtn.Size = UDim2.new(1, -40, 0, 45)
	leaderboardBtn.Position = UDim2.new(0, 20, 0, 475)
	leaderboardBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 180)
	leaderboardBtn.BorderSizePixel = 0
	leaderboardBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	leaderboardBtn.TextSize = 16
	leaderboardBtn.Font = Enum.Font.GothamBold
	leaderboardBtn.Text = "View Leaderboard"
	leaderboardBtn.Parent = mainFrame

	local lbCorner = Instance.new("UICorner")
	lbCorner.CornerRadius = UDim.new(0, 8)
	lbCorner.Parent = leaderboardBtn

	leaderboardBtn.MouseButton1Click:Connect(function()
		Events.FireServer("Ranked", "RequestLeaderboard", {})
	end)

	-- Match result popup
	resultPopup = Instance.new("Frame")
	resultPopup.Name = "MatchResult"
	resultPopup.Size = UDim2.new(0, 350, 0, 200)
	resultPopup.Position = UDim2.fromScale(0.5, 0.5)
	resultPopup.AnchorPoint = Vector2.new(0.5, 0.5)
	resultPopup.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	resultPopup.BorderSizePixel = 0
	resultPopup.Visible = false
	resultPopup.Parent = screenGui

	local resultCorner = Instance.new("UICorner")
	resultCorner.CornerRadius = UDim.new(0, 12)
	resultCorner.Parent = resultPopup

	local resultTitle = Instance.new("TextLabel")
	resultTitle.Name = "Title"
	resultTitle.Size = UDim2.new(1, 0, 0, 40)
	resultTitle.Position = UDim2.fromOffset(0, 10)
	resultTitle.BackgroundTransparency = 1
	resultTitle.TextColor3 = Color3.fromRGB(255, 200, 50)
	resultTitle.TextSize = 20
	resultTitle.Font = Enum.Font.GothamBold
	resultTitle.Text = "MATCH COMPLETE"
	resultTitle.Parent = resultPopup

	local placementLabel = Instance.new("TextLabel")
	placementLabel.Name = "Placement"
	placementLabel.Size = UDim2.new(1, 0, 0, 30)
	placementLabel.Position = UDim2.fromOffset(0, 50)
	placementLabel.BackgroundTransparency = 1
	placementLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	placementLabel.TextSize = 16
	placementLabel.Font = Enum.Font.GothamMedium
	placementLabel.Text = "#5 - 3 Eliminations"
	placementLabel.Parent = resultPopup

	local rpChangeLabel = Instance.new("TextLabel")
	rpChangeLabel.Name = "RPChange"
	rpChangeLabel.Size = UDim2.new(1, 0, 0, 40)
	rpChangeLabel.Position = UDim2.fromOffset(0, 90)
	rpChangeLabel.BackgroundTransparency = 1
	rpChangeLabel.TextColor3 = Color3.fromRGB(80, 200, 80)
	rpChangeLabel.TextSize = 28
	rpChangeLabel.Font = Enum.Font.GothamBold
	rpChangeLabel.Text = "+75 RP"
	rpChangeLabel.Parent = resultPopup

	local newRankLabel = Instance.new("TextLabel")
	newRankLabel.Name = "NewRank"
	newRankLabel.Size = UDim2.new(1, 0, 0, 25)
	newRankLabel.Position = UDim2.fromOffset(0, 135)
	newRankLabel.BackgroundTransparency = 1
	newRankLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	newRankLabel.TextSize = 16
	newRankLabel.Font = Enum.Font.GothamBold
	newRankLabel.Text = "Gold II (2,825 RP)"
	newRankLabel.Parent = resultPopup

	local dismissButton = Instance.new("TextButton")
	dismissButton.Name = "Dismiss"
	dismissButton.Size = UDim2.new(0, 120, 0, 35)
	dismissButton.Position = UDim2.new(0.5, -60, 1, -50)
	dismissButton.BackgroundColor3 = Color3.fromRGB(80, 80, 85)
	dismissButton.BorderSizePixel = 0
	dismissButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	dismissButton.TextSize = 14
	dismissButton.Font = Enum.Font.GothamBold
	dismissButton.Text = "Continue"
	dismissButton.Parent = resultPopup

	local dismissCorner = Instance.new("UICorner")
	dismissCorner.CornerRadius = UDim.new(0, 6)
	dismissCorner.Parent = dismissButton

	dismissButton.MouseButton1Click:Connect(function()
		RankedUI.HideMatchResult()
	end)
end

--[[
	Setup event listeners
]]
function RankedUI.SetupEventListeners()
	Events.OnClientEvent("Ranked", function(action, data)
		if action == "DataUpdate" then
			RankedUI.OnDataUpdate(data)
		elseif action == "MatchResult" then
			RankedUI.OnMatchResult(data)
		elseif action == "LeaderboardUpdate" then
			RankedUI.OnLeaderboardUpdate(data)
		elseif action == "SeasonRewards" then
			RankedUI.OnSeasonRewards(data)
		end
	end)
end

--[[
	On data update
]]
function RankedUI.OnDataUpdate(data: any)
	currentRank = data.rank

	-- Update badge
	RankedUI.UpdateBadge(data)

	-- Update main panel
	RankedUI.UpdateMainPanel(data)
end

--[[
	Update rank badge
]]
function RankedUI.UpdateBadge(data: any)
	if not rankBadge then return end

	local icon = rankBadge:FindFirstChild("Icon") :: Frame?
	local nameLabel = rankBadge:FindFirstChild("RankName") :: TextLabel?
	local rpLabel = rankBadge:FindFirstChild("RP") :: TextLabel?

	if icon then
		icon.BackgroundColor3 = data.tierColor
	end

	if nameLabel then
		nameLabel.Text = data.displayName
		nameLabel.TextColor3 = data.tierColor
	end

	if rpLabel then
		if data.isInPlacements then
			rpLabel.Text = `{data.placementMatchesLeft} placement matches left`
		else
			rpLabel.Text = `{data.rank.rp:format("%,d")} RP`
		end
	end
end

--[[
	Update main panel
]]
function RankedUI.UpdateMainPanel(data: any)
	if not mainFrame then return end

	local rankDisplay = mainFrame:FindFirstChild("RankDisplay") :: Frame?
	if rankDisplay then
		local icon = rankDisplay:FindFirstChild("LargeIcon") :: Frame?
		local nameLabel = rankDisplay:FindFirstChild("RankName") :: TextLabel?
		local progress = rankDisplay:FindFirstChild("RPProgress") :: Frame?

		if icon then
			icon.BackgroundColor3 = data.tierColor
		end

		if nameLabel then
			nameLabel.Text = data.displayName
			nameLabel.TextColor3 = data.tierColor
		end

		if progress then
			local fill = progress:FindFirstChild("Fill") :: Frame?
			if fill then
				-- Calculate progress within current division/tier
				local tier = RankedData.GetTierForRP(data.rank.rp)
				local rpInTier = data.rank.rp - tier.minRP
				local tierRange = tier.maxRP - tier.minRP + 1
				local progressPct = math.clamp(rpInTier / tierRange, 0, 1)

				TweenService:Create(fill, TweenInfo.new(0.3), {
					Size = UDim2.new(progressPct, 0, 1, 0),
				}):Play()

				fill.BackgroundColor3 = data.tierColor
			end
		end
	end

	-- Update stats
	local statsFrame = mainFrame:FindFirstChild("Stats") :: Frame?
	if statsFrame then
		local grid = statsFrame:FindFirstChild("Grid") :: Frame?
		if grid then
			local rank = data.rank

			local statValues = {
				Matches = tostring(rank.matchesPlayed),
				Wins = tostring(rank.wins),
				["Top 10s"] = tostring(rank.top10s),
				["Avg Place"] = string.format("%.1f", rank.avgPlacement),
				["Win Rate"] = rank.matchesPlayed > 0 and string.format("%.1f%%", (rank.wins / rank.matchesPlayed) * 100) or "0%",
				["Peak Rank"] = RankedData.GetRankDisplayName(rank.peakRP),
				["Total RP"] = tostring(rank.rp),
				["Kill/Match"] = "0", -- Would need kill tracking
			}

			for statName, value in pairs(statValues) do
				local statFrame = grid:FindFirstChild(statName)
				if statFrame then
					local valueLabel = statFrame:FindFirstChild("Value") :: TextLabel?
					if valueLabel then
						valueLabel.Text = value
					end
				end
			end
		end
	end

	-- Update season info
	if data.season then
		local seasonFrame = mainFrame:FindFirstChild("Season") :: Frame?
		if seasonFrame then
			local seasonName = seasonFrame:FindFirstChild("SeasonName") :: TextLabel?
			local timeRemaining = seasonFrame:FindFirstChild("TimeRemaining") :: TextLabel?

			if seasonName then
				seasonName.Text = data.season.name
			end

			if timeRemaining then
				local remaining = data.season.endTime - os.time()
				local days = math.floor(remaining / 86400)
				timeRemaining.Text = `{days} days remaining`
			end
		end
	end
end

--[[
	On match result
]]
function RankedUI.OnMatchResult(data: any)
	if not resultPopup then return end

	local placementLabel = resultPopup:FindFirstChild("Placement") :: TextLabel?
	local rpChangeLabel = resultPopup:FindFirstChild("RPChange") :: TextLabel?
	local newRankLabel = resultPopup:FindFirstChild("NewRank") :: TextLabel?

	if placementLabel then
		placementLabel.Text = `#{data.placement} - {data.kills} Elimination{data.kills == 1 and "" or "s"}`
	end

	if rpChangeLabel then
		if data.rpChange >= 0 then
			rpChangeLabel.Text = `+{data.rpChange} RP`
			rpChangeLabel.TextColor3 = Color3.fromRGB(80, 200, 80)
		else
			rpChangeLabel.Text = `{data.rpChange} RP`
			rpChangeLabel.TextColor3 = Color3.fromRGB(200, 80, 80)
		end
	end

	if newRankLabel then
		local displayName = RankedData.GetRankDisplayName(data.newRP)
		newRankLabel.Text = `{displayName} ({data.newRP:format("%,d")} RP)`

		local tier = RankedData.GetTierForRP(data.newRP)
		newRankLabel.TextColor3 = tier.color
	end

	-- Show popup
	resultPopup.Visible = true
	resultPopup.Size = UDim2.new(0, 0, 0, 0)
	resultPopup.BackgroundTransparency = 1

	TweenService:Create(resultPopup, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 350, 0, 200),
		BackgroundTransparency = 0,
	}):Play()
end

--[[
	Hide match result
]]
function RankedUI.HideMatchResult()
	if not resultPopup then return end

	local tween = TweenService:Create(resultPopup, TweenInfo.new(0.2), {
		Size = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 1,
	})

	tween:Play()
	tween.Completed:Connect(function()
		resultPopup.Visible = false
	end)
end

--[[
	On leaderboard update
]]
function RankedUI.OnLeaderboardUpdate(data: any)
	-- TODO: Show leaderboard popup
	print(`[RankedUI] Your rank: #{data.playerRank} of {data.totalPlayers}`)
end

--[[
	On season rewards
]]
function RankedUI.OnSeasonRewards(data: any)
	-- TODO: Show rewards popup
	print(`[RankedUI] Season rewards for {data.tier}: {#data.rewards} items`)
end

--[[
	Show ranked badge
]]
function RankedUI.ShowBadge()
	if not rankBadge then return end
	rankBadge.Visible = true
end

--[[
	Hide ranked badge
]]
function RankedUI.HideBadge()
	if not rankBadge then return end
	rankBadge.Visible = false
end

--[[
	Show main panel
]]
function RankedUI.Show()
	if not mainFrame then return end
	isVisible = true
	mainFrame.Visible = true
end

--[[
	Hide main panel
]]
function RankedUI.Hide()
	if not mainFrame then return end
	isVisible = false
	mainFrame.Visible = false
end

--[[
	Toggle main panel
]]
function RankedUI.Toggle()
	if isVisible then
		RankedUI.Hide()
	else
		RankedUI.Show()
	end
end

--[[
	Get current rank
]]
function RankedUI.GetCurrentRank(): RankedData.PlayerRank?
	return currentRank
end

return RankedUI
