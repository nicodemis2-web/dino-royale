--!strict
--[[
	ProgressionManager.lua
	======================
	Server-side XP and progression handling
	Based on GDD Section 8: Progression System
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local Events = require(ReplicatedStorage.Shared.Events)
local ProgressionData = require(ReplicatedStorage.Shared.ProgressionData)

local ProgressionManager = {}

-- Types
export type PlayerProgress = {
	totalXP: number,
	level: number,
	claimedRewardLevels: { number },

	-- Stats
	kills: number,
	deaths: number,
	wins: number,
	gamesPlayed: number,
	dinoKills: number,
	damageDealt: number,
	revives: number,
	reboots: number,
	timePlayed: number, -- seconds

	-- Challenge progress
	dailyChallengeProgress: { [string]: number },
	weeklyChallengeProgress: { [string]: number },
	lifetimeChallengeProgress: { [string]: number },

	-- Timestamps
	lastDailyReset: number,
	lastWeeklyReset: number,
	lastMatchTime: number,
}

export type MatchStats = {
	kills: number,
	assists: number,
	dinoKills: { [string]: number }, -- By tier
	damageDealt: number,
	survivalTime: number,
	placement: number,
	totalPlayers: number,
	revives: number,
	reboots: number,
	biomesVisited: { string },
	itemsLooted: number,
}

-- State
local playerProgress: { [Player]: PlayerProgress } = {}
local currentMatchStats: { [Player]: MatchStats } = {}
local isInitialized = false

-- DataStore
local progressDataStore = DataStoreService:GetDataStore("PlayerProgression_v1")

-- DataStore retry constants
local MAX_RETRIES = 3
local RETRY_DELAY = 1

-- Signals
local onXPGained = Instance.new("BindableEvent")
local onLevelUp = Instance.new("BindableEvent")
local onChallengeCompleted = Instance.new("BindableEvent")
local onRewardClaimed = Instance.new("BindableEvent")

ProgressionManager.OnXPGained = onXPGained.Event
ProgressionManager.OnLevelUp = onLevelUp.Event
ProgressionManager.OnChallengeCompleted = onChallengeCompleted.Event
ProgressionManager.OnRewardClaimed = onRewardClaimed.Event

-- Default progress
local function createDefaultProgress(): PlayerProgress
	return {
		totalXP = 0,
		level = 1,
		claimedRewardLevels = {},

		kills = 0,
		deaths = 0,
		wins = 0,
		gamesPlayed = 0,
		dinoKills = 0,
		damageDealt = 0,
		revives = 0,
		reboots = 0,
		timePlayed = 0,

		dailyChallengeProgress = {},
		weeklyChallengeProgress = {},
		lifetimeChallengeProgress = {},

		lastDailyReset = 0,
		lastWeeklyReset = 0,
		lastMatchTime = 0,
	}
end

-- Default match stats
local function createDefaultMatchStats(): MatchStats
	return {
		kills = 0,
		assists = 0,
		dinoKills = {},
		damageDealt = 0,
		survivalTime = 0,
		placement = 100,
		totalPlayers = 100,
		revives = 0,
		reboots = 0,
		biomesVisited = {},
		itemsLooted = 0,
	}
end

--[[
	Initialize the progression manager
]]
function ProgressionManager.Initialize()
	if isInitialized then return end
	isInitialized = true

	print("[ProgressionManager] Initializing...")

	-- Setup client events
	Events.OnServerEvent("Progression", "ClaimReward", function(player, data)
		if typeof(data) == "table" and typeof(data.level) == "number" then
			ProgressionManager.ClaimReward(player, data.level)
		end
	end)

	Events.OnServerEvent("Progression", "GetProgress", function(player)
		ProgressionManager.SendProgressToClient(player)
	end)

	-- Handle player join/leave
	Players.PlayerAdded:Connect(function(player)
		ProgressionManager.LoadPlayerProgress(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		ProgressionManager.SavePlayerProgress(player)
	end)

	-- Load existing players
	for _, player in ipairs(Players:GetPlayers()) do
		ProgressionManager.LoadPlayerProgress(player)
	end

	print("[ProgressionManager] Initialized")
end

--[[
	Load player progress from DataStore with retry logic
]]
function ProgressionManager.LoadPlayerProgress(player: Player)
	local data = nil
	local success = false

	for attempt = 1, MAX_RETRIES do
		success, data = pcall(function()
			return progressDataStore:GetAsync(`player_{player.UserId}`)
		end)

		if success then
			break
		end

		if attempt < MAX_RETRIES then
			warn(`[ProgressionManager] GetAsync failed for {player.Name}, retry {attempt}/{MAX_RETRIES}`)
			task.wait(RETRY_DELAY * attempt) -- Exponential backoff
		end
	end

	local progress: PlayerProgress
	if success and data then
		progress = data :: PlayerProgress
		-- Ensure all fields exist (for backward compatibility)
		local default = createDefaultProgress()
		for key, value in pairs(default) do
			if (progress :: any)[key] == nil then
				(progress :: any)[key] = value
			end
		end
	else
		progress = createDefaultProgress()
	end

	-- Check for daily/weekly reset
	local now = os.time()
	local daySeconds = 86400
	local weekSeconds = 604800

	-- Daily reset (midnight UTC)
	local lastDailyReset = progress.lastDailyReset
	local todayMidnight = math.floor(now / daySeconds) * daySeconds
	if lastDailyReset < todayMidnight then
		progress.dailyChallengeProgress = {}
		progress.lastDailyReset = todayMidnight
	end

	-- Weekly reset (Monday midnight UTC)
	local lastWeeklyReset = progress.lastWeeklyReset
	local thisWeekMonday = math.floor((now - 345600) / weekSeconds) * weekSeconds + 345600 -- Adjust for epoch starting Thursday
	if lastWeeklyReset < thisWeekMonday then
		progress.weeklyChallengeProgress = {}
		progress.lastWeeklyReset = thisWeekMonday
	end

	playerProgress[player] = progress

	-- Send to client
	ProgressionManager.SendProgressToClient(player)

	print(`[ProgressionManager] Loaded progress for {player.Name} (Level {progress.level})`)
end

--[[
	Save player progress to DataStore with retry logic
]]
function ProgressionManager.SavePlayerProgress(player: Player)
	local progress = playerProgress[player]
	if not progress then return end

	local playerKey = `player_{player.UserId}`
	local playerName = player.Name
	local saved = false

	for attempt = 1, MAX_RETRIES do
		local success, err = pcall(function()
			progressDataStore:SetAsync(playerKey, progress)
		end)

		if success then
			print(`[ProgressionManager] Saved progress for {playerName}`)
			saved = true
			break
		end

		if attempt < MAX_RETRIES then
			warn(`[ProgressionManager] SetAsync failed for {playerName}, retry {attempt}/{MAX_RETRIES}: {err}`)
			task.wait(RETRY_DELAY * attempt) -- Exponential backoff
		else
			warn(`[ProgressionManager] Failed to save progress for {playerName} after {MAX_RETRIES} attempts: {err}`)
		end
	end

	playerProgress[player] = nil
	currentMatchStats[player] = nil
end

--[[
	Send progress to client
]]
function ProgressionManager.SendProgressToClient(player: Player)
	local progress = playerProgress[player]
	if not progress then return end

	Events.FireClient(player, "Progression", "ProgressUpdate", {
		totalXP = progress.totalXP,
		level = progress.level,
		levelProgress = ProgressionData.GetLevelProgress(progress.totalXP),
		xpToNextLevel = ProgressionData.GetXPForNextLevel(progress.level) - progress.totalXP,

		stats = {
			kills = progress.kills,
			deaths = progress.deaths,
			wins = progress.wins,
			gamesPlayed = progress.gamesPlayed,
			kd = progress.deaths > 0 and (progress.kills / progress.deaths) or progress.kills,
			winRate = progress.gamesPlayed > 0 and (progress.wins / progress.gamesPlayed * 100) or 0,
		},

		dailyChallenges = ProgressionManager.GetChallengeStatus(player, "Daily"),
		weeklyChallenges = ProgressionManager.GetChallengeStatus(player, "Weekly"),
		lifetimeChallenges = ProgressionManager.GetChallengeStatus(player, "Lifetime"),

		unclaimedRewards = ProgressionData.GetUnclaimedRewards(progress.level, progress.claimedRewardLevels),
	})
end

--[[
	Start tracking a new match
]]
function ProgressionManager.StartMatch(player: Player)
	currentMatchStats[player] = createDefaultMatchStats()
end

--[[
	Award XP to player
]]
function ProgressionManager.AwardXP(player: Player, source: ProgressionData.XPSource, amount: number?, context: any?)
	local progress = playerProgress[player]
	if not progress then return end

	local xp = amount or ProgressionData.XPValues[source]

	-- Apply context-based multipliers
	if context then
		if context.dinoTier == "Legendary" then
			xp = math.floor(xp * ProgressionData.BonusMultipliers.DinoKillLegendary)
		elseif context.dinoTier == "Epic" then
			xp = math.floor(xp * ProgressionData.BonusMultipliers.DinoKillEpic)
		elseif context.dinoTier == "Rare" then
			xp = math.floor(xp * ProgressionData.BonusMultipliers.DinoKillRare)
		end

		if context.killStreak then
			if context.killStreak >= 10 then
				xp = math.floor(xp * ProgressionData.BonusMultipliers.KillStreak10)
			elseif context.killStreak >= 5 then
				xp = math.floor(xp * ProgressionData.BonusMultipliers.KillStreak5)
			elseif context.killStreak >= 3 then
				xp = math.floor(xp * ProgressionData.BonusMultipliers.KillStreak3)
			end
		end
	end

	local oldLevel = progress.level
	progress.totalXP = progress.totalXP + xp
	progress.level = ProgressionData.GetLevelFromXP(progress.totalXP)

	-- Notify client
	Events.FireClient(player, "Progression", "XPGained", {
		amount = xp,
		source = source,
		totalXP = progress.totalXP,
		level = progress.level,
		levelProgress = ProgressionData.GetLevelProgress(progress.totalXP),
	})

	onXPGained:Fire(player, xp, source)

	-- Check for level up
	if progress.level > oldLevel then
		for level = oldLevel + 1, progress.level do
			ProgressionManager.OnLevelUp(player, level)
		end
	end
end

--[[
	Handle level up
]]
function ProgressionManager.OnLevelUp(player: Player, newLevel: number)
	local rewards = ProgressionData.GetRewardsForLevel(newLevel)

	Events.FireClient(player, "Progression", "LevelUp", {
		level = newLevel,
		rewards = rewards,
	})

	onLevelUp:Fire(player, newLevel, rewards)
	print(`[ProgressionManager] {player.Name} reached level {newLevel}`)
end

--[[
	Claim a level reward
]]
function ProgressionManager.ClaimReward(player: Player, level: number)
	local progress = playerProgress[player]
	if not progress then return end

	-- Check if already claimed
	for _, claimed in ipairs(progress.claimedRewardLevels) do
		if claimed == level then
			return
		end
	end

	-- Check if level reached
	if progress.level < level then
		return
	end

	-- Get rewards for this level
	local rewards = ProgressionData.GetRewardsForLevel(level)
	if #rewards == 0 then return end

	-- Mark as claimed
	table.insert(progress.claimedRewardLevels, level)

	-- Grant rewards
	for _, reward in ipairs(rewards) do
		ProgressionManager.GrantReward(player, reward)
	end

	Events.FireClient(player, "Progression", "RewardClaimed", {
		level = level,
		rewards = rewards,
	})

	onRewardClaimed:Fire(player, level, rewards)
	print(`[ProgressionManager] {player.Name} claimed level {level} rewards`)
end

--[[
	Grant a reward to player
]]
function ProgressionManager.GrantReward(player: Player, reward: ProgressionData.LevelReward)
	-- This would integrate with inventory/cosmetics system
	-- For now, just log it
	print(`[ProgressionManager] Granting {reward.rewardType}: {reward.rewardId} to {player.Name}`)

	-- TODO: Add to player's unlocked items
	-- InventoryManager.UnlockItem(player, reward.rewardType, reward.rewardId)
end

--[[
	Record a kill
]]
function ProgressionManager.RecordKill(player: Player, context: any?)
	local progress = playerProgress[player]
	local matchStats = currentMatchStats[player]

	if progress then
		progress.kills = progress.kills + 1
	end

	if matchStats then
		matchStats.kills = matchStats.kills + 1
	end

	-- Award XP
	ProgressionManager.AwardXP(player, "Kill", nil, context)

	-- Update challenges
	ProgressionManager.UpdateChallengeProgress(player, "kills", 1)
end

--[[
	Record an assist
]]
function ProgressionManager.RecordAssist(player: Player)
	local matchStats = currentMatchStats[player]
	if matchStats then
		matchStats.assists = matchStats.assists + 1
	end

	ProgressionManager.AwardXP(player, "Assist")
end

--[[
	Record a dinosaur kill
]]
function ProgressionManager.RecordDinoKill(player: Player, dinoTier: string)
	local progress = playerProgress[player]
	local matchStats = currentMatchStats[player]

	if progress then
		progress.dinoKills = progress.dinoKills + 1
	end

	if matchStats then
		matchStats.dinoKills[dinoTier] = (matchStats.dinoKills[dinoTier] or 0) + 1
	end

	-- Award XP with tier bonus
	ProgressionManager.AwardXP(player, "DinoKill", nil, { dinoTier = dinoTier })

	-- Update challenges
	ProgressionManager.UpdateChallengeProgress(player, "dino_kills", 1)

	if dinoTier == "Legendary" then
		ProgressionManager.UpdateChallengeProgress(player, "legendary_dino_kill", 1)
		if matchStats then
			-- Track for T-Rex specifically (would need more context)
			local _ = matchStats -- Acknowledge intentionally empty block
		end
	end
end

--[[
	Record a revive
]]
function ProgressionManager.RecordRevive(player: Player)
	local progress = playerProgress[player]
	local matchStats = currentMatchStats[player]

	if progress then
		progress.revives = progress.revives + 1
	end

	if matchStats then
		matchStats.revives = matchStats.revives + 1
	end

	ProgressionManager.AwardXP(player, "Revive")
	ProgressionManager.UpdateChallengeProgress(player, "revives", 1)
end

--[[
	Record a reboot
]]
function ProgressionManager.RecordReboot(player: Player)
	local progress = playerProgress[player]
	local matchStats = currentMatchStats[player]

	if progress then
		progress.reboots = progress.reboots + 1
	end

	if matchStats then
		matchStats.reboots = matchStats.reboots + 1
	end

	ProgressionManager.AwardXP(player, "Reboot")
end

--[[
	Record damage dealt
]]
function ProgressionManager.RecordDamage(player: Player, amount: number)
	local progress = playerProgress[player]
	local matchStats = currentMatchStats[player]

	if progress then
		progress.damageDealt = progress.damageDealt + amount
	end

	if matchStats then
		matchStats.damageDealt = matchStats.damageDealt + amount
	end

	-- Award XP per 10 damage
	local xpAmount = math.floor(amount / 10) * ProgressionData.XPValues.DamageDealt
	if xpAmount > 0 then
		ProgressionManager.AwardXP(player, "DamageDealt", xpAmount)
	end

	ProgressionManager.UpdateChallengeProgress(player, "damage", amount)
end

--[[
	Record biome visited
]]
function ProgressionManager.RecordBiomeVisited(player: Player, biome: string)
	local matchStats = currentMatchStats[player]
	if not matchStats then return end

	-- Check if already visited
	for _, visited in ipairs(matchStats.biomesVisited) do
		if visited == biome then
			return
		end
	end

	table.insert(matchStats.biomesVisited, biome)
	ProgressionManager.UpdateChallengeProgress(player, "biomes_visited", #matchStats.biomesVisited)
end

--[[
	Record item looted
]]
function ProgressionManager.RecordLoot(player: Player)
	local matchStats = currentMatchStats[player]
	if matchStats then
		matchStats.itemsLooted = matchStats.itemsLooted + 1
	end

	ProgressionManager.UpdateChallengeProgress(player, "loot", 1)
end

--[[
	End match and calculate final XP
]]
function ProgressionManager.EndMatch(player: Player, placement: number, totalPlayers: number, survivalTime: number)
	local progress = playerProgress[player]
	local matchStats = currentMatchStats[player]

	if progress then
		progress.gamesPlayed = progress.gamesPlayed + 1
		progress.timePlayed = progress.timePlayed + survivalTime
		progress.lastMatchTime = os.time()

		if placement == 1 then
			progress.wins = progress.wins + 1
			ProgressionManager.UpdateChallengeProgress(player, "wins", 1)
		end
	end

	if matchStats then
		matchStats.placement = placement
		matchStats.totalPlayers = totalPlayers
		matchStats.survivalTime = survivalTime
	end

	-- Award placement XP
	local placementXP = ProgressionData.CalculatePlacementXP(placement, totalPlayers)
	ProgressionManager.AwardXP(player, "Placement", placementXP)

	-- Award survival XP
	local survivalMinutes = math.floor(survivalTime / 60)
	local survivalXP = survivalMinutes * ProgressionData.XPValues.Survival
	if survivalXP > 0 then
		ProgressionManager.AwardXP(player, "Survival", survivalXP)
	end

	-- Check placement challenges
	if placement <= 10 then
		ProgressionManager.UpdateChallengeProgress(player, "top10", 1)
	end

	-- Send match summary
	Events.FireClient(player, "Progression", "MatchSummary", {
		placement = placement,
		totalPlayers = totalPlayers,
		stats = matchStats,
		xpEarned = {
			placement = placementXP,
			survival = survivalXP,
			kills = matchStats and matchStats.kills * ProgressionData.XPValues.Kill or 0,
		},
	})

	-- Clear match stats
	currentMatchStats[player] = nil

	-- Save progress
	ProgressionManager.SavePlayerProgress(player)
end

--[[
	Update challenge progress
]]
function ProgressionManager.UpdateChallengeProgress(player: Player, requirement: string, amount: number)
	local progress = playerProgress[player]
	if not progress then return end

	-- Update daily challenges
	for _, challenge in ipairs(ProgressionData.DailyChallenges) do
		if challenge.requirement == requirement then
			local current = progress.dailyChallengeProgress[challenge.id] or 0
			local wasComplete = current >= challenge.targetAmount

			progress.dailyChallengeProgress[challenge.id] = current + amount

			-- Check if just completed
			if not wasComplete and progress.dailyChallengeProgress[challenge.id] >= challenge.targetAmount then
				ProgressionManager.CompleteChallenge(player, challenge)
			end
		end
	end

	-- Update weekly challenges
	for _, challenge in ipairs(ProgressionData.WeeklyChallenges) do
		if challenge.requirement == requirement then
			local current = progress.weeklyChallengeProgress[challenge.id] or 0
			local wasComplete = current >= challenge.targetAmount

			progress.weeklyChallengeProgress[challenge.id] = current + amount

			if not wasComplete and progress.weeklyChallengeProgress[challenge.id] >= challenge.targetAmount then
				ProgressionManager.CompleteChallenge(player, challenge)
			end
		end
	end

	-- Update lifetime challenges
	for _, challenge in ipairs(ProgressionData.LifetimeChallenges) do
		if challenge.requirement == requirement then
			local current = progress.lifetimeChallengeProgress[challenge.id] or 0
			local wasComplete = current >= challenge.targetAmount

			progress.lifetimeChallengeProgress[challenge.id] = current + amount

			if not wasComplete and progress.lifetimeChallengeProgress[challenge.id] >= challenge.targetAmount then
				ProgressionManager.CompleteChallenge(player, challenge)
			end
		end
	end
end

--[[
	Complete a challenge
]]
function ProgressionManager.CompleteChallenge(player: Player, challenge: ProgressionData.Challenge)
	-- Award XP
	ProgressionManager.AwardXP(player, "Challenge", challenge.xpReward)

	-- Grant additional reward if any
	if challenge.additionalReward then
		ProgressionManager.GrantReward(player, challenge.additionalReward)
	end

	Events.FireClient(player, "Progression", "ChallengeCompleted", {
		challenge = challenge,
	})

	onChallengeCompleted:Fire(player, challenge)
	print(`[ProgressionManager] {player.Name} completed challenge: {challenge.name}`)
end

--[[
	Get challenge status for player
]]
function ProgressionManager.GetChallengeStatus(player: Player, challengeType: ProgressionData.ChallengeType): { any }
	local progress = playerProgress[player]
	if not progress then return {} end

	local challenges
	local progressTable

	if challengeType == "Daily" then
		challenges = ProgressionData.DailyChallenges
		progressTable = progress.dailyChallengeProgress
	elseif challengeType == "Weekly" then
		challenges = ProgressionData.WeeklyChallenges
		progressTable = progress.weeklyChallengeProgress
	else
		challenges = ProgressionData.LifetimeChallenges
		progressTable = progress.lifetimeChallengeProgress
	end

	local result = {}
	for _, challenge in ipairs(challenges) do
		local current = progressTable[challenge.id] or 0
		table.insert(result, {
			challenge = challenge,
			progress = current,
			completed = current >= challenge.targetAmount,
		})
	end

	return result
end

--[[
	Get player progress
]]
function ProgressionManager.GetPlayerProgress(player: Player): PlayerProgress?
	return playerProgress[player]
end

--[[
	Get player level
]]
function ProgressionManager.GetPlayerLevel(player: Player): number
	local progress = playerProgress[player]
	return progress and progress.level or 1
end

--[[
	Reset for new season (would be called externally)
]]
function ProgressionManager.ResetSeason()
	-- This would reset seasonal content
	-- Keep lifetime progress, reset seasonal challenges
	print("[ProgressionManager] Season reset")
end

return ProgressionManager
