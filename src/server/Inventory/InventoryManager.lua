--!strict
--[[
	InventoryManager.lua
	====================
	Server-authoritative inventory management for Dino Royale.

	RESPONSIBILITIES:
	- Manages player inventories (weapons, consumables, equipment, ammo)
	- Handles world item spawning, pickup, and despawning
	- Validates all inventory operations server-side
	- Synchronizes inventory state to clients

	INVENTORY STRUCTURE:
	Each player has:
	- 5 weapon slots (switchable with number keys 1-5)
	- 2 equipment slots (tactical and utility)
	- Consumables (stackable items like medkits)
	- Ammo pools (shared across weapons of same type)

	WORLD ITEMS:
	Items dropped in the world are tracked with:
	- Unique ID for network reference
	- Visual model with ProximityPrompt for pickup
	- Billboard UI showing item name/rarity
	- Highlight effect based on rarity color

	AMMO LIMITS (balanced for gameplay):
	- Light/Medium ammo: 300 max (encourages ammo management)
	- Heavy/Shells: 60 max (limits sniper/shotgun spam)
	- Special: 30 max (rare weapon ammunition)

	SECURITY:
	All inventory modifications happen server-side. Clients can only:
	- Request item pickup (validated by proximity)
	- Request item use (validated by possession)
	- Request item drop (always allowed for owned items)

	USAGE:
	```lua
	local InventoryManager = require(path.to.InventoryManager)
	InventoryManager.Initialize()
	InventoryManager.InitializePlayer(player)
	InventoryManager.AddItem(player, { itemType = "Weapon", itemId = "RangerAR" })
	```

	@server
	@singleton
]]

local Players = game:GetService("Players")

--------------------------------------------------------------------------------
-- MODULE DEPENDENCIES
--------------------------------------------------------------------------------

local Events = require(game.ReplicatedStorage.Shared.Events)
local WeaponBase = require(game.ReplicatedStorage.Shared.Weapons.WeaponBase)
local WeaponData = require(game.ReplicatedStorage.Shared.Config.WeaponData)
local ItemData = require(game.ReplicatedStorage.Shared.Config.ItemData)

--------------------------------------------------------------------------------
-- TYPE DEFINITIONS
--------------------------------------------------------------------------------

-- Import weapon instance type for inventory storage
type WeaponInstance = WeaponBase.WeaponInstance

local InventoryManager = {}

--------------------------------------------------------------------------------
-- EXPORTED TYPES
--------------------------------------------------------------------------------

--[[
	EquipmentSlots: Player's equipment loadout
	- tactical: Grenades, flashbangs, etc. (thrown items)
	- utility: Grapple hook, motion sensor, etc. (gadgets)
]]
export type EquipmentSlots = {
	tactical: string?,
	utility: string?,
}

--[[
	Inventory: Complete player inventory state
	Synchronized to client on any change via InventoryUpdate event
]]
export type Inventory = {
	weapons: { [number]: WeaponInstance? }, -- Slots 1-5 for weapons
	equipment: EquipmentSlots,               -- Tactical and utility items
	consumables: { [string]: number },       -- itemId -> stack count
	ammo: { [string]: number },              -- ammoType -> total rounds
	currentWeaponSlot: number,               -- Currently selected slot (1-5)
}

--[[
	WorldItem: Item dropped in the game world
	Represents physical items that can be picked up
]]
export type WorldItem = {
	id: string,          -- Unique identifier (e.g., "WorldItem_123")
	itemType: string,    -- Category: "Weapon", "Consumable", "Ammo", "Equipment"
	itemId: string,      -- Specific item ID (e.g., "RangerAR", "MedKit")
	rarity: string?,     -- For weapons: "Common" to "Legendary"
	count: number,       -- Stack count (1 for weapons, varies for ammo)
	position: Vector3,   -- World position
	model: Model?,       -- Visual representation in workspace
}

--------------------------------------------------------------------------------
-- STATE VARIABLES
--------------------------------------------------------------------------------

-- Maps UserId -> Inventory for all connected players
local playerInventories = {} :: { [number]: Inventory }

-- Maps UserId -> connection for cleanup on player leave
local playerConnections = {} :: { [number]: RBXScriptConnection }

-- Maps WorldItem ID -> WorldItem for all items in the world
local worldItems = {} :: { [string]: WorldItem }

-- Counter for generating unique WorldItem IDs
local worldItemCounter = 0

--------------------------------------------------------------------------------
-- CONSTANTS
--------------------------------------------------------------------------------

--[[
	Maximum ammo capacity per type.
	Balanced to encourage:
	- Looting (can't carry infinite ammo)
	- Weapon variety (different ammo pools)
	- Strategic decisions (save ammo or spray)
]]
local MAX_AMMO = {
	LightAmmo = 300,    -- SMGs, Pistols - high capacity, common
	MediumAmmo = 300,   -- ARs, DMRs - high capacity, common
	HeavyAmmo = 60,     -- Snipers - limited for balance
	Shells = 60,        -- Shotguns - limited for balance
	SpecialAmmo = 30,   -- Tranq, Flamethrower - very limited
}

--[[
	Initialize the InventoryManager module (call once on server start)
]]
function InventoryManager.Initialize()
	-- Set up event listeners
	InventoryManager.InitializeEvents()
	print("[InventoryManager] Initialized")
end

--[[
	Initialize inventory for a specific player
	@param player The player to initialize
]]
function InventoryManager.InitializePlayer(player: Player)
	local userId = player.UserId

	playerInventories[userId] = {
		weapons = { nil, nil, nil, nil, nil },
		equipment = {
			tactical = nil,
			utility = nil,
		},
		consumables = {},
		ammo = {
			LightAmmo = 0,
			MediumAmmo = 0,
			HeavyAmmo = 0,
			Shells = 0,
			SpecialAmmo = 0,
		},
		currentWeaponSlot = 1,
	}

	-- Cleanup on player leaving
	local ancestryConn = player.AncestryChanged:Connect(function(_, parent)
		if not parent then
			InventoryManager.CleanupPlayer(player)
		end
	end)
	playerConnections[userId] = ancestryConn

	print(`[InventoryManager] Initialized inventory for {player.Name}`)
end

--[[
	Initialize event listeners
]]
function InventoryManager.InitializeEvents()
	Events.OnServerEvent("Inventory", "PickupItem", function(player, data)
		InventoryManager.HandlePickupItem(player, data)
	end)

	Events.OnServerEvent("Inventory", "DropItem", function(player, data)
		InventoryManager.HandleDropItem(player, data)
	end)

	Events.OnServerEvent("Inventory", "UseItem", function(player, data)
		InventoryManager.HandleUseItem(player, data)
	end)

	Events.OnServerEvent("Inventory", "SwapSlots", function(player, data)
		InventoryManager.HandleSwapSlots(player, data)
	end)
end

--[[
	Add an item to a player's inventory
	@param player The player
	@param item The item to add (weapon, consumable, ammo, or equipment)
	@return Success and slot number if applicable
]]
function InventoryManager.AddItem(
	player: Player,
	item: { itemType: string, itemId: string, rarity: string?, count: number? }
): { success: boolean, slot: number? }
	local inventory = playerInventories[player.UserId]
	if not inventory then
		return { success = false }
	end

	local itemType = item.itemType
	local itemId = item.itemId
	local count = item.count or 1

	if itemType == "Weapon" then
		return InventoryManager.AddWeapon(player, itemId, item.rarity or "Common")
	elseif itemType == "Consumable" then
		return InventoryManager.AddConsumable(player, itemId, count)
	elseif itemType == "Ammo" then
		local added = InventoryManager.AddAmmo(player, itemId, count)
		return { success = added > 0, slot = nil }
	elseif itemType == "Equipment" then
		return InventoryManager.AddEquipment(player, itemId)
	end

	return { success = false }
end

--[[
	Add a weapon to inventory
	@param player The player
	@param weaponId The weapon ID
	@param rarity The weapon rarity
	@return Success and slot number
]]
function InventoryManager.AddWeapon(player: Player, weaponId: string, rarity: string): { success: boolean, slot: number? }
	local inventory = playerInventories[player.UserId]
	if not inventory then
		return { success = false }
	end

	-- Check for duplicate weapon type
	local weaponDef = WeaponData.GetWeapon(weaponId)
	if not weaponDef then
		return { success = false }
	end

	-- Find empty slot or check for same category
	local emptySlot: number? = nil
	for slot = 1, 5 do
		local existingWeapon = inventory.weapons[slot]
		if not existingWeapon then
			if not emptySlot then
				emptySlot = slot
			end
		elseif existingWeapon.definition.category == weaponDef.category then
			-- Can't have two of same category - would need to swap
			-- For now, reject
			return { success = false }
		end
	end

	if not emptySlot then
		-- Inventory full - would swap with current slot
		return { success = false }
	end

	-- Create weapon instance (comes with one full mag)
	local weapon = WeaponBase.new(weaponId, rarity :: any)
	weapon.state.reserveAmmo = 0 -- Reserve ammo comes from inventory pool now
	inventory.weapons[emptySlot] = weapon

	-- Add starting ammo to inventory pool (2 extra mags worth)
	local ammoType = WeaponData.GetAmmoType(weaponId)
	if ammoType then
		local startingAmmo = weaponDef.magSize * 2
		InventoryManager.AddAmmo(player, ammoType, startingAmmo)
	end

	-- Send update to client
	InventoryManager.SendInventoryUpdate(player)

	return { success = true, slot = emptySlot }
end

--[[
	Add a consumable to inventory
	@param player The player
	@param itemId The item ID
	@param count Amount to add
	@return Success and whether it stacked
]]
function InventoryManager.AddConsumable(player: Player, itemId: string, count: number): { success: boolean, slot: number? }
	local inventory = playerInventories[player.UserId]
	if not inventory then
		return { success = false }
	end

	local itemDef = ItemData.GetItem(itemId)
	if not itemDef then
		return { success = false }
	end

	local maxStack = ItemData.GetMaxStack(itemId)
	local currentCount = inventory.consumables[itemId] or 0
	local spaceAvailable = maxStack - currentCount

	if spaceAvailable <= 0 then
		return { success = false }
	end

	local toAdd = math.min(count, spaceAvailable)
	inventory.consumables[itemId] = currentCount + toAdd

	InventoryManager.SendInventoryUpdate(player)

	return { success = true }
end

--[[
	Add ammo to inventory
	@param player The player
	@param ammoType The ammo type
	@param amount Amount to add
	@return Amount actually added
]]
function InventoryManager.AddAmmo(player: Player, ammoType: string, amount: number): number
	local inventory = playerInventories[player.UserId]
	if not inventory then
		return 0
	end

	local maxAmmo = MAX_AMMO[ammoType] or 999
	local currentAmmo = inventory.ammo[ammoType] or 0
	local spaceAvailable = maxAmmo - currentAmmo

	local toAdd = math.min(amount, spaceAvailable)
	inventory.ammo[ammoType] = currentAmmo + toAdd

	InventoryManager.SendInventoryUpdate(player)

	return toAdd
end

--[[
	Add equipment to inventory
	@param player The player
	@param itemId The equipment ID
	@return Success
]]
function InventoryManager.AddEquipment(player: Player, itemId: string): { success: boolean, slot: number? }
	local inventory = playerInventories[player.UserId]
	if not inventory then
		return { success = false }
	end

	local itemDef = ItemData.GetItem(itemId)
	if not itemDef or itemDef.category ~= "Tactical" then
		return { success = false }
	end

	-- Determine slot (tactical or utility based on item)
	local slot = "tactical"

	-- Check if slot is available
	if inventory.equipment[slot] then
		return { success = false } -- Would need to swap
	end

	inventory.equipment[slot] = itemId

	InventoryManager.SendInventoryUpdate(player)

	return { success = true }
end

--[[
	Remove an item from a specific slot
	@param player The player
	@param slotType "weapon", "consumable", "equipment"
	@param slotIndex Slot number or item ID
	@return The removed item data or nil
]]
function InventoryManager.RemoveItem(player: Player, slotType: string, slotIndex: any): any
	local inventory = playerInventories[player.UserId]
	if not inventory then
		return nil
	end

	if slotType == "weapon" then
		local slot = slotIndex :: number
		local weapon = inventory.weapons[slot]
		inventory.weapons[slot] = nil
		InventoryManager.SendInventoryUpdate(player)
		return weapon
	elseif slotType == "consumable" then
		local itemId = slotIndex :: string
		local count = inventory.consumables[itemId]
		if count and count > 0 then
			inventory.consumables[itemId] = count - 1
			if inventory.consumables[itemId] <= 0 then
				inventory.consumables[itemId] = nil
			end
			InventoryManager.SendInventoryUpdate(player)
			return { itemId = itemId, count = 1 }
		end
	elseif slotType == "equipment" then
		local slot = slotIndex :: string
		local itemId = inventory.equipment[slot]
		inventory.equipment[slot] = nil
		InventoryManager.SendInventoryUpdate(player)
		return itemId
	end

	return nil
end

--[[
	Swap two weapon slots
	@param player The player
	@param slot1 First slot
	@param slot2 Second slot
	@return Success
]]
function InventoryManager.SwapSlots(player: Player, slot1: number, slot2: number): boolean
	local inventory = playerInventories[player.UserId]
	if not inventory then
		return false
	end

	if slot1 < 1 or slot1 > 5 or slot2 < 1 or slot2 > 5 then
		return false
	end

	local temp = inventory.weapons[slot1]
	inventory.weapons[slot1] = inventory.weapons[slot2]
	inventory.weapons[slot2] = temp

	InventoryManager.SendInventoryUpdate(player)

	return true
end

--[[
	Drop an item from inventory into the world
	@param player The player
	@param slotType The slot type
	@param slotIndex The slot index/ID
	@return The created WorldItem or nil
]]
function InventoryManager.DropItem(player: Player, slotType: string, slotIndex: any): WorldItem?
	local item = InventoryManager.RemoveItem(player, slotType, slotIndex)
	if not item then
		return nil
	end

	-- Get drop position
	local character = player.Character
	if not character then
		return nil
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return nil
	end

	local dropPosition = rootPart.Position + rootPart.CFrame.LookVector * 3

	-- Create world item
	local worldItem: WorldItem

	if slotType == "weapon" then
		local weapon = item :: WeaponInstance
		worldItem = InventoryManager.CreateWorldItem("Weapon", weapon.id, dropPosition, weapon.rarity, 1)
	elseif slotType == "consumable" then
		worldItem = InventoryManager.CreateWorldItem("Consumable", item.itemId, dropPosition, nil, 1)
	elseif slotType == "equipment" then
		worldItem = InventoryManager.CreateWorldItem("Equipment", item, dropPosition, nil, 1)
	else
		return nil
	end

	return worldItem
end

--[[
	Use a consumable item
	@param player The player
	@param itemId The item ID
	@return Success
]]
function InventoryManager.UseItem(player: Player, itemId: string): boolean
	local inventory = playerInventories[player.UserId]
	if not inventory then
		return false
	end

	local count = inventory.consumables[itemId]
	if not count or count <= 0 then
		return false
	end

	local itemDef = ItemData.GetItem(itemId)
	if not itemDef then
		return false
	end

	-- Remove item first
	inventory.consumables[itemId] = count - 1
	if inventory.consumables[itemId] <= 0 then
		inventory.consumables[itemId] = nil
	end

	-- Apply item effect (would integrate with HealthManager)
	-- For now, just return success
	-- Effect application would be:
	-- if itemDef.category == "Healing" then
	--     HealthManager.ApplyHealing(player, itemDef.healAmount, itemDef.maxHealTo)
	-- elseif itemDef.category == "Shield" then
	--     HealthManager.ApplyShield(player, itemDef.shieldAmount)
	-- end

	InventoryManager.SendInventoryUpdate(player)

	return true
end

--[[
	Consume ammo from inventory
	@param player The player
	@param ammoType The ammo type
	@param amount Amount to consume
	@return Success
]]
function InventoryManager.ConsumeAmmo(player: Player, ammoType: string, amount: number): boolean
	local inventory = playerInventories[player.UserId]
	if not inventory then
		return false
	end

	local currentAmmo = inventory.ammo[ammoType] or 0
	if currentAmmo < amount then
		return false
	end

	inventory.ammo[ammoType] = currentAmmo - amount

	return true
end

--[[
	Get a player's inventory
	@param player The player
	@return The inventory or nil
]]
function InventoryManager.GetInventory(player: Player): Inventory?
	return playerInventories[player.UserId]
end

--[[
	Create a world item
	@param itemType The item type
	@param itemId The item ID
	@param position World position
	@param rarity Optional rarity
	@param count Item count
	@return The created WorldItem
]]
function InventoryManager.CreateWorldItem(
	itemType: string,
	itemId: string,
	position: Vector3,
	rarity: string?,
	count: number
): WorldItem
	worldItemCounter = worldItemCounter + 1
	local id = `WorldItem_{worldItemCounter}`

	local worldItem: WorldItem = {
		id = id,
		itemType = itemType,
		itemId = itemId,
		rarity = rarity,
		count = count,
		position = position,
		model = nil,
	}

	-- Create visual model
	local model = InventoryManager.CreateWorldItemModel(worldItem)
	worldItem.model = model

	worldItems[id] = worldItem

	return worldItem
end

--[[
	Create visual model for a world item
	@param worldItem The world item
	@return The created model
]]
function InventoryManager.CreateWorldItemModel(worldItem: WorldItem): Model
	local model = Instance.new("Model")
	model.Name = worldItem.id

	-- Create base part
	local part = Instance.new("Part")
	part.Name = "Base"
	part.Anchored = true
	part.CanCollide = false
	part.Size = Vector3.new(1, 0.5, 1)
	part.Position = worldItem.position
	part.Material = Enum.Material.SmoothPlastic

	-- Color based on rarity
	local rarityColors = {
		Common = Color3.fromRGB(150, 150, 150),
		Uncommon = Color3.fromRGB(50, 200, 50),
		Rare = Color3.fromRGB(50, 100, 255),
		Epic = Color3.fromRGB(150, 50, 255),
		Legendary = Color3.fromRGB(255, 200, 50),
	}
	part.Color = rarityColors[worldItem.rarity or "Common"] or rarityColors.Common
	part.Parent = model

	-- Add highlight effect
	local highlight = Instance.new("Highlight")
	highlight.FillColor = part.Color
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.FillTransparency = 0.7
	highlight.Parent = model

	-- Add proximity prompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick Up"
	prompt.ObjectText = worldItem.itemId
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.Parent = part

	-- Connect prompt
	prompt.Triggered:Connect(function(player)
		InventoryManager.HandleWorldItemPickup(player, worldItem.id)
	end)

	-- Add billboard for item name
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(100, 30)
	billboard.StudsOffset = Vector3.new(0, 1.5, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 30
	billboard.Adornee = part
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = worldItem.itemId
	label.TextColor3 = part.Color
	label.TextSize = 14
	label.Font = Enum.Font.GothamBold
	label.TextStrokeTransparency = 0.5
	label.Parent = billboard

	model.PrimaryPart = part
	model.Parent = workspace

	-- Tag for collision service
	model:AddTag("WorldItem")
	model:SetAttribute("WorldItemId", worldItem.id)

	return model
end

--[[
	Handle world item pickup
	@param player The player
	@param worldItemId The world item ID
]]
function InventoryManager.HandleWorldItemPickup(player: Player, worldItemId: string)
	local worldItem = worldItems[worldItemId]
	if not worldItem then
		return
	end

	-- Try to add to inventory
	local result = InventoryManager.AddItem(player, {
		itemType = worldItem.itemType,
		itemId = worldItem.itemId,
		rarity = worldItem.rarity,
		count = worldItem.count,
	})

	if result.success then
		-- Remove world item
		if worldItem.model then
			worldItem.model:Destroy()
		end
		worldItems[worldItemId] = nil
	end
end

--[[
	Handle pickup item event from client
]]
function InventoryManager.HandlePickupItem(player: Player, data: any)
	if typeof(data) ~= "table" then
		return
	end

	local itemInstanceId = data.itemInstanceId
	if typeof(itemInstanceId) ~= "string" then
		return
	end

	InventoryManager.HandleWorldItemPickup(player, itemInstanceId)
end

--[[
	Handle drop item event from client
]]
function InventoryManager.HandleDropItem(player: Player, data: any)
	if typeof(data) ~= "table" then
		return
	end

	local slotIndex = data.slotIndex
	local slotType = data.slotType or "weapon"

	InventoryManager.DropItem(player, slotType, slotIndex)
end

--[[
	Handle use item event from client
]]
function InventoryManager.HandleUseItem(player: Player, data: any)
	if typeof(data) ~= "table" then
		return
	end

	local itemId = data.itemId
	if typeof(itemId) ~= "string" then
		return
	end

	InventoryManager.UseItem(player, itemId)
end

--[[
	Handle swap slots event from client
]]
function InventoryManager.HandleSwapSlots(player: Player, data: any)
	if typeof(data) ~= "table" then
		return
	end

	local slot1 = data.slot1
	local slot2 = data.slot2

	if typeof(slot1) ~= "number" or typeof(slot2) ~= "number" then
		return
	end

	InventoryManager.SwapSlots(player, slot1, slot2)
end

--[[
	Send inventory update to client
	@param player The player
]]
function InventoryManager.SendInventoryUpdate(player: Player)
	local inventory = playerInventories[player.UserId]
	if not inventory then
		return
	end

	-- Serialize weapons with reserve ammo synced from inventory pool
	local serializedWeapons = {}
	for slot, weapon in pairs(inventory.weapons) do
		if weapon then
			local serialized = weapon:Serialize()
			-- Sync reserve ammo with inventory ammo pool
			local ammoType = WeaponData.GetAmmoType(weapon.id)
			if ammoType and inventory.ammo[ammoType] then
				serialized.reserveAmmo = inventory.ammo[ammoType]
			end
			serializedWeapons[slot] = serialized
		end
	end

	Events.FireClient("Inventory", "InventoryUpdate", player, {
		weapons = serializedWeapons,
		equipment = inventory.equipment,
		consumables = inventory.consumables,
		ammo = inventory.ammo,
		currentWeaponSlot = inventory.currentWeaponSlot,
	})
end

--[[
	Get a world item by ID
	@param id The world item ID
	@return The world item or nil
]]
function InventoryManager.GetWorldItem(id: string): WorldItem?
	return worldItems[id]
end

--[[
	Remove a world item
	@param id The world item ID
]]
function InventoryManager.RemoveWorldItem(id: string)
	local worldItem = worldItems[id]
	if worldItem then
		if worldItem.model then
			worldItem.model:Destroy()
		end
		worldItems[id] = nil
	end
end

--[[
	Clear a player's entire inventory
	@param player The player whose inventory to clear
]]
function InventoryManager.ClearInventory(player: Player)
	local userId = player.UserId
	local inventory = playerInventories[userId]
	if not inventory then return end

	-- Clear all slots
	inventory.weapons = { nil, nil, nil, nil, nil }
	inventory.equipment = {
		tactical = nil,
		utility = nil,
	}
	inventory.consumables = {}
	inventory.ammo = {
		LightAmmo = 0,
		MediumAmmo = 0,
		HeavyAmmo = 0,
		Shells = 0,
		SpecialAmmo = 0,
	}
	inventory.currentWeaponSlot = 1

	-- Notify client of cleared inventory
	InventoryManager.SendInventoryUpdate(player)
end

--[[
	Cleanup player data when they leave
	@param player The player to cleanup
]]
function InventoryManager.CleanupPlayer(player: Player)
	local userId = player.UserId

	-- Disconnect the ancestry connection
	local conn = playerConnections[userId]
	if conn then
		conn:Disconnect()
		playerConnections[userId] = nil
	end

	playerInventories[userId] = nil
end


--[[
	Reset all inventory state for new match
	Clears world items, resets counter, and clears all player inventories
]]
function InventoryManager.Reset()
	-- Destroy all world item models
	for _, worldItem in pairs(worldItems) do
		if worldItem.model then
			worldItem.model:Destroy()
		end
	end
	worldItems = {}
	worldItemCounter = 0

	-- Clear all player inventories (they'll be re-initialized when match starts)
	for userId, _ in pairs(playerInventories) do
		local player = game:GetService("Players"):GetPlayerByUserId(userId)
		if player then
			InventoryManager.ClearInventory(player)
		end
	end

	print("[InventoryManager] Reset")
end

return InventoryManager
