--!strict
--[[
	WeaponServer.lua
	================
	Server-authoritative weapon handling
	Validates fire requests, performs raycasts, and applies damage
]]

local Players = game:GetService("Players")

local Events = require(game.ReplicatedStorage.Shared.Events)
local Constants = require(game.ReplicatedStorage.Shared.Constants)
local WeaponData = require(game.ReplicatedStorage.Shared.Config.WeaponData)
local WeaponBase = require(game.ReplicatedStorage.Shared.Weapons.WeaponBase)

-- Type imports
type WeaponInstance = WeaponBase.WeaponInstance

local WeaponServer = {}

--[[
	Configuration
]]
local Config = {
	POSITION_TOLERANCE = 10, -- Studs tolerance for origin validation
	FIRE_RATE_TOLERANCE = 1.2, -- 20% tolerance for fire rate
	MAX_FIRE_QUEUE = 5, -- Maximum queued fire requests
}

--[[
	Types
]]
export type HitResult = {
	hit: boolean,
	target: Instance?,
	position: Vector3?,
	normal: Vector3?,
	material: Enum.Material?,
	hitPart: string?,
	isPlayer: boolean,
	isDinosaur: boolean,
}

-- Player weapon states
local playerWeapons = {} :: { [number]: WeaponInstance? }

-- Fire rate tracking for anti-cheat
local fireTimestamps = {} :: { [number]: { number } }

-- Reference to HealthManager (set during initialization)
local HealthManager: any = nil

-- Reference to InventoryManager (set during initialization)
local InventoryManager: any = nil

--[[
	Initialize the weapon server
	@param healthManager Reference to HealthManager module
	@param inventoryManager Reference to InventoryManager module (optional)
]]
function WeaponServer.Initialize(healthManager: any, inventoryManager: any?)
	HealthManager = healthManager
	InventoryManager = inventoryManager

	-- Listen for weapon fire events
	Events.OnServerEvent("Combat", "WeaponFire", function(player, data)
		WeaponServer.HandleWeaponFire(player, data)
	end)

	-- Listen for reload events
	Events.OnServerEvent("Combat", "WeaponReload", function(player, data)
		WeaponServer.HandleWeaponReload(player, data)
	end)

	-- Cleanup on player leaving
	Players.PlayerRemoving:Connect(function(player)
		playerWeapons[player.UserId] = nil
		fireTimestamps[player.UserId] = nil
	end)
end

--[[
	Handle weapon fire request from client
	@param player The firing player
	@param data Fire data {weaponId, origin, direction}
]]
function WeaponServer.HandleWeaponFire(player: Player, data: any)
	-- Validate data structure
	if typeof(data) ~= "table" then
		return
	end

	local weaponId = data.weaponId
	local origin = data.origin
	local direction = data.direction

	if typeof(weaponId) ~= "string" or typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return
	end

	-- Get player's weapon
	local weapon = playerWeapons[player.UserId]
	if not weapon or weapon.id ~= weaponId then
		-- Player doesn't have this weapon equipped
		return
	end

	-- Validate fire rate (anti-cheat)
	if not WeaponServer.ValidateFireRate(player, weapon) then
		warn(`[WeaponServer] Fire rate violation from {player.Name}`)
		return
	end

	-- Validate origin position (anti-cheat)
	if not WeaponServer.ValidateOrigin(player, origin) then
		warn(`[WeaponServer] Origin violation from {player.Name}`)
		return
	end

	-- Validate weapon can fire
	if not weapon:CanFire() then
		return
	end

	-- Fire the weapon
	local fireResult = weapon:Fire(origin, direction)
	if not fireResult.success then
		return
	end

	-- Perform server-side raycast
	local hitResult = WeaponServer.PerformRaycast(player, origin, fireResult.spread or direction, weapon)

	-- Process hit
	if hitResult.hit then
		WeaponServer.ProcessHit(player, weapon, hitResult)
	end

	-- Record fire timestamp
	WeaponServer.RecordFire(player)

	-- Broadcast to nearby players for effects (optional - could use different system)
	-- Events.FireAllClients("Combat", "WeaponFired", {playerId = player.UserId, position = origin})
end

--[[
	Validate fire rate against weapon limits
	@param player The player
	@param weapon The weapon being fired
	@return Whether fire rate is valid
]]
function WeaponServer.ValidateFireRate(player: Player, weapon: WeaponInstance): boolean
	local userId = player.UserId
	local timestamps = fireTimestamps[userId]

	if not timestamps then
		timestamps = {}
		fireTimestamps[userId] = timestamps
	end

	local currentTime = tick()
	local expectedInterval = (1 / weapon.stats.fireRate) / Config.FIRE_RATE_TOLERANCE

	-- Clean old timestamps (keep last 10)
	while #timestamps > 10 do
		table.remove(timestamps, 1)
	end

	-- Check last fire time
	if #timestamps > 0 then
		local lastFire = timestamps[#timestamps]
		if currentTime - lastFire < expectedInterval then
			return false
		end
	end

	return true
end

--[[
	Validate fire origin is near player position
	@param player The player
	@param origin The claimed fire origin
	@return Whether origin is valid
]]
function WeaponServer.ValidateOrigin(player: Player, origin: Vector3): boolean
	local character = player.Character
	if not character then
		return false
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return false
	end

	local distance = (origin - rootPart.Position).Magnitude
	return distance <= Config.POSITION_TOLERANCE
end

--[[
	Perform server-side raycast
	@param player The firing player
	@param origin Ray origin
	@param direction Ray direction
	@param weapon The weapon being used
	@return HitResult
]]
function WeaponServer.PerformRaycast(
	player: Player,
	origin: Vector3,
	direction: Vector3,
	weapon: WeaponInstance
): HitResult
	-- Setup raycast params
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	-- Exclude shooter's character
	local excludeList = {}
	if player.Character then
		table.insert(excludeList, player.Character)
	end
	params.FilterDescendantsInstances = excludeList

	-- Perform raycast
	local rayResult = workspace:Raycast(origin, direction.Unit * weapon.stats.range, params)

	if not rayResult then
		return {
			hit = false,
			isPlayer = false,
			isDinosaur = false,
		}
	end

	-- Determine what was hit
	local hitInstance = rayResult.Instance
	local hitPart = hitInstance.Name
	local isPlayer = false
	local isDinosaur = false

	-- Check if hit a player
	local hitCharacter = hitInstance:FindFirstAncestorOfClass("Model")
	if hitCharacter then
		local hitPlayer = Players:GetPlayerFromCharacter(hitCharacter)
		if hitPlayer then
			isPlayer = true
		else
			-- Check for dinosaur tag
			if hitCharacter:HasTag("Dinosaur") then
				isDinosaur = true
			end
		end
	end

	return {
		hit = true,
		target = hitCharacter or hitInstance,
		position = rayResult.Position,
		normal = rayResult.Normal,
		material = rayResult.Material,
		hitPart = hitPart,
		isPlayer = isPlayer,
		isDinosaur = isDinosaur,
	}
end

--[[
	Process a hit result
	@param shooter The player who fired
	@param weapon The weapon used
	@param hitResult The hit result
]]
function WeaponServer.ProcessHit(shooter: Player, weapon: WeaponInstance, hitResult: HitResult)
	if not hitResult.hit or not hitResult.target then
		return
	end

	-- Calculate damage
	local damage = weapon:GetDamage(hitResult.hitPart)
	local isHeadshot = hitResult.hitPart and string.lower(hitResult.hitPart) == "head"

	if hitResult.isPlayer then
		-- Hit a player
		local hitCharacter = hitResult.target :: Model
		local hitPlayer = Players:GetPlayerFromCharacter(hitCharacter)

		if hitPlayer and HealthManager then
			-- Apply damage through HealthManager
			local damageResult = HealthManager.ApplyDamage(hitPlayer, damage, "Weapon", hitResult.hitPart)

			-- Send hit confirm to shooter
			Events.FireClient("Combat", "HitConfirm", shooter, {
				isHeadshot = isHeadshot,
				damage = damageResult.actualDamage,
			})

			-- Check for elimination
			if damageResult.isKill then
				-- EliminationManager handles this
			end
		end
	elseif hitResult.isDinosaur then
		-- Hit a dinosaur
		local dinoModel = hitResult.target :: Model
		local dinoId = dinoModel:GetAttribute("DinoId")

		if dinoId then
			-- Fire dinosaur damage event
			Events.FireAllClients("Dinosaur", "DinosaurDamaged", {
				dinoId = dinoId,
				damage = damage,
				-- newHealth would come from DinosaurManager
			})

			-- Send hit confirm to shooter
			Events.FireClient("Combat", "HitConfirm", shooter, {
				isHeadshot = isHeadshot,
				damage = damage,
			})
		end
	else
		-- Hit environment - broadcast impact position for effects
		if hitResult.position and hitResult.normal and hitResult.material then
			-- Could broadcast impact effect here
		end
	end
end

--[[
	Record a fire timestamp for anti-cheat
	@param player The player
]]
function WeaponServer.RecordFire(player: Player)
	local userId = player.UserId
	local timestamps = fireTimestamps[userId]

	if not timestamps then
		timestamps = {}
		fireTimestamps[userId] = timestamps
	end

	table.insert(timestamps, tick())

	-- Limit size
	while #timestamps > Config.MAX_FIRE_QUEUE do
		table.remove(timestamps, 1)
	end
end

--[[
	Handle reload request from client
	@param player The player
	@param data Reload data {weaponId}
]]
function WeaponServer.HandleWeaponReload(player: Player, data: any)
	if typeof(data) ~= "table" then
		return
	end

	local weaponId = data.weaponId
	if typeof(weaponId) ~= "string" then
		return
	end

	local weapon = playerWeapons[player.UserId]
	if not weapon or weapon.id ~= weaponId then
		return
	end

	-- Check if we have ammo in inventory pool
	local ammoType = WeaponData.GetAmmoType(weapon.id)
	local availableAmmo = 0

	if InventoryManager and ammoType then
		local inventory = InventoryManager.GetInventory(player)
		if inventory then
			availableAmmo = inventory.ammo[ammoType] or 0
		end
	else
		-- Fallback to weapon's reserve ammo if no inventory manager
		availableAmmo = weapon.state.reserveAmmo
	end

	-- Can't reload without ammo
	if availableAmmo <= 0 then
		return
	end

	-- Can't reload if mag is full
	if weapon.state.currentAmmo >= weapon.definition.magSize then
		return
	end

	-- Start reload
	weapon.state.isReloading = true

	-- Schedule reload completion
	task.delay(weapon.stats.reloadTime, function()
		-- Verify player still has weapon and is still reloading
		local currentWeapon = playerWeapons[player.UserId]
		if not currentWeapon or currentWeapon.id ~= weaponId or not currentWeapon.state.isReloading then
			return
		end

		-- Calculate ammo to transfer
		local ammoNeeded = currentWeapon.definition.magSize - currentWeapon.state.currentAmmo
		local ammoToTransfer = 0

		if InventoryManager and ammoType then
			-- Get current inventory ammo
			local inventory = InventoryManager.GetInventory(player)
			if inventory then
				local poolAmmo = inventory.ammo[ammoType] or 0
				ammoToTransfer = math.min(ammoNeeded, poolAmmo)

				-- Consume ammo from inventory pool
				if ammoToTransfer > 0 then
					InventoryManager.ConsumeAmmo(player, ammoType, ammoToTransfer)
				end
			end
		else
			-- Fallback to weapon's reserve ammo
			ammoToTransfer = math.min(ammoNeeded, currentWeapon.state.reserveAmmo)
			currentWeapon.state.reserveAmmo = currentWeapon.state.reserveAmmo - ammoToTransfer
		end

		-- Add ammo to magazine
		currentWeapon.state.currentAmmo = currentWeapon.state.currentAmmo + ammoToTransfer
		currentWeapon.state.isReloading = false

		-- Send inventory update to client
		if InventoryManager then
			InventoryManager.SendInventoryUpdate(player)
		end
	end)
end

--[[
	Equip a weapon for a player
	@param player The player
	@param weapon The weapon to equip
]]
function WeaponServer.EquipWeapon(player: Player, weapon: WeaponInstance)
	-- Cancel any current reload
	local currentWeapon = playerWeapons[player.UserId]
	if currentWeapon then
		currentWeapon:CancelReload()
	end

	playerWeapons[player.UserId] = weapon
	weapon.owner = player
end

--[[
	Unequip current weapon for a player
	@param player The player
	@return The unequipped weapon or nil
]]
function WeaponServer.UnequipWeapon(player: Player): WeaponInstance?
	local weapon = playerWeapons[player.UserId]
	if weapon then
		weapon:CancelReload()
		weapon.owner = nil
		playerWeapons[player.UserId] = nil
	end
	return weapon
end

--[[
	Get player's currently equipped weapon
	@param player The player
	@return The equipped weapon or nil
]]
function WeaponServer.GetEquippedWeapon(player: Player): WeaponInstance?
	return playerWeapons[player.UserId]
end

--[[
	Add ammo to player's equipped weapon
	@param player The player
	@param ammoType The ammo type
	@param amount The amount to add
	@return Overflow amount
]]
function WeaponServer.AddAmmo(player: Player, ammoType: string, amount: number): number
	local weapon = playerWeapons[player.UserId]
	if not weapon then
		return amount
	end

	local weaponAmmoType = WeaponData.GetAmmoType(weapon.id)
	if weaponAmmoType ~= ammoType then
		return amount
	end

	return weapon:AddAmmo(amount)
end

return WeaponServer
