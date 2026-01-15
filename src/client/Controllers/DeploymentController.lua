--!strict
--[[
	DeploymentController.lua
	========================
	Client-side deployment controls
	Handles helicopter UI, glider descent, and landing
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")

local Events = require(game.ReplicatedStorage.Shared.Events)

-- Toast notification (loaded lazily)
local ToastNotification: any = nil

local DeploymentController = {}

-- Local player reference
local localPlayer = Players.LocalPlayer

-- State
local isDeploymentActive = false
local hasJumped = false
local isGliding = false
local flightPath: { startPoint: Vector3, endPoint: Vector3, duration: number }? = nil
local deployStartTime = 0

-- Glider input
local pitchInput = 0 -- -1 = dive, 0 = glide, 1 = pull up (limited)
local yawInput = 0 -- -1 = left, 1 = right

-- Camera settings
local GLIDE_CAMERA_DISTANCE = 20
local GLIDE_CAMERA_HEIGHT = 10

-- UI references
local deploymentGui: ScreenGui? = nil
local minimapFrame: Frame? = nil
local jumpButton: TextButton? = nil
local altitudeLabel: TextLabel? = nil
local speedLabel: TextLabel? = nil

-- Connections
local connections = {} :: { RBXScriptConnection }

--[[
	Create deployment UI
]]
local function createDeploymentUI()
	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

	deploymentGui = Instance.new("ScreenGui")
	deploymentGui.Name = "DeploymentGui"
	deploymentGui.ResetOnSpawn = false
	deploymentGui.Parent = playerGui

	-- Minimap container (top right)
	minimapFrame = Instance.new("Frame")
	minimapFrame.Name = "Minimap"
	minimapFrame.AnchorPoint = Vector2.new(1, 0)
	minimapFrame.Position = UDim2.new(1, -20, 0, 20)
	minimapFrame.Size = UDim2.fromOffset(200, 200)
	minimapFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	minimapFrame.BackgroundTransparency = 0.3
	minimapFrame.Parent = deploymentGui

	local minimapCorner = Instance.new("UICorner")
	minimapCorner.CornerRadius = UDim.new(0, 8)
	minimapCorner.Parent = minimapFrame

	local minimapBorder = Instance.new("UIStroke")
	minimapBorder.Color = Color3.fromRGB(100, 100, 100)
	minimapBorder.Thickness = 2
	minimapBorder.Parent = minimapFrame

	-- Flight path line (simplified as a frame)
	local pathLine = Instance.new("Frame")
	pathLine.Name = "FlightPath"
	pathLine.AnchorPoint = Vector2.new(0.5, 0.5)
	pathLine.Position = UDim2.fromScale(0.5, 0.5)
	pathLine.Size = UDim2.new(0.8, 0, 0, 4)
	pathLine.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
	pathLine.BorderSizePixel = 0
	pathLine.Parent = minimapFrame

	-- Player position indicator
	local playerDot = Instance.new("Frame")
	playerDot.Name = "PlayerDot"
	playerDot.AnchorPoint = Vector2.new(0.5, 0.5)
	playerDot.Position = UDim2.fromScale(0.1, 0.5)
	playerDot.Size = UDim2.fromOffset(12, 12)
	playerDot.BackgroundColor3 = Color3.fromRGB(50, 200, 255)
	playerDot.Parent = minimapFrame

	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = playerDot

	-- Jump button container (center bottom)
	local jumpContainer = Instance.new("Frame")
	jumpContainer.Name = "JumpContainer"
	jumpContainer.AnchorPoint = Vector2.new(0.5, 1)
	jumpContainer.Position = UDim2.new(0.5, 0, 1, -80)
	jumpContainer.Size = UDim2.fromOffset(250, 90)
	jumpContainer.BackgroundTransparency = 1
	jumpContainer.Parent = deploymentGui

	jumpButton = Instance.new("TextButton")
	jumpButton.Name = "JumpButton"
	jumpButton.AnchorPoint = Vector2.new(0.5, 0)
	jumpButton.Position = UDim2.new(0.5, 0, 0, 0)
	jumpButton.Size = UDim2.fromOffset(220, 55)
	jumpButton.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
	jumpButton.Text = "PRESS SPACE TO JUMP"
	jumpButton.TextColor3 = Color3.new(1, 1, 1)
	jumpButton.TextScaled = true
	jumpButton.Font = Enum.Font.GothamBold
	jumpButton.AutoButtonColor = true
	jumpButton.Parent = jumpContainer

	-- Text size constraint for jump button
	local jumpTextConstraint = Instance.new("UITextSizeConstraint")
	jumpTextConstraint.MinTextSize = 12
	jumpTextConstraint.MaxTextSize = 20
	jumpTextConstraint.Parent = jumpButton

	local jumpCorner = Instance.new("UICorner")
	jumpCorner.CornerRadius = UDim.new(0, 8)
	jumpCorner.Parent = jumpButton

	-- Subtle glow/pulse animation on button
	local jumpStroke = Instance.new("UIStroke")
	jumpStroke.Color = Color3.fromRGB(100, 180, 255)
	jumpStroke.Thickness = 2
	jumpStroke.Transparency = 0.5
	jumpStroke.Parent = jumpButton

	-- Skip hint label below button
	local skipHint = Instance.new("TextLabel")
	skipHint.Name = "SkipHint"
	skipHint.AnchorPoint = Vector2.new(0.5, 0)
	skipHint.Position = UDim2.new(0.5, 0, 0, 62)
	skipHint.Size = UDim2.fromOffset(250, 25)
	skipHint.BackgroundTransparency = 1
	skipHint.Text = "or click anywhere on the map to jump"
	skipHint.TextColor3 = Color3.fromRGB(180, 180, 180)
	skipHint.TextScaled = true
	skipHint.Font = Enum.Font.Gotham
	skipHint.Parent = jumpContainer

	local skipHintConstraint = Instance.new("UITextSizeConstraint")
	skipHintConstraint.MinTextSize = 10
	skipHintConstraint.MaxTextSize = 14
	skipHintConstraint.Parent = skipHint

	jumpButton.MouseButton1Click:Connect(function()
		DeploymentController.RequestJump()
	end)

	-- Pulse animation for jump button
	task.spawn(function()
		while jumpButton and jumpButton.Parent do
			local pulseIn = TweenService:Create(jumpStroke, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Transparency = 0,
				Thickness = 3,
			})
			pulseIn:Play()
			pulseIn.Completed:Wait()

			local pulseOut = TweenService:Create(jumpStroke, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Transparency = 0.5,
				Thickness = 2,
			})
			pulseOut:Play()
			pulseOut.Completed:Wait()
		end
	end)

	-- Altitude display (during glide)
	altitudeLabel = Instance.new("TextLabel")
	altitudeLabel.Name = "Altitude"
	altitudeLabel.AnchorPoint = Vector2.new(0, 1)
	altitudeLabel.Position = UDim2.new(0, 20, 1, -20)
	altitudeLabel.Size = UDim2.fromOffset(150, 30)
	altitudeLabel.BackgroundTransparency = 1
	altitudeLabel.Text = "ALT: 500m"
	altitudeLabel.TextColor3 = Color3.new(1, 1, 1)
	altitudeLabel.TextSize = 24
	altitudeLabel.Font = Enum.Font.GothamBold
	altitudeLabel.TextXAlignment = Enum.TextXAlignment.Left
	altitudeLabel.Visible = false
	altitudeLabel.Parent = deploymentGui

	-- Speed display (during glide)
	speedLabel = Instance.new("TextLabel")
	speedLabel.Name = "Speed"
	speedLabel.AnchorPoint = Vector2.new(0, 1)
	speedLabel.Position = UDim2.new(0, 20, 1, -50)
	speedLabel.Size = UDim2.fromOffset(150, 30)
	speedLabel.BackgroundTransparency = 1
	speedLabel.Text = "SPD: 20 m/s"
	speedLabel.TextColor3 = Color3.new(1, 1, 1)
	speedLabel.TextSize = 24
	speedLabel.Font = Enum.Font.GothamBold
	speedLabel.TextXAlignment = Enum.TextXAlignment.Left
	speedLabel.Visible = false
	speedLabel.Parent = deploymentGui
end

--[[
	Update minimap player position
]]
local function updateMinimapPosition(progress: number)
	if not minimapFrame then
		return
	end

	local playerDot = minimapFrame:FindFirstChild("PlayerDot") :: Frame?
	if playerDot then
		local xPos = 0.1 + progress * 0.8 -- Map 0-1 to 0.1-0.9
		playerDot.Position = UDim2.fromScale(xPos, 0.5)
	end
end

--[[
	Show glider UI
]]
local function showGliderUI()
	if jumpButton then
		jumpButton.Visible = false
	end
	if altitudeLabel then
		altitudeLabel.Visible = true
	end
	if speedLabel then
		speedLabel.Visible = true
	end
end

--[[
	Hide all deployment UI
]]
local function hideDeploymentUI()
	if deploymentGui then
		deploymentGui:Destroy()
		deploymentGui = nil
	end
	minimapFrame = nil
	jumpButton = nil
	altitudeLabel = nil
	speedLabel = nil
end

--[[
	Update glider controls based on input
]]
local function updateGliderInput()
	pitchInput = 0
	yawInput = 0

	-- Keyboard input
	if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.S) then
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then
			pitchInput = -0.8 -- Dive (limited pull-up on S)
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then
			pitchInput = 0.3 -- Slight pull up (can't gain altitude)
		end
	end

	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		yawInput = -1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		yawInput = 1
	end

	-- Mouse input for aiming direction
	-- Could add mouse look here for more control
end

--[[
	Update glider camera
]]
local function updateGliderCamera()
	local camera = workspace.CurrentCamera
	local character = localPlayer.Character
	if not camera or not character then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return
	end

	-- Third person behind player
	local position = rootPart.Position
	local lookVector = rootPart.CFrame.LookVector

	local cameraPosition = position - lookVector * GLIDE_CAMERA_DISTANCE + Vector3.new(0, GLIDE_CAMERA_HEIGHT, 0)
	camera.CFrame = CFrame.new(cameraPosition, position)
end

--[[
	Update altitude and speed display
]]
local function updateGliderDisplay()
	local character = localPlayer.Character
	if not character then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return
	end

	local altitude = math.floor(rootPart.Position.Y)
	local speed = math.floor(rootPart.AssemblyLinearVelocity.Magnitude)

	if altitudeLabel then
		altitudeLabel.Text = `ALT: {altitude}m`
	end

	if speedLabel then
		speedLabel.Text = `SPD: {speed} m/s`
	end
end

--[[
	Request to jump from helicopter
]]
function DeploymentController.RequestJump()
	if not isDeploymentActive or hasJumped then
		return
	end

	Events.FireServer("GameState", "PlayerJumped", {})
end

--[[
	Handle deployment ready event
]]
local function onDeployReady(data: { flightPath: { startPoint: Vector3, endPoint: Vector3, duration: number } })
	flightPath = data.flightPath
	deployStartTime = tick()
	isDeploymentActive = true
	hasJumped = false
	isGliding = false

	createDeploymentUI()

	print("[DeploymentController] Deployment ready, flight path received")
end

--[[
	Handle glider enabled event
]]
local function onGliderEnabled(data: { position: Vector3, forced: boolean? })
	hasJumped = true
	isGliding = true

	showGliderUI()

	-- Bind glider controls
	ContextActionService:BindAction("GliderPitch", function(_, inputState)
		-- Handled in update
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.W, Enum.KeyCode.S)

	ContextActionService:BindAction("GliderYaw", function(_, inputState)
		-- Handled in update
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.A, Enum.KeyCode.D)

	print("[DeploymentController] Glider enabled")
end

--[[
	Handle glider disabled event (landed)
]]
local function onGliderDisabled()
	isGliding = false

	-- Unbind glider controls
	ContextActionService:UnbindAction("GliderPitch")
	ContextActionService:UnbindAction("GliderYaw")

	-- Hide UI
	hideDeploymentUI()

	print("[DeploymentController] Landed, glider disabled")
end

--[[
	Handle jump denied - show toast feedback
]]
local function onJumpDenied(data: { reason: string })
	-- Load toast if not loaded
	if not ToastNotification then
		local success, result = pcall(function()
			return require(game.Players.LocalPlayer.PlayerGui:WaitForChild("ToastNotificationGui", 1))
		end)
		if not success then
			-- Try loading from components
			local playerScripts = game.Players.LocalPlayer:WaitForChild("PlayerScripts", 1)
			if playerScripts then
				local UI = playerScripts:FindFirstChild("UI")
				if UI then
					local Components = UI:FindFirstChild("Components")
					if Components then
						local toastModule = Components:FindFirstChild("ToastNotification")
						if toastModule then
							ToastNotification = require(toastModule)
						end
					end
				end
			end
		end
	end

	-- Show toast notification
	if ToastNotification then
		ToastNotification.Warning(`Can't jump: {data.reason}`, 2)
	end

	warn(`[DeploymentController] Jump denied: {data.reason}`)
end

--[[
	Update loop
]]
local function update(dt: number)
	if not isDeploymentActive then
		return
	end

	if not hasJumped and flightPath then
		-- Update helicopter position on minimap
		local elapsed = tick() - deployStartTime
		local progress = math.clamp(elapsed / flightPath.duration, 0, 1)
		updateMinimapPosition(progress)
	end

	if isGliding then
		updateGliderInput()

		-- Send input to server
		Events.FireServer("GameState", "GliderInput", {
			pitch = pitchInput,
			yaw = yawInput,
		})

		updateGliderCamera()
		updateGliderDisplay()
	end
end

--[[
	Bind jump action
]]
local function bindJumpAction()
	ContextActionService:BindAction("DeployJump", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			DeploymentController.RequestJump()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.Space)
end

--[[
	Initialize the deployment controller
]]
function DeploymentController.Initialize()
	-- Listen for deployment events
	local deployReadyConn = Events.OnClientEvent("GameState", "DeployReady", onDeployReady)
	table.insert(connections, deployReadyConn)

	local gliderEnabledConn = Events.OnClientEvent("GameState", "GliderEnabled", onGliderEnabled)
	table.insert(connections, gliderEnabledConn)

	local gliderDisabledConn = Events.OnClientEvent("GameState", "GliderDisabled", onGliderDisabled)
	table.insert(connections, gliderDisabledConn)

	local jumpDeniedConn = Events.OnClientEvent("GameState", "JumpDenied", onJumpDenied)
	table.insert(connections, jumpDeniedConn)

	-- Bind jump action
	bindJumpAction()

	-- Update loop
	local heartbeatConn = RunService.Heartbeat:Connect(update)
	table.insert(connections, heartbeatConn)

	print("[DeploymentController] Initialized")
end

--[[
	Enable deployment mode
]]
function DeploymentController.Enable()
	isDeploymentActive = true
	print("[DeploymentController] Enabled")
end

--[[
	Disable deployment mode
]]
function DeploymentController.Disable()
	isDeploymentActive = false
	isGliding = false
	hasJumped = false
	hideDeploymentUI()
	print("[DeploymentController] Disabled")
end

--[[
	Check if deployment is active
]]
function DeploymentController.IsActive(): boolean
	return isDeploymentActive
end

--[[
	Check if player is gliding
]]
function DeploymentController.IsGliding(): boolean
	return isGliding
end

--[[
	Check if player has jumped
]]
function DeploymentController.HasJumped(): boolean
	return hasJumped
end

--[[
	Cleanup
]]
function DeploymentController.Cleanup()
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	connections = {}

	ContextActionService:UnbindAction("DeployJump")
	ContextActionService:UnbindAction("GliderPitch")
	ContextActionService:UnbindAction("GliderYaw")

	hideDeploymentUI()

	isDeploymentActive = false
	hasJumped = false
	isGliding = false
end

return DeploymentController
