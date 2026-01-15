--!strict
--[[
	AmmoDisplay.lua
	===============
	Professional weapon ammo counter with reload indicator and weapon info.

	FEATURES:
	- Magazine/reserve ammo display with large readable numbers
	- Weapon name and type indicator
	- Ammo type color coding (Light/Medium/Heavy/Shells/Special)
	- Reload progress bar with smooth animation
	- Low ammo and empty warnings
	- Reload key hint

	DESIGN PRINCIPLES (from GDD 12.5):
	- Instant weapon status without looking away from center screen
	- Color-coded ammo types for quick identification
	- Clear visual states (full, low, empty, reloading)

	@client
]]

local TweenService = game:GetService("TweenService")

local AmmoDisplay = {}
AmmoDisplay.__index = AmmoDisplay

--------------------------------------------------------------------------------
-- CONFIGURATION
--------------------------------------------------------------------------------

-- Display dimensions
local DISPLAY_WIDTH = 180
local DISPLAY_HEIGHT = 70
local RELOAD_BAR_HEIGHT = 4
local CORNER_RADIUS = 8

-- Thresholds
local LOW_AMMO_THRESHOLD = 0.25

-- Animation timings
local RELOAD_FLASH_DURATION = 0.2
local EMPTY_FLASH_INTERVAL = 0.15
local NUMBER_TWEEN_TIME = 0.15

-- Colors (from GDD 12.5)
local COLORS = {
	-- Text colors
	TextNormal = Color3.new(1, 1, 1),
	TextLow = Color3.fromRGB(255, 200, 50),    -- Yellow warning
	TextEmpty = Color3.fromRGB(255, 50, 50),   -- Red empty

	-- Ammo type colors
	LightAmmo = Color3.fromRGB(255, 215, 0),   -- #FFD700 Yellow
	MediumAmmo = Color3.fromRGB(255, 140, 0),  -- #FF8C00 Orange
	HeavyAmmo = Color3.fromRGB(220, 20, 60),   -- #DC143C Red
	Shells = Color3.fromRGB(139, 69, 19),      -- #8B4513 Brown
	SpecialAmmo = Color3.fromRGB(153, 50, 204), -- #9932CC Purple

	-- UI colors
	Background = Color3.fromRGB(20, 20, 20),
	BackgroundBorder = Color3.fromRGB(50, 50, 50),
	ReloadBar = Color3.fromRGB(100, 200, 255),
	ReloadBarBg = Color3.fromRGB(40, 40, 40),
	ReserveText = Color3.fromRGB(180, 180, 180),
}

-- Ammo type to color mapping
local AMMO_TYPE_COLORS = {
	LightAmmo = COLORS.LightAmmo,
	MediumAmmo = COLORS.MediumAmmo,
	HeavyAmmo = COLORS.HeavyAmmo,
	Shells = COLORS.Shells,
	SpecialAmmo = COLORS.SpecialAmmo,
}

--------------------------------------------------------------------------------
-- TYPES
--------------------------------------------------------------------------------

export type AmmoDisplayInstance = {
	frame: Frame,
	magLabel: TextLabel,
	separatorLabel: TextLabel,
	reserveLabel: TextLabel,
	weaponNameLabel: TextLabel,
	ammoTypeBar: Frame,
	reloadBarContainer: Frame,
	reloadBar: Frame,
	reloadHint: TextLabel,

	-- State
	currentMag: number,
	maxMag: number,
	reserve: number,
	weaponName: string,
	ammoType: string,
	isReloading: boolean,
	reloadTween: Tween?,

	-- Methods
	Update: (self: AmmoDisplayInstance, currentMag: number, maxMag: number, reserve: number) -> (),
	SetWeaponInfo: (self: AmmoDisplayInstance, weaponName: string, ammoType: string) -> (),
	StartReload: (self: AmmoDisplayInstance, duration: number) -> (),
	CancelReload: (self: AmmoDisplayInstance) -> (),
	ShowEmpty: (self: AmmoDisplayInstance) -> (),
	SetVisible: (self: AmmoDisplayInstance, visible: boolean) -> (),
	Destroy: (self: AmmoDisplayInstance) -> (),
}

--------------------------------------------------------------------------------
-- HELPER FUNCTIONS
--------------------------------------------------------------------------------

--[[
	Add rounded corners to a frame
]]
local function addCorner(parent: GuiObject, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or CORNER_RADIUS)
	corner.Parent = parent
	return corner
end

--[[
	Add stroke/border to a frame
]]
local function addStroke(parent: GuiObject, color: Color3, thickness: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

--------------------------------------------------------------------------------
-- CONSTRUCTOR
--------------------------------------------------------------------------------

--[[
	Create a new ammo display
	@param parent Parent GUI element
	@param position UDim2 position
	@return AmmoDisplayInstance
]]
function AmmoDisplay.new(parent: GuiObject, position: UDim2): AmmoDisplayInstance
	local self = setmetatable({}, AmmoDisplay) :: any

	-- Initialize state
	self.currentMag = 0
	self.maxMag = 0
	self.reserve = 0
	self.weaponName = ""
	self.ammoType = "MediumAmmo"
	self.isReloading = false
	self.reloadTween = nil

	-- Main frame (anchored bottom-right)
	self.frame = Instance.new("Frame")
	self.frame.Name = "AmmoDisplay"
	self.frame.Position = position
	self.frame.AnchorPoint = Vector2.new(1, 1)
	self.frame.Size = UDim2.fromOffset(DISPLAY_WIDTH, DISPLAY_HEIGHT)
	self.frame.BackgroundColor3 = COLORS.Background
	self.frame.BackgroundTransparency = 0.2
	self.frame.BorderSizePixel = 0
	self.frame.Parent = parent

	addCorner(self.frame)
	addStroke(self.frame, COLORS.BackgroundBorder, 2)

	-- Create UI elements
	self:CreateAmmoCounter()
	self:CreateWeaponInfo()
	self:CreateReloadBar()

	return self
end

--------------------------------------------------------------------------------
-- UI CREATION METHODS
--------------------------------------------------------------------------------

--[[
	Create the main ammo counter (mag / reserve)
]]
function AmmoDisplay:CreateAmmoCounter()
	-- Magazine count (large, prominent)
	self.magLabel = Instance.new("TextLabel")
	self.magLabel.Name = "MagLabel"
	self.magLabel.Position = UDim2.fromOffset(15, 8)
	self.magLabel.Size = UDim2.fromOffset(60, 35)
	self.magLabel.BackgroundTransparency = 1
	self.magLabel.Text = "30"
	self.magLabel.TextColor3 = COLORS.TextNormal
	self.magLabel.TextSize = 32
	self.magLabel.Font = Enum.Font.GothamBold
	self.magLabel.TextXAlignment = Enum.TextXAlignment.Right
	self.magLabel.TextStrokeTransparency = 0.5
	self.magLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	self.magLabel.Parent = self.frame

	-- Separator "/"
	self.separatorLabel = Instance.new("TextLabel")
	self.separatorLabel.Name = "Separator"
	self.separatorLabel.Position = UDim2.fromOffset(78, 12)
	self.separatorLabel.Size = UDim2.fromOffset(15, 30)
	self.separatorLabel.BackgroundTransparency = 1
	self.separatorLabel.Text = "/"
	self.separatorLabel.TextColor3 = COLORS.ReserveText
	self.separatorLabel.TextSize = 20
	self.separatorLabel.Font = Enum.Font.Gotham
	self.separatorLabel.Parent = self.frame

	-- Reserve ammo (smaller)
	self.reserveLabel = Instance.new("TextLabel")
	self.reserveLabel.Name = "ReserveLabel"
	self.reserveLabel.Position = UDim2.fromOffset(95, 15)
	self.reserveLabel.Size = UDim2.fromOffset(50, 25)
	self.reserveLabel.BackgroundTransparency = 1
	self.reserveLabel.Text = "90"
	self.reserveLabel.TextColor3 = COLORS.ReserveText
	self.reserveLabel.TextSize = 18
	self.reserveLabel.Font = Enum.Font.Gotham
	self.reserveLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.reserveLabel.Parent = self.frame

	-- Reload hint (R key)
	self.reloadHint = Instance.new("TextLabel")
	self.reloadHint.Name = "ReloadHint"
	self.reloadHint.Position = UDim2.new(1, -10, 0, 10)
	self.reloadHint.AnchorPoint = Vector2.new(1, 0)
	self.reloadHint.Size = UDim2.fromOffset(30, 20)
	self.reloadHint.BackgroundTransparency = 1
	self.reloadHint.Text = "[R]"
	self.reloadHint.TextColor3 = COLORS.ReserveText
	self.reloadHint.TextSize = 12
	self.reloadHint.Font = Enum.Font.Gotham
	self.reloadHint.Visible = false -- Only show when can reload
	self.reloadHint.Parent = self.frame
end

--[[
	Create weapon name and ammo type indicator
]]
function AmmoDisplay:CreateWeaponInfo()
	-- Weapon name label
	self.weaponNameLabel = Instance.new("TextLabel")
	self.weaponNameLabel.Name = "WeaponName"
	self.weaponNameLabel.Position = UDim2.fromOffset(15, 42)
	self.weaponNameLabel.Size = UDim2.new(1, -30, 0, 16)
	self.weaponNameLabel.BackgroundTransparency = 1
	self.weaponNameLabel.Text = "RANGER AR"
	self.weaponNameLabel.TextColor3 = COLORS.ReserveText
	self.weaponNameLabel.TextSize = 11
	self.weaponNameLabel.Font = Enum.Font.GothamBold
	self.weaponNameLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.weaponNameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	self.weaponNameLabel.Parent = self.frame

	-- Ammo type color bar (bottom indicator)
	self.ammoTypeBar = Instance.new("Frame")
	self.ammoTypeBar.Name = "AmmoTypeBar"
	self.ammoTypeBar.Position = UDim2.new(0, 10, 1, -8)
	self.ammoTypeBar.Size = UDim2.new(1, -20, 0, 3)
	self.ammoTypeBar.BackgroundColor3 = COLORS.MediumAmmo
	self.ammoTypeBar.BorderSizePixel = 0
	self.ammoTypeBar.Parent = self.frame

	addCorner(self.ammoTypeBar, 2)
end

--[[
	Create reload progress bar
]]
function AmmoDisplay:CreateReloadBar()
	-- Reload bar container (background)
	self.reloadBarContainer = Instance.new("Frame")
	self.reloadBarContainer.Name = "ReloadBarContainer"
	self.reloadBarContainer.Position = UDim2.new(0, 10, 1, -(RELOAD_BAR_HEIGHT + 12))
	self.reloadBarContainer.Size = UDim2.new(1, -20, 0, RELOAD_BAR_HEIGHT)
	self.reloadBarContainer.BackgroundColor3 = COLORS.ReloadBarBg
	self.reloadBarContainer.BorderSizePixel = 0
	self.reloadBarContainer.Visible = false
	self.reloadBarContainer.Parent = self.frame

	addCorner(self.reloadBarContainer, 2)

	-- Reload bar fill
	self.reloadBar = Instance.new("Frame")
	self.reloadBar.Name = "ReloadBar"
	self.reloadBar.Position = UDim2.fromScale(0, 0)
	self.reloadBar.Size = UDim2.fromScale(0, 1)
	self.reloadBar.BackgroundColor3 = COLORS.ReloadBar
	self.reloadBar.BorderSizePixel = 0
	self.reloadBar.Parent = self.reloadBarContainer

	addCorner(self.reloadBar, 2)
end

--------------------------------------------------------------------------------
-- UPDATE METHODS
--------------------------------------------------------------------------------

--[[
	Update ammo counts with animations
]]
function AmmoDisplay:Update(currentMag: number, maxMag: number, reserve: number)
	local previousMag = self.currentMag
	self.currentMag = currentMag
	self.maxMag = maxMag
	self.reserve = reserve

	-- Update magazine label with animation
	self.magLabel.Text = tostring(currentMag)

	-- Calculate ammo state
	local magPercent = maxMag > 0 and (currentMag / maxMag) or 0

	-- Update magazine color based on state
	local magColor = COLORS.TextNormal
	if currentMag == 0 then
		magColor = COLORS.TextEmpty
	elseif magPercent <= LOW_AMMO_THRESHOLD then
		magColor = COLORS.TextLow
	end

	-- Tween color change
	TweenService:Create(self.magLabel, TweenInfo.new(NUMBER_TWEEN_TIME), {
		TextColor3 = magColor,
	}):Play()

	-- Update reserve label
	self.reserveLabel.Text = tostring(reserve)

	-- Reserve color
	if reserve == 0 then
		self.reserveLabel.TextColor3 = COLORS.TextEmpty
		self.reserveLabel.Text = "OUT"
	else
		self.reserveLabel.TextColor3 = COLORS.ReserveText
	end

	-- Show reload hint when mag not full and has reserve
	local canReload = currentMag < maxMag and reserve > 0 and not self.isReloading
	self.reloadHint.Visible = canReload

	-- Flash reload hint if empty
	if currentMag == 0 and reserve > 0 and not self.isReloading then
		self:FlashReloadHint()
	end

	-- Scale animation on ammo change
	if currentMag ~= previousMag then
		local scaleUp = currentMag < previousMag and 1.1 or 1.05
		self.magLabel.Size = UDim2.fromOffset(60 * scaleUp, 35 * scaleUp)

		TweenService:Create(self.magLabel, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(60, 35),
		}):Play()
	end
end

--[[
	Set weapon information
]]
function AmmoDisplay:SetWeaponInfo(weaponName: string, ammoType: string)
	self.weaponName = weaponName
	self.ammoType = ammoType

	-- Update weapon name (uppercase for style)
	self.weaponNameLabel.Text = string.upper(weaponName)

	-- Update ammo type bar color
	local ammoColor = AMMO_TYPE_COLORS[ammoType] or COLORS.MediumAmmo
	TweenService:Create(self.ammoTypeBar, TweenInfo.new(0.2), {
		BackgroundColor3 = ammoColor,
	}):Play()
end

--[[
	Flash reload hint to draw attention
]]
function AmmoDisplay:FlashReloadHint()
	if not self.reloadHint.Visible then
		return
	end

	-- Flash animation
	local originalColor = self.reloadHint.TextColor3
	self.reloadHint.TextColor3 = COLORS.TextEmpty

	TweenService:Create(self.reloadHint, TweenInfo.new(0.3), {
		TextColor3 = originalColor,
	}):Play()
end

--------------------------------------------------------------------------------
-- RELOAD METHODS
--------------------------------------------------------------------------------

--[[
	Start reload animation
	@param duration Reload duration in seconds
]]
function AmmoDisplay:StartReload(duration: number)
	if self.isReloading then
		return
	end

	self.isReloading = true

	-- Hide normal ammo bar, show reload bar
	self.ammoTypeBar.Visible = false
	self.reloadBarContainer.Visible = true
	self.reloadHint.Visible = false

	-- Reset reload bar
	self.reloadBar.Size = UDim2.fromScale(0, 1)

	-- Cancel existing tween
	if self.reloadTween then
		self.reloadTween:Cancel()
	end

	-- Show reloading text
	self.magLabel.Text = "..."
	self.magLabel.TextColor3 = COLORS.ReloadBar

	-- Animate reload bar
	self.reloadTween = TweenService:Create(self.reloadBar, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		Size = UDim2.fromScale(1, 1),
	})
	self.reloadTween:Play()

	-- Handle completion
	self.reloadTween.Completed:Once(function(playbackState)
		if playbackState == Enum.PlaybackState.Completed then
			self:FinishReload()
		end
	end)
end

--[[
	Complete reload animation
]]
function AmmoDisplay:FinishReload()
	self.isReloading = false

	-- Hide reload bar, show ammo bar
	self.reloadBarContainer.Visible = false
	self.ammoTypeBar.Visible = true

	-- Flash completion effect
	local flash = Instance.new("Frame")
	flash.Name = "ReloadFlash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.Position = UDim2.fromScale(0, 0)
	flash.BackgroundColor3 = COLORS.ReloadBar
	flash.BackgroundTransparency = 0.5
	flash.ZIndex = 10
	flash.Parent = self.frame

	addCorner(flash)

	-- Fade out flash
	local flashTween = TweenService:Create(flash, TweenInfo.new(RELOAD_FLASH_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	})
	flashTween:Play()
	flashTween.Completed:Once(function()
		flash:Destroy()
	end)

	-- Update display
	self:Update(self.currentMag, self.maxMag, self.reserve)
end

--[[
	Cancel reload animation
]]
function AmmoDisplay:CancelReload()
	if not self.isReloading then
		return
	end

	self.isReloading = false

	-- Cancel tween
	if self.reloadTween then
		self.reloadTween:Cancel()
		self.reloadTween = nil
	end

	-- Hide reload bar
	self.reloadBarContainer.Visible = false
	self.ammoTypeBar.Visible = true

	-- Restore ammo display
	self:Update(self.currentMag, self.maxMag, self.reserve)
end

--[[
	Show empty magazine warning animation
]]
function AmmoDisplay:ShowEmpty()
	-- Flash red multiple times
	task.spawn(function()
		for _ = 1, 3 do
			self.magLabel.TextColor3 = COLORS.TextEmpty

			-- Scale up
			TweenService:Create(self.magLabel, TweenInfo.new(EMPTY_FLASH_INTERVAL), {
				Size = UDim2.fromOffset(65, 38),
			}):Play()

			task.wait(EMPTY_FLASH_INTERVAL)

			-- Scale back
			TweenService:Create(self.magLabel, TweenInfo.new(EMPTY_FLASH_INTERVAL), {
				Size = UDim2.fromOffset(60, 35),
			}):Play()

			task.wait(EMPTY_FLASH_INTERVAL)
		end

		-- Ensure proper final state
		if self.currentMag == 0 then
			self.magLabel.TextColor3 = COLORS.TextEmpty
		end
	end)
end

--[[
	Set visibility
]]
function AmmoDisplay:SetVisible(visible: boolean)
	self.frame.Visible = visible
end

--[[
	Cleanup
]]
function AmmoDisplay:Destroy()
	if self.reloadTween then
		self.reloadTween:Cancel()
	end
	self.frame:Destroy()
end

return AmmoDisplay
