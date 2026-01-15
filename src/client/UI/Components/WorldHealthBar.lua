--!strict
--[[
	WorldHealthBar.lua
	==================
	World-space health bars using BillboardGui for players and dinosaurs.

	FEATURES:
	- BillboardGui health bars above characters
	- Distance-based fading (80-100 studs)
	- Different styles for player types (self, teammate, enemy)
	- Dinosaur health bars with tier coloring
	- Boss health bars (displayed at screen top)
	- Smooth health transitions

	DESIGN PRINCIPLES (from GDD 12.9):
	- Health bars displayed above characters in 3D space
	- Color coding: Self=Green, Teammate=Blue, Enemy=Red
	- Dinosaurs colored by tier (Common=Green to Legendary=Gold)

	@client
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local WorldHealthBar = {}
WorldHealthBar.__index = WorldHealthBar

--------------------------------------------------------------------------------
-- CONFIGURATION
--------------------------------------------------------------------------------

-- Health bar dimensions (in studs for BillboardGui)
local BAR_WIDTH = 6              -- Width in studs
local BAR_HEIGHT = 0.5           -- Height in studs
local BAR_OFFSET = 3             -- Studs above head
local NAME_OFFSET = 0.3          -- Name label offset below bar

-- Distance settings
local MAX_VISIBLE_DISTANCE = 100  -- Maximum distance to show bar
local FADE_START_DISTANCE = 80    -- Distance where fade begins
local BOSS_BAR_ALWAYS_VISIBLE = true

-- Animation timings
local HEALTH_TWEEN_TIME = 0.3
local FADE_TWEEN_TIME = 0.2

-- Player type colors (from GDD 12.9)
local PLAYER_COLORS = {
	Self = {
		bar = Color3.fromRGB(50, 200, 50),       -- Green
		name = Color3.new(1, 1, 1),              -- White
		border = nil,                             -- No border
	},
	Teammate = {
		bar = Color3.fromRGB(50, 150, 255),      -- Blue
		name = Color3.fromRGB(100, 180, 255),    -- Light blue
		border = Color3.fromRGB(50, 150, 255),   -- Blue glow
	},
	Enemy = {
		bar = Color3.fromRGB(255, 50, 50),       -- Red
		name = Color3.fromRGB(255, 100, 100),    -- Light red
		border = nil,
	},
	Downed = {
		bar = Color3.fromRGB(255, 200, 50),      -- Yellow
		name = Color3.new(1, 1, 1),
		border = Color3.fromRGB(255, 200, 50),
	},
}

-- Dinosaur tier colors (from GDD 12.9)
local DINO_TIER_COLORS = {
	Common = Color3.fromRGB(50, 200, 50),        -- Green
	Uncommon = Color3.fromRGB(255, 200, 50),     -- Yellow
	Rare = Color3.fromRGB(50, 150, 255),         -- Blue
	Epic = Color3.fromRGB(153, 50, 204),         -- Purple
	Legendary = Color3.fromRGB(255, 215, 0),     -- Gold
}

-- Background/UI colors
local COLORS = {
	Background = Color3.fromRGB(20, 20, 20),
	HealthLow = Color3.fromRGB(255, 50, 50),
	HealthMedium = Color3.fromRGB(255, 200, 50),
}

--------------------------------------------------------------------------------
-- TYPES
--------------------------------------------------------------------------------

export type PlayerType = "Self" | "Teammate" | "Enemy" | "Downed"
export type DinoTier = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"

export type WorldHealthBarInstance = {
	billboard: BillboardGui,
	container: Frame,
	backgroundBar: Frame,
	healthBar: Frame,
	nameLabel: TextLabel,
	target: Model,

	-- State
	currentHealth: number,
	maxHealth: number,
	playerType: PlayerType?,
	dinoTier: DinoTier?,
	isDinosaur: boolean,

	-- Methods
	Update: (self: WorldHealthBarInstance, health: number, maxHealth: number) -> (),
	SetPlayerType: (self: WorldHealthBarInstance, playerType: PlayerType) -> (),
	SetDinoTier: (self: WorldHealthBarInstance, tier: DinoTier) -> (),
	SetName: (self: WorldHealthBarInstance, name: string) -> (),
	UpdateVisibility: (self: WorldHealthBarInstance, distance: number) -> (),
	Destroy: (self: WorldHealthBarInstance) -> (),
}

-- Module-level state
local activeHealthBars: { [Model]: WorldHealthBarInstance } = {}
local localPlayer = Players.LocalPlayer
local updateConnection: RBXScriptConnection? = nil

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

--[[
	Get health bar color based on percentage
]]
local function getHealthColor(healthPercent: number, baseColor: Color3): Color3
	if healthPercent > 0.5 then
		return baseColor
	elseif healthPercent > 0.25 then
		return COLORS.HealthMedium
	else
		return COLORS.HealthLow
	end
end

--------------------------------------------------------------------------------
-- CONSTRUCTOR
--------------------------------------------------------------------------------

--[[
	Create a new world health bar for a character
	@param target The Model (character) to attach health bar to
	@param isDinosaur Whether this is a dinosaur (vs player)
	@return WorldHealthBarInstance
]]
function WorldHealthBar.new(target: Model, isDinosaur: boolean?): WorldHealthBarInstance
	local self = setmetatable({}, WorldHealthBar) :: any

	self.target = target
	self.isDinosaur = isDinosaur or false
	self.currentHealth = 100
	self.maxHealth = 100
	self.playerType = nil
	self.dinoTier = nil

	-- Find head/attachment point
	local head = target:FindFirstChild("Head") :: BasePart?
	if not head then
		-- Try HumanoidRootPart as fallback
		head = target:FindFirstChild("HumanoidRootPart") :: BasePart?
	end

	if not head then
		error("Target has no Head or HumanoidRootPart")
	end

	-- Create BillboardGui
	self.billboard = Instance.new("BillboardGui")
	self.billboard.Name = "WorldHealthBar"
	self.billboard.Size = UDim2.new(BAR_WIDTH, 0, BAR_HEIGHT + NAME_OFFSET + 0.3, 0)
	self.billboard.StudsOffset = Vector3.new(0, BAR_OFFSET, 0)
	self.billboard.Adornee = head
	self.billboard.AlwaysOnTop = false
	self.billboard.MaxDistance = MAX_VISIBLE_DISTANCE
	self.billboard.Parent = target

	-- Container frame
	self.container = Instance.new("Frame")
	self.container.Name = "Container"
	self.container.Size = UDim2.fromScale(1, 1)
	self.container.BackgroundTransparency = 1
	self.container.Parent = self.billboard

	-- Create health bar
	self:CreateHealthBar()

	-- Create name label
	self:CreateNameLabel()

	-- Track this health bar
	activeHealthBars[target] = self

	return self
end

--------------------------------------------------------------------------------
-- UI CREATION
--------------------------------------------------------------------------------

--[[
	Create the health bar components
]]
function WorldHealthBar:CreateHealthBar()
	-- Background bar
	self.backgroundBar = Instance.new("Frame")
	self.backgroundBar.Name = "Background"
	self.backgroundBar.Size = UDim2.new(1, 0, 0, 8)
	self.backgroundBar.Position = UDim2.fromScale(0, 0)
	self.backgroundBar.BackgroundColor3 = COLORS.Background
	self.backgroundBar.BackgroundTransparency = 0.3
	self.backgroundBar.BorderSizePixel = 0
	self.backgroundBar.Parent = self.container

	addCorner(self.backgroundBar, 4)

	-- Health bar fill
	self.healthBar = Instance.new("Frame")
	self.healthBar.Name = "HealthBar"
	self.healthBar.Size = UDim2.fromScale(1, 1)
	self.healthBar.Position = UDim2.fromScale(0, 0)
	self.healthBar.BackgroundColor3 = PLAYER_COLORS.Enemy.bar
	self.healthBar.BorderSizePixel = 0
	self.healthBar.Parent = self.backgroundBar

	addCorner(self.healthBar, 4)
end

--[[
	Create the name label
]]
function WorldHealthBar:CreateNameLabel()
	self.nameLabel = Instance.new("TextLabel")
	self.nameLabel.Name = "NameLabel"
	self.nameLabel.Size = UDim2.new(1, 0, 0, 14)
	self.nameLabel.Position = UDim2.new(0, 0, 0, 10)
	self.nameLabel.BackgroundTransparency = 1
	self.nameLabel.Text = ""
	self.nameLabel.TextColor3 = Color3.new(1, 1, 1)
	self.nameLabel.TextSize = 14
	self.nameLabel.Font = Enum.Font.GothamBold
	self.nameLabel.TextStrokeTransparency = 0.5
	self.nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	self.nameLabel.TextScaled = false
	self.nameLabel.Parent = self.container
end

--------------------------------------------------------------------------------
-- UPDATE METHODS
--------------------------------------------------------------------------------

--[[
	Update health values with animation
]]
function WorldHealthBar:Update(health: number, maxHealth: number)
	self.currentHealth = health
	self.maxHealth = maxHealth

	local healthPercent = math.clamp(health / maxHealth, 0, 1)

	-- Determine base color
	local baseColor = PLAYER_COLORS.Enemy.bar
	if self.playerType then
		baseColor = PLAYER_COLORS[self.playerType].bar
	elseif self.dinoTier then
		baseColor = DINO_TIER_COLORS[self.dinoTier]
	end

	-- Get color based on health level
	local healthColor = getHealthColor(healthPercent, baseColor)

	-- Animate health bar
	TweenService:Create(self.healthBar, TweenInfo.new(HEALTH_TWEEN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.new(healthPercent, 0, 1, 0),
		BackgroundColor3 = healthColor,
	}):Play()
end

--[[
	Set player type (Self, Teammate, Enemy, Downed)
]]
function WorldHealthBar:SetPlayerType(playerType: PlayerType)
	self.playerType = playerType

	local colors = PLAYER_COLORS[playerType]
	if colors then
		self.healthBar.BackgroundColor3 = colors.bar
		self.nameLabel.TextColor3 = colors.name

		-- Add border/glow if specified
		if colors.border then
			local existingStroke = self.backgroundBar:FindFirstChildOfClass("UIStroke")
			if not existingStroke then
				local stroke = Instance.new("UIStroke")
				stroke.Color = colors.border
				stroke.Thickness = 2
				stroke.Transparency = 0.3
				stroke.Parent = self.backgroundBar
			else
				existingStroke.Color = colors.border
			end
		else
			local existingStroke = self.backgroundBar:FindFirstChildOfClass("UIStroke")
			if existingStroke then
				existingStroke:Destroy()
			end
		end
	end

	-- Hide for self (player sees their own HUD health)
	if playerType == "Self" then
		self.billboard.Enabled = false
	else
		self.billboard.Enabled = true
	end
end

--[[
	Set dinosaur tier for color
]]
function WorldHealthBar:SetDinoTier(tier: DinoTier)
	self.dinoTier = tier
	self.isDinosaur = true

	local color = DINO_TIER_COLORS[tier]
	if color then
		self.healthBar.BackgroundColor3 = color
		self.nameLabel.TextColor3 = color
	end

	-- Add glow for epic+ tiers
	if tier == "Epic" or tier == "Legendary" then
		local existingStroke = self.backgroundBar:FindFirstChildOfClass("UIStroke")
		if not existingStroke then
			local stroke = Instance.new("UIStroke")
			stroke.Color = color
			stroke.Thickness = 2
			stroke.Transparency = 0.5
			stroke.Parent = self.backgroundBar
		end
	end
end

--[[
	Set display name
]]
function WorldHealthBar:SetName(name: string)
	self.nameLabel.Text = name
end

--[[
	Update visibility based on distance
]]
function WorldHealthBar:UpdateVisibility(distance: number)
	if distance > MAX_VISIBLE_DISTANCE then
		self.billboard.Enabled = false
		return
	end

	-- Don't show for self
	if self.playerType == "Self" then
		self.billboard.Enabled = false
		return
	end

	self.billboard.Enabled = true

	-- Fade based on distance
	if distance > FADE_START_DISTANCE then
		local fadePercent = (distance - FADE_START_DISTANCE) / (MAX_VISIBLE_DISTANCE - FADE_START_DISTANCE)
		local transparency = fadePercent

		self.backgroundBar.BackgroundTransparency = 0.3 + (0.7 * transparency)
		self.healthBar.BackgroundTransparency = transparency
		self.nameLabel.TextTransparency = transparency
		self.nameLabel.TextStrokeTransparency = 0.5 + (0.5 * transparency)
	else
		self.backgroundBar.BackgroundTransparency = 0.3
		self.healthBar.BackgroundTransparency = 0
		self.nameLabel.TextTransparency = 0
		self.nameLabel.TextStrokeTransparency = 0.5
	end
end

--[[
	Cleanup
]]
function WorldHealthBar:Destroy()
	activeHealthBars[self.target] = nil
	self.billboard:Destroy()
end

--------------------------------------------------------------------------------
-- MODULE FUNCTIONS
--------------------------------------------------------------------------------

--[[
	Get or create health bar for a target
]]
function WorldHealthBar.GetOrCreate(target: Model, isDinosaur: boolean?): WorldHealthBarInstance
	local existing = activeHealthBars[target]
	if existing then
		return existing
	end

	return WorldHealthBar.new(target, isDinosaur)
end

--[[
	Get existing health bar for a target
]]
function WorldHealthBar.Get(target: Model): WorldHealthBarInstance?
	return activeHealthBars[target]
end

--[[
	Remove health bar for a target
]]
function WorldHealthBar.Remove(target: Model)
	local healthBar = activeHealthBars[target]
	if healthBar then
		healthBar:Destroy()
	end
end

--[[
	Start the distance update loop
]]
function WorldHealthBar.StartUpdateLoop()
	if updateConnection then
		return
	end

	updateConnection = RunService.Heartbeat:Connect(function()
		local playerCharacter = localPlayer.Character
		if not playerCharacter then
			return
		end

		local rootPart = playerCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not rootPart then
			return
		end

		local playerPosition = rootPart.Position

		-- Update all active health bars
		for target, healthBar in pairs(activeHealthBars) do
			if target and target.Parent then
				local targetRoot = target:FindFirstChild("HumanoidRootPart") :: BasePart?
					or target:FindFirstChild("Head") :: BasePart?

				if targetRoot then
					local distance = (targetRoot.Position - playerPosition).Magnitude
					healthBar:UpdateVisibility(distance)
				end
			else
				-- Target was destroyed, clean up
				healthBar:Destroy()
			end
		end
	end)
end

--[[
	Stop the update loop
]]
function WorldHealthBar.StopUpdateLoop()
	if updateConnection then
		updateConnection:Disconnect()
		updateConnection = nil
	end
end

--[[
	Clear all health bars
]]
function WorldHealthBar.ClearAll()
	for _, healthBar in pairs(activeHealthBars) do
		healthBar:Destroy()
	end
	activeHealthBars = {}
end

--[[
	Get count of active health bars
]]
function WorldHealthBar.GetActiveCount(): number
	local count = 0
	for _ in pairs(activeHealthBars) do
		count = count + 1
	end
	return count
end

return WorldHealthBar
