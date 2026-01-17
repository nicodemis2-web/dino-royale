--!strict
--[[
	KillFeed.lua
	============
	Displays recent eliminations and events
	Shows killer, victim, weapon/cause
]]

local TweenService = game:GetService("TweenService")

local KillFeed = {}
KillFeed.__index = KillFeed

-- Display settings
local MAX_ENTRIES = 6
local ENTRY_HEIGHT = 24
local ENTRY_SPACING = 4
local ENTRY_DURATION = 5
local FADE_DURATION = 0.5
local DISPLAY_WIDTH = 350

-- Colors
local BACKGROUND_COLOR = Color3.fromRGB(0, 0, 0)
local KILLER_COLOR = Color3.new(1, 1, 1)
local VICTIM_COLOR = Color3.new(1, 1, 1)
local LOCAL_PLAYER_COLOR = Color3.fromRGB(255, 200, 50) -- Highlight local player
local DINOSAUR_COLOR = Color3.fromRGB(255, 100, 50)
local STORM_COLOR = Color3.fromRGB(150, 50, 255)

-- Kill icons (placeholders)
local KILL_ICONS = {
	Headshot = "rbxassetid://0",
	Melee = "rbxassetid://0",
	Explosion = "rbxassetid://0",
	Dinosaur = "rbxassetid://0",
	Storm = "rbxassetid://0",
	Vehicle = "rbxassetid://0",
	Default = "rbxassetid://0",
}

export type KillEntry = {
	killerName: string,
	killerId: number?,
	victimName: string,
	victimId: number?,
	weapon: string?,
	killType: string?,
	isLocalKiller: boolean?,
	isLocalVictim: boolean?,
}

export type KillFeedInstance = {
	frame: Frame,
	entries: { Frame },
	localPlayerId: number,

	AddKill: (self: KillFeedInstance, entry: KillEntry) -> (),
	AddDinosaurKill: (self: KillFeedInstance, dinoName: string, victimName: string, victimId: number?) -> (),
	AddStormKill: (self: KillFeedInstance, victimName: string, victimId: number?) -> (),
	AddEvent: (self: KillFeedInstance, message: string, color: Color3?) -> (),
	Clear: (self: KillFeedInstance) -> (),
	Destroy: (self: KillFeedInstance) -> (),
}

--[[
	Create a new kill feed
	@param parent Parent GUI element
	@param position UDim2 position
	@param localPlayerId Local player's UserId
	@return KillFeedInstance
]]
function KillFeed.new(parent: GuiObject, position: UDim2, localPlayerId: number): KillFeedInstance
	local self = setmetatable({}, KillFeed) :: any

	-- State
	self.entries = {}
	self.localPlayerId = localPlayerId

	-- Main frame
	self.frame = Instance.new("Frame")
	self.frame.Name = "KillFeed"
	self.frame.Position = position
	self.frame.Size = UDim2.fromOffset(DISPLAY_WIDTH, (ENTRY_HEIGHT + ENTRY_SPACING) * MAX_ENTRIES)
	self.frame.BackgroundTransparency = 1
	self.frame.Parent = parent

	return self
end

--[[
	Create a kill feed entry
]]
function KillFeed:CreateEntry(content: GuiObject): Frame
	local entry = Instance.new("Frame")
	entry.Name = "Entry"
	entry.Size = UDim2.new(1, 0, 0, ENTRY_HEIGHT)
	entry.BackgroundColor3 = BACKGROUND_COLOR
	entry.BackgroundTransparency = 0.5
	entry.BorderSizePixel = 0
	entry.Parent = self.frame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = entry

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = entry

	-- Add content
	content.Parent = entry

	return entry
end

--[[
	Add entry to feed and manage overflow
]]
function KillFeed:PushEntry(entry: Frame)
	-- Move existing entries down
	for i, existingEntry in ipairs(self.entries) do
		local targetY = (i) * (ENTRY_HEIGHT + ENTRY_SPACING)
		TweenService:Create(existingEntry, TweenInfo.new(0.2), {
			Position = UDim2.fromOffset(0, targetY),
		}):Play()
	end

	-- Insert new entry at top
	entry.Position = UDim2.fromOffset(0, -ENTRY_HEIGHT)
	TweenService:Create(entry, TweenInfo.new(0.2), {
		Position = UDim2.fromOffset(0, 0),
	}):Play()

	table.insert(self.entries, 1, entry)

	-- Remove overflow
	while #self.entries > MAX_ENTRIES do
		local oldEntry = table.remove(self.entries)
		if oldEntry then
			oldEntry:Destroy()
		end
	end

	-- Schedule removal
	task.delay(ENTRY_DURATION, function()
		self:FadeOutEntry(entry)
	end)
end

--[[
	Fade out and remove entry
]]
function KillFeed:FadeOutEntry(entry: Frame)
	-- Check if entry still exists in list
	local index = table.find(self.entries, entry)
	if not index then
		return
	end

	-- Fade out
	local tween = TweenService:Create(entry, TweenInfo.new(FADE_DURATION), {
		BackgroundTransparency = 1,
	})

	-- Fade children
	for _, child in ipairs(entry:GetDescendants()) do
		if child:IsA("TextLabel") then
			TweenService:Create(child, TweenInfo.new(FADE_DURATION), {
				TextTransparency = 1,
			}):Play()
		elseif child:IsA("ImageLabel") then
			TweenService:Create(child, TweenInfo.new(FADE_DURATION), {
				ImageTransparency = 1,
			}):Play()
		end
	end

	tween:Play()
	tween.Completed:Connect(function()
		local currentIndex = table.find(self.entries, entry)
		if currentIndex then
			table.remove(self.entries, currentIndex)
		end
		entry:Destroy()

		-- Shift remaining entries up
		for i, e in ipairs(self.entries) do
			TweenService:Create(e, TweenInfo.new(0.2), {
				Position = UDim2.fromOffset(0, (i - 1) * (ENTRY_HEIGHT + ENTRY_SPACING)),
			}):Play()
		end
	end)
end

--[[
	Add a kill to the feed
]]
function KillFeed:AddKill(entryData: KillEntry)
	-- Create content container
	local content = Instance.new("Frame")
	content.Size = UDim2.fromScale(1, 1)
	content.BackgroundTransparency = 1

	-- Killer name
	local killerLabel = Instance.new("TextLabel")
	killerLabel.Position = UDim2.fromOffset(0, 0)
	killerLabel.Size = UDim2.fromScale(0.4, 1)
	killerLabel.BackgroundTransparency = 1
	killerLabel.Text = entryData.killerName
	killerLabel.TextXAlignment = Enum.TextXAlignment.Right
	killerLabel.TextSize = 14
	killerLabel.Font = Enum.Font.GothamBold
	killerLabel.TextTruncate = Enum.TextTruncate.AtEnd
	killerLabel.Parent = content

	-- Highlight local player
	if entryData.isLocalKiller then
		killerLabel.TextColor3 = LOCAL_PLAYER_COLOR
	else
		killerLabel.TextColor3 = KILLER_COLOR
	end

	-- Kill icon
	local killIcon = Instance.new("ImageLabel")
	killIcon.Position = UDim2.new(0.4, 5, 0.5, 0)
	killIcon.Size = UDim2.fromOffset(16, 16)
	killIcon.AnchorPoint = Vector2.new(0, 0.5)
	killIcon.BackgroundTransparency = 1
	killIcon.Image = KILL_ICONS[entryData.killType or "Default"] or KILL_ICONS.Default
	killIcon.ImageColor3 = Color3.new(1, 1, 1)
	killIcon.Parent = content

	-- Weapon name (small)
	local weaponLabel = Instance.new("TextLabel")
	weaponLabel.Position = UDim2.new(0.4, 25, 0.5, 0)
	weaponLabel.Size = UDim2.fromScale(0.15, 0.8)
	weaponLabel.AnchorPoint = Vector2.new(0, 0.5)
	weaponLabel.BackgroundTransparency = 1
	weaponLabel.Text = entryData.weapon or ""
	weaponLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	weaponLabel.TextSize = 10
	weaponLabel.Font = Enum.Font.Gotham
	weaponLabel.TextTruncate = Enum.TextTruncate.AtEnd
	weaponLabel.Parent = content

	-- Victim name
	local victimLabel = Instance.new("TextLabel")
	victimLabel.Position = UDim2.fromScale(0.6, 0)
	victimLabel.Size = UDim2.fromScale(0.4, 1)
	victimLabel.BackgroundTransparency = 1
	victimLabel.Text = entryData.victimName
	victimLabel.TextXAlignment = Enum.TextXAlignment.Left
	victimLabel.TextSize = 14
	victimLabel.Font = Enum.Font.GothamBold
	victimLabel.TextTruncate = Enum.TextTruncate.AtEnd
	victimLabel.Parent = content

	-- Highlight local player
	if entryData.isLocalVictim then
		victimLabel.TextColor3 = LOCAL_PLAYER_COLOR
	else
		victimLabel.TextColor3 = VICTIM_COLOR
	end

	local entry = self:CreateEntry(content)
	self:PushEntry(entry)
end

--[[
	Add dinosaur kill to feed
]]
function KillFeed:AddDinosaurKill(dinoName: string, victimName: string, victimId: number?)
	local content = Instance.new("Frame")
	content.Size = UDim2.fromScale(1, 1)
	content.BackgroundTransparency = 1

	-- Dino name
	local dinoLabel = Instance.new("TextLabel")
	dinoLabel.Position = UDim2.fromOffset(0, 0)
	dinoLabel.Size = UDim2.fromScale(0.4, 1)
	dinoLabel.BackgroundTransparency = 1
	dinoLabel.Text = dinoName
	dinoLabel.TextColor3 = DINOSAUR_COLOR
	dinoLabel.TextXAlignment = Enum.TextXAlignment.Right
	dinoLabel.TextSize = 14
	dinoLabel.Font = Enum.Font.GothamBold
	dinoLabel.Parent = content

	-- Dino icon
	local dinoIcon = Instance.new("ImageLabel")
	dinoIcon.Position = UDim2.new(0.4, 5, 0.5, 0)
	dinoIcon.Size = UDim2.fromOffset(16, 16)
	dinoIcon.AnchorPoint = Vector2.new(0, 0.5)
	dinoIcon.BackgroundTransparency = 1
	dinoIcon.Image = KILL_ICONS.Dinosaur
	dinoIcon.ImageColor3 = DINOSAUR_COLOR
	dinoIcon.Parent = content

	-- Victim name
	local victimLabel = Instance.new("TextLabel")
	victimLabel.Position = UDim2.fromScale(0.5, 0)
	victimLabel.Size = UDim2.fromScale(0.5, 1)
	victimLabel.BackgroundTransparency = 1
	victimLabel.Text = victimName
	victimLabel.TextXAlignment = Enum.TextXAlignment.Left
	victimLabel.TextSize = 14
	victimLabel.Font = Enum.Font.GothamBold
	victimLabel.Parent = content

	if victimId == self.localPlayerId then
		victimLabel.TextColor3 = LOCAL_PLAYER_COLOR
	else
		victimLabel.TextColor3 = VICTIM_COLOR
	end

	local entry = self:CreateEntry(content)
	self:PushEntry(entry)
end

--[[
	Add storm kill to feed
]]
function KillFeed:AddStormKill(victimName: string, victimId: number?)
	local content = Instance.new("Frame")
	content.Size = UDim2.fromScale(1, 1)
	content.BackgroundTransparency = 1

	-- Storm label
	local stormLabel = Instance.new("TextLabel")
	stormLabel.Position = UDim2.fromOffset(0, 0)
	stormLabel.Size = UDim2.fromScale(0.5, 1)
	stormLabel.BackgroundTransparency = 1
	stormLabel.Text = "Extinction Wave"
	stormLabel.TextColor3 = STORM_COLOR
	stormLabel.TextXAlignment = Enum.TextXAlignment.Right
	stormLabel.TextSize = 14
	stormLabel.Font = Enum.Font.GothamBold
	stormLabel.Parent = content

	-- Victim name
	local victimLabel = Instance.new("TextLabel")
	victimLabel.Position = UDim2.fromScale(0.55, 0)
	victimLabel.Size = UDim2.fromScale(0.45, 1)
	victimLabel.BackgroundTransparency = 1
	victimLabel.Text = victimName
	victimLabel.TextXAlignment = Enum.TextXAlignment.Left
	victimLabel.TextSize = 14
	victimLabel.Font = Enum.Font.GothamBold
	victimLabel.Parent = content

	if victimId == self.localPlayerId then
		victimLabel.TextColor3 = LOCAL_PLAYER_COLOR
	else
		victimLabel.TextColor3 = VICTIM_COLOR
	end

	local entry = self:CreateEntry(content)
	self:PushEntry(entry)
end

--[[
	Add generic event message
]]
function KillFeed:AddEvent(message: string, color: Color3?)
	local content = Instance.new("Frame")
	content.Size = UDim2.fromScale(1, 1)
	content.BackgroundTransparency = 1

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = message
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextSize = 14
	label.Font = Enum.Font.GothamBold
	label.Parent = content

	local entry = self:CreateEntry(content)
	self:PushEntry(entry)
end

--[[
	Clear all entries
]]
function KillFeed:Clear()
	for _, entry in ipairs(self.entries) do
		entry:Destroy()
	end
	self.entries = {}
end

--[[
	Destroy the kill feed
]]
function KillFeed:Destroy()
	self:Clear()
	self.frame:Destroy()
end

return KillFeed
