--!strict
--[[
	PartyData.lua
	=============
	Party system configuration and types
	Based on GDD Section 11: Social Features
]]

export type PartyMember = {
	userId: number,
	name: string,
	displayName: string,
	isLeader: boolean,
	isReady: boolean,
	joinTime: number,
}

export type Party = {
	id: string,
	leader: number, -- UserId
	members: { PartyMember },
	maxSize: number,
	gameMode: string,
	isPublic: boolean,
	createdAt: number,
}

export type PartyInvite = {
	id: string,
	partyId: string,
	fromUserId: number,
	fromName: string,
	toUserId: number,
	expiresAt: number,
}

local PartyData = {}

-- Party size limits by game mode
PartyData.MaxSizes = {
	Solos = 1, -- No parties in solos
	Duos = 2,
	Trios = 3,
	Squads = 4,
}

-- Invite settings
PartyData.InviteExpirationSeconds = 60
PartyData.MaxPendingInvites = 10

-- Ready check settings
PartyData.ReadyCheckTimeout = 30

-- Voice chat settings (if supported)
PartyData.VoiceChatEnabled = true
PartyData.VoiceChatProximity = 50 -- Studs for proximity chat

-- Party finder settings
PartyData.PartyFinderEnabled = true
PartyData.PartyFinderRefreshRate = 10 -- Seconds

-- Game modes that support parties
PartyData.PartyModes = {
	"Duos",
	"Trios",
	"Squads",
}

-- Get max party size for a mode
function PartyData.GetMaxSize(gameMode: string): number
	return PartyData.MaxSizes[gameMode] or 4
end

-- Check if mode supports parties
function PartyData.SupportsParties(gameMode: string): boolean
	return table.find(PartyData.PartyModes, gameMode) ~= nil
end

-- Generate unique party ID
function PartyData.GeneratePartyId(): string
	return `party_{os.time()}_{math.random(10000, 99999)}`
end

-- Generate unique invite ID
function PartyData.GenerateInviteId(): string
	return `invite_{os.time()}_{math.random(10000, 99999)}`
end

return PartyData
