--!strict
--[[
	LobbyScreen.lua
	===============
	Pre-match lobby UI with player list and ready system
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Events = require(ReplicatedStorage.Shared.Events)

-- Toast notification (loaded lazily)
local ToastNotification: any = nil

-- Animation settings
local FADE_DURATION = 0.25

local LobbyScreen = {}

-- State
local player = Players.LocalPlayer
local screenGui: ScreenGui? = nil
local mainFrame: Frame? = nil
local playerListFrame: Frame? = nil
local isVisible = false
local isReady = false
local countdownActive = false
local countdownTime = 0

-- Constants
local MAX_PLAYERS = 100
local MIN_PLAYERS_TO_START = 2

--[[
	Initialize the lobby screen
]]
function LobbyScreen.Initialize()
	print("[LobbyScreen] Initializing...")

	LobbyScreen.CreateUI()
	LobbyScreen.SetupEventListeners()

	-- Auto-show lobby on initialization
	task.defer(function()
		task.wait(0.5) -- Brief delay for character to load
		LobbyScreen.Show()
	end)

	print("[LobbyScreen] Initialized")
end

--[[
	Create UI elements
]]
function LobbyScreen.CreateUI()
	local playerGui = player:WaitForChild("PlayerGui")

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "LobbyScreenGui"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Enabled = false
	screenGui.Parent = playerGui

	-- Main container
	mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.fromScale(1, 1)
	mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	mainFrame.BorderSizePixel = 0
	mainFrame.Parent = screenGui

	-- Game title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0, 100)
	titleLabel.Position = UDim2.fromOffset(0, 50)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(255, 100, 50)
	titleLabel.TextSize = 72
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.Text = "DINO ROYALE"
	titleLabel.Parent = mainFrame

	-- Subtitle
	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Name = "Subtitle"
	subtitleLabel.Size = UDim2.new(1, 0, 0, 30)
	subtitleLabel.Position = UDim2.fromOffset(0, 150)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
	subtitleLabel.TextSize = 20
	subtitleLabel.Font = Enum.Font.Gotham
	subtitleLabel.Text = "Battle Royale with Dinosaurs"
	subtitleLabel.Parent = mainFrame

	-- Player count display
	local playerCountFrame = Instance.new("Frame")
	playerCountFrame.Name = "PlayerCount"
	playerCountFrame.Size = UDim2.new(0, 300, 0, 80)
	playerCountFrame.Position = UDim2.new(0.5, 0, 0, 220)
	playerCountFrame.AnchorPoint = Vector2.new(0.5, 0)
	playerCountFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	playerCountFrame.BorderSizePixel = 0
	playerCountFrame.Parent = mainFrame

	local countCorner = Instance.new("UICorner")
	countCorner.CornerRadius = UDim.new(0, 8)
	countCorner.Parent = playerCountFrame

	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "Count"
	countLabel.Size = UDim2.fromScale(1, 0.6)
	countLabel.BackgroundTransparency = 1
	countLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	countLabel.TextSize = 32
	countLabel.Font = Enum.Font.GothamBold
	countLabel.Text = "0 / 100"
	countLabel.Parent = playerCountFrame

	local countSubLabel = Instance.new("TextLabel")
	countSubLabel.Name = "SubLabel"
	countSubLabel.Size = UDim2.fromScale(1, 0.4)
	countSubLabel.Position = UDim2.fromScale(0, 0.6)
	countSubLabel.BackgroundTransparency = 1
	countSubLabel.TextColor3 = Color3.fromRGB(120, 120, 120)
	countSubLabel.TextSize = 14
	countSubLabel.Font = Enum.Font.Gotham
	countSubLabel.Text = "Players in Lobby"
	countSubLabel.Parent = playerCountFrame

	-- Player list container
	playerListFrame = Instance.new("ScrollingFrame")
	playerListFrame.Name = "PlayerList"
	playerListFrame.Size = UDim2.new(0, 400, 0, 300)
	playerListFrame.Position = UDim2.new(0.5, 0, 0, 320)
	playerListFrame.AnchorPoint = Vector2.new(0.5, 0)
	playerListFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	playerListFrame.BorderSizePixel = 0
	playerListFrame.ScrollBarThickness = 4
	playerListFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
	playerListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	playerListFrame.Parent = mainFrame

	local listCorner = Instance.new("UICorner")
	listCorner.CornerRadius = UDim.new(0, 8)
	listCorner.Parent = playerListFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 2)
	listLayout.Parent = playerListFrame

	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingTop = UDim.new(0, 5)
	listPadding.PaddingBottom = UDim.new(0, 5)
	listPadding.PaddingLeft = UDim.new(0, 5)
	listPadding.PaddingRight = UDim.new(0, 5)
	listPadding.Parent = playerListFrame

	-- Ready button
	local readyButton = Instance.new("TextButton")
	readyButton.Name = "ReadyButton"
	readyButton.Size = UDim2.new(0, 250, 0, 60)
	readyButton.Position = UDim2.new(0.5, 0, 1, -120)
	readyButton.AnchorPoint = Vector2.new(0.5, 0)
	readyButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
	readyButton.BorderSizePixel = 0
	readyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	readyButton.TextSize = 24
	readyButton.Font = Enum.Font.GothamBold
	readyButton.Text = "READY"
	readyButton.Parent = mainFrame

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 8)
	buttonCorner.Parent = readyButton

	readyButton.MouseButton1Click:Connect(function()
		LobbyScreen.ToggleReady()
	end)

	-- Button hover effects
	readyButton.MouseEnter:Connect(function()
		local targetColor = isReady and Color3.fromRGB(180, 60, 60) or Color3.fromRGB(70, 180, 70)
		TweenService:Create(readyButton, TweenInfo.new(0.2), { BackgroundColor3 = targetColor }):Play()
	end)

	readyButton.MouseLeave:Connect(function()
		local targetColor = isReady and Color3.fromRGB(150, 50, 50) or Color3.fromRGB(50, 150, 50)
		TweenService:Create(readyButton, TweenInfo.new(0.2), { BackgroundColor3 = targetColor }):Play()
	end)

	-- Countdown display (hidden by default)
	local countdownFrame = Instance.new("Frame")
	countdownFrame.Name = "Countdown"
	countdownFrame.Size = UDim2.new(0, 400, 0, 100)
	countdownFrame.Position = UDim2.new(0.5, 0, 1, -250)
	countdownFrame.AnchorPoint = Vector2.new(0.5, 0)
	countdownFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	countdownFrame.BorderSizePixel = 0
	countdownFrame.Visible = false
	countdownFrame.Parent = mainFrame

	local cdCorner = Instance.new("UICorner")
	cdCorner.CornerRadius = UDim.new(0, 8)
	cdCorner.Parent = countdownFrame

	local countdownLabel = Instance.new("TextLabel")
	countdownLabel.Name = "Time"
	countdownLabel.Size = UDim2.fromScale(1, 0.6)
	countdownLabel.BackgroundTransparency = 1
	countdownLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
	countdownLabel.TextSize = 48
	countdownLabel.Font = Enum.Font.GothamBlack
	countdownLabel.Text = "30"
	countdownLabel.Parent = countdownFrame

	local countdownSubLabel = Instance.new("TextLabel")
	countdownSubLabel.Name = "Label"
	countdownSubLabel.Size = UDim2.fromScale(1, 0.4)
	countdownSubLabel.Position = UDim2.fromScale(0, 0.6)
	countdownSubLabel.BackgroundTransparency = 1
	countdownSubLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
	countdownSubLabel.TextSize = 16
	countdownSubLabel.Font = Enum.Font.Gotham
	countdownSubLabel.Text = "Match starting..."
	countdownSubLabel.Parent = countdownFrame

	-- Tips at bottom
	local tipLabel = Instance.new("TextLabel")
	tipLabel.Name = "Tip"
	tipLabel.Size = UDim2.new(1, 0, 0, 30)
	tipLabel.Position = UDim2.new(0, 0, 1, -40)
	tipLabel.BackgroundTransparency = 1
	tipLabel.TextColor3 = Color3.fromRGB(100, 100, 100)
	tipLabel.TextSize = 14
	tipLabel.Font = Enum.Font.Gotham
	tipLabel.Text = "TIP: Dinosaurs roam the island - they can be dangerous allies or deadly foes!"
	tipLabel.Parent = mainFrame
end

--[[
	Setup event listeners
]]
function LobbyScreen.SetupEventListeners()
	-- Listen for match state changes (new format from Main.client.lua)
	Events.OnClientEvent("GameState", "MatchStateChanged", function(data)
		if data.newState == "Deploying" or data.newState == "Playing" then
			LobbyScreen.Hide()
		elseif data.newState == "Lobby" then
			LobbyScreen.Show()
		end
	end)

	-- Legacy format lobby updates (for backwards compatibility)
	Events.OnClientEvent("GameState", "LobbyUpdate", function(data)
		if data and data.players then
			LobbyScreen.UpdatePlayerList(data.players)
		end
	end)

	-- Countdown events
	Events.OnClientEvent("GameState", "CountdownStarted", function(data)
		if data and data.duration then
			LobbyScreen.StartCountdown(data.duration)
		end
	end)

	Events.OnClientEvent("GameState", "CountdownCancelled", function()
		LobbyScreen.CancelCountdown()
	end)

	-- Player added/removed
	Players.PlayerAdded:Connect(function()
		if isVisible then
			LobbyScreen.RefreshPlayerList()
		end
	end)

	Players.PlayerRemoving:Connect(function()
		if isVisible then
			LobbyScreen.RefreshPlayerList()
		end
	end)
end

--[[
	Toggle ready state
]]
function LobbyScreen.ToggleReady()
	isReady = not isReady

	-- Update button
	if mainFrame then
		local readyButton = mainFrame:FindFirstChild("ReadyButton") :: TextButton?
		if readyButton then
			if isReady then
				readyButton.Text = "CANCEL"
				readyButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
			else
				readyButton.Text = "READY"
				readyButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
			end
		end
	end

	-- Notify server
	Events.FireServer("GameState", "ToggleReady", { ready = isReady })
end

--[[
	Update player list display
]]
function LobbyScreen.UpdatePlayerList(playerData: { any }?)
	if not playerListFrame then return end

	-- Clear existing entries
	for _, child in ipairs(playerListFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	-- Get players to display
	local playersToShow = playerData or {}
	if #playersToShow == 0 then
		-- Use current players if no data provided
		for _, p in ipairs(Players:GetPlayers()) do
			table.insert(playersToShow, {
				name = p.Name,
				id = p.UserId,
				ready = false,
			})
		end
	end

	-- Create entries
	for i, pData in ipairs(playersToShow) do
		local entry = Instance.new("Frame")
		entry.Name = `Player_{pData.id or i}`
		entry.Size = UDim2.new(1, -10, 0, 30)
		entry.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
		entry.BorderSizePixel = 0
		entry.LayoutOrder = i
		entry.Parent = playerListFrame

		local entryCorner = Instance.new("UICorner")
		entryCorner.CornerRadius = UDim.new(0, 4)
		entryCorner.Parent = entry

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "Name"
		nameLabel.Size = UDim2.new(1, -80, 1, 0)
		nameLabel.Position = UDim2.fromOffset(10, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
		nameLabel.TextSize = 14
		nameLabel.Font = Enum.Font.Gotham
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Text = pData.name or "Unknown"
		nameLabel.Parent = entry

		local statusLabel = Instance.new("TextLabel")
		statusLabel.Name = "Status"
		statusLabel.Size = UDim2.new(0, 60, 1, 0)
		statusLabel.Position = UDim2.new(1, -70, 0, 0)
		statusLabel.BackgroundTransparency = 1
		statusLabel.TextSize = 12
		statusLabel.Font = Enum.Font.GothamBold
		statusLabel.Parent = entry

		if pData.ready then
			statusLabel.Text = "READY"
			statusLabel.TextColor3 = Color3.fromRGB(100, 200, 100)
		else
			statusLabel.Text = "WAITING"
			statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
		end
	end

	-- Update canvas size
	local layout = playerListFrame:FindFirstChild("UIListLayout") :: UIListLayout?
	if layout then
		playerListFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
	end

	-- Update player count
	LobbyScreen.UpdatePlayerCount(#playersToShow)
end

--[[
	Refresh player list from current players
]]
function LobbyScreen.RefreshPlayerList()
	LobbyScreen.UpdatePlayerList(nil)
end

--[[
	Update player count display
]]
function LobbyScreen.UpdatePlayerCount(count: number)
	if not mainFrame then return end

	local playerCountFrame = mainFrame:FindFirstChild("PlayerCount") :: Frame?
	if not playerCountFrame then return end

	local countLabel = playerCountFrame:FindFirstChild("Count") :: TextLabel?
	if countLabel then
		countLabel.Text = `{count} / {MAX_PLAYERS}`

		-- Color based on count
		if count >= MAX_PLAYERS then
			countLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
		elseif count >= MIN_PLAYERS_TO_START then
			countLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		else
			countLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
	end
end

--[[
	Start countdown display
]]
function LobbyScreen.StartCountdown(time: number)
	countdownActive = true
	countdownTime = time

	if not mainFrame then return end

	local countdownFrame = mainFrame:FindFirstChild("Countdown") :: Frame?
	if not countdownFrame then return end

	countdownFrame.Visible = true

	-- Update countdown
	task.spawn(function()
		while countdownActive and countdownTime > 0 do
			local timeLabel = countdownFrame:FindFirstChild("Time") :: TextLabel?
			if timeLabel then
				timeLabel.Text = tostring(math.ceil(countdownTime))

				-- Pulse effect on low time
				if countdownTime <= 5 then
					timeLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
					local tween = TweenService:Create(timeLabel, TweenInfo.new(0.3), { TextSize = 56 })
					tween:Play()
					tween.Completed:Wait()
					TweenService:Create(timeLabel, TweenInfo.new(0.2), { TextSize = 48 }):Play()
				end
			end

			task.wait(1)
			countdownTime = countdownTime - 1
		end
	end)
end

--[[
	Cancel countdown
]]
function LobbyScreen.CancelCountdown()
	countdownActive = false
	countdownTime = 0

	if not mainFrame then return end

	local countdownFrame = mainFrame:FindFirstChild("Countdown") :: Frame?
	if countdownFrame then
		countdownFrame.Visible = false
	end
end

--[[
	Load toast notification module
]]
local function loadToast()
	if ToastNotification then return end

	local success, result = pcall(function()
		return require(script.Parent.ToastNotification)
	end)
	if success then
		ToastNotification = result
	end
end

--[[
	Show the lobby screen with fade animation
]]
function LobbyScreen.Show()
	if not screenGui then return end
	if isVisible then return end

	isVisible = true
	isReady = false

	-- Reset ready button and all transparency values
	if mainFrame then
		local readyButton = mainFrame:FindFirstChild("ReadyButton") :: TextButton?
		if readyButton then
			readyButton.Text = "READY"
			readyButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
			readyButton.TextTransparency = 0
			readyButton.BackgroundTransparency = 0
		end

		-- Reset all children's transparency (in case they were faded out)
		for _, child in ipairs(mainFrame:GetDescendants()) do
			if child:IsA("TextLabel") or child:IsA("TextButton") then
				child.TextTransparency = 0
				child.BackgroundTransparency = child.Name == "Title" or child.Name == "Subtitle" or child.Name == "Tip"
					or child.Name == "Count" or child.Name == "SubLabel" or child.Name == "Time" or child.Name == "Label"
					or child.Name == "Name" or child.Name == "Status" or child.Name == "ControlsLabel"
					and 1 or 0 -- Keep text labels with transparent backgrounds
			elseif child:IsA("Frame") then
				child.BackgroundTransparency = 0
			elseif child:IsA("ScrollingFrame") then
				child.BackgroundTransparency = 0
				child.ScrollBarImageTransparency = 0
			end
		end

		-- Start with transparency for fade in
		mainFrame.BackgroundTransparency = 1
	end

	screenGui.Enabled = true

	-- Fade in animation
	if mainFrame then
		TweenService:Create(mainFrame, TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0,
		}):Play()
	end

	-- Refresh player list
	LobbyScreen.RefreshPlayerList()

	-- Show welcome toast
	loadToast()
	if ToastNotification then
		ToastNotification.Info("Welcome to the lobby!", 2)
	end
end

--[[
	Hide the lobby screen with fade animation
]]
function LobbyScreen.Hide()
	if not screenGui then return end
	if not isVisible then return end

	isVisible = false
	countdownActive = false

	-- Fade out animation for all children
	if mainFrame then
		-- Create a CanvasGroup-like fade effect by animating all text and frame elements
		local fadeInfo = TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

		-- Fade the main frame background
		TweenService:Create(mainFrame, fadeInfo, { BackgroundTransparency = 1 }):Play()

		-- Fade all children (text labels, frames, buttons)
		for _, child in ipairs(mainFrame:GetDescendants()) do
			if child:IsA("TextLabel") or child:IsA("TextButton") then
				TweenService:Create(child, fadeInfo, {
					TextTransparency = 1,
					BackgroundTransparency = 1,
				}):Play()
			elseif child:IsA("Frame") then
				TweenService:Create(child, fadeInfo, {
					BackgroundTransparency = 1,
				}):Play()
			elseif child:IsA("ScrollingFrame") then
				TweenService:Create(child, fadeInfo, {
					BackgroundTransparency = 1,
					ScrollBarImageTransparency = 1,
				}):Play()
			end
		end

		-- Disable after fade completes
		task.delay(FADE_DURATION + 0.05, function()
			if not isVisible and screenGui then
				screenGui.Enabled = false
			end
		end)
	else
		screenGui.Enabled = false
	end
end

--[[
	Check if visible
]]
function LobbyScreen.IsVisible(): boolean
	return isVisible
end

return LobbyScreen
