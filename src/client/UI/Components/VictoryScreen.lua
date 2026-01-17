--!strict
--[[
	VictoryScreen.lua
	=================
	Match results and victory/defeat screen
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Events = require(ReplicatedStorage.Shared.Events)

local VictoryScreen = {}

-- State
local player = Players.LocalPlayer
local screenGui: ScreenGui? = nil
local mainFrame: Frame? = nil
local isVisible = false

--[[
	Initialize the victory screen
]]
function VictoryScreen.Initialize()
	print("[VictoryScreen] Initializing...")

	VictoryScreen.CreateUI()
	VictoryScreen.SetupEventListeners()

	print("[VictoryScreen] Initialized")
end

--[[
	Create UI elements
]]
function VictoryScreen.CreateUI()
	local playerGui = player:WaitForChild("PlayerGui")

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "VictoryScreenGui"
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

	-- Main container
	mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.fromOffset(600, 500)
	mainFrame.Position = UDim2.fromScale(0.5, 0.5)
	mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	mainFrame.BorderSizePixel = 0
	mainFrame.Parent = screenGui

	local mainCorner = Instance.new("UICorner")
	mainCorner.CornerRadius = UDim.new(0, 12)
	mainCorner.Parent = mainFrame

	-- Result title (Victory/Defeat/Eliminated)
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0, 80)
	titleLabel.Position = UDim2.fromOffset(0, 20)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	titleLabel.TextSize = 56
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Text = "VICTORY ROYALE"
	titleLabel.Parent = mainFrame

	-- Placement
	local placementLabel = Instance.new("TextLabel")
	placementLabel.Name = "Placement"
	placementLabel.Size = UDim2.new(1, 0, 0, 40)
	placementLabel.Position = UDim2.fromOffset(0, 100)
	placementLabel.BackgroundTransparency = 1
	placementLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	placementLabel.TextSize = 24
	placementLabel.Font = Enum.Font.GothamBold
	placementLabel.Text = "#1 of 100 Players"
	placementLabel.Parent = mainFrame

	-- Stats container
	local statsFrame = Instance.new("Frame")
	statsFrame.Name = "Stats"
	statsFrame.Size = UDim2.new(0.9, 0, 0, 180)
	statsFrame.Position = UDim2.new(0.5, 0, 0, 160)
	statsFrame.AnchorPoint = Vector2.new(0.5, 0)
	statsFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
	statsFrame.BorderSizePixel = 0
	statsFrame.Parent = mainFrame

	local statsCorner = Instance.new("UICorner")
	statsCorner.CornerRadius = UDim.new(0, 8)
	statsCorner.Parent = statsFrame

	-- Stats grid
	local statsGrid = Instance.new("UIGridLayout")
	statsGrid.CellSize = UDim2.new(0.33, -10, 0.5, -10)
	statsGrid.CellPadding = UDim2.fromOffset(10, 10)
	statsGrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	statsGrid.VerticalAlignment = Enum.VerticalAlignment.Center
	statsGrid.Parent = statsFrame

	-- Create stat entries
	local stats = {
		{ name = "Eliminations", value = "0", icon = "kill" },
		{ name = "Damage Dealt", value = "0", icon = "damage" },
		{ name = "Survival Time", value = "0:00", icon = "time" },
		{ name = "Assists", value = "0", icon = "assist" },
		{ name = "Revives", value = "0", icon = "revive" },
		{ name = "Dinos Killed", value = "0", icon = "dino" },
	}

	for i, stat in ipairs(stats) do
		local statFrame = Instance.new("Frame")
		statFrame.Name = `Stat_{stat.name}`
		statFrame.BackgroundTransparency = 1
		statFrame.LayoutOrder = i
		statFrame.Parent = statsFrame

		local statValue = Instance.new("TextLabel")
		statValue.Name = "Value"
		statValue.Size = UDim2.new(1, 0, 0.6, 0)
		statValue.BackgroundTransparency = 1
		statValue.TextColor3 = Color3.fromRGB(255, 255, 255)
		statValue.TextSize = 28
		statValue.Font = Enum.Font.GothamBold
		statValue.Text = stat.value
		statValue.Parent = statFrame

		local statName = Instance.new("TextLabel")
		statName.Name = "Name"
		statName.Size = UDim2.new(1, 0, 0.4, 0)
		statName.Position = UDim2.fromScale(0, 0.6)
		statName.BackgroundTransparency = 1
		statName.TextColor3 = Color3.fromRGB(150, 150, 150)
		statName.TextSize = 14
		statName.Font = Enum.Font.Gotham
		statName.Text = stat.name
		statName.Parent = statFrame
	end

	-- XP Gained section
	local xpFrame = Instance.new("Frame")
	xpFrame.Name = "XPFrame"
	xpFrame.Size = UDim2.new(0.9, 0, 0, 60)
	xpFrame.Position = UDim2.new(0.5, 0, 0, 355)
	xpFrame.AnchorPoint = Vector2.new(0.5, 0)
	xpFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
	xpFrame.BorderSizePixel = 0
	xpFrame.Parent = mainFrame

	local xpCorner = Instance.new("UICorner")
	xpCorner.CornerRadius = UDim.new(0, 8)
	xpCorner.Parent = xpFrame

	local xpLabel = Instance.new("TextLabel")
	xpLabel.Name = "XPLabel"
	xpLabel.Size = UDim2.fromScale(0.5, 1)
	xpLabel.Position = UDim2.fromOffset(15, 0)
	xpLabel.BackgroundTransparency = 1
	xpLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
	xpLabel.TextSize = 18
	xpLabel.Font = Enum.Font.Gotham
	xpLabel.TextXAlignment = Enum.TextXAlignment.Left
	xpLabel.Text = "XP Earned"
	xpLabel.Parent = xpFrame

	local xpValue = Instance.new("TextLabel")
	xpValue.Name = "XPValue"
	xpValue.Size = UDim2.new(0.5, -15, 1, 0)
	xpValue.Position = UDim2.fromScale(0.5, 0)
	xpValue.BackgroundTransparency = 1
	xpValue.TextColor3 = Color3.fromRGB(100, 200, 255)
	xpValue.TextSize = 24
	xpValue.Font = Enum.Font.GothamBold
	xpValue.TextXAlignment = Enum.TextXAlignment.Right
	xpValue.Text = "+500 XP"
	xpValue.Parent = xpFrame

	-- Return to lobby button
	local lobbyButton = Instance.new("TextButton")
	lobbyButton.Name = "LobbyButton"
	lobbyButton.Size = UDim2.fromOffset(200, 50)
	lobbyButton.Position = UDim2.new(0.5, 0, 1, -70)
	lobbyButton.AnchorPoint = Vector2.new(0.5, 0)
	lobbyButton.BackgroundColor3 = Color3.fromRGB(80, 150, 255)
	lobbyButton.BorderSizePixel = 0
	lobbyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	lobbyButton.TextSize = 18
	lobbyButton.Font = Enum.Font.GothamBold
	lobbyButton.Text = "Return to Lobby"
	lobbyButton.Parent = mainFrame

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 8)
	buttonCorner.Parent = lobbyButton

	lobbyButton.MouseButton1Click:Connect(function()
		VictoryScreen.Hide()
		Events.FireServer("GameState", "ReturnToLobby", {})
	end)

	-- Hover effect
	lobbyButton.MouseEnter:Connect(function()
		TweenService:Create(lobbyButton, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(100, 170, 255) }):Play()
	end)

	lobbyButton.MouseLeave:Connect(function()
		TweenService:Create(lobbyButton, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(80, 150, 255) }):Play()
	end)
end

--[[
	Setup event listeners
]]
function VictoryScreen.SetupEventListeners()
	Events.OnClientEvent("GameState", function(action, data)
		if action == "MatchEnded" then
			VictoryScreen.Show(data)
		end
	end)

	Events.OnClientEvent("Progression", function(action, data)
		if action == "MatchSummary" then
			VictoryScreen.UpdateStats(data)
		end
	end)
end

--[[
	Show the victory screen
]]
function VictoryScreen.Show(data: any)
	if not screenGui or not mainFrame then return end
	if isVisible then return end

	isVisible = true

	-- Update title based on placement
	local titleLabel = mainFrame:FindFirstChild("Title") :: TextLabel?
	local placementLabel = mainFrame:FindFirstChild("Placement") :: TextLabel?

	if titleLabel then
		if data.placement == 1 then
			titleLabel.Text = "VICTORY ROYALE"
			titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0) -- Gold
		elseif data.placement <= 10 then
			titleLabel.Text = "GREAT GAME"
			titleLabel.TextColor3 = Color3.fromRGB(200, 200, 200) -- Silver
		else
			titleLabel.Text = "ELIMINATED"
			titleLabel.TextColor3 = Color3.fromRGB(200, 100, 100) -- Red
		end
	end

	if placementLabel then
		placementLabel.Text = `#{data.placement} of {data.totalPlayers} Players`
	end

	-- Animate in
	screenGui.Enabled = true
	mainFrame.Position = UDim2.fromScale(0.5, 1.5)

	local tween = TweenService:Create(
		mainFrame,
		TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.fromScale(0.5, 0.5) }
	)
	tween:Play()
end

--[[
	Update stats display
]]
function VictoryScreen.UpdateStats(data: any)
	if not mainFrame then return end

	local statsFrame = mainFrame:FindFirstChild("Stats") :: Frame?
	if not statsFrame then return end

	-- Update each stat
	local statMappings = {
		Eliminations = data.stats and data.stats.kills or 0,
		["Damage Dealt"] = data.stats and data.stats.damageDealt or 0,
		["Survival Time"] = VictoryScreen.FormatTime(data.stats and data.stats.survivalTime or 0),
		Assists = data.stats and data.stats.assists or 0,
		Revives = data.stats and data.stats.revives or 0,
		["Dinos Killed"] = data.stats and data.stats.dinoKills or 0,
	}

	for statName, value in pairs(statMappings) do
		local statFrame = statsFrame:FindFirstChild(`Stat_{statName}`)
		if statFrame then
			local valueLabel = statFrame:FindFirstChild("Value") :: TextLabel?
			if valueLabel then
				valueLabel.Text = tostring(value)
			end
		end
	end

	-- Update XP
	local xpFrame = mainFrame:FindFirstChild("XPFrame") :: Frame?
	if xpFrame then
		local xpValue = xpFrame:FindFirstChild("XPValue") :: TextLabel?
		if xpValue and data.xpEarned then
			local totalXP = 0
			for _, xp in pairs(data.xpEarned) do
				totalXP = totalXP + xp
			end
			xpValue.Text = `+{totalXP} XP`
		end
	end
end

--[[
	Format time as M:SS
]]
function VictoryScreen.FormatTime(seconds: number): string
	local minutes = math.floor(seconds / 60)
	local secs = math.floor(seconds % 60)
	return string.format("%d:%02d", minutes, secs)
end

--[[
	Hide the victory screen
]]
function VictoryScreen.Hide()
	if not screenGui or not mainFrame then return end
	if not isVisible then return end

	local tween = TweenService:Create(
		mainFrame,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In),
		{ Position = UDim2.fromScale(0.5, 1.5) }
	)

	tween:Play()
	tween.Completed:Connect(function()
		if screenGui then
			screenGui.Enabled = false
		end
		isVisible = false
	end)
end

--[[
	Check if visible
]]
function VictoryScreen.IsVisible(): boolean
	return isVisible
end

return VictoryScreen
