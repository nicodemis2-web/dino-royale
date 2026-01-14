--!strict
--[[
	AmmoDisplay.lua
	===============
	Weapon ammo counter and reload indicator
	Shows current mag, reserve ammo, reload progress
]]

local TweenService = game:GetService("TweenService")

local AmmoDisplay = {}
AmmoDisplay.__index = AmmoDisplay

-- Display settings
local DISPLAY_WIDTH = 150
local DISPLAY_HEIGHT = 50
local RELOAD_BAR_HEIGHT = 4
local LOW_AMMO_THRESHOLD = 0.25
local EMPTY_FLASH_DURATION = 0.15

-- Colors
local TEXT_COLOR = Color3.new(1, 1, 1)
local LOW_AMMO_COLOR = Color3.fromRGB(255, 200, 50)
local EMPTY_COLOR = Color3.fromRGB(255, 50, 50)
local RELOAD_COLOR = Color3.fromRGB(100, 200, 255)
local BACKGROUND_COLOR = Color3.fromRGB(30, 30, 30)

export type AmmoDisplayInstance = {
	frame: Frame,
	magLabel: TextLabel,
	reserveLabel: TextLabel,
	reloadBar: Frame,
	currentMag: number,
	maxMag: number,
	reserve: number,
	isReloading: boolean,
	reloadProgress: number,

	Update: (self: AmmoDisplayInstance, currentMag: number, maxMag: number, reserve: number) -> (),
	StartReload: (self: AmmoDisplayInstance, duration: number) -> (),
	CancelReload: (self: AmmoDisplayInstance) -> (),
	ShowEmpty: (self: AmmoDisplayInstance) -> (),
	SetVisible: (self: AmmoDisplayInstance, visible: boolean) -> (),
	Destroy: (self: AmmoDisplayInstance) -> (),
}

--[[
	Create a new ammo display
	@param parent Parent GUI element
	@param position UDim2 position
	@return AmmoDisplayInstance
]]
function AmmoDisplay.new(parent: GuiObject, position: UDim2): AmmoDisplayInstance
	local self = setmetatable({}, AmmoDisplay) :: any

	-- State
	self.currentMag = 0
	self.maxMag = 0
	self.reserve = 0
	self.isReloading = false
	self.reloadProgress = 0
	self.reloadTween = nil

	-- Main frame
	self.frame = Instance.new("Frame")
	self.frame.Name = "AmmoDisplay"
	self.frame.Position = position
	self.frame.Size = UDim2.fromOffset(DISPLAY_WIDTH, DISPLAY_HEIGHT)
	self.frame.BackgroundColor3 = BACKGROUND_COLOR
	self.frame.BackgroundTransparency = 0.3
	self.frame.BorderSizePixel = 0
	self.frame.Parent = parent

	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 8)
	frameCorner.Parent = self.frame

	-- Ammo icon
	local ammoIcon = Instance.new("ImageLabel")
	ammoIcon.Name = "AmmoIcon"
	ammoIcon.Position = UDim2.fromOffset(10, 10)
	ammoIcon.Size = UDim2.fromOffset(30, 30)
	ammoIcon.BackgroundTransparency = 1
	ammoIcon.Image = "rbxassetid://0" -- Placeholder
	ammoIcon.ImageColor3 = TEXT_COLOR
	ammoIcon.Parent = self.frame

	-- Magazine count (large)
	self.magLabel = Instance.new("TextLabel")
	self.magLabel.Name = "MagLabel"
	self.magLabel.Position = UDim2.fromOffset(50, 5)
	self.magLabel.Size = UDim2.fromOffset(60, 30)
	self.magLabel.BackgroundTransparency = 1
	self.magLabel.Text = "30"
	self.magLabel.TextColor3 = TEXT_COLOR
	self.magLabel.TextSize = 28
	self.magLabel.Font = Enum.Font.GothamBold
	self.magLabel.TextXAlignment = Enum.TextXAlignment.Right
	self.magLabel.Parent = self.frame

	-- Separator
	local separator = Instance.new("TextLabel")
	separator.Name = "Separator"
	separator.Position = UDim2.fromOffset(112, 5)
	separator.Size = UDim2.fromOffset(10, 30)
	separator.BackgroundTransparency = 1
	separator.Text = "/"
	separator.TextColor3 = Color3.fromRGB(150, 150, 150)
	separator.TextSize = 20
	separator.Font = Enum.Font.Gotham
	separator.Parent = self.frame

	-- Reserve count (smaller)
	self.reserveLabel = Instance.new("TextLabel")
	self.reserveLabel.Name = "ReserveLabel"
	self.reserveLabel.Position = UDim2.fromOffset(122, 12)
	self.reserveLabel.Size = UDim2.fromOffset(25, 20)
	self.reserveLabel.BackgroundTransparency = 1
	self.reserveLabel.Text = "90"
	self.reserveLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	self.reserveLabel.TextSize = 16
	self.reserveLabel.Font = Enum.Font.Gotham
	self.reserveLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.reserveLabel.Parent = self.frame

	-- Reload bar background
	local reloadBg = Instance.new("Frame")
	reloadBg.Name = "ReloadBackground"
	reloadBg.Position = UDim2.new(0, 10, 1, -(RELOAD_BAR_HEIGHT + 5))
	reloadBg.Size = UDim2.new(1, -20, 0, RELOAD_BAR_HEIGHT)
	reloadBg.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	reloadBg.BorderSizePixel = 0
	reloadBg.Visible = false
	reloadBg.Parent = self.frame

	local reloadBgCorner = Instance.new("UICorner")
	reloadBgCorner.CornerRadius = UDim.new(0, 2)
	reloadBgCorner.Parent = reloadBg

	-- Reload bar fill
	self.reloadBar = Instance.new("Frame")
	self.reloadBar.Name = "ReloadBar"
	self.reloadBar.Size = UDim2.fromScale(0, 1)
	self.reloadBar.BackgroundColor3 = RELOAD_COLOR
	self.reloadBar.BorderSizePixel = 0
	self.reloadBar.Parent = reloadBg

	local reloadBarCorner = Instance.new("UICorner")
	reloadBarCorner.CornerRadius = UDim.new(0, 2)
	reloadBarCorner.Parent = self.reloadBar

	return self
end

--[[
	Update ammo counts
]]
function AmmoDisplay:Update(currentMag: number, maxMag: number, reserve: number)
	self.currentMag = currentMag
	self.maxMag = maxMag
	self.reserve = reserve

	-- Update labels
	self.magLabel.Text = tostring(currentMag)
	self.reserveLabel.Text = tostring(reserve)

	-- Update colors based on ammo state
	local magPercent = maxMag > 0 and (currentMag / maxMag) or 0

	if currentMag == 0 then
		self.magLabel.TextColor3 = EMPTY_COLOR
	elseif magPercent <= LOW_AMMO_THRESHOLD then
		self.magLabel.TextColor3 = LOW_AMMO_COLOR
	else
		self.magLabel.TextColor3 = TEXT_COLOR
	end

	-- Reserve color
	if reserve == 0 then
		self.reserveLabel.TextColor3 = EMPTY_COLOR
	else
		self.reserveLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	end
end

--[[
	Start reload animation
	@param duration Reload duration in seconds
]]
function AmmoDisplay:StartReload(duration: number)
	if self.isReloading then
		return
	end

	self.isReloading = true
	self.reloadProgress = 0

	-- Show reload bar
	local reloadBg = self.reloadBar.Parent :: Frame?
	if reloadBg then
		reloadBg.Visible = true
	end

	self.reloadBar.Size = UDim2.fromScale(0, 1)

	-- Cancel existing tween
	if self.reloadTween then
		self.reloadTween:Cancel()
	end

	-- Animate reload bar
	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
	self.reloadTween = TweenService:Create(self.reloadBar, tweenInfo, {
		Size = UDim2.fromScale(1, 1),
	})
	self.reloadTween:Play()

	self.reloadTween.Completed:Connect(function(playbackState)
		if playbackState == Enum.PlaybackState.Completed then
			self:FinishReload()
		end
	end)

	-- Show reloading text
	self.magLabel.Text = "..."
	self.magLabel.TextColor3 = RELOAD_COLOR
end

--[[
	Finish reload animation
]]
function AmmoDisplay:FinishReload()
	self.isReloading = false
	self.reloadProgress = 1

	-- Hide reload bar
	local reloadBg = self.reloadBar.Parent :: Frame?
	if reloadBg then
		reloadBg.Visible = false
	end

	-- Flash completion
	local flash = Instance.new("Frame")
	flash.Name = "ReloadFlash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = RELOAD_COLOR
	flash.BackgroundTransparency = 0.7
	flash.ZIndex = 10
	flash.Parent = self.frame

	local flashCorner = Instance.new("UICorner")
	flashCorner.CornerRadius = UDim.new(0, 8)
	flashCorner.Parent = flash

	local tween = TweenService:Create(flash, TweenInfo.new(0.2), { BackgroundTransparency = 1 })
	tween:Play()
	tween.Completed:Connect(function()
		flash:Destroy()
	end)
end

--[[
	Cancel reload
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
	local reloadBg = self.reloadBar.Parent :: Frame?
	if reloadBg then
		reloadBg.Visible = false
	end

	-- Update display
	self:Update(self.currentMag, self.maxMag, self.reserve)
end

--[[
	Show empty magazine indicator
]]
function AmmoDisplay:ShowEmpty()
	-- Flash red
	local originalColor = self.magLabel.TextColor3

	for _ = 1, 3 do
		self.magLabel.TextColor3 = EMPTY_COLOR
		task.wait(EMPTY_FLASH_DURATION)
		self.magLabel.TextColor3 = originalColor
		task.wait(EMPTY_FLASH_DURATION)
	end

	-- Ensure proper color after flashing
	if self.currentMag == 0 then
		self.magLabel.TextColor3 = EMPTY_COLOR
	end
end

--[[
	Set visibility
]]
function AmmoDisplay:SetVisible(visible: boolean)
	self.frame.Visible = visible
end

--[[
	Destroy the display
]]
function AmmoDisplay:Destroy()
	if self.reloadTween then
		self.reloadTween:Cancel()
	end
	self.frame:Destroy()
end

return AmmoDisplay
