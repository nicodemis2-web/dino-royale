--!strict
--[[
	DamageIndicator.lua
	==================
	Professional directional damage indicators and hit marker system.

	FEATURES:
	- Directional damage arrows showing attack source
	- Hit markers (X) for dealing damage with variants
	- Floating damage numbers at hit location
	- Screen-space damage vignettes
	- Kill confirm effects

	DESIGN PRINCIPLES (from GDD 12.7, 12.8):
	- Immediate feedback when dealing damage
	- Clear directional information for incoming damage
	- Different colors/sizes for hit types (body, headshot, kill)

	@client
]]

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local _RunService = game:GetService("RunService")

local DamageIndicator = {}
DamageIndicator.__index = DamageIndicator

--------------------------------------------------------------------------------
-- CONFIGURATION
--------------------------------------------------------------------------------

-- Damage indicator settings
local INDICATOR_DISTANCE = 150     -- Distance from screen center (pixels)
local INDICATOR_SIZE = 60          -- Arrow/chevron size
local INDICATOR_DURATION = 2.0     -- How long indicators stay visible
local MAX_INDICATORS = 8           -- Maximum simultaneous indicators

-- Hit marker settings
local HIT_MARKER_SIZE = 32         -- Base hit marker size
local HIT_MARKER_DURATION = 0.2    -- How long hit marker shows
local HIT_MARKER_LINE_LENGTH = 12  -- Length of X lines
local HIT_MARKER_THICKNESS = 3     -- Thickness of X lines
local HIT_MARKER_GAP = 4           -- Gap in center of X

-- Floating damage numbers
local DAMAGE_NUMBER_DURATION = 1.0
local DAMAGE_NUMBER_RISE = 50      -- How far numbers float up

-- Colors (from GDD 12.7)
local COLORS = {
	-- Damage received indicators
	PlayerDamage = Color3.fromRGB(255, 50, 50),      -- #FF3232 Red
	DinosaurDamage = Color3.fromRGB(255, 150, 50),   -- #FF9632 Orange
	ExplosionDamage = Color3.fromRGB(255, 255, 50),  -- #FFFF32 Yellow
	StormDamage = Color3.fromRGB(153, 50, 255),      -- #9932FF Purple

	-- Hit markers (damage dealt)
	HitNormal = Color3.new(1, 1, 1),                 -- White
	HitHeadshot = Color3.fromRGB(255, 215, 0),       -- #FFD700 Gold
	HitKill = Color3.fromRGB(255, 68, 68),           -- #FF4444 Red
	HitShieldBreak = Color3.fromRGB(100, 200, 255),  -- Light blue

	-- Floating damage numbers
	DamageNormal = Color3.new(1, 1, 1),
	DamageHeadshot = Color3.fromRGB(255, 215, 0),
	DamageCritical = Color3.fromRGB(255, 68, 68),
}

-- Hit marker sizes by type
local HIT_MARKER_SIZES = {
	Normal = 1.0,
	Headshot = 1.15,
	Kill = 1.3,
	ShieldBreak = 1.1,
}

--------------------------------------------------------------------------------
-- TYPES
--------------------------------------------------------------------------------

export type DamageIndicatorInstance = {
	frame: Frame,
	hitMarkerFrame: Frame,
	hitMarkerLines: { Frame },
	activeIndicators: { Frame },
	camera: Camera?,

	-- Methods
	ShowDamageFrom: (self: DamageIndicatorInstance, sourcePosition: Vector3, damage: number, sourceType: string?) -> (),
	ShowHitMarker: (self: DamageIndicatorInstance, isHeadshot: boolean?, isKill: boolean?, damage: number?) -> (),
	ShowDamageNumber: (self: DamageIndicatorInstance, worldPosition: Vector3, damage: number, isHeadshot: boolean?) -> (),
	ShowDinosaurDamage: (self: DamageIndicatorInstance, sourcePosition: Vector3) -> (),
	ShowStormDamage: (self: DamageIndicatorInstance) -> (),
	ShowKillConfirm: (self: DamageIndicatorInstance, victimName: string?) -> (),
	Clear: (self: DamageIndicatorInstance) -> (),
	Destroy: (self: DamageIndicatorInstance) -> (),
}

--------------------------------------------------------------------------------
-- HELPER FUNCTIONS
--------------------------------------------------------------------------------

--[[
	Add rounded corners to a frame
]]
local function addCorner(parent: GuiObject, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 4)
	corner.Parent = parent
	return corner
end

--------------------------------------------------------------------------------
-- CONSTRUCTOR
--------------------------------------------------------------------------------

--[[
	Create new damage indicator system
	@param parent Parent GUI element (ScreenGui)
	@return DamageIndicatorInstance
]]
function DamageIndicator.new(parent: GuiObject): DamageIndicatorInstance
	local self = setmetatable({}, DamageIndicator) :: any

	-- State
	self.activeIndicators = {}
	self.hitMarkerLines = {}
	self.camera = workspace.CurrentCamera

	-- Main container (fullscreen, centered)
	self.frame = Instance.new("Frame")
	self.frame.Name = "DamageIndicators"
	self.frame.Size = UDim2.fromScale(1, 1)
	self.frame.Position = UDim2.fromScale(0.5, 0.5)
	self.frame.AnchorPoint = Vector2.new(0.5, 0.5)
	self.frame.BackgroundTransparency = 1
	self.frame.Parent = parent

	-- Create hit marker
	self:CreateHitMarker()

	return self
end

--------------------------------------------------------------------------------
-- HIT MARKER CREATION
--------------------------------------------------------------------------------

--[[
	Create the hit marker X graphic
]]
function DamageIndicator:CreateHitMarker()
	-- Hit marker container (centered)
	self.hitMarkerFrame = Instance.new("Frame")
	self.hitMarkerFrame.Name = "HitMarker"
	self.hitMarkerFrame.Size = UDim2.fromOffset(HIT_MARKER_SIZE, HIT_MARKER_SIZE)
	self.hitMarkerFrame.Position = UDim2.fromScale(0.5, 0.5)
	self.hitMarkerFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	self.hitMarkerFrame.BackgroundTransparency = 1
	self.hitMarkerFrame.Visible = false
	self.hitMarkerFrame.ZIndex = 100
	self.hitMarkerFrame.Parent = self.frame

	-- Create X shape with 4 lines (2 for each diagonal, split at center)
	local lineConfigs = {
		-- Top-left to center
		{ rotation = 45, offsetX = -HIT_MARKER_GAP, offsetY = -HIT_MARKER_GAP },
		-- Center to bottom-right
		{ rotation = 45, offsetX = HIT_MARKER_GAP, offsetY = HIT_MARKER_GAP },
		-- Top-right to center
		{ rotation = -45, offsetX = HIT_MARKER_GAP, offsetY = -HIT_MARKER_GAP },
		-- Center to bottom-left
		{ rotation = -45, offsetX = -HIT_MARKER_GAP, offsetY = HIT_MARKER_GAP },
	}

	for i, config in ipairs(lineConfigs) do
		local line = Instance.new("Frame")
		line.Name = `HitLine{i}`
		line.Size = UDim2.fromOffset(HIT_MARKER_LINE_LENGTH, HIT_MARKER_THICKNESS)
		line.Position = UDim2.new(0.5, config.offsetX, 0.5, config.offsetY)
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Rotation = config.rotation
		line.BackgroundColor3 = COLORS.HitNormal
		line.BorderSizePixel = 0
		line.Parent = self.hitMarkerFrame

		-- Add subtle shadow/outline
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Thickness = 1
		stroke.Transparency = 0.5
		stroke.Parent = line

		table.insert(self.hitMarkerLines, line)
	end
end

--------------------------------------------------------------------------------
-- DIRECTION CALCULATION
--------------------------------------------------------------------------------

--[[
	Calculate screen angle from world position to player
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

	-- Get direction to source (flattened to horizontal plane)
	local playerPos = rootPart.Position
	local direction = (sourcePosition - playerPos)
	direction = Vector3.new(direction.X, 0, direction.Z).Unit

	-- Get camera's forward direction (flattened)
	local camera = self.camera or workspace.CurrentCamera
	if not camera then
		return 0
	end

	local cameraLook = camera.CFrame.LookVector
	cameraLook = Vector3.new(cameraLook.X, 0, cameraLook.Z).Unit

	-- Calculate angle using dot and cross products
	local dot = cameraLook:Dot(direction)
	local cross = cameraLook:Cross(direction)
	local angle = math.atan2(cross.Y, dot)

	return math.deg(angle)
end

--------------------------------------------------------------------------------
-- DAMAGE INDICATORS (RECEIVING DAMAGE)
--------------------------------------------------------------------------------

--[[
	Show damage indicator from a direction
	@param sourcePosition World position of damage source
	@param damage Amount of damage received
	@param sourceType Optional: "Player", "Dinosaur", "Explosion", "Storm"
]]
function DamageIndicator:ShowDamageFrom(sourcePosition: Vector3, damage: number, sourceType: string?)
	-- Get angle to source
	local angle = self:GetDirectionAngle(sourcePosition)

	-- Determine color based on source type
	local color = COLORS.PlayerDamage
	if sourceType == "Dinosaur" then
		color = COLORS.DinosaurDamage
	elseif sourceType == "Explosion" then
		color = COLORS.ExplosionDamage
	elseif sourceType == "Storm" then
		color = COLORS.StormDamage
	end

	-- Remove oldest indicator if at max
	if #self.activeIndicators >= MAX_INDICATORS then
		local oldest = table.remove(self.activeIndicators, 1)
		if oldest then
			oldest:Destroy()
		end
	end

	-- Create chevron/arrow indicator
	local indicator = Instance.new("Frame")
	indicator.Name = "DamageIndicator"
	indicator.Size = UDim2.fromOffset(INDICATOR_SIZE, INDICATOR_SIZE / 2)
	indicator.BackgroundTransparency = 1
	indicator.Parent = self.frame

	-- Create arrow shape using frames
	local arrowLeft = Instance.new("Frame")
	arrowLeft.Size = UDim2.fromOffset(INDICATOR_SIZE / 2, 6)
	arrowLeft.Position = UDim2.fromScale(0.3, 0.5)
	arrowLeft.AnchorPoint = Vector2.new(0.5, 0.5)
	arrowLeft.Rotation = 30
	arrowLeft.BackgroundColor3 = color
	arrowLeft.BorderSizePixel = 0
	arrowLeft.Parent = indicator
	addCorner(arrowLeft, 3)

	local arrowRight = Instance.new("Frame")
	arrowRight.Size = UDim2.fromOffset(INDICATOR_SIZE / 2, 6)
	arrowRight.Position = UDim2.fromScale(0.7, 0.5)
	arrowRight.AnchorPoint = Vector2.new(0.5, 0.5)
	arrowRight.Rotation = -30
	arrowRight.BackgroundColor3 = color
	arrowRight.BorderSizePixel = 0
	arrowRight.Parent = indicator
	addCorner(arrowRight, 3)

	-- Position indicator around screen center based on angle
	-- Rotate the indicator to point toward source
	indicator.Rotation = angle

	-- Position in ring around center
	local radians = math.rad(angle - 90) -- Offset by 90 to point correctly
	local offsetX = math.cos(radians) * INDICATOR_DISTANCE
	local offsetY = math.sin(radians) * INDICATOR_DISTANCE
	indicator.Position = UDim2.new(0.5, offsetX, 0.5, offsetY)
	indicator.AnchorPoint = Vector2.new(0.5, 0.5)

	-- Intensity based on damage
	local intensity = math.clamp(damage / 50, 0.5, 1)
	arrowLeft.BackgroundTransparency = 1 - intensity
	arrowRight.BackgroundTransparency = 1 - intensity

	-- Track indicator
	table.insert(self.activeIndicators, indicator)

	-- Fade out animation
	local fadeInfo = TweenInfo.new(INDICATOR_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

	TweenService:Create(arrowLeft, fadeInfo, {
		BackgroundTransparency = 1,
	}):Play()

	local fadeTween = TweenService:Create(arrowRight, fadeInfo, {
		BackgroundTransparency = 1,
	})
	fadeTween:Play()

	-- Remove after animation
	fadeTween.Completed:Once(function()
		local index = table.find(self.activeIndicators, indicator)
		if index then
			table.remove(self.activeIndicators, index)
		end
		indicator:Destroy()
	end)
end

--[[
	Show dinosaur-specific damage indicator (with claw mark styling)
]]
function DamageIndicator:ShowDinosaurDamage(sourcePosition: Vector3)
	self:ShowDamageFrom(sourcePosition, 40, "Dinosaur")
end

--[[
	Show storm damage (screen vignette effect)
]]
function DamageIndicator:ShowStormDamage()
	-- Create purple vignette around screen edges
	local vignette = Instance.new("Frame")
	vignette.Name = "StormVignette"
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.Position = UDim2.fromScale(0.5, 0.5)
	vignette.AnchorPoint = Vector2.new(0.5, 0.5)
	vignette.BackgroundTransparency = 1
	vignette.ZIndex = 50
	vignette.Parent = self.frame

	-- Create gradient edges
	local edges = {
		{ pos = UDim2.fromScale(0.5, 0), anchor = Vector2.new(0.5, 0), size = UDim2.fromScale(1, 0.15), rot = 180 },
		{ pos = UDim2.fromScale(0.5, 1), anchor = Vector2.new(0.5, 1), size = UDim2.fromScale(1, 0.15), rot = 0 },
		{ pos = UDim2.fromScale(0, 0.5), anchor = Vector2.new(0, 0.5), size = UDim2.fromScale(0.1, 1), rot = 90 },
		{ pos = UDim2.fromScale(1, 0.5), anchor = Vector2.new(1, 0.5), size = UDim2.fromScale(0.1, 1), rot = -90 },
	}

	for _, edge in ipairs(edges) do
		local edgeFrame = Instance.new("Frame")
		edgeFrame.Position = edge.pos
		edgeFrame.AnchorPoint = edge.anchor
		edgeFrame.Size = edge.size
		edgeFrame.BackgroundColor3 = COLORS.StormDamage
		edgeFrame.BackgroundTransparency = 0.5
		edgeFrame.Parent = vignette

		local gradient = Instance.new("UIGradient")
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(0.5, 0.7),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Rotation = edge.rot
		gradient.Parent = edgeFrame
	end

	-- Pulse and fade
	task.spawn(function()
		task.wait(0.3)
		for _, child in ipairs(vignette:GetChildren()) do
			if child:IsA("Frame") then
				TweenService:Create(child, TweenInfo.new(0.4), {
					BackgroundTransparency = 1,
				}):Play()
			end
		end
		task.wait(0.5)
		vignette:Destroy()
	end)
end

--------------------------------------------------------------------------------
-- HIT MARKERS (DEALING DAMAGE)
--------------------------------------------------------------------------------

--[[
	Show hit marker when dealing damage
	@param isHeadshot Whether it was a headshot
	@param isKill Whether it killed the target
	@param damage Optional damage amount for floating number
]]
function DamageIndicator:ShowHitMarker(isHeadshot: boolean?, isKill: boolean?, _damage: number?)
	-- Determine color and size
	local color = COLORS.HitNormal
	local sizeMultiplier = HIT_MARKER_SIZES.Normal

	if isKill then
		color = COLORS.HitKill
		sizeMultiplier = HIT_MARKER_SIZES.Kill
	elseif isHeadshot then
		color = COLORS.HitHeadshot
		sizeMultiplier = HIT_MARKER_SIZES.Headshot
	end

	-- Set color for all lines
	for _, line in ipairs(self.hitMarkerLines) do
		line.BackgroundColor3 = color
		line.BackgroundTransparency = 0

		-- Get stroke
		local stroke = line:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = 0.5
		end
	end

	-- Show hit marker
	self.hitMarkerFrame.Visible = true

	-- Start expanded, contract to normal
	local startSize = HIT_MARKER_SIZE * sizeMultiplier * 1.5
	local endSize = HIT_MARKER_SIZE * sizeMultiplier

	self.hitMarkerFrame.Size = UDim2.fromOffset(startSize, startSize)

	-- Contract animation
	TweenService:Create(self.hitMarkerFrame, TweenInfo.new(HIT_MARKER_DURATION * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(endSize, endSize),
	}):Play()

	-- Fade out lines
	task.delay(HIT_MARKER_DURATION * 0.3, function()
		for _, line in ipairs(self.hitMarkerLines) do
			TweenService:Create(line, TweenInfo.new(HIT_MARKER_DURATION * 0.7), {
				BackgroundTransparency = 1,
			}):Play()

			local stroke = line:FindFirstChildOfClass("UIStroke")
			if stroke then
				TweenService:Create(stroke, TweenInfo.new(HIT_MARKER_DURATION * 0.7), {
					Transparency = 1,
				}):Play()
			end
		end
	end)

	-- Hide after animation
	task.delay(HIT_MARKER_DURATION, function()
		self.hitMarkerFrame.Visible = false
	end)
end

--[[
	Show floating damage number at world position
	@param worldPosition Position in world space where damage occurred
	@param damage Amount of damage
	@param isHeadshot Whether it was a headshot
]]
function DamageIndicator:ShowDamageNumber(worldPosition: Vector3, damage: number, isHeadshot: boolean?)
	local camera = self.camera or workspace.CurrentCamera
	if not camera then
		return
	end

	-- Convert world position to screen position
	local screenPos, onScreen = camera:WorldToScreenPoint(worldPosition)
	if not onScreen then
		return
	end

	-- Determine color and size
	local color = isHeadshot and COLORS.DamageHeadshot or COLORS.DamageNormal
	local fontSize = isHeadshot and 22 or 18

	-- Create floating number
	local damageLabel = Instance.new("TextLabel")
	damageLabel.Name = "DamageNumber"
	damageLabel.Position = UDim2.fromOffset(screenPos.X + math.random(-20, 20), screenPos.Y)
	damageLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	damageLabel.Size = UDim2.fromOffset(80, 30)
	damageLabel.BackgroundTransparency = 1
	damageLabel.Text = tostring(math.floor(damage))
	damageLabel.TextColor3 = color
	damageLabel.TextSize = fontSize
	damageLabel.Font = Enum.Font.GothamBold
	damageLabel.TextStrokeTransparency = 0.3
	damageLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	damageLabel.ZIndex = 90
	damageLabel.Parent = self.frame

	-- Headshot gets extra emphasis
	if isHeadshot then
		damageLabel.Text = damage .. "!"

		-- Scale up briefly
		damageLabel.TextSize = fontSize * 1.3
		TweenService:Create(damageLabel, TweenInfo.new(0.1), {
			TextSize = fontSize,
		}):Play()
	end

	-- Float up and fade
	local endY = screenPos.Y - DAMAGE_NUMBER_RISE
	TweenService:Create(damageLabel, TweenInfo.new(DAMAGE_NUMBER_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(screenPos.X + math.random(-30, 30), endY),
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()

	-- Cleanup
	task.delay(DAMAGE_NUMBER_DURATION, function()
		damageLabel:Destroy()
	end)
end

--[[
	Show kill confirmation effect
	@param victimName Optional name of killed player/creature
]]
function DamageIndicator:ShowKillConfirm(victimName: string?)
	-- Show enlarged kill hit marker
	self:ShowHitMarker(false, true)

	-- Optional: Create kill banner
	if victimName then
		local killBanner = Instance.new("TextLabel")
		killBanner.Name = "KillBanner"
		killBanner.Position = UDim2.fromScale(0.5, 0.4)
		killBanner.AnchorPoint = Vector2.new(0.5, 0.5)
		killBanner.Size = UDim2.fromOffset(200, 30)
		killBanner.BackgroundTransparency = 1
		killBanner.Text = `Eliminated {victimName}`
		killBanner.TextColor3 = COLORS.HitKill
		killBanner.TextSize = 16
		killBanner.Font = Enum.Font.GothamBold
		killBanner.TextTransparency = 0
		killBanner.TextStrokeTransparency = 0.5
		killBanner.TextStrokeColor3 = Color3.new(0, 0, 0)
		killBanner.ZIndex = 95
		killBanner.Parent = self.frame

		-- Fade animation
		task.delay(0.5, function()
			TweenService:Create(killBanner, TweenInfo.new(1.0), {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.35),
			}):Play()
		end)

		-- Cleanup
		task.delay(1.5, function()
			killBanner:Destroy()
		end)
	end
end

--------------------------------------------------------------------------------
-- UTILITY
--------------------------------------------------------------------------------

--[[
	Clear all active indicators
]]
function DamageIndicator:Clear()
	for _, indicator in ipairs(self.activeIndicators) do
		indicator:Destroy()
	end
	self.activeIndicators = {}

	self.hitMarkerFrame.Visible = false
end

--[[
	Destroy the system
]]
function DamageIndicator:Destroy()
	self:Clear()
	self.frame:Destroy()
end

return DamageIndicator
