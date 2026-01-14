--!strict
--[[
	DeploymentManager.lua
	=====================
	Server-side deployment system for match start
	Handles helicopter flight path and player jump validation
]]

local Players = game:GetService("Players")

local Events = require(game.ReplicatedStorage.Shared.Events)
local Constants = require(game.ReplicatedStorage.Shared.Constants)

local DeploymentManager = {}

-- Type definitions
type FlightPath = {
	startPoint: Vector3,
	endPoint: Vector3,
	duration: number,
}

type PlayerDeployState = {
	hasJumped: boolean,
	jumpTime: number?,
	jumpPosition: Vector3?,
	isGliding: boolean,
	landedTime: number?,
}

-- State
local isActive = false
local flightPath: FlightPath? = nil
local deployStartTime = 0
local helicopterPosition = Vector3.zero

local playerStates = {} :: { [number]: PlayerDeployState }

-- Map boundary check (simple box for now)
local MAP_BOUNDS = {
	minX = -2500,
	maxX = 2500,
	minZ = -2500,
	maxZ = 2500,
	minY = 0,
}

-- Glider settings
local GLIDER_BASE_SPEED = 20 -- studs/sec falling
local GLIDER_DIVE_SPEED = 60 -- studs/sec max dive
local GLIDER_GLIDE_RATIO = 2 -- 2 horizontal per 1 vertical
local AUTO_DEPLOY_ALTITUDE = 50 -- Deploy parachute at this height
local MIN_JUMP_ALTITUDE = 100 -- Minimum altitude to jump

--[[
	Check if a position is over land (within map bounds)
]]
local function isOverLand(position: Vector3): boolean
	return position.X >= MAP_BOUNDS.minX
		and position.X <= MAP_BOUNDS.maxX
		and position.Z >= MAP_BOUNDS.minZ
		and position.Z <= MAP_BOUNDS.maxZ
end

--[[
	Get current helicopter position along flight path
]]
function DeploymentManager.GetHelicopterPosition(): Vector3
	if not flightPath or not isActive then
		return Vector3.zero
	end

	local elapsed = tick() - deployStartTime
	local progress = math.clamp(elapsed / flightPath.duration, 0, 1)

	return flightPath.startPoint:Lerp(flightPath.endPoint, progress)
end

--[[
	Get flight progress (0-1)
]]
function DeploymentManager.GetFlightProgress(): number
	if not flightPath or not isActive then
		return 0
	end

	local elapsed = tick() - deployStartTime
	return math.clamp(elapsed / flightPath.duration, 0, 1)
end

--[[
	Start the deployment phase
	@param path Flight path configuration
]]
function DeploymentManager.StartDeployment(path: FlightPath)
	flightPath = path
	deployStartTime = tick()
	isActive = true
	playerStates = {}

	-- Initialize state for all players
	for _, player in ipairs(Players:GetPlayers()) do
		playerStates[player.UserId] = {
			hasJumped = false,
			jumpTime = nil,
			jumpPosition = nil,
			isGliding = false,
			landedTime = nil,
		}
	end

	-- Broadcast flight path
	Events.FireAllClients("GameState", "DeployReady", {
		flightPath = {
			startPoint = path.startPoint,
			endPoint = path.endPoint,
			duration = path.duration,
		},
	})

	print(`[DeploymentManager] Deployment started, flight from {path.startPoint} to {path.endPoint}`)
end

--[[
	Handle player jump request
	@param player The player requesting to jump
	@return Whether the jump was allowed
]]
function DeploymentManager.OnPlayerJump(player: Player): boolean
	if not isActive then
		return false
	end

	local state = playerStates[player.UserId]
	if not state then
		return false
	end

	-- Check if already jumped
	if state.hasJumped then
		return false
	end

	-- Get current helicopter position
	local helicopterPos = DeploymentManager.GetHelicopterPosition()

	-- Check if over land
	if not isOverLand(helicopterPos) then
		-- Notify player they can't jump here
		Events.FireClient(player, "GameState", "JumpDenied", {
			reason = "Not over land",
		})
		return false
	end

	-- Check altitude
	if helicopterPos.Y < MIN_JUMP_ALTITUDE then
		Events.FireClient(player, "GameState", "JumpDenied", {
			reason = "Too low to jump",
		})
		return false
	end

	-- Allow jump
	state.hasJumped = true
	state.jumpTime = tick()
	state.jumpPosition = helicopterPos
	state.isGliding = true

	-- Teleport player to jump position and enable gliding
	local character = player.Character
	if character then
		local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if rootPart then
			rootPart.CFrame = CFrame.new(helicopterPos)
			rootPart.AssemblyLinearVelocity = Vector3.new(0, -GLIDER_BASE_SPEED, 0)
		end

		-- Disable normal movement during glide
		local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
		if humanoid then
			humanoid.WalkSpeed = 0
			humanoid.JumpPower = 0
		end
	end

	-- Notify client to enable glider controls
	Events.FireClient(player, "GameState", "GliderEnabled", {
		position = helicopterPos,
	})

	-- Broadcast to other clients
	Events.FireAllClients("GameState", "PlayerJumpedFromHelicopter", {
		playerId = player.UserId,
		position = helicopterPos,
	})

	print(`[DeploymentManager] {player.Name} jumped at {helicopterPos}`)

	return true
end

--[[
	Handle player landing
	@param player The player who landed
]]
function DeploymentManager.OnPlayerLanded(player: Player)
	local state = playerStates[player.UserId]
	if not state then
		return
	end

	state.isGliding = false
	state.landedTime = tick()

	-- Re-enable normal movement
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
		if humanoid then
			humanoid.WalkSpeed = Constants.PLAYER.WALK_SPEED
			humanoid.JumpPower = 50 -- Default jump power
		end
	end

	-- Notify client
	Events.FireClient(player, "GameState", "GliderDisabled", {})

	print(`[DeploymentManager] {player.Name} landed`)
end

--[[
	Force eject all remaining players
]]
function DeploymentManager.ForceEjectAll()
	if not isActive then
		return
	end

	local helicopterPos = DeploymentManager.GetHelicopterPosition()

	for userId, state in pairs(playerStates) do
		if not state.hasJumped then
			local player = Players:GetPlayerByUserId(userId)
			if player then
				-- Force jump
				state.hasJumped = true
				state.jumpTime = tick()
				state.jumpPosition = helicopterPos
				state.isGliding = true

				-- Teleport and setup glider
				local character = player.Character
				if character then
					local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
					if rootPart then
						rootPart.CFrame = CFrame.new(helicopterPos)
						rootPart.AssemblyLinearVelocity = Vector3.new(0, -GLIDER_BASE_SPEED, 0)
					end
				end

				Events.FireClient(player, "GameState", "GliderEnabled", {
					position = helicopterPos,
					forced = true,
				})

				print(`[DeploymentManager] Force ejected {player.Name}`)
			end
		end
	end
end

--[[
	Validate glider input from client
	@param player The player
	@param input Glider input data
]]
function DeploymentManager.ValidateGliderInput(player: Player, input: { pitch: number, yaw: number })
	local state = playerStates[player.UserId]
	if not state or not state.isGliding then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return
	end

	-- Calculate velocity based on pitch
	local pitch = math.clamp(input.pitch, -1, 1) -- -1 = dive, 0 = glide, 1 = pull up (limited)
	local yaw = math.clamp(input.yaw, -1, 1)

	-- Calculate fall speed based on pitch
	local fallSpeed = GLIDER_BASE_SPEED + (GLIDER_DIVE_SPEED - GLIDER_BASE_SPEED) * math.max(0, -pitch)

	-- Calculate horizontal speed (higher when diving)
	local horizontalSpeed = fallSpeed * GLIDER_GLIDE_RATIO * (1 - pitch * 0.5)

	-- Get current facing direction and apply yaw
	local currentCFrame = rootPart.CFrame
	local lookVector = currentCFrame.LookVector

	-- Apply yaw rotation
	local yawRotation = CFrame.Angles(0, -yaw * 0.05, 0)
	local newLookVector = yawRotation:VectorToWorldSpace(Vector3.new(0, 0, -1))
	newLookVector = (currentCFrame * yawRotation).LookVector

	-- Calculate velocity
	local horizontalVelocity = Vector3.new(newLookVector.X, 0, newLookVector.Z).Unit * horizontalSpeed
	local velocity = Vector3.new(horizontalVelocity.X, -fallSpeed, horizontalVelocity.Z)

	rootPart.AssemblyLinearVelocity = velocity

	-- Check for auto-deploy (low altitude)
	local position = rootPart.Position
	if position.Y <= AUTO_DEPLOY_ALTITUDE then
		DeploymentManager.OnPlayerLanded(player)
	end
end

--[[
	Check if a player has jumped
]]
function DeploymentManager.HasPlayerJumped(player: Player): boolean
	local state = playerStates[player.UserId]
	return state ~= nil and state.hasJumped
end

--[[
	Check if a player is gliding
]]
function DeploymentManager.IsPlayerGliding(player: Player): boolean
	local state = playerStates[player.UserId]
	return state ~= nil and state.isGliding
end

--[[
	Get deployment state for a player
]]
function DeploymentManager.GetPlayerState(player: Player): PlayerDeployState?
	return playerStates[player.UserId]
end

--[[
	Get current flight path
]]
function DeploymentManager.GetFlightPath(): FlightPath?
	return flightPath
end

--[[
	Check if deployment is active
]]
function DeploymentManager.IsActive(): boolean
	return isActive
end

--[[
	End deployment phase
]]
function DeploymentManager.EndDeployment()
	isActive = false

	-- Land any remaining gliding players
	for userId, state in pairs(playerStates) do
		if state.isGliding then
			local player = Players:GetPlayerByUserId(userId)
			if player then
				DeploymentManager.OnPlayerLanded(player)
			end
		end
	end

	print("[DeploymentManager] Deployment ended")
end

--[[
	Reset deployment state
]]
function DeploymentManager.Reset()
	isActive = false
	flightPath = nil
	deployStartTime = 0
	helicopterPosition = Vector3.zero
	playerStates = {}

	print("[DeploymentManager] Reset")
end

--[[
	Handle player removing (cleanup)
]]
function DeploymentManager.OnPlayerRemoving(player: Player)
	playerStates[player.UserId] = nil
end

return DeploymentManager
