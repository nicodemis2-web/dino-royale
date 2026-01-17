--!strict
--[[
	VehicleManager.lua
	==================
	Manages spawning, updating, and lifecycle of all vehicles
	Handles vehicle spawn points and proximity queries
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Events = require(game.ReplicatedStorage.Shared.Events)
local VehicleBase = require(script.Parent.VehicleBase)

local VehicleManager = {}

-- State
local activeVehicles = {} :: { [string]: VehicleBase.VehicleInstance }
local spawnPoints = {} :: { { position: CFrame, vehicleType: string, used: boolean } }
local isInitialized = false

-- Settings
local MAX_VEHICLES = 30
local VEHICLE_SPAWN_COUNTS = {
	Jeep = 8,
	ATV = 10,
	Boat = 6,
	Helicopter = 2,
	Motorcycle = 8,
}

-- Connections
local connections = {} :: { RBXScriptConnection }

-- Vehicle class references (lazy loaded)
local vehicleClasses = {} :: { [string]: any }

--[[
	Load vehicle class module
]]
local function getVehicleClass(vehicleType: string): any
	if vehicleClasses[vehicleType] then
		return vehicleClasses[vehicleType]
	end

	local success, module = pcall(function()
		return require(script.Parent:FindFirstChild(vehicleType))
	end)

	if success and module then
		vehicleClasses[vehicleType] = module
		return module
	end

	-- Fallback to base
	return VehicleBase
end

--[[
	Create a vehicle model (placeholder)
]]
local function createVehicleModel(vehicleType: string, position: CFrame): Model
	local model = Instance.new("Model")
	model.Name = vehicleType

	-- Create main body
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Anchored = false
	body.CanCollide = true

	-- Size based on vehicle type
	if vehicleType == "Jeep" then
		body.Size = Vector3.new(8, 4, 12)
		body.Color = Color3.fromRGB(50, 80, 50)
	elseif vehicleType == "ATV" then
		body.Size = Vector3.new(4, 3, 6)
		body.Color = Color3.fromRGB(150, 50, 50)
	elseif vehicleType == "Boat" then
		body.Size = Vector3.new(6, 2, 14)
		body.Color = Color3.fromRGB(200, 200, 200)
	elseif vehicleType == "Helicopter" then
		body.Size = Vector3.new(6, 4, 12)
		body.Color = Color3.fromRGB(40, 40, 40)
	elseif vehicleType == "Motorcycle" then
		body.Size = Vector3.new(2, 3, 6)
		body.Color = Color3.fromRGB(20, 20, 20)
	else
		body.Size = Vector3.new(6, 3, 10)
	end

	body.CFrame = position
	body.Parent = model

	-- Create vehicle seat
	local seat = Instance.new("VehicleSeat")
	seat.Name = "Seat1"
	seat.Size = Vector3.new(2, 1, 2)
	seat.CFrame = position * CFrame.new(0, 1, 2)
	seat.Parent = model

	-- Create proximity prompt for entry
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Enter"
	prompt.ObjectText = vehicleType
	prompt.MaxActivationDistance = 10
	prompt.HoldDuration = 0.3
	prompt.Parent = body

	model.PrimaryPart = body
	model.Parent = workspace

	return model
end

--[[
	Spawn a vehicle at a position
	@param vehicleType Type of vehicle
	@param position Spawn CFrame
	@return VehicleInstance or nil
]]
function VehicleManager.SpawnVehicle(vehicleType: string, position: CFrame): VehicleBase.VehicleInstance?
	-- Check max vehicles
	local count = 0
	for _ in pairs(activeVehicles) do
		count = count + 1
	end

	if count >= MAX_VEHICLES then
		warn("[VehicleManager] Max vehicles reached")
		return nil
	end

	-- Get vehicle class
	local VehicleClass = getVehicleClass(vehicleType)

	-- Create vehicle instance
	local vehicle = VehicleClass.new(vehicleType, position)

	-- Create model
	local model = createVehicleModel(vehicleType, position)
	vehicle:SetModel(model)

	-- Setup proximity prompt
	local body = model:FindFirstChild("Body")
	if body then
		local prompt = body:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				VehicleManager.OnVehicleInteract(vehicle, player)
			end)
		end
	end

	-- Register vehicle
	activeVehicles[vehicle.id] = vehicle

	-- Broadcast spawn
	Events.FireAllClients("Vehicle", "VehicleSpawned", {
		vehicleId = vehicle.id,
		vehicleType = vehicleType,
		position = position.Position,
	})

	print(`[VehicleManager] Spawned {vehicleType} at {position.Position}`)

	return vehicle
end

--[[
	Handle vehicle interaction (enter/exit)
]]
function VehicleManager.OnVehicleInteract(vehicle: VehicleBase.VehicleInstance, player: Player)
	-- Check if player is already in this vehicle
	for _seatIndex, occupant in pairs(vehicle.seats) do
		if occupant == player then
			-- Exit vehicle
			vehicle:Exit(player)
			return
		end
	end

	-- Check if player is in another vehicle
	for _, v in pairs(activeVehicles) do
		for _, occupant in pairs(v.seats) do
			if occupant == player then
				-- Exit other vehicle first
				v:Exit(player)
				break
			end
		end
	end

	-- Try to enter vehicle
	local availableSeat = vehicle:GetAvailableSeat()
	if availableSeat then
		vehicle:Enter(player, availableSeat)
	end
end

--[[
	Get nearest vehicle to a position
	@param position World position
	@param maxDistance Maximum search distance
	@return Nearest vehicle or nil
]]
function VehicleManager.GetNearestVehicle(position: Vector3, maxDistance: number?): VehicleBase.VehicleInstance?
	local searchRadius = maxDistance or 50
	local nearestVehicle: VehicleBase.VehicleInstance? = nil
	local nearestDistance = searchRadius

	for _, vehicle in pairs(activeVehicles) do
		if not vehicle.isDestroyed then
			local distance = (vehicle.position - position).Magnitude
			if distance < nearestDistance then
				nearestDistance = distance
				nearestVehicle = vehicle
			end
		end
	end

	return nearestVehicle
end

--[[
	Get vehicle by ID
]]
function VehicleManager.GetVehicle(id: string): VehicleBase.VehicleInstance?
	return activeVehicles[id]
end

--[[
	Get vehicle player is in
]]
function VehicleManager.GetPlayerVehicle(player: Player): VehicleBase.VehicleInstance?
	for _, vehicle in pairs(activeVehicles) do
		for _, occupant in pairs(vehicle.seats) do
			if occupant == player then
				return vehicle
			end
		end
	end
	return nil
end

--[[
	Handle vehicle destroyed
]]
function VehicleManager.OnVehicleDestroyed(vehicle: VehicleBase.VehicleInstance)
	activeVehicles[vehicle.id] = nil
	print(`[VehicleManager] Vehicle {vehicle.id} removed`)
end

--[[
	Find spawn points from map tags
]]
local function findSpawnPoints()
	spawnPoints = {}

	-- Find tagged spawn points
	for _, tag in ipairs({ "JeepSpawn", "ATVSpawn", "BoatSpawn", "HelicopterSpawn", "MotorcycleSpawn" }) do
		local vehicleType = tag:gsub("Spawn", "")
		local taggedPoints = CollectionService:GetTagged(tag)

		for _, part in ipairs(taggedPoints) do
			if part:IsA("BasePart") then
				table.insert(spawnPoints, {
					position = part.CFrame,
					vehicleType = vehicleType,
					used = false,
				})
			end
		end
	end

	-- Generic vehicle spawns
	local genericSpawns = CollectionService:GetTagged("VehicleSpawn")
	for _, part in ipairs(genericSpawns) do
		if part:IsA("BasePart") then
			local vehicleType = part:GetAttribute("VehicleType") or "Jeep"
			table.insert(spawnPoints, {
				position = part.CFrame,
				vehicleType = vehicleType,
				used = false,
			})
		end
	end

	print(`[VehicleManager] Found {#spawnPoints} spawn points`)
end

--[[
	Spawn initial vehicles
]]
local function spawnInitialVehicles()
	-- Count available spawn points per type
	local spawnsByType = {} :: { [string]: { { position: CFrame, vehicleType: string, used: boolean } } }

	for _, spawn in ipairs(spawnPoints) do
		if not spawnsByType[spawn.vehicleType] then
			spawnsByType[spawn.vehicleType] = {}
		end
		table.insert(spawnsByType[spawn.vehicleType], spawn)
	end

	-- Spawn vehicles at designated points
	for vehicleType, count in pairs(VEHICLE_SPAWN_COUNTS) do
		local typeSpawns = spawnsByType[vehicleType] or {}

		-- Shuffle spawns
		for i = #typeSpawns, 2, -1 do
			local j = math.random(1, i)
			typeSpawns[i], typeSpawns[j] = typeSpawns[j], typeSpawns[i]
		end

		-- Spawn up to count
		local spawned = 0
		for _, spawn in ipairs(typeSpawns) do
			if spawned >= count then
				break
			end

			if not spawn.used then
				VehicleManager.SpawnVehicle(vehicleType, spawn.position)
				spawn.used = true
				spawned = spawned + 1
			end
		end

		-- If not enough spawn points, generate random positions
		if spawned < count and #typeSpawns == 0 then
			for _ = 1, count - spawned do
				local randomPos = CFrame.new(
					math.random(-500, 500),
					5,
					math.random(-500, 500)
				)
				VehicleManager.SpawnVehicle(vehicleType, randomPos)
			end
		end
	end
end

--[[
	Update all vehicles
	@param dt Delta time
]]
function VehicleManager.Update(dt: number)
	if not isInitialized then
		return
	end

	for _id, vehicle in pairs(activeVehicles) do
		if vehicle.isDestroyed then
			VehicleManager.OnVehicleDestroyed(vehicle)
			continue
		end

		-- Get driver input if any
		local input: VehicleBase.VehicleInput? = nil
		if vehicle.driver then
			-- Input comes from VehicleInput events
			-- For now, vehicle just coasts
			local _ = vehicle.driver -- Acknowledge intentionally empty block
		end

		vehicle:Update(dt, input)
	end
end

--[[
	Handle vehicle input from client
]]
function VehicleManager.OnVehicleInput(player: Player, input: VehicleBase.VehicleInput)
	local vehicle = VehicleManager.GetPlayerVehicle(player)
	if not vehicle then
		return
	end

	-- Only driver can control
	if vehicle.driver ~= player then
		return
	end

	vehicle:Update(0.016, input) -- Approximate frame time
end

--[[
	Handle player enter request
]]
function VehicleManager.OnEnterVehicle(player: Player, data: { vehicleId: string, seat: number? })
	local vehicle = activeVehicles[data.vehicleId]
	if not vehicle then
		return
	end

	local seatIndex = data.seat or vehicle:GetAvailableSeat()
	if seatIndex then
		vehicle:Enter(player, seatIndex)
	end
end

--[[
	Handle player exit request
]]
function VehicleManager.OnExitVehicle(player: Player)
	local vehicle = VehicleManager.GetPlayerVehicle(player)
	if vehicle then
		vehicle:Exit(player)
	end
end

--[[
	Get active vehicle count
]]
function VehicleManager.GetActiveCount(): number
	local count = 0
	for _ in pairs(activeVehicles) do
		count = count + 1
	end
	return count
end

--[[
	Initialize the vehicle manager
]]
function VehicleManager.Initialize()
	if isInitialized then
		return
	end

	findSpawnPoints()
	spawnInitialVehicles()

	-- Update loop
	local updateConnection = RunService.Heartbeat:Connect(function(dt)
		VehicleManager.Update(dt)
	end)
	table.insert(connections, updateConnection)

	-- Listen for vehicle events
	local inputConnection = Events.OnServerEvent("Vehicle", "VehicleInput", function(player, data)
		VehicleManager.OnVehicleInput(player, data)
	end)
	table.insert(connections, inputConnection)

	local enterConnection = Events.OnServerEvent("Vehicle", "EnterVehicle", function(player, data)
		VehicleManager.OnEnterVehicle(player, data)
	end)
	table.insert(connections, enterConnection)

	local exitConnection = Events.OnServerEvent("Vehicle", "ExitVehicle", function(player)
		VehicleManager.OnExitVehicle(player)
	end)
	table.insert(connections, exitConnection)

	-- Handle player removing (exit vehicle)
	local playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
		local vehicle = VehicleManager.GetPlayerVehicle(player)
		if vehicle then
			vehicle:Exit(player)
		end
	end)
	table.insert(connections, playerRemovingConnection)

	isInitialized = true
	print("[VehicleManager] Initialized")
end

--[[
	Reset the manager
]]
function VehicleManager.Reset()
	for _id, vehicle in pairs(activeVehicles) do
		if vehicle.model then
			vehicle.model:Destroy()
		end
	end

	activeVehicles = {}

	-- Reset spawn points
	for _, spawn in ipairs(spawnPoints) do
		spawn.used = false
	end

	print("[VehicleManager] Reset")
end

--[[
	Cleanup
]]
function VehicleManager.Cleanup()
	isInitialized = false

	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	connections = {}

	VehicleManager.Reset()
end

return VehicleManager
