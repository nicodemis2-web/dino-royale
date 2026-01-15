--!strict
--[[
	AdminConsole.lua
	================
	Debug/Admin console for testing Dino Royale
	Provides commands for solo testing, skipping phases, etc.

	Commands (type in chat with /):
		/forcestart - Force start match (skip lobby)
		/skip - Skip current phase
		/godmode - Toggle god mode
		/spawn [item] - Spawn item
		/tp [x] [y] [z] - Teleport to position
		/heal - Full heal
		/kill - Kill self (for testing)
		/phase [n] - Set storm phase
		/debug - Toggle debug overlay
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GameConfig = require(game.ReplicatedStorage.Shared.GameConfig)
local Events = require(game.ReplicatedStorage.Shared.Events)

local AdminConsole = {}

-- Reference to GameManager (set via Initialize)
local gameManager: any = nil

-- Track god mode per player
local godModePlayers = {} :: { [number]: boolean }

--[[
	Check if a player is an admin (in Studio, everyone is admin)
]]
local function isAdmin(player: Player): boolean
	-- In Studio, everyone is admin for testing
	if RunService:IsStudio() then
		return true
	end

	-- Check admin list
	if GameConfig.Debug.AdminUserIds then
		for _, userId in ipairs(GameConfig.Debug.AdminUserIds) do
			if player.UserId == userId then
				return true
			end
		end
	end

	return false
end

--[[
	Send feedback message to player
]]
local function sendFeedback(player: Player, message: string)
	-- Fire client event for UI feedback
	Events.FireClient("AdminConsole", "Feedback", player, {
		message = message,
	})
	-- Also print to output for debugging
	print(`[AdminConsole] {player.Name}: {message}`)
end

--[[
	Command: Force start match
]]
local function cmdForceStart(player: Player, _args: { string })
	if not gameManager then
		sendFeedback(player, "GameManager not available")
		return
	end

	local currentState = gameManager.GetCurrentState()
	if currentState == "Lobby" then
		gameManager.TransitionTo("Loading")
		sendFeedback(player, "Force starting match...")
	else
		sendFeedback(player, `Cannot force start from {currentState} state`)
	end
end

--[[
	Command: Skip current phase
]]
local function cmdSkip(player: Player, _args: { string })
	if not gameManager then
		sendFeedback(player, "GameManager not available")
		return
	end

	local currentState = gameManager.GetCurrentState()
	local transitions = {
		Lobby = "Loading",
		Loading = "Deploying",
		Deploying = "Playing",
		Playing = "Ending",
		Ending = "Resetting",
		Resetting = "Lobby",
	}

	local nextState = transitions[currentState]
	if nextState then
		gameManager.TransitionTo(nextState)
		sendFeedback(player, `Skipped to {nextState}`)
	else
		sendFeedback(player, `Cannot skip from {currentState}`)
	end
end

--[[
	Command: Toggle god mode
]]
local function cmdGodMode(player: Player, _args: { string })
	local userId = player.UserId
	godModePlayers[userId] = not godModePlayers[userId]

	local status = godModePlayers[userId] and "ENABLED" or "DISABLED"
	sendFeedback(player, `God mode {status}`)

	-- Apply to character
	local character = player.Character
	if character and godModePlayers[userId] then
		local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
		if humanoid then
			humanoid.MaxHealth = math.huge
			humanoid.Health = math.huge
		end
	end
end

--[[
	Command: Full heal
]]
local function cmdHeal(player: Player, _args: { string })
	local character = player.Character
	if not character then
		sendFeedback(player, "No character")
		return
	end

	local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
	if humanoid then
		humanoid.Health = humanoid.MaxHealth
		sendFeedback(player, "Fully healed")
	end
end

--[[
	Command: Teleport
]]
local function cmdTeleport(player: Player, args: { string })
	local character = player.Character
	if not character then
		sendFeedback(player, "No character")
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		sendFeedback(player, "No HumanoidRootPart")
		return
	end

	local x = tonumber(args[1]) or 0
	local y = tonumber(args[2]) or 100
	local z = tonumber(args[3]) or 0

	rootPart.CFrame = CFrame.new(x, y, z)
	sendFeedback(player, `Teleported to ({x}, {y}, {z})`)
end

--[[
	Command: Kill self (for testing respawn)
]]
local function cmdKill(player: Player, _args: { string })
	local character = player.Character
	if not character then
		sendFeedback(player, "No character")
		return
	end

	local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
	if humanoid then
		humanoid.Health = 0
		sendFeedback(player, "Killed self")
	end
end

--[[
	Command: Set storm phase
]]
local function cmdPhase(player: Player, args: { string })
	local phase = tonumber(args[1])
	if not phase then
		sendFeedback(player, "Usage: /phase [number]")
		return
	end

	-- This would need StormManager reference
	sendFeedback(player, `Set storm phase to {phase} (not yet implemented)`)
end

--[[
	Command: Toggle debug overlay
]]
local function cmdDebug(player: Player, _args: { string })
	GameConfig.Debug.ShowHitboxes = not GameConfig.Debug.ShowHitboxes
	local status = GameConfig.Debug.ShowHitboxes and "ENABLED" or "DISABLED"
	sendFeedback(player, `Debug overlay {status}`)
end

--[[
	Command: Quick jump (teleport to glide position)
]]
local function cmdJump(player: Player, _args: { string })
	local character = player.Character
	if not character then
		sendFeedback(player, "No character")
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		sendFeedback(player, "No HumanoidRootPart")
		return
	end

	-- Teleport to deployment altitude
	local currentPos = rootPart.Position
	rootPart.CFrame = CFrame.new(currentPos.X, 500, currentPos.Z)
	rootPart.AssemblyLinearVelocity = Vector3.new(0, -20, 0)
	sendFeedback(player, "Teleported to jump altitude (500)")
end

--[[
	Command: Show help
]]
local function cmdHelp(player: Player, _args: { string })
	local helpText = [[
Admin Commands:
/forcestart - Force start match
/skip - Skip current phase
/godmode - Toggle invincibility
/heal - Full heal
/tp X Y Z - Teleport to position
/jump - Teleport to jump altitude
/kill - Kill self
/phase N - Set storm phase
/debug - Toggle debug overlay
/help - Show this help
]]
	sendFeedback(player, helpText)
end

-- Command registry
local commands = {
	forcestart = cmdForceStart,
	skip = cmdSkip,
	godmode = cmdGodMode,
	heal = cmdHeal,
	tp = cmdTeleport,
	teleport = cmdTeleport,
	kill = cmdKill,
	phase = cmdPhase,
	debug = cmdDebug,
	jump = cmdJump,
	help = cmdHelp,
}

--[[
	Process a chat command
]]
local function processCommand(player: Player, message: string)
	if string.sub(message, 1, 1) ~= "/" then
		return
	end

	if not isAdmin(player) then
		return
	end

	-- Parse command and args
	local parts = string.split(string.sub(message, 2), " ")
	local commandName = string.lower(parts[1] or "")
	local args = {}
	for i = 2, #parts do
		table.insert(args, parts[i])
	end

	-- Execute command
	local commandFunc = commands[commandName]
	if commandFunc then
		commandFunc(player, args)
	else
		sendFeedback(player, `Unknown command: {commandName}. Type /help for commands.`)
	end
end

--[[
	Check if player has god mode enabled
]]
function AdminConsole.HasGodMode(player: Player): boolean
	return godModePlayers[player.UserId] == true
end

--[[
	Execute a command programmatically
]]
function AdminConsole.ExecuteCommand(player: Player, command: string, args: { string }?)
	if not isAdmin(player) then
		return false
	end

	local commandFunc = commands[string.lower(command)]
	if commandFunc then
		commandFunc(player, args or {})
		return true
	end
	return false
end

--[[
	Set GameManager reference
]]
function AdminConsole.SetGameManager(manager: any)
	gameManager = manager
end

--[[
	Initialize admin console
]]
function AdminConsole.Initialize()
	if not GameConfig.Debug.Enabled then
		print("[AdminConsole] Debug mode disabled, admin console inactive")
		return
	end

	-- Listen for chat messages
	Players.PlayerAdded:Connect(function(player)
		player.Chatted:Connect(function(message)
			if string.sub(message, 1, 1) == "/" then
				processCommand(player, message)
			end
		end)
	end)

	-- Handle existing players
	for _, player in ipairs(Players:GetPlayers()) do
		player.Chatted:Connect(function(message)
			if string.sub(message, 1, 1) == "/" then
				processCommand(player, message)
			end
		end)
	end

	-- Listen for admin command events from client
	Events.OnServerEvent("AdminConsole", "ExecuteCommand", function(player, data)
		if isAdmin(player) and data.command then
			AdminConsole.ExecuteCommand(player, data.command, data.args)
		end
	end)

	print("[AdminConsole] Initialized - type /help in chat for commands")
end

--[[
	Cleanup
]]
function AdminConsole.Cleanup()
	godModePlayers = {}
end

return AdminConsole
