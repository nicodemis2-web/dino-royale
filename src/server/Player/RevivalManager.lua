--!strict
--[[
	RevivalManager.lua
	==================
	Handles player downed state and teammate revival
	Based on GDD Section 4.5: Team Modes
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Events = require(ReplicatedStorage.Shared.Events)
local TeamData = require(ReplicatedStorage.Shared.TeamData)

local RevivalManager = {}

-- Types
export type DownedPlayer = {
	player: Player,
	teamId: string,
	downedTime: number,
	bleedOutTime: number,
	position: Vector3,
	reviver: Player?,
	reviveProgress: number,
	crawlSpeed: number,
}

export type ReviveAttempt = {
	reviver: Player,
	target: Player,
	startTime: number,
	requiredTime: number,
}

-- State
local downedPlayers: { [Player]: DownedPlayer } = {}
local reviveAttempts: { [Player]: ReviveAttempt } = {}
local playerTeams: { [Player]: string } = {}
local teamMembers: { [string]: { Player } } = {}
local currentMode: TeamData.TeamMode = "Solos"
local isInitialized = false

-- Constants
local CRAWL_SPEED = 4
local REVIVE_RANGE = 5
local BLEED_DAMAGE_INTERVAL = 5
local BLEED_DAMAGE_AMOUNT = 5

-- Signals
local onPlayerDowned = Instance.new("BindableEvent")
local onPlayerRevived = Instance.new("BindableEvent")
local onPlayerBledOut = Instance.new("BindableEvent")
local onReviveStarted = Instance.new("BindableEvent")
local onReviveCancelled = Instance.new("BindableEvent")

RevivalManager.OnPlayerDowned = onPlayerDowned.Event
RevivalManager.OnPlayerRevived = onPlayerRevived.Event
RevivalManager.OnPlayerBledOut = onPlayerBledOut.Event
RevivalManager.OnReviveStarted = onReviveStarted.Event
RevivalManager.OnReviveCancelled = onReviveCancelled.Event

--[[
	Initialize the revival manager
]]
function RevivalManager.Initialize()
	if isInitialized then return end
	isInitialized = true

	print("[RevivalManager] Initializing...")

	-- Setup client events
	Events.OnServerEvent("Revival", function(player, action, data)
		if action == "StartRevive" then
			RevivalManager.StartRevive(player, data.targetId)
		elseif action == "CancelRevive" then
			RevivalManager.CancelRevive(player)
		elseif action == "CrawlMove" then
			RevivalManager.UpdateCrawlPosition(player, data.position)
		end
	end)

	-- Start update loop
	task.spawn(function()
		while true do
			RevivalManager.Update()
			task.wait(0.1)
		end
	end)

	print("[RevivalManager] Initialized")
end

--[[
	Set the current game mode
]]
function RevivalManager.SetMode(mode: TeamData.TeamMode)
	currentMode = mode
	print(`[RevivalManager] Mode set to: {mode}`)
end

--[[
	Register a player to a team
]]
function RevivalManager.RegisterPlayerTeam(player: Player, teamId: string)
	playerTeams[player] = teamId

	if not teamMembers[teamId] then
		teamMembers[teamId] = {}
	end
	table.insert(teamMembers[teamId], player)

	print(`[RevivalManager] {player.Name} joined team {teamId}`)
end

--[[
	Get player's team
]]
function RevivalManager.GetPlayerTeam(player: Player): string?
	return playerTeams[player]
end

--[[
	Get team members
]]
function RevivalManager.GetTeamMembers(teamId: string): { Player }
	return teamMembers[teamId] or {}
end

--[[
	Check if player is downed
]]
function RevivalManager.IsPlayerDowned(player: Player): boolean
	return downedPlayers[player] ~= nil
end

--[[
	Down a player (instead of eliminating)
]]
function RevivalManager.DownPlayer(player: Player, damageSource: string?): boolean
	local modeConfig = TeamData.GetModeConfig(currentMode)

	-- Check if mode supports revival
	if not modeConfig.canRevive then
		return false -- Should be eliminated instead
	end

	-- Check if player has alive teammates
	local teamId = playerTeams[player]
	if not teamId then
		return false -- No team, can't be downed
	end

	local hasAliveTeammate = false
	local members = teamMembers[teamId] or {}
	for _, member in ipairs(members) do
		if member ~= player and not downedPlayers[member] then
			-- Check if teammate is actually alive
			local character = member.Character
			if character then
				local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
				if humanoid and humanoid.Health > 0 then
					hasAliveTeammate = true
					break
				end
			end
		end
	end

	if not hasAliveTeammate then
		return false -- No teammates to revive, should be eliminated
	end

	-- Get player position
	local character = player.Character
	if not character then return false end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then return false end

	-- Create downed state
	local downedData: DownedPlayer = {
		player = player,
		teamId = teamId,
		downedTime = tick(),
		bleedOutTime = tick() + modeConfig.downedDuration,
		position = rootPart.Position,
		reviver = nil,
		reviveProgress = 0,
		crawlSpeed = CRAWL_SPEED,
	}

	downedPlayers[player] = downedData

	-- Set player to downed state (reduced health, crawling)
	local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
	if humanoid then
		humanoid.WalkSpeed = CRAWL_SPEED
		humanoid.JumpPower = 0
	end

	-- Notify clients
	Events.FireAllClients("Revival", "PlayerDowned", {
		playerId = player.UserId,
		playerName = player.Name,
		teamId = teamId,
		bleedOutTime = modeConfig.downedDuration,
		position = rootPart.Position,
	})

	-- Fire event
	onPlayerDowned:Fire(player, damageSource)

	print(`[RevivalManager] {player.Name} was downed`)
	return true
end

--[[
	Start reviving a downed teammate
]]
function RevivalManager.StartRevive(reviver: Player, targetId: number)
	-- Find target player
	local target = Players:GetPlayerByUserId(targetId)
	if not target then return end

	-- Check if target is downed
	if not downedPlayers[target] then
		return
	end

	-- Check if same team
	local reviverTeam = playerTeams[reviver]
	local targetTeam = playerTeams[target]
	if reviverTeam ~= targetTeam then
		return
	end

	-- Check if reviver is alive and not downed
	if downedPlayers[reviver] then
		return
	end

	-- Check distance
	local reviverChar = reviver.Character
	local targetChar = target.Character
	if not reviverChar or not targetChar then return end

	local reviverRoot = reviverChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	local targetRoot = targetChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not reviverRoot or not targetRoot then return end

	local distance = (reviverRoot.Position - targetRoot.Position).Magnitude
	if distance > REVIVE_RANGE then
		return
	end

	-- Cancel any existing revive attempt
	if reviveAttempts[reviver] then
		RevivalManager.CancelRevive(reviver)
	end

	local modeConfig = TeamData.GetModeConfig(currentMode)

	-- Start revive
	local attempt: ReviveAttempt = {
		reviver = reviver,
		target = target,
		startTime = tick(),
		requiredTime = modeConfig.reviveTime,
	}

	reviveAttempts[reviver] = attempt
	downedPlayers[target].reviver = reviver
	downedPlayers[target].reviveProgress = 0

	-- Notify clients
	Events.FireAllClients("Revival", "ReviveStarted", {
		reviverId = reviver.UserId,
		targetId = target.UserId,
		reviveTime = modeConfig.reviveTime,
	})

	onReviveStarted:Fire(reviver, target)
	print(`[RevivalManager] {reviver.Name} started reviving {target.Name}`)
end

--[[
	Cancel a revive attempt
]]
function RevivalManager.CancelRevive(reviver: Player)
	local attempt = reviveAttempts[reviver]
	if not attempt then return end

	-- Clear reviver from downed player
	local downedData = downedPlayers[attempt.target]
	if downedData then
		downedData.reviver = nil
		downedData.reviveProgress = 0
	end

	reviveAttempts[reviver] = nil

	-- Notify clients
	Events.FireAllClients("Revival", "ReviveCancelled", {
		reviverId = reviver.UserId,
		targetId = attempt.target.UserId,
	})

	onReviveCancelled:Fire(reviver, attempt.target)
	print(`[RevivalManager] {reviver.Name} cancelled revive`)
end

--[[
	Complete a revive
]]
function RevivalManager.CompleteRevive(reviver: Player, target: Player)
	local modeConfig = TeamData.GetModeConfig(currentMode)

	-- Remove from downed state
	downedPlayers[target] = nil
	reviveAttempts[reviver] = nil

	-- Restore player
	local character = target.Character
	if character then
		local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
		if humanoid then
			humanoid.Health = humanoid.MaxHealth * modeConfig.reviveHealthPercent
			humanoid.WalkSpeed = 16 -- Default walk speed
			humanoid.JumpPower = 50 -- Default jump power
		end
	end

	-- Notify clients
	Events.FireAllClients("Revival", "PlayerRevived", {
		reviverId = reviver.UserId,
		targetId = target.UserId,
		reviverName = reviver.Name,
		targetName = target.Name,
	})

	onPlayerRevived:Fire(target, reviver)
	print(`[RevivalManager] {reviver.Name} revived {target.Name}`)
end

--[[
	Handle player bleeding out
]]
function RevivalManager.BleedOut(player: Player)
	local downedData = downedPlayers[player]
	if not downedData then return end

	-- Cancel any active revive
	if downedData.reviver then
		RevivalManager.CancelRevive(downedData.reviver)
	end

	-- Remove from downed state
	downedPlayers[player] = nil

	-- Notify clients
	Events.FireAllClients("Revival", "PlayerBledOut", {
		playerId = player.UserId,
		playerName = player.Name,
	})

	onPlayerBledOut:Fire(player)
	print(`[RevivalManager] {player.Name} bled out`)
end

--[[
	Update crawl position for downed player
]]
function RevivalManager.UpdateCrawlPosition(player: Player, position: Vector3)
	local downedData = downedPlayers[player]
	if not downedData then return end

	downedData.position = position
end

--[[
	Update loop
]]
function RevivalManager.Update()
	local currentTime = tick()

	-- Update downed players
	for player, data in pairs(downedPlayers) do
		-- Check bleed out
		if currentTime >= data.bleedOutTime then
			RevivalManager.BleedOut(player)
			continue
		end

		-- Update revive progress
		if data.reviver then
			local attempt = reviveAttempts[data.reviver]
			if attempt then
				-- Check if reviver is still in range
				local reviverChar = data.reviver.Character
				local targetChar = player.Character
				if reviverChar and targetChar then
					local reviverRoot = reviverChar:FindFirstChild("HumanoidRootPart") :: BasePart?
					local targetRoot = targetChar:FindFirstChild("HumanoidRootPart") :: BasePart?
					if reviverRoot and targetRoot then
						local distance = (reviverRoot.Position - targetRoot.Position).Magnitude
						if distance > REVIVE_RANGE then
							RevivalManager.CancelRevive(data.reviver)
							continue
						end
					end
				end

				-- Update progress
				local elapsed = currentTime - attempt.startTime
				data.reviveProgress = math.clamp(elapsed / attempt.requiredTime, 0, 1)

				-- Check if complete
				if data.reviveProgress >= 1 then
					RevivalManager.CompleteRevive(data.reviver, player)
				else
					-- Send progress update
					Events.FireClient(data.reviver, "Revival", "ReviveProgress", {
						progress = data.reviveProgress,
						targetId = player.UserId,
					})
					Events.FireClient(player, "Revival", "BeingRevived", {
						progress = data.reviveProgress,
						reviverId = data.reviver.UserId,
					})
				end
			end
		end
	end
end

--[[
	Get downed player data
]]
function RevivalManager.GetDownedData(player: Player): DownedPlayer?
	return downedPlayers[player]
end

--[[
	Get all downed players
]]
function RevivalManager.GetAllDowned(): { DownedPlayer }
	local result = {}
	for _, data in pairs(downedPlayers) do
		table.insert(result, data)
	end
	return result
end

--[[
	Check if team is eliminated (all members dead or downed with no revivers)
]]
function RevivalManager.IsTeamEliminated(teamId: string): boolean
	local members = teamMembers[teamId]
	if not members then return true end

	for _, member in ipairs(members) do
		-- Check if member is alive and not downed
		if not downedPlayers[member] then
			local character = member.Character
			if character then
				local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
				if humanoid and humanoid.Health > 0 then
					return false -- At least one alive
				end
			end
		end
	end

	return true -- All dead or downed
end

--[[
	Reset for new match
]]
function RevivalManager.Reset()
	downedPlayers = {}
	reviveAttempts = {}
	playerTeams = {}
	teamMembers = {}
	print("[RevivalManager] Reset")
end

--[[
	Cleanup player
]]
function RevivalManager.CleanupPlayer(player: Player)
	-- Remove from downed
	if downedPlayers[player] then
		if downedPlayers[player].reviver then
			RevivalManager.CancelRevive(downedPlayers[player].reviver)
		end
		downedPlayers[player] = nil
	end

	-- Cancel any revive attempts
	if reviveAttempts[player] then
		RevivalManager.CancelRevive(player)
	end

	-- Remove from team
	local teamId = playerTeams[player]
	if teamId and teamMembers[teamId] then
		for i, member in ipairs(teamMembers[teamId]) do
			if member == player then
				table.remove(teamMembers[teamId], i)
				break
			end
		end
	end
	playerTeams[player] = nil
end

return RevivalManager
