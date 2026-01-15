--!strict
--[[
	DinosaurVisualEffects.lua
	=========================
	Visual effects system for dinosaurs and creatures
	Implements highlighting, threat indicators, and atmospheric effects

	Best Practices Implemented:
	- Roblox Highlight instance for creature outlines (efficient, built-in)
	- Distance-based effect culling for performance
	- Threat-level color coding for gameplay clarity
	- Particle effects for creature states (aggro, damaged, etc.)

	Visual Design Philosophy:
	- Carnivores: Red/orange highlights indicating danger
	- Herbivores: Green/blue highlights indicating passive
	- Boss creatures: Purple/gold legendary highlights
	- Damaged creatures: Pulsing effects showing vulnerability
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local DinosaurVisualEffects = {}

-- State
local isInitialized = false
local localPlayer = Players.LocalPlayer
local trackedDinosaurs: { [Model]: DinosaurVisualData } = {}
local updateConnection: RBXScriptConnection? = nil

-- Configuration constants
local MAX_HIGHLIGHT_DISTANCE = 150 -- Studs beyond which highlights fade
local HIGHLIGHT_FADE_START = 100 -- Distance at which fade begins
local UPDATE_INTERVAL = 0.1 -- Seconds between distance checks
local MAX_TRACKED_DINOSAURS = 20 -- Performance limit

-- Type definitions
type DinosaurVisualData = {
	model: Model,
	highlight: Highlight?,
	threatLevel: string, -- "passive", "neutral", "aggressive", "boss"
	species: string,
	isVisible: boolean,
	lastDistance: number,
	particleEmitters: { ParticleEmitter },
	pulseConnection: RBXScriptConnection?,
}

--[[
	DINOSAUR VISUAL PRESETS
	=======================
	Each dinosaur type has specific visual settings for clarity and immersion
	Colors chosen for colorblind accessibility (avoid red/green only differentiation)
]]
local DinosaurPresets = {
	-- Passive herbivores (safe to approach)
	Passive = {
		highlightColor = Color3.fromRGB(80, 180, 120), -- Soft green
		outlineColor = Color3.fromRGB(40, 100, 60),
		fillTransparency = 0.8,
		outlineTransparency = 0.3,
		depthMode = Enum.HighlightDepthMode.Occluded,
		particleColor = Color3.fromRGB(100, 200, 150),
	},

	-- Neutral creatures (may become aggressive if provoked)
	Neutral = {
		highlightColor = Color3.fromRGB(200, 180, 80), -- Amber/yellow
		outlineColor = Color3.fromRGB(150, 130, 40),
		fillTransparency = 0.75,
		outlineTransparency = 0.25,
		depthMode = Enum.HighlightDepthMode.Occluded,
		particleColor = Color3.fromRGB(220, 200, 100),
	},

	-- Aggressive carnivores (dangerous, will attack)
	Aggressive = {
		highlightColor = Color3.fromRGB(220, 80, 60), -- Warning red
		outlineColor = Color3.fromRGB(180, 40, 30),
		fillTransparency = 0.7,
		outlineTransparency = 0.2,
		depthMode = Enum.HighlightDepthMode.AlwaysOnTop, -- Always visible for safety
		particleColor = Color3.fromRGB(255, 100, 80),
	},

	-- Boss creatures (rare, extremely dangerous)
	Boss = {
		highlightColor = Color3.fromRGB(180, 80, 220), -- Royal purple
		outlineColor = Color3.fromRGB(255, 200, 80), -- Gold outline
		fillTransparency = 0.6,
		outlineTransparency = 0.1,
		depthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		particleColor = Color3.fromRGB(200, 150, 255),
	},

	-- Damaged/weakened creatures
	Damaged = {
		highlightColor = Color3.fromRGB(255, 150, 100), -- Orange warning
		outlineColor = Color3.fromRGB(255, 200, 150),
		fillTransparency = 0.65,
		outlineTransparency = 0.15,
		depthMode = Enum.HighlightDepthMode.Occluded,
		particleColor = Color3.fromRGB(255, 180, 120),
	},

	-- Tranquilized/sleeping creatures
	Tranquilized = {
		highlightColor = Color3.fromRGB(100, 150, 220), -- Calm blue
		outlineColor = Color3.fromRGB(60, 100, 180),
		fillTransparency = 0.85,
		outlineTransparency = 0.4,
		depthMode = Enum.HighlightDepthMode.Occluded,
		particleColor = Color3.fromRGB(150, 180, 255),
	},
}

--[[
	SPECIES-SPECIFIC VISUAL OVERRIDES
	==================================
	Some species have unique visual treatments for gameplay distinction
]]
local SpeciesOverrides = {
	-- T-Rex: Always highly visible due to extreme danger
	TRex = {
		basePreset = "Aggressive",
		outlineThickness = 0.1,
		glowIntensity = 1.5,
		footstepParticles = true,
	},

	-- Velociraptor: Pack hunters, show connection lines
	Velociraptor = {
		basePreset = "Aggressive",
		showPackLines = true,
		glowIntensity = 1.0,
	},

	-- Triceratops: Defensive, highlight shield/horns
	Triceratops = {
		basePreset = "Neutral",
		highlightParts = { "Head", "Horns" },
		glowIntensity = 0.8,
	},

	-- Pterodactyl: Flying, always visible in sky
	Pterodactyl = {
		basePreset = "Neutral",
		alwaysOnTop = true,
		trailEffect = true,
	},

	-- Spinosaurus: Boss-tier threat
	Spinosaurus = {
		basePreset = "Boss",
		glowIntensity = 2.0,
		ambientParticles = true,
	},
}

--[[
	Initialize the dinosaur visual effects system
]]
function DinosaurVisualEffects.Initialize()
	if isInitialized then return end
	isInitialized = true

	print("[DinosaurVisualEffects] Initializing creature visual system...")

	-- Start update loop for distance-based effects
	local lastUpdate = 0
	updateConnection = RunService.Heartbeat:Connect(function()
		local now = tick()
		if now - lastUpdate >= UPDATE_INTERVAL then
			lastUpdate = now
			DinosaurVisualEffects.UpdateAllDinosaurs()
		end
	end)

	print("[DinosaurVisualEffects] Initialized with distance-based highlighting")
end

--[[
	Register a dinosaur for visual tracking
	@param model The dinosaur model
	@param species Species identifier
	@param threatLevel Threat classification
]]
function DinosaurVisualEffects.RegisterDinosaur(model: Model, species: string, threatLevel: string)
	if trackedDinosaurs[model] then return end

	-- Performance limit check
	local count = 0
	for _ in pairs(trackedDinosaurs) do
		count = count + 1
	end
	if count >= MAX_TRACKED_DINOSAURS then
		-- Remove furthest dinosaur to make room
		DinosaurVisualEffects.RemoveFurthestDinosaur()
	end

	-- Get preset for this threat level
	local preset = DinosaurPresets[threatLevel] or DinosaurPresets.Neutral
	local speciesOverride = SpeciesOverrides[species]

	-- Create highlight instance
	local highlight = Instance.new("Highlight")
	highlight.Name = "DinoHighlight"
	highlight.Adornee = model
	highlight.FillColor = preset.highlightColor
	highlight.OutlineColor = preset.outlineColor
	highlight.FillTransparency = preset.fillTransparency
	highlight.OutlineTransparency = preset.outlineTransparency
	highlight.DepthMode = preset.depthMode
	highlight.Enabled = false -- Start disabled, enable when in range
	highlight.Parent = model

	-- Create visual data entry
	local visualData: DinosaurVisualData = {
		model = model,
		highlight = highlight,
		threatLevel = threatLevel,
		species = species,
		isVisible = false,
		lastDistance = math.huge,
		particleEmitters = {},
		pulseConnection = nil,
	}

	-- Apply species-specific effects
	if speciesOverride then
		if speciesOverride.ambientParticles then
			DinosaurVisualEffects.AddAmbientParticles(visualData, preset.particleColor)
		end
	end

	-- Add threat-level-specific effects
	if threatLevel == "Aggressive" or threatLevel == "Boss" then
		DinosaurVisualEffects.StartThreatPulse(visualData)
	end

	trackedDinosaurs[model] = visualData

	-- Listen for model removal
	model.AncestryChanged:Connect(function(_, parent)
		if not parent then
			DinosaurVisualEffects.UnregisterDinosaur(model)
		end
	end)
end

--[[
	Unregister a dinosaur from visual tracking
	@param model The dinosaur model to remove
]]
function DinosaurVisualEffects.UnregisterDinosaur(model: Model)
	local visualData = trackedDinosaurs[model]
	if not visualData then return end

	-- Cleanup highlight
	if visualData.highlight then
		visualData.highlight:Destroy()
	end

	-- Cleanup particles
	for _, emitter in ipairs(visualData.particleEmitters) do
		emitter:Destroy()
	end

	-- Cleanup pulse connection
	if visualData.pulseConnection then
		visualData.pulseConnection:Disconnect()
	end

	trackedDinosaurs[model] = nil
end

--[[
	Update all tracked dinosaurs based on distance from player
	Enables/disables highlights and adjusts transparency based on range
]]
function DinosaurVisualEffects.UpdateAllDinosaurs()
	local character = localPlayer.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then return end

	local playerPosition = rootPart.Position

	for model, visualData in pairs(trackedDinosaurs) do
		-- Check if model still exists
		if not model.Parent then
			DinosaurVisualEffects.UnregisterDinosaur(model)
			continue
		end

		-- Calculate distance
		local dinoPrimaryPart = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
		if not dinoPrimaryPart then continue end

		local distance = (dinoPrimaryPart.Position - playerPosition).Magnitude
		visualData.lastDistance = distance

		-- Update highlight visibility based on distance
		if visualData.highlight then
			if distance <= MAX_HIGHLIGHT_DISTANCE then
				visualData.highlight.Enabled = true
				visualData.isVisible = true

				-- Calculate fade based on distance
				if distance > HIGHLIGHT_FADE_START then
					local fadeProgress = (distance - HIGHLIGHT_FADE_START) / (MAX_HIGHLIGHT_DISTANCE - HIGHLIGHT_FADE_START)
					local preset = DinosaurPresets[visualData.threatLevel] or DinosaurPresets.Neutral

					-- Fade out highlight at distance
					visualData.highlight.FillTransparency = preset.fillTransparency + (1 - preset.fillTransparency) * fadeProgress
					visualData.highlight.OutlineTransparency = preset.outlineTransparency + (1 - preset.outlineTransparency) * fadeProgress
				else
					-- Full visibility when close
					local preset = DinosaurPresets[visualData.threatLevel] or DinosaurPresets.Neutral
					visualData.highlight.FillTransparency = preset.fillTransparency
					visualData.highlight.OutlineTransparency = preset.outlineTransparency
				end
			else
				visualData.highlight.Enabled = false
				visualData.isVisible = false
			end
		end
	end
end

--[[
	Remove the furthest tracked dinosaur (for performance management)
]]
function DinosaurVisualEffects.RemoveFurthestDinosaur()
	local furthestModel: Model? = nil
	local furthestDistance = 0

	for model, visualData in pairs(trackedDinosaurs) do
		if visualData.lastDistance > furthestDistance then
			furthestDistance = visualData.lastDistance
			furthestModel = model
		end
	end

	if furthestModel then
		DinosaurVisualEffects.UnregisterDinosaur(furthestModel)
	end
end

--[[
	Start threat pulse animation for dangerous dinosaurs
	Creates pulsing highlight effect to draw attention
	@param visualData The dinosaur visual data
]]
function DinosaurVisualEffects.StartThreatPulse(visualData: DinosaurVisualData)
	if visualData.pulseConnection then return end

	local preset = DinosaurPresets[visualData.threatLevel] or DinosaurPresets.Aggressive
	local baseTransparency = preset.fillTransparency
	local pulseSpeed = visualData.threatLevel == "Boss" and 3 or 2

	visualData.pulseConnection = RunService.Heartbeat:Connect(function()
		if not visualData.highlight or not visualData.isVisible then return end

		-- Sinusoidal pulse
		local pulse = math.sin(tick() * pulseSpeed) * 0.15
		visualData.highlight.FillTransparency = math.clamp(baseTransparency + pulse, 0, 1)
	end)
end

--[[
	Add ambient particle effects around a dinosaur
	@param visualData The dinosaur visual data
	@param color Particle color
]]
function DinosaurVisualEffects.AddAmbientParticles(visualData: DinosaurVisualData, color: Color3)
	local model = visualData.model
	local primaryPart = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	if not primaryPart then return end

	-- Create ambient particle emitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "AmbientEffect"
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.5
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(0.5, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(1, 2)
	emitter.Rate = 5
	emitter.Speed = NumberRange.new(1, 3)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = primaryPart

	table.insert(visualData.particleEmitters, emitter)
end

--[[
	Show damage effect on a dinosaur
	@param model The dinosaur model
	@param damageAmount Amount of damage taken
]]
function DinosaurVisualEffects.ShowDamageEffect(model: Model, damageAmount: number)
	local visualData = trackedDinosaurs[model]
	if not visualData or not visualData.highlight then return end

	-- Flash white on damage
	local originalFillColor = visualData.highlight.FillColor
	local originalOutlineColor = visualData.highlight.OutlineColor

	visualData.highlight.FillColor = Color3.new(1, 1, 1)
	visualData.highlight.OutlineColor = Color3.new(1, 1, 1)
	visualData.highlight.FillTransparency = 0.3

	-- Tween back to original
	task.delay(0.1, function()
		if not visualData.highlight then return end

		local tween = TweenService:Create(visualData.highlight, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			FillColor = originalFillColor,
			OutlineColor = originalOutlineColor,
			FillTransparency = DinosaurPresets[visualData.threatLevel].fillTransparency,
		})
		tween:Play()
	end)

	-- Spawn damage particles
	DinosaurVisualEffects.SpawnDamageParticles(model, damageAmount)
end

--[[
	Spawn damage particles at dinosaur location
	@param model The dinosaur model
	@param amount Intensity of effect
]]
function DinosaurVisualEffects.SpawnDamageParticles(model: Model, amount: number)
	local primaryPart = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	if not primaryPart then return end

	-- Create one-shot particle burst
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 100, 100))
	emitter.Size = NumberSequence.new(0.5, 0)
	emitter.Transparency = NumberSequence.new(0, 1)
	emitter.Lifetime = NumberRange.new(0.3, 0.6)
	emitter.Rate = 0
	emitter.Speed = NumberRange.new(10, 20)
	emitter.SpreadAngle = Vector2.new(360, 360)
	emitter.Parent = primaryPart

	-- Emit burst
	local particleCount = math.clamp(math.floor(amount / 10), 5, 30)
	emitter:Emit(particleCount)

	-- Cleanup
	Debris:AddItem(emitter, 1)
end

--[[
	Show aggro indicator when dinosaur targets player
	@param model The dinosaur model
]]
function DinosaurVisualEffects.ShowAggroIndicator(model: Model)
	local visualData = trackedDinosaurs[model]
	if not visualData then return end

	-- Update to aggressive preset if not already
	if visualData.threatLevel ~= "Aggressive" and visualData.threatLevel ~= "Boss" then
		visualData.threatLevel = "Aggressive"
		local preset = DinosaurPresets.Aggressive

		if visualData.highlight then
			local tween = TweenService:Create(visualData.highlight, TweenInfo.new(0.5), {
				FillColor = preset.highlightColor,
				OutlineColor = preset.outlineColor,
			})
			tween:Play()
			visualData.highlight.DepthMode = preset.depthMode
		end

		-- Start threat pulse
		DinosaurVisualEffects.StartThreatPulse(visualData)
	end
end

--[[
	Show tranquilized effect when dinosaur is sedated
	@param model The dinosaur model
]]
function DinosaurVisualEffects.ShowTranquilizedEffect(model: Model)
	local visualData = trackedDinosaurs[model]
	if not visualData then return end

	-- Update to tranquilized preset
	visualData.threatLevel = "Tranquilized"
	local preset = DinosaurPresets.Tranquilized

	if visualData.highlight then
		local tween = TweenService:Create(visualData.highlight, TweenInfo.new(1), {
			FillColor = preset.highlightColor,
			OutlineColor = preset.outlineColor,
			FillTransparency = preset.fillTransparency,
		})
		tween:Play()
		visualData.highlight.DepthMode = preset.depthMode
	end

	-- Stop threat pulse if active
	if visualData.pulseConnection then
		visualData.pulseConnection:Disconnect()
		visualData.pulseConnection = nil
	end

	-- Add sleep particles (Z's floating up)
	DinosaurVisualEffects.AddSleepParticles(visualData)
end

--[[
	Add floating sleep particles for tranquilized dinosaurs
	@param visualData The dinosaur visual data
]]
function DinosaurVisualEffects.AddSleepParticles(visualData: DinosaurVisualData)
	local model = visualData.model
	local head = model:FindFirstChild("Head") or model.PrimaryPart
	if not head then return end

	local sleepEmitter = Instance.new("ParticleEmitter")
	sleepEmitter.Name = "SleepParticles"
	sleepEmitter.Color = ColorSequence.new(Color3.fromRGB(200, 220, 255))
	sleepEmitter.LightEmission = 0.3
	sleepEmitter.Size = NumberSequence.new(1, 0.5)
	sleepEmitter.Transparency = NumberSequence.new(0.3, 1)
	sleepEmitter.Lifetime = NumberRange.new(2, 3)
	sleepEmitter.Rate = 2
	sleepEmitter.Speed = NumberRange.new(2, 4)
	sleepEmitter.SpreadAngle = Vector2.new(30, 30)
	sleepEmitter.EmissionDirection = Enum.NormalId.Top
	sleepEmitter.Parent = head

	table.insert(visualData.particleEmitters, sleepEmitter)
end

--[[
	Get all dinosaurs within a radius
	@param position Center position
	@param radius Search radius
	@return Array of dinosaur models in range
]]
function DinosaurVisualEffects.GetDinosaursInRadius(position: Vector3, radius: number): { Model }
	local result = {}

	for model, visualData in pairs(trackedDinosaurs) do
		if visualData.lastDistance <= radius then
			table.insert(result, model)
		end
	end

	return result
end

--[[
	Check if a dinosaur is currently visible (highlighted)
	@param model The dinosaur model
	@return Whether the dinosaur is visible
]]
function DinosaurVisualEffects.IsDinosaurVisible(model: Model): boolean
	local visualData = trackedDinosaurs[model]
	return visualData ~= nil and visualData.isVisible
end

--[[
	Cleanup and shutdown the visual effects system
]]
function DinosaurVisualEffects.Shutdown()
	isInitialized = false

	if updateConnection then
		updateConnection:Disconnect()
		updateConnection = nil
	end

	-- Cleanup all tracked dinosaurs
	for model in pairs(trackedDinosaurs) do
		DinosaurVisualEffects.UnregisterDinosaur(model)
	end

	print("[DinosaurVisualEffects] Shutdown complete")
end

return DinosaurVisualEffects
