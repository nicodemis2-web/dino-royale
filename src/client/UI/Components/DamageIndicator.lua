--!strict
--[[
	DamageIndicator.lua
	==================
	Directional damage indicators showing where damage came from
	Also shows hit markers for dealing damage
]]

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local DamageIndicator = {}
DamageIndicator.__index = DamageIndicator

-- Display settings
local INDICATOR_SIZE = 80
local INDICATOR_DISTANCE = 150 -- Distance from center
local INDICATOR_DURATION = 2
local HIT_MARKER_SIZE = 30
local HIT_MARKER_DURATION = 0.3

-- Colors
local DAMAGE_COLOR = Color3.fromRGB(255, 50, 50)
local HEADSHOT_COLOR = Color3.fromRGB(255, 200, 50)
local KILL_COLOR = Color3.fromRGB(255, 100, 50)
local HIT_COLOR = Color3.new(1, 1, 1)

export type DamageIndicatorInstance = {
	frame: Frame,
	hitMarkerFrame: Frame,
	indicators: { Frame },
	camera: Camera?,

	ShowDamageFrom: (self: DamageIndicatorInstance, sourcePosition: Vector3, damage: number) -> (),
	ShowHitMarker: (self: DamageIndicatorInstance, isHeadshot: boolean?, isKill: boolean?) -> (),
	ShowDinosaurDamage: (self: DamageIndicatorInstance, sourcePosition: Vector3) -> (),
	ShowStormDamage: (self: DamageIndicatorInstance) -> (),
	Clear: (self: DamageIndicatorInstance) -> (),
	Destroy: (self: DamageIndicatorInstance) -> (),
}

--[[
	Create new damage indicator system
	@param parent Parent GUI element
	@return DamageIndicatorInstance
]]
function DamageIndicator.new(parent: GuiObject): DamageIndicatorInstance
	local self = setmetatable({}, DamageIndicator) :: any

	-- State
	self.indicators = {}
	self.camera = workspace.CurrentCamera

	-- Main frame (fullscreen)
	self.frame = Instance.new("Frame")
	self.frame.Name = "DamageIndicators"
	self.frame.Size = UDim2.fromScale(1, 1)
	self.frame.Position = UDim2.fromScale(0.5, 0.5)
	self.frame.AnchorPoint = Vector2.new(0.5, 0.5)
	self.frame.BackgroundTransparency = 1
	self.frame.Parent = parent

	-- Hit marker frame (centered)
	self.hitMarkerFrame = Instance.new("Frame")
	self.hitMarkerFrame.Name = "HitMarker"
	self.hitMarkerFrame.Size = UDim2.fromOffset(HIT_MARKER_SIZE, HIT_MARKER_SIZE)
	self.hitMarkerFrame.Position = UDim2.fromScale(0.5, 0.5)
	self.hitMarkerFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	self.hitMarkerFrame.BackgroundTransparency = 1
	self.hitMarkerFrame.Visible = false
	self.hitMarkerFrame.ZIndex = 20
	self.hitMarkerFrame.Parent = parent

	-- Create hit marker X shape
	self:CreateHitMarkerGraphic()

	return self
end

--[[
	Create the hit marker X graphic
]]
function DamageIndicator:CreateHitMarkerGraphic()
	local lines = {
		{ rotation = 45, position = UDim2.fromScale(0.5, 0.5) },
		{ rotation = -45, position = UDim2.fromScale(0.5, 0.5) },
	}

	for i, lineData in ipairs(lines) do
		local line = Instance.new("Frame")
		line.Name = `Line{i}`
		line.Size = UDim2.new(1, 0, 0, 3)
		line.Position = lineData.position
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Rotation = lineData.rotation
		line.BackgroundColor3 = HIT_COLOR
		line.BorderSizePixel = 0
		line.Parent = self.hitMarkerFrame
	end
end

--[[
	Calculate screen angle from world position
]]
function DamageIndicator:GetDirectionAngle(sourcePosition: Vector3): number
	local localPlayer = Players.LocalPlayer
	if not localPlayer or not localPlayer.Character then
		return 0
	end

	local rootPart = localPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return 0
	end

	-- Get direction to source
	local playerPos = rootPart.Position
	local direction = (sourcePosition - playerPos)
	direction = Vector3.new(direction.X, 0, direction.Z).Unit

	-- Get player's forward direction
	local camera = self.camera or workspace.CurrentCamera
	if not camera then
		return 0
	end

	local cameraLook = camera.CFrame.LookVector
	cameraLook = Vector3.new(cameraLook.X, 0, cameraLook.Z).Unit

	-- Calculate angle
	local dot = cameraLook:Dot(direction)
	local cross = cameraLook:Cross(direction)
	local angle = math.atan2(cross.Y, dot)

	return math.deg(angle)
end

--[[
	Show damage indicator from a direction
]]
function DamageIndicator:ShowDamageFrom(sourcePosition: Vector3, damage: number)
	local angle = self:GetDirectionAngle(sourcePosition)

	-- Create indicator
	local indicator = Instance.new("ImageLabel")
	indicator.Name = "DamageIndicator"
	indicator.Size = UDim2.fromOffset(INDICATOR_SIZE, INDICATOR_SIZE / 2)
	indicator.Position = UDim2.fromScale(0.5, 0.5)
	indicator.AnchorPoint = Vector2.new(0.5, 0.5)
	indicator.BackgroundTransparency = 1
	indicator.Image = "rbxassetid://0" -- Arrow/chevron pointing inward
	indicator.ImageColor3 = DAMAGE_COLOR
	indicator.Rotation = angle
	indicator.ZIndex = 5
	indicator.Parent = self.frame

	-- Position based on angle (around center)
	local radians = math.rad(angle - 90)
	local offsetX = math.cos(radians) * INDICATOR_DISTANCE
	local offsetY = math.sin(radians) * INDICATOR_DISTANCE
	indicator.Position = UDim2.new(0.5, offsetX, 0.5, offsetY)

	-- Intensity based on damage
	local intensity = math.clamp(damage / 50, 0.5, 1)
	indicator.ImageTransparency = 1 - intensity

	table.insert(self.indicators, indicator)

	-- Fade out
	TweenService:Create(indicator, TweenInfo.new(INDICATOR_DURATION), {
		ImageTransparency = 1,
	}):Play()

	-- Remove after duration
	task.delay(INDICATOR_DURATION, function()
		local index = table.find(self.indicators, indicator)
		if index then
			table.remove(self.indicators, index)
		end
		indicator:Destroy()
	end)
end

--[[
	Show hit marker when dealing damage
]]
function DamageIndicator:ShowHitMarker(isHeadshot: boolean?, isKill: boolean?)
	local color = HIT_COLOR
	if isKill then
		color = KILL_COLOR
	elseif isHeadshot then
		color = HEADSHOT_COLOR
	end

	-- Set color for all lines
	for _, child in ipairs(self.hitMarkerFrame:GetChildren()) do
		if child:IsA("Frame") then
			child.BackgroundColor3 = color
		end
	end

	-- Show and animate
	self.hitMarkerFrame.Visible = true
	self.hitMarkerFrame.Size = UDim2.fromOffset(HIT_MARKER_SIZE * 1.5, HIT_MARKER_SIZE * 1.5)

	-- Scale down
	TweenService:Create(self.hitMarkerFrame, TweenInfo.new(HIT_MARKER_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(HIT_MARKER_SIZE, HIT_MARKER_SIZE),
	}):Play()

	-- Fade out lines
	for _, child in ipairs(self.hitMarkerFrame:GetChildren()) do
		if child:IsA("Frame") then
			child.BackgroundTransparency = 0
			TweenService:Create(child, TweenInfo.new(HIT_MARKER_DURATION), {
				BackgroundTransparency = 1,
			}):Play()
		end
	end

	-- Hide after animation
	task.delay(HIT_MARKER_DURATION, function()
		self.hitMarkerFrame.Visible = false
		-- Reset transparency for next use
		for _, child in ipairs(self.hitMarkerFrame:GetChildren()) do
			if child:IsA("Frame") then
				child.BackgroundTransparency = 0
			end
		end
	end)
end

--[[
	Show dinosaur damage indicator (special color)
]]
function DamageIndicator:ShowDinosaurDamage(sourcePosition: Vector3)
	local angle = self:GetDirectionAngle(sourcePosition)

	local indicator = Instance.new("ImageLabel")
	indicator.Name = "DinoDamageIndicator"
	indicator.Size = UDim2.fromOffset(INDICATOR_SIZE, INDICATOR_SIZE / 2)
	indicator.Position = UDim2.fromScale(0.5, 0.5)
	indicator.AnchorPoint = Vector2.new(0.5, 0.5)
	indicator.BackgroundTransparency = 1
	indicator.Image = "rbxassetid://0" -- Claw mark or dino icon
	indicator.ImageColor3 = Color3.fromRGB(255, 150, 50) -- Orange for dino
	indicator.Rotation = angle
	indicator.ZIndex = 5
	indicator.Parent = self.frame

	-- Position
	local radians = math.rad(angle - 90)
	local offsetX = math.cos(radians) * INDICATOR_DISTANCE
	local offsetY = math.sin(radians) * INDICATOR_DISTANCE
	indicator.Position = UDim2.new(0.5, offsetX, 0.5, offsetY)

	table.insert(self.indicators, indicator)

	-- Fade out
	TweenService:Create(indicator, TweenInfo.new(INDICATOR_DURATION * 1.5), {
		ImageTransparency = 1,
	}):Play()

	task.delay(INDICATOR_DURATION * 1.5, function()
		local index = table.find(self.indicators, indicator)
		if index then
			table.remove(self.indicators, index)
		end
		indicator:Destroy()
	end)
end

--[[
	Show storm damage (screen edge vignette)
]]
function DamageIndicator:ShowStormDamage()
	-- Create vignette around screen edges
	local vignette = Instance.new("ImageLabel")
	vignette.Name = "StormVignette"
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.Position = UDim2.fromScale(0.5, 0.5)
	vignette.AnchorPoint = Vector2.new(0.5, 0.5)
	vignette.BackgroundTransparency = 1
	vignette.Image = "rbxassetid://0" -- Vignette gradient texture
	vignette.ImageColor3 = Color3.fromRGB(150, 50, 255) -- Storm purple
	vignette.ImageTransparency = 0.3
	vignette.ZIndex = 3
	vignette.Parent = self.frame

	-- Pulse and fade
	TweenService:Create(vignette, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
		ImageTransparency = 0.7,
	}):Play()

	task.delay(0.5, function()
		TweenService:Create(vignette, TweenInfo.new(0.5), {
			ImageTransparency = 1,
		}):Play()

		task.delay(0.5, function()
			vignette:Destroy()
		end)
	end)
end

--[[
	Clear all indicators
]]
function DamageIndicator:Clear()
	for _, indicator in ipairs(self.indicators) do
		indicator:Destroy()
	end
	self.indicators = {}
	self.hitMarkerFrame.Visible = false
end

--[[
	Destroy the system
]]
function DamageIndicator:Destroy()
	self:Clear()
	self.frame:Destroy()
	self.hitMarkerFrame:Destroy()
end

return DamageIndicator
