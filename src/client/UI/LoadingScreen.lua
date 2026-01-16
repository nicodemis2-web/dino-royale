--!strict
--[[
	LoadingScreen.lua
	=================
	Professional loading screen for Dino Royale.
	Displays during initial load and map transitions.

	FEATURES:
	- Animated background with parallax layers
	- Progress bar with smooth animation
	- Rotating gameplay tips
	- Dinosaur silhouette animation
	- Smooth fade in/out transitions

	@client
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")

local LoadingScreen = {}

--------------------------------------------------------------------------------
-- CONFIGURATION
--------------------------------------------------------------------------------

local TIPS = {
	-- Gameplay tips
	"Stay inside the safe zone - the storm deals increasing damage!",
	"Dinosaurs roam the island. Hunt them for powerful loot!",
	"Higher tier dinosaurs drop better weapons and gear.",
	"Headshots deal 2x damage - aim for the head!",
	"Crouching reduces weapon spread and makes you harder to spot.",
	"Sprint by holding Shift, but watch your stamina!",
	"The safe zone shrinks over time - keep moving!",
	"Legendary dinosaurs are extremely dangerous but drop the best loot.",
	"Use cover to avoid enemy fire and dinosaur attacks.",
	"Sound travels - sprinting and shooting reveals your position.",

	-- Weapon tips
	"Different weapons excel at different ranges.",
	"SMGs are great for close quarters combat.",
	"Sniper rifles are deadly at long range but slow to fire.",
	"Shotguns deal massive damage up close.",
	"Reload when safe - don't get caught with an empty magazine!",
	"Assault rifles are versatile at medium range.",

	-- Strategy tips
	"Land away from others if you want a safer early game.",
	"The center of the safe zone is often contested - be ready!",
	"High ground gives you a tactical advantage.",
	"Listen for dinosaur roars to locate high-tier creatures.",
	"Eliminate wounded dinosaurs to steal their prey's loot.",
	"Buildings provide cover but limit escape routes.",

	-- Dinosaur tips
	"Raptors are fast and hunt in packs - watch your back!",
	"T-Rex is slow but devastating - keep your distance!",
	"Pteranodons attack from above - look up!",
	"Triceratops charge when threatened - dodge sideways!",
	"Epic and Legendary dinosaurs have special abilities.",
}

local COLORS = {
	Background = Color3.fromRGB(15, 20, 30),
	BackgroundAccent = Color3.fromRGB(25, 35, 50),
	Primary = Color3.fromRGB(80, 200, 120),    -- Green accent
	Secondary = Color3.fromRGB(60, 150, 90),
	Text = Color3.fromRGB(255, 255, 255),
	TextDim = Color3.fromRGB(180, 180, 180),
	ProgressBg = Color3.fromRGB(40, 50, 60),
	ProgressFill = Color3.fromRGB(80, 200, 120),
}

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------

local localPlayer = Players.LocalPlayer
local playerGui: PlayerGui? = nil
local screenGui: ScreenGui? = nil

-- UI Elements
local mainFrame: Frame? = nil
local progressBar: Frame? = nil
local progressFill: Frame? = nil
local tipLabel: TextLabel? = nil
local statusLabel: TextLabel? = nil
local titleLabel: TextLabel? = nil
local dinoSilhouette: ImageLabel? = nil

-- Animation state
local isVisible = false
local currentProgress = 0
local targetProgress = 0
local currentTipIndex = 1
local tipRotationTime = 0
local updateConnection: RBXScriptConnection? = nil

--------------------------------------------------------------------------------
-- UI CREATION
--------------------------------------------------------------------------------

--[[
	Create the loading screen GUI
]]
local function createLoadingScreen()
	playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "LoadingScreen"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 1000 -- Above everything
	screenGui.Enabled = false
	screenGui.Parent = playerGui

	-- Main container
	mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.fromScale(1, 1)
	mainFrame.BackgroundColor3 = COLORS.Background
	mainFrame.BorderSizePixel = 0
	mainFrame.Parent = screenGui

	-- Background pattern (subtle grid)
	local bgPattern = Instance.new("Frame")
	bgPattern.Name = "BackgroundPattern"
	bgPattern.Size = UDim2.fromScale(1, 1)
	bgPattern.BackgroundColor3 = COLORS.BackgroundAccent
	bgPattern.BackgroundTransparency = 0.95
	bgPattern.BorderSizePixel = 0
	bgPattern.Parent = mainFrame

	-- Title
	titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(0.8, 0, 0, 80)
	titleLabel.Position = UDim2.new(0.5, 0, 0.25, 0)
	titleLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Text = "DINO ROYALE"
	titleLabel.TextColor3 = COLORS.Text
	titleLabel.TextSize = 64
	titleLabel.TextScaled = false
	titleLabel.Parent = mainFrame

	-- Subtitle
	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.Size = UDim2.new(0.6, 0, 0, 30)
	subtitle.Position = UDim2.new(0.5, 0, 0.32, 0)
	subtitle.AnchorPoint = Vector2.new(0.5, 0.5)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.Gotham
	subtitle.Text = "SURVIVAL OF THE FIERCEST"
	subtitle.TextColor3 = COLORS.Primary
	subtitle.TextSize = 24
	subtitle.Parent = mainFrame

	-- Dinosaur silhouette container (animated)
	local silhouetteContainer = Instance.new("Frame")
	silhouetteContainer.Name = "SilhouetteContainer"
	silhouetteContainer.Size = UDim2.new(0.4, 0, 0.3, 0)
	silhouetteContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
	silhouetteContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	silhouetteContainer.BackgroundTransparency = 1
	silhouetteContainer.Parent = mainFrame

	-- Simple dinosaur shape using frames (T-Rex silhouette)
	local function createDinoSilhouette(parent: Frame)
		local dinoFrame = Instance.new("Frame")
		dinoFrame.Name = "DinoSilhouette"
		dinoFrame.Size = UDim2.fromScale(1, 1)
		dinoFrame.BackgroundTransparency = 1
		dinoFrame.Parent = parent

		-- Body
		local body = Instance.new("Frame")
		body.Name = "Body"
		body.Size = UDim2.new(0.4, 0, 0.3, 0)
		body.Position = UDim2.new(0.3, 0, 0.4, 0)
		body.BackgroundColor3 = COLORS.Primary
		body.BackgroundTransparency = 0.3
		body.BorderSizePixel = 0
		body.Parent = dinoFrame

		local bodyCorner = Instance.new("UICorner")
		bodyCorner.CornerRadius = UDim.new(0.3, 0)
		bodyCorner.Parent = body

		-- Head
		local head = Instance.new("Frame")
		head.Name = "Head"
		head.Size = UDim2.new(0.25, 0, 0.2, 0)
		head.Position = UDim2.new(0.55, 0, 0.25, 0)
		head.BackgroundColor3 = COLORS.Primary
		head.BackgroundTransparency = 0.3
		head.BorderSizePixel = 0
		head.Parent = dinoFrame

		local headCorner = Instance.new("UICorner")
		headCorner.CornerRadius = UDim.new(0.2, 0)
		headCorner.Parent = head

		-- Tail
		local tail = Instance.new("Frame")
		tail.Name = "Tail"
		tail.Size = UDim2.new(0.35, 0, 0.15, 0)
		tail.Position = UDim2.new(0, 0, 0.45, 0)
		tail.BackgroundColor3 = COLORS.Primary
		tail.BackgroundTransparency = 0.3
		tail.BorderSizePixel = 0
		tail.Parent = dinoFrame

		local tailCorner = Instance.new("UICorner")
		tailCorner.CornerRadius = UDim.new(0.5, 0)
		tailCorner.Parent = tail

		-- Legs
		local leg1 = Instance.new("Frame")
		leg1.Name = "Leg1"
		leg1.Size = UDim2.new(0.08, 0, 0.25, 0)
		leg1.Position = UDim2.new(0.38, 0, 0.65, 0)
		leg1.BackgroundColor3 = COLORS.Primary
		leg1.BackgroundTransparency = 0.3
		leg1.BorderSizePixel = 0
		leg1.Parent = dinoFrame

		local leg2 = Instance.new("Frame")
		leg2.Name = "Leg2"
		leg2.Size = UDim2.new(0.08, 0, 0.25, 0)
		leg2.Position = UDim2.new(0.55, 0, 0.65, 0)
		leg2.BackgroundColor3 = COLORS.Primary
		leg2.BackgroundTransparency = 0.3
		leg2.BorderSizePixel = 0
		leg2.Parent = dinoFrame

		return dinoFrame
	end

	dinoSilhouette = createDinoSilhouette(silhouetteContainer) :: any

	-- Progress section container
	local progressContainer = Instance.new("Frame")
	progressContainer.Name = "ProgressContainer"
	progressContainer.Size = UDim2.new(0.6, 0, 0, 100)
	progressContainer.Position = UDim2.new(0.5, 0, 0.75, 0)
	progressContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	progressContainer.BackgroundTransparency = 1
	progressContainer.Parent = mainFrame

	-- Status label
	statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.Size = UDim2.new(1, 0, 0, 24)
	statusLabel.Position = UDim2.new(0, 0, 0, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Enum.Font.GothamMedium
	statusLabel.Text = "Loading..."
	statusLabel.TextColor3 = COLORS.Text
	statusLabel.TextSize = 18
	statusLabel.Parent = progressContainer

	-- Progress bar background
	progressBar = Instance.new("Frame")
	progressBar.Name = "ProgressBar"
	progressBar.Size = UDim2.new(1, 0, 0, 8)
	progressBar.Position = UDim2.new(0, 0, 0, 35)
	progressBar.BackgroundColor3 = COLORS.ProgressBg
	progressBar.BorderSizePixel = 0
	progressBar.Parent = progressContainer

	local progressCorner = Instance.new("UICorner")
	progressCorner.CornerRadius = UDim.new(0, 4)
	progressCorner.Parent = progressBar

	-- Progress bar fill
	progressFill = Instance.new("Frame")
	progressFill.Name = "Fill"
	progressFill.Size = UDim2.new(0, 0, 1, 0)
	progressFill.BackgroundColor3 = COLORS.ProgressFill
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressBar

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = progressFill

	-- Glow effect on progress
	local fillGlow = Instance.new("Frame")
	fillGlow.Name = "Glow"
	fillGlow.Size = UDim2.new(0, 20, 1, 4)
	fillGlow.Position = UDim2.new(1, -10, 0.5, 0)
	fillGlow.AnchorPoint = Vector2.new(0.5, 0.5)
	fillGlow.BackgroundColor3 = COLORS.Primary
	fillGlow.BackgroundTransparency = 0.5
	fillGlow.BorderSizePixel = 0
	fillGlow.Parent = progressFill

	local glowCorner = Instance.new("UICorner")
	glowCorner.CornerRadius = UDim.new(0.5, 0)
	glowCorner.Parent = fillGlow

	-- Tip label
	tipLabel = Instance.new("TextLabel")
	tipLabel.Name = "Tip"
	tipLabel.Size = UDim2.new(1, 0, 0, 40)
	tipLabel.Position = UDim2.new(0, 0, 0, 55)
	tipLabel.BackgroundTransparency = 1
	tipLabel.Font = Enum.Font.Gotham
	tipLabel.Text = "TIP: " .. TIPS[1]
	tipLabel.TextColor3 = COLORS.TextDim
	tipLabel.TextSize = 14
	tipLabel.TextWrapped = true
	tipLabel.TextXAlignment = Enum.TextXAlignment.Center
	tipLabel.Parent = progressContainer

	-- Version info
	local versionLabel = Instance.new("TextLabel")
	versionLabel.Name = "Version"
	versionLabel.Size = UDim2.new(0, 200, 0, 20)
	versionLabel.Position = UDim2.new(1, -10, 1, -10)
	versionLabel.AnchorPoint = Vector2.new(1, 1)
	versionLabel.BackgroundTransparency = 1
	versionLabel.Font = Enum.Font.Gotham
	versionLabel.Text = "v0.1.0 Alpha"
	versionLabel.TextColor3 = COLORS.TextDim
	versionLabel.TextSize = 12
	versionLabel.TextXAlignment = Enum.TextXAlignment.Right
	versionLabel.TextTransparency = 0.5
	versionLabel.Parent = mainFrame
end

--------------------------------------------------------------------------------
-- ANIMATION
--------------------------------------------------------------------------------

--[[
	Update loop for animations
]]
local function onUpdate(deltaTime: number)
	-- Smooth progress bar animation
	if progressFill and currentProgress ~= targetProgress then
		currentProgress = currentProgress + (targetProgress - currentProgress) * math.min(deltaTime * 5, 1)
		progressFill.Size = UDim2.new(math.clamp(currentProgress, 0, 1), 0, 1, 0)
	end

	-- Tip rotation
	tipRotationTime = tipRotationTime + deltaTime
	if tipRotationTime >= 5 then -- Change tip every 5 seconds
		tipRotationTime = 0
		currentTipIndex = (currentTipIndex % #TIPS) + 1

		if tipLabel then
			-- Fade out
			local fadeOut = TweenService:Create(tipLabel, TweenInfo.new(0.3), {
				TextTransparency = 1,
			})
			fadeOut:Play()
			fadeOut.Completed:Connect(function()
				if tipLabel then
					tipLabel.Text = "TIP: " .. TIPS[currentTipIndex]
					-- Fade in
					TweenService:Create(tipLabel, TweenInfo.new(0.3), {
						TextTransparency = 0,
					}):Play()
				end
			end)
		end
	end

	-- Subtle dinosaur breathing animation
	if dinoSilhouette then
		local breathe = math.sin(tick() * 2) * 0.02
		dinoSilhouette.Size = UDim2.fromScale(1 + breathe, 1 + breathe)
	end
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

--[[
	Initialize the loading screen
]]
function LoadingScreen.Initialize()
	createLoadingScreen()

	-- Start update loop
	updateConnection = RunService.RenderStepped:Connect(onUpdate)

	print("[LoadingScreen] Initialized")
end

--[[
	Show the loading screen with fade in
]]
function LoadingScreen.Show(instant: boolean?)
	if not screenGui or not mainFrame then return end

	isVisible = true
	currentProgress = 0
	targetProgress = 0
	tipRotationTime = 0
	currentTipIndex = math.random(1, #TIPS)

	if tipLabel then
		tipLabel.Text = "TIP: " .. TIPS[currentTipIndex]
	end

	if instant then
		mainFrame.BackgroundTransparency = 0
		screenGui.Enabled = true
	else
		mainFrame.BackgroundTransparency = 1
		screenGui.Enabled = true

		TweenService:Create(mainFrame, TweenInfo.new(0.5), {
			BackgroundTransparency = 0,
		}):Play()
	end
end

--[[
	Hide the loading screen with fade out
]]
function LoadingScreen.Hide(instant: boolean?)
	if not screenGui or not mainFrame then return end

	isVisible = false

	if instant then
		screenGui.Enabled = false
	else
		local tween = TweenService:Create(mainFrame, TweenInfo.new(0.5), {
			BackgroundTransparency = 1,
		})
		tween:Play()
		tween.Completed:Connect(function()
			if screenGui and not isVisible then
				screenGui.Enabled = false
			end
		end)
	end
end

--[[
	Set the loading progress (0-1)
]]
function LoadingScreen.SetProgress(progress: number)
	targetProgress = math.clamp(progress, 0, 1)
end

--[[
	Set the status text
]]
function LoadingScreen.SetStatus(status: string)
	if statusLabel then
		statusLabel.Text = status
	end
end

--[[
	Complete loading sequence - fills to 100% then hides
]]
function LoadingScreen.Complete(callback: (() -> ())?)
	LoadingScreen.SetProgress(1)
	LoadingScreen.SetStatus("Ready!")

	task.delay(0.5, function()
		LoadingScreen.Hide()
		if callback then
			task.delay(0.5, callback)
		end
	end)
end

--[[
	Preload assets with progress tracking
]]
function LoadingScreen.PreloadAssets(assets: { Instance }, callback: (() -> ())?)
	if #assets == 0 then
		LoadingScreen.SetProgress(1)
		if callback then callback() end
		return
	end

	local loaded = 0
	local total = #assets

	LoadingScreen.SetStatus("Loading assets...")

	ContentProvider:PreloadAsync(assets, function(assetId, status)
		loaded += 1
		LoadingScreen.SetProgress(loaded / total)
		LoadingScreen.SetStatus(`Loading assets... ({loaded}/{total})`)
	end)

	LoadingScreen.SetProgress(1)
	LoadingScreen.SetStatus("Assets loaded!")

	if callback then
		callback()
	end
end

--[[
	Check if loading screen is visible
]]
function LoadingScreen.IsVisible(): boolean
	return isVisible
end

--[[
	Get a random tip
]]
function LoadingScreen.GetRandomTip(): string
	return TIPS[math.random(1, #TIPS)]
end

--[[
	Cleanup
]]
function LoadingScreen.Cleanup()
	if updateConnection then
		updateConnection:Disconnect()
		updateConnection = nil
	end

	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
end

return LoadingScreen
