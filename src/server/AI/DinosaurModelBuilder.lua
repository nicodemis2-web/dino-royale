--!strict
--[[
	DinosaurModelBuilder.lua
	========================
	Creates realistic dinosaur models with proper anatomy for Dino Royale.
	Each dinosaur has species-specific proportions, colors, and features.
]]

local DinosaurModelBuilder = {}

-- Species-specific configurations
local SPECIES_CONFIG = {
	-- COMMON TIER
	Compsognathus = {
		bodyLength = 3,
		bodyHeight = 1.5,
		legLength = 1,
		neckLength = 1,
		headSize = 0.8,
		tailLength = 2,
		tailSegments = 3,
		color = Color3.fromRGB(90, 120, 60), -- Olive green
		secondaryColor = Color3.fromRGB(60, 80, 40),
		stance = "bipedal",
		features = {"small", "agile"},
	},
	Gallimimus = {
		bodyLength = 6,
		bodyHeight = 3,
		legLength = 4,
		neckLength = 3,
		headSize = 1.2,
		tailLength = 4,
		tailSegments = 4,
		color = Color3.fromRGB(180, 160, 120), -- Tan/beige
		secondaryColor = Color3.fromRGB(140, 120, 80),
		stance = "bipedal",
		features = {"long_neck", "runner"},
	},

	-- UNCOMMON TIER
	Dilophosaurus = {
		bodyLength = 8,
		bodyHeight = 4,
		legLength = 3,
		neckLength = 2.5,
		headSize = 2,
		tailLength = 5,
		tailSegments = 5,
		color = Color3.fromRGB(60, 100, 80), -- Dark teal
		secondaryColor = Color3.fromRGB(200, 80, 80), -- Red frill
		stance = "bipedal",
		features = {"crests", "frill"},
	},
	Triceratops = {
		bodyLength = 12,
		bodyHeight = 5,
		legLength = 3,
		neckLength = 1.5,
		headSize = 4,
		tailLength = 4,
		tailSegments = 3,
		color = Color3.fromRGB(120, 100, 80), -- Brown
		secondaryColor = Color3.fromRGB(180, 160, 120),
		stance = "quadruped",
		features = {"horns", "frill", "heavy"},
	},

	-- RARE TIER
	Velociraptor = {
		bodyLength = 6,
		bodyHeight = 3,
		legLength = 2.5,
		neckLength = 1.5,
		headSize = 1.5,
		tailLength = 4,
		tailSegments = 5,
		color = Color3.fromRGB(100, 80, 60), -- Brown/orange
		secondaryColor = Color3.fromRGB(60, 80, 100), -- Blue stripes
		stance = "bipedal",
		features = {"claws", "feathers", "agile"},
	},
	Baryonyx = {
		bodyLength = 10,
		bodyHeight = 4,
		legLength = 3,
		neckLength = 2,
		headSize = 2.5,
		tailLength = 5,
		tailSegments = 4,
		color = Color3.fromRGB(70, 90, 70), -- Swamp green
		secondaryColor = Color3.fromRGB(50, 70, 50),
		stance = "bipedal",
		features = {"crocodile_snout", "claws"},
	},
	Pteranodon = {
		bodyLength = 4,
		bodyHeight = 2,
		legLength = 1,
		neckLength = 2,
		headSize = 2,
		tailLength = 1,
		tailSegments = 2,
		wingSpan = 12,
		color = Color3.fromRGB(140, 120, 100), -- Tan
		secondaryColor = Color3.fromRGB(180, 60, 60), -- Red crest
		stance = "flying",
		features = {"wings", "crest"},
	},
	Dimorphodon = {
		bodyLength = 2,
		bodyHeight = 1,
		legLength = 0.5,
		neckLength = 0.8,
		headSize = 1.2,
		tailLength = 2,
		tailSegments = 3,
		wingSpan = 4,
		color = Color3.fromRGB(80, 60, 60), -- Dark brown
		secondaryColor = Color3.fromRGB(200, 100, 80),
		stance = "flying",
		features = {"wings", "large_head"},
	},

	-- EPIC TIER
	Carnotaurus = {
		bodyLength = 12,
		bodyHeight = 5,
		legLength = 4,
		neckLength = 2,
		headSize = 2.5,
		tailLength = 6,
		tailSegments = 5,
		color = Color3.fromRGB(140, 60, 60), -- Reddish brown
		secondaryColor = Color3.fromRGB(100, 40, 40),
		stance = "bipedal",
		features = {"horns", "tiny_arms", "muscular"},
	},
	Spinosaurus = {
		bodyLength = 18,
		bodyHeight = 6,
		legLength = 4,
		neckLength = 3,
		headSize = 3,
		tailLength = 8,
		tailSegments = 6,
		sailHeight = 5,
		color = Color3.fromRGB(80, 100, 80), -- Greenish grey
		secondaryColor = Color3.fromRGB(180, 80, 60), -- Orange sail
		stance = "bipedal",
		features = {"sail", "crocodile_snout", "aquatic"},
	},
	Mosasaurus = {
		bodyLength = 20,
		bodyHeight = 4,
		legLength = 0,
		neckLength = 2,
		headSize = 4,
		tailLength = 10,
		tailSegments = 8,
		color = Color3.fromRGB(60, 80, 100), -- Blue-grey
		secondaryColor = Color3.fromRGB(40, 60, 80),
		stance = "aquatic",
		features = {"flippers", "aquatic", "massive"},
	},

	-- LEGENDARY TIER
	TRex = {
		bodyLength = 20,
		bodyHeight = 8,
		legLength = 6,
		neckLength = 3,
		headSize = 5,
		tailLength = 10,
		tailSegments = 6,
		color = Color3.fromRGB(100, 80, 60), -- Brown
		secondaryColor = Color3.fromRGB(60, 50, 40),
		stance = "bipedal",
		features = {"tiny_arms", "massive_head", "apex"},
	},
	Indoraptor = {
		bodyLength = 10,
		bodyHeight = 4,
		legLength = 3,
		neckLength = 2,
		headSize = 2,
		tailLength = 5,
		tailSegments = 5,
		color = Color3.fromRGB(30, 30, 40), -- Near black
		secondaryColor = Color3.fromRGB(200, 180, 100), -- Gold stripe
		stance = "bipedal",
		features = {"claws", "hybrid", "intelligent"},
	},
}

-- Create a single part with material
local function createPart(name: string, size: Vector3, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = false
	part.CanCollide = false
	return part
end

-- Weld two parts together
local function weldParts(part0: BasePart, part1: BasePart): WeldConstraint
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part0
	weld.Part1 = part1
	weld.Parent = part1
	return weld
end

-- Create bipedal dinosaur body (T-Rex, Velociraptor, etc.)
local function createBipedalBody(config: any, model: Model): BasePart
	local mainColor = config.color
	local secondColor = config.secondaryColor

	-- Main body (torso)
	local body = createPart("HumanoidRootPart",
		Vector3.new(config.bodyLength * 0.6, config.bodyHeight * 0.7, config.bodyLength),
		mainColor, Enum.Material.SmoothPlastic)
	body.Anchored = true -- Root part anchored
	body.CanCollide = true
	body.Parent = model
	model.PrimaryPart = body

	-- Chest/upper body
	local chest = createPart("Chest",
		Vector3.new(config.bodyLength * 0.5, config.bodyHeight * 0.6, config.bodyLength * 0.5),
		mainColor)
	chest.CFrame = body.CFrame * CFrame.new(0, config.bodyHeight * 0.1, -config.bodyLength * 0.3)
	chest.Parent = model
	weldParts(body, chest)

	-- Neck
	local neck = createPart("Neck",
		Vector3.new(config.bodyLength * 0.2, config.neckLength, config.bodyLength * 0.2),
		mainColor)
	neck.CFrame = chest.CFrame * CFrame.new(0, config.neckLength * 0.5, -config.bodyLength * 0.2)
	neck.Parent = model
	weldParts(chest, neck)

	-- Head
	local headSize = config.headSize
	local head = createPart("Head",
		Vector3.new(headSize * 0.8, headSize * 0.6, headSize * 1.2),
		mainColor)
	head.CFrame = neck.CFrame * CFrame.new(0, config.neckLength * 0.5 + headSize * 0.3, -headSize * 0.3)
	head.Parent = model
	weldParts(neck, head)

	-- Jaw (lower)
	local jaw = createPart("Jaw",
		Vector3.new(headSize * 0.7, headSize * 0.3, headSize * 1.0),
		secondColor)
	jaw.CFrame = head.CFrame * CFrame.new(0, -headSize * 0.3, -headSize * 0.1)
	jaw.Parent = model
	weldParts(head, jaw)

	-- Eyes
	local eyeLeft = createPart("EyeLeft", Vector3.new(headSize * 0.15, headSize * 0.15, headSize * 0.1), Color3.new(1, 1, 0))
	eyeLeft.Material = Enum.Material.Neon
	eyeLeft.CFrame = head.CFrame * CFrame.new(headSize * 0.3, headSize * 0.1, -headSize * 0.4)
	eyeLeft.Parent = model
	weldParts(head, eyeLeft)

	local eyeRight = createPart("EyeRight", Vector3.new(headSize * 0.15, headSize * 0.15, headSize * 0.1), Color3.new(1, 1, 0))
	eyeRight.Material = Enum.Material.Neon
	eyeRight.CFrame = head.CFrame * CFrame.new(-headSize * 0.3, headSize * 0.1, -headSize * 0.4)
	eyeRight.Parent = model
	weldParts(head, eyeRight)

	-- Legs (back legs for bipedal)
	local legWidth = config.bodyLength * 0.15
	local legLeft = createPart("LegLeft",
		Vector3.new(legWidth, config.legLength, legWidth),
		mainColor)
	legLeft.CFrame = body.CFrame * CFrame.new(config.bodyLength * 0.2, -config.bodyHeight * 0.5 - config.legLength * 0.5, config.bodyLength * 0.2)
	legLeft.Parent = model
	weldParts(body, legLeft)

	local legRight = createPart("LegRight",
		Vector3.new(legWidth, config.legLength, legWidth),
		mainColor)
	legRight.CFrame = body.CFrame * CFrame.new(-config.bodyLength * 0.2, -config.bodyHeight * 0.5 - config.legLength * 0.5, config.bodyLength * 0.2)
	legRight.Parent = model
	weldParts(body, legRight)

	-- Feet
	local footLeft = createPart("FootLeft",
		Vector3.new(legWidth * 1.5, legWidth * 0.5, legWidth * 2),
		secondColor)
	footLeft.CFrame = legLeft.CFrame * CFrame.new(0, -config.legLength * 0.5, -legWidth * 0.5)
	footLeft.Parent = model
	weldParts(legLeft, footLeft)

	local footRight = createPart("FootRight",
		Vector3.new(legWidth * 1.5, legWidth * 0.5, legWidth * 2),
		secondColor)
	footRight.CFrame = legRight.CFrame * CFrame.new(0, -config.legLength * 0.5, -legWidth * 0.5)
	footRight.Parent = model
	weldParts(legRight, footRight)

	-- Small arms for T-Rex type
	if table.find(config.features, "tiny_arms") then
		local armSize = config.bodyLength * 0.08
		local armLeft = createPart("ArmLeft", Vector3.new(armSize, armSize * 2, armSize), mainColor)
		armLeft.CFrame = chest.CFrame * CFrame.new(config.bodyLength * 0.25, -config.bodyHeight * 0.1, -config.bodyLength * 0.15)
		armLeft.Parent = model
		weldParts(chest, armLeft)

		local armRight = createPart("ArmRight", Vector3.new(armSize, armSize * 2, armSize), mainColor)
		armRight.CFrame = chest.CFrame * CFrame.new(-config.bodyLength * 0.25, -config.bodyHeight * 0.1, -config.bodyLength * 0.15)
		armRight.Parent = model
		weldParts(chest, armRight)
	end

	-- Tail
	local tailBase = body
	local prevTail = body
	for i = 1, config.tailSegments do
		local segmentLength = config.tailLength / config.tailSegments
		local taper = 1 - (i - 1) / config.tailSegments * 0.7
		local tailSeg = createPart("Tail" .. i,
			Vector3.new(config.bodyLength * 0.3 * taper, config.bodyHeight * 0.4 * taper, segmentLength),
			mainColor)

		local zOffset = config.bodyLength * 0.5 + (i - 0.5) * segmentLength
		if i == 1 then
			tailSeg.CFrame = body.CFrame * CFrame.new(0, 0, zOffset)
		else
			tailSeg.CFrame = prevTail.CFrame * CFrame.new(0, 0, segmentLength)
		end
		tailSeg.Parent = model
		weldParts(prevTail, tailSeg)
		prevTail = tailSeg
	end

	return body
end

-- Create quadruped dinosaur body (Triceratops, etc.)
local function createQuadrupedBody(config: any, model: Model): BasePart
	local mainColor = config.color
	local secondColor = config.secondaryColor

	-- Main body
	local body = createPart("HumanoidRootPart",
		Vector3.new(config.bodyLength * 0.5, config.bodyHeight * 0.8, config.bodyLength),
		mainColor, Enum.Material.SmoothPlastic)
	body.Anchored = true
	body.CanCollide = true
	body.Parent = model
	model.PrimaryPart = body

	-- Neck (shorter for quadrupeds)
	local neck = createPart("Neck",
		Vector3.new(config.bodyLength * 0.3, config.neckLength, config.bodyLength * 0.25),
		mainColor)
	neck.CFrame = body.CFrame * CFrame.new(0, config.bodyHeight * 0.2, -config.bodyLength * 0.45)
	neck.Parent = model
	weldParts(body, neck)

	-- Head (large for Triceratops)
	local head = createPart("Head",
		Vector3.new(config.headSize * 0.8, config.headSize * 0.7, config.headSize),
		mainColor)
	head.CFrame = neck.CFrame * CFrame.new(0, 0, -config.headSize * 0.5)
	head.Parent = model
	weldParts(neck, head)

	-- Frill (for Triceratops)
	if table.find(config.features, "frill") and config.stance == "quadruped" then
		local frill = createPart("Frill",
			Vector3.new(config.headSize * 1.5, config.headSize * 1.2, config.headSize * 0.2),
			secondColor)
		frill.CFrame = neck.CFrame * CFrame.new(0, config.headSize * 0.4, 0)
		frill.Parent = model
		weldParts(neck, frill)
	end

	-- Horns (for Triceratops)
	if table.find(config.features, "horns") and config.stance == "quadruped" then
		local hornSize = config.headSize * 0.6
		-- Nose horn
		local noseHorn = createPart("NoseHorn",
			Vector3.new(hornSize * 0.3, hornSize * 0.5, hornSize * 0.3),
			Color3.new(0.9, 0.9, 0.8))
		noseHorn.CFrame = head.CFrame * CFrame.new(0, config.headSize * 0.2, -config.headSize * 0.5)
		noseHorn.Parent = model
		weldParts(head, noseHorn)

		-- Brow horns
		local hornLeft = createPart("HornLeft",
			Vector3.new(hornSize * 0.2, hornSize * 1.2, hornSize * 0.2),
			Color3.new(0.9, 0.9, 0.8))
		hornLeft.CFrame = head.CFrame * CFrame.new(config.headSize * 0.3, config.headSize * 0.5, -config.headSize * 0.2) * CFrame.Angles(math.rad(-30), 0, math.rad(-15))
		hornLeft.Parent = model
		weldParts(head, hornLeft)

		local hornRight = createPart("HornRight",
			Vector3.new(hornSize * 0.2, hornSize * 1.2, hornSize * 0.2),
			Color3.new(0.9, 0.9, 0.8))
		hornRight.CFrame = head.CFrame * CFrame.new(-config.headSize * 0.3, config.headSize * 0.5, -config.headSize * 0.2) * CFrame.Angles(math.rad(-30), 0, math.rad(15))
		hornRight.Parent = model
		weldParts(head, hornRight)
	end

	-- Four legs
	local legWidth = config.bodyLength * 0.12
	local positions = {
		{x = config.bodyLength * 0.2, z = -config.bodyLength * 0.35, name = "FrontLeft"},
		{x = -config.bodyLength * 0.2, z = -config.bodyLength * 0.35, name = "FrontRight"},
		{x = config.bodyLength * 0.2, z = config.bodyLength * 0.35, name = "BackLeft"},
		{x = -config.bodyLength * 0.2, z = config.bodyLength * 0.35, name = "BackRight"},
	}

	for _, pos in ipairs(positions) do
		local leg = createPart(pos.name .. "Leg",
			Vector3.new(legWidth, config.legLength, legWidth),
			mainColor)
		leg.CFrame = body.CFrame * CFrame.new(pos.x, -config.bodyHeight * 0.4 - config.legLength * 0.5, pos.z)
		leg.Parent = model
		weldParts(body, leg)

		local foot = createPart(pos.name .. "Foot",
			Vector3.new(legWidth * 1.5, legWidth * 0.4, legWidth * 1.5),
			secondColor)
		foot.CFrame = leg.CFrame * CFrame.new(0, -config.legLength * 0.5 - legWidth * 0.2, 0)
		foot.Parent = model
		weldParts(leg, foot)
	end

	-- Tail
	local prevTail = body
	for i = 1, config.tailSegments do
		local segmentLength = config.tailLength / config.tailSegments
		local taper = 1 - (i - 1) / config.tailSegments * 0.6
		local tailSeg = createPart("Tail" .. i,
			Vector3.new(config.bodyLength * 0.25 * taper, config.bodyHeight * 0.35 * taper, segmentLength),
			mainColor)

		local zOffset = config.bodyLength * 0.5 + (i - 0.5) * segmentLength
		if i == 1 then
			tailSeg.CFrame = body.CFrame * CFrame.new(0, -config.bodyHeight * 0.1, zOffset)
		else
			tailSeg.CFrame = prevTail.CFrame * CFrame.new(0, 0, segmentLength)
		end
		tailSeg.Parent = model
		weldParts(prevTail, tailSeg)
		prevTail = tailSeg
	end

	return body
end

-- Create flying dinosaur (Pteranodon, Dimorphodon)
local function createFlyingBody(config: any, model: Model): BasePart
	local mainColor = config.color
	local secondColor = config.secondaryColor

	-- Body
	local body = createPart("HumanoidRootPart",
		Vector3.new(config.bodyLength * 0.4, config.bodyHeight, config.bodyLength),
		mainColor)
	body.Anchored = true
	body.CanCollide = true
	body.Parent = model
	model.PrimaryPart = body

	-- Neck
	local neck = createPart("Neck",
		Vector3.new(config.bodyLength * 0.15, config.neckLength, config.bodyLength * 0.15),
		mainColor)
	neck.CFrame = body.CFrame * CFrame.new(0, config.bodyHeight * 0.3, -config.bodyLength * 0.4)
	neck.Parent = model
	weldParts(body, neck)

	-- Head with beak
	local head = createPart("Head",
		Vector3.new(config.headSize * 0.5, config.headSize * 0.5, config.headSize * 1.5),
		mainColor)
	head.CFrame = neck.CFrame * CFrame.new(0, config.neckLength * 0.4, -config.headSize * 0.5)
	head.Parent = model
	weldParts(neck, head)

	-- Crest (for Pteranodon)
	if table.find(config.features, "crest") then
		local crest = createPart("Crest",
			Vector3.new(config.headSize * 0.1, config.headSize * 0.8, config.headSize * 1.2),
			secondColor)
		crest.CFrame = head.CFrame * CFrame.new(0, config.headSize * 0.4, config.headSize * 0.3)
		crest.Parent = model
		weldParts(head, crest)
	end

	-- Wings
	local wingSpan = config.wingSpan or config.bodyLength * 3
	local wingWidth = wingSpan / 2

	local wingLeft = createPart("WingLeft",
		Vector3.new(wingWidth, config.bodyHeight * 0.1, config.bodyLength * 0.8),
		mainColor)
	wingLeft.CFrame = body.CFrame * CFrame.new(wingWidth * 0.5 + config.bodyLength * 0.2, 0, 0)
	wingLeft.Parent = model
	weldParts(body, wingLeft)

	local wingRight = createPart("WingRight",
		Vector3.new(wingWidth, config.bodyHeight * 0.1, config.bodyLength * 0.8),
		mainColor)
	wingRight.CFrame = body.CFrame * CFrame.new(-wingWidth * 0.5 - config.bodyLength * 0.2, 0, 0)
	wingRight.Parent = model
	weldParts(body, wingRight)

	-- Small tail
	local tail = createPart("Tail",
		Vector3.new(config.bodyLength * 0.15, config.bodyHeight * 0.2, config.tailLength),
		mainColor)
	tail.CFrame = body.CFrame * CFrame.new(0, 0, config.bodyLength * 0.5 + config.tailLength * 0.5)
	tail.Parent = model
	weldParts(body, tail)

	return body
end

-- Create name label billboard
local function createNameLabel(model: Model, species: string, tier: string)
	local primaryPart = model.PrimaryPart
	if not primaryPart then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NameLabel"
	billboard.Size = UDim2.new(0, 200, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 8, 0)
	billboard.AlwaysOnTop = true
	billboard.Adornee = primaryPart
	billboard.Parent = primaryPart

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 0.5
	label.BackgroundColor3 = Color3.new(0, 0, 0)
	label.Text = species .. " (" .. tier .. ")"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = billboard
end

-- Create humanoid for health display
local function createHumanoid(model: Model, health: number, speed: number)
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = health
	humanoid.Health = health
	humanoid.WalkSpeed = speed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.HealthDisplayDistance = 100
	humanoid.Parent = model
end

--[[
	Build a complete dinosaur model
]]
function DinosaurModelBuilder.Build(species: string, position: Vector3, tier: string, health: number, speed: number): Model?
	local config = SPECIES_CONFIG[species]
	if not config then
		warn("[DinosaurModelBuilder] Unknown species: " .. species)
		-- Fallback to a default config
		config = SPECIES_CONFIG.Velociraptor
	end

	local model = Instance.new("Model")
	model.Name = species

	local primaryPart: BasePart

	if config.stance == "bipedal" then
		primaryPart = createBipedalBody(config, model)
	elseif config.stance == "quadruped" then
		primaryPart = createQuadrupedBody(config, model)
	elseif config.stance == "flying" then
		primaryPart = createFlyingBody(config, model)
	elseif config.stance == "aquatic" then
		-- Aquatic uses similar to bipedal but horizontal
		primaryPart = createBipedalBody(config, model)
	else
		primaryPart = createBipedalBody(config, model)
	end

	-- Position the model
	model:SetPrimaryPartCFrame(CFrame.new(position))

	-- Add humanoid
	createHumanoid(model, health, speed)

	-- Add name label
	createNameLabel(model, species, tier)

	-- Parent to workspace
	model.Parent = workspace

	print("[DinosaurModelBuilder] Built " .. species .. " at " .. tostring(position))

	return model
end

--[[
	Get list of all supported species
]]
function DinosaurModelBuilder.GetSupportedSpecies(): {string}
	local species = {}
	for name, _ in pairs(SPECIES_CONFIG) do
		table.insert(species, name)
	end
	return species
end

return DinosaurModelBuilder
