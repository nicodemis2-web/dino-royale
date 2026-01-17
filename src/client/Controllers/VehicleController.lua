--!strict
--[[
	VehicleController.lua
	=====================
	Client-side vehicle controls and UI
	Handles input, camera, and vehicle HUD
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local _UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Events = require(game.ReplicatedStorage.Shared.Events)

local VehicleController = {}

-- Local player reference
local localPlayer = Players.LocalPlayer

-- State
local currentVehicle: { [string]: any }? = nil
local isDriver = false
local __currentSeatIndex = 0

-- Input state
local throttleInput = 0
local steerInput = 0
local brakeInput = false
local hornInput = false
local altitudeInput = 0 -- For helicopter

-- Camera settings
local VEHICLE_CAMERA_DISTANCE = 20
local VEHICLE_CAMERA_HEIGHT = 8
local CAMERA_LERP_SPEED = 10

-- UI references
local vehicleGui: ScreenGui? = nil
local speedLabel: TextLabel? = nil
local healthBar: Frame? = nil
local fuelBar: Frame? = nil

-- Connections
local connections = {} :: { RBXScriptConnection }

--[[
	Create vehicle HUD
]]
local function createVehicleUI()
	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

	vehicleGui = Instance.new("ScreenGui")
	vehicleGui.Name = "VehicleGui"
	vehicleGui.ResetOnSpawn = false
	vehicleGui.Parent = playerGui

	-- Speedometer (bottom center)
	local speedFrame = Instance.new("Frame")
	speedFrame.Name = "Speedometer"
	speedFrame.AnchorPoint = Vector2.new(0.5, 1)
	speedFrame.Position = UDim2.new(0.5, 0, 1, -20)
	speedFrame.Size = UDim2.fromOffset(200, 60)
	speedFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	speedFrame.BackgroundTransparency = 0.3
	speedFrame.Parent = vehicleGui

	local speedCorner = Instance.new("UICorner")
	speedCorner.CornerRadius = UDim.new(0, 8)
	speedCorner.Parent = speedFrame

	speedLabel = Instance.new("TextLabel")
	speedLabel.Name = "Speed"
	speedLabel.Size = UDim2.fromScale(1, 1)
	speedLabel.BackgroundTransparency = 1
	speedLabel.Text = "0 km/h"
	speedLabel.TextColor3 = Color3.new(1, 1, 1)
	speedLabel.TextSize = 32
	speedLabel.Font = Enum.Font.GothamBold
	speedLabel.Parent = speedFrame

	-- Health bar (bottom left)
	local healthFrame = Instance.new("Frame")
	healthFrame.Name = "HealthFrame"
	healthFrame.AnchorPoint = Vector2.new(0, 1)
	healthFrame.Position = UDim2.new(0, 20, 1, -20)
	healthFrame.Size = UDim2.fromOffset(150, 20)
	healthFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	healthFrame.Parent = vehicleGui

	local healthCorner = Instance.new("UICorner")
	healthCorner.CornerRadius = UDim.new(0, 4)
	healthCorner.Parent = healthFrame

	healthBar = Instance.new("Frame")
	healthBar.Name = "HealthBar"
	healthBar.Size = UDim2.fromScale(1, 1)
	healthBar.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
	healthBar.Parent = healthFrame

	local healthBarCorner = Instance.new("UICorner")
	healthBarCorner.CornerRadius = UDim.new(0, 4)
	healthBarCorner.Parent = healthBar

	local healthLabel = Instance.new("TextLabel")
	healthLabel.Name = "Label"
	healthLabel.Size = UDim2.fromScale(1, 1)
	healthLabel.BackgroundTransparency = 1
	healthLabel.Text = "VEHICLE"
	healthLabel.TextColor3 = Color3.new(1, 1, 1)
	healthLabel.TextSize = 12
	healthLabel.Font = Enum.Font.GothamBold
	healthLabel.Parent = healthFrame

	-- Fuel bar (only for helicopter)
	local fuelFrame = Instance.new("Frame")
	fuelFrame.Name = "FuelFrame"
	fuelFrame.AnchorPoint = Vector2.new(0, 1)
	fuelFrame.Position = UDim2.new(0, 20, 1, -50)
	fuelFrame.Size = UDim2.fromOffset(150, 20)
	fuelFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	fuelFrame.Visible = false
	fuelFrame.Parent = vehicleGui

	local fuelCorner = Instance.new("UICorner")
	fuelCorner.CornerRadius = UDim.new(0, 4)
	fuelCorner.Parent = fuelFrame

	fuelBar = Instance.new("Frame")
	fuelBar.Name = "FuelBar"
	fuelBar.Size = UDim2.fromScale(1, 1)
	fuelBar.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
	fuelBar.Parent = fuelFrame

	local fuelBarCorner = Instance.new("UICorner")
	fuelBarCorner.CornerRadius = UDim.new(0, 4)
	fuelBarCorner.Parent = fuelBar

	local fuelLabel = Instance.new("TextLabel")
	fuelLabel.Name = "Label"
	fuelLabel.Size = UDim2.fromScale(1, 1)
	fuelLabel.BackgroundTransparency = 1
	fuelLabel.Text = "FUEL"
	fuelLabel.TextColor3 = Color3.new(1, 1, 1)
	fuelLabel.TextSize = 12
	fuelLabel.Font = Enum.Font.GothamBold
	fuelLabel.Parent = fuelFrame
end

--[[
	Destroy vehicle UI
]]
local function destroyVehicleUI()
	if vehicleGui then
		vehicleGui:Destroy()
		vehicleGui = nil
	end
	speedLabel = nil
	healthBar = nil
	fuelBar = nil
end

--[[
	Update vehicle UI
]]
local function updateVehicleUI()
	if not currentVehicle or not vehicleGui then
		return
	end

	-- Update speed
	if speedLabel then
		local speed = math.floor(math.abs(currentVehicle.speed or 0) * 3.6) -- Convert to km/h
		speedLabel.Text = `{speed} km/h`
	end

	-- Update health
	if healthBar then
		local healthPercent = (currentVehicle.health or 0) / (currentVehicle.maxHealth or 1)
		healthBar.Size = UDim2.fromScale(healthPercent, 1)

		-- Color based on health
		if healthPercent > 0.5 then
			healthBar.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
		elseif healthPercent > 0.25 then
			healthBar.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
		else
			healthBar.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
		end
	end

	-- Update fuel (helicopter only)
	if fuelBar and currentVehicle.fuel ~= nil then
		local fuelFrame = fuelBar.Parent :: Frame?
		if fuelFrame then
			fuelFrame.Visible = true
		end

		local fuelPercent = (currentVehicle.fuel or 0) / (currentVehicle.maxFuel or 1)
		fuelBar.Size = UDim2.fromScale(fuelPercent, 1)
	end
end

--[[
	Update vehicle camera
]]
local function updateVehicleCamera()
	if not currentVehicle then
		return
	end

	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	-- Get vehicle position
	local vehiclePos = currentVehicle.position or Vector3.zero

	-- Calculate camera position behind and above vehicle
	local rotation = currentVehicle.rotation or CFrame.new()
	local backward = -rotation.LookVector
	local cameraOffset = backward * VEHICLE_CAMERA_DISTANCE + Vector3.new(0, VEHICLE_CAMERA_HEIGHT, 0)
	local targetCameraPos = vehiclePos + cameraOffset

	-- Smooth camera movement
	local currentPos = camera.CFrame.Position
	local newPos = currentPos:Lerp(targetCameraPos, CAMERA_LERP_SPEED * 0.016)

	camera.CFrame = CFrame.new(newPos, vehiclePos)
end

--[[
	Bind vehicle controls
]]
local function bindVehicleControls()
	-- Throttle (W/S)
	ContextActionService:BindAction("VehicleThrottle", function(_, inputState, inputObject)
		if inputObject.KeyCode == Enum.KeyCode.W then
			throttleInput = inputState == Enum.UserInputState.Begin and 1 or 0
		elseif inputObject.KeyCode == Enum.KeyCode.S then
			throttleInput = inputState == Enum.UserInputState.Begin and -1 or 0
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.W, Enum.KeyCode.S)

	-- Steering (A/D)
	ContextActionService:BindAction("VehicleSteer", function(_, inputState, inputObject)
		if inputObject.KeyCode == Enum.KeyCode.A then
			steerInput = inputState == Enum.UserInputState.Begin and -1 or 0
		elseif inputObject.KeyCode == Enum.KeyCode.D then
			steerInput = inputState == Enum.UserInputState.Begin and 1 or 0
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.A, Enum.KeyCode.D)

	-- Brake (Space)
	ContextActionService:BindAction("VehicleBrake", function(_, inputState)
		brakeInput = inputState == Enum.UserInputState.Begin
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Space)

	-- Horn (H)
	ContextActionService:BindAction("VehicleHorn", function(_, inputState)
		hornInput = inputState == Enum.UserInputState.Begin
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.H)

	-- Exit (F)
	ContextActionService:BindAction("VehicleExit", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			VehicleController.ExitVehicle()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.F)

	-- Helicopter altitude (Q/E)
	ContextActionService:BindAction("VehicleAltitude", function(_, inputState, inputObject)
		if inputObject.KeyCode == Enum.KeyCode.Q then
			altitudeInput = inputState == Enum.UserInputState.Begin and 1 or 0
		elseif inputObject.KeyCode == Enum.KeyCode.E then
			altitudeInput = inputState == Enum.UserInputState.Begin and -1 or 0
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Q, Enum.KeyCode.E)
end

--[[
	Unbind vehicle controls
]]
local function unbindVehicleControls()
	ContextActionService:UnbindAction("VehicleThrottle")
	ContextActionService:UnbindAction("VehicleSteer")
	ContextActionService:UnbindAction("VehicleBrake")
	ContextActionService:UnbindAction("VehicleHorn")
	ContextActionService:UnbindAction("VehicleExit")
	ContextActionService:UnbindAction("VehicleAltitude")

	throttleInput = 0
	steerInput = 0
	brakeInput = false
	hornInput = false
	altitudeInput = 0
end

--[[
	Send input to server
]]
local function sendVehicleInput()
	if not currentVehicle or not isDriver then
		return
	end

	Events.FireServer("Vehicle", "VehicleInput", {
		throttle = throttleInput,
		steer = steerInput,
		brake = brakeInput,
		horn = hornInput,
		altitude = altitudeInput,
	})
end

--[[
	Enter a vehicle
]]
function VehicleController.EnterVehicle(vehicleId: string, seatIndex: number?)
	Events.FireServer("Vehicle", "EnterVehicle", {
		vehicleId = vehicleId,
		seat = seatIndex,
	})
end

--[[
	Exit current vehicle
]]
function VehicleController.ExitVehicle()
	if currentVehicle then
		Events.FireServer("Vehicle", "ExitVehicle", {})
	end
end

--[[
	Handle player entered vehicle event
]]
local function onPlayerEntered(data: { vehicleId: string, playerId: number, seatIndex: number })
	if data.playerId ~= localPlayer.UserId then
		return
	end

	currentVehicle = {
		id = data.vehicleId,
		seatIndex = data.seatIndex,
		position = Vector3.zero,
		rotation = CFrame.new(),
		speed = 0,
		health = 100,
		maxHealth = 100,
	}
	_currentSeatIndex = data.seatIndex
	isDriver = data.seatIndex == 1

	createVehicleUI()

	if isDriver then
		bindVehicleControls()
	end

	print(`[VehicleController] Entered vehicle {data.vehicleId} seat {data.seatIndex}`)
end

--[[
	Handle player exited vehicle event
]]
local function onPlayerExited(data: { vehicleId: string, playerId: number })
	if data.playerId ~= localPlayer.UserId then
		return
	end

	unbindVehicleControls()
	destroyVehicleUI()

	currentVehicle = nil
	isDriver = false
	_currentSeatIndex = 0

	print("[VehicleController] Exited vehicle")
end

--[[
	Handle vehicle state update
]]
local function onVehicleUpdate(data: { vehicleId: string, position: Vector3, rotation: CFrame, speed: number, health: number, maxHealth: number, fuel: number?, maxFuel: number? })
	if not currentVehicle or currentVehicle.id ~= data.vehicleId then
		return
	end

	currentVehicle.position = data.position
	currentVehicle.rotation = data.rotation
	currentVehicle.speed = data.speed
	currentVehicle.health = data.health
	currentVehicle.maxHealth = data.maxHealth
	currentVehicle.fuel = data.fuel
	currentVehicle.maxFuel = data.maxFuel
end

--[[
	Handle vehicle destroyed
]]
local function onVehicleDestroyed(data: { vehicleId: string })
	if currentVehicle and currentVehicle.id == data.vehicleId then
		unbindVehicleControls()
		destroyVehicleUI()
		currentVehicle = nil
		isDriver = false
		_currentSeatIndex = 0
	end
end

--[[
	Update loop
]]
local function update(_dt: number)
	if currentVehicle then
		updateVehicleUI()

		if isDriver then
			sendVehicleInput()
			updateVehicleCamera()
		end
	end
end

--[[
	Check if in vehicle
]]
function VehicleController.IsInVehicle(): boolean
	return currentVehicle ~= nil
end

--[[
	Check if driving
]]
function VehicleController.IsDriver(): boolean
	return isDriver
end

--[[
	Get current vehicle ID
]]
function VehicleController.GetCurrentVehicleId(): string?
	return currentVehicle and currentVehicle.id or nil
end

--[[
	Initialize the vehicle controller
]]
function VehicleController.Initialize()
	-- Listen for vehicle events
	local enteredConn = Events.OnClientEvent("Vehicle", "PlayerEntered", onPlayerEntered)
	table.insert(connections, enteredConn)

	local exitedConn = Events.OnClientEvent("Vehicle", "PlayerExited", onPlayerExited)
	table.insert(connections, exitedConn)

	local updateConn = Events.OnClientEvent("Vehicle", "VehicleUpdate", onVehicleUpdate)
	table.insert(connections, updateConn)

	local destroyedConn = Events.OnClientEvent("Vehicle", "VehicleDestroyed", onVehicleDestroyed)
	table.insert(connections, destroyedConn)

	-- Update loop
	local heartbeatConn = RunService.Heartbeat:Connect(update)
	table.insert(connections, heartbeatConn)

	-- Enter vehicle with E key when near
	ContextActionService:BindAction("InteractVehicle", function(_, inputState)
		if inputState == Enum.UserInputState.Begin and not currentVehicle then
			-- Server handles proximity check via RemoteEvent
			return Enum.ContextActionResult.Pass
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.E)

	print("[VehicleController] Initialized")
end

--[[
	Cleanup
]]
function VehicleController.Cleanup()
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	connections = {}

	unbindVehicleControls()
	destroyVehicleUI()

	ContextActionService:UnbindAction("InteractVehicle")

	currentVehicle = nil
	isDriver = false
end

return VehicleController
