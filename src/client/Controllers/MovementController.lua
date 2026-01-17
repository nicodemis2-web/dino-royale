--!strict
--[[
	MovementController.lua
	======================
	Client-side movement input handling with server validation awareness
	Handles WASD movement, sprint, crouch, prone, and stamina
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Constants = require(game.ReplicatedStorage.Shared.Constants)
local PlayerState = require(game.ReplicatedStorage.Shared.Player.PlayerState)

local MovementController = {}

-- Local player reference
local localPlayer = Players.LocalPlayer

-- State
local currentState: PlayerState.MovementState = "Idle"
local stamina = Constants.PLAYER.MAX_STAMINA
local isEnabled = true

-- Input state
local moveDirection = Vector3.zero
local isSprintHeld = false
local isCrouchHeld = false
local isProneHeld = false

-- Connections
local connections = {} :: { RBXScriptConnection }

-- Camera settings
local DEFAULT_FOV = 70
local SPRINT_FOV = 80
local _ADS_FOV = 50
local FOV_LERP_SPEED = 10

--[[
	Initialize the movement controller
]]
function MovementController.Initialize()
	-- Bind actions
	MovementController.BindActions()

	-- Start update loop
	local heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
		if isEnabled then
			MovementController.Update(dt)
		end
	end)
	table.insert(connections, heartbeatConnection)

	-- Handle character respawn
	local characterAddedConnection = localPlayer.CharacterAdded:Connect(function(character)
		MovementController.OnCharacterAdded(character)
	end)
	table.insert(connections, characterAddedConnection)

	-- Initialize with current character if exists
	if localPlayer.Character then
		MovementController.OnCharacterAdded(localPlayer.Character)
	end
end

--[[
	Bind input actions
]]
function MovementController.BindActions()
	-- Sprint (LeftShift / Left Bumper)
	ContextActionService:BindAction("Sprint", function(_, inputState)
		isSprintHeld = inputState == Enum.UserInputState.Begin
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL1)

	-- Crouch (LeftControl / B Button)
	ContextActionService:BindAction("Crouch", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			isCrouchHeld = not isCrouchHeld
			if isCrouchHeld then
				isProneHeld = false
			end
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.LeftControl, Enum.KeyCode.C, Enum.KeyCode.ButtonB)

	-- Prone (Z / Right Stick Click)
	ContextActionService:BindAction("Prone", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			isProneHeld = not isProneHeld
			if isProneHeld then
				isCrouchHeld = false
			end
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.Z, Enum.KeyCode.ButtonR3)

	-- Jump (Space / A Button) - handled through Humanoid
	ContextActionService:BindAction("Jump", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			MovementController.TryJump()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
end

--[[
	Handle character spawn
	@param character The new character
]]
function MovementController.OnCharacterAdded(character: Model)
	-- Reset state
	currentState = "Idle"
	stamina = Constants.PLAYER.MAX_STAMINA
	isCrouchHeld = false
	isProneHeld = false

	-- Wait for humanoid
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid

	-- Set initial walk speed
	humanoid.WalkSpeed = Constants.PLAYER.WALK_SPEED

	-- Disable auto-jump
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
end

--[[
	Update movement every frame
	@param dt Delta time
]]
function MovementController.Update(dt: number)
	local character = localPlayer.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	-- Get movement input direction
	moveDirection = MovementController.GetMoveDirection()

	-- Determine movement state
	local newState = MovementController.DetermineState(humanoid)

	-- Update stamina
	MovementController.UpdateStamina(dt, newState)

	-- Apply movement state
	MovementController.ApplyState(humanoid, newState)

	-- Update camera FOV
	MovementController.UpdateCamera(dt)

	currentState = newState
end

--[[
	Get the current movement input direction
	@return Normalized movement direction in world space
]]
function MovementController.GetMoveDirection(): Vector3
	local camera = workspace.CurrentCamera
	if not camera then
		return Vector3.zero
	end

	-- Get input from keyboard
	local moveVector = Vector3.zero

	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		moveVector = moveVector + Vector3.new(0, 0, -1)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		moveVector = moveVector + Vector3.new(0, 0, 1)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		moveVector = moveVector + Vector3.new(-1, 0, 0)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		moveVector = moveVector + Vector3.new(1, 0, 0)
	end

	-- Get gamepad thumbstick input
	local gamepadState = UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
	for _, input in ipairs(gamepadState) do
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then
			moveVector = moveVector + Vector3.new(input.Position.X, 0, -input.Position.Y)
		end
	end

	-- Normalize
	if moveVector.Magnitude > 0 then
		moveVector = moveVector.Unit
	end

	-- Convert to world space relative to camera
	local cameraCFrame = camera.CFrame
	local cameraYaw = math.atan2(-cameraCFrame.LookVector.X, -cameraCFrame.LookVector.Z)
	local rotation = CFrame.Angles(0, cameraYaw, 0)

	return (rotation * CFrame.new(moveVector)).Position
end

--[[
	Determine the current movement state
	@param humanoid The player's humanoid
	@return The appropriate movement state
]]
function MovementController.DetermineState(_humanoid: Humanoid): PlayerState.MovementState
	local isMoving = moveDirection.Magnitude > 0.1

	-- Check for prone
	if isProneHeld then
		return "Prone"
	end

	-- Check for crouch
	if isCrouchHeld then
		return "Crouching"
	end

	-- Check for sprint (requires stamina and movement)
	if isSprintHeld and isMoving and stamina >= 10 then
		return "Sprinting"
	end

	-- Walking or idle
	if isMoving then
		return "Walking"
	end

	return "Idle"
end

--[[
	Update stamina based on current state
	@param dt Delta time
	@param state Current movement state
]]
function MovementController.UpdateStamina(dt: number, state: PlayerState.MovementState)
	if state == "Sprinting" then
		-- Drain stamina while sprinting
		stamina = math.max(0, stamina - Constants.PLAYER.STAMINA_SPRINT_COST * dt)
	else
		-- Regenerate stamina when not sprinting
		stamina = math.min(Constants.PLAYER.MAX_STAMINA, stamina + Constants.PLAYER.STAMINA_REGEN * dt)
	end
end

--[[
	Apply the movement state to the humanoid
	@param humanoid The player's humanoid
	@param state The state to apply
]]
function MovementController.ApplyState(humanoid: Humanoid, state: PlayerState.MovementState)
	-- Get target speed
	local targetSpeed = PlayerState.getSpeedForState(state)
	humanoid.WalkSpeed = targetSpeed

	-- Handle crouch/prone hitbox (simplified - just camera offset)
	local character = humanoid.Parent :: Model?
	if character then
		local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if rootPart then
			-- Adjust hip height for visual crouch (full implementation would use Motor6D)
			if state == "Prone" then
				humanoid.HipHeight = 0.5
			elseif state == "Crouching" then
				humanoid.HipHeight = 1.0
			else
				humanoid.HipHeight = 2.0
			end
		end
	end
end

--[[
	Attempt to jump
]]
function MovementController.TryJump()
	local character = localPlayer.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
	if not humanoid then
		return
	end

	-- Can't jump while crouching or prone
	if isCrouchHeld or isProneHeld then
		isCrouchHeld = false
		isProneHeld = false
		return
	end

	-- Check stamina
	if stamina < Constants.PLAYER.STAMINA_JUMP_COST then
		return
	end

	-- Deduct stamina
	stamina = stamina - Constants.PLAYER.STAMINA_JUMP_COST

	-- Perform jump
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
end

--[[
	Update camera FOV based on state
	@param dt Delta time
]]
function MovementController.UpdateCamera(dt: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local targetFOV = DEFAULT_FOV

	if currentState == "Sprinting" then
		targetFOV = SPRINT_FOV
	end

	-- Smooth lerp to target FOV
	local currentFOV = camera.FieldOfView
	local newFOV = currentFOV + (targetFOV - currentFOV) * math.min(1, FOV_LERP_SPEED * dt)
	camera.FieldOfView = newFOV
end

--[[
	Get current stamina
	@return Current stamina value
]]
function MovementController.GetStamina(): number
	return stamina
end

--[[
	Get current movement state
	@return Current movement state
]]
function MovementController.GetState(): PlayerState.MovementState
	return currentState
end

--[[
	Enable or disable movement control
	@param enabled Whether to enable
]]
function MovementController.SetEnabled(enabled: boolean)
	isEnabled = enabled

	if not enabled then
		moveDirection = Vector3.zero
		isSprintHeld = false
	end
end

-- Convenience aliases
function MovementController.Enable()
	MovementController.SetEnabled(true)
end

function MovementController.Disable()
	MovementController.SetEnabled(false)
end

--[[
	Force a specific state (for external control like vehicles)
	@param state The state to force
]]
function MovementController.ForceState(state: PlayerState.MovementState)
	currentState = state
	isCrouchHeld = state == "Crouching"
	isProneHeld = state == "Prone"
end

--[[
	Cleanup the controller
]]
function MovementController.Cleanup()
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	connections = {}

	ContextActionService:UnbindAction("Sprint")
	ContextActionService:UnbindAction("Crouch")
	ContextActionService:UnbindAction("Prone")
	ContextActionService:UnbindAction("Jump")
end

return MovementController
