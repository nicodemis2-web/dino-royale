--!strict
--[[
	InteractionPrompt.lua
	====================
	Shows interaction prompts for nearby interactable objects
	Loot, vehicles, doors, etc.
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local InteractionPrompt = {}
InteractionPrompt.__index = InteractionPrompt

-- Display settings
local PROMPT_WIDTH = 200
local PROMPT_HEIGHT = 50
local PROGRESS_HEIGHT = 4
local FADE_DURATION = 0.2

-- Colors
local BACKGROUND_COLOR = Color3.fromRGB(30, 30, 30)
local TEXT_COLOR = Color3.new(1, 1, 1)
local KEY_BACKGROUND = Color3.fromRGB(60, 60, 60)
local PROGRESS_COLOR = Color3.fromRGB(100, 200, 255)

-- Rarity colors for loot
local RARITY_COLORS = {
	Common = Color3.fromRGB(180, 180, 180),
	Uncommon = Color3.fromRGB(50, 200, 50),
	Rare = Color3.fromRGB(50, 150, 255),
	Epic = Color3.fromRGB(180, 50, 255),
	Legendary = Color3.fromRGB(255, 150, 50),
}

export type PromptData = {
	actionText: string,
	objectText: string,
	keyCode: Enum.KeyCode?,
	holdDuration: number?,
	rarity: string?,
	icon: string?,
}

export type InteractionPromptInstance = {
	frame: Frame,
	keyLabel: TextLabel,
	actionLabel: TextLabel,
	objectLabel: TextLabel,
	progressBar: Frame,
	currentData: PromptData?,
	isHolding: boolean,
	holdProgress: number,
	onInteract: ((PromptData) -> ())?,

	Show: (self: InteractionPromptInstance, data: PromptData) -> (),
	Hide: (self: InteractionPromptInstance) -> (),
	StartHold: (self: InteractionPromptInstance) -> (),
	CancelHold: (self: InteractionPromptInstance) -> (),
	UpdateHoldProgress: (self: InteractionPromptInstance, progress: number) -> (),
	SetInteractCallback: (self: InteractionPromptInstance, callback: (PromptData) -> ()) -> (),
	Destroy: (self: InteractionPromptInstance) -> (),
}

--[[
	Create new interaction prompt
	@param parent Parent GUI element
	@param position UDim2 position
	@return InteractionPromptInstance
]]
function InteractionPrompt.new(parent: GuiObject, position: UDim2): InteractionPromptInstance
	local self = setmetatable({}, InteractionPrompt) :: any

	-- State
	self.currentData = nil
	self.isHolding = false
	self.holdProgress = 0
	self.onInteract = nil
	self.holdConnection = nil

	-- Main frame
	self.frame = Instance.new("Frame")
	self.frame.Name = "InteractionPrompt"
	self.frame.Position = position
	self.frame.Size = UDim2.fromOffset(PROMPT_WIDTH, PROMPT_HEIGHT)
	self.frame.AnchorPoint = Vector2.new(0.5, 1)
	self.frame.BackgroundColor3 = BACKGROUND_COLOR
	self.frame.BackgroundTransparency = 0.3
	self.frame.BorderSizePixel = 0
	self.frame.Visible = false
	self.frame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = self.frame

	-- Key indicator
	local keyFrame = Instance.new("Frame")
	keyFrame.Name = "KeyFrame"
	keyFrame.Position = UDim2.fromOffset(10, 10)
	keyFrame.Size = UDim2.fromOffset(30, 30)
	keyFrame.BackgroundColor3 = KEY_BACKGROUND
	keyFrame.BorderSizePixel = 0
	keyFrame.Parent = self.frame

	local keyCorner = Instance.new("UICorner")
	keyCorner.CornerRadius = UDim.new(0, 4)
	keyCorner.Parent = keyFrame

	local keyStroke = Instance.new("UIStroke")
	keyStroke.Color = Color3.fromRGB(100, 100, 100)
	keyStroke.Thickness = 1
	keyStroke.Parent = keyFrame

	self.keyLabel = Instance.new("TextLabel")
	self.keyLabel.Name = "Key"
	self.keyLabel.Size = UDim2.fromScale(1, 1)
	self.keyLabel.BackgroundTransparency = 1
	self.keyLabel.Text = "E"
	self.keyLabel.TextColor3 = TEXT_COLOR
	self.keyLabel.TextSize = 18
	self.keyLabel.Font = Enum.Font.GothamBold
	self.keyLabel.Parent = keyFrame

	-- Action text
	self.actionLabel = Instance.new("TextLabel")
	self.actionLabel.Name = "Action"
	self.actionLabel.Position = UDim2.fromOffset(50, 8)
	self.actionLabel.Size = UDim2.new(1, -60, 0, 16)
	self.actionLabel.BackgroundTransparency = 1
	self.actionLabel.Text = "Interact"
	self.actionLabel.TextColor3 = TEXT_COLOR
	self.actionLabel.TextSize = 14
	self.actionLabel.Font = Enum.Font.GothamBold
	self.actionLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.actionLabel.Parent = self.frame

	-- Object text
	self.objectLabel = Instance.new("TextLabel")
	self.objectLabel.Name = "Object"
	self.objectLabel.Position = UDim2.fromOffset(50, 26)
	self.objectLabel.Size = UDim2.new(1, -60, 0, 14)
	self.objectLabel.BackgroundTransparency = 1
	self.objectLabel.Text = "Object"
	self.objectLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	self.objectLabel.TextSize = 12
	self.objectLabel.Font = Enum.Font.Gotham
	self.objectLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.objectLabel.TextTruncate = Enum.TextTruncate.AtEnd
	self.objectLabel.Parent = self.frame

	-- Progress bar (for hold interactions)
	local progressBg = Instance.new("Frame")
	progressBg.Name = "ProgressBackground"
	progressBg.Position = UDim2.new(0, 10, 1, -(PROGRESS_HEIGHT + 5))
	progressBg.Size = UDim2.new(1, -20, 0, PROGRESS_HEIGHT)
	progressBg.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	progressBg.BorderSizePixel = 0
	progressBg.Visible = false
	progressBg.Parent = self.frame

	local progressBgCorner = Instance.new("UICorner")
	progressBgCorner.CornerRadius = UDim.new(0, 2)
	progressBgCorner.Parent = progressBg

	self.progressBar = Instance.new("Frame")
	self.progressBar.Name = "Progress"
	self.progressBar.Size = UDim2.fromScale(0, 1)
	self.progressBar.BackgroundColor3 = PROGRESS_COLOR
	self.progressBar.BorderSizePixel = 0
	self.progressBar.Parent = progressBg

	local progressBarCorner = Instance.new("UICorner")
	progressBarCorner.CornerRadius = UDim.new(0, 2)
	progressBarCorner.Parent = self.progressBar

	-- Rarity indicator
	local rarityBar = Instance.new("Frame")
	rarityBar.Name = "RarityBar"
	rarityBar.Position = UDim2.fromOffset(0, 0)
	rarityBar.Size = UDim2.new(1, 0, 0, 3)
	rarityBar.BackgroundColor3 = RARITY_COLORS.Common
	rarityBar.BorderSizePixel = 0
	rarityBar.Visible = false
	rarityBar.Parent = self.frame

	local rarityCorner = Instance.new("UICorner")
	rarityCorner.CornerRadius = UDim.new(0, 8)
	rarityCorner.Parent = rarityBar

	return self
end

--[[
	Show the prompt with data
]]
function InteractionPrompt:Show(data: PromptData)
	self.currentData = data

	-- Update key
	local keyCode = data.keyCode or Enum.KeyCode.E
	self.keyLabel.Text = UserInputService:GetStringForKeyCode(keyCode)

	-- Update text
	self.actionLabel.Text = data.actionText
	self.objectLabel.Text = data.objectText

	-- Update rarity
	local rarityBar = self.frame:FindFirstChild("RarityBar") :: Frame?
	if rarityBar then
		if data.rarity and RARITY_COLORS[data.rarity] then
			rarityBar.BackgroundColor3 = RARITY_COLORS[data.rarity]
			rarityBar.Visible = true
			self.objectLabel.TextColor3 = RARITY_COLORS[data.rarity]
		else
			rarityBar.Visible = false
			self.objectLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
		end
	end

	-- Show/hide progress bar
	local progressBg = self.progressBar.Parent :: Frame?
	if progressBg then
		progressBg.Visible = data.holdDuration ~= nil and data.holdDuration > 0
	end

	-- Animate in
	self.frame.Visible = true
	self.frame.BackgroundTransparency = 1
	TweenService:Create(self.frame, TweenInfo.new(FADE_DURATION), {
		BackgroundTransparency = 0.3,
	}):Play()
end

--[[
	Hide the prompt
]]
function InteractionPrompt:Hide()
	self:CancelHold()

	TweenService:Create(self.frame, TweenInfo.new(FADE_DURATION), {
		BackgroundTransparency = 1,
	}):Play()

	task.delay(FADE_DURATION, function()
		if not self.currentData then
			self.frame.Visible = false
		end
	end)

	self.currentData = nil
end

--[[
	Start hold interaction
]]
function InteractionPrompt:StartHold()
	if not self.currentData then
		return
	end

	local holdDuration = self.currentData.holdDuration
	if not holdDuration or holdDuration <= 0 then
		-- Instant interaction
		if self.onInteract and self.currentData then
			self.onInteract(self.currentData)
		end
		return
	end

	self.isHolding = true
	self.holdProgress = 0

	-- Progress animation
	local startTime = tick()
	local RunService = game:GetService("RunService")

	self.holdConnection = RunService.Heartbeat:Connect(function()
		if not self.isHolding then
			return
		end

		local elapsed = tick() - startTime
		self.holdProgress = math.clamp(elapsed / holdDuration, 0, 1)
		self:UpdateHoldProgress(self.holdProgress)

		if self.holdProgress >= 1 then
			self:CancelHold()
			if self.onInteract and self.currentData then
				self.onInteract(self.currentData)
			end
		end
	end)
end

--[[
	Cancel hold interaction
]]
function InteractionPrompt:CancelHold()
	self.isHolding = false
	self.holdProgress = 0

	if self.holdConnection then
		self.holdConnection:Disconnect()
		self.holdConnection = nil
	end

	self:UpdateHoldProgress(0)
end

--[[
	Update hold progress bar
]]
function InteractionPrompt:UpdateHoldProgress(progress: number)
	self.progressBar.Size = UDim2.fromScale(progress, 1)

	-- Color change as progress increases
	local color = PROGRESS_COLOR:Lerp(Color3.fromRGB(50, 255, 100), progress)
	self.progressBar.BackgroundColor3 = color
end

--[[
	Set interaction callback
]]
function InteractionPrompt:SetInteractCallback(callback: (PromptData) -> ())
	self.onInteract = callback
end

--[[
	Destroy the prompt
]]
function InteractionPrompt:Destroy()
	self:CancelHold()
	self.frame:Destroy()
end

return InteractionPrompt
