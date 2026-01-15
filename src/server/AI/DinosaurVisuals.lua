--!strict
--[[
	DinosaurVisuals.lua
	===================
	Visual effects and shader system for dinosaurs.

	FEATURES:
	- Tier-based glow effects (Epic/Legendary dinosaurs glow)
	- Highlight effects for visibility and feedback
	- Particle effects (dust, breath steam, etc.)
	- Neon accent parts for bioluminescent species
	- Scale and color variations
	- Damage flash effects
	- Death dissolution effect

	VISUAL TIERS:
	- Common: Base appearance, no special effects
	- Uncommon: Slight color enhancement
	- Rare: Subtle highlight outline
	- Epic: Purple glow, particles
	- Legendary: Gold glow, intense particles, trail effect

	@server
]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local DinosaurVisuals = {}

--------------------------------------------------------------------------------
-- CONFIGURATION
--------------------------------------------------------------------------------

-- Tier-based visual settings
local TIER_VISUALS = {
	Common = {
		hasHighlight = false,
		hasGlow = false,
		hasParticles = false,
		colorMultiplier = 1.0,
	},
	Uncommon = {
		hasHighlight = false,
		hasGlow = false,
		hasParticles = false,
		colorMultiplier = 1.1, -- Slightly more vibrant
	},
	Rare = {
		hasHighlight = true,
		highlightColor = Color3.fromRGB(50, 150, 255),
		highlightTransparency = 0.8,
		hasGlow = false,
		hasParticles = false,
		colorMultiplier = 1.15,
	},
	Epic = {
		hasHighlight = true,
		highlightColor = Color3.fromRGB(153, 50, 204),
		highlightTransparency = 0.6,
		hasGlow = true,
		glowColor = Color3.fromRGB(180, 100, 255),
		hasParticles = true,
		particleColor = Color3.fromRGB(200, 150, 255),
		colorMultiplier = 1.2,
	},
	Legendary = {
		hasHighlight = true,
		highlightColor = Color3.fromRGB(255, 215, 0),
		highlightTransparency = 0.4,
		hasGlow = true,
		glowColor = Color3.fromRGB(255, 200, 50),
		hasParticles = true,
		particleColor = Color3.fromRGB(255, 220, 100),
		hasTrail = true,
		colorMultiplier = 1.3,
	},
}

-- Species-specific accent colors (for bioluminescent markings)
local SPECIES_ACCENTS = {
	Dilophosaurus = {
		hasNeonMarkings = true,
		neonColor = Color3.fromRGB(100, 255, 150),
		markingPattern = "frill",
	},
	Pteranodon = {
		hasNeonMarkings = false,
	},
	Velociraptor = {
		hasNeonMarkings = true,
		neonColor = Color3.fromRGB(255, 100, 50),
		markingPattern = "stripes",
	},
	TRex = {
		hasNeonMarkings = true,
		neonColor = Color3.fromRGB(255, 50, 50),
		markingPattern = "eyes",
	},
	Triceratops = {
		hasNeonMarkings = true,
		neonColor = Color3.fromRGB(50, 200, 255),
		markingPattern = "frill",
	},
	Brachiosaurus = {
		hasNeonMarkings = true,
		neonColor = Color3.fromRGB(100, 255, 200),
		markingPattern = "spots",
	},
	Spinosaurus = {
		hasNeonMarkings = true,
		neonColor = Color3.fromRGB(255, 150, 50),
		markingPattern = "sail",
	},
	Mosasaurus = {
		hasNeonMarkings = true,
		neonColor = Color3.fromRGB(50, 150, 255),
		markingPattern = "bioluminescent",
	},
}

--------------------------------------------------------------------------------
-- MAIN FUNCTIONS
--------------------------------------------------------------------------------

--[[
	Apply all visual effects to a dinosaur model
	@param model The dinosaur model
	@param species The dinosaur species name
	@param tier The rarity tier
]]
function DinosaurVisuals.ApplyVisuals(model: Model, species: string, tier: string)
	local tierConfig = TIER_VISUALS[tier] or TIER_VISUALS.Common
	local speciesConfig = SPECIES_ACCENTS[species]

	-- Apply color enhancement based on tier
	if tierConfig.colorMultiplier ~= 1.0 then
		DinosaurVisuals.EnhanceColors(model, tierConfig.colorMultiplier)
	end

	-- Add highlight effect
	if tierConfig.hasHighlight then
		DinosaurVisuals.AddHighlight(model, tierConfig.highlightColor, tierConfig.highlightTransparency)
	end

	-- Add glow effect
	if tierConfig.hasGlow then
		DinosaurVisuals.AddGlowEffect(model, tierConfig.glowColor)
	end

	-- Add particles
	if tierConfig.hasParticles then
		DinosaurVisuals.AddAmbientParticles(model, tierConfig.particleColor)
	end

	-- Add trail for legendary
	if tierConfig.hasTrail then
		DinosaurVisuals.AddTrailEffect(model, tierConfig.highlightColor)
	end

	-- Add species-specific neon markings
	if speciesConfig and speciesConfig.hasNeonMarkings then
		DinosaurVisuals.AddNeonMarkings(model, speciesConfig.neonColor, speciesConfig.markingPattern)
	end

	-- Add ambient effects (breath steam, dust)
	DinosaurVisuals.AddAmbientEffects(model, species)

	-- Add eye glow
	DinosaurVisuals.AddEyeGlow(model, tier)
end

--[[
	Enhance part colors to be more vibrant
]]
function DinosaurVisuals.EnhanceColors(model: Model, multiplier: number)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			local h, s, v = part.Color:ToHSV()
			-- Increase saturation and value slightly
			s = math.min(1, s * multiplier)
			v = math.min(1, v * (multiplier * 0.9))
			part.Color = Color3.fromHSV(h, s, v)
		end
	end
end

--[[
	Add highlight outline effect
]]
function DinosaurVisuals.AddHighlight(model: Model, color: Color3, transparency: number)
	-- Remove existing highlight if any
	local existing = model:FindFirstChildOfClass("Highlight")
	if existing then
		existing:Destroy()
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "TierHighlight"
	highlight.FillColor = color
	highlight.OutlineColor = color
	highlight.FillTransparency = 0.9
	highlight.OutlineTransparency = transparency
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
end

--[[
	Add glow effect using neon parts
]]
function DinosaurVisuals.AddGlowEffect(model: Model, color: Color3)
	local rootPart = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if not rootPart then return end

	-- Create glow attachment
	local glowPart = Instance.new("Part")
	glowPart.Name = "GlowCore"
	glowPart.Anchored = false
	glowPart.CanCollide = false
	glowPart.Transparency = 0.7
	glowPart.Material = Enum.Material.Neon
	glowPart.Color = color
	glowPart.Size = rootPart.Size * 1.05
	glowPart.CFrame = rootPart.CFrame

	-- Weld to root
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = rootPart
	weld.Part1 = glowPart
	weld.Parent = glowPart

	glowPart.Parent = model

	-- Add pulsing animation
	local tweenInfo = TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local tween = TweenService:Create(glowPart, tweenInfo, {
		Transparency = 0.9,
	})
	tween:Play()
end

--[[
	Add ambient particle effects
]]
function DinosaurVisuals.AddAmbientParticles(model: Model, color: Color3)
	local rootPart = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if not rootPart then return end

	-- Create particle attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = "ParticleAttachment"
	attachment.Position = Vector3.new(0, 1, 0)
	attachment.Parent = rootPart

	-- Ambient sparkle particles
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "TierSparkles"
	sparkles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color),
		ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
	})
	sparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.5, 0.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparkles.Lifetime = NumberRange.new(1, 2)
	sparkles.Rate = 8
	sparkles.Speed = NumberRange.new(0.5, 2)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Brightness = 2
	sparkles.LightEmission = 0.8
	sparkles.LightInfluence = 0
	sparkles.Parent = attachment
end

--[[
	Add trail effect for legendary dinosaurs
]]
function DinosaurVisuals.AddTrailEffect(model: Model, color: Color3)
	local rootPart = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if not rootPart then return end

	-- Create trail attachments
	local attachment0 = Instance.new("Attachment")
	attachment0.Name = "TrailStart"
	attachment0.Position = Vector3.new(0, 0, -rootPart.Size.Z / 2)
	attachment0.Parent = rootPart

	local attachment1 = Instance.new("Attachment")
	attachment1.Name = "TrailEnd"
	attachment1.Position = Vector3.new(0, 0, rootPart.Size.Z / 2)
	attachment1.Parent = rootPart

	local trail = Instance.new("Trail")
	trail.Name = "LegendaryTrail"
	trail.Attachment0 = attachment0
	trail.Attachment1 = attachment1
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color),
		ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Lifetime = 0.5
	trail.MinLength = 0.1
	trail.FaceCamera = true
	trail.LightEmission = 0.5
	trail.Parent = rootPart
end

--[[
	Add neon markings to dinosaur
]]
function DinosaurVisuals.AddNeonMarkings(model: Model, color: Color3, pattern: string)
	-- Find parts to add markings to based on pattern
	local targetParts = {}

	if pattern == "frill" then
		-- Look for head/frill parts
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and (part.Name:lower():find("head") or part.Name:lower():find("frill")) then
				table.insert(targetParts, part)
			end
		end
	elseif pattern == "stripes" then
		-- Add to torso/body parts
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and (part.Name:lower():find("torso") or part.Name:lower():find("body")) then
				table.insert(targetParts, part)
			end
		end
	elseif pattern == "eyes" then
		-- Only head
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and part.Name:lower():find("head") then
				table.insert(targetParts, part)
			end
		end
	elseif pattern == "sail" then
		-- Sail/back parts
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and (part.Name:lower():find("sail") or part.Name:lower():find("back")) then
				table.insert(targetParts, part)
			end
		end
	elseif pattern == "spots" or pattern == "bioluminescent" then
		-- Random body parts
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and math.random() > 0.7 then
				table.insert(targetParts, part)
			end
		end
	end

	-- Add neon accents to target parts
	for _, part in targetParts do
		local neonAccent = Instance.new("Part")
		neonAccent.Name = "NeonMarking"
		neonAccent.Anchored = false
		neonAccent.CanCollide = false
		neonAccent.Material = Enum.Material.Neon
		neonAccent.Color = color
		neonAccent.Size = part.Size * Vector3.new(0.3, 0.1, 0.3)
		neonAccent.Transparency = 0.3

		-- Position on surface of part
		local surfaceOffset = Vector3.new(
			(math.random() - 0.5) * part.Size.X * 0.6,
			part.Size.Y / 2 + 0.05,
			(math.random() - 0.5) * part.Size.Z * 0.6
		)
		neonAccent.CFrame = part.CFrame * CFrame.new(surfaceOffset)

		-- Weld to parent part
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = part
		weld.Part1 = neonAccent
		weld.Parent = neonAccent

		neonAccent.Parent = model

		-- Add subtle pulse
		local tweenInfo = TweenInfo.new(
			1 + math.random() * 0.5,
			Enum.EasingStyle.Sine,
			Enum.EasingDirection.InOut,
			-1,
			true
		)
		TweenService:Create(neonAccent, tweenInfo, { Transparency = 0.6 }):Play()
	end
end

--[[
	Add ambient effects like breath steam
]]
function DinosaurVisuals.AddAmbientEffects(model: Model, species: string)
	-- Find head for breath effects
	local head = model:FindFirstChild("Head", true) :: BasePart?
	if not head then return end

	-- Create breath attachment
	local breathAttachment = Instance.new("Attachment")
	breathAttachment.Name = "BreathAttachment"
	breathAttachment.Position = Vector3.new(0, 0, head.Size.Z / 2)
	breathAttachment.Parent = head

	-- Breath steam particles (subtle)
	local breath = Instance.new("ParticleEmitter")
	breath.Name = "BreathSteam"
	breath.Color = ColorSequence.new(Color3.fromRGB(200, 200, 200))
	breath.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 0.5),
	})
	breath.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})
	breath.Lifetime = NumberRange.new(0.5, 1)
	breath.Rate = 3
	breath.Speed = NumberRange.new(1, 2)
	breath.SpreadAngle = Vector2.new(15, 15)
	breath.Enabled = true
	breath.Parent = breathAttachment
end

--[[
	Add glowing eyes effect
]]
function DinosaurVisuals.AddEyeGlow(model: Model, tier: string)
	-- Find eye parts or create them
	local head = model:FindFirstChild("Head", true) :: BasePart?
	if not head then return end

	-- Determine eye color based on tier
	local eyeColors = {
		Common = Color3.fromRGB(255, 200, 50),
		Uncommon = Color3.fromRGB(255, 180, 50),
		Rare = Color3.fromRGB(100, 200, 255),
		Epic = Color3.fromRGB(200, 100, 255),
		Legendary = Color3.fromRGB(255, 50, 50),
	}
	local eyeColor = eyeColors[tier] or eyeColors.Common

	-- Create eye glow parts
	local eyePositions = {
		Vector3.new(head.Size.X * 0.25, head.Size.Y * 0.2, head.Size.Z * 0.45),
		Vector3.new(-head.Size.X * 0.25, head.Size.Y * 0.2, head.Size.Z * 0.45),
	}

	for i, pos in eyePositions do
		local eye = Instance.new("Part")
		eye.Name = "Eye" .. i
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.new(head.Size.X * 0.15, head.Size.X * 0.15, head.Size.X * 0.15)
		eye.Anchored = false
		eye.CanCollide = false
		eye.Material = Enum.Material.Neon
		eye.Color = eyeColor
		eye.CFrame = head.CFrame * CFrame.new(pos)

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = eye
		weld.Parent = eye

		eye.Parent = model

		-- Add point light for glow
		local light = Instance.new("PointLight")
		light.Color = eyeColor
		light.Brightness = 1
		light.Range = 4
		light.Parent = eye
	end
end

--------------------------------------------------------------------------------
-- COMBAT EFFECTS
--------------------------------------------------------------------------------

--[[
	Flash dinosaur when taking damage
]]
function DinosaurVisuals.PlayDamageFlash(model: Model)
	-- Store original colors
	local originalColors = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			originalColors[part] = part.Color
			part.Color = Color3.fromRGB(255, 100, 100)
		end
	end

	-- Flash back to original
	task.delay(0.1, function()
		for part, color in originalColors do
			if part and part.Parent then
				part.Color = color
			end
		end
	end)
end

--[[
	Play death dissolution effect
]]
function DinosaurVisuals.PlayDeathEffect(model: Model)
	-- Disable physics
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
		end
	end

	-- Dissolution effect - fade out parts
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			local tween = TweenService:Create(part, tweenInfo, {
				Transparency = 1,
				Size = part.Size * 0.5,
			})
			tween:Play()
		end
	end

	-- Create death particles
	local rootPart = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if rootPart then
		local deathParticles = Instance.new("Part")
		deathParticles.Name = "DeathParticles"
		deathParticles.Anchored = true
		deathParticles.CanCollide = false
		deathParticles.Transparency = 1
		deathParticles.Size = Vector3.new(1, 1, 1)
		deathParticles.Position = rootPart.Position
		deathParticles.Parent = workspace

		local particles = Instance.new("ParticleEmitter")
		particles.Color = ColorSequence.new(Color3.fromRGB(100, 100, 100))
		particles.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(1, 0),
		})
		particles.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		})
		particles.Lifetime = NumberRange.new(1, 2)
		particles.Rate = 50
		particles.Speed = NumberRange.new(5, 10)
		particles.SpreadAngle = Vector2.new(180, 180)
		particles.Parent = deathParticles

		-- Stop after burst
		task.delay(0.5, function()
			particles.Enabled = false
		end)

		Debris:AddItem(deathParticles, 3)
	end
end

--[[
	Add roar effect (visual component)
]]
function DinosaurVisuals.PlayRoarEffect(model: Model)
	local head = model:FindFirstChild("Head", true) :: BasePart?
	if not head then return end

	-- Create shockwave ring
	local shockwave = Instance.new("Part")
	shockwave.Name = "RoarShockwave"
	shockwave.Shape = Enum.PartType.Cylinder
	shockwave.Anchored = true
	shockwave.CanCollide = false
	shockwave.Material = Enum.Material.Neon
	shockwave.Color = Color3.fromRGB(255, 200, 100)
	shockwave.Size = Vector3.new(0.5, 1, 1)
	shockwave.CFrame = head.CFrame * CFrame.Angles(0, 0, math.rad(90))
	shockwave.Transparency = 0.5
	shockwave.Parent = workspace

	-- Expand animation
	local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(shockwave, tweenInfo, {
		Size = Vector3.new(0.5, 30, 30),
		Transparency = 1,
	})
	tween:Play()

	Debris:AddItem(shockwave, 0.6)
end

return DinosaurVisuals
