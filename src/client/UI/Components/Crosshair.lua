--!strict
--[[
	Crosshair.lua
	=============
	Dynamic crosshair system with weapon-specific styles and bloom feedback.

	FEATURES:
	- Multiple crosshair styles (Cross, Dot, Circle, Chevron)
	- Dynamic spread indicator based on weapon bloom
	- Hit marker integration
	- ADS (Aim Down Sights) size reduction
	- Movement/stance spread visualization
	- Customizable colors, size, and opacity

	DESIGN PRINCIPLES (from GDD 12.6):
	- Crosshair provides weapon state feedback
	- Expands/contracts based on bloom and movement
	- Different styles per weapon type
	- Hit feedback at center screen

	@client
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Crosshair = {}
Crosshair.__index = Crosshair

--------------------------------------------------------------------------------
-- CONFIGURATION
--------------------------------------------------------------------------------

-- Base sizes
local BASE_SIZE = 24              -- Default crosshair size
local LINE_THICKNESS = 2          -- Thickness of crosshair lines
local GAP_SIZE = 4                -- Gap in center for dot visibility
local DOT_SIZE = 4                -- Center dot size

-- Dynamic scaling
local MIN_SPREAD_MULT = 0.8       -- Minimum spread multiplier (crouching/ADS)
local MAX_SPREAD_MULT = 2.5       -- Maximum spread multiplier (running/jumping)
local BLOOM_RECOVERY_SPEED = 3.0  -- How fast crosshair contracts after firing
local SPREAD_TWEEN_TIME = 0.1     -- Tween time for spread changes

-- Spread modifiers (match WeaponBase constants)
local SPREAD_MODIFIERS = {
	Standing = 1.0,
	Walking = 1.2,
	Running = 1.5,
	Jumping = 2.0,
	Crouching = 0.75,
	Prone = 0.5,
	ADS = 0.6,
}

-- Crosshair styles
local STYLE_CROSS = "Cross"       -- Traditional + shape
local STYLE_DOT = "Dot"           -- Single center dot
local STYLE_CIRCLE = "Circle"     -- Circle with optional dot
local STYLE_CHEVRON = "Chevron"   -- V shapes pointing inward

-- Default colors
local COLORS = {
	Default = Color3.new(1, 1, 1),           -- White
	Hit = Color3.new(1, 1, 1),               -- White flash on hit
	Headshot = Color3.fromRGB(255, 215, 0),  -- Gold for headshots
	Kill = Color3.fromRGB(255, 68, 68),      -- Red for kills
	Outline = Color3.new(0, 0, 0),           -- Black outline
}

-- Weapon type to crosshair style mapping
local WEAPON_CROSSHAIRS = {
	AssaultRifle = { style = STYLE_CROSS, baseSize = 24, bloomMultiplier = 1.0 },
	SMG = { style = STYLE_CIRCLE, baseSize = 28, bloomMultiplier = 1.3 },
	Shotgun = { style = STYLE_CIRCLE, baseSize = 32, bloomMultiplier = 0.8, showPellets = true },
	Sniper = { style = STYLE_CROSS, baseSize = 18, bloomMultiplier = 0.5, thinLines = true },
	Pistol = { style = STYLE_CROSS, baseSize = 20, bloomMultiplier = 0.9 },
	DMR = { style = STYLE_CROSS, baseSize = 20, bloomMultiplier = 0.7 },
}

--------------------------------------------------------------------------------
-- TYPES
--------------------------------------------------------------------------------

export type CrosshairConfig = {
	style: string?,
	color: Color3?,
	size: number?,
	opacity: number?,
	showDot: boolean?,
	showOutline: boolean?,
	bloomMultiplier: number?,
}

export type CrosshairInstance = {
	frame: Frame,
	lines: { Frame },
	dot: Frame?,
	circle: Frame?,
	pelletDots: { Frame }?,

	-- Settings
	style: string,
	baseColor: Color3,
	baseSize: number,
	opacity: number,
	showDot: boolean,
	showOutline: boolean,
	bloomMultiplier: number,

	-- State
	currentSpread: number,
	targetSpread: number,
	isADS: boolean,
	currentStance: string,

	-- Connections
	updateConnection: RBXScriptConnection?,

	-- Methods
	SetWeaponType: (self: CrosshairInstance, weaponType: string) -> (),
	SetSpread: (self: CrosshairInstance, spread: number) -> (),
	SetStance: (self: CrosshairInstance, stance: string) -> (),
	SetADS: (self: CrosshairInstance, isADS: boolean) -> (),
	AddBloom: (self: CrosshairInstance, amount: number) -> (),
	ShowHit: (self: CrosshairInstance, isHeadshot: boolean?, isKill: boolean?) -> (),
	SetConfig: (self: CrosshairInstance, config: CrosshairConfig) -> (),
	SetVisible: (self: CrosshairInstance, visible: boolean) -> (),
	Destroy: (self: CrosshairInstance) -> (),
}

--------------------------------------------------------------------------------
-- HELPER FUNCTIONS
--------------------------------------------------------------------------------

--[[
	Create a frame with optional outline
]]
local function createLine(parent: Frame, showOutline: boolean): Frame
	local line = Instance.new("Frame")
	line.BackgroundColor3 = COLORS.Default
	line.BorderSizePixel = 0
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Parent = parent

	if showOutline then
		local stroke = Instance.new("UIStroke")
		stroke.Color = COLORS.Outline
		stroke.Thickness = 1
		stroke.Parent = line
	end

	return line
end

--------------------------------------------------------------------------------
-- CONSTRUCTOR
--------------------------------------------------------------------------------

--[[
	Create a new crosshair instance
	@param parent Parent ScreenGui
	@param config Optional configuration
	@return CrosshairInstance
]]
function Crosshair.new(parent: GuiObject, config: CrosshairConfig?): CrosshairInstance
	local self = setmetatable({}, Crosshair) :: any

	-- Apply config with defaults
	config = config or {}
	self.style = config.style or STYLE_CROSS
	self.baseColor = config.color or COLORS.Default
	self.baseSize = config.size or BASE_SIZE
	self.opacity = config.opacity or 1
	self.showDot = config.showDot ~= false -- Default true
	self.showOutline = config.showOutline ~= false -- Default true
	self.bloomMultiplier = config.bloomMultiplier or 1.0

	-- State
	self.currentSpread = 1.0
	self.targetSpread = 1.0
	self.isADS = false
	self.currentStance = "Standing"
	self.lines = {}
	self.pelletDots = nil

	-- Main container (centered on screen)
	self.frame = Instance.new("Frame")
	self.frame.Name = "Crosshair"
	self.frame.Size = UDim2.fromOffset(self.baseSize * 4, self.baseSize * 4)
	self.frame.Position = UDim2.fromScale(0.5, 0.5)
	self.frame.AnchorPoint = Vector2.new(0.5, 0.5)
	self.frame.BackgroundTransparency = 1
	self.frame.Parent = parent

	-- Create crosshair based on style
	self:BuildCrosshair()

	-- Start update loop
	self:StartUpdateLoop()

	return self
end

--------------------------------------------------------------------------------
-- BUILD METHODS
--------------------------------------------------------------------------------

--[[
	Build/rebuild crosshair based on current style
]]
function Crosshair:BuildCrosshair()
	-- Clear existing elements
	for _, line in ipairs(self.lines) do
		line:Destroy()
	end
	self.lines = {}

	if self.dot then
		self.dot:Destroy()
		self.dot = nil
	end

	if self.circle then
		self.circle:Destroy()
		self.circle = nil
	end

	if self.pelletDots then
		for _, dot in ipairs(self.pelletDots) do
			dot:Destroy()
		end
		self.pelletDots = nil
	end

	-- Build based on style
	if self.style == STYLE_CROSS then
		self:BuildCrossStyle()
	elseif self.style == STYLE_DOT then
		self:BuildDotStyle()
	elseif self.style == STYLE_CIRCLE then
		self:BuildCircleStyle()
	elseif self.style == STYLE_CHEVRON then
		self:BuildChevronStyle()
	else
		self:BuildCrossStyle() -- Default fallback
	end

	-- Apply color and opacity
	self:ApplyAppearance()
end

--[[
	Build cross (+) style crosshair
]]
function Crosshair:BuildCrossStyle()
	local halfSize = self.baseSize / 2
	local lineLength = halfSize - GAP_SIZE

	-- Top line
	local top = createLine(self.frame, self.showOutline)
	top.Size = UDim2.fromOffset(LINE_THICKNESS, lineLength)
	top.Position = UDim2.new(0.5, 0, 0.5, -(GAP_SIZE + lineLength / 2))
	table.insert(self.lines, top)

	-- Bottom line
	local bottom = createLine(self.frame, self.showOutline)
	bottom.Size = UDim2.fromOffset(LINE_THICKNESS, lineLength)
	bottom.Position = UDim2.new(0.5, 0, 0.5, GAP_SIZE + lineLength / 2)
	table.insert(self.lines, bottom)

	-- Left line
	local left = createLine(self.frame, self.showOutline)
	left.Size = UDim2.fromOffset(lineLength, LINE_THICKNESS)
	left.Position = UDim2.new(0.5, -(GAP_SIZE + lineLength / 2), 0.5, 0)
	table.insert(self.lines, left)

	-- Right line
	local right = createLine(self.frame, self.showOutline)
	right.Size = UDim2.fromOffset(lineLength, LINE_THICKNESS)
	right.Position = UDim2.new(0.5, GAP_SIZE + lineLength / 2, 0.5, 0)
	table.insert(self.lines, right)

	-- Center dot
	if self.showDot then
		self.dot = createLine(self.frame, self.showOutline)
		self.dot.Size = UDim2.fromOffset(DOT_SIZE, DOT_SIZE)
		self.dot.Position = UDim2.fromScale(0.5, 0.5)

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = self.dot
	end
end

--[[
	Build dot only style
]]
function Crosshair:BuildDotStyle()
	self.dot = createLine(self.frame, self.showOutline)
	self.dot.Size = UDim2.fromOffset(DOT_SIZE * 1.5, DOT_SIZE * 1.5)
	self.dot.Position = UDim2.fromScale(0.5, 0.5)

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = self.dot
end

--[[
	Build circle style crosshair (good for SMGs/shotguns)
]]
function Crosshair:BuildCircleStyle()
	-- Outer circle (ring)
	self.circle = Instance.new("Frame")
	self.circle.Name = "Circle"
	self.circle.Size = UDim2.fromOffset(self.baseSize, self.baseSize)
	self.circle.Position = UDim2.fromScale(0.5, 0.5)
	self.circle.AnchorPoint = Vector2.new(0.5, 0.5)
	self.circle.BackgroundTransparency = 1
	self.circle.Parent = self.frame

	local circleCorner = Instance.new("UICorner")
	circleCorner.CornerRadius = UDim.new(1, 0)
	circleCorner.Parent = self.circle

	local circleStroke = Instance.new("UIStroke")
	circleStroke.Color = self.baseColor
	circleStroke.Thickness = LINE_THICKNESS
	circleStroke.Parent = self.circle

	if self.showOutline then
		-- Add outer outline
		local outline = Instance.new("Frame")
		outline.Size = UDim2.new(1, 4, 1, 4)
		outline.Position = UDim2.fromScale(0.5, 0.5)
		outline.AnchorPoint = Vector2.new(0.5, 0.5)
		outline.BackgroundTransparency = 1
		outline.Parent = self.circle

		local outlineCorner = Instance.new("UICorner")
		outlineCorner.CornerRadius = UDim.new(1, 0)
		outlineCorner.Parent = outline

		local outlineStroke = Instance.new("UIStroke")
		outlineStroke.Color = COLORS.Outline
		outlineStroke.Thickness = 1
		outlineStroke.Parent = outline
	end

	-- Center dot
	if self.showDot then
		self.dot = createLine(self.frame, self.showOutline)
		self.dot.Size = UDim2.fromOffset(DOT_SIZE, DOT_SIZE)
		self.dot.Position = UDim2.fromScale(0.5, 0.5)

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = self.dot
	end
end

--[[
	Build chevron (V) style crosshair
]]
function Crosshair:BuildChevronStyle()
	local halfSize = self.baseSize / 2
	local chevronLength = halfSize * 0.7

	-- Create 4 chevron lines (V shapes pointing inward)
	local positions = {
		{ x = 0, y = -1, rot = 0 },   -- Top
		{ x = 0, y = 1, rot = 180 },  -- Bottom
		{ x = -1, y = 0, rot = -90 }, -- Left
		{ x = 1, y = 0, rot = 90 },   -- Right
	}

	for _, pos in ipairs(positions) do
		-- Left side of V
		local line1 = createLine(self.frame, self.showOutline)
		line1.Size = UDim2.fromOffset(chevronLength, LINE_THICKNESS)
		line1.Rotation = pos.rot + 45
		line1.Position = UDim2.new(0.5, pos.x * (GAP_SIZE + 5), 0.5, pos.y * (GAP_SIZE + 5))
		table.insert(self.lines, line1)
	end

	-- Center dot
	if self.showDot then
		self.dot = createLine(self.frame, self.showOutline)
		self.dot.Size = UDim2.fromOffset(DOT_SIZE, DOT_SIZE)
		self.dot.Position = UDim2.fromScale(0.5, 0.5)

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = self.dot
	end
end

--[[
	Apply color and opacity to all elements
]]
function Crosshair:ApplyAppearance()
	local color = self.baseColor
	local transparency = 1 - self.opacity

	for _, line in ipairs(self.lines) do
		line.BackgroundColor3 = color
		line.BackgroundTransparency = transparency
	end

	if self.dot then
		self.dot.BackgroundColor3 = color
		self.dot.BackgroundTransparency = transparency
	end

	if self.circle then
		local stroke = self.circle:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = color
			stroke.Transparency = transparency
		end
	end
end

--------------------------------------------------------------------------------
-- UPDATE METHODS
--------------------------------------------------------------------------------

--[[
	Start the update loop for smooth spread transitions
]]
function Crosshair:StartUpdateLoop()
	self.updateConnection = RunService.Heartbeat:Connect(function(deltaTime)
		-- Smooth spread transition
		local spreadDiff = self.targetSpread - self.currentSpread

		if math.abs(spreadDiff) > 0.01 then
			-- Move toward target spread
			local speed = spreadDiff > 0 and 10 or BLOOM_RECOVERY_SPEED
			self.currentSpread = self.currentSpread + spreadDiff * math.min(1, deltaTime * speed)
		else
			self.currentSpread = self.targetSpread
		end

		-- Apply spread to crosshair
		self:UpdateSpreadVisual()
	end)
end

--[[
	Update visual spread based on current spread value
]]
function Crosshair:UpdateSpreadVisual()
	local spreadMult = self.currentSpread * self.bloomMultiplier

	-- Clamp spread
	spreadMult = math.clamp(spreadMult, MIN_SPREAD_MULT, MAX_SPREAD_MULT)

	-- Apply ADS reduction
	if self.isADS then
		spreadMult = spreadMult * SPREAD_MODIFIERS.ADS
	end

	-- Calculate new size
	local newSize = self.baseSize * spreadMult
	local halfSize = newSize / 2
	local lineLength = halfSize - GAP_SIZE

	-- Update cross lines positions
	if self.style == STYLE_CROSS or self.style == STYLE_CHEVRON then
		for i, line in ipairs(self.lines) do
			if i == 1 then -- Top
				line.Position = UDim2.new(0.5, 0, 0.5, -(GAP_SIZE + lineLength / 2))
				line.Size = UDim2.fromOffset(LINE_THICKNESS, lineLength)
			elseif i == 2 then -- Bottom
				line.Position = UDim2.new(0.5, 0, 0.5, GAP_SIZE + lineLength / 2)
				line.Size = UDim2.fromOffset(LINE_THICKNESS, lineLength)
			elseif i == 3 then -- Left
				line.Position = UDim2.new(0.5, -(GAP_SIZE + lineLength / 2), 0.5, 0)
				line.Size = UDim2.fromOffset(lineLength, LINE_THICKNESS)
			elseif i == 4 then -- Right
				line.Position = UDim2.new(0.5, GAP_SIZE + lineLength / 2, 0.5, 0)
				line.Size = UDim2.fromOffset(lineLength, LINE_THICKNESS)
			end
		end
	end

	-- Update circle size
	if self.circle then
		self.circle.Size = UDim2.fromOffset(newSize, newSize)
	end
end

--------------------------------------------------------------------------------
-- PUBLIC METHODS
--------------------------------------------------------------------------------

--[[
	Set crosshair based on weapon type
]]
function Crosshair:SetWeaponType(weaponType: string)
	local config = WEAPON_CROSSHAIRS[weaponType]
	if config then
		self.style = config.style
		self.baseSize = config.baseSize
		self.bloomMultiplier = config.bloomMultiplier
		self:BuildCrosshair()
	end
end

--[[
	Set base spread value (0-1 normalized)
]]
function Crosshair:SetSpread(spread: number)
	self.targetSpread = 1.0 + spread
end

--[[
	Set player stance for spread calculation
]]
function Crosshair:SetStance(stance: string)
	self.currentStance = stance
	local modifier = SPREAD_MODIFIERS[stance] or 1.0
	self.targetSpread = modifier
end

--[[
	Set ADS (Aim Down Sights) state
]]
function Crosshair:SetADS(isADS: boolean)
	self.isADS = isADS

	-- Tween size change
	if isADS then
		TweenService:Create(self.frame, TweenInfo.new(0.15), {
			Size = UDim2.fromOffset(self.baseSize * 2, self.baseSize * 2),
		}):Play()
	else
		TweenService:Create(self.frame, TweenInfo.new(0.15), {
			Size = UDim2.fromOffset(self.baseSize * 4, self.baseSize * 4),
		}):Play()
	end
end

--[[
	Add bloom from firing (expands crosshair)
]]
function Crosshair:AddBloom(amount: number)
	self.targetSpread = self.targetSpread + amount
	self.targetSpread = math.min(self.targetSpread, MAX_SPREAD_MULT)

	-- Immediate visual feedback
	self.currentSpread = math.min(self.currentSpread + amount * 0.5, MAX_SPREAD_MULT)
end

--[[
	Show hit marker effect
]]
function Crosshair:ShowHit(isHeadshot: boolean?, isKill: boolean?)
	local color = COLORS.Hit
	local size = 1.0

	if isKill then
		color = COLORS.Kill
		size = 1.3
	elseif isHeadshot then
		color = COLORS.Headshot
		size = 1.15
	end

	-- Flash all elements
	for _, line in ipairs(self.lines) do
		local originalColor = line.BackgroundColor3
		line.BackgroundColor3 = color

		-- Scale up
		local originalSize = line.Size
		line.Size = UDim2.new(
			originalSize.X.Scale * size,
			originalSize.X.Offset * size,
			originalSize.Y.Scale * size,
			originalSize.Y.Offset * size
		)

		-- Tween back
		task.delay(0.05, function()
			TweenService:Create(line, TweenInfo.new(0.15), {
				BackgroundColor3 = originalColor,
				Size = originalSize,
			}):Play()
		end)
	end

	if self.dot then
		local originalColor = self.dot.BackgroundColor3
		self.dot.BackgroundColor3 = color

		task.delay(0.05, function()
			TweenService:Create(self.dot, TweenInfo.new(0.15), {
				BackgroundColor3 = originalColor,
			}):Play()
		end)
	end
end

--[[
	Update crosshair configuration
]]
function Crosshair:SetConfig(config: CrosshairConfig)
	if config.style then
		self.style = config.style
	end
	if config.color then
		self.baseColor = config.color
	end
	if config.size then
		self.baseSize = config.size
	end
	if config.opacity then
		self.opacity = config.opacity
	end
	if config.showDot ~= nil then
		self.showDot = config.showDot
	end
	if config.showOutline ~= nil then
		self.showOutline = config.showOutline
	end
	if config.bloomMultiplier then
		self.bloomMultiplier = config.bloomMultiplier
	end

	self:BuildCrosshair()
end

--[[
	Set visibility
]]
function Crosshair:SetVisible(visible: boolean)
	self.frame.Visible = visible
end

--[[
	Cleanup
]]
function Crosshair:Destroy()
	if self.updateConnection then
		self.updateConnection:Disconnect()
	end

	self.frame:Destroy()
end

return Crosshair
