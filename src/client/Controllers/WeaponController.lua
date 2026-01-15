--!strict
--[[
	WeaponController.lua
	====================
	Client-side weapon input and visual feedback for Dino Royale.

	RESPONSIBILITIES:
	- Handles player input for firing, reloading, ADS, weapon switching
	- Manages client-side weapon state prediction
	- Applies visual feedback (recoil, screen shake, FOV changes)
	- Communicates with server for authoritative validation

	INPUT HANDLING:
	- Mouse1 / RT: Fire weapon (hold for automatic)
	- Mouse2 / LT: Aim down sights (ADS)
	- R / X: Reload weapon
	- 1-5: Switch weapon slots
	- Scroll wheel: Cycle weapons

	ADS (AIM DOWN SIGHTS) SYSTEM:
	When aiming, several effects are applied:
	- FOV reduction (zoom effect based on weapon scope)
	- Camera offset toward weapon sights
	- Reduced mouse sensitivity for precision
	- Reduced recoil (more stable aim)

	RECOIL SYSTEM:
	Weapons apply recoil when fired:
	- Vertical kick (camera moves up)
	- Horizontal variation (slight random horizontal movement)
	- Screen shake for impact feel
	- All effects recover over time when not firing

	CLIENT PREDICTION:
	Fire requests are sent to server but visual feedback is immediate.
	Server validates and may reject invalid fire attempts.

	USAGE:
	```lua
	local WeaponController = require(path.to.WeaponController)
	WeaponController.Initialize()
	WeaponController.SetFireCallback(function(weapon, origin, direction)
		-- Play muzzle flash, etc.
	end)
	```

	@client
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

--------------------------------------------------------------------------------
-- MODULE DEPENDENCIES
--------------------------------------------------------------------------------

local Events = require(game.ReplicatedStorage.Shared.Events)
local WeaponBase = require(game.ReplicatedStorage.Shared.Weapons.WeaponBase)

--------------------------------------------------------------------------------
-- TYPE DEFINITIONS
--------------------------------------------------------------------------------

type WeaponInstance = WeaponBase.WeaponInstance

local WeaponController = {}

--------------------------------------------------------------------------------
-- STATE VARIABLES
--------------------------------------------------------------------------------

-- Reference to local player (cached for performance)
local localPlayer = Players.LocalPlayer

-- Currently equipped weapon instance (nil if no weapon)
local currentWeapon: WeaponInstance? = nil

-- Weapon inventory: slots 1-5 for different weapons
local weaponSlots = {} :: { [number]: WeaponInstance? }

-- Currently selected weapon slot (1-5)
local currentSlot = 1

-- ADS state: true when right mouse / LT is held
local isADS = false

-- Firing state: true when fire button is held (for automatic weapons)
local isFiring = false

-- Controller enabled state (disabled during menus, death, etc.)
local isEnabled = true

-- Active event connections (cleaned up on destroy)
local connections = {} :: { RBXScriptConnection }

--------------------------------------------------------------------------------
-- CALLBACK HOOKS
--------------------------------------------------------------------------------

-- Called when weapon fires successfully (for visual effects)
local onFireCallback: ((WeaponInstance, Vector3, Vector3) -> ())?

-- Called when reload starts (for reload animations/sounds)
local onReloadCallback: ((WeaponInstance) -> ())?

-- Called when hit is confirmed by server (for hit markers)
local onHitCallback: ((boolean, number) -> ())? -- (isHeadshot, damage)

--------------------------------------------------------------------------------
-- CAMERA CONFIGURATION
--------------------------------------------------------------------------------

-- Base field of view (degrees)
local DEFAULT_FOV = 70

-- FOV multiplier when ADS (lower = more zoom)
local ADS_FOV_MULTIPLIER = 0.7

-- Speed of FOV transition (higher = faster)
local FOV_LERP_SPEED = 15

--------------------------------------------------------------------------------
-- ENHANCED ADS CONFIGURATION
--------------------------------------------------------------------------------

-- Camera offset when aiming (brings view to weapon sights)
-- X: Right offset, Y: Down offset, Z: Forward offset
local ADS_OFFSET = Vector3.new(0.4, -0.1, -0.3)

-- Speed of camera offset transition
local ADS_OFFSET_LERP_SPEED = 12

-- Mouse sensitivity reduction when ADS (0.6 = 40% slower)
local ADS_SENSITIVITY_MULTIPLIER = 0.6

--------------------------------------------------------------------------------
-- RECOIL CONFIGURATION
--------------------------------------------------------------------------------

-- Current accumulated recoil (pitch, yaw in degrees)
local recoilOffset = Vector2.new(0, 0)

-- How fast recoil recovers (higher = faster return to center)
local recoilRecoverySpeed = 8

-- Current interpolated ADS camera offset
local currentADSOffset = Vector3.new(0, 0, 0)

--------------------------------------------------------------------------------
-- SCREEN SHAKE
--------------------------------------------------------------------------------

-- Current screen shake intensity (0 = none, higher = more shake)
local screenShakeAmount = 0

-- How fast screen shake decays (higher = faster decay)
local screenShakeDecay = 10

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
	local scrollConnection = UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			local delta = input.Position.Z
			if delta > 0 then
				WeaponController.SwitchToNextSlot(-1)
			elseif delta < 0 then
				WeaponController.SwitchToNextSlot(1)
			end
		end
	end)
	table.insert(connections, scrollConnection)
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
		-- Apply recoil
		WeaponController.ApplyRecoil(currentWeapon)

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
	Update camera FOV, ADS offset, and recoil for enhanced weapon feel
	@param dt Delta time
]]
function WeaponController.UpdateCamera(dt: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local targetFOV = DEFAULT_FOV
	local targetOffset = Vector3.new(0, 0, 0)

	if isADS and currentWeapon then
		local scopeZoom = currentWeapon.definition.scopeZoom or 1
		if scopeZoom > 1 then
			targetFOV = DEFAULT_FOV / scopeZoom
		else
			targetFOV = DEFAULT_FOV * ADS_FOV_MULTIPLIER
		end
		-- Apply ADS offset to bring camera to sights
		targetOffset = ADS_OFFSET
	end

	-- Smooth FOV lerp
	local currentFOV = camera.FieldOfView
	local newFOV = currentFOV + (targetFOV - currentFOV) * math.min(1, FOV_LERP_SPEED * dt)
	camera.FieldOfView = newFOV

	-- Smooth ADS offset lerp
	currentADSOffset = currentADSOffset:Lerp(targetOffset, math.min(1, ADS_OFFSET_LERP_SPEED * dt))

	-- Apply recoil recovery (gradually return to center)
	if recoilOffset.Magnitude > 0.001 then
		recoilOffset = recoilOffset:Lerp(Vector2.new(0, 0), math.min(1, recoilRecoverySpeed * dt))
	end

	-- Apply screen shake decay
	if screenShakeAmount > 0.001 then
		screenShakeAmount = screenShakeAmount * math.exp(-screenShakeDecay * dt)
	else
		screenShakeAmount = 0
	end

	-- Apply combined camera effects (recoil + shake + ADS offset)
	local character = localPlayer.Character
	if character then
		local humanoid = character:FindFirstChild("Humanoid") :: Humanoid?
		if humanoid then
			-- Apply camera offset through CameraOffset (shifts view without rotating)
			local shakeOffset = Vector3.new(
				(math.random() - 0.5) * screenShakeAmount * 0.1,
				(math.random() - 0.5) * screenShakeAmount * 0.1,
				0
			)
			humanoid.CameraOffset = currentADSOffset + shakeOffset
		end
	end
end

--[[
	Apply recoil from weapon fire
	@param weapon The weapon that fired
]]
function WeaponController.ApplyRecoil(weapon: WeaponInstance)
	if not weapon then return end

	local weaponDef = weapon.definition
	local recoilAmount = weaponDef.recoil or 2

	-- Reduce recoil when ADS
	if isADS then
		recoilAmount = recoilAmount * 0.6
	end

	-- Add vertical recoil with slight horizontal variation
	local verticalRecoil = recoilAmount
	local horizontalRecoil = (math.random() - 0.5) * recoilAmount * 0.3

	recoilOffset = recoilOffset + Vector2.new(verticalRecoil, horizontalRecoil)

	-- Add screen shake on fire
	screenShakeAmount = screenShakeAmount + recoilAmount * 0.5

	-- Apply immediate camera kick
	local camera = workspace.CurrentCamera
	if camera then
		local kickAngle = CFrame.Angles(
			math.rad(-recoilAmount * 0.8), -- Pitch up
			math.rad(horizontalRecoil * 0.5), -- Slight yaw
			0
		)
		camera.CFrame = camera.CFrame * kickAngle
	end
end

--[[
	Get current mouse sensitivity multiplier (reduced when ADS)
	@return Sensitivity multiplier
]]
function WeaponController.GetSensitivityMultiplier(): number
	if isADS then
		return ADS_SENSITIVITY_MULTIPLIER
	end
	return 1
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
