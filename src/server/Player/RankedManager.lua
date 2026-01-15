--!strict
--[[
	RankedManager.lua
	=================
	Server-side ranked mode management
	Based on GDD Section 7.2: Ranked Leagues
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Events = require(ReplicatedStorage.Shared.Events)
local RankedData = require(ReplicatedStorage.Shared.RankedData)

local RankedManager = {}

-- Types
type PlayerRank = RankedData.PlayerRank

-- State
local playerRanks: { [Player]: PlayerRank } = {}
local currentSeason: RankedData.SeasonInfo? = nil
local isInitialized = false

-- Signals
local onRankChanged = Instance.new("BindableEvent")
local onSeasonEnd = Instance.new("BindableEvent")

RankedManager.OnRankChanged = onRankChanged.Event
RankedManager.OnSeasonEnd = onSeasonEnd.Event

--[[
	Initialize the ranked manager
]]
function RankedManager.Initialize()
	if isInitialized then return end
	isInitialized = true

	print("[RankedManager] Initializing...")

	-- Setup current season
	RankedManager.InitializeSeason()

	-- Setup client events
	Events.OnServerEvent("Ranked", "GetStats", function(player)
		RankedManager.SendRankData(player)
	end)

	-- Setup player tracking
	Players.PlayerAdded:Connect(function(player)
		RankedManager.InitializePlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		RankedManager.SavePlayer(player)
		RankedManager.CleanupPlayer(player)
	end)

	-- Initialize existing players
	for _, player in ipairs(Players:GetPlayers()) do
		RankedManager.InitializePlayer(player)
	end

	print("[RankedManager] Initialized")
end

--[[
	Initialize current season
]]
function RankedManager.InitializeSeason()
	local now = os.time()
	local seasonDuration = RankedData.SeasonDurationDays * 24 * 3600

	-- TODO: Load actual season from DataStore
	currentSeason = {
		id = "S1",
		name = "Season 1: Primordial Dawn",
		startTime = now,
		endTime = now + seasonDuration,
		rewards = RankedData.SeasonRewards,
	}

	print(`[RankedManager] Current season: {currentSeason.name}`)
end

--[[
	Initialize player rank
]]
function RankedManager.InitializePlayer(player: Player)
	-- TODO: Load from DataStore
	local rank: PlayerRank = {
		tier = "Bronze",
		division = 3,
		rp = 0,
		peakTier = "Bronze",
		peakDivision = 3,
		peakRP = 0,
		matchesPlayed = 0,
		wins = 0,
		top10s = 0,
		avgPlacement = 0,
	}

	playerRanks[player] = rank

	task.defer(function()
		RankedManager.SendRankData(player)
	end)
end

--[[
	Save player rank
]]
function RankedManager.SavePlayer(player: Player)
	local rank = playerRanks[player]
	if not rank then return end

	-- TODO: Save to DataStore
	print(`[RankedManager] Saving rank for {player.Name}: {rank.tier} {rank.division} ({rank.rp} RP)`)
end

--[[
	Cleanup player
]]
function RankedManager.CleanupPlayer(player: Player)
	playerRanks[player] = nil
end

--[[
	Process match result for ranked
]]
function RankedManager.ProcessMatchResult(player: Player, placement: number, kills: number)
	local rank = playerRanks[player]
	if not rank then return end

	-- Record stats
	rank.matchesPlayed = rank.matchesPlayed + 1

	if placement == 1 then
		rank.wins = rank.wins + 1
	end

	if placement <= 10 then
		rank.top10s = rank.top10s + 1
	end

	-- Update average placement
	rank.avgPlacement = ((rank.avgPlacement * (rank.matchesPlayed - 1)) + placement) / rank.matchesPlayed

	-- Calculate RP change
	local rpChange = RankedData.CalculateRPChange(placement, kills, rank.tier)

	-- Apply RP change
	local oldRP = rank.rp
	rank.rp = math.max(0, rank.rp + rpChange)

	-- Update tier/division
	local newTier = RankedData.GetTierForRP(rank.rp)
	local newDivision = RankedData.GetDivision(rank.rp, newTier)

	local tierChanged = rank.tier ~= newTier.id
	local divisionChanged = rank.division ~= newDivision

	rank.tier = newTier.id
	rank.division = newDivision

	-- Update peak rank
	if rank.rp > rank.peakRP then
		rank.peakRP = rank.rp
		rank.peakTier = rank.tier
		rank.peakDivision = rank.division
	end

	-- Notify player
	Events.FireClient("Ranked", "MatchResult", player, {
		placement = placement,
		kills = kills,
		rpChange = rpChange,
		newRP = rank.rp,
		tier = rank.tier,
		division = rank.division,
		tierChanged = tierChanged,
		divisionChanged = divisionChanged,
		isPromotion = rpChange > 0 and (tierChanged or divisionChanged),
		isDemotion = rpChange < 0 and (tierChanged or divisionChanged),
	})

	-- Fire signal if rank changed
	if tierChanged or divisionChanged then
		onRankChanged:Fire(player, rank.tier, rank.division, oldRP, rank.rp)
		print(`[RankedManager] {player.Name} rank changed to {RankedData.GetRankDisplayName(rank.rp)}`)
	end
end

--[[
	Get player's current rank
]]
function RankedManager.GetPlayerRank(player: Player): PlayerRank?
	return playerRanks[player]
end

--[[
	Get player's tier
]]
function RankedManager.GetPlayerTier(player: Player): string
	local rank = playerRanks[player]
	return rank and rank.tier or "Bronze"
end

--[[
	Get player's RP
]]
function RankedManager.GetPlayerRP(player: Player): number
	local rank = playerRanks[player]
	return rank and rank.rp or 0
end

--[[
	Check if player is in placement matches
]]
function RankedManager.IsInPlacements(player: Player): boolean
	local rank = playerRanks[player]
	if not rank then return true end
	return rank.matchesPlayed < RankedData.PlacementMatches
end

--[[
	Send rank data to player
]]
function RankedManager.SendRankData(player: Player)
	local rank = playerRanks[player]
	if not rank then return end

	local tier = RankedData.GetTier(rank.tier)
	if not tier then return end

	Events.FireClient("Ranked", "DataUpdate", player, {
		rank = rank,
		displayName = RankedData.GetRankDisplayName(rank.rp),
		rpToNext = RankedData.GetRPToNextRank(rank.rp),
		tierColor = tier.color,
		isInPlacements = RankedManager.IsInPlacements(player),
		placementMatchesLeft = math.max(0, RankedData.PlacementMatches - rank.matchesPlayed),
		season = currentSeason,
	})
end

--[[
	Send leaderboard data
]]
function RankedManager.SendLeaderboard(player: Player)
	-- Build leaderboard from current players
	local leaderboard = {}

	for p, rank in pairs(playerRanks) do
		table.insert(leaderboard, {
			userId = p.UserId,
			name = p.DisplayName,
			tier = rank.tier,
			division = rank.division,
			rp = rank.rp,
			wins = rank.wins,
		})
	end

	-- Sort by RP descending
	table.sort(leaderboard, function(a, b)
		return a.rp > b.rp
	end)

	-- Limit to top 100
	local topPlayers = {}
	for i = 1, math.min(100, #leaderboard) do
		topPlayers[i] = leaderboard[i]
		topPlayers[i].rank = i
	end

	-- Find player's rank
	local playerRankPosition = 0
	for i, entry in ipairs(leaderboard) do
		if entry.userId == player.UserId then
			playerRankPosition = i
			break
		end
	end

	Events.FireClient("Ranked", "LeaderboardUpdate", player, {
		topPlayers = topPlayers,
		playerRank = playerRankPosition,
		totalPlayers = #leaderboard,
	})
end

--[[
	Get matchmaking tier for player (for queue matching)
]]
function RankedManager.GetMatchmakingTier(player: Player): string
	local rank = playerRanks[player]
	if not rank then return "Bronze" end

	-- Group similar tiers for faster matchmaking
	local tier = rank.tier
	if tier == "Bronze" or tier == "Silver" then
		return "Low"
	elseif tier == "Gold" or tier == "Platinum" then
		return "Mid"
	elseif tier == "Diamond" then
		return "High"
	else
		return "Elite" -- Master and Apex
	end
end

--[[
	End season and distribute rewards
]]
function RankedManager.EndSeason()
	if not currentSeason then return end

	print("[RankedManager] Ending season...")

	-- Award rewards to all players
	for player, rank in pairs(playerRanks) do
		local rewards = RankedData.SeasonRewards[rank.peakTier]
		if rewards then
			Events.FireClient("Ranked", "SeasonRewards", player, {
				tier = rank.peakTier,
				rewards = rewards,
			})

			-- TODO: Actually grant rewards via cosmetics system
			print(`[RankedManager] Awarding {rank.peakTier} rewards to {player.Name}`)
		end

		-- Reset rank for new season (soft reset - keep some progress)
		local resetRP = math.floor(rank.rp * 0.5)
		resetRP = math.min(resetRP, 2500) -- Cap at Gold

		rank.rp = resetRP
		rank.tier = RankedData.GetTierForRP(resetRP).id
		rank.division = RankedData.GetDivision(resetRP, RankedData.GetTierForRP(resetRP))
		rank.matchesPlayed = 0
		rank.wins = 0
		rank.top10s = 0
		rank.avgPlacement = 0
	end

	onSeasonEnd:Fire(currentSeason)

	-- Start new season
	RankedManager.InitializeSeason()

	-- Notify all players
	for player in pairs(playerRanks) do
		RankedManager.SendRankData(player)
	end

	print("[RankedManager] New season started!")
end

--[[
	Get season info
]]
function RankedManager.GetSeason(): RankedData.SeasonInfo?
	return currentSeason
end

--[[
	Get time remaining in season
]]
function RankedManager.GetSeasonTimeRemaining(): number
	if not currentSeason then return 0 end
	return math.max(0, currentSeason.endTime - os.time())
end

return RankedManager
