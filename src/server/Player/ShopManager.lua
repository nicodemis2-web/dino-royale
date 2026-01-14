--!strict
--[[
	ShopManager.lua
	===============
	Server-side Item Shop management and purchases
	Based on GDD Section 8.3: Shop Structure
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Events = require(ReplicatedStorage.Shared.Events)
local ShopData = require(ReplicatedStorage.Shared.ShopData)

local ShopManager = {}

-- Types
export type PlayerInventory = {
	ownedItems: { [string]: boolean },
	purchaseHistory: { { itemId: string, timestamp: number, price: number } },
}

export type ShopState = {
	featuredItems: { string },
	dailyItems: { string },
	specialItems: { string },
	rotationTimestamp: number,
	nextRotation: number,
}

-- State
local playerInventories: { [Player]: PlayerInventory } = {}
local currentShopState: ShopState = {
	featuredItems = {},
	dailyItems = {},
	specialItems = {},
	rotationTimestamp = 0,
	nextRotation = 0,
}
local isInitialized = false

-- Constants
local DAILY_ROTATION_HOURS = 24
local FEATURED_ROTATION_HOURS = 48

-- Signals
local onPurchaseComplete = Instance.new("BindableEvent")
local onShopRotation = Instance.new("BindableEvent")

ShopManager.OnPurchaseComplete = onPurchaseComplete.Event
ShopManager.OnShopRotation = onShopRotation.Event

--[[
	Initialize the shop manager
]]
function ShopManager.Initialize()
	if isInitialized then return end
	isInitialized = true

	print("[ShopManager] Initializing...")

	-- Setup client events
	Events.OnServerEvent("Shop", function(player, action, data)
		if action == "Purchase" then
			ShopManager.PurchaseItem(player, data.itemId)
		elseif action == "RequestData" then
			ShopManager.SendShopData(player)
		elseif action == "RequestInventory" then
			ShopManager.SendInventory(player)
		end
	end)

	-- Setup player tracking
	Players.PlayerAdded:Connect(function(player)
		ShopManager.InitializePlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		ShopManager.SavePlayer(player)
		ShopManager.CleanupPlayer(player)
	end)

	-- Initialize existing players
	for _, player in ipairs(Players:GetPlayers()) do
		ShopManager.InitializePlayer(player)
	end

	-- Initialize shop rotation
	ShopManager.InitializeRotation()

	-- Start rotation timer
	task.spawn(function()
		while true do
			task.wait(60) -- Check every minute
			ShopManager.CheckRotation()
		end
	end)

	print("[ShopManager] Initialized")
end

--[[
	Initialize player inventory
]]
function ShopManager.InitializePlayer(player: Player)
	-- TODO: Load from DataStore
	local inventory: PlayerInventory = {
		ownedItems = {},
		purchaseHistory = {},
	}

	playerInventories[player] = inventory

	task.defer(function()
		ShopManager.SendInventory(player)
	end)
end

--[[
	Save player inventory
]]
function ShopManager.SavePlayer(player: Player)
	local inventory = playerInventories[player]
	if not inventory then return end

	-- TODO: Save to DataStore
	print(`[ShopManager] Saving inventory for {player.Name}`)
end

--[[
	Cleanup player
]]
function ShopManager.CleanupPlayer(player: Player)
	playerInventories[player] = nil
end

--[[
	Initialize shop rotation
]]
function ShopManager.InitializeRotation()
	local now = os.time()

	-- Featured items (rotate every 48 hours)
	currentShopState.featuredItems = ShopManager.SelectFeaturedItems()

	-- Daily items (rotate every 24 hours)
	currentShopState.dailyItems = ShopManager.SelectDailyItems()

	-- Special items (bundles/sales)
	currentShopState.specialItems = ShopManager.SelectSpecialItems()

	currentShopState.rotationTimestamp = now
	currentShopState.nextRotation = now + (DAILY_ROTATION_HOURS * 3600)

	print("[ShopManager] Shop rotation initialized")
end

--[[
	Select featured items for rotation
]]
function ShopManager.SelectFeaturedItems(): { string }
	local featured = {}
	local legendaryItems = ShopData.GetByRarity("Legendary")
	local epicItems = ShopData.GetByRarity("Epic")

	-- Pick 1-2 legendary items
	if #legendaryItems > 0 then
		local shuffled = ShopManager.ShuffleArray(legendaryItems)
		for i = 1, math.min(2, #shuffled) do
			table.insert(featured, shuffled[i].id)
		end
	end

	-- Pick 1-2 epic items
	if #epicItems > 0 then
		local shuffled = ShopManager.ShuffleArray(epicItems)
		for i = 1, math.min(2, #shuffled) do
			if not table.find(featured, shuffled[i].id) then
				table.insert(featured, shuffled[i].id)
			end
		end
	end

	return featured
end

--[[
	Select daily items for rotation
]]
function ShopManager.SelectDailyItems(): { string }
	local daily = {}
	local allItems = {}

	for id, item in pairs(ShopData.Catalog) do
		if item.itemType ~= "Bundle" and item.rarity ~= "Legendary" then
			table.insert(allItems, item)
		end
	end

	local shuffled = ShopManager.ShuffleArray(allItems)
	for i = 1, math.min(6, #shuffled) do
		table.insert(daily, shuffled[i].id)
	end

	return daily
end

--[[
	Select special items (bundles/sales)
]]
function ShopManager.SelectSpecialItems(): { string }
	local special = {}
	local bundles = ShopData.GetBundles()

	for _, bundle in ipairs(bundles) do
		table.insert(special, bundle.id)
	end

	return special
end

--[[
	Check if rotation is needed
]]
function ShopManager.CheckRotation()
	local now = os.time()

	if now >= currentShopState.nextRotation then
		ShopManager.RotateShop()
	end
end

--[[
	Rotate the shop
]]
function ShopManager.RotateShop()
	local now = os.time()

	-- Rotate daily items
	currentShopState.dailyItems = ShopManager.SelectDailyItems()

	-- Check if featured should rotate (every 48 hours)
	local hoursSinceRotation = (now - currentShopState.rotationTimestamp) / 3600
	if hoursSinceRotation >= FEATURED_ROTATION_HOURS then
		currentShopState.featuredItems = ShopManager.SelectFeaturedItems()
	end

	currentShopState.nextRotation = now + (DAILY_ROTATION_HOURS * 3600)

	-- Notify all players
	for _, player in ipairs(Players:GetPlayers()) do
		ShopManager.SendShopData(player)
	end

	onShopRotation:Fire()
	print("[ShopManager] Shop rotated")
end

--[[
	Purchase an item
]]
function ShopManager.PurchaseItem(player: Player, itemId: string)
	local inventory = playerInventories[player]
	if not inventory then return end

	-- Get item
	local item = ShopData.GetItem(itemId)
	if not item then
		warn(`[ShopManager] Item not found: {itemId}`)
		return
	end

	-- Check if already owned
	if inventory.ownedItems[itemId] then
		Events.FireClient(player, "Shop", "PurchaseFailed", {
			reason = "AlreadyOwned",
			itemId = itemId,
		})
		return
	end

	-- Check if item is in current rotation (for non-bundles)
	local inRotation = table.find(currentShopState.featuredItems, itemId)
		or table.find(currentShopState.dailyItems, itemId)
		or table.find(currentShopState.specialItems, itemId)

	if not inRotation then
		Events.FireClient(player, "Shop", "PurchaseFailed", {
			reason = "NotAvailable",
			itemId = itemId,
		})
		return
	end

	-- TODO: Integrate with Roblox marketplace
	-- For now, simulate purchase success
	local price = item.price

	-- Grant item
	ShopManager.GrantItem(player, itemId)

	-- Handle bundles
	if item.bundleContents then
		for _, contentId in ipairs(item.bundleContents) do
			if not inventory.ownedItems[contentId] then
				ShopManager.GrantItem(player, contentId)
			end
		end
	end

	-- Record purchase
	table.insert(inventory.purchaseHistory, {
		itemId = itemId,
		timestamp = os.time(),
		price = price,
	})

	-- Notify client
	Events.FireClient(player, "Shop", "PurchaseSuccess", {
		itemId = itemId,
		price = price,
	})

	onPurchaseComplete:Fire(player, itemId, price)
	print(`[ShopManager] {player.Name} purchased {item.name} for {price}`)
end

--[[
	Grant an item to player
]]
function ShopManager.GrantItem(player: Player, itemId: string)
	local inventory = playerInventories[player]
	if not inventory then return end

	inventory.ownedItems[itemId] = true

	-- TODO: Integrate with cosmetics system
	local item = ShopData.GetItem(itemId)
	if item then
		print(`[ShopManager] Granted {item.name} to {player.Name}`)
	end
end

--[[
	Send shop data to client
]]
function ShopManager.SendShopData(player: Player)
	local inventory = playerInventories[player]

	-- Build shop data with owned status
	local featuredData = {}
	for _, itemId in ipairs(currentShopState.featuredItems) do
		local item = ShopData.GetItem(itemId)
		if item then
			table.insert(featuredData, {
				id = item.id,
				name = item.name,
				description = item.description,
				itemType = item.itemType,
				rarity = item.rarity,
				price = item.price,
				originalPrice = item.originalPrice,
				isOnSale = item.isOnSale,
				isOwned = inventory and inventory.ownedItems[itemId] or false,
			})
		end
	end

	local dailyData = {}
	for _, itemId in ipairs(currentShopState.dailyItems) do
		local item = ShopData.GetItem(itemId)
		if item then
			table.insert(dailyData, {
				id = item.id,
				name = item.name,
				description = item.description,
				itemType = item.itemType,
				rarity = item.rarity,
				price = item.price,
				isOwned = inventory and inventory.ownedItems[itemId] or false,
			})
		end
	end

	local specialData = {}
	for _, itemId in ipairs(currentShopState.specialItems) do
		local item = ShopData.GetItem(itemId)
		if item then
			table.insert(specialData, {
				id = item.id,
				name = item.name,
				description = item.description,
				itemType = item.itemType,
				rarity = item.rarity,
				price = item.price,
				originalPrice = item.originalPrice,
				isOnSale = item.isOnSale,
				bundleContents = item.bundleContents,
				savings = item.bundleContents and ShopData.GetBundleSavings(itemId) or 0,
				isOwned = inventory and inventory.ownedItems[itemId] or false,
			})
		end
	end

	Events.FireClient(player, "Shop", "DataUpdate", {
		featured = featuredData,
		daily = dailyData,
		special = specialData,
		nextRotation = currentShopState.nextRotation,
	})
end

--[[
	Send inventory to client
]]
function ShopManager.SendInventory(player: Player)
	local inventory = playerInventories[player]
	if not inventory then return end

	local ownedList = {}
	for itemId in pairs(inventory.ownedItems) do
		table.insert(ownedList, itemId)
	end

	Events.FireClient(player, "Shop", "InventoryUpdate", {
		ownedItems = ownedList,
	})
end

--[[
	Check if player owns item
]]
function ShopManager.OwnsItem(player: Player, itemId: string): boolean
	local inventory = playerInventories[player]
	return inventory and inventory.ownedItems[itemId] or false
end

--[[
	Shuffle array helper
]]
function ShopManager.ShuffleArray<T>(array: { T }): { T }
	local result = table.clone(array)
	for i = #result, 2, -1 do
		local j = math.random(i)
		result[i], result[j] = result[j], result[i]
	end
	return result
end

--[[
	Get time until next rotation
]]
function ShopManager.GetTimeUntilRotation(): number
	return math.max(0, currentShopState.nextRotation - os.time())
end

return ShopManager
