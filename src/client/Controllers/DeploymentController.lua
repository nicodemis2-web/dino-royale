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

local Events = require(game.ReplicatedStorage.Shared.Events)

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

	-- Jump button (center bottom)
	jumpButton = Instance.new("TextButton")
	jumpButton.Name = "JumpButton"
	jumpButton.AnchorPoint = Vector2.new(0.5, 1)
	jumpButton.Position = UDim2.new(0.5, 0, 1, -100)
	jumpButton.Size = UDim2.fromOffset(200, 60)
	jumpButton.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
	jumpButton.Text = "PRESS SPACE TO JUMP"
	jumpButton.TextColor3 = Color3.new(1, 1, 1)
	jumpButton.TextSize = 18
	jumpButton.Font = Enum.Font.GothamBold
	jumpButton.Parent = deploymentGui

	local jumpCorner = Instance.new("UICorner")
	jumpCorner.CornerRadius = UDim.new(0, 8)
	jumpCorner.Parent = jumpButton

	jumpButton.MouseButton1Click:Connect(function()
		DeploymentController.RequestJump()
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
	Handle jump denied
]]
local function onJumpDenied(data: { reason: string })
	-- Could show UI feedback
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
