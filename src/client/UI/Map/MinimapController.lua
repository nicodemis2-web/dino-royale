--!strict
--[[
	MinimapController.lua
	=====================
	Client-side minimap controller
	Handles minimap rendering, POI markers, and player tracking
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Events = require(ReplicatedStorage.Shared.Events)
local BiomeData = require(ReplicatedStorage.Shared.BiomeData)
local POIData = require(ReplicatedStorage.Shared.POIData)

local MinimapController = {}

-- Types
export type MinimapMarker = {
	id: string,
	position: Vector3,
	markerType: string,
	icon: string?,
	color: Color3?,
	label: string?,
	visible: boolean,
	frame: Frame?,
}

export type MinimapConfig = {
	size: UDim2,
	position: UDim2,
	mapRadius: number, -- World units shown on minimap
	rotation: boolean, -- Rotate map with player
	showBiomes: boolean,
	showPOIs: boolean,
	showTeammates: boolean,
	showEnemies: boolean,
	showDinosaurs: boolean,
	showVehicles: boolean,
	showStorm: boolean,
}

-- State
local player = Players.LocalPlayer
local minimapFrame: Frame? = nil
local mapContainer: Frame? = nil
local playerMarker: Frame? = nil
local stormCircle: Frame? = nil
local markers: { [string]: MinimapMarker } = {}
local config: MinimapConfig = {
	size = UDim2.fromOffset(200, 200),
	position = UDim2.new(1, -220, 0, 20),
	mapRadius = 150,
	rotation = true,
	showBiomes = true,
	showPOIs = true,
	showTeammates = true,
	showEnemies = false,
	showDinosaurs = true,
	showVehicles = true,
	showStorm = true,
}

local isInitialized = false
local isVisible = true
local _currentBiome = ""

-- Map bounds (would be set from map data)
local mapCenter = Vector3.new(0, 0, 0)
local mapSize = 2048 -- World units

-- Constants
local MARKER_SIZE = 10
local POI_MARKER_SIZE = 16
local PLAYER_MARKER_SIZE = 12
local TEAMMATE_COLOR = Color3.fromRGB(0, 200, 255)
local ENEMY_COLOR = Color3.fromRGB(255, 80, 80)
local DINO_COLOR = Color3.fromRGB(255, 200, 0)
local VEHICLE_COLOR = Color3.fromRGB(100, 255, 100)
local STORM_COLOR = Color3.fromRGB(150, 50, 200)

--[[
	Initialize the minimap controller
]]
function MinimapController.Initialize()
	if isInitialized then return end
	isInitialized = true

	print("[MinimapController] Initializing...")

	-- Create minimap UI
	MinimapController.CreateMinimapUI()

	-- Setup event listeners
	MinimapController.SetupEventListeners()

	-- Start update loop
	RunService.RenderStepped:Connect(function()
		if isVisible then
			MinimapController.Update()
		end
	end)

	print("[MinimapController] Initialized")
end

--[[
	Create the minimap UI
]]
function MinimapController.CreateMinimapUI()
	local playerGui = player:WaitForChild("PlayerGui")

	-- Check if already exists
	local existingGui = playerGui:FindFirstChild("MinimapGui")
	if existingGui then
		existingGui:Destroy()
	end

	-- Create ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MinimapGui"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	-- Main minimap frame (circular mask)
	minimapFrame = Instance.new("Frame")
	minimapFrame.Name = "MinimapFrame"
	minimapFrame.Size = config.size
	minimapFrame.Position = config.position
	minimapFrame.AnchorPoint = Vector2.new(1, 0)
	minimapFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	minimapFrame.BorderSizePixel = 0
	minimapFrame.Parent = screenGui

	-- Corner rounding
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = minimapFrame

	-- Border
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(100, 100, 100)
	stroke.Thickness = 2
	stroke.Parent = minimapFrame

	-- Map container (rotates)
	mapContainer = Instance.new("Frame")
	mapContainer.Name = "MapContainer"
	mapContainer.Size = UDim2.fromScale(1, 1)
	mapContainer.Position = UDim2.fromScale(0.5, 0.5)
	mapContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	mapContainer.BackgroundTransparency = 1
	mapContainer.ClipsDescendants = true
	mapContainer.Parent = minimapFrame

	-- Create biome background layers
	if config.showBiomes then
		MinimapController.CreateBiomeLayers()
	end

	-- Storm circle indicator
	if config.showStorm then
		stormCircle = Instance.new("Frame")
		stormCircle.Name = "StormCircle"
		stormCircle.Size = UDim2.fromScale(0.8, 0.8)
		stormCircle.Position = UDim2.fromScale(0.5, 0.5)
		stormCircle.AnchorPoint = Vector2.new(0.5, 0.5)
		stormCircle.BackgroundTransparency = 1
		stormCircle.Parent = mapContainer

		local stormStroke = Instance.new("UIStroke")
		stormStroke.Color = STORM_COLOR
		stormStroke.Thickness = 3
		stormStroke.Parent = stormCircle

		local stormCorner = Instance.new("UICorner")
		stormCorner.CornerRadius = UDim.new(0.5, 0)
		stormCorner.Parent = stormCircle
	end

	-- Player marker (always centered)
	playerMarker = Instance.new("Frame")
	playerMarker.Name = "PlayerMarker"
	playerMarker.Size = UDim2.fromOffset(PLAYER_MARKER_SIZE, PLAYER_MARKER_SIZE)
	playerMarker.Position = UDim2.fromScale(0.5, 0.5)
	playerMarker.AnchorPoint = Vector2.new(0.5, 0.5)
	playerMarker.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	playerMarker.BorderSizePixel = 0
	playerMarker.ZIndex = 10
	playerMarker.Parent = minimapFrame

	local playerCorner = Instance.new("UICorner")
	playerCorner.CornerRadius = UDim.new(0.5, 0)
	playerCorner.Parent = playerMarker

	-- Direction indicator (triangle)
	local directionIndicator = Instance.new("ImageLabel")
	directionIndicator.Name = "Direction"
	directionIndicator.Size = UDim2.fromOffset(8, 12)
	directionIndicator.Position = UDim2.fromScale(0.5, 0)
	directionIndicator.AnchorPoint = Vector2.new(0.5, 1)
	directionIndicator.BackgroundTransparency = 1
	directionIndicator.Image = "rbxassetid://0" -- Would use actual triangle asset
	directionIndicator.ImageColor3 = Color3.fromRGB(255, 255, 255)
	directionIndicator.Parent = playerMarker

	-- Compass directions
	MinimapController.CreateCompass()

	-- Biome label
	local biomeLabel = Instance.new("TextLabel")
	biomeLabel.Name = "BiomeLabel"
	biomeLabel.Size = UDim2.new(1, 0, 0, 20)
	biomeLabel.Position = UDim2.new(0, 0, 1, 5)
	biomeLabel.BackgroundTransparency = 1
	biomeLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	biomeLabel.TextSize = 12
	biomeLabel.Font = Enum.Font.GothamBold
	biomeLabel.Text = ""
	biomeLabel.Parent = minimapFrame

	-- Create POI markers
	if config.showPOIs then
		MinimapController.CreatePOIMarkers()
	end
end

--[[
	Create biome background layers
]]
function MinimapController.CreateBiomeLayers()
	if not mapContainer then return end

	for biomeName, biome in pairs(BiomeData.Biomes) do
		-- Create a simple colored region for each biome
		-- In a real implementation, this would use a texture or procedural rendering

		local biomeFrame = Instance.new("Frame")
		biomeFrame.Name = `Biome_{biomeName}`

		-- Position based on biome bounds (simplified)
		local pos = biome.bounds.center
		local size = biome.bounds.radius * 2

		-- Convert world position to minimap position
		local relX = (pos.X - mapCenter.X) / mapSize + 0.5
		local relZ = (pos.Z - mapCenter.Z) / mapSize + 0.5
		local relSize = size / mapSize

		biomeFrame.Size = UDim2.fromScale(relSize, relSize)
		biomeFrame.Position = UDim2.fromScale(relX, relZ)
		biomeFrame.AnchorPoint = Vector2.new(0.5, 0.5)
		biomeFrame.BackgroundColor3 = biome.minimapColor
		biomeFrame.BackgroundTransparency = 0.3
		biomeFrame.BorderSizePixel = 0
		biomeFrame.ZIndex = 1
		biomeFrame.Parent = mapContainer

		local biomeCorner = Instance.new("UICorner")
		biomeCorner.CornerRadius = UDim.new(0.2, 0)
		biomeCorner.Parent = biomeFrame
	end
end

--[[
	Create compass directions
]]
function MinimapController.CreateCompass()
	if not minimapFrame then return end

	local directions = {
		{ letter = "N", position = UDim2.fromScale(0.5, 0.02), color = Color3.fromRGB(255, 100, 100) },
		{ letter = "E", position = UDim2.fromScale(0.98, 0.5), color = Color3.fromRGB(200, 200, 200) },
		{ letter = "S", position = UDim2.fromScale(0.5, 0.98), color = Color3.fromRGB(200, 200, 200) },
		{ letter = "W", position = UDim2.fromScale(0.02, 0.5), color = Color3.fromRGB(200, 200, 200) },
	}

	for _, dir in ipairs(directions) do
		local label = Instance.new("TextLabel")
		label.Name = `Compass_{dir.letter}`
		label.Size = UDim2.fromOffset(15, 15)
		label.Position = dir.position
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.BackgroundTransparency = 1
		label.TextColor3 = dir.color
		label.TextSize = 12
		label.Font = Enum.Font.GothamBold
		label.Text = dir.letter
		label.ZIndex = 20
		label.Parent = minimapFrame
	end
end

--[[
	Create POI markers
]]
function MinimapController.CreatePOIMarkers()
	for poiId, poi in pairs(POIData.POIs) do
		MinimapController.AddMarker({
			id = `poi_{poiId}`,
			position = POIData.GetPosition(poi),
			markerType = "POI",
			icon = POIData.GetIcon(poi),
			color = POIData.GetTierColor(poi.lootTier),
			label = poi.displayName,
			visible = true,
		})
	end
end

--[[
	Setup event listeners
]]
function MinimapController.SetupEventListeners()
	-- Storm updates
	Events.OnClientEvent("Storm", function(action, data)
		if action == "PhaseChanged" then
			MinimapController.UpdateStormCircle(data.center, data.radius)
		end
	end)

	-- Teammate markers
	Events.OnClientEvent("Team", function(action, data)
		if action == "TeammatePosition" then
			MinimapController.UpdateTeammateMarker(data.playerId, data.position)
		end
	end)

	-- Dinosaur markers (from detection/motion sensor)
	Events.OnClientEvent("Detection", function(action, data)
		if action == "DinosaurDetected" then
			MinimapController.AddTemporaryMarker({
				id = `dino_{data.id}`,
				position = data.position,
				markerType = "Dinosaur",
				color = DINO_COLOR,
				label = data.name,
				visible = true,
			}, data.duration or 3)
		elseif action == "EnemyDetected" then
			MinimapController.AddTemporaryMarker({
				id = `enemy_{data.id}`,
				position = data.position,
				markerType = "Enemy",
				color = ENEMY_COLOR,
				visible = true,
			}, data.duration or 3)
		end
	end)

	-- Vehicle markers
	Events.OnClientEvent("Vehicle", function(action, data)
		if action == "VehicleSpawned" then
			MinimapController.AddMarker({
				id = `vehicle_{data.id}`,
				position = data.position,
				markerType = "Vehicle",
				color = VEHICLE_COLOR,
				label = data.name,
				visible = true,
			})
		elseif action == "VehicleDestroyed" then
			MinimapController.RemoveMarker(`vehicle_{data.id}`)
		end
	end)

	-- Biome changed
	Events.OnClientEvent("Biome", function(action, data)
		if action == "EnteredBiome" then
			MinimapController.UpdateCurrentBiome(data.biome)
		end
	end)
end

--[[
	Update minimap
]]
function MinimapController.Update()
	local character = player.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then return end

	local playerPos = rootPart.Position
	local playerRotation = rootPart.CFrame.LookVector

	-- Update map container rotation (if rotating map)
	if config.rotation and mapContainer then
		local angle = math.atan2(playerRotation.X, playerRotation.Z)
		mapContainer.Rotation = math.deg(angle)
	end

	-- Update player direction indicator (if not rotating map)
	if not config.rotation and playerMarker then
		local angle = math.atan2(playerRotation.X, playerRotation.Z)
		playerMarker.Rotation = math.deg(angle)
	end

	-- Update all markers relative to player position
	for _, marker in pairs(markers) do
		if marker.frame and marker.visible then
			local relativePos = marker.position - playerPos
			local distance = relativePos.Magnitude

			-- Check if within minimap radius
			if distance <= config.mapRadius then
				marker.frame.Visible = true

				-- Convert to minimap coordinates
				local mapX = relativePos.X / config.mapRadius * 0.5 + 0.5
				local mapZ = relativePos.Z / config.mapRadius * 0.5 + 0.5

				marker.frame.Position = UDim2.fromScale(mapX, mapZ)
			else
				-- Show at edge for important markers
				if marker.markerType == "POI" or marker.markerType == "Teammate" then
					marker.frame.Visible = true

					-- Clamp to edge
					local normalizedX = relativePos.X / distance
					local normalizedZ = relativePos.Z / distance
					local edgeX = normalizedX * 0.45 + 0.5
					local edgeZ = normalizedZ * 0.45 + 0.5

					marker.frame.Position = UDim2.fromScale(edgeX, edgeZ)
					marker.frame.BackgroundTransparency = 0.5
				else
					marker.frame.Visible = false
				end
			end
		end
	end
end

--[[
	Add a marker to the minimap
]]
function MinimapController.AddMarker(markerData: MinimapMarker)
	if not mapContainer then return end

	-- Remove existing marker with same ID
	if markers[markerData.id] then
		MinimapController.RemoveMarker(markerData.id)
	end

	-- Create marker frame
	local frame = Instance.new("Frame")
	frame.Name = `Marker_{markerData.id}`

	local size = MARKER_SIZE
	if markerData.markerType == "POI" then
		size = POI_MARKER_SIZE
	end

	frame.Size = UDim2.fromOffset(size, size)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = markerData.color or Color3.fromRGB(255, 255, 255)
	frame.BorderSizePixel = 0
	frame.ZIndex = 5
	frame.Parent = mapContainer

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame

	-- Add icon if provided
	if markerData.icon and markerData.icon ~= "" then
		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.fromScale(0.8, 0.8)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.BackgroundTransparency = 1
		icon.Image = markerData.icon
		icon.Parent = frame
	end

	markerData.frame = frame
	markers[markerData.id] = markerData
end

--[[
	Add a temporary marker
]]
function MinimapController.AddTemporaryMarker(markerData: MinimapMarker, duration: number)
	MinimapController.AddMarker(markerData)

	task.delay(duration, function()
		MinimapController.RemoveMarker(markerData.id)
	end)
end

--[[
	Remove a marker
]]
function MinimapController.RemoveMarker(id: string)
	local marker = markers[id]
	if marker then
		if marker.frame then
			marker.frame:Destroy()
		end
		markers[id] = nil
	end
end

--[[
	Update teammate marker
]]
function MinimapController.UpdateTeammateMarker(playerId: number, position: Vector3)
	local markerId = `teammate_{playerId}`
	local existing = markers[markerId]

	if existing then
		existing.position = position
	else
		MinimapController.AddMarker({
			id = markerId,
			position = position,
			markerType = "Teammate",
			color = TEAMMATE_COLOR,
			visible = true,
		})
	end
end

--[[
	Update storm circle
]]
function MinimapController.UpdateStormCircle(center: Vector3, radius: number)
	if not stormCircle then return end

	-- Calculate storm circle size relative to map
	local relativeSize = radius / config.mapRadius

	stormCircle.Size = UDim2.fromScale(relativeSize, relativeSize)

	-- Position relative to player would be handled in Update()
end

--[[
	Update current biome display
]]
function MinimapController.UpdateCurrentBiome(biomeName: string)
	currentBiome = biomeName

	if minimapFrame then
		local biomeLabel = minimapFrame:FindFirstChild("BiomeLabel") :: TextLabel?
		if biomeLabel then
			local biome = BiomeData.Biomes[biomeName]
			if biome then
				biomeLabel.Text = biome.displayName
				biomeLabel.TextColor3 = biome.minimapColor
			end
		end
	end
end

--[[
	Toggle minimap visibility
]]
function MinimapController.SetVisible(visible: boolean)
	isVisible = visible
	if minimapFrame then
		minimapFrame.Visible = visible
	end
end

--[[
	Toggle minimap visibility
]]
function MinimapController.Toggle()
	MinimapController.SetVisible(not isVisible)
end

--[[
	Set minimap zoom
]]
function MinimapController.SetZoom(radius: number)
	config.mapRadius = math.clamp(radius, 50, 500)
end

--[[
	Zoom in
]]
function MinimapController.ZoomIn()
	MinimapController.SetZoom(config.mapRadius * 0.8)
end

--[[
	Zoom out
]]
function MinimapController.ZoomOut()
	MinimapController.SetZoom(config.mapRadius * 1.25)
end

--[[
	Open full map
]]
function MinimapController.OpenFullMap()
	-- Would open a larger map view
	Events.FireServer("UI", "RequestFullMap", {})
end

--[[
	Add ping at position
]]
function MinimapController.AddPing(position: Vector3, pingType: string)
	local color = Color3.fromRGB(255, 255, 0) -- Yellow default

	if pingType == "Enemy" then
		color = ENEMY_COLOR
	elseif pingType == "Loot" then
		color = Color3.fromRGB(255, 200, 0)
	elseif pingType == "Danger" then
		color = Color3.fromRGB(255, 0, 0)
	end

	MinimapController.AddTemporaryMarker({
		id = `ping_{tick()}`,
		position = position,
		markerType = "Ping",
		color = color,
		visible = true,
	}, 5)

	-- Animate ping (pulsing effect)
	-- Would add animation here
end

--[[
	Get current config
]]
function MinimapController.GetConfig(): MinimapConfig
	return config
end

--[[
	Update config
]]
function MinimapController.UpdateConfig(newConfig: { [string]: any })
	for key, value in pairs(newConfig) do
		if (config :: any)[key] ~= nil then
			(config :: any)[key] = value
		end
	end
end

return MinimapController
