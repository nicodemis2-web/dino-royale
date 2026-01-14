--!strict
--[[
	RankedData.lua
	==============
	Ranked mode configuration and types
	Based on GDD Section 7.2: Ranked Leagues
]]

export type RankTier = {
	id: string,
	name: string,
	icon: string,
	minRP: number,
	maxRP: number,
	divisions: number, -- Number of divisions within tier (e.g., Gold I, Gold II, etc.)
	color: Color3,
}

export type PlayerRank = {
	tier: string,
	division: number,
	rp: number, -- Rank Points
	peakTier: string,
	peakDivision: number,
	peakRP: number,
	matchesPlayed: number,
	wins: number,
	top10s: number,
	avgPlacement: number,
}

export type SeasonInfo = {
	id: string,
	name: string,
	startTime: number,
	endTime: number,
	rewards: { [string]: { string } }, -- Tier -> Reward IDs
}

local RankedData = {}

-- Rank tiers from lowest to highest
RankedData.Tiers: { RankTier } = {
	{
		id = "Bronze",
		name = "Bronze",
		icon = "rbxassetid://bronze_rank",
		minRP = 0,
		maxRP = 999,
		divisions = 3,
		color = Color3.fromRGB(205, 127, 50),
	},
	{
		id = "Silver",
		name = "Silver",
		icon = "rbxassetid://silver_rank",
		minRP = 1000,
		maxRP = 2499,
		divisions = 3,
		color = Color3.fromRGB(192, 192, 192),
	},
	{
		id = "Gold",
		name = "Gold",
		icon = "rbxassetid://gold_rank",
		minRP = 2500,
		maxRP = 4499,
		divisions = 3,
		color = Color3.fromRGB(255, 215, 0),
	},
	{
		id = "Platinum",
		name = "Platinum",
		icon = "rbxassetid://platinum_rank",
		minRP = 4500,
		maxRP = 6999,
		divisions = 3,
		color = Color3.fromRGB(229, 228, 226),
	},
	{
		id = "Diamond",
		name = "Diamond",
		icon = "rbxassetid://diamond_rank",
		minRP = 7000,
		maxRP = 9999,
		divisions = 3,
		color = Color3.fromRGB(185, 242, 255),
	},
	{
		id = "Master",
		name = "Master",
		icon = "rbxassetid://master_rank",
		minRP = 10000,
		maxRP = 14999,
		divisions = 1,
		color = Color3.fromRGB(147, 112, 219),
	},
	{
		id = "Apex",
		name = "Apex Predator",
		icon = "rbxassetid://apex_rank",
		minRP = 15000,
		maxRP = 999999,
		divisions = 1,
		color = Color3.fromRGB(255, 50, 50),
	},
}

-- RP gains/losses based on placement
RankedData.PlacementRP = {
	[1] = 125,   -- Victory
	[2] = 95,
	[3] = 80,
	[4] = 70,
	[5] = 60,
	[6] = 50,
	[7] = 40,
	[8] = 35,
	[9] = 30,
	[10] = 25,
	[11] = 20,
	[12] = 15,
	[13] = 15,
	[14] = 15,
	[15] = 10,
	[16] = 10,
	[17] = 10,
	[18] = 10,
	[19] = 10,
	[20] = 5,
	-- 21-40: 0 RP
	-- 41+: Negative RP
}

-- RP per elimination
RankedData.KillRP = 15

-- Entry cost by tier (deducted at match start)
RankedData.EntryCost = {
	Bronze = 0,
	Silver = 12,
	Gold = 24,
	Platinum = 36,
	Diamond = 48,
	Master = 60,
	Apex = 60,
}

-- Minimum matches to get ranked
RankedData.PlacementMatches = 10

-- Season duration in days
RankedData.SeasonDurationDays = 60

-- Season rewards by tier achieved
RankedData.SeasonRewards = {
	Bronze = { "Spray_Bronze", "Badge_Bronze" },
	Silver = { "Spray_Silver", "Badge_Silver", "Charm_Silver" },
	Gold = { "Spray_Gold", "Badge_Gold", "Charm_Gold", "Trail_Gold" },
	Platinum = { "Spray_Platinum", "Badge_Platinum", "Charm_Platinum", "Trail_Platinum" },
	Diamond = { "Spray_Diamond", "Badge_Diamond", "Charm_Diamond", "Trail_Diamond", "Skin_DiamondElite" },
	Master = { "Spray_Master", "Badge_Master", "Charm_Master", "Trail_Master", "Skin_MasterElite" },
	Apex = { "Spray_Apex", "Badge_Apex", "Charm_Apex", "Trail_Apex", "Skin_ApexPredator", "Glider_ApexWings" },
}

-- Division names (I, II, III from highest to lowest within tier)
RankedData.DivisionNames = { "I", "II", "III" }

-- Get tier for RP amount
function RankedData.GetTierForRP(rp: number): RankTier
	for i = #RankedData.Tiers, 1, -1 do
		local tier = RankedData.Tiers[i]
		if rp >= tier.minRP then
			return tier
		end
	end
	return RankedData.Tiers[1]
end

-- Get tier by ID
function RankedData.GetTier(tierId: string): RankTier?
	for _, tier in ipairs(RankedData.Tiers) do
		if tier.id == tierId then
			return tier
		end
	end
	return nil
end

-- Get division within tier (1 = highest, 3 = lowest)
function RankedData.GetDivision(rp: number, tier: RankTier): number
	if tier.divisions == 1 then
		return 1
	end

	local rpInTier = rp - tier.minRP
	local rpPerDivision = (tier.maxRP - tier.minRP + 1) / tier.divisions

	local division = tier.divisions - math.floor(rpInTier / rpPerDivision)
	return math.clamp(division, 1, tier.divisions)
end

-- Get display name for rank (e.g., "Gold II")
function RankedData.GetRankDisplayName(rp: number): string
	local tier = RankedData.GetTierForRP(rp)
	local division = RankedData.GetDivision(rp, tier)

	if tier.divisions == 1 then
		return tier.name
	end

	return `{tier.name} {RankedData.DivisionNames[division]}`
end

-- Calculate RP change for a match
function RankedData.CalculateRPChange(placement: number, kills: number, currentTier: string): number
	-- Get entry cost
	local entryCost = RankedData.EntryCost[currentTier] or 0

	-- Get placement RP
	local placementRP = 0
	if placement <= 20 then
		placementRP = RankedData.PlacementRP[placement] or 0
	elseif placement > 40 then
		-- Negative RP for very low placements
		placementRP = -10 - math.floor((placement - 40) / 10) * 5
	end

	-- Get kill RP (capped at 10 kills)
	local killRP = math.min(kills, 10) * RankedData.KillRP

	-- Total change
	return placementRP + killRP - entryCost
end

-- Get RP needed for next division/tier
function RankedData.GetRPToNextRank(rp: number): number
	local tier = RankedData.GetTierForRP(rp)
	local division = RankedData.GetDivision(rp, tier)

	if tier.divisions == 1 then
		-- Top tier, just show progress
		return tier.maxRP - rp
	end

	local rpPerDivision = (tier.maxRP - tier.minRP + 1) / tier.divisions
	local divisionStart = tier.minRP + (tier.divisions - division) * rpPerDivision

	if division == 1 then
		-- Need to reach next tier
		return (tier.maxRP + 1) - rp
	else
		-- Need to reach next division
		return math.ceil(divisionStart + rpPerDivision - rp)
	end
end

-- Check if eligible for ranked
function RankedData.IsEligibleForRanked(matchesPlayed: number): boolean
	return matchesPlayed >= RankedData.PlacementMatches
end

-- Get tier index (for comparison)
function RankedData.GetTierIndex(tierId: string): number
	for i, tier in ipairs(RankedData.Tiers) do
		if tier.id == tierId then
			return i
		end
	end
	return 1
end

return RankedData
