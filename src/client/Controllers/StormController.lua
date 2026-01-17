--!strict
--[[
	StormController.lua
	==================
	Client-side storm visual effects and rendering
	Based on GDD Section 4: Storm Circle Mechanics
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Events = require(ReplicatedStorage.Shared.Events)

local StormController = {}

-- State
local player = Players.LocalPlayer
local stormPart: Part? = nil
local stormCenter = Vector3.new(0, 0, 0)
local stormRadius = 3000
local targetRadius = 3000
local shrinkTime = 0
local shrinkStartTime = 0
local isInStorm = false
local currentPhase = 0

-- Visual effects
local stormBlur: BlurEffect? = nil
local stormColorCorrection: ColorCorrectionEffect? = nil
local damageOverlay: Frame? = nil
local warningUI: Frame? = nil

-- Constants
local STORM_HEIGHT = 500
local _STORM_SEGMENTS = 64
local STORM_COLOR = Color3.fromRGB(100, 50, 150)
local STORM_TRANSPARENCY = 0.3
local DAMAGE_OVERLAY_COLOR = Color3.fromRGB(150, 50, 200)
local WARNING_DISTANCE = 50 -- Distance from edge to show warning

--[[
	Initialize the storm controller
]]
function StormController.Initialize()
	print("[StormController] Initializing...")

	StormController.CreateStormVisual()
	StormController.CreateEffects()
	StormController.CreateUI()
	StormController.SetupEventListeners()

	-- Start update loop
	RunService.Heartbeat:Connect(function()
		StormController.Update()
	end)

	print("[StormController] Initialized")
end

--[[
	Create the storm wall visual
]]
function StormController.CreateStormVisual()
	-- Create storm container in workspace
	local stormFolder = workspace:FindFirstChild("Storm")
	if not stormFolder then
		stormFolder = Instance.new("Folder")
		stormFolder.Name = "Storm"
		stormFolder.Parent = workspace
	end

	-- Create cylindrical storm wall
	stormPart = Instance.new("Part")
	stormPart.Name = "StormWall"
	stormPart.Anchored = true
	stormPart.CanCollide = false
	stormPart.CastShadow = false
	stormPart.Transparency = STORM_TRANSPARENCY
	stormPart.Material = Enum.Material.ForceField
	stormPart.BrickColor = BrickColor.new("Bright violet")
	stormPart.Size = Vector3.new(stormRadius * 2, STORM_HEIGHT, stormRadius * 2)
	stormPart.Position = Vector3.new(stormCenter.X, STORM_HEIGHT / 2, stormCenter.Z)
	stormPart.Shape = Enum.PartType.Cylinder
	stormPart.Orientation = Vector3.new(0, 0, 90) -- Rotate to vertical
	stormPart.Parent = stormFolder

	-- Add particle effects
	local particles = Instance.new("ParticleEmitter")
	particles.Name = "StormParticles"
	particles.Texture = "rbxassetid://6490035152" -- Generic particle
	particles.Color = ColorSequence.new(STORM_COLOR)
	particles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(1, 1),
	})
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2),
		NumberSequenceKeypoint.new(1, 5),
	})
	particles.Lifetime = NumberRange.new(2, 4)
	particles.Rate = 50
	particles.Speed = NumberRange.new(10, 30)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.RotSpeed = NumberRange.new(-180, 180)
	particles.Parent = stormPart
end

--[[
	Create visual effects for being in storm
]]
function StormController.CreateEffects()
	-- Blur effect
	stormBlur = Instance.new("BlurEffect")
	stormBlur.Name = "StormBlur"
	stormBlur.Size = 0
	stormBlur.Enabled = true
	stormBlur.Parent = Lighting

	-- Color correction
	stormColorCorrection = Instance.new("ColorCorrectionEffect")
	stormColorCorrection.Name = "StormColor"
	stormColorCorrection.Brightness = 0
	stormColorCorrection.Contrast = 0
	stormColorCorrection.Saturation = 0
	stormColorCorrection.TintColor = Color3.fromRGB(255, 255, 255)
	stormColorCorrection.Enabled = true
	stormColorCorrection.Parent = Lighting
end

--[[
	Create storm UI elements
]]
function StormController.CreateUI()
	local playerGui = player:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "StormUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	-- Damage overlay (full screen tint when in storm)
	damageOverlay = Instance.new("Frame")
	damageOverlay.Name = "DamageOverlay"
	damageOverlay.Size = UDim2.fromScale(1, 1)
	damageOverlay.BackgroundColor3 = DAMAGE_OVERLAY_COLOR
	damageOverlay.BackgroundTransparency = 1
	damageOverlay.BorderSizePixel = 0
	damageOverlay.Parent = screenGui

	-- Warning indicator
	warningUI = Instance.new("Frame")
	warningUI.Name = "StormWarning"
	warningUI.Size = UDim2.fromOffset(300, 50)
	warningUI.Position = UDim2.new(0.5, 0, 0, 100)
	warningUI.AnchorPoint = Vector2.new(0.5, 0)
	warningUI.BackgroundColor3 = Color3.fromRGB(100, 30, 130)
	warningUI.BackgroundTransparency = 0.3
	warningUI.BorderSizePixel = 0
	warningUI.Visible = false
	warningUI.Parent = screenGui

	local warningCorner = Instance.new("UICorner")
	warningCorner.CornerRadius = UDim.new(0, 8)
	warningCorner.Parent = warningUI

	local warningLabel = Instance.new("TextLabel")
	warningLabel.Name = "Label"
	warningLabel.Size = UDim2.fromScale(1, 1)
	warningLabel.BackgroundTransparency = 1
	warningLabel.TextColor3 = Color3.fromRGB(255, 200, 255)
	warningLabel.TextSize = 18
	warningLabel.Font = Enum.Font.GothamBold
	warningLabel.Text = "STORM APPROACHING!"
	warningLabel.Parent = warningUI
end

--[[
	Setup event listeners
]]
function StormController.SetupEventListeners()
	-- Listen to GameState.StormUpdate for storm circle updates
	Events.OnClientEvent("GameState", "StormUpdate", function(data)
		StormController.OnStormUpdate(data)
		-- Also treat StormUpdate as a phase change if it has phase info
		if data.phase then
			StormController.OnPhaseChanged(data)
		end
	end)

	-- Listen to Storm.PlayerInStorm for damage feedback
	Events.OnClientEvent("Storm", "PlayerInStorm", function(data)
		isInStorm = data.isInStorm
		if isInStorm then
			StormController.ShowDamageOverlay()
		else
			StormController.HideDamageOverlay()
		end
	end)
end

--[[
	Handle phase change
]]
function StormController.OnPhaseChanged(data: any)
	currentPhase = data.phase or currentPhase
	stormCenter = data.center or stormCenter
	targetRadius = data.radius or targetRadius
	shrinkTime = data.shrinkTime or 0
	shrinkStartTime = tick()

	print(`[StormController] Phase {currentPhase}: radius {targetRadius}, shrink {shrinkTime}s`)
end

--[[
	Handle storm update
]]
function StormController.OnStormUpdate(data: any)
	if data.center then
		stormCenter = data.center
	end
	if data.radius then
		stormRadius = data.radius
		targetRadius = data.radius
	end
end

--[[
	Update loop
]]
function StormController.Update()
	-- Update storm radius if shrinking
	if shrinkTime > 0 then
		local elapsed = tick() - shrinkStartTime
		local progress = math.clamp(elapsed / shrinkTime, 0, 1)

		-- Lerp radius (assumes linear shrink)
		local startRadius = stormRadius
		stormRadius = startRadius + (targetRadius - startRadius) * progress

		if progress >= 1 then
			shrinkTime = 0
			stormRadius = targetRadius
		end
	end

	-- Update storm visual
	StormController.UpdateStormVisual()

	-- Check player position
	StormController.CheckPlayerPosition()
end

--[[
	Update storm visual appearance
]]
function StormController.UpdateStormVisual()
	if not stormPart then return end

	-- Update size and position
	stormPart.Size = Vector3.new(STORM_HEIGHT, stormRadius * 2, stormRadius * 2)
	stormPart.Position = Vector3.new(stormCenter.X, STORM_HEIGHT / 2, stormCenter.Z)
end

--[[
	Check if player is in storm
]]
function StormController.CheckPlayerPosition()
	local character = player.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then return end

	local playerPos = rootPart.Position
	local horizontalDist = (Vector3.new(playerPos.X, 0, playerPos.Z) - Vector3.new(stormCenter.X, 0, stormCenter.Z)).Magnitude

	local wasInStorm = isInStorm
	isInStorm = horizontalDist > stormRadius

	-- Check if approaching storm
	local distToEdge = stormRadius - horizontalDist

	-- Update effects based on state
	if isInStorm then
		StormController.ApplyStormEffects()
		if warningUI then
			warningUI.Visible = false
		end
	else
		StormController.RemoveStormEffects()

		-- Show warning if close to edge
		if distToEdge < WARNING_DISTANCE and distToEdge > 0 then
			if warningUI then
				warningUI.Visible = true
				local label = warningUI:FindFirstChild("Label") :: TextLabel?
				if label then
					label.Text = `STORM IN {math.ceil(distToEdge)}m!`
				end
			end
		else
			if warningUI then
				warningUI.Visible = false
			end
		end
	end

	-- State change events
	if isInStorm and not wasInStorm then
		StormController.OnEnterStorm()
	elseif not isInStorm and wasInStorm then
		StormController.OnExitStorm()
	end
end

--[[
	Apply visual effects when in storm
]]
function StormController.ApplyStormEffects()
	if stormBlur then
		TweenService:Create(stormBlur, TweenInfo.new(0.5), { Size = 8 }):Play()
	end

	if stormColorCorrection then
		TweenService:Create(stormColorCorrection, TweenInfo.new(0.5), {
			Saturation = -0.3,
			TintColor = Color3.fromRGB(200, 180, 220),
		}):Play()
	end

	if damageOverlay then
		-- Pulse effect for damage
		TweenService:Create(damageOverlay, TweenInfo.new(0.3), { BackgroundTransparency = 0.7 }):Play()
	end
end

--[[
	Remove visual effects when leaving storm
]]
function StormController.RemoveStormEffects()
	if stormBlur then
		TweenService:Create(stormBlur, TweenInfo.new(0.5), { Size = 0 }):Play()
	end

	if stormColorCorrection then
		TweenService:Create(stormColorCorrection, TweenInfo.new(0.5), {
			Saturation = 0,
			TintColor = Color3.fromRGB(255, 255, 255),
		}):Play()
	end

	if damageOverlay then
		TweenService:Create(damageOverlay, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
	end
end

--[[
	Called when player enters storm
]]
function StormController.OnEnterStorm()
	print("[StormController] Entered storm!")

	-- Play storm enter sound
	-- AudioController.PlayUISound("StormEnter")

	-- Start damage tick effect
	task.spawn(function()
		while isInStorm do
			if damageOverlay then
				-- Flash damage overlay
				damageOverlay.BackgroundTransparency = 0.5
				task.delay(0.1, function()
					if damageOverlay and isInStorm then
						damageOverlay.BackgroundTransparency = 0.7
					end
				end)
			end
			task.wait(1) -- Sync with damage tick rate
		end
	end)
end

--[[
	Called when player exits storm
]]
function StormController.OnExitStorm()
	print("[StormController] Exited storm!")

	-- Play storm exit sound
	-- AudioController.PlayUISound("StormExit")
end

--[[
	Get distance to safe zone
]]
function StormController.GetDistanceToSafeZone(): number
	local character = player.Character
	if not character then return 0 end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then return 0 end

	local playerPos = rootPart.Position
	local horizontalDist = (Vector3.new(playerPos.X, 0, playerPos.Z) - Vector3.new(stormCenter.X, 0, stormCenter.Z)).Magnitude

	return math.max(0, horizontalDist - stormRadius)
end

--[[
	Get direction to safe zone
]]
function StormController.GetDirectionToSafeZone(): Vector3
	local character = player.Character
	if not character then return Vector3.zero end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then return Vector3.zero end

	local playerPos = rootPart.Position
	local direction = (stormCenter - playerPos)
	direction = Vector3.new(direction.X, 0, direction.Z)

	if direction.Magnitude > 0 then
		return direction.Unit
	end

	return Vector3.zero
end

--[[
	Is player currently in storm
]]
function StormController.IsInStorm(): boolean
	return isInStorm
end

--[[
	Get current storm data
]]
function StormController.GetStormData(): { center: Vector3, radius: number, phase: number }
	return {
		center = stormCenter,
		radius = stormRadius,
		phase = currentPhase,
	}
end

--[[
	Cleanup
]]
function StormController.Cleanup()
	if stormPart then
		stormPart:Destroy()
		stormPart = nil
	end

	if stormBlur then
		stormBlur:Destroy()
		stormBlur = nil
	end

	if stormColorCorrection then
		stormColorCorrection:Destroy()
		stormColorCorrection = nil
	end
end

return StormController
