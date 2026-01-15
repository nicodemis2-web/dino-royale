--!strict
--[[
	BattlePassData.lua
	==================
	Battle Pass reward tiers and configuration
	Based on GDD Section 8.1: Battle Pass System
]]

export type RewardType = "Skin" | "WeaponSkin" | "Emote" | "Glider" | "BackBling" | "Trail" | "Banner" | "Currency" | "XPBoost"

export type BattlePassReward = {
	id: string,
	name: string,
	description: string,
	rewardType: RewardType,
	rarity: string,
	isPremium: boolean,
	iconId: string?,
	assetId: string?,
}

export type BattlePassTier = {
	tier: number,
	xpRequired: number,
	freeReward: BattlePassReward?,
	premiumReward: BattlePassReward?,
}

export type SeasonInfo = {
	seasonNumber: number,
	seasonName: string,
	theme: string,
	startDate: number,
	endDate: number,
	premiumPrice: number, -- In Robux
}

local BattlePassData = {}

-- Current season info
BattlePassData.CurrentSeason = {
	seasonNumber = 1,
	seasonName = "Welcome to the Park",
	theme = "Jurassic",
	startDate = 1704067200, -- Example timestamp
	endDate = 1710115200,
	premiumPrice = 950,
}

-- XP per tier (increases as tiers progress)
local function GetXPForTier(tier: number): number
	if tier <= 10 then
		return 1000
	elseif tier <= 25 then
		return 1500
	elseif tier <= 50 then
		return 2000
	elseif tier <= 75 then
		return 2500
	else
		return 3000
	end
end

-- Generate reward definitions
local Rewards: { [string]: BattlePassReward } = {
	-- Free Track Rewards
	Spray_DinoFootprint = {
		id = "Spray_DinoFootprint",
		name = "Dino Footprint Spray",
		description = "Leave your mark with dinosaur tracks",
		rewardType = "Banner",
		rarity = "Common",
		isPremium = false,
	},
	Banner_Survivor = {
		id = "Banner_Survivor",
		name = "Survivor Banner",
		description = "Show you survived the island",
		rewardType = "Banner",
		rarity = "Common",
		isPremium = false,
	},
	XPBoost_10 = {
		id = "XPBoost_10",
		name = "10% XP Boost",
		description = "Earn 10% more XP for the rest of the season",
		rewardType = "XPBoost",
		rarity = "Uncommon",
		isPremium = false,
	},
	Emote_DinoRoar = {
		id = "Emote_DinoRoar",
		name = "Dino Roar",
		description = "Let out a mighty roar",
		rewardType = "Emote",
		rarity = "Uncommon",
		isPremium = false,
	},
	Skin_ParkRanger = {
		id = "Skin_ParkRanger",
		name = "Park Ranger",
		description = "Standard issue ranger uniform",
		rewardType = "Skin",
		rarity = "Uncommon",
		isPremium = false,
	},
	Trail_Footprints = {
		id = "Trail_Footprints",
		name = "Footprint Trail",
		description = "Leave tracks wherever you go",
		rewardType = "Trail",
		rarity = "Rare",
		isPremium = false,
	},
	Glider_Parachute = {
		id = "Glider_Parachute",
		name = "Rescue Parachute",
		description = "Standard deployment chute",
		rewardType = "Glider",
		rarity = "Rare",
		isPremium = false,
	},
	WeaponSkin_JungleCamo = {
		id = "WeaponSkin_JungleCamo",
		name = "Jungle Camo",
		description = "Blend into the environment",
		rewardType = "WeaponSkin",
		rarity = "Rare",
		isPremium = false,
	},
	Skin_Scientist = {
		id = "Skin_Scientist",
		name = "Lab Scientist",
		description = "InGen research team attire",
		rewardType = "Skin",
		rarity = "Epic",
		isPremium = false,
	},
	Emote_VictoryDance = {
		id = "Emote_VictoryDance",
		name = "Victory Dance",
		description = "Celebrate your wins in style",
		rewardType = "Emote",
		rarity = "Epic",
		isPremium = false,
	},

	-- Premium Track Rewards
	Skin_VelociraptorHunter = {
		id = "Skin_VelociraptorHunter",
		name = "Velociraptor Hunter",
		description = "Tactical gear for raptor encounters",
		rewardType = "Skin",
		rarity = "Uncommon",
		isPremium = true,
	},
	Currency_200 = {
		id = "Currency_200",
		name = "200 Dino Coins",
		description = "Premium currency for the shop",
		rewardType = "Currency",
		rarity = "Uncommon",
		isPremium = true,
	},
	BackBling_BabyRaptor = {
		id = "BackBling_BabyRaptor",
		name = "Baby Raptor",
		description = "A friendly companion for your adventures",
		rewardType = "BackBling",
		rarity = "Rare",
		isPremium = true,
	},
	Glider_PteranodonWings = {
		id = "Glider_PteranodonWings",
		name = "Pteranodon Wings",
		description = "Soar like a prehistoric flyer",
		rewardType = "Glider",
		rarity = "Rare",
		isPremium = true,
	},
	WeaponSkin_AmberGold = {
		id = "WeaponSkin_AmberGold",
		name = "Amber Gold",
		description = "Preserved in prehistoric amber",
		rewardType = "WeaponSkin",
		rarity = "Epic",
		isPremium = true,
	},
	Skin_DinoTamer = {
		id = "Skin_DinoTamer",
		name = "Dino Tamer",
		description = "Master of the prehistoric beasts",
		rewardType = "Skin",
		rarity = "Epic",
		isPremium = true,
	},
	Currency_300 = {
		id = "Currency_300",
		name = "300 Dino Coins",
		description = "Premium currency for the shop",
		rewardType = "Currency",
		rarity = "Epic",
		isPremium = true,
	},
	Emote_TRexStomp = {
		id = "Emote_TRexStomp",
		name = "T-Rex Stomp",
		description = "Make the ground shake",
		rewardType = "Emote",
		rarity = "Epic",
		isPremium = true,
	},
	Trail_AmberParticles = {
		id = "Trail_AmberParticles",
		name = "Amber Trail",
		description = "Leave a trail of glowing amber",
		rewardType = "Trail",
		rarity = "Epic",
		isPremium = true,
	},
	BackBling_DinoEgg = {
		id = "BackBling_DinoEgg",
		name = "Mysterious Egg",
		description = "What will hatch?",
		rewardType = "BackBling",
		rarity = "Epic",
		isPremium = true,
	},
	Glider_VolcanicAsh = {
		id = "Glider_VolcanicAsh",
		name = "Volcanic Glider",
		description = "Born from the island's fury",
		rewardType = "Glider",
		rarity = "Legendary",
		isPremium = true,
	},
	Skin_ApexPredator = {
		id = "Skin_ApexPredator",
		name = "Apex Predator",
		description = "The ultimate hunter of Isla Primordial",
		rewardType = "Skin",
		rarity = "Legendary",
		isPremium = true,
	},
	BackBling_BabyTRex = {
		id = "BackBling_BabyTRex",
		name = "Baby T-Rex",
		description = "Your very own king of the dinosaurs",
		rewardType = "BackBling",
		rarity = "Legendary",
		isPremium = true,
	},
}

-- Battle Pass tiers (100 total)
BattlePassData.Tiers = {}

-- Generate all 100 tiers
local freeRewardSchedule = {
	[1] = "Spray_DinoFootprint",
	[5] = "Banner_Survivor",
	[10] = "XPBoost_10",
	[15] = "Emote_DinoRoar",
	[20] = "Skin_ParkRanger",
	[30] = "Trail_Footprints",
	[40] = "Glider_Parachute",
	[50] = "WeaponSkin_JungleCamo",
	[70] = "Skin_Scientist",
	[90] = "Emote_VictoryDance",
}

local premiumRewardSchedule = {
	[1] = "Skin_VelociraptorHunter",
	[5] = "Currency_200",
	[10] = "BackBling_BabyRaptor",
	[15] = "Glider_PteranodonWings",
	[20] = "WeaponSkin_AmberGold",
	[25] = "Skin_DinoTamer",
	[30] = "Currency_300",
	[35] = "Emote_TRexStomp",
	[40] = "Trail_AmberParticles",
	[50] = "BackBling_DinoEgg",
	[60] = "Currency_200",
	[70] = "Glider_VolcanicAsh",
	[80] = "Currency_300",
	[90] = "BackBling_BabyTRex",
	[100] = "Skin_ApexPredator",
}

local cumulativeXP = 0
for tier = 1, 100 do
	local tierXP = GetXPForTier(tier)
	cumulativeXP = cumulativeXP + tierXP

	local freeRewardId = freeRewardSchedule[tier]
	local premiumRewardId = premiumRewardSchedule[tier]

	table.insert(BattlePassData.Tiers, {
		tier = tier,
		xpRequired = cumulativeXP,
		freeReward = freeRewardId and Rewards[freeRewardId] or nil,
		premiumReward = premiumRewardId and Rewards[premiumRewardId] or nil,
	})
end

-- Get tier for XP amount
function BattlePassData.GetTierForXP(xp: number): number
	for i, tier in ipairs(BattlePassData.Tiers) do
		if xp < tier.xpRequired then
			return i - 1
		end
	end
	return 100
end

-- Get XP required for specific tier
function BattlePassData.GetXPForTier(tier: number): number
	if tier <= 0 then return 0 end
	if tier > 100 then return BattlePassData.Tiers[100].xpRequired end
	return BattlePassData.Tiers[tier].xpRequired
end

-- Get progress to next tier (0-1)
function BattlePassData.GetTierProgress(xp: number): number
	local currentTier = BattlePassData.GetTierForXP(xp)
	if currentTier >= 100 then return 1 end

	local currentTierXP = currentTier > 0 and BattlePassData.Tiers[currentTier].xpRequired or 0
	local nextTierXP = BattlePassData.Tiers[currentTier + 1].xpRequired
	local xpIntoTier = xp - currentTierXP
	local xpNeeded = nextTierXP - currentTierXP

	return math.clamp(xpIntoTier / xpNeeded, 0, 1)
end

-- Get all rewards up to a tier
function BattlePassData.GetRewardsUpToTier(tier: number, isPremium: boolean): { BattlePassReward }
	local rewards = {}
	for i = 1, math.min(tier, 100) do
		local tierData = BattlePassData.Tiers[i]
		if tierData.freeReward then
			table.insert(rewards, tierData.freeReward)
		end
		if isPremium and tierData.premiumReward then
			table.insert(rewards, tierData.premiumReward)
		end
	end
	return rewards
end

-- Get reward by ID
function BattlePassData.GetReward(rewardId: string): BattlePassReward?
	return Rewards[rewardId]
end

-- Get total XP required for max tier
function BattlePassData.GetMaxXP(): number
	return BattlePassData.Tiers[100].xpRequired
end

return BattlePassData
