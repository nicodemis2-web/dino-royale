--!strict
--[[
	PlayerState.lua
	===============
	Defines and manages player state shared between client and server
	Server owns the state, client predicts/displays it
]]

local Constants = require(script.Parent.Parent.Constants)

local PlayerState = {}

--[[
	Movement state enum
]]
export type MovementState = "Idle" | "Walking" | "Sprinting" | "Crouching" | "Prone" | "Swimming" | "Gliding" | "Downed"

--[[
	Complete player state structure
]]
export type PlayerStateData = {
	-- Health/combat
	health: number,
	shield: number,
	stamina: number,
	isAlive: boolean,
	isDowned: boolean,
	downedTime: number?,

	-- Movement
	movementState: MovementState,
	position: Vector3,
	rotation: Vector3,
	velocity: Vector3,

	-- Meta
	lastUpdateTime: number,
}

--[[
	Serialized state for network transmission
	Uses a compact buffer format
]]
export type SerializedState = buffer

-- Movement state to byte mapping for serialization
local MOVEMENT_STATE_MAP = {
	Idle = 0,
	Walking = 1,
	Sprinting = 2,
	Crouching = 3,
	Prone = 4,
	Swimming = 5,
	Gliding = 6,
	Downed = 7,
}

local MOVEMENT_STATE_REVERSE = {
	[0] = "Idle",
	[1] = "Walking",
	[2] = "Sprinting",
	[3] = "Crouching",
	[4] = "Prone",
	[5] = "Swimming",
	[6] = "Gliding",
	[7] = "Downed",
}

--[[
	Create a new PlayerState for a player
	@param player The player to create state for
	@return The new PlayerStateData
]]
function PlayerState.new(player: Player): PlayerStateData
	local character = player.Character
	local position = Vector3.zero
	local rotation = Vector3.zero

	if character then
		local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if rootPart then
			position = rootPart.Position
			local lookVector = rootPart.CFrame.LookVector
			rotation = Vector3.new(0, math.atan2(lookVector.X, lookVector.Z), 0)
		end
	end

	return {
		health = Constants.PLAYER.MAX_HEALTH,
		shield = 0,
		stamina = Constants.PLAYER.MAX_STAMINA,
		isAlive = true,
		isDowned = false,
		downedTime = nil,

		movementState = "Idle" :: MovementState,
		position = position,
		rotation = rotation,
		velocity = Vector3.zero,

		lastUpdateTime = tick(),
	}
end

--[[
	Create default state (for initialization before player has character)
	@return Default PlayerStateData
]]
function PlayerState.default(): PlayerStateData
	return {
		health = Constants.PLAYER.MAX_HEALTH,
		shield = 0,
		stamina = Constants.PLAYER.MAX_STAMINA,
		isAlive = true,
		isDowned = false,
		downedTime = nil,

		movementState = "Idle" :: MovementState,
		position = Vector3.zero,
		rotation = Vector3.zero,
		velocity = Vector3.zero,

		lastUpdateTime = tick(),
	}
end

--[[
	Serialize player state to a compact buffer for network transmission
	Buffer format (50 bytes total):
	- health: f32 (4 bytes)
	- shield: f32 (4 bytes)
	- stamina: f32 (4 bytes)
	- flags: u8 (1 byte) - isAlive, isDowned, movementState
	- position: 3x f32 (12 bytes)
	- rotation: 3x f32 (12 bytes)
	- velocity: 3x f32 (12 bytes)
	- timestamp: f64 (8 bytes) - removed to keep it simpler

	@param state The state to serialize
	@return Serialized buffer
]]
function PlayerState.serialize(state: PlayerStateData): buffer
	local buf = buffer.create(49)
	local offset = 0

	-- Health, shield, stamina
	buffer.writef32(buf, offset, state.health)
	offset += 4
	buffer.writef32(buf, offset, state.shield)
	offset += 4
	buffer.writef32(buf, offset, state.stamina)
	offset += 4

	-- Flags byte: bits 0-2 = movementState, bit 3 = isAlive, bit 4 = isDowned
	local movementByte = MOVEMENT_STATE_MAP[state.movementState] or 0
	local flags = movementByte
	if state.isAlive then
		flags = bit32.bor(flags, 0x08)
	end
	if state.isDowned then
		flags = bit32.bor(flags, 0x10)
	end
	buffer.writeu8(buf, offset, flags)
	offset += 1

	-- Position
	buffer.writef32(buf, offset, state.position.X)
	offset += 4
	buffer.writef32(buf, offset, state.position.Y)
	offset += 4
	buffer.writef32(buf, offset, state.position.Z)
	offset += 4

	-- Rotation
	buffer.writef32(buf, offset, state.rotation.X)
	offset += 4
	buffer.writef32(buf, offset, state.rotation.Y)
	offset += 4
	buffer.writef32(buf, offset, state.rotation.Z)
	offset += 4

	-- Velocity
	buffer.writef32(buf, offset, state.velocity.X)
	offset += 4
	buffer.writef32(buf, offset, state.velocity.Y)
	offset += 4
	buffer.writef32(buf, offset, state.velocity.Z)
	offset += 4

	return buf
end

--[[
	Deserialize player state from a buffer
	@param buf The buffer to deserialize
	@return The deserialized PlayerStateData
]]
function PlayerState.deserialize(buf: buffer): PlayerStateData
	local offset = 0

	-- Health, shield, stamina
	local health = buffer.readf32(buf, offset)
	offset += 4
	local shield = buffer.readf32(buf, offset)
	offset += 4
	local stamina = buffer.readf32(buf, offset)
	offset += 4

	-- Flags
	local flags = buffer.readu8(buf, offset)
	offset += 1
	local movementIndex = bit32.band(flags, 0x07)
	local isAlive = bit32.band(flags, 0x08) ~= 0
	local isDowned = bit32.band(flags, 0x10) ~= 0
	local movementState = MOVEMENT_STATE_REVERSE[movementIndex] or "Idle"

	-- Position
	local posX = buffer.readf32(buf, offset)
	offset += 4
	local posY = buffer.readf32(buf, offset)
	offset += 4
	local posZ = buffer.readf32(buf, offset)
	offset += 4

	-- Rotation
	local rotX = buffer.readf32(buf, offset)
	offset += 4
	local rotY = buffer.readf32(buf, offset)
	offset += 4
	local rotZ = buffer.readf32(buf, offset)
	offset += 4

	-- Velocity
	local velX = buffer.readf32(buf, offset)
	offset += 4
	local velY = buffer.readf32(buf, offset)
	offset += 4
	local velZ = buffer.readf32(buf, offset)
	offset += 4

	return {
		health = health,
		shield = shield,
		stamina = stamina,
		isAlive = isAlive,
		isDowned = isDowned,
		downedTime = nil,

		movementState = movementState :: MovementState,
		position = Vector3.new(posX, posY, posZ),
		rotation = Vector3.new(rotX, rotY, rotZ),
		velocity = Vector3.new(velX, velY, velZ),

		lastUpdateTime = tick(),
	}
end

--[[
	Interpolate between two player states for smooth rendering
	@param from Starting state
	@param to Target state
	@param alpha Interpolation factor (0-1)
	@return Interpolated state
]]
function PlayerState.interpolate(from: PlayerStateData, to: PlayerStateData, alpha: number): PlayerStateData
	-- Clamp alpha
	alpha = math.clamp(alpha, 0, 1)

	-- Lerp numeric values
	local health = from.health + (to.health - from.health) * alpha
	local shield = from.shield + (to.shield - from.shield) * alpha
	local stamina = from.stamina + (to.stamina - from.stamina) * alpha

	-- Lerp vectors
	local position = from.position:Lerp(to.position, alpha)
	local velocity = from.velocity:Lerp(to.velocity, alpha)

	-- Slerp rotation (simplified - just lerp Y rotation for now)
	local rotation = from.rotation:Lerp(to.rotation, alpha)

	-- Use target state for discrete values
	return {
		health = health,
		shield = shield,
		stamina = stamina,
		isAlive = to.isAlive,
		isDowned = to.isDowned,
		downedTime = to.downedTime,

		movementState = to.movementState,
		position = position,
		rotation = rotation,
		velocity = velocity,

		lastUpdateTime = to.lastUpdateTime,
	}
end

--[[
	Get the movement speed for a given movement state
	@param state The movement state
	@return Speed in studs per second
]]
function PlayerState.getSpeedForState(state: MovementState): number
	if state == "Idle" then
		return 0
	elseif state == "Walking" then
		return Constants.PLAYER.WALK_SPEED
	elseif state == "Sprinting" then
		return Constants.PLAYER.SPRINT_SPEED
	elseif state == "Crouching" then
		return Constants.PLAYER.CROUCH_SPEED
	elseif state == "Prone" then
		return Constants.PLAYER.PRONE_SPEED
	elseif state == "Downed" then
		return Constants.PLAYER.PRONE_SPEED * 0.5
	elseif state == "Swimming" then
		return Constants.PLAYER.WALK_SPEED * 0.8
	elseif state == "Gliding" then
		return Constants.PLAYER.SPRINT_SPEED * 2
	end
	return Constants.PLAYER.WALK_SPEED
end

--[[
	Check if player can sprint based on current state
	@param state The current player state
	@return Whether sprinting is allowed
]]
function PlayerState.canSprint(state: PlayerStateData): boolean
	if not state.isAlive then
		return false
	end
	if state.isDowned then
		return false
	end
	if state.stamina < 10 then
		return false
	end
	if state.movementState == "Swimming" or state.movementState == "Gliding" then
		return false
	end
	return true
end

--[[
	Clone a player state
	@param state The state to clone
	@return A copy of the state
]]
function PlayerState.clone(state: PlayerStateData): PlayerStateData
	return {
		health = state.health,
		shield = state.shield,
		stamina = state.stamina,
		isAlive = state.isAlive,
		isDowned = state.isDowned,
		downedTime = state.downedTime,

		movementState = state.movementState,
		position = state.position,
		rotation = state.rotation,
		velocity = state.velocity,

		lastUpdateTime = state.lastUpdateTime,
	}
end

return PlayerState
