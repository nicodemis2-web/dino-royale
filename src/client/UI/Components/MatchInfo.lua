--!strict
--[[
	MatchInfo.lua
	=============
	Displays match state information
	Players alive, kill count, placement, storm timer
]]

local TweenService = game:GetService("TweenService")

local MatchInfo = {}
MatchInfo.__index = MatchInfo

-- Display settings
local FRAME_WIDTH = 180
local FRAME_HEIGHT = 80
local PULSE_SPEED = 2

-- Colors
local BACKGROUND_COLOR = Color3.fromRGB(30, 30, 30)
local TEXT_COLOR = Color3.new(1, 1, 1)
local WARNING_COLOR = Color3.fromRGB(255, 200, 50)
local DANGER_COLOR = Color3.fromRGB(255, 50, 50)

export type MatchInfoInstance = {
	frame: Frame,
	aliveLabel: TextLabel,
	killsLabel: TextLabel,
	stormTimerLabel: TextLabel,
	placementLabel: TextLabel?,
	playersAlive: number,
	personalKills: number,
	stormTimeRemaining: number,
	isStormWarning: boolean,

	UpdatePlayersAlive: (self: MatchInfoInstance, count: number) -> (),
	UpdateKills: (self: MatchInfoInstance, kills: number) -> (),
	UpdateStormTimer: (self: MatchInfoInstance, seconds: number) -> (),
	ShowPlacement: (self: MatchInfoInstance, placement: number) -> (),
	ShowMatchStart: (self: MatchInfoInstance) -> (),
	ShowVictory: (self: MatchInfoInstance) -> (),
	Destroy: (self: MatchInfoInstance) -> (),
}

--[[
	Create new match info display
	@param parent Parent GUI element
	@param position UDim2 position
	@return MatchInfoInstance
]]
function MatchInfo.new(parent: GuiObject, position: UDim2): MatchInfoInstance
	local self = setmetatable({}, MatchInfo) :: any

	-- State
	self.playersAlive = 0
	self.personalKills = 0
	self.stormTimeRemaining = 0
	self.isStormWarning = false
	self.pulseConnection = nil

	-- Main frame
	self.frame = Instance.new("Frame")
	self.frame.Name = "MatchInfo"
	self.frame.Position = position
	self.frame.Size = UDim2.fromOffset(FRAME_WIDTH, FRAME_HEIGHT)
	self.frame.AnchorPoint = Vector2.new(0.5, 0)
	self.frame.BackgroundColor3 = BACKGROUND_COLOR
	self.frame.BackgroundTransparency = 0.3
	self.frame.BorderSizePixel = 0
	self.frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = self.frame

	-- Players alive section
	local aliveFrame = Instance.new("Frame")
	aliveFrame.Name = "AliveFrame"
	aliveFrame.Position = UDim2.fromOffset(10, 8)
	aliveFrame.Size = UDim2.fromOffset(70, 35)
	aliveFrame.BackgroundTransparency = 1
	aliveFrame.Parent = self.frame

	local aliveIcon = Instance.new("ImageLabel")
	aliveIcon.Name = "Icon"
	aliveIcon.Position = UDim2.fromOffset(0, 0)
	aliveIcon.Size = UDim2.fromOffset(20, 20)
	aliveIcon.BackgroundTransparency = 1
	aliveIcon.Image = "rbxassetid://0" -- Player icon
	aliveIcon.ImageColor3 = TEXT_COLOR
	aliveIcon.Parent = aliveFrame

	self.aliveLabel = Instance.new("TextLabel")
	self.aliveLabel.Name = "Count"
	self.aliveLabel.Position = UDim2.fromOffset(0, 20)
	self.aliveLabel.Size = UDim2.new(1, 0, 0, 15)
	self.aliveLabel.BackgroundTransparency = 1
	self.aliveLabel.Text = "100"
	self.aliveLabel.TextColor3 = TEXT_COLOR
	self.aliveLabel.TextSize = 24
	self.aliveLabel.Font = Enum.Font.GothamBold
	self.aliveLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.aliveLabel.Parent = aliveFrame

	-- Kills section
	local killsFrame = Instance.new("Frame")
	killsFrame.Name = "KillsFrame"
	killsFrame.Position = UDim2.fromOffset(100, 8)
	killsFrame.Size = UDim2.fromOffset(70, 35)
	killsFrame.BackgroundTransparency = 1
	killsFrame.Parent = self.frame

	local killsIcon = Instance.new("ImageLabel")
	killsIcon.Name = "Icon"
	killsIcon.Position = UDim2.fromOffset(0, 0)
	killsIcon.Size = UDim2.fromOffset(20, 20)
	killsIcon.BackgroundTransparency = 1
	killsIcon.Image = "rbxassetid://0" -- Skull icon
	killsIcon.ImageColor3 = TEXT_COLOR
	killsIcon.Parent = killsFrame

	self.killsLabel = Instance.new("TextLabel")
	self.killsLabel.Name = "Count"
	self.killsLabel.Position = UDim2.fromOffset(0, 20)
	self.killsLabel.Size = UDim2.new(1, 0, 0, 15)
	self.killsLabel.BackgroundTransparency = 1
	self.killsLabel.Text = "0"
	self.killsLabel.TextColor3 = TEXT_COLOR
	self.killsLabel.TextSize = 24
	self.killsLabel.Font = Enum.Font.GothamBold
	self.killsLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.killsLabel.Parent = killsFrame

	-- Storm timer section
	local stormFrame = Instance.new("Frame")
	stormFrame.Name = "StormFrame"
	stormFrame.Position = UDim2.fromOffset(10, 50)
	stormFrame.Size = UDim2.new(1, -20, 0, 25)
	stormFrame.BackgroundTransparency = 1
	stormFrame.Parent = self.frame

	local stormIcon = Instance.new("ImageLabel")
	stormIcon.Name = "Icon"
	stormIcon.Position = UDim2.fromOffset(0, 2)
	stormIcon.Size = UDim2.fromOffset(16, 16)
	stormIcon.BackgroundTransparency = 1
	stormIcon.Image = "rbxassetid://0" -- Storm icon
	stormIcon.ImageColor3 = Color3.fromRGB(150, 100, 255)
	stormIcon.Parent = stormFrame

	self.stormTimerLabel = Instance.new("TextLabel")
	self.stormTimerLabel.Name = "Timer"
	self.stormTimerLabel.Position = UDim2.fromOffset(22, 0)
	self.stormTimerLabel.Size = UDim2.new(1, -22, 1, 0)
	self.stormTimerLabel.BackgroundTransparency = 1
	self.stormTimerLabel.Text = "Safe Zone: 2:00"
	self.stormTimerLabel.TextColor3 = TEXT_COLOR
	self.stormTimerLabel.TextSize = 14
	self.stormTimerLabel.Font = Enum.Font.Gotham
	self.stormTimerLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.stormTimerLabel.Parent = stormFrame

	return self
end

--[[
	Update players alive count
]]
function MatchInfo:UpdatePlayersAlive(count: number)
	local previousCount = self.playersAlive
	self.playersAlive = count
	self.aliveLabel.Text = tostring(count)

	-- Animate if count decreased
	if count < previousCount then
		-- Scale pop effect
		TweenService:Create(self.aliveLabel, TweenInfo.new(0.1), {
			TextSize = 28,
		}):Play()

		task.delay(0.1, function()
			TweenService:Create(self.aliveLabel, TweenInfo.new(0.1), {
				TextSize = 24,
			}):Play()
		end)
	end
end

--[[
	Update personal kill count
]]
function MatchInfo:UpdateKills(kills: number)
	local previousKills = self.personalKills
	self.personalKills = kills
	self.killsLabel.Text = tostring(kills)

	-- Animate if kills increased
	if kills > previousKills then
		-- Flash and scale
		self.killsLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
		TweenService:Create(self.killsLabel, TweenInfo.new(0.1), {
			TextSize = 32,
		}):Play()

		task.delay(0.2, function()
			TweenService:Create(self.killsLabel, TweenInfo.new(0.2), {
				TextSize = 24,
				TextColor3 = TEXT_COLOR,
			}):Play()
		end)
	end
end

--[[
	Update storm timer
]]
function MatchInfo:UpdateStormTimer(seconds: number)
	self.stormTimeRemaining = seconds

	-- Format time
	local minutes = math.floor(seconds / 60)
	local secs = math.floor(seconds % 60)
	local timeStr = string.format("%d:%02d", minutes, secs)

	-- Determine state text
	local stateText = "Safe Zone: "
	if seconds <= 0 then
		stateText = "Storm Moving!"
		self.stormTimerLabel.TextColor3 = DANGER_COLOR
	elseif seconds <= 30 then
		stateText = "Storm Warning: "
		self.stormTimerLabel.TextColor3 = WARNING_COLOR
		self:StartStormPulse()
	else
		self.stormTimerLabel.TextColor3 = TEXT_COLOR
		self:StopStormPulse()
	end

	self.stormTimerLabel.Text = stateText .. timeStr
end

--[[
	Start storm warning pulse
]]
function MatchInfo:StartStormPulse()
	if self.pulseConnection then
		return
	end

	local RunService = game:GetService("RunService")
	self.pulseConnection = RunService.Heartbeat:Connect(function()
		local pulse = (math.sin(tick() * PULSE_SPEED * math.pi) + 1) / 2
		local color = WARNING_COLOR:Lerp(DANGER_COLOR, pulse)
		self.stormTimerLabel.TextColor3 = color
	end)
end

--[[
	Stop storm warning pulse
]]
function MatchInfo:StopStormPulse()
	if self.pulseConnection then
		self.pulseConnection:Disconnect()
		self.pulseConnection = nil
	end
end

--[[
	Show final placement
]]
function MatchInfo:ShowPlacement(placement: number)
	-- Create overlay
	local overlay = Instance.new("Frame")
	overlay.Name = "PlacementOverlay"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.5
	overlay.ZIndex = 10
	overlay.Parent = self.frame

	local overlayCorner = Instance.new("UICorner")
	overlayCorner.CornerRadius = UDim.new(0, 8)
	overlayCorner.Parent = overlay

	self.placementLabel = Instance.new("TextLabel")
	self.placementLabel.Name = "Placement"
	self.placementLabel.Size = UDim2.fromScale(1, 1)
	self.placementLabel.BackgroundTransparency = 1
	self.placementLabel.Text = `#{placement}`
	self.placementLabel.TextColor3 = Color3.new(1, 1, 1)
	self.placementLabel.TextSize = 36
	self.placementLabel.Font = Enum.Font.GothamBold
	self.placementLabel.ZIndex = 11
	self.placementLabel.Parent = overlay

	-- Color based on placement
	if placement == 1 then
		self.placementLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
		self.placementLabel.Text = "VICTORY!"
	elseif placement <= 3 then
		self.placementLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	elseif placement <= 10 then
		self.placementLabel.TextColor3 = Color3.fromRGB(180, 100, 50)
	end

	-- Animate in
	self.placementLabel.TextTransparency = 1
	TweenService:Create(self.placementLabel, TweenInfo.new(0.5), {
		TextTransparency = 0,
	}):Play()
end

--[[
	Show match start animation
]]
function MatchInfo:ShowMatchStart()
	-- Flash effect
	local flash = Instance.new("Frame")
	flash.Name = "StartFlash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 0
	flash.ZIndex = 10
	flash.Parent = self.frame

	local flashCorner = Instance.new("UICorner")
	flashCorner.CornerRadius = UDim.new(0, 8)
	flashCorner.Parent = flash

	TweenService:Create(flash, TweenInfo.new(0.5), {
		BackgroundTransparency = 1,
	}):Play()

	task.delay(0.5, function()
		flash:Destroy()
	end)
end

--[[
	Show victory animation
]]
function MatchInfo:ShowVictory()
	self:ShowPlacement(1)

	-- Gold pulse effect
	if self.placementLabel then
		local RunService = game:GetService("RunService")
		local conn
		conn = RunService.Heartbeat:Connect(function()
			local pulse = (math.sin(tick() * 3) + 1) / 2
			if self.placementLabel then
				self.placementLabel.TextColor3 = Color3.fromRGB(255, 200 + pulse * 55, 50)
			end
		end)

		task.delay(5, function()
			conn:Disconnect()
		end)
	end
end

--[[
	Destroy the display
]]
function MatchInfo:Destroy()
	self:StopStormPulse()
	self.frame:Destroy()
end

return MatchInfo
