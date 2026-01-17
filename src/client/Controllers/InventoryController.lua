--!strict
--[[
	InventoryController.lua
	=======================
	Client-side inventory management
	Handles item pickup, dropping, using, and UI updates
]]

local Players = game:GetService("Players")
local _UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Events = require(ReplicatedStorage.Shared.Events)

local InventoryController = {}

-- Local player reference
local localPlayer = Players.LocalPlayer

-- State
local inventory = {} :: { [number]: any } -- Inventory slots
local selectedSlot = 1
local isEnabled = false
local isInventoryOpen = false

-- Connections
local connections = {} :: { RBXScriptConnection }

-- Callbacks
local onInventoryChanged: ((any) -> ())?
local onItemSelected: ((number, any?) -> ())?

-- Constants
local MAX_SLOTS = 5
local PICKUP_DISTANCE = 10

--[[
	Initialize the inventory controller
]]
function InventoryController.Initialize()
	-- Initialize empty inventory
	for i = 1, MAX_SLOTS do
		inventory[i] = nil
	end

	-- Bind input actions
	InventoryController.BindActions()

	-- Listen for server events
	local updateConnection = Events.OnClientEvent("Inventory", "InventoryUpdate", function(data)
		InventoryController.OnInventoryUpdate(data)
	end)
	table.insert(connections, updateConnection)

	print("[InventoryController] Initialized")
end

--[[
	Bind input actions for inventory
]]
function InventoryController.BindActions()
	-- Inventory toggle (Tab / Back)
	ContextActionService:BindAction("ToggleInventory", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			InventoryController.ToggleInventory()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.Tab, Enum.KeyCode.ButtonSelect)

	-- Pickup item (E / A)
	ContextActionService:BindAction("PickupItem", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			InventoryController.TryPickupNearby()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.E, Enum.KeyCode.ButtonA)

	-- Drop item (G)
	ContextActionService:BindAction("DropItem", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			InventoryController.DropCurrentItem()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.G)

	-- Use item (F)
	ContextActionService:BindAction("UseItem", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			InventoryController.UseCurrentItem()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.F)

	-- Slot selection (1-5)
	for slot = 1, MAX_SLOTS do
		local keyCode = Enum.KeyCode[tostring(slot)]
		ContextActionService:BindAction("SelectSlot" .. slot, function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				InventoryController.SelectSlot(slot)
			end
			return Enum.ContextActionResult.Pass
		end, false, keyCode)
	end
end

--[[
	Enable the inventory controller
]]
function InventoryController.Enable()
	isEnabled = true
end

--[[
	Disable the inventory controller
]]
function InventoryController.Disable()
	isEnabled = false
end

--[[
	Toggle inventory UI
]]
function InventoryController.ToggleInventory()
	isInventoryOpen = not isInventoryOpen
	-- UI would be handled by LootUI or similar
end

--[[
	Select an inventory slot
]]
function InventoryController.SelectSlot(slot: number)
	if slot < 1 or slot > MAX_SLOTS then return end

	selectedSlot = slot
	local item = inventory[slot]

	if onItemSelected then
		onItemSelected(slot, item)
	end
end

--[[
	Get the currently selected slot
]]
function InventoryController.GetSelectedSlot(): number
	return selectedSlot
end

--[[
	Get item in a specific slot
]]
function InventoryController.GetItem(slot: number): any?
	return inventory[slot]
end

--[[
	Get all inventory items
]]
function InventoryController.GetInventory(): { [number]: any }
	return inventory
end

--[[
	Try to pickup nearby item
]]
function InventoryController.TryPickupNearby()
	if not isEnabled then return end

	local character = localPlayer.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	-- Find nearest loot within pickup distance
	local nearestLoot: BasePart? = nil
	local nearestDistance = PICKUP_DISTANCE

	for _, loot in pairs(workspace:GetChildren()) do
		if loot:HasTag("Loot") or loot:GetAttribute("IsLoot") then
			local lootPart = loot:IsA("BasePart") and loot or loot:FindFirstChildWhichIsA("BasePart")
			if lootPart then
				local distance = (lootPart.Position - rootPart.Position).Magnitude
				if distance < nearestDistance then
					nearestDistance = distance
					nearestLoot = lootPart
				end
			end
		end
	end

	if nearestLoot then
		local lootId = nearestLoot:GetAttribute("LootId") or nearestLoot.Name
		Events.FireServer("Inventory", "PickupItem", { itemInstanceId = lootId })
	end
end

--[[
	Drop the currently selected item
]]
function InventoryController.DropCurrentItem()
	if not isEnabled then return end
	if not inventory[selectedSlot] then return end

	Events.FireServer("Inventory", "DropItem", { slotIndex = selectedSlot })
end

--[[
	Use the currently selected item
]]
function InventoryController.UseCurrentItem()
	if not isEnabled then return end
	if not inventory[selectedSlot] then return end

	Events.FireServer("Inventory", "UseItem", { slotIndex = selectedSlot })
end

--[[
	Handle inventory update from server
]]
function InventoryController.OnInventoryUpdate(data: any)
	if typeof(data) ~= "table" then
		return
	end

	-- Handle weapons
	if data.weapons then
		for slot, weaponData in pairs(data.weapons) do
			inventory[slot] = weaponData
		end
	end

	-- Store additional inventory data
	if data.equipment then
		inventory.equipment = data.equipment
	end

	if data.consumables then
		inventory.consumables = data.consumables
	end

	if data.ammo then
		inventory.ammo = data.ammo
	end

	if data.currentWeaponSlot then
		selectedSlot = data.currentWeaponSlot
	end

	if onInventoryChanged then
		onInventoryChanged(inventory)
	end
end

--[[
	Set callback for inventory changes
]]
function InventoryController.SetOnInventoryChanged(callback: (any) -> ())
	onInventoryChanged = callback
end

--[[
	Set callback for item selection
]]
function InventoryController.SetOnItemSelected(callback: (number, any?) -> ())
	onItemSelected = callback
end

--[[
	Cleanup
]]
function InventoryController.Cleanup()
	isEnabled = false

	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	connections = {}

	-- Unbind actions
	ContextActionService:UnbindAction("ToggleInventory")
	ContextActionService:UnbindAction("PickupItem")
	ContextActionService:UnbindAction("DropItem")
	ContextActionService:UnbindAction("UseItem")

	for slot = 1, MAX_SLOTS do
		ContextActionService:UnbindAction("SelectSlot" .. slot)
	end
end

return InventoryController
