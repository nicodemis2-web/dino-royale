--!strict
--[[
	BattlePassManager.lua
	=====================
	Server-side Battle Pass progression and reward management
	Based on GDD Section 8.1: Battle Pass System
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Events = require(ReplicatedStorage.Shared.Events)
local BattlePassData = require(ReplicatedStorage.Shared.BattlePassData)

local BattlePassManager = {}

-- Types
export type PlayerBattlePass = {
	seasonNumber: number,
	xp: number,
	tier: number,
	isPremium: boolean,
	claimedRewards: { [string]: boolean },
	purchaseDate: number?,
}

-- State
local playerBattlePasses: { [Player]: PlayerBattlePass } = {}
local isInitialized = false

-- Signals
local onTierUp = Instance.new("BindableEvent")
local onRewardClaimed = Instance.new("BindableEvent")
local onPremiumPurchased = Instance.new("BindableEvent")

BattlePassManager.OnTierUp = onTierUp.Event
BattlePassManager.OnRewardClaimed = onRewardClaimed.Event
BattlePassManager.OnPremiumPurchased = onPremiumPurchased.Event

--[[
	Initialize the battle pass manager
]]
function BattlePassManager.Initialize()
	if isInitialized then return end
	isInitialized = true

	print("[BattlePassManager] Initializing...")

	-- Setup client events
	Events.OnServerEvent("BattlePass", "ClaimReward", function(player, data)
		if typeof(data) == "table" then
			BattlePassManager.ClaimReward(player, data.tier, data.isPremium)
		end
	end)

	Events.OnServerEvent("BattlePass", "GetProgress", function(player)
		BattlePassManager.SendBattlePassData(player)
	end)

	-- Setup player tracking
	Players.PlayerAdded:Connect(function(player)
		BattlePassManager.InitializePlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		BattlePassManager.SavePlayer(player)
		BattlePassManager.CleanupPlayer(player)
	end)

	-- Initialize existing players
	for _, player in ipairs(Players:GetPlayers()) do
		BattlePassManager.InitializePlayer(player)
	end

	print("[BattlePassManager] Initialized")
end

--[[
	Initialize player battle pass
]]
function BattlePassManager.InitializePlayer(player: Player)
	-- TODO: Load from DataStore
	local battlePass: PlayerBattlePass = {
		seasonNumber = BattlePassData.CurrentSeason.seasonNumber,
		xp = 0,
		tier = 0,
		isPremium = false,
		claimedRewards = {},
	}

	playerBattlePasses[player] = battlePass

	-- Send initial data to client
	task.defer(function()
		BattlePassManager.SendBattlePassData(player)
	end)
end

--[[
	Save player battle pass data
]]
function BattlePassManager.SavePlayer(player: Player)
	local battlePass = playerBattlePasses[player]
	if not battlePass then return end

	-- TODO: Save to DataStore
	print(`[BattlePassManager] Saving battle pass for {player.Name}`)
end

--[[
	Cleanup player
]]
function BattlePassManager.CleanupPlayer(player: Player)
	playerBattlePasses[player] = nil
end

--[[
	Add XP to player's battle pass
]]
function BattlePassManager.AddXP(player: Player, amount: number, source: string?)
	local battlePass = playerBattlePasses[player]
	if not battlePass then return end

	-- Check if season is current
	if battlePass.seasonNumber ~= BattlePassData.CurrentSeason.seasonNumber then
		-- Reset for new season
		battlePass.seasonNumber = BattlePassData.CurrentSeason.seasonNumber
		battlePass.xp = 0
		battlePass.tier = 0
		battlePass.claimedRewards = {}
		battlePass.isPremium = false
	end

	local previousTier = battlePass.tier
	battlePass.xp = battlePass.xp + amount
	battlePass.tier = BattlePassData.GetTierForXP(battlePass.xp)

	-- Check for tier ups
	if battlePass.tier > previousTier then
		for tier = previousTier + 1, battlePass.tier do
			onTierUp:Fire(player, tier)

			-- Notify client
			Events.FireClient(player, "BattlePass", "TierUp", {
				tier = tier,
				xp = battlePass.xp,
			})
		end
	end

	-- Send XP update
	Events.FireClient(player, "BattlePass", "XPGained", {
		amount = amount,
		total = battlePass.xp,
		tier = battlePass.tier,
		progress = BattlePassData.GetTierProgress(battlePass.xp),
		source = source,
	})

	print(`[BattlePassManager] {player.Name} gained {amount} XP (total: {battlePass.xp}, tier: {battlePass.tier})`)
end

--[[
	Claim a reward
]]
function BattlePassManager.ClaimReward(player: Player, tier: number, isPremiumReward: boolean)
	local battlePass = playerBattlePasses[player]
	if not battlePass then return end

	-- Validate tier
	if tier > battlePass.tier then
		warn(`[BattlePassManager] {player.Name} tried to claim tier {tier} but is only tier {battlePass.tier}`)
		return
	end

	-- Check premium requirement
	if isPremiumReward and not battlePass.isPremium then
		warn(`[BattlePassManager] {player.Name} tried to claim premium reward without premium pass`)
		return
	end

	-- Get reward
	local tierData = BattlePassData.Tiers[tier]
	if not tierData then return end

	local reward = isPremiumReward and tierData.premiumReward or tierData.freeReward
	if not reward then return end

	-- Check if already claimed
	local claimKey = `{tier}_{isPremiumReward and "premium" or "free"}`
	if battlePass.claimedRewards[claimKey] then
		warn(`[BattlePassManager] {player.Name} already claimed reward {claimKey}`)
		return
	end

	-- Grant reward
	BattlePassManager.GrantReward(player, reward)

	-- Mark as claimed
	battlePass.claimedRewards[claimKey] = true

	-- Notify
	Events.FireClient(player, "BattlePass", "RewardClaimed", {
		tier = tier,
		isPremium = isPremiumReward,
		reward = reward,
	})

	onRewardClaimed:Fire(player, tier, reward)
	print(`[BattlePassManager] {player.Name} claimed {reward.name}`)
end

--[[
	Grant a reward to player
]]
function BattlePassManager.GrantReward(player: Player, reward: BattlePassData.BattlePassReward)
	-- TODO: Integrate with inventory/cosmetics system
	if reward.rewardType == "Currency" then
		-- Add premium currency
		-- CurrencyManager.AddCurrency(player, "DinoCoins", tonumber(reward.name:match("%d+")) or 0)
		print(`[BattlePassManager] Granted currency: {reward.name}`)

	elseif reward.rewardType == "XPBoost" then
		-- Apply XP boost
		-- ProgressionManager.ApplyXPBoost(player, boost)
		print(`[BattlePassManager] Applied XP boost: {reward.name}`)

	elseif reward.rewardType == "Skin" then
		-- Unlock skin
		-- CosmeticsManager.UnlockSkin(player, reward.id)
		print(`[BattlePassManager] Unlocked skin: {reward.name}`)

	elseif reward.rewardType == "Emote" then
		-- Unlock emote
		-- CosmeticsManager.UnlockEmote(player, reward.id)
		print(`[BattlePassManager] Unlocked emote: {reward.name}`)

	elseif reward.rewardType == "Glider" then
		-- Unlock glider
		-- CosmeticsManager.UnlockGlider(player, reward.id)
		print(`[BattlePassManager] Unlocked glider: {reward.name}`)

	elseif reward.rewardType == "BackBling" then
		-- Unlock back bling
		-- CosmeticsManager.UnlockBackBling(player, reward.id)
		print(`[BattlePassManager] Unlocked back bling: {reward.name}`)

	elseif reward.rewardType == "Trail" then
		-- Unlock trail
		-- CosmeticsManager.UnlockTrail(player, reward.id)
		print(`[BattlePassManager] Unlocked trail: {reward.name}`)

	elseif reward.rewardType == "WeaponSkin" then
		-- Unlock weapon skin
		-- CosmeticsManager.UnlockWeaponSkin(player, reward.id)
		print(`[BattlePassManager] Unlocked weapon skin: {reward.name}`)

	elseif reward.rewardType == "Banner" then
		-- Unlock banner
		-- CosmeticsManager.UnlockBanner(player, reward.id)
		print(`[BattlePassManager] Unlocked banner: {reward.name}`)
	end
end

--[[
	Purchase premium battle pass
]]
function BattlePassManager.PurchasePremium(player: Player)
	local battlePass = playerBattlePasses[player]
	if not battlePass then return end

	if battlePass.isPremium then
		warn(`[BattlePassManager] {player.Name} already has premium`)
		return
	end

	-- TODO: Integrate with Roblox marketplace/purchase system
	-- For now, just grant premium
	battlePass.isPremium = true
	battlePass.purchaseDate = os.time()

	Events.FireClient(player, "BattlePass", "PremiumPurchased", {
		seasonNumber = battlePass.seasonNumber,
	})

	onPremiumPurchased:Fire(player)
	print(`[BattlePassManager] {player.Name} purchased premium battle pass`)

	-- Send updated data
	BattlePassManager.SendBattlePassData(player)
end

--[[
	Purchase additional tiers
]]
function BattlePassManager.PurchaseTiers(player: Player, amount: number)
	local battlePass = playerBattlePasses[player]
	if not battlePass then return end

	-- Validate amount
	amount = math.clamp(amount, 1, 100 - battlePass.tier)
	if amount <= 0 then return end

	-- TODO: Integrate with currency system
	-- local cost = amount * 150 -- 150 Robux per tier
	-- if not CurrencyManager.Spend(player, "Robux", cost) then return end

	-- Calculate XP needed for target tier
	local targetTier = battlePass.tier + amount
	local targetXP = BattlePassData.GetXPForTier(targetTier)
	local xpToAdd = targetXP - battlePass.xp

	BattlePassManager.AddXP(player, xpToAdd, "TierPurchase")

	print(`[BattlePassManager] {player.Name} purchased {amount} tiers`)
end

--[[
	Send battle pass data to client
]]
function BattlePassManager.SendBattlePassData(player: Player)
	local battlePass = playerBattlePasses[player]
	if not battlePass then return end

	Events.FireClient(player, "BattlePass", "DataUpdate", {
		seasonNumber = battlePass.seasonNumber,
		seasonName = BattlePassData.CurrentSeason.seasonName,
		seasonTheme = BattlePassData.CurrentSeason.theme,
		xp = battlePass.xp,
		tier = battlePass.tier,
		progress = BattlePassData.GetTierProgress(battlePass.xp),
		isPremium = battlePass.isPremium,
		claimedRewards = battlePass.claimedRewards,
		maxTier = 100,
		premiumPrice = BattlePassData.CurrentSeason.premiumPrice,
	})
end

--[[
	Get player battle pass data
]]
function BattlePassManager.GetPlayerData(player: Player): PlayerBattlePass?
	return playerBattlePasses[player]
end

--[[
	Check if player has premium
]]
function BattlePassManager.HasPremium(player: Player): boolean
	local battlePass = playerBattlePasses[player]
	return battlePass and battlePass.isPremium or false
end

--[[
	Get player tier
]]
function BattlePassManager.GetTier(player: Player): number
	local battlePass = playerBattlePasses[player]
	return battlePass and battlePass.tier or 0
end

--[[
	Reset for new season
]]
function BattlePassManager.ResetForNewSeason()
	for player, battlePass in pairs(playerBattlePasses) do
		battlePass.seasonNumber = BattlePassData.CurrentSeason.seasonNumber
		battlePass.xp = 0
		battlePass.tier = 0
		battlePass.claimedRewards = {}
		battlePass.isPremium = false
		battlePass.purchaseDate = nil

		BattlePassManager.SendBattlePassData(player)
	end

	print("[BattlePassManager] Reset all players for new season")
end

return BattlePassManager
