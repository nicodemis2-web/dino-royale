--!strict
--[[
	MovementValidator.lua
	=====================
	Server-side anti-cheat for movement
	Detects speed hacks, teleportation, and fly hacks
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Constants = require(game.ReplicatedStorage.Shared.Constants)
local PlayerState = require(game.ReplicatedStorage.Shared.Player.PlayerState)

local MovementValidator = {}

--[[
	Configuration
]]
local Config = {
	POSITION_TOLERANCE = 5, -- studs of acceptable deviation
	SPEED_TOLERANCE = 1.2, -- 20% over max allowed speed
	TELEPORT_THRESHOLD = 50, -- studs (instant jump detection)
	VIOLATION_THRESHOLD = 10, -- violations before flagging
	AIR_TIME_THRESHOLD = 3, -- seconds in air before fly check
	CHECK_INTERVAL = 0.1, -- seconds between full checks
	NETWORK_LATENCY_BUFFER = 0.2, -- extra time allowance for network latency
}

--[[
	Types
]]
export type ValidationState = {
	lastPosition: Vector3,
	lastCheckTime: number,
	lastGroundTime: number,
	expectedMovementState: PlayerState.MovementState,
	violationCount: number,
	isFlagged: boolean,
	violations: { ViolationRecord },
}

export type ViolationRecord = {
	type: string,
	timestamp: number,
	details: string,
	severity: "Minor" | "Major",
}

export type ValidationResult = {
	isValid: boolean,
	violation: string?,
	severity: ("Minor" | "Major")?,
	correctedPosition: Vector3?,
}

-- Player validation states
local playerStates = {} :: { [number]: ValidationState }

-- Callbacks for external handling
local onViolationCallback: ((Player, ViolationRecord) -> ())?
local onFlaggedCallback: ((Player) -> ())?

--[[
	Initialize validation tracking for a player
	@param player The player to track
]]
function MovementValidator.Initialize(player: Player)
	local userId = player.UserId
	local character = player.Character
	local initialPosition = Vector3.zero

	if character then
		local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if rootPart then
			initialPosition = rootPart.Position
		end
	end

	playerStates[userId] = {
		lastPosition = initialPosition,
		lastCheckTime = tick(),
		lastGroundTime = tick(),
		expectedMovementState = "Idle",
		violationCount = 0,
		isFlagged = false,
		violations = {},
	}

	-- Handle character changes
	player.CharacterAdded:Connect(function(newCharacter)
		local state = playerStates[userId]
		if state then
			local rootPart = newCharacter:WaitForChild("HumanoidRootPart") :: BasePart
			state.lastPosition = rootPart.Position
			state.lastCheckTime = tick()
			state.lastGroundTime = tick()
		end
	end)

	-- Cleanup on player leaving
	player.AncestryChanged:Connect(function(_, parent)
		if not parent then
			playerStates[userId] = nil
		end
	end)
end

--[[
	Validate a player's current position
	@param player The player to validate
	@return ValidationResult
]]
function MovementValidator.ValidatePosition(player: Player): ValidationResult
	local userId = player.UserId
	local state = playerStates[userId]

	if not state then
		return { isValid = true }
	end

	local character = player.Character
	if not character then
		return { isValid = true }
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return { isValid = true }
	end

	local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
	if not humanoid or humanoid.Health <= 0 then
		return { isValid = true }
	end

	local currentPosition = rootPart.Position
	local currentTime = tick()
	local deltaTime = currentTime - state.lastCheckTime

	-- Skip if not enough time has passed
	if deltaTime < Config.CHECK_INTERVAL then
		return { isValid = true }
	end

	-- Calculate distance moved
	local distance = (currentPosition - state.lastPosition).Magnitude

	-- Check for teleportation
	local teleportResult = MovementValidator.CheckTeleport(state, currentPosition, distance)
	if not teleportResult.isValid then
		MovementValidator.RecordViolation(player, state, teleportResult)
		state.lastPosition = currentPosition
		state.lastCheckTime = currentTime
		return teleportResult
	end

	-- Check for speed hacks
	local speedResult = MovementValidator.CheckSpeed(state, currentPosition, distance, deltaTime, humanoid)
	if not speedResult.isValid then
		MovementValidator.RecordViolation(player, state, speedResult)
		state.lastPosition = currentPosition
		state.lastCheckTime = currentTime
		return speedResult
	end

	-- Check for fly hacks
	local flyResult = MovementValidator.CheckFly(state, rootPart, humanoid, currentTime)
	if not flyResult.isValid then
		MovementValidator.RecordViolation(player, state, flyResult)
	end

	-- Update state
	state.lastPosition = currentPosition
	state.lastCheckTime = currentTime

	-- Update ground time if on ground
	local floorMaterial = humanoid.FloorMaterial
	if floorMaterial ~= Enum.Material.Air then
		state.lastGroundTime = currentTime
	end

	return { isValid = true }
end

--[[
	Check for teleportation (instant position jumps)
]]
function MovementValidator.CheckTeleport(
	state: ValidationState,
	currentPosition: Vector3,
	distance: number
): ValidationResult
	if distance > Config.TELEPORT_THRESHOLD then
		return {
			isValid = false,
			violation = "Teleport",
			severity = "Major",
			correctedPosition = state.lastPosition,
		}
	end
	return { isValid = true }
end

--[[
	Check for speed hacks (moving faster than allowed)
]]
function MovementValidator.CheckSpeed(
	state: ValidationState,
	currentPosition: Vector3,
	distance: number,
	deltaTime: number,
	humanoid: Humanoid
): ValidationResult
	-- Calculate expected max speed based on movement state
	local maxSpeed = MovementValidator.GetMaxSpeedForState(humanoid)

	-- Add tolerance and latency buffer
	local allowedDistance = maxSpeed * (deltaTime + Config.NETWORK_LATENCY_BUFFER) * Config.SPEED_TOLERANCE

	-- Add position tolerance
	allowedDistance = allowedDistance + Config.POSITION_TOLERANCE

	if distance > allowedDistance then
		local actualSpeed = distance / deltaTime
		return {
			isValid = false,
			violation = "SpeedHack",
			severity = "Minor",
			correctedPosition = state.lastPosition + (currentPosition - state.lastPosition).Unit * allowedDistance,
		}
	end

	return { isValid = true }
end

--[[
	Check for fly hacks (sustained air time without ground contact)
]]
function MovementValidator.CheckFly(
	state: ValidationState,
	rootPart: BasePart,
	humanoid: Humanoid,
	currentTime: number
): ValidationResult
	local floorMaterial = humanoid.FloorMaterial
	local isInAir = floorMaterial == Enum.Material.Air

	if isInAir then
		local airTime = currentTime - state.lastGroundTime

		-- Check if they've been in the air too long
		if airTime > Config.AIR_TIME_THRESHOLD then
			-- Additional check: raycast down to see if they should be on ground
			local raycastParams = RaycastParams.new()
			raycastParams.FilterType = Enum.RaycastFilterType.Exclude
			raycastParams.FilterDescendantsInstances = { rootPart.Parent }

			local rayResult = workspace:Raycast(rootPart.Position, Vector3.new(0, -100, 0), raycastParams)

			-- If ground is within reasonable distance but they're not touching it
			if rayResult and (rootPart.Position.Y - rayResult.Position.Y) < 5 then
				-- They should be on the ground - suspicious
				return {
					isValid = false,
					violation = "FlyHack",
					severity = "Major",
				}
			end

			-- If no ground below at all, they might be falling legitimately
			-- Only flag if they're maintaining altitude
			local velocity = rootPart.AssemblyLinearVelocity
			if math.abs(velocity.Y) < 1 and airTime > Config.AIR_TIME_THRESHOLD * 2 then
				return {
					isValid = false,
					violation = "FlyHack",
					severity = "Major",
				}
			end
		end
	end

	return { isValid = true }
end

--[[
	Get the maximum allowed speed for current humanoid state
]]
function MovementValidator.GetMaxSpeedForState(humanoid: Humanoid): number
	-- Use the humanoid's current walk speed as the base
	local walkSpeed = humanoid.WalkSpeed

	-- Account for jumping/falling (can move faster due to momentum)
	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
		walkSpeed = walkSpeed * 1.5
	end

	-- Account for swimming
	if state == Enum.HumanoidStateType.Swimming then
		walkSpeed = Constants.PLAYER.WALK_SPEED * 0.8
	end

	return walkSpeed
end

--[[
	Record a violation and handle consequences
]]
function MovementValidator.RecordViolation(player: Player, state: ValidationState, result: ValidationResult)
	local violation: ViolationRecord = {
		type = result.violation or "Unknown",
		timestamp = tick(),
		details = `Position deviation detected`,
		severity = result.severity or "Minor",
	}

	table.insert(state.violations, violation)

	-- Increment violation count
	if result.severity == "Major" then
		state.violationCount = state.violationCount + 3
	else
		state.violationCount = state.violationCount + 1
	end

	-- Fire callback
	if onViolationCallback then
		onViolationCallback(player, violation)
	end

	-- Check if player should be flagged
	if state.violationCount >= Config.VIOLATION_THRESHOLD and not state.isFlagged then
		state.isFlagged = true
		if onFlaggedCallback then
			onFlaggedCallback(player)
		end
		warn(`[MovementValidator] Player {player.Name} flagged for review. Violations: {state.violationCount}`)
	end

	-- Log violation (don't spam)
	if #state.violations % 5 == 1 then
		warn(
			`[MovementValidator] {result.violation} detected for {player.Name}. Count: {state.violationCount}/{Config.VIOLATION_THRESHOLD}`
		)
	end
end

--[[
	Correct a player's position (teleport them to valid position)
	@param player The player to correct
	@param position The position to teleport to
]]
function MovementValidator.CorrectPosition(player: Player, position: Vector3)
	local character = player.Character
	if not character then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if rootPart then
		rootPart.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, 0)
	end
end

--[[
	Update function - validates all players periodically
	Should be called from main game loop
	@param dt Delta time
]]
function MovementValidator.Update(dt: number)
	for _, player in ipairs(Players:GetPlayers()) do
		local result = MovementValidator.ValidatePosition(player)

		-- Apply correction if needed (be careful - false positives are bad)
		if not result.isValid and result.correctedPosition and result.severity == "Major" then
			MovementValidator.CorrectPosition(player, result.correctedPosition)
		end
	end
end

--[[
	Set callback for when a violation is detected
	@param callback The callback function
]]
function MovementValidator.SetViolationCallback(callback: (Player, ViolationRecord) -> ())
	onViolationCallback = callback
end

--[[
	Set callback for when a player is flagged
	@param callback The callback function
]]
function MovementValidator.SetFlaggedCallback(callback: (Player) -> ())
	onFlaggedCallback = callback
end

--[[
	Get validation state for a player
	@param player The player to get state for
	@return The validation state or nil
]]
function MovementValidator.GetState(player: Player): ValidationState?
	return playerStates[player.UserId]
end

--[[
	Check if a player is flagged
	@param player The player to check
	@return Whether the player is flagged
]]
function MovementValidator.IsFlagged(player: Player): boolean
	local state = playerStates[player.UserId]
	return state and state.isFlagged or false
end

--[[
	Reset violations for a player (admin action)
	@param player The player to reset
]]
function MovementValidator.ResetViolations(player: Player)
	local state = playerStates[player.UserId]
	if state then
		state.violationCount = 0
		state.isFlagged = false
		state.violations = {}
	end
end

--[[
	Update expected movement state for a player
	@param player The player
	@param newState The new expected movement state
]]
function MovementValidator.SetExpectedState(player: Player, newState: PlayerState.MovementState)
	local state = playerStates[player.UserId]
	if state then
		state.expectedMovementState = newState
	end
end

return MovementValidator
