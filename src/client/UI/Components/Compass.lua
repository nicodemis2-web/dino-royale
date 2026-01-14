--!strict
--[[
	Compass.lua
	===========
	Top-of-screen compass with direction indicators and markers
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Events = require(ReplicatedStorage.Shared.Events)

local Compass = {}

-- State
local player = Players.LocalPlayer
local screenGui: ScreenGui? = nil
local compassFrame: Frame? = nil
local markersContainer: Frame? = nil
local isVisible = true

-- Markers
local activeMarkers: { [string]: {
	position: Vector3,
	icon: string,
	color: Color3,
	label: string?,
	frame: Frame?,
} } = {}

-- Constants
local COMPASS_WIDTH = 600
local COMPASS_HEIGHT = 40
local FOV_DEGREES = 180 -- How many degrees the compass shows
local CARDINAL_DIRECTIONS = {
	{ angle = 0, label = "N", color = Color3.fromRGB(255, 100, 100) },
	{ angle = 45, label = "NE", color = Color3.fromRGB(200, 200, 200) },
	{ angle = 90, label = "E", color = Color3.fromRGB(255, 255, 255) },
	{ angle = 135, label = "SE", color = Color3.fromRGB(200, 200, 200) },
	{ angle = 180, label = "S", color = Color3.fromRGB(255, 255, 255) },
	{ angle = 225, label = "SW", color = Color3.fromRGB(200, 200, 200) },
	{ angle = 270, label = "W", color = Color3.fromRGB(255, 255, 255) },
	{ angle = 315, label = "NW", color = Color3.fromRGB(200, 200, 200) },
}

--[[
	Initialize the compass
]]
function Compass.Initialize()
	print("[Compass] Initializing...")

	Compass.CreateUI()
	Compass.SetupEventListeners()

	-- Start update loop
	RunService.RenderStepped:Connect(function()
		Compass.Update()
	end)

	print("[Compass] Initialized")
end

--[[
	Create UI elements
]]
function Compass.CreateUI()
	local playerGui = player:WaitForChild("PlayerGui")

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CompassGui"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	-- Main compass container
	compassFrame = Instance.new("Frame")
	compassFrame.Name = "Compass"
	compassFrame.Size = UDim2.new(0, COMPASS_WIDTH, 0, COMPASS_HEIGHT)
	compassFrame.Position = UDim2.new(0.5, 0, 0, 10)
	compassFrame.AnchorPoint = Vector2.new(0.5, 0)
	compassFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	compassFrame.BackgroundTransparency = 0.5
	compassFrame.BorderSizePixel = 0
	compassFrame.ClipsDescendants = true
	compassFrame.Parent = screenGui

	local compassCorner = Instance.new("UICorner")
	compassCorner.CornerRadius = UDim.new(0, 4)
	compassCorner.Parent = compassFrame

	-- Center indicator
	local centerLine = Instance.new("Frame")
	centerLine.Name = "CenterLine"
	centerLine.Size = UDim2.new(0, 2, 1, 0)
	centerLine.Position = UDim2.fromScale(0.5, 0)
	centerLine.AnchorPoint = Vector2.new(0.5, 0)
	centerLine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	centerLine.BorderSizePixel = 0
	centerLine.ZIndex = 10
	centerLine.Parent = compassFrame

	-- Degree markings container
	local degreesFrame = Instance.new("Frame")
	degreesFrame.Name = "Degrees"
	degreesFrame.Size = UDim2.fromScale(3, 1) -- Extra wide for scrolling
	degreesFrame.Position = UDim2.fromScale(0.5, 0)
	degreesFrame.AnchorPoint = Vector2.new(0.5, 0)
	degreesFrame.BackgroundTransparency = 1
	degreesFrame.Parent = compassFrame

	-- Create degree markers
	for deg = 0, 359, 15 do
		local marker = Instance.new("Frame")
		marker.Name = `Deg_{deg}`
		marker.Size = UDim2.new(0, 1, 0, deg % 45 == 0 and 15 or 8)
		marker.Position = UDim2.new(deg / 360, 0, 1, 0)
		marker.AnchorPoint = Vector2.new(0.5, 1)
		marker.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
		marker.BorderSizePixel = 0
		marker.Parent = degreesFrame
	end

	-- Create cardinal direction labels
	for _, dir in ipairs(CARDINAL_DIRECTIONS) do
		local label = Instance.new("TextLabel")
		label.Name = `Dir_{dir.label}`
		label.Size = UDim2.new(0, 30, 0, 20)
		label.Position = UDim2.new(dir.angle / 360, 0, 0.5, 0)
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.BackgroundTransparency = 1
		label.TextColor3 = dir.color
		label.TextSize = dir.label == "N" and 18 or 14
		label.Font = dir.label == "N" and Enum.Font.GothamBold or Enum.Font.Gotham
		label.Text = dir.label
		label.Parent = degreesFrame
	end

	-- Markers container
	markersContainer = Instance.new("Frame")
	markersContainer.Name = "Markers"
	markersContainer.Size = UDim2.fromScale(1, 1)
	markersContainer.BackgroundTransparency = 1
	markersContainer.Parent = compassFrame
end

--[[
	Setup event listeners
]]
function Compass.SetupEventListeners()
	-- Ping markers
	Events.OnClientEvent("Ping", function(action, data)
		if action == "Created" then
			Compass.AddMarker(data.id, data.position, data.pingType, data.color)
		elseif action == "Removed" then
			Compass.RemoveMarker(data.id)
		end
	end)

	-- Storm direction
	Events.OnClientEvent("Storm", function(action, data)
		if action == "PhaseChanged" or action == "Update" then
			Compass.UpdateStormMarker(data.center)
		end
	end)
end

--[[
	Update the compass
]]
function Compass.Update()
	if not compassFrame or not isVisible then return end

	local camera = workspace.CurrentCamera
	if not camera then return end

	-- Get camera look direction
	local lookVector = camera.CFrame.LookVector
	local yaw = math.deg(math.atan2(lookVector.X, lookVector.Z))

	-- Normalize to 0-360
	if yaw < 0 then
		yaw = yaw + 360
	end

	-- Update degrees frame position
	local degreesFrame = compassFrame:FindFirstChild("Degrees") :: Frame?
	if degreesFrame then
		-- Calculate offset to center current heading
		local normalizedHeading = yaw / 360
		local offset = 0.5 - normalizedHeading

		-- Handle wrapping by using multiple instances
		degreesFrame.Position = UDim2.new(0.5 + offset, 0, 0, 0)
	end

	-- Update markers
	Compass.UpdateMarkers(yaw)
end

--[[
	Update marker positions
]]
function Compass.UpdateMarkers(currentYaw: number)
	if not markersContainer then return end

	local character = player.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then return end

	local playerPos = rootPart.Position

	for id, marker in pairs(activeMarkers) do
		if marker.frame then
			-- Calculate angle to marker
			local direction = marker.position - playerPos
			local angle = math.deg(math.atan2(direction.X, direction.Z))

			if angle < 0 then
				angle = angle + 360
			end

			-- Calculate relative angle
			local relativeAngle = angle - currentYaw

			-- Normalize to -180 to 180
			while relativeAngle > 180 do
				relativeAngle = relativeAngle - 360
			end
			while relativeAngle < -180 do
				relativeAngle = relativeAngle + 360
			end

			-- Check if within FOV
			if math.abs(relativeAngle) <= FOV_DEGREES / 2 then
				marker.frame.Visible = true

				-- Calculate position on compass
				local normalizedPos = 0.5 + (relativeAngle / FOV_DEGREES)
				marker.frame.Position = UDim2.new(normalizedPos, 0, 0.5, 0)

				-- Calculate distance for display
				local distance = direction.Magnitude
				local distLabel = marker.frame:FindFirstChild("Distance") :: TextLabel?
				if distLabel then
					distLabel.Text = `{math.floor(distance)}m`
				end
			else
				marker.frame.Visible = false
			end
		end
	end
end

--[[
	Add a marker to the compass
]]
function Compass.AddMarker(id: string, position: Vector3, markerType: string, color: Color3?)
	-- Remove existing marker with same ID
	Compass.RemoveMarker(id)

	if not markersContainer then return end

	-- Create marker frame
	local markerFrame = Instance.new("Frame")
	markerFrame.Name = `Marker_{id}`
	markerFrame.Size = UDim2.new(0, 20, 0, 30)
	markerFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	markerFrame.BackgroundTransparency = 1
	markerFrame.Parent = markersContainer

	-- Marker icon
	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.Size = UDim2.new(0, 8, 0, 8)
	icon.Position = UDim2.new(0.5, 0, 0, 5)
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.BackgroundColor3 = color or Color3.fromRGB(255, 200, 50)
	icon.BorderSizePixel = 0
	icon.Parent = markerFrame

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(0.5, 0)
	iconCorner.Parent = icon

	-- Distance label
	local distLabel = Instance.new("TextLabel")
	distLabel.Name = "Distance"
	distLabel.Size = UDim2.new(0, 40, 0, 12)
	distLabel.Position = UDim2.new(0.5, 0, 1, -2)
	distLabel.AnchorPoint = Vector2.new(0.5, 1)
	distLabel.BackgroundTransparency = 1
	distLabel.TextColor3 = color or Color3.fromRGB(255, 200, 50)
	distLabel.TextSize = 10
	distLabel.Font = Enum.Font.Gotham
	distLabel.Text = "0m"
	distLabel.Parent = markerFrame

	activeMarkers[id] = {
		position = position,
		icon = markerType,
		color = color or Color3.fromRGB(255, 200, 50),
		frame = markerFrame,
	}
end

--[[
	Remove a marker
]]
function Compass.RemoveMarker(id: string)
	local marker = activeMarkers[id]
	if marker then
		if marker.frame then
			marker.frame:Destroy()
		end
		activeMarkers[id] = nil
	end
end

--[[
	Update storm direction marker
]]
function Compass.UpdateStormMarker(stormCenter: Vector3)
	-- Add/update storm marker
	Compass.AddMarker("storm_center", stormCenter, "Storm", Color3.fromRGB(150, 100, 200))
end

--[[
	Add teammate marker
]]
function Compass.AddTeammateMarker(teammate: Player)
	local character = teammate.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then return end

	Compass.AddMarker(`teammate_{teammate.UserId}`, rootPart.Position, "Teammate", Color3.fromRGB(100, 200, 255))
end

--[[
	Update teammate positions
]]
function Compass.UpdateTeammateMarkers(teammates: { Player })
	for _, teammate in ipairs(teammates) do
		local character = teammate.Character
		if character then
			local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if rootPart then
				local marker = activeMarkers[`teammate_{teammate.UserId}`]
				if marker then
					marker.position = rootPart.Position
				else
					Compass.AddTeammateMarker(teammate)
				end
			end
		end
	end
end

--[[
	Show the compass
]]
function Compass.Show()
	isVisible = true
	if screenGui then
		screenGui.Enabled = true
	end
end

--[[
	Hide the compass
]]
function Compass.Hide()
	isVisible = false
	if screenGui then
		screenGui.Enabled = false
	end
end

--[[
	Clear all markers
]]
function Compass.ClearMarkers()
	for id in pairs(activeMarkers) do
		Compass.RemoveMarker(id)
	end
end

return Compass
