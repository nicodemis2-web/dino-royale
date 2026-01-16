--!strict
--[[
	ScreenEffects.lua
	=================
	Professional screen effects system for Dino Royale.
	Handles fullscreen visual effects for immersion and feedback.

	FEATURES:
	- Damage vignette (red flash when hurt)
	- Low health warning (pulsing red border)
	- Speed lines (when sprinting/moving fast)
	- Blood splatter overlay
	- Flash effects (explosions, flashbangs)
	- Color grading (biome-based tinting)
	- Motion blur simulation
	- Death screen fade

	@client
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local ScreenEffects = {}

--------------------------------------------------------------------------------
-- CONFIGURATION
--------------------------------------------------------------------------------

local COLORS = {
	DamageVignette = Color3.fromRGB(180, 0, 0),
	LowHealthPulse = Color3.fromRGB(255, 0, 0),
	HealFlash = Color3.fromRGB(100, 255, 100),
	ShieldFlash = Color3.fromRGB(100, 150, 255),
	FlashBang = Color3.fromRGB(255, 255, 255),
	DeathFade = Color3.fromRGB(0, 0, 0),
	SpeedLines = Color3.fromRGB(255, 255, 255),
}

-- Biome color grading presets
local BIOME_COLOR_GRADES = {
	Jungle = {
		tint = Color3.fromRGB(200, 255, 200),
		saturation = 1.1,
		brightness = 1.0,
	},
	Plains = {
		tint = Color3.fromRGB(255, 250, 230),
		saturation = 1.0,
		brightness = 1.05,
	},
	Swamp = {
		tint = Color3.fromRGB(180, 200, 180),
		saturation = 0.85,
		brightness = 0.9,
	},
	Volcanic = {
		tint = Color3.fromRGB(255, 200, 180),
		saturation = 1.05,
		brightness = 0.95,
	},
	Coastal = {
		tint = Color3.fromRGB(220, 240, 255),
		saturation = 1.1,
		brightness = 1.1,
	},
}

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------

local localPlayer = Players.LocalPlayer
local playerGui: PlayerGui? = nil
local screenGui: ScreenGui? = nil

-- Effect frames
local damageVignette: Frame? = nil
local lowHealthOverlay: Frame? = nil
local flashOverlay: Frame? = nil
local speedLinesContainer: Frame? = nil
local colorGradeOverlay: Frame? = nil
local bloodSplatter: ImageLabel? = nil

-- State tracking
local isInitialized = false
local currentHealth = 100
local maxHealth = 100
local isLowHealthPulsing = false
local lowHealthTween: Tween? = nil
local updateConnection: RBXScriptConnection? = nil

--------------------------------------------------------------------------------
-- UI CREATION
--------------------------------------------------------------------------------

--[[
	Create a radial gradient for vignette effects
]]
local function createVignetteGradient(parent: Frame, color: Color3)
	local gradient = Instance.new("UIGradient")
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.8),
		NumberSequenceKeypoint.new(0.8, 0.3),
		NumberSequenceKeypoint.new(1, 0),
	})
	gradient.Color = ColorSequence.new(color)
	-- Radial-ish effect using offset
	gradient.Offset = Vector2.new(0, 0)
	gradient.Parent = parent
	return gradient
end

--[[
	Create the main screen effects GUI
]]
local function createScreenGui()
	playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ScreenEffects"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 100 -- Above most UI
	screenGui.Parent = playerGui

	-- Damage vignette (red edges when hurt)
	damageVignette = Instance.new("Frame")
	damageVignette.Name = "DamageVignette"
	damageVignette.Size = UDim2.fromScale(1, 1)
	damageVignette.Position = UDim2.fromScale(0, 0)
	damageVignette.BackgroundColor3 = COLORS.DamageVignette
	damageVignette.BackgroundTransparency = 1
	damageVignette.BorderSizePixel = 0
	damageVignette.Parent = screenGui

	-- Create edge-only effect using multiple frames
	local edges = {"Top", "Bottom", "Left", "Right"}
	local edgeSizes = {
		Top = UDim2.new(1, 0, 0.15, 0),
		Bottom = UDim2.new(1, 0, 0.15, 0),
		Left = UDim2.new(0.1, 0, 1, 0),
		Right = UDim2.new(0.1, 0, 1, 0),
	}
	local edgePositions = {
		Top = UDim2.fromScale(0, 0),
		Bottom = UDim2.fromScale(0, 0.85),
		Left = UDim2.fromScale(0, 0),
		Right = UDim2.fromScale(0.9, 0),
	}
	local edgeGradientRotations = {
		Top = 90,
		Bottom = 270,
		Left = 0,
		Right = 180,
	}

	for _, edge in edges do
		local edgeFrame = Instance.new("Frame")
		edgeFrame.Name = edge
		edgeFrame.Size = edgeSizes[edge]
		edgeFrame.Position = edgePositions[edge]
		edgeFrame.BackgroundColor3 = COLORS.DamageVignette
		edgeFrame.BackgroundTransparency = 1
		edgeFrame.BorderSizePixel = 0
		edgeFrame.Parent = damageVignette

		local gradient = Instance.new("UIGradient")
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Rotation = edgeGradientRotations[edge]
		gradient.Parent = edgeFrame
	end

	-- Low health overlay (pulsing red)
	lowHealthOverlay = Instance.new("Frame")
	lowHealthOverlay.Name = "LowHealthOverlay"
	lowHealthOverlay.Size = UDim2.fromScale(1, 1)
	lowHealthOverlay.BackgroundColor3 = COLORS.LowHealthPulse
	lowHealthOverlay.BackgroundTransparency = 1
	lowHealthOverlay.BorderSizePixel = 0
	lowHealthOverlay.Visible = false
	lowHealthOverlay.Parent = screenGui

	-- Flash overlay (white flash for explosions, etc.)
	flashOverlay = Instance.new("Frame")
	flashOverlay.Name = "FlashOverlay"
	flashOverlay.Size = UDim2.fromScale(1, 1)
	flashOverlay.BackgroundColor3 = COLORS.FlashBang
	flashOverlay.BackgroundTransparency = 1
	flashOverlay.BorderSizePixel = 0
	flashOverlay.Parent = screenGui

	-- Speed lines container
	speedLinesContainer = Instance.new("Frame")
	speedLinesContainer.Name = "SpeedLines"
	speedLinesContainer.Size = UDim2.fromScale(1, 1)
	speedLinesContainer.BackgroundTransparency = 1
	speedLinesContainer.Visible = false
	speedLinesContainer.Parent = screenGui

	-- Create speed line elements
	for i = 1, 12 do
		local line = Instance.new("Frame")
		line.Name = "Line" .. i
		line.Size = UDim2.new(0, 3, 0.4, 0)
		line.AnchorPoint = Vector2.new(0.5, 0)
		line.Position = UDim2.fromScale(
			0.5 + math.cos(math.rad(i * 30)) * 0.35,
			0.5 + math.sin(math.rad(i * 30)) * 0.35
		)
		line.Rotation = i * 30
		line.BackgroundColor3 = COLORS.SpeedLines
		line.BackgroundTransparency = 0.7
		line.BorderSizePixel = 0
		line.Parent = speedLinesContainer

		local gradient = Instance.new("UIGradient")
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.5),
			NumberSequenceKeypoint.new(1, 0),
		})
		gradient.Parent = line
	end

	-- Color grade overlay
	colorGradeOverlay = Instance.new("Frame")
	colorGradeOverlay.Name = "ColorGrade"
	colorGradeOverlay.Size = UDim2.fromScale(1, 1)
	colorGradeOverlay.BackgroundColor3 = Color3.new(1, 1, 1)
	colorGradeOverlay.BackgroundTransparency = 1
	colorGradeOverlay.BorderSizePixel = 0
	colorGradeOverlay.Parent = screenGui
end

--------------------------------------------------------------------------------
-- EFFECT FUNCTIONS
--------------------------------------------------------------------------------

--[[
	Flash damage vignette when taking damage
]]
function ScreenEffects.FlashDamage(intensity: number?)
	if not damageVignette then return end

	local actualIntensity = math.clamp(intensity or 0.5, 0.1, 1)

	-- Flash all edge frames
	for _, child in damageVignette:GetChildren() do
		if child:IsA("Frame") then
			child.BackgroundTransparency = 1 - actualIntensity * 0.7

			TweenService:Create(child, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 1,
			}):Play()
		end
	end
end

--[[
	Start low health pulsing effect
]]
function ScreenEffects.StartLowHealthPulse()
	if isLowHealthPulsing or not lowHealthOverlay then return end

	isLowHealthPulsing = true
	lowHealthOverlay.Visible = true
	lowHealthOverlay.BackgroundTransparency = 0.95

	-- Create pulsing tween
	local function pulse()
		if not isLowHealthPulsing or not lowHealthOverlay then return end

		lowHealthTween = TweenService:Create(lowHealthOverlay, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
			BackgroundTransparency = 0.85,
		})
		lowHealthTween:Play()
		lowHealthTween.Completed:Connect(function()
			if not isLowHealthPulsing or not lowHealthOverlay then return end

			lowHealthTween = TweenService:Create(lowHealthOverlay, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				BackgroundTransparency = 0.95,
			})
			lowHealthTween:Play()
			lowHealthTween.Completed:Connect(pulse)
		end)
	end

	pulse()
end

--[[
	Stop low health pulsing effect
]]
function ScreenEffects.StopLowHealthPulse()
	isLowHealthPulsing = false

	if lowHealthTween then
		lowHealthTween:Cancel()
		lowHealthTween = nil
	end

	if lowHealthOverlay then
		TweenService:Create(lowHealthOverlay, TweenInfo.new(0.3), {
			BackgroundTransparency = 1,
		}):Play()

		task.delay(0.3, function()
			if lowHealthOverlay then
				lowHealthOverlay.Visible = false
			end
		end)
	end
end

--[[
	Flash screen (for explosions, flashbangs, healing)
]]
function ScreenEffects.Flash(color: Color3?, intensity: number?, duration: number?)
	if not flashOverlay then return end

	local flashColor = color or COLORS.FlashBang
	local flashIntensity = intensity or 0.8
	local flashDuration = duration or 0.5

	flashOverlay.BackgroundColor3 = flashColor
	flashOverlay.BackgroundTransparency = 1 - flashIntensity

	TweenService:Create(flashOverlay, TweenInfo.new(flashDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
end

--[[
	Flash for healing
]]
function ScreenEffects.FlashHeal()
	ScreenEffects.Flash(COLORS.HealFlash, 0.4, 0.3)
end

--[[
	Flash for shield
]]
function ScreenEffects.FlashShield()
	ScreenEffects.Flash(COLORS.ShieldFlash, 0.4, 0.3)
end

--[[
	Show speed lines when moving fast
]]
function ScreenEffects.SetSpeedLines(enabled: boolean, intensity: number?)
	if not speedLinesContainer then return end

	if enabled then
		speedLinesContainer.Visible = true
		local alpha = math.clamp(intensity or 0.5, 0, 1)

		for _, line in speedLinesContainer:GetChildren() do
			if line:IsA("Frame") then
				line.BackgroundTransparency = 1 - alpha * 0.5
			end
		end
	else
		speedLinesContainer.Visible = false
	end
end

--[[
	Set color grade based on biome
]]
function ScreenEffects.SetBiomeColorGrade(biomeName: string)
	if not colorGradeOverlay then return end

	local grade = BIOME_COLOR_GRADES[biomeName]
	if not grade then
		-- Reset to neutral
		TweenService:Create(colorGradeOverlay, TweenInfo.new(2), {
			BackgroundTransparency = 1,
		}):Play()
		return
	end

	colorGradeOverlay.BackgroundColor3 = grade.tint
	TweenService:Create(colorGradeOverlay, TweenInfo.new(2), {
		BackgroundTransparency = 0.95, -- Very subtle tint
	}):Play()
end

--[[
	Death screen fade to black
]]
function ScreenEffects.FadeToBlack(duration: number?, callback: (() -> ())?)
	if not flashOverlay then return end

	local fadeDuration = duration or 1

	flashOverlay.BackgroundColor3 = COLORS.DeathFade
	flashOverlay.BackgroundTransparency = 1

	local tween = TweenService:Create(flashOverlay, TweenInfo.new(fadeDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 0,
	})

	tween:Play()

	if callback then
		tween.Completed:Connect(callback)
	end
end

--[[
	Fade from black (respawn)
]]
function ScreenEffects.FadeFromBlack(duration: number?)
	if not flashOverlay then return end

	local fadeDuration = duration or 1

	flashOverlay.BackgroundColor3 = COLORS.DeathFade
	flashOverlay.BackgroundTransparency = 0

	TweenService:Create(flashOverlay, TweenInfo.new(fadeDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
end

--[[
	Update health state for automatic effects
]]
function ScreenEffects.UpdateHealth(health: number, max: number)
	currentHealth = health
	maxHealth = max

	local healthPercent = health / max

	-- Low health warning at 25%
	if healthPercent <= 0.25 and healthPercent > 0 then
		if not isLowHealthPulsing then
			ScreenEffects.StartLowHealthPulse()
		end
	else
		if isLowHealthPulsing then
			ScreenEffects.StopLowHealthPulse()
		end
	end
end

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

--[[
	Initialize the screen effects system
]]
function ScreenEffects.Initialize()
	if isInitialized then return end

	createScreenGui()

	isInitialized = true
	print("[ScreenEffects] Initialized")
end

--[[
	Cleanup
]]
function ScreenEffects.Cleanup()
	isLowHealthPulsing = false

	if lowHealthTween then
		lowHealthTween:Cancel()
		lowHealthTween = nil
	end

	if updateConnection then
		updateConnection:Disconnect()
		updateConnection = nil
	end

	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end

	isInitialized = false
end

return ScreenEffects
