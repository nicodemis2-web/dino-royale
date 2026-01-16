--!strict
--[[
	TutorialHints.lua
	=================
	Contextual onboarding and tutorial system for Dino Royale.
	Shows hints at appropriate moments to guide new players.

	FEATURES:
	- Contextual hints based on player actions/state
	- Non-intrusive visual style
	- Priority system for hint importance
	- One-time hints that don't repeat
	- Timed hints for key moments
	- Input prompt overlays

	@client
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local TutorialHints = {}

--------------------------------------------------------------------------------
-- CONFIGURATION
--------------------------------------------------------------------------------

-- Hint definitions with triggers and conditions
local HINT_DEFINITIONS = {
	-- First spawn hints
	FirstSpawn = {
		title = "Welcome to Dino Royale!",
		message = "Survive against other players and dinosaurs. Be the last one standing!",
		icon = "rbxassetid://0", -- Would use actual asset
		duration = 8,
		priority = 10,
		showOnce = true,
	},

	-- Movement hints
	MovementControls = {
		title = "Movement",
		message = "Use WASD to move. Hold SHIFT to sprint. Press SPACE to jump.",
		keybinds = { "W", "A", "S", "D", "SHIFT", "SPACE" },
		duration = 6,
		priority = 9,
		showOnce = true,
		delay = 3,
	},

	CrouchHint = {
		title = "Crouch",
		message = "Press C to crouch. Crouching improves accuracy and makes you harder to spot.",
		keybinds = { "C" },
		duration = 5,
		priority = 5,
		showOnce = true,
	},

	-- Weapon hints
	WeaponPickup = {
		title = "Weapon Acquired!",
		message = "Press 1-5 to switch weapons. Click to fire.",
		keybinds = { "1", "2", "3", "4", "5", "LMB" },
		duration = 5,
		priority = 8,
		showOnce = true,
	},

	ReloadHint = {
		title = "Reload",
		message = "Press R to reload your weapon. Don't get caught empty!",
		keybinds = { "R" },
		duration = 4,
		priority = 6,
		showOnce = true,
	},

	AimDownSights = {
		title = "Aim Down Sights",
		message = "Hold RIGHT CLICK to aim for better accuracy.",
		keybinds = { "RMB" },
		duration = 4,
		priority = 5,
		showOnce = true,
	},

	-- Combat hints
	FirstDamage = {
		title = "You're Taking Damage!",
		message = "Find cover or eliminate the threat. Watch your health bar!",
		duration = 4,
		priority = 7,
		showOnce = true,
	},

	LowHealth = {
		title = "Low Health!",
		message = "Find healing items or play defensively. Your health is critical!",
		duration = 4,
		priority = 9,
		showOnce = true,
	},

	FirstKill = {
		title = "Elimination!",
		message = "Great shot! Check eliminated players for loot.",
		duration = 4,
		priority = 6,
		showOnce = true,
	},

	-- Dinosaur hints
	DinosaurNearby = {
		title = "Dinosaur Detected!",
		message = "Dinosaurs drop valuable loot but are dangerous. Choose wisely!",
		duration = 5,
		priority = 7,
		showOnce = true,
	},

	DinosaurTier = {
		title = "Dinosaur Tiers",
		message = "Legendary dinosaurs (gold glow) drop the best loot but are extremely dangerous!",
		duration = 6,
		priority = 5,
		showOnce = true,
	},

	-- Zone hints
	StormWarning = {
		title = "Storm Approaching!",
		message = "The safe zone is shrinking! Get inside the white circle on your map.",
		duration = 5,
		priority = 10,
		showOnce = false, -- Can repeat
	},

	StormDamage = {
		title = "Outside Safe Zone!",
		message = "You're taking storm damage! Move to the safe zone immediately!",
		duration = 4,
		priority = 10,
		showOnce = false,
	},

	-- Inventory hints
	InventoryFull = {
		title = "Inventory Full",
		message = "Press TAB to open inventory and drop items to make room.",
		keybinds = { "TAB" },
		duration = 4,
		priority = 5,
		showOnce = true,
	},

	-- Map hints
	MapHint = {
		title = "Map",
		message = "Press M to view the full map. See the safe zone and your position.",
		keybinds = { "M" },
		duration = 4,
		priority = 4,
		showOnce = true,
	},

	-- Victory/Defeat
	VictoryHint = {
		title = "VICTORY ROYALE!",
		message = "You are the last survivor! Congratulations!",
		duration = 10,
		priority = 10,
		showOnce = false,
	},
}

local COLORS = {
	Background = Color3.fromRGB(20, 25, 35),
	BackgroundBorder = Color3.fromRGB(80, 200, 120),
	Title = Color3.fromRGB(255, 255, 255),
	Message = Color3.fromRGB(200, 200, 200),
	Keybind = Color3.fromRGB(80, 200, 120),
	KeybindBg = Color3.fromRGB(40, 50, 60),
}

--------------------------------------------------------------------------------
-- TYPES
--------------------------------------------------------------------------------

type HintDefinition = {
	title: string,
	message: string,
	icon: string?,
	keybinds: { string }?,
	duration: number,
	priority: number,
	showOnce: boolean,
	delay: number?,
}

type ActiveHint = {
	id: string,
	definition: HintDefinition,
	frame: Frame,
	startTime: number,
	endTime: number,
}

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------

local localPlayer = Players.LocalPlayer
local playerGui: PlayerGui? = nil
local screenGui: ScreenGui? = nil
local hintContainer: Frame? = nil

local shownHints: { [string]: boolean } = {}
local activeHints: { ActiveHint } = {}
local hintQueue: { { id: string, definition: HintDefinition } } = {}

local isInitialized = false
local updateConnection: RBXScriptConnection? = nil

local MAX_VISIBLE_HINTS = 3

--------------------------------------------------------------------------------
-- UI CREATION
--------------------------------------------------------------------------------

--[[
	Create a keybind visual
]]
local function createKeybindVisual(parent: Frame, key: string): Frame
	local keyFrame = Instance.new("Frame")
	keyFrame.Name = "Key_" .. key
	keyFrame.Size = UDim2.new(0, 32, 0, 24)
	keyFrame.BackgroundColor3 = COLORS.KeybindBg
	keyFrame.BorderSizePixel = 0
	keyFrame.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = keyFrame

	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.Keybind
	stroke.Thickness = 1
	stroke.Parent = keyFrame

	local keyLabel = Instance.new("TextLabel")
	keyLabel.Name = "KeyLabel"
	keyLabel.Size = UDim2.fromScale(1, 1)
	keyLabel.BackgroundTransparency = 1
	keyLabel.Font = Enum.Font.GothamBold
	keyLabel.Text = key
	keyLabel.TextColor3 = COLORS.Keybind
	keyLabel.TextSize = 12
	keyLabel.Parent = keyFrame

	return keyFrame
end

--[[
	Create a hint frame
]]
local function createHintFrame(id: string, definition: HintDefinition): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Hint_" .. id
	frame.Size = UDim2.new(0.35, 0, 0, 0) -- Height will be set by UIListLayout
	frame.BackgroundColor3 = COLORS.Background
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.BackgroundBorder
	stroke.Thickness = 2
	stroke.Transparency = 0.5
	stroke.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.Padding = UDim.new(0, 8)
	layout.Parent = frame

	-- Title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0, 22)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Text = definition.title
	titleLabel.TextColor3 = COLORS.Title
	titleLabel.TextSize = 16
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.LayoutOrder = 1
	titleLabel.Parent = frame

	-- Message
	local messageLabel = Instance.new("TextLabel")
	messageLabel.Name = "Message"
	messageLabel.Size = UDim2.new(1, 0, 0, 36)
	messageLabel.BackgroundTransparency = 1
	messageLabel.Font = Enum.Font.Gotham
	messageLabel.Text = definition.message
	messageLabel.TextColor3 = COLORS.Message
	messageLabel.TextSize = 14
	messageLabel.TextXAlignment = Enum.TextXAlignment.Left
	messageLabel.TextYAlignment = Enum.TextYAlignment.Top
	messageLabel.TextWrapped = true
	messageLabel.LayoutOrder = 2
	messageLabel.Parent = frame

	-- Keybinds (if any)
	if definition.keybinds and #definition.keybinds > 0 then
		local keybindContainer = Instance.new("Frame")
		keybindContainer.Name = "Keybinds"
		keybindContainer.Size = UDim2.new(1, 0, 0, 28)
		keybindContainer.BackgroundTransparency = 1
		keybindContainer.LayoutOrder = 3
		keybindContainer.Parent = frame

		local keybindLayout = Instance.new("UIListLayout")
		keybindLayout.FillDirection = Enum.FillDirection.Horizontal
		keybindLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		keybindLayout.Padding = UDim.new(0, 6)
		keybindLayout.Parent = keybindContainer

		for _, key in definition.keybinds do
			createKeybindVisual(keybindContainer, key)
		end
	end

	-- Progress bar (time remaining)
	local progressBar = Instance.new("Frame")
	progressBar.Name = "ProgressBar"
	progressBar.Size = UDim2.new(1, 0, 0, 3)
	progressBar.BackgroundColor3 = COLORS.KeybindBg
	progressBar.BorderSizePixel = 0
	progressBar.LayoutOrder = 4
	progressBar.Parent = frame

	local progressCorner = Instance.new("UICorner")
	progressCorner.CornerRadius = UDim.new(0, 2)
	progressCorner.Parent = progressBar

	local progressFill = Instance.new("Frame")
	progressFill.Name = "Fill"
	progressFill.Size = UDim2.fromScale(1, 1)
	progressFill.BackgroundColor3 = COLORS.BackgroundBorder
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressBar

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 2)
	fillCorner.Parent = progressFill

	-- Set auto size
	frame.AutomaticSize = Enum.AutomaticSize.Y

	return frame
end

--[[
	Create the main hint container GUI
]]
local function createHintGui()
	playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TutorialHints"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 90
	screenGui.Parent = playerGui

	-- Hint container (top-right positioning)
	hintContainer = Instance.new("Frame")
	hintContainer.Name = "HintContainer"
	hintContainer.Size = UDim2.new(0.35, 0, 1, 0)
	hintContainer.Position = UDim2.new(1, -20, 0, 100)
	hintContainer.AnchorPoint = Vector2.new(1, 0)
	hintContainer.BackgroundTransparency = 1
	hintContainer.Parent = screenGui

	local containerLayout = Instance.new("UIListLayout")
	containerLayout.FillDirection = Enum.FillDirection.Vertical
	containerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	containerLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	containerLayout.Padding = UDim.new(0, 10)
	containerLayout.Parent = hintContainer
end

--------------------------------------------------------------------------------
-- HINT MANAGEMENT
--------------------------------------------------------------------------------

--[[
	Show a hint with animation
]]
local function showHint(id: string, definition: HintDefinition)
	if not hintContainer then return end

	-- Check if already visible
	for _, hint in activeHints do
		if hint.id == id then return end
	end

	-- Limit visible hints
	if #activeHints >= MAX_VISIBLE_HINTS then
		-- Queue the hint instead
		table.insert(hintQueue, { id = id, definition = definition })
		return
	end

	local frame = createHintFrame(id, definition)
	frame.Parent = hintContainer

	-- Initial state (invisible, offset)
	frame.Position = frame.Position + UDim2.new(0, 50, 0, 0)
	frame.BackgroundTransparency = 1
	for _, child in frame:GetDescendants() do
		if child:IsA("TextLabel") then
			child.TextTransparency = 1
		elseif child:IsA("Frame") then
			child.BackgroundTransparency = 1
		elseif child:IsA("UIStroke") then
			child.Transparency = 1
		end
	end

	-- Animate in
	local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	TweenService:Create(frame, tweenInfo, {
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 0.1,
	}):Play()

	for _, child in frame:GetDescendants() do
		if child:IsA("TextLabel") then
			TweenService:Create(child, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
		elseif child:IsA("Frame") and child.Name ~= "ProgressBar" then
			TweenService:Create(child, TweenInfo.new(0.3), { BackgroundTransparency = 0 }):Play()
		elseif child:IsA("UIStroke") then
			TweenService:Create(child, TweenInfo.new(0.3), { Transparency = 0.5 }):Play()
		end
	end

	local activeHint: ActiveHint = {
		id = id,
		definition = definition,
		frame = frame,
		startTime = tick(),
		endTime = tick() + definition.duration,
	}

	table.insert(activeHints, activeHint)

	-- Mark as shown if showOnce
	if definition.showOnce then
		shownHints[id] = true
	end
end

--[[
	Hide a hint with animation
]]
local function hideHint(hint: ActiveHint)
	local frame = hint.frame

	-- Animate out
	local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

	TweenService:Create(frame, tweenInfo, {
		Position = frame.Position + UDim2.new(0, 50, 0, 0),
		BackgroundTransparency = 1,
	}):Play()

	for _, child in frame:GetDescendants() do
		if child:IsA("TextLabel") then
			TweenService:Create(child, TweenInfo.new(0.2), { TextTransparency = 1 }):Play()
		elseif child:IsA("Frame") then
			TweenService:Create(child, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
		elseif child:IsA("UIStroke") then
			TweenService:Create(child, TweenInfo.new(0.2), { Transparency = 1 }):Play()
		end
	end

	-- Remove after animation
	task.delay(0.25, function()
		if frame and frame.Parent then
			frame:Destroy()
		end
	end)
end

--[[
	Update loop for hint timers
]]
local function onUpdate(deltaTime: number)
	local currentTime = tick()

	-- Update active hints
	local i = 1
	while i <= #activeHints do
		local hint = activeHints[i]

		-- Update progress bar
		local progressFill = hint.frame:FindFirstChild("ProgressBar")
		if progressFill then
			progressFill = progressFill:FindFirstChild("Fill")
			if progressFill then
				local elapsed = currentTime - hint.startTime
				local total = hint.definition.duration
				local remaining = 1 - (elapsed / total)
				(progressFill :: Frame).Size = UDim2.new(math.clamp(remaining, 0, 1), 0, 1, 0)
			end
		end

		-- Check if expired
		if currentTime >= hint.endTime then
			hideHint(hint)
			table.remove(activeHints, i)
		else
			i += 1
		end
	end

	-- Process queue
	if #hintQueue > 0 and #activeHints < MAX_VISIBLE_HINTS then
		local queued = table.remove(hintQueue, 1)
		if queued then
			showHint(queued.id, queued.definition)
		end
	end
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

--[[
	Initialize the tutorial hints system
]]
function TutorialHints.Initialize()
	if isInitialized then return end

	createHintGui()

	updateConnection = RunService.RenderStepped:Connect(onUpdate)

	isInitialized = true
	print("[TutorialHints] Initialized")
end

--[[
	Trigger a hint by ID
]]
function TutorialHints.TriggerHint(hintId: string)
	local definition = HINT_DEFINITIONS[hintId]
	if not definition then
		warn(`[TutorialHints] Unknown hint: {hintId}`)
		return
	end

	-- Check if already shown (for showOnce hints)
	if definition.showOnce and shownHints[hintId] then
		return
	end

	-- Apply delay if specified
	if definition.delay and definition.delay > 0 then
		task.delay(definition.delay, function()
			if definition.showOnce and shownHints[hintId] then return end
			showHint(hintId, definition)
		end)
	else
		showHint(hintId, definition)
	end
end

--[[
	Show a custom hint (not from definitions)
]]
function TutorialHints.ShowCustomHint(title: string, message: string, duration: number?, keybinds: { string }?)
	local customDef: HintDefinition = {
		title = title,
		message = message,
		keybinds = keybinds,
		duration = duration or 5,
		priority = 5,
		showOnce = false,
	}

	local customId = "Custom_" .. tostring(tick())
	showHint(customId, customDef)
end

--[[
	Dismiss all active hints
]]
function TutorialHints.DismissAll()
	for _, hint in activeHints do
		hideHint(hint)
	end
	activeHints = {}
	hintQueue = {}
end

--[[
	Dismiss a specific hint
]]
function TutorialHints.DismissHint(hintId: string)
	for i, hint in activeHints do
		if hint.id == hintId then
			hideHint(hint)
			table.remove(activeHints, i)
			return
		end
	end
end

--[[
	Reset shown hints (for new game)
]]
function TutorialHints.ResetShownHints()
	shownHints = {}
end

--[[
	Check if a hint has been shown
]]
function TutorialHints.HasShownHint(hintId: string): boolean
	return shownHints[hintId] == true
end

--[[
	Mark a hint as shown (without displaying it)
]]
function TutorialHints.MarkAsShown(hintId: string)
	shownHints[hintId] = true
end

--[[
	Get list of all hint IDs
]]
function TutorialHints.GetHintIds(): { string }
	local ids = {}
	for id in HINT_DEFINITIONS do
		table.insert(ids, id)
	end
	return ids
end

--[[
	Cleanup
]]
function TutorialHints.Cleanup()
	if updateConnection then
		updateConnection:Disconnect()
		updateConnection = nil
	end

	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end

	activeHints = {}
	hintQueue = {}
	isInitialized = false
end

return TutorialHints
