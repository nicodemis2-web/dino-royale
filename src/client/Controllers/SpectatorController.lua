--!strict
--[[
	SpectatorController.lua
	=======================
	Client-side spectator camera and UI
	Allows eliminated players to watch remaining players
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local _RunService = game:GetService("RunService")

local Events = require(ReplicatedStorage.Shared.Events)

local SpectatorController = {}

-- State
local player = Players.LocalPlayer
local screenGui: ScreenGui? = nil
local spectatorUI: Frame? = nil
local isSpectating = false
local spectateTargets: { Player } = {}
local currentTargetIndex = 1
local currentTarget: Player? = nil
local spectatorCamera: Camera? = nil
local originalCamera: Camera? = nil

-- Connections for cleanup
local connections: { RBXScriptConnection } = {}

-- Camera settings
local CAMERA_DISTANCE = 15
local CAMERA_HEIGHT = 5
local CAMERA_SMOOTHNESS = 0.1

-- Input bindings
local NEXT_TARGET_KEY = Enum.KeyCode.E
local PREV_TARGET_KEY = Enum.KeyCode.Q
local FREE_CAM_KEY = Enum.KeyCode.F

local isFreeCam = false
local freeCamPosition = Vector3.new(0, 100, 0)
local freeCamRotation = CFrame.new()

--[[
	Initialize the spectator controller
]]
function SpectatorController.Initialize()
	print("[SpectatorController] Initializing...")

	SpectatorController.CreateUI()
	SpectatorController.SetupEventListeners()
	SpectatorController.SetupInputHandling()

	game:GetService("RunService").RenderStepped:Connect(function(deltaTime)
		if isSpectating then
			SpectatorController.UpdateCamera(deltaTime)
		end
	end)

	print("[SpectatorController] Initialized")
end

--[[
	Create spectator UI
]]
function SpectatorController.CreateUI()
	local playerGui = player:WaitForChild("PlayerGui")

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SpectatorUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Enabled = false
	screenGui.Parent = playerGui

	-- Main spectator panel
	spectatorUI = Instance.new("Frame")
	spectatorUI.Name = "SpectatorPanel"
	spectatorUI.Size = UDim2.fromOffset(300, 80)
	spectatorUI.Position = UDim2.new(0.5, 0, 0, 20)
	spectatorUI.AnchorPoint = Vector2.new(0.5, 0)
	spectatorUI.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	spectatorUI.BackgroundTransparency = 0.3
	spectatorUI.BorderSizePixel = 0
	spectatorUI.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = spectatorUI

	-- "SPECTATING" label
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0, 20)
	titleLabel.Position = UDim2.fromOffset(0, 5)
	titleLabel.BackgroundTransparency = 1
	titleLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
	titleLabel.TextSize = 12
	titleLabel.Font = Enum.Font.Gotham
	titleLabel.Text = "SPECTATING"
	titleLabel.Parent = spectatorUI

	-- Target name
	local targetLabel = Instance.new("TextLabel")
	targetLabel.Name = "TargetName"
	targetLabel.Size = UDim2.new(1, -20, 0, 30)
	targetLabel.Position = UDim2.fromOffset(10, 25)
	targetLabel.BackgroundTransparency = 1
	targetLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	targetLabel.TextSize = 22
	targetLabel.Font = Enum.Font.GothamBold
	targetLabel.Text = "Player Name"
	targetLabel.Parent = spectatorUI

	-- Controls hint
	local controlsLabel = Instance.new("TextLabel")
	controlsLabel.Name = "Controls"
	controlsLabel.Size = UDim2.new(1, 0, 0, 15)
	controlsLabel.Position = UDim2.new(0, 0, 1, -20)
	controlsLabel.BackgroundTransparency = 1
	controlsLabel.TextColor3 = Color3.fromRGB(100, 100, 100)
	controlsLabel.TextSize = 10
	controlsLabel.Font = Enum.Font.Gotham
	controlsLabel.Text = "[Q] Previous  |  [E] Next  |  [F] Free Cam"
	controlsLabel.Parent = spectatorUI

	-- Player count
	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "PlayerCount"
	countLabel.Size = UDim2.fromOffset(80, 20)
	countLabel.Position = UDim2.new(1, -90, 0, 5)
	countLabel.BackgroundTransparency = 1
	countLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	countLabel.TextSize = 12
	countLabel.Font = Enum.Font.GothamBold
	countLabel.Text = "1/50"
	countLabel.TextXAlignment = Enum.TextXAlignment.Right
	countLabel.Parent = spectatorUI
end

--[[
	Setup event listeners
]]
function SpectatorController.SetupEventListeners()
	Events.OnClientEvent("GameState", function(action, _data)
		if action == "Spectate" then
			SpectatorController.StartSpectating()
		elseif action == "StopSpectate" then
			SpectatorController.StopSpectating()
		end
	end)

	-- Update targets when players leave
	Players.PlayerRemoving:Connect(function(_removedPlayer)
		if isSpectating then
			SpectatorController.RefreshTargets()
		end
	end)
end

--[[
	Setup input handling using ContextActionService
]]
function SpectatorController.SetupInputHandling()
	-- Bind spectator controls (only active when spectating)
	ContextActionService:BindAction("SpectatorNextTarget", function(_, inputState)
		if inputState == Enum.UserInputState.Begin and isSpectating then
			SpectatorController.NextTarget()
		end
		return Enum.ContextActionResult.Pass
	end, false, NEXT_TARGET_KEY)

	ContextActionService:BindAction("SpectatorPrevTarget", function(_, inputState)
		if inputState == Enum.UserInputState.Begin and isSpectating then
			SpectatorController.PreviousTarget()
		end
		return Enum.ContextActionResult.Pass
	end, false, PREV_TARGET_KEY)

	ContextActionService:BindAction("SpectatorFreeCam", function(_, inputState)
		if inputState == Enum.UserInputState.Begin and isSpectating then
			SpectatorController.ToggleFreeCam()
		end
		return Enum.ContextActionResult.Pass
	end, false, FREE_CAM_KEY)

	-- Free cam mouse look (still use UserInputService for continuous mouse movement)
	local mouseConn = UserInputService.InputChanged:Connect(function(input, _gameProcessed)
		if not isSpectating or not isFreeCam then return end

		if input.UserInputType == Enum.UserInputType.MouseMovement then
			-- Handle mouse look in free cam
			local delta = input.Delta
			local sensitivity = 0.002
			freeCamRotation = freeCamRotation * CFrame.Angles(-delta.Y * sensitivity, -delta.X * sensitivity, 0)
		end
	end)
	table.insert(connections, mouseConn)
end

--[[
	Start spectating
]]
function SpectatorController.StartSpectating()
	if isSpectating then return end
	isSpectating = true

	print("[SpectatorController] Starting spectator mode")

	-- Store original camera
	originalCamera = workspace.CurrentCamera

	-- Create spectator camera
	spectatorCamera = Instance.new("Camera")
	spectatorCamera.CameraType = Enum.CameraType.Scriptable
	spectatorCamera.Parent = workspace
	workspace.CurrentCamera = spectatorCamera

	-- Get available targets
	SpectatorController.RefreshTargets()

	-- Show UI
	if screenGui then
		screenGui.Enabled = true
	end

	-- Select first target
	if #spectateTargets > 0 then
		SpectatorController.SelectTarget(1)
	end
end

--[[
	Stop spectating
]]
function SpectatorController.StopSpectating()
	if not isSpectating then return end
	isSpectating = false
	isFreeCam = false

	print("[SpectatorController] Stopping spectator mode")

	-- Restore original camera
	if originalCamera then
		workspace.CurrentCamera = originalCamera
	end

	-- Cleanup spectator camera
	if spectatorCamera then
		spectatorCamera:Destroy()
		spectatorCamera = nil
	end

	-- Hide UI
	if screenGui then
		screenGui.Enabled = false
	end

	currentTarget = nil
	spectateTargets = {}
end

--[[
	Refresh available spectate targets
]]
function SpectatorController.RefreshTargets()
	spectateTargets = {}

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			local character = p.Character
			if character then
				local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
				if humanoid and humanoid.Health > 0 then
					table.insert(spectateTargets, p)
				end
			end
		end
	end

	-- Update count display
	if spectatorUI then
		local countLabel = spectatorUI:FindFirstChild("PlayerCount") :: TextLabel?
		if countLabel then
			countLabel.Text = `{currentTargetIndex}/{#spectateTargets}`
		end
	end

	-- Ensure current index is valid
	if currentTargetIndex > #spectateTargets then
		currentTargetIndex = math.max(1, #spectateTargets)
	end

	-- Update current target
	if #spectateTargets > 0 then
		currentTarget = spectateTargets[currentTargetIndex]
	else
		currentTarget = nil
	end

	SpectatorController.UpdateUI()
end

--[[
	Select specific target
]]
function SpectatorController.SelectTarget(index: number)
	if #spectateTargets == 0 then return end

	currentTargetIndex = ((index - 1) % #spectateTargets) + 1
	currentTarget = spectateTargets[currentTargetIndex]
	isFreeCam = false

	SpectatorController.UpdateUI()
end

--[[
	Next target
]]
function SpectatorController.NextTarget()
	SpectatorController.RefreshTargets()
	SpectatorController.SelectTarget(currentTargetIndex + 1)
end

--[[
	Previous target
]]
function SpectatorController.PreviousTarget()
	SpectatorController.RefreshTargets()
	SpectatorController.SelectTarget(currentTargetIndex - 1)
end

--[[
	Toggle free cam
]]
function SpectatorController.ToggleFreeCam()
	isFreeCam = not isFreeCam

	if isFreeCam and spectatorCamera then
		freeCamPosition = spectatorCamera.CFrame.Position
		freeCamRotation = spectatorCamera.CFrame - spectatorCamera.CFrame.Position
	end

	SpectatorController.UpdateUI()
end

--[[
	Update UI
]]
function SpectatorController.UpdateUI()
	if not spectatorUI then return end

	local targetLabel = spectatorUI:FindFirstChild("TargetName") :: TextLabel?
	local countLabel = spectatorUI:FindFirstChild("PlayerCount") :: TextLabel?

	if targetLabel then
		if isFreeCam then
			targetLabel.Text = "Free Camera"
		elseif currentTarget then
			targetLabel.Text = currentTarget.Name
		else
			targetLabel.Text = "No players"
		end
	end

	if countLabel then
		countLabel.Text = `{currentTargetIndex}/{#spectateTargets}`
	end
end

--[[
	Update camera position
]]
function SpectatorController.UpdateCamera(deltaTime: number)
	if not spectatorCamera then return end

	if isFreeCam then
		SpectatorController.UpdateFreeCam(deltaTime)
	else
		SpectatorController.UpdateFollowCam(deltaTime)
	end
end

--[[
	Update follow camera
]]
function SpectatorController.UpdateFollowCam(_deltaTime: number)
	if not currentTarget or not spectatorCamera then return end

	local character = currentTarget.Character
	if not character then
		SpectatorController.RefreshTargets()
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then return end

	local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
	if humanoid and humanoid.Health <= 0 then
		SpectatorController.RefreshTargets()
		return
	end

	-- Calculate target camera position
	local targetPos = rootPart.Position
	local lookVector = rootPart.CFrame.LookVector
	local cameraOffset = Vector3.new(0, CAMERA_HEIGHT, 0) - lookVector * CAMERA_DISTANCE

	local targetCFrame = CFrame.new(targetPos + cameraOffset, targetPos)

	-- Smooth interpolation
	spectatorCamera.CFrame = spectatorCamera.CFrame:Lerp(targetCFrame, CAMERA_SMOOTHNESS)
end

--[[
	Update free camera
]]
function SpectatorController.UpdateFreeCam(deltaTime: number)
	if not spectatorCamera then return end

	-- Get input for movement
	local moveDirection = Vector3.new(0, 0, 0)
	local speed = 50

	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		moveDirection = moveDirection + freeCamRotation.LookVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		moveDirection = moveDirection - freeCamRotation.LookVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		moveDirection = moveDirection - freeCamRotation.RightVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		moveDirection = moveDirection + freeCamRotation.RightVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		moveDirection = moveDirection + Vector3.new(0, 1, 0)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
		moveDirection = moveDirection - Vector3.new(0, 1, 0)
	end

	if moveDirection.Magnitude > 0 then
		moveDirection = moveDirection.Unit
		freeCamPosition = freeCamPosition + moveDirection * speed * deltaTime
	end

	spectatorCamera.CFrame = CFrame.new(freeCamPosition) * freeCamRotation
end

--[[
	Check if currently spectating
]]
function SpectatorController.IsSpectating(): boolean
	return isSpectating
end

--[[
	Get current target
]]
function SpectatorController.GetCurrentTarget(): Player?
	return currentTarget
end

--[[
	Cleanup connections and unbind actions
]]
function SpectatorController.Cleanup()
	-- Disconnect all connections
	for _, conn in ipairs(connections) do
		conn:Disconnect()
	end
	connections = {}

	-- Unbind context actions
	ContextActionService:UnbindAction("SpectatorNextTarget")
	ContextActionService:UnbindAction("SpectatorPrevTarget")
	ContextActionService:UnbindAction("SpectatorFreeCam")

	-- Stop spectating if active
	if isSpectating then
		SpectatorController.StopSpectating()
	end

	print("[SpectatorController] Cleaned up")
end

return SpectatorController
