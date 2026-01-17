--!strict
--[[
	Minimap.lua
	===========
	Overhead map showing player position, storm zone, and points of interest
	Supports zoom and ping functionality
]]

local TweenService = game:GetService("TweenService")
local _Players = game:GetService("Players")

local Minimap = {}
Minimap.__index = Minimap

-- Display settings
local DEFAULT_SIZE = 200
local ZOOM_LEVELS = { 0.5, 1, 2, 4 }
local DEFAULT_ZOOM_INDEX = 2
local MAP_SCALE = 0.1 -- Studs to pixels ratio
local PLAYER_DOT_SIZE = 8
local POI_MARKER_SIZE = 12
local PING_DURATION = 5
local PING_PULSE_SPEED = 2

-- Colors
local PLAYER_COLOR = Color3.fromRGB(50, 200, 50)
local _ENEMY_COLOR = Color3.fromRGB(255, 50, 50)
local _TEAMMATE_COLOR = Color3.fromRGB(50, 150, 255)
local STORM_COLOR = Color3.fromRGB(255, 100, 50)
local SAFE_ZONE_COLOR = Color3.fromRGB(255, 255, 255)
local PING_COLOR = Color3.fromRGB(255, 200, 50)
local BACKGROUND_COLOR = Color3.fromRGB(30, 40, 35)

export type MarkerData = {
	id: string,
	position: Vector3,
	markerType: string,
	color: Color3?,
	label: string?,
}

export type MinimapInstance = {
	frame: Frame,
	mapContainer: Frame,
	playerDot: Frame,
	stormCircle: Frame?,
	safeZoneCircle: Frame?,
	markers: { [string]: Frame },
	pings: { [string]: Frame },
	zoomIndex: number,
	centerPosition: Vector3,
	mapWorldSize: number,

	Update: (self: MinimapInstance, playerPosition: Vector3, playerRotation: number) -> (),
	SetStormCircle: (self: MinimapInstance, center: Vector3, radius: number) -> (),
	SetSafeZone: (self: MinimapInstance, center: Vector3, radius: number) -> (),
	AddMarker: (self: MinimapInstance, data: MarkerData) -> (),
	RemoveMarker: (self: MinimapInstance, id: string) -> (),
	AddPing: (self: MinimapInstance, position: Vector3, pingType: string?) -> (),
	ZoomIn: (self: MinimapInstance) -> (),
	ZoomOut: (self: MinimapInstance) -> (),
	SetExpanded: (self: MinimapInstance, expanded: boolean) -> (),
	Destroy: (self: MinimapInstance) -> (),
}

--[[
	Create a new minimap
	@param parent Parent GUI element
	@param position UDim2 position
	@param mapWorldSize Size of the game world in studs
	@return MinimapInstance
]]
function Minimap.new(parent: GuiObject, position: UDim2, mapWorldSize: number?): MinimapInstance
	local self = setmetatable({}, Minimap) :: any

	-- State
	self.zoomIndex = DEFAULT_ZOOM_INDEX
	self.centerPosition = Vector3.zero
	self.mapWorldSize = mapWorldSize or 2000
	self.markers = {}
	self.pings = {}

	-- Main frame
	self.frame = Instance.new("Frame")
	self.frame.Name = "Minimap"
	self.frame.Position = position
	self.frame.Size = UDim2.fromOffset(DEFAULT_SIZE, DEFAULT_SIZE)
	self.frame.BackgroundColor3 = BACKGROUND_COLOR
	self.frame.BorderSizePixel = 0
	self.frame.ClipsDescendants = true
	self.frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = self.frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(80, 80, 80)
	stroke.Thickness = 2
	stroke.Parent = self.frame

	-- Map container (scrolls based on player position)
	self.mapContainer = Instance.new("Frame")
	self.mapContainer.Name = "MapContainer"
	self.mapContainer.Position = UDim2.fromScale(0.5, 0.5)
	self.mapContainer.Size = UDim2.fromScale(2, 2)
	self.mapContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	self.mapContainer.BackgroundTransparency = 1
	self.mapContainer.Parent = self.frame

	-- Storm circle indicator
	self.stormCircle = Instance.new("Frame")
	self.stormCircle.Name = "StormCircle"
	self.stormCircle.BackgroundTransparency = 1
	self.stormCircle.Visible = false
	self.stormCircle.Parent = self.mapContainer

	local stormBorder = Instance.new("UIStroke")
	stormBorder.Color = STORM_COLOR
	stormBorder.Thickness = 3
	stormBorder.Parent = self.stormCircle

	local stormCorner = Instance.new("UICorner")
	stormCorner.CornerRadius = UDim.new(0.5, 0)
	stormCorner.Parent = self.stormCircle

	-- Safe zone circle
	self.safeZoneCircle = Instance.new("Frame")
	self.safeZoneCircle.Name = "SafeZoneCircle"
	self.safeZoneCircle.BackgroundTransparency = 1
	self.safeZoneCircle.Visible = false
	self.safeZoneCircle.Parent = self.mapContainer

	local safeBorder = Instance.new("UIStroke")
	safeBorder.Color = SAFE_ZONE_COLOR
	safeBorder.Thickness = 2
	safeBorder.Parent = self.safeZoneCircle

	local safeCorner = Instance.new("UICorner")
	safeCorner.CornerRadius = UDim.new(0.5, 0)
	safeCorner.Parent = self.safeZoneCircle

	-- Player dot (always centered)
	self.playerDot = Instance.new("Frame")
	self.playerDot.Name = "PlayerDot"
	self.playerDot.Position = UDim2.fromScale(0.5, 0.5)
	self.playerDot.Size = UDim2.fromOffset(PLAYER_DOT_SIZE, PLAYER_DOT_SIZE)
	self.playerDot.AnchorPoint = Vector2.new(0.5, 0.5)
	self.playerDot.BackgroundColor3 = PLAYER_COLOR
	self.playerDot.BorderSizePixel = 0
	self.playerDot.ZIndex = 10
	self.playerDot.Parent = self.frame -- On top frame, not container

	local playerCorner = Instance.new("UICorner")
	playerCorner.CornerRadius = UDim.new(0.5, 0)
	playerCorner.Parent = self.playerDot

	-- Direction indicator (triangle)
	local directionIndicator = Instance.new("ImageLabel")
	directionIndicator.Name = "DirectionIndicator"
	directionIndicator.Position = UDim2.fromScale(0.5, 0.5)
	directionIndicator.Size = UDim2.fromOffset(PLAYER_DOT_SIZE * 2, PLAYER_DOT_SIZE * 2)
	directionIndicator.AnchorPoint = Vector2.new(0.5, 0.5)
	directionIndicator.BackgroundTransparency = 1
	directionIndicator.Image = "rbxassetid://0" -- Would use a triangle asset
	directionIndicator.ImageColor3 = PLAYER_COLOR
	directionIndicator.Parent = self.playerDot

	-- Compass
	self:CreateCompass()

	-- Zoom controls
	self:CreateZoomControls()

	return self
end

--[[
	Create compass overlay
]]
function Minimap:CreateCompass()
	local compassFrame = Instance.new("Frame")
	compassFrame.Name = "Compass"
	compassFrame.Position = UDim2.new(0.5, 0, 0, 5)
	compassFrame.Size = UDim2.new(1, -20, 0, 15)
	compassFrame.AnchorPoint = Vector2.new(0.5, 0)
	compassFrame.BackgroundTransparency = 1
	compassFrame.Parent = self.frame

	local directions = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }
	for i, dir in ipairs(directions) do
		local label = Instance.new("TextLabel")
		label.Name = dir
		label.Position = UDim2.fromScale((i - 1) / 8, 0)
		label.Size = UDim2.new(1 / 8, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = dir
		label.TextColor3 = Color3.fromRGB(200, 200, 200)
		label.TextSize = 10
		label.Font = Enum.Font.GothamBold
		label.Parent = compassFrame
	end
end

--[[
	Create zoom controls
]]
function Minimap:CreateZoomControls()
	local zoomFrame = Instance.new("Frame")
	zoomFrame.Name = "ZoomControls"
	zoomFrame.Position = UDim2.new(1, -30, 0.5, 0)
	zoomFrame.Size = UDim2.fromOffset(25, 60)
	zoomFrame.AnchorPoint = Vector2.new(1, 0.5)
	zoomFrame.BackgroundTransparency = 1
	zoomFrame.Parent = self.frame

	local zoomIn = Instance.new("TextButton")
	zoomIn.Name = "ZoomIn"
	zoomIn.Position = UDim2.fromOffset(0, 0)
	zoomIn.Size = UDim2.fromOffset(25, 25)
	zoomIn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	zoomIn.Text = "+"
	zoomIn.TextColor3 = Color3.new(1, 1, 1)
	zoomIn.TextSize = 18
	zoomIn.Font = Enum.Font.GothamBold
	zoomIn.Parent = zoomFrame

	local zoomInCorner = Instance.new("UICorner")
	zoomInCorner.CornerRadius = UDim.new(0, 4)
	zoomInCorner.Parent = zoomIn

	zoomIn.MouseButton1Click:Connect(function()
		self:ZoomIn()
	end)

	local zoomOut = Instance.new("TextButton")
	zoomOut.Name = "ZoomOut"
	zoomOut.Position = UDim2.fromOffset(0, 35)
	zoomOut.Size = UDim2.fromOffset(25, 25)
	zoomOut.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	zoomOut.Text = "-"
	zoomOut.TextColor3 = Color3.new(1, 1, 1)
	zoomOut.TextSize = 18
	zoomOut.Font = Enum.Font.GothamBold
	zoomOut.Parent = zoomFrame

	local zoomOutCorner = Instance.new("UICorner")
	zoomOutCorner.CornerRadius = UDim.new(0, 4)
	zoomOutCorner.Parent = zoomOut

	zoomOut.MouseButton1Click:Connect(function()
		self:ZoomOut()
	end)
end

--[[
	Convert world position to map position
]]
function Minimap:WorldToMap(worldPos: Vector3): UDim2
	local zoom = ZOOM_LEVELS[self.zoomIndex]
	local scale = MAP_SCALE * zoom

	-- Relative to center (player position)
	local relX = (worldPos.X - self.centerPosition.X) * scale
	local relZ = (worldPos.Z - self.centerPosition.Z) * scale

	-- Map Y axis is inverted (Z in world)
	return UDim2.fromScale(0.5 + relX / DEFAULT_SIZE, 0.5 + relZ / DEFAULT_SIZE)
end

--[[
	Update minimap based on player position
]]
function Minimap:Update(playerPosition: Vector3, playerRotation: number)
	self.centerPosition = playerPosition

	-- Rotate direction indicator
	local dirIndicator = self.playerDot:FindFirstChild("DirectionIndicator") :: ImageLabel?
	if dirIndicator then
		dirIndicator.Rotation = math.deg(playerRotation)
	end

	-- Update marker positions
	for id, marker in pairs(self.markers) do
		-- TODO: Implement world-to-minimap coordinate mapping
		local _, _ = id, marker -- Suppress unused until implemented
	end
end

--[[
	Set storm circle display
]]
function Minimap:SetStormCircle(center: Vector3, radius: number)
	if not self.stormCircle then
		return
	end

	local zoom = ZOOM_LEVELS[self.zoomIndex]
	local scale = MAP_SCALE * zoom
	local size = radius * 2 * scale

	local mapPos = self:WorldToMap(center)
	self.stormCircle.Position = mapPos
	self.stormCircle.Size = UDim2.fromOffset(size, size)
	self.stormCircle.AnchorPoint = Vector2.new(0.5, 0.5)
	self.stormCircle.Visible = true
end

--[[
	Set safe zone display
]]
function Minimap:SetSafeZone(center: Vector3, radius: number)
	if not self.safeZoneCircle then
		return
	end

	local zoom = ZOOM_LEVELS[self.zoomIndex]
	local scale = MAP_SCALE * zoom
	local size = radius * 2 * scale

	local mapPos = self:WorldToMap(center)
	self.safeZoneCircle.Position = mapPos
	self.safeZoneCircle.Size = UDim2.fromOffset(size, size)
	self.safeZoneCircle.AnchorPoint = Vector2.new(0.5, 0.5)
	self.safeZoneCircle.Visible = true
end

--[[
	Add a marker to the map
]]
function Minimap:AddMarker(data: MarkerData)
	-- Remove existing marker with same ID
	if self.markers[data.id] then
		self.markers[data.id]:Destroy()
	end

	local marker = Instance.new("Frame")
	marker.Name = `Marker_{data.id}`
	marker.Size = UDim2.fromOffset(POI_MARKER_SIZE, POI_MARKER_SIZE)
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.BackgroundColor3 = data.color or Color3.new(1, 1, 1)
	marker.BorderSizePixel = 0
	marker.Parent = self.mapContainer

	local markerCorner = Instance.new("UICorner")
	markerCorner.CornerRadius = UDim.new(0.5, 0)
	markerCorner.Parent = marker

	-- Label if provided
	if data.label then
		local label = Instance.new("TextLabel")
		label.Position = UDim2.new(0.5, 0, 1, 2)
		label.Size = UDim2.fromOffset(50, 12)
		label.AnchorPoint = Vector2.new(0.5, 0)
		label.BackgroundTransparency = 1
		label.Text = data.label
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextSize = 8
		label.Font = Enum.Font.Gotham
		label.Parent = marker
	end

	-- Store position for updates
	marker:SetAttribute("WorldX", data.position.X)
	marker:SetAttribute("WorldZ", data.position.Z)

	-- Position marker
	local mapPos = self:WorldToMap(data.position)
	marker.Position = mapPos

	self.markers[data.id] = marker
end

--[[
	Remove a marker
]]
function Minimap:RemoveMarker(id: string)
	if self.markers[id] then
		self.markers[id]:Destroy()
		self.markers[id] = nil
	end
end

--[[
	Add a ping to the map
]]
function Minimap:AddPing(position: Vector3, _pingType: string?)
	local pingId = `ping_{tick()}`

	local ping = Instance.new("Frame")
	ping.Name = pingId
	ping.Size = UDim2.fromOffset(20, 20)
	ping.AnchorPoint = Vector2.new(0.5, 0.5)
	ping.BackgroundTransparency = 1
	ping.Parent = self.mapContainer

	-- Ping circle
	local circle = Instance.new("Frame")
	circle.Size = UDim2.fromScale(1, 1)
	circle.BackgroundTransparency = 1
	circle.Parent = ping

	local circleStroke = Instance.new("UIStroke")
	circleStroke.Color = PING_COLOR
	circleStroke.Thickness = 2
	circleStroke.Parent = circle

	local circleCorner = Instance.new("UICorner")
	circleCorner.CornerRadius = UDim.new(0.5, 0)
	circleCorner.Parent = circle

	-- Center dot
	local dot = Instance.new("Frame")
	dot.Position = UDim2.fromScale(0.5, 0.5)
	dot.Size = UDim2.fromOffset(6, 6)
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.BackgroundColor3 = PING_COLOR
	dot.Parent = ping

	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(0.5, 0)
	dotCorner.Parent = dot

	-- Position ping
	local mapPos = self:WorldToMap(position)
	ping.Position = mapPos

	-- Pulse animation
	local pulseConnection: RBXScriptConnection
	pulseConnection = game:GetService("RunService").Heartbeat:Connect(function()
		local scale = 1 + math.sin(tick() * PING_PULSE_SPEED * math.pi) * 0.3
		circle.Size = UDim2.fromScale(scale, scale)
	end)

	self.pings[pingId] = ping

	-- Remove after duration
	task.delay(PING_DURATION, function()
		pulseConnection:Disconnect()
		if self.pings[pingId] then
			self.pings[pingId]:Destroy()
			self.pings[pingId] = nil
		end
	end)
end

--[[
	Zoom in
]]
function Minimap:ZoomIn()
	if self.zoomIndex < #ZOOM_LEVELS then
		self.zoomIndex = self.zoomIndex + 1
		self:RefreshZoom()
	end
end

--[[
	Zoom out
]]
function Minimap:ZoomOut()
	if self.zoomIndex > 1 then
		self.zoomIndex = self.zoomIndex - 1
		self:RefreshZoom()
	end
end

--[[
	Refresh zoom level
]]
function Minimap:RefreshZoom()
	-- Update all marker positions
	for _, marker in pairs(self.markers) do
		local worldX = marker:GetAttribute("WorldX")
		local worldZ = marker:GetAttribute("WorldZ")
		if worldX and worldZ then
			local mapPos = self:WorldToMap(Vector3.new(worldX, 0, worldZ))
			marker.Position = mapPos
		end
	end
end

--[[
	Set expanded/fullscreen mode
]]
function Minimap:SetExpanded(expanded: boolean)
	local targetSize = expanded and UDim2.fromOffset(400, 400) or UDim2.fromOffset(DEFAULT_SIZE, DEFAULT_SIZE)

	TweenService:Create(self.frame, TweenInfo.new(0.2), {
		Size = targetSize,
	}):Play()
end

--[[
	Destroy the minimap
]]
function Minimap:Destroy()
	self.frame:Destroy()
end

return Minimap
