--!strict
--[[
	PartyManager.lua
	================
	Server-side party system management
	Based on GDD Section 11: Social Features
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Events = require(ReplicatedStorage.Shared.Events)
local PartyData = require(ReplicatedStorage.Shared.PartyData)

local PartyManager = {}

-- Types
type PartyMember = PartyData.PartyMember
type Party = PartyData.Party
type PartyInvite = PartyData.PartyInvite

-- State
local parties: { [string]: Party } = {}
local playerParties: { [Player]: string } = {} -- Player -> Party ID
local pendingInvites: { [string]: PartyInvite } = {} -- Invite ID -> Invite
local playerInvites: { [number]: { string } } = {} -- UserId -> Invite IDs
local isInitialized = false

-- Signals
local onPartyCreated = Instance.new("BindableEvent")
local onPartyDisbanded = Instance.new("BindableEvent")
local onPlayerJoined = Instance.new("BindableEvent")
local onPlayerLeft = Instance.new("BindableEvent")

PartyManager.OnPartyCreated = onPartyCreated.Event
PartyManager.OnPartyDisbanded = onPartyDisbanded.Event
PartyManager.OnPlayerJoined = onPlayerJoined.Event
PartyManager.OnPlayerLeft = onPlayerLeft.Event

--[[
	Initialize the party manager
]]
function PartyManager.Initialize()
	if isInitialized then return end
	isInitialized = true

	print("[PartyManager] Initializing...")

	-- Setup client events
	Events.OnServerEvent("Party", function(player, action, data)
		if action == "Create" then
			PartyManager.CreateParty(player, data.gameMode)
		elseif action == "Leave" then
			PartyManager.LeaveParty(player)
		elseif action == "Invite" then
			PartyManager.InvitePlayer(player, data.targetUserId)
		elseif action == "AcceptInvite" then
			PartyManager.AcceptInvite(player, data.inviteId)
		elseif action == "DeclineInvite" then
			PartyManager.DeclineInvite(player, data.inviteId)
		elseif action == "Kick" then
			PartyManager.KickPlayer(player, data.targetUserId)
		elseif action == "PromoteLeader" then
			PartyManager.PromoteLeader(player, data.targetUserId)
		elseif action == "SetReady" then
			PartyManager.SetReady(player, data.isReady)
		elseif action == "SetGameMode" then
			PartyManager.SetGameMode(player, data.gameMode)
		elseif action == "RequestData" then
			PartyManager.SendPartyData(player)
		end
	end)

	-- Cleanup on player leaving
	Players.PlayerRemoving:Connect(function(player)
		PartyManager.CleanupPlayer(player)
	end)

	-- Start invite expiration checker
	task.spawn(function()
		while true do
			task.wait(5)
			PartyManager.CleanupExpiredInvites()
		end
	end)

	print("[PartyManager] Initialized")
end

--[[
	Create a new party
]]
function PartyManager.CreateParty(player: Player, gameMode: string?): Party?
	-- Check if already in party
	if playerParties[player] then
		Events.FireClient(player, "Party", "Error", {
			message = "You are already in a party",
		})
		return nil
	end

	local mode = gameMode or "Squads"

	-- Validate game mode
	if not PartyData.SupportsParties(mode) then
		Events.FireClient(player, "Party", "Error", {
			message = "This game mode does not support parties",
		})
		return nil
	end

	local partyId = PartyData.GeneratePartyId()

	local party: Party = {
		id = partyId,
		leader = player.UserId,
		members = {
			{
				userId = player.UserId,
				name = player.Name,
				displayName = player.DisplayName,
				isLeader = true,
				isReady = false,
				joinTime = os.time(),
			},
		},
		maxSize = PartyData.GetMaxSize(mode),
		gameMode = mode,
		isPublic = false,
		createdAt = os.time(),
	}

	parties[partyId] = party
	playerParties[player] = partyId

	-- Notify player
	Events.FireClient(player, "Party", "Created", {
		party = party,
	})

	onPartyCreated:Fire(party)
	print(`[PartyManager] {player.Name} created party: {partyId}`)

	return party
end

--[[
	Leave current party
]]
function PartyManager.LeaveParty(player: Player)
	local partyId = playerParties[player]
	if not partyId then return end

	local party = parties[partyId]
	if not party then
		playerParties[player] = nil
		return
	end

	-- Remove player from party
	for i, member in ipairs(party.members) do
		if member.userId == player.UserId then
			table.remove(party.members, i)
			break
		end
	end

	playerParties[player] = nil

	-- Notify the leaving player
	Events.FireClient(player, "Party", "Left", {})

	-- Check if party is empty
	if #party.members == 0 then
		PartyManager.DisbandParty(partyId)
		return
	end

	-- If leader left, promote new leader
	if party.leader == player.UserId then
		local newLeader = party.members[1]
		party.leader = newLeader.userId
		newLeader.isLeader = true
	end

	-- Notify remaining members
	PartyManager.BroadcastToParty(partyId, "MemberLeft", {
		userId = player.UserId,
		name = player.Name,
		newLeader = party.leader,
	})

	onPlayerLeft:Fire(player, partyId)
	print(`[PartyManager] {player.Name} left party: {partyId}`)
end

--[[
	Disband a party
]]
function PartyManager.DisbandParty(partyId: string)
	local party = parties[partyId]
	if not party then return end

	-- Notify all members
	for _, member in ipairs(party.members) do
		local player = Players:GetPlayerByUserId(member.userId)
		if player then
			playerParties[player] = nil
			Events.FireClient(player, "Party", "Disbanded", {})
		end
	end

	parties[partyId] = nil
	onPartyDisbanded:Fire(partyId)
	print(`[PartyManager] Party disbanded: {partyId}`)
end

--[[
	Invite a player to the party
]]
function PartyManager.InvitePlayer(player: Player, targetUserId: number)
	local partyId = playerParties[player]
	if not partyId then
		Events.FireClient(player, "Party", "Error", {
			message = "You are not in a party",
		})
		return
	end

	local party = parties[partyId]
	if not party then return end

	-- Only leader can invite
	if party.leader ~= player.UserId then
		Events.FireClient(player, "Party", "Error", {
			message = "Only the party leader can invite players",
		})
		return
	end

	-- Check party size
	if #party.members >= party.maxSize then
		Events.FireClient(player, "Party", "Error", {
			message = "Party is full",
		})
		return
	end

	-- Check if target is already in party
	for _, member in ipairs(party.members) do
		if member.userId == targetUserId then
			Events.FireClient(player, "Party", "Error", {
				message = "Player is already in your party",
			})
			return
		end
	end

	-- Get target player
	local targetPlayer = Players:GetPlayerByUserId(targetUserId)
	if not targetPlayer then
		Events.FireClient(player, "Party", "Error", {
			message = "Player not found",
		})
		return
	end

	-- Check if target already has pending invite from this party
	local existingInvites = playerInvites[targetUserId] or {}
	for _, inviteId in ipairs(existingInvites) do
		local invite = pendingInvites[inviteId]
		if invite and invite.partyId == partyId then
			Events.FireClient(player, "Party", "Error", {
				message = "Player already has a pending invite",
			})
			return
		end
	end

	-- Check max pending invites
	if #existingInvites >= PartyData.MaxPendingInvites then
		Events.FireClient(player, "Party", "Error", {
			message = "Player has too many pending invites",
		})
		return
	end

	-- Create invite
	local inviteId = PartyData.GenerateInviteId()
	local invite: PartyInvite = {
		id = inviteId,
		partyId = partyId,
		fromUserId = player.UserId,
		fromName = player.DisplayName,
		toUserId = targetUserId,
		expiresAt = os.time() + PartyData.InviteExpirationSeconds,
	}

	pendingInvites[inviteId] = invite

	if not playerInvites[targetUserId] then
		playerInvites[targetUserId] = {}
	end
	table.insert(playerInvites[targetUserId], inviteId)

	-- Notify target
	Events.FireClient(targetPlayer, "Party", "InviteReceived", {
		invite = invite,
		gameMode = party.gameMode,
		memberCount = #party.members,
		maxSize = party.maxSize,
	})

	-- Notify sender
	Events.FireClient(player, "Party", "InviteSent", {
		targetName = targetPlayer.DisplayName,
	})

	print(`[PartyManager] {player.Name} invited {targetPlayer.Name} to party`)
end

--[[
	Accept a party invite
]]
function PartyManager.AcceptInvite(player: Player, inviteId: string)
	local invite = pendingInvites[inviteId]
	if not invite then
		Events.FireClient(player, "Party", "Error", {
			message = "Invite not found or expired",
		})
		return
	end

	if invite.toUserId ~= player.UserId then
		Events.FireClient(player, "Party", "Error", {
			message = "This invite is not for you",
		})
		return
	end

	-- Check if invite expired
	if os.time() > invite.expiresAt then
		PartyManager.RemoveInvite(inviteId)
		Events.FireClient(player, "Party", "Error", {
			message = "Invite has expired",
		})
		return
	end

	local party = parties[invite.partyId]
	if not party then
		PartyManager.RemoveInvite(inviteId)
		Events.FireClient(player, "Party", "Error", {
			message = "Party no longer exists",
		})
		return
	end

	-- Check party size
	if #party.members >= party.maxSize then
		PartyManager.RemoveInvite(inviteId)
		Events.FireClient(player, "Party", "Error", {
			message = "Party is full",
		})
		return
	end

	-- Leave current party if in one
	if playerParties[player] then
		PartyManager.LeaveParty(player)
	end

	-- Join party
	local member: PartyMember = {
		userId = player.UserId,
		name = player.Name,
		displayName = player.DisplayName,
		isLeader = false,
		isReady = false,
		joinTime = os.time(),
	}

	table.insert(party.members, member)
	playerParties[player] = party.id

	-- Remove invite
	PartyManager.RemoveInvite(inviteId)

	-- Notify new member
	Events.FireClient(player, "Party", "Joined", {
		party = party,
	})

	-- Notify other members
	for _, m in ipairs(party.members) do
		if m.userId ~= player.UserId then
			local p = Players:GetPlayerByUserId(m.userId)
			if p then
				Events.FireClient(p, "Party", "MemberJoined", {
					member = member,
				})
			end
		end
	end

	onPlayerJoined:Fire(player, party.id)
	print(`[PartyManager] {player.Name} joined party: {party.id}`)
end

--[[
	Decline a party invite
]]
function PartyManager.DeclineInvite(player: Player, inviteId: string)
	local invite = pendingInvites[inviteId]
	if not invite then return end

	if invite.toUserId ~= player.UserId then return end

	PartyManager.RemoveInvite(inviteId)

	-- Notify the inviter
	local inviter = Players:GetPlayerByUserId(invite.fromUserId)
	if inviter then
		Events.FireClient(inviter, "Party", "InviteDeclined", {
			targetName = player.DisplayName,
		})
	end

	print(`[PartyManager] {player.Name} declined party invite`)
end

--[[
	Remove an invite
]]
function PartyManager.RemoveInvite(inviteId: string)
	local invite = pendingInvites[inviteId]
	if not invite then return end

	-- Remove from player invites
	local invites = playerInvites[invite.toUserId]
	if invites then
		for i, id in ipairs(invites) do
			if id == inviteId then
				table.remove(invites, i)
				break
			end
		end
	end

	pendingInvites[inviteId] = nil
end

--[[
	Kick a player from the party
]]
function PartyManager.KickPlayer(leader: Player, targetUserId: number)
	local partyId = playerParties[leader]
	if not partyId then return end

	local party = parties[partyId]
	if not party then return end

	-- Only leader can kick
	if party.leader ~= leader.UserId then
		Events.FireClient(leader, "Party", "Error", {
			message = "Only the party leader can kick players",
		})
		return
	end

	-- Can't kick yourself
	if targetUserId == leader.UserId then
		Events.FireClient(leader, "Party", "Error", {
			message = "You cannot kick yourself",
		})
		return
	end

	-- Find and remove member
	local kicked = false
	for i, member in ipairs(party.members) do
		if member.userId == targetUserId then
			table.remove(party.members, i)
			kicked = true
			break
		end
	end

	if not kicked then return end

	-- Update kicked player
	local kickedPlayer = Players:GetPlayerByUserId(targetUserId)
	if kickedPlayer then
		playerParties[kickedPlayer] = nil
		Events.FireClient(kickedPlayer, "Party", "Kicked", {})
	end

	-- Notify party
	PartyManager.BroadcastToParty(partyId, "MemberKicked", {
		userId = targetUserId,
	})

	print(`[PartyManager] {leader.Name} kicked {targetUserId} from party`)
end

--[[
	Promote a new leader
]]
function PartyManager.PromoteLeader(leader: Player, targetUserId: number)
	local partyId = playerParties[leader]
	if not partyId then return end

	local party = parties[partyId]
	if not party then return end

	-- Only leader can promote
	if party.leader ~= leader.UserId then
		Events.FireClient(leader, "Party", "Error", {
			message = "Only the party leader can promote others",
		})
		return
	end

	-- Find target member
	local targetMember: PartyMember? = nil
	for _, member in ipairs(party.members) do
		if member.userId == targetUserId then
			targetMember = member
		end
		-- Remove leader status from all
		member.isLeader = false
	end

	if not targetMember then
		Events.FireClient(leader, "Party", "Error", {
			message = "Player not found in party",
		})
		return
	end

	-- Promote
	party.leader = targetUserId
	targetMember.isLeader = true

	-- Notify party
	PartyManager.BroadcastToParty(partyId, "LeaderChanged", {
		newLeader = targetUserId,
	})

	print(`[PartyManager] {leader.Name} promoted {targetUserId} to leader`)
end

--[[
	Set player ready status
]]
function PartyManager.SetReady(player: Player, isReady: boolean)
	local partyId = playerParties[player]
	if not partyId then return end

	local party = parties[partyId]
	if not party then return end

	-- Find member and update
	for _, member in ipairs(party.members) do
		if member.userId == player.UserId then
			member.isReady = isReady
			break
		end
	end

	-- Notify party
	PartyManager.BroadcastToParty(partyId, "MemberReady", {
		userId = player.UserId,
		isReady = isReady,
	})

	-- Check if all ready
	if PartyManager.AreAllReady(partyId) then
		PartyManager.BroadcastToParty(partyId, "AllReady", {})
	end
end

--[[
	Check if all members are ready
]]
function PartyManager.AreAllReady(partyId: string): boolean
	local party = parties[partyId]
	if not party then return false end

	for _, member in ipairs(party.members) do
		if not member.isReady then
			return false
		end
	end

	return true
end

--[[
	Set game mode for party
]]
function PartyManager.SetGameMode(player: Player, gameMode: string)
	local partyId = playerParties[player]
	if not partyId then return end

	local party = parties[partyId]
	if not party then return end

	-- Only leader can change mode
	if party.leader ~= player.UserId then
		Events.FireClient(player, "Party", "Error", {
			message = "Only the party leader can change game mode",
		})
		return
	end

	-- Validate game mode
	if not PartyData.SupportsParties(gameMode) then
		Events.FireClient(player, "Party", "Error", {
			message = "This game mode does not support parties",
		})
		return
	end

	local newMaxSize = PartyData.GetMaxSize(gameMode)

	-- Check if party is too large for new mode
	if #party.members > newMaxSize then
		Events.FireClient(player, "Party", "Error", {
			message = `Party too large for {gameMode} (max {newMaxSize})`,
		})
		return
	end

	party.gameMode = gameMode
	party.maxSize = newMaxSize

	-- Notify party
	PartyManager.BroadcastToParty(partyId, "GameModeChanged", {
		gameMode = gameMode,
		maxSize = newMaxSize,
	})

	print(`[PartyManager] Party {partyId} changed mode to {gameMode}`)
end

--[[
	Broadcast message to all party members
]]
function PartyManager.BroadcastToParty(partyId: string, action: string, data: any)
	local party = parties[partyId]
	if not party then return end

	for _, member in ipairs(party.members) do
		local player = Players:GetPlayerByUserId(member.userId)
		if player then
			Events.FireClient(player, "Party", action, data)
		end
	end
end

--[[
	Send party data to player
]]
function PartyManager.SendPartyData(player: Player)
	local partyId = playerParties[player]

	if partyId then
		local party = parties[partyId]
		if party then
			Events.FireClient(player, "Party", "DataUpdate", {
				party = party,
			})
		end
	else
		Events.FireClient(player, "Party", "DataUpdate", {
			party = nil,
		})
	end

	-- Send pending invites
	local invites = {}
	local inviteIds = playerInvites[player.UserId]
	if inviteIds then
		for _, inviteId in ipairs(inviteIds) do
			local invite = pendingInvites[inviteId]
			if invite and os.time() < invite.expiresAt then
				local party = parties[invite.partyId]
				if party then
					table.insert(invites, {
						invite = invite,
						gameMode = party.gameMode,
						memberCount = #party.members,
						maxSize = party.maxSize,
					})
				end
			end
		end
	end

	Events.FireClient(player, "Party", "InvitesUpdate", {
		invites = invites,
	})
end

--[[
	Cleanup expired invites
]]
function PartyManager.CleanupExpiredInvites()
	local now = os.time()
	local toRemove = {}

	for inviteId, invite in pairs(pendingInvites) do
		if now > invite.expiresAt then
			table.insert(toRemove, inviteId)
		end
	end

	for _, inviteId in ipairs(toRemove) do
		PartyManager.RemoveInvite(inviteId)
	end
end

--[[
	Cleanup player
]]
function PartyManager.CleanupPlayer(player: Player)
	-- Leave party
	if playerParties[player] then
		PartyManager.LeaveParty(player)
	end

	-- Clear invites for this player
	local inviteIds = playerInvites[player.UserId]
	if inviteIds then
		for _, inviteId in ipairs(inviteIds) do
			pendingInvites[inviteId] = nil
		end
		playerInvites[player.UserId] = nil
	end
end

--[[
	Get player's party
]]
function PartyManager.GetPlayerParty(player: Player): Party?
	local partyId = playerParties[player]
	if not partyId then return nil end
	return parties[partyId]
end

--[[
	Get party by ID
]]
function PartyManager.GetParty(partyId: string): Party?
	return parties[partyId]
end

--[[
	Check if player is party leader
]]
function PartyManager.IsLeader(player: Player): boolean
	local party = PartyManager.GetPlayerParty(player)
	return party and party.leader == player.UserId or false
end

--[[
	Get party members as players
]]
function PartyManager.GetPartyPlayers(player: Player): { Player }
	local result = {}
	local party = PartyManager.GetPlayerParty(player)
	if not party then return result end

	for _, member in ipairs(party.members) do
		local p = Players:GetPlayerByUserId(member.userId)
		if p then
			table.insert(result, p)
		end
	end

	return result
end

return PartyManager
