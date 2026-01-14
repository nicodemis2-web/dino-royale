--!strict
--[[
	WeaponController.lua
	====================
	Client-side weapon input and visual feedback
	Handles firing, reloading, ADS, and weapon switching
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Events = require(game.ReplicatedStorage.Shared.Events)
local WeaponBase = require(game.ReplicatedStorage.Shared.Weapons.WeaponBase)

-- Type imports
type WeaponInstance = WeaponBase.WeaponInstance

local WeaponController = {}

-- Local player reference
local localPlayer = Players.LocalPlayer

-- State
local currentWeapon: WeaponInstance? = nil
local weaponSlots = {} :: { [number]: WeaponInstance? } -- 1-5 weapon slots
local currentSlot = 1
local isADS = false
local isFiring = false
local isEnabled = true

-- Connections
local connections = {} :: { RBXScriptConnection }

-- Callbacks for effects
local onFireCallback: ((WeaponInstance, Vector3, Vector3) -> ())?
local onReloadCallback: ((WeaponInstance) -> ())?
local onHitCallback: ((boolean, number) -> ())? -- isHeadshot, damage

-- Camera settings
local DEFAULT_FOV = 70
local ADS_FOV_MULTIPLIER = 0.7
local FOV_LERP_SPEED = 15

--[[
	Initialize the weapon controller
]]
function WeaponController.Initialize()
	-- Bind input actions
	WeaponController.BindActions()

	-- Start update loop
	local heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
		if isEnabled then
			WeaponController.Update(dt)
		end
	end)
	table.insert(connections, heartbeatConnection)

	-- Listen for server events
	local hitConfirmConnection = Events.OnClientEvent("Combat", "HitConfirm", function(data)
		if onHitCallback then
			onHitCallback(data.isHeadshot, data.damage)
		end
	end)
	table.insert(connections, hitConfirmConnection)

	local inventoryConnection = Events.OnClientEvent("Inventory", "InventoryUpdate", function(data)
		WeaponController.OnInventoryUpdate(data)
	end)
	table.insert(connections, inventoryConnection)
end

--[[
	Bind input actions for weapons
]]
function WeaponController.BindActions()
	-- Fire (Mouse1 / RT)
	ContextActionService:BindAction("Fire", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			isFiring = true
		elseif inputState == Enum.UserInputState.End then
			isFiring = false
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)

	-- Reload (R / X)
	ContextActionService:BindAction("Reload", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			WeaponController.Reload()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.R, Enum.KeyCode.ButtonX)

	-- ADS (Mouse2 / LT)
	ContextActionService:BindAction("ADS", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			WeaponController.EnterADS()
		elseif inputState == Enum.UserInputState.End then
			WeaponController.ExitADS()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2)

	-- Weapon slots (1-5)
	for i = 1, 5 do
		local keyCode = Enum.KeyCode[tostring(i)]
		ContextActionService:BindAction(`WeaponSlot{i}`, function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				WeaponController.SwitchToSlot(i)
			end
			return Enum.ContextActionResult.Pass
		end, false, keyCode)
	end

	-- Scroll wheel weapon switch
	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			local delta = input.Position.Z
			if delta > 0 then
				WeaponController.SwitchToNextSlot(-1)
			elseif delta < 0 then
				WeaponController.SwitchToNextSlot(1)
			end
		end
	end)
end

--[[
	Update loop for weapon handling
	@param dt Delta time
]]
function WeaponController.Update(dt: number)
	-- Handle automatic fire
	if isFiring and currentWeapon then
		WeaponController.TryFire()
	end

	-- Update camera for ADS
	WeaponController.UpdateCamera(dt)
end

--[[
	Try to fire the current weapon
]]
function WeaponController.TryFire()
	if not currentWeapon then
		return
	end

	-- Check if weapon can fire (client prediction)
	if not currentWeapon:CanFire() then
		-- Check for automatic weapons that need to wait
		local weaponDef = currentWeapon.definition
		local category = weaponDef.category

		-- For non-automatic weapons, only fire once per click
		if category == "Pistol" or category == "Sniper" or category == "DMR" or category == "Shotgun" then
			-- Already tried to fire this click
			return
		end

		-- For automatic weapons, just wait
		return
	end

	-- Get fire origin and direction
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local character = localPlayer.Character
	if not character then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return
	end

	-- Origin from character (server will validate)
	local origin = rootPart.Position + Vector3.new(0, 1.5, 0) -- Approximate eye level
	local direction = camera.CFrame.LookVector

	-- Fire weapon (client-side prediction)
	local fireResult = currentWeapon:Fire(origin, direction)

	if fireResult.success then
		-- Play immediate feedback
		if onFireCallback then
			onFireCallback(currentWeapon, origin, fireResult.spread or direction)
		end

		-- Send to server
		Events.FireServer("Combat", "WeaponFire", {
			weaponId = currentWeapon.id,
			origin = origin,
			direction = direction,
		})
	end
end

--[[
	Start reloading current weapon
]]
function WeaponController.Reload()
	if not currentWeapon then
		return
	end

	-- Check if reload is possible
	if currentWeapon.state.isReloading then
		return
	end

	if currentWeapon.state.currentAmmo >= currentWeapon.definition.magSize then
		return
	end

	if currentWeapon.state.reserveAmmo <= 0 then
		return
	end

	-- Start reload (client prediction)
	currentWeapon:Reload()

	-- Play reload effects
	if onReloadCallback then
		onReloadCallback(currentWeapon)
	end

	-- Send to server
	Events.FireServer("Combat", "WeaponReload", {
		weaponId = currentWeapon.id,
	})

	-- Schedule client-side reload completion
	task.delay(currentWeapon.stats.reloadTime, function()
		if currentWeapon and currentWeapon.state.isReloading then
			WeaponBase.CompleteReload(currentWeapon)
		end
	end)
end

--[[
	Enter ADS mode
]]
function WeaponController.EnterADS()
	isADS = true

	-- Trigger scope for scoped weapons
	if currentWeapon then
		local hasScope = currentWeapon.definition.scopeZoom and currentWeapon.definition.scopeZoom > 0
		if hasScope then
			-- Would trigger scope overlay UI
		end
	end
end

--[[
	Exit ADS mode
]]
function WeaponController.ExitADS()
	isADS = false
end

--[[
	Update camera FOV for ADS
	@param dt Delta time
]]
function WeaponController.UpdateCamera(dt: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local targetFOV = DEFAULT_FOV

	if isADS and currentWeapon then
		local scopeZoom = currentWeapon.definition.scopeZoom or 1
		if scopeZoom > 1 then
			targetFOV = DEFAULT_FOV / scopeZoom
		else
			targetFOV = DEFAULT_FOV * ADS_FOV_MULTIPLIER
		end
	end

	-- Smooth lerp
	local currentFOV = camera.FieldOfView
	local newFOV = currentFOV + (targetFOV - currentFOV) * math.min(1, FOV_LERP_SPEED * dt)
	camera.FieldOfView = newFOV
end

--[[
	Switch to a specific weapon slot
	@param slot The slot number (1-5)
]]
function WeaponController.SwitchToSlot(slot: number)
	if slot < 1 or slot > 5 then
		return
	end

	if slot == currentSlot then
		return
	end

	-- Cancel current reload
	if currentWeapon then
		currentWeapon:CancelReload()
	end

	currentSlot = slot
	currentWeapon = weaponSlots[slot]

	-- Exit ADS on switch
	isADS = false
	isFiring = false
end

--[[
	Switch to next/previous weapon slot
	@param direction 1 for next, -1 for previous
]]
function WeaponController.SwitchToNextSlot(direction: number)
	local newSlot = currentSlot + direction

	-- Wrap around
	if newSlot < 1 then
		newSlot = 5
	elseif newSlot > 5 then
		newSlot = 1
	end

	-- Find next slot with a weapon
	local startSlot = newSlot
	repeat
		if weaponSlots[newSlot] then
			WeaponController.SwitchToSlot(newSlot)
			return
		end
		newSlot = newSlot + direction
		if newSlot < 1 then
			newSlot = 5
		elseif newSlot > 5 then
			newSlot = 1
		end
	until newSlot == startSlot
end

--[[
	Handle inventory update from server
	@param data Inventory data
]]
function WeaponController.OnInventoryUpdate(data: any)
	if typeof(data) ~= "table" then
		return
	end

	-- Update weapon slots from inventory data
	local weapons = data.weapons
	if typeof(weapons) == "table" then
		for slot, weaponData in pairs(weapons) do
			if typeof(weaponData) == "table" and weaponData.id then
				weaponSlots[slot] = WeaponBase.Deserialize(weaponData)
			else
				weaponSlots[slot] = nil
			end
		end

		-- Update current weapon reference
		currentWeapon = weaponSlots[currentSlot]
	end
end

--[[
	Get current weapon
	@return Current weapon or nil
]]
function WeaponController.GetCurrentWeapon(): WeaponInstance?
	return currentWeapon
end

--[[
	Get current ammo info
	@return Current ammo, reserve ammo, or 0, 0 if no weapon
]]
function WeaponController.GetAmmo(): (number, number)
	if not currentWeapon then
		return 0, 0
	end
	return currentWeapon.state.currentAmmo, currentWeapon.state.reserveAmmo
end

--[[
	Check if currently in ADS
	@return Whether ADS is active
]]
function WeaponController.IsADS(): boolean
	return isADS
end

--[[
	Check if currently reloading
	@return Whether reloading
]]
function WeaponController.IsReloading(): boolean
	return currentWeapon and currentWeapon.state.isReloading or false
end

--[[
	Get current weapon slot
	@return Current slot number
]]
function WeaponController.GetCurrentSlot(): number
	return currentSlot
end

--[[
	Set callback for weapon fire
	@param callback The callback function
]]
function WeaponController.SetFireCallback(callback: (WeaponInstance, Vector3, Vector3) -> ())
	onFireCallback = callback
end

--[[
	Set callback for weapon reload
	@param callback The callback function
]]
function WeaponController.SetReloadCallback(callback: (WeaponInstance) -> ())
	onReloadCallback = callback
end

--[[
	Set callback for hit confirmation
	@param callback The callback function
]]
function WeaponController.SetHitCallback(callback: (boolean, number) -> ())
	onHitCallback = callback
end

--[[
	Enable or disable weapon controls
	@param enabled Whether to enable
]]
function WeaponController.SetEnabled(enabled: boolean)
	isEnabled = enabled
	if not enabled then
		isFiring = false
		isADS = false
	end
end

--[[
	Cleanup the controller
]]
function WeaponController.Cleanup()
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	connections = {}

	ContextActionService:UnbindAction("Fire")
	ContextActionService:UnbindAction("Reload")
	ContextActionService:UnbindAction("ADS")
	for i = 1, 5 do
		ContextActionService:UnbindAction(`WeaponSlot{i}`)
	end
end

return WeaponController
