--!strict
--[[
	ProgressionData.lua
	===================
	XP, level, and progression data for Dino Royale
	Based on GDD Section 8: Progression System
]]

export type XPSource =
	"Kill" |
	"DinoKill" |
	"Assist" |
	"Revive" |
	"Reboot" |
	"Placement" |
	"Survival" |
	"DamageDealt" |
	"Challenge" |
	"DailyBonus" |
	"FirstMatch"

export type RewardType = "Skin" | "Emote" | "Trail" | "Spray" | "Banner" | "Currency" | "Title"

export type LevelReward = {
	level: number,
	rewardType: RewardType,
	rewardId: string,
	rewardName: string,
	description: string,
}

export type ChallengeType = "Daily" | "Weekly" | "Seasonal" | "Lifetime"

export type Challenge = {
	id: string,
	name: string,
	description: string,
	challengeType: ChallengeType,
	requirement: string, -- e.g., "kills", "wins", "dino_kills"
	targetAmount: number,
	xpReward: number,
	additionalReward: LevelReward?,
}

local ProgressionData = {}

-- XP values for different actions
ProgressionData.XPValues = {
	Kill = 100,
	DinoKill = 25,
	Assist = 50,
	Revive = 75,
	Reboot = 100,
	Placement = 10, -- Per player outlasted
	Survival = 5, -- Per minute survived
	DamageDealt = 1, -- Per 10 damage
	Challenge = 0, -- Varies by challenge
	DailyBonus = 500,
	FirstMatch = 200,
}

-- Bonus XP multipliers
ProgressionData.BonusMultipliers = {
	-- Placement bonuses
	Victory = 5.0,
	Top5 = 2.0,
	Top10 = 1.5,
	Top25 = 1.2,

	-- Streak bonuses
	KillStreak3 = 1.5,
	KillStreak5 = 2.0,
	KillStreak10 = 3.0,

	-- Special kills
	DinoKillLegendary = 4.0,
	DinoKillEpic = 2.0,
	DinoKillRare = 1.5,
}

-- XP required per level (cumulative)
ProgressionData.LevelXP = {}
local baseXP = 1000
local xpMultiplier = 1.08

for level = 1, 100 do
	if level == 1 then
		ProgressionData.LevelXP[level] = 0
	else
		local requiredXP = math.floor(baseXP * (xpMultiplier ^ (level - 2)))
		ProgressionData.LevelXP[level] = ProgressionData.LevelXP[level - 1] + requiredXP
	end
end

-- Level rewards
ProgressionData.LevelRewards = {
	-- Early levels
	{ level = 2, rewardType = "Currency", rewardId = "coins_100", rewardName = "100 Coins", description = "Starter coins" },
	{ level = 5, rewardType = "Spray", rewardId = "spray_dino_print", rewardName = "Dino Footprint", description = "Basic spray" },
	{ level = 10, rewardType = "Skin", rewardId = "skin_jungle_camo", rewardName = "Jungle Camo", description = "Forest camouflage outfit" },
	{ level = 15, rewardType = "Emote", rewardId = "emote_roar", rewardName = "Dino Roar", description = "Mimic a dinosaur roar" },
	{ level = 20, rewardType = "Trail", rewardId = "trail_leaf", rewardName = "Leaf Trail", description = "Leaves follow your path" },
	{ level = 25, rewardType = "Banner", rewardId = "banner_raptor", rewardName = "Raptor Banner", description = "Display your raptor pride" },

	-- Mid levels
	{ level = 30, rewardType = "Skin", rewardId = "skin_volcanic", rewardName = "Volcanic Suit", description = "Heat-resistant outfit" },
	{ level = 35, rewardType = "Title", rewardId = "title_hunter", rewardName = "Dino Hunter", description = "Show your hunting skills" },
	{ level = 40, rewardType = "Emote", rewardId = "emote_victory_dance", rewardName = "Victory Dance", description = "Celebrate in style" },
	{ level = 45, rewardType = "Trail", rewardId = "trail_ember", rewardName = "Ember Trail", description = "Fiery particles follow you" },
	{ level = 50, rewardType = "Skin", rewardId = "skin_gold", rewardName = "Golden Explorer", description = "Prestigious golden outfit" },

	-- High levels
	{ level = 60, rewardType = "Title", rewardId = "title_apex", rewardName = "Apex Predator", description = "Top of the food chain" },
	{ level = 70, rewardType = "Skin", rewardId = "skin_neon", rewardName = "Neon Survivor", description = "Futuristic neon outfit" },
	{ level = 80, rewardType = "Trail", rewardId = "trail_lightning", rewardName = "Lightning Trail", description = "Electrifying presence" },
	{ level = 90, rewardType = "Emote", rewardId = "emote_trex_stomp", rewardName = "T-Rex Stomp", description = "Ground-shaking display" },
	{ level = 100, rewardType = "Skin", rewardId = "skin_legendary", rewardName = "Legendary Survivor", description = "The ultimate achievement" },
}

-- Default challenges
ProgressionData.DailyChallenges = {
	{
		id = "daily_kills_5",
		name = "Hunter",
		description = "Eliminate 5 players",
		challengeType = "Daily",
		requirement = "kills",
		targetAmount = 5,
		xpReward = 500,
	},
	{
		id = "daily_dino_kills_3",
		name = "Dino Slayer",
		description = "Eliminate 3 dinosaurs",
		challengeType = "Daily",
		requirement = "dino_kills",
		targetAmount = 3,
		xpReward = 300,
	},
	{
		id = "daily_top10",
		name = "Survivor",
		description = "Place in the top 10",
		challengeType = "Daily",
		requirement = "top10",
		targetAmount = 1,
		xpReward = 400,
	},
	{
		id = "daily_damage_500",
		name = "Damage Dealer",
		description = "Deal 500 damage to players",
		challengeType = "Daily",
		requirement = "damage",
		targetAmount = 500,
		xpReward = 350,
	},
	{
		id = "daily_loot_10",
		name = "Scavenger",
		description = "Loot 10 items",
		challengeType = "Daily",
		requirement = "loot",
		targetAmount = 10,
		xpReward = 200,
	},
}

ProgressionData.WeeklyChallenges = {
	{
		id = "weekly_wins_3",
		name = "Champion",
		description = "Win 3 matches",
		challengeType = "Weekly",
		requirement = "wins",
		targetAmount = 3,
		xpReward = 2000,
	},
	{
		id = "weekly_kills_50",
		name = "Eliminator",
		description = "Eliminate 50 players",
		challengeType = "Weekly",
		requirement = "kills",
		targetAmount = 50,
		xpReward = 1500,
	},
	{
		id = "weekly_legendary_dino",
		name = "Legendary Hunter",
		description = "Eliminate a Legendary dinosaur",
		challengeType = "Weekly",
		requirement = "legendary_dino_kill",
		targetAmount = 1,
		xpReward = 1000,
	},
	{
		id = "weekly_revives_5",
		name = "Team Player",
		description = "Revive 5 teammates",
		challengeType = "Weekly",
		requirement = "revives",
		targetAmount = 5,
		xpReward = 800,
	},
	{
		id = "weekly_biomes_all",
		name = "Explorer",
		description = "Visit all 6 biomes in one match",
		challengeType = "Weekly",
		requirement = "biomes_visited",
		targetAmount = 6,
		xpReward = 600,
	},
}

-- Lifetime achievements
ProgressionData.LifetimeChallenges = {
	{
		id = "lifetime_wins_100",
		name = "Century Champion",
		description = "Win 100 matches",
		challengeType = "Lifetime",
		requirement = "wins",
		targetAmount = 100,
		xpReward = 10000,
		additionalReward = {
			level = 0,
			rewardType = "Title",
			rewardId = "title_century",
			rewardName = "Century Champion",
			description = "100 victories achieved",
		},
	},
	{
		id = "lifetime_kills_1000",
		name = "Thousand Eliminations",
		description = "Eliminate 1000 players",
		challengeType = "Lifetime",
		requirement = "kills",
		targetAmount = 1000,
		xpReward = 5000,
		additionalReward = {
			level = 0,
			rewardType = "Title",
			rewardId = "title_eliminator",
			rewardName = "The Eliminator",
			description = "1000 eliminations",
		},
	},
	{
		id = "lifetime_trex_10",
		name = "T-Rex Terminator",
		description = "Eliminate 10 T-Rex",
		challengeType = "Lifetime",
		requirement = "trex_kills",
		targetAmount = 10,
		xpReward = 8000,
		additionalReward = {
			level = 0,
			rewardType = "Skin",
			rewardId = "skin_trex_hunter",
			rewardName = "T-Rex Hunter",
			description = "Prove your dominance",
		},
	},
}

-- Get level from XP
function ProgressionData.GetLevelFromXP(xp: number): number
	for level = 100, 1, -1 do
		if xp >= ProgressionData.LevelXP[level] then
			return level
		end
	end
	return 1
end

-- Get XP needed for next level
function ProgressionData.GetXPForNextLevel(currentLevel: number): number
	if currentLevel >= 100 then
		return 0
	end
	return ProgressionData.LevelXP[currentLevel + 1]
end

-- Get progress to next level (0-1)
function ProgressionData.GetLevelProgress(xp: number): number
	local level = ProgressionData.GetLevelFromXP(xp)
	if level >= 100 then
		return 1
	end

	local currentLevelXP = ProgressionData.LevelXP[level]
	local nextLevelXP = ProgressionData.LevelXP[level + 1]
	local xpIntoLevel = xp - currentLevelXP
	local xpNeeded = nextLevelXP - currentLevelXP

	return math.clamp(xpIntoLevel / xpNeeded, 0, 1)
end

-- Get rewards for a level
function ProgressionData.GetRewardsForLevel(level: number): { LevelReward }
	local rewards = {}
	for _, reward in ipairs(ProgressionData.LevelRewards) do
		if reward.level == level then
			table.insert(rewards, reward)
		end
	end
	return rewards
end

-- Get all unclaimed rewards up to level
function ProgressionData.GetUnclaimedRewards(currentLevel: number, claimedLevels: { number }): { LevelReward }
	local rewards = {}
	local claimedSet = {}
	for _, level in ipairs(claimedLevels) do
		claimedSet[level] = true
	end

	for _, reward in ipairs(ProgressionData.LevelRewards) do
		if reward.level <= currentLevel and not claimedSet[reward.level] then
			table.insert(rewards, reward)
		end
	end

	return rewards
end

-- Calculate XP for placement
function ProgressionData.CalculatePlacementXP(placement: number, totalPlayers: number): number
	local outlasted = totalPlayers - placement
	local baseXP = outlasted * ProgressionData.XPValues.Placement

	-- Apply placement multiplier
	local multiplier = 1.0
	if placement == 1 then
		multiplier = ProgressionData.BonusMultipliers.Victory
	elseif placement <= 5 then
		multiplier = ProgressionData.BonusMultipliers.Top5
	elseif placement <= 10 then
		multiplier = ProgressionData.BonusMultipliers.Top10
	elseif placement <= 25 then
		multiplier = ProgressionData.BonusMultipliers.Top25
	end

	return math.floor(baseXP * multiplier)
end

return ProgressionData
