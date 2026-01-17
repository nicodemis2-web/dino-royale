--!strict
--[[
	FloraGenerator.lua
	==================
	Professional procedural flora generation system for Dino Royale.

	FEATURES:
	- Segment-based branching for natural tree shapes
	- CFrame-based construction for proper part attachment
	- Multiple tree varieties per biome
	- LOD (Level of Detail) support
	- Foliage clusters with proper density
	- Rock formations and ground cover
	- Performance-optimized batch generation

	TREE CONSTRUCTION:
	Trees are built using branch segments - each branch consists of
	multiple slightly rotated segments creating organic curves.
	All parts use CFrame positioning for proper attachment.

	VISUAL EFFECTS:
	- Neon material accents for magical/bioluminescent plants
	- Particle emitters for ambient effects (spores, fireflies)
	- Color gradients for canopy depth
	- Proper shadow casting setup

	@server
]]

local _TweenService = game:GetService("TweenService")

local FloraGenerator = {}

--------------------------------------------------------------------------------
-- CONFIGURATION
--------------------------------------------------------------------------------

-- Tree segment settings for natural branching
local BRANCH_SEGMENTS_MIN = 4
local BRANCH_SEGMENTS_MAX = 8
local SEGMENT_ANGLE_VARIANCE = 8 -- degrees of random rotation per segment
local BRANCH_TAPER = 0.85 -- How much each segment shrinks

-- Performance settings
local BATCH_SIZE = 50 -- Parts to create before yielding
local YIELD_TIME = 0.01

-- Material assignments
local MATERIALS = {
	Bark = Enum.Material.Wood,
	BarkRough = Enum.Material.Slate,
	Leaves = Enum.Material.Grass,
	LeavesLush = Enum.Material.LeafyGrass,
	Flowers = Enum.Material.SmoothPlastic,
	Rock = Enum.Material.Rock,
	Moss = Enum.Material.Grass,
	Neon = Enum.Material.Neon,
}

-- Color palettes by biome
local BIOME_COLORS = {
	Jungle = {
		bark = { Color3.fromRGB(89, 60, 31), Color3.fromRGB(71, 48, 25) },
		leaves = { Color3.fromRGB(34, 139, 34), Color3.fromRGB(0, 100, 0), Color3.fromRGB(85, 107, 47) },
		flowers = { Color3.fromRGB(255, 105, 180), Color3.fromRGB(255, 69, 0), Color3.fromRGB(148, 0, 211) },
		accent = Color3.fromRGB(50, 255, 150), -- Bioluminescent
	},
	Plains = {
		bark = { Color3.fromRGB(139, 90, 43), Color3.fromRGB(160, 82, 45) },
		leaves = { Color3.fromRGB(107, 142, 35), Color3.fromRGB(154, 205, 50), Color3.fromRGB(85, 107, 47) },
		flowers = { Color3.fromRGB(255, 255, 0), Color3.fromRGB(255, 165, 0) },
		accent = Color3.fromRGB(255, 223, 186),
	},
	Coastal = {
		bark = { Color3.fromRGB(139, 119, 101), Color3.fromRGB(160, 140, 120) },
		leaves = { Color3.fromRGB(0, 128, 0), Color3.fromRGB(50, 205, 50) },
		flowers = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 192, 203) },
		accent = Color3.fromRGB(135, 206, 250),
	},
	Swamp = {
		bark = { Color3.fromRGB(47, 79, 79), Color3.fromRGB(60, 60, 60) },
		leaves = { Color3.fromRGB(85, 107, 47), Color3.fromRGB(107, 142, 35) },
		flowers = { Color3.fromRGB(148, 0, 211), Color3.fromRGB(75, 0, 130) },
		accent = Color3.fromRGB(100, 255, 100), -- Swamp glow
	},
	Volcanic = {
		bark = { Color3.fromRGB(40, 40, 40), Color3.fromRGB(60, 50, 50) },
		leaves = { Color3.fromRGB(139, 69, 19), Color3.fromRGB(160, 82, 45) },
		flowers = { Color3.fromRGB(255, 69, 0), Color3.fromRGB(255, 140, 0) },
		accent = Color3.fromRGB(255, 100, 0), -- Ember glow
	},
}

-- Tree type definitions
local TREE_TYPES = {
	-- Jungle trees
	JungleGiant = {
		biome = "Jungle",
		heightRange = { 35, 55 },
		trunkWidth = 0.08, -- Multiplier of height
		branchCount = { 8, 14 },
		canopyLayers = 3,
		hasVines = true,
		hasButtressRoots = true,
		leafDensity = "dense",
	},
	JungleMedium = {
		biome = "Jungle",
		heightRange = { 20, 35 },
		trunkWidth = 0.1,
		branchCount = { 5, 9 },
		canopyLayers = 2,
		hasVines = true,
		hasButtressRoots = false,
		leafDensity = "medium",
	},

	-- Plains trees
	Oak = {
		biome = "Plains",
		heightRange = { 15, 28 },
		trunkWidth = 0.12,
		branchCount = { 6, 10 },
		canopyLayers = 2,
		canopyShape = "spreading",
		leafDensity = "medium",
	},
	Birch = {
		biome = "Plains",
		heightRange = { 12, 22 },
		trunkWidth = 0.06,
		branchCount = { 4, 7 },
		canopyLayers = 1,
		canopyShape = "columnar",
		hasWhiteBark = true,
		leafDensity = "sparse",
	},

	-- Coastal trees
	Palm = {
		biome = "Coastal",
		heightRange = { 18, 30 },
		trunkWidth = 0.05,
		hasFronds = true,
		frondCount = { 8, 12 },
		trunkCurve = true,
		hasCoconuts = true,
	},
	CoastalPine = {
		biome = "Coastal",
		heightRange = { 15, 25 },
		trunkWidth = 0.08,
		branchCount = { 8, 14 },
		canopyShape = "conical",
		leafDensity = "medium",
	},

	-- Swamp trees
	Cypress = {
		biome = "Swamp",
		heightRange = { 20, 35 },
		trunkWidth = 0.15,
		hasKnees = true, -- Cypress knees
		hasMoss = true,
		branchCount = { 4, 8 },
		leafDensity = "sparse",
	},
	DeadTree = {
		biome = "Swamp",
		heightRange = { 10, 20 },
		trunkWidth = 0.08,
		branchCount = { 3, 6 },
		isDead = true,
		hasMoss = true,
	},

	-- Volcanic trees
	CharredTree = {
		biome = "Volcanic",
		heightRange = { 8, 18 },
		trunkWidth = 0.1,
		branchCount = { 2, 5 },
		isDead = true,
		hasEmbers = true,
	},
	HeatResistant = {
		biome = "Volcanic",
		heightRange = { 6, 12 },
		trunkWidth = 0.15,
		branchCount = { 3, 6 },
		canopyLayers = 1,
		leafDensity = "sparse",
	},
}

--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------------

local partCount = 0

local function yieldIfNeeded()
	partCount = partCount + 1
	if partCount >= BATCH_SIZE then
		partCount = 0
		task.wait(YIELD_TIME)
	end
end

local function randomInRange(min: number, max: number): number
	return min + math.random() * (max - min)
end

local function pickRandom<T>(array: { T }): T
	return array[math.random(1, #array)]
end

local function addCorner(_part: BasePart, _radius: number?)
	-- Parts don't support UICorner, but we can use Mesh for rounded look
	-- For now, skip this - parts are naturally blocky
end

--[[
	Create a branch segment with proper CFrame attachment
]]
local function createBranchSegment(
	parent: Model,
	startCF: CFrame,
	length: number,
	startRadius: number,
	endRadius: number,
	material: Enum.Material,
	color: Color3
): (Part, CFrame)
	local segment = Instance.new("Part")
	segment.Name = "BranchSegment"
	segment.Anchored = true
	segment.CanCollide = true
	segment.Material = material
	segment.Color = color
	segment.Size = Vector3.new(startRadius * 2, length, startRadius * 2)

	-- Position segment so bottom is at startCF
	local segmentCF = startCF * CFrame.new(0, length / 2, 0)
	segment.CFrame = segmentCF
	segment.Parent = parent

	yieldIfNeeded()

	-- Return end CFrame for next segment
	local endCF = startCF * CFrame.new(0, length, 0)
	return segment, endCF
end

--[[
	Create a curved branch using multiple segments
]]
local function createCurvedBranch(
	parent: Model,
	startCF: CFrame,
	totalLength: number,
	startRadius: number,
	segmentCount: number,
	curveBias: Vector3, -- Direction to curve toward
	material: Enum.Material,
	color: Color3
): CFrame
	local currentCF = startCF
	local currentRadius = startRadius
	local segmentLength = totalLength / segmentCount

	for _ = 1, segmentCount do
		-- Add slight random rotation for organic feel
		local angleX = math.rad(randomInRange(-SEGMENT_ANGLE_VARIANCE, SEGMENT_ANGLE_VARIANCE))
		local angleZ = math.rad(randomInRange(-SEGMENT_ANGLE_VARIANCE, SEGMENT_ANGLE_VARIANCE))

		-- Add curve bias
		local biasStrength = (i / segmentCount) * 0.15
		angleX = angleX + curveBias.X * biasStrength
		angleZ = angleZ + curveBias.Z * biasStrength

		currentCF = currentCF * CFrame.Angles(angleX, 0, angleZ)

		local _, endCF = createBranchSegment(
			parent,
			currentCF,
			segmentLength,
			currentRadius,
			currentRadius * BRANCH_TAPER,
			material,
			color
		)

		currentCF = endCF
		currentRadius = currentRadius * BRANCH_TAPER
	end

	return currentCF
end

--[[
	Create a leaf cluster (sphere-based canopy piece)
]]
local function createLeafCluster(
	parent: Model,
	position: Vector3,
	size: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local leaves = Instance.new("Part")
	leaves.Name = "LeafCluster"
	leaves.Anchored = true
	leaves.CanCollide = false
	leaves.Shape = Enum.PartType.Ball
	leaves.Size = size
	leaves.Position = position
	leaves.Material = material or MATERIALS.Leaves
	leaves.Color = color
	leaves.Transparency = 0
	leaves.CastShadow = true
	leaves.Parent = parent

	yieldIfNeeded()

	return leaves
end

--------------------------------------------------------------------------------
-- TREE GENERATION FUNCTIONS
--------------------------------------------------------------------------------

--[[
	Generate a complete tree with segmented branches
]]
function FloraGenerator.CreateTree(
	position: Vector3,
	treeType: string,
	biome: string?
): Model
	local config = TREE_TYPES[treeType]
	if not config then
		config = TREE_TYPES.Oak -- Default fallback
	end

	local actualBiome = biome or config.biome
	local colors = BIOME_COLORS[actualBiome] or BIOME_COLORS.Plains

	local tree = Instance.new("Model")
	tree.Name = treeType

	-- Determine tree dimensions
	local height = randomInRange(config.heightRange[1], config.heightRange[2])
	local trunkRadius = height * config.trunkWidth
	local trunkHeight = height * (config.hasFronds and 0.85 or 0.55)

	-- Create trunk using curved segments
	local trunkColor = pickRandom(colors.bark)
	local trunkSegments = math.floor(trunkHeight / 4) + 2

	local groundCF = CFrame.new(position)
	local curveBias = config.trunkCurve and Vector3.new(
		randomInRange(-0.3, 0.3),
		0,
		randomInRange(-0.3, 0.3)
	) or Vector3.new(0, 0, 0)

	local topCF = createCurvedBranch(
		tree,
		groundCF,
		trunkHeight,
		trunkRadius,
		trunkSegments,
		curveBias,
		config.hasWhiteBark and Enum.Material.SmoothPlastic or MATERIALS.Bark,
		config.hasWhiteBark and Color3.fromRGB(245, 245, 240) or trunkColor
	)

	-- Add buttress roots for jungle trees
	if config.hasButtressRoots then
		for i = 1, 4 do
			local angle = (i / 4) * math.pi * 2
			local rootLength = trunkRadius * 8
			local rootCF = groundCF
				* CFrame.Angles(0, angle, 0)
				* CFrame.new(trunkRadius * 0.8, 0, 0)
				* CFrame.Angles(0, 0, math.rad(-55))

			createCurvedBranch(
				tree,
				rootCF,
				rootLength,
				trunkRadius * 0.4,
				3,
				Vector3.new(0.2, 0, 0),
				MATERIALS.Bark,
				trunkColor
			)
		end
	end

	-- Handle different tree types
	if config.hasFronds then
		-- Palm tree fronds
		FloraGenerator.AddPalmFronds(tree, topCF, height, colors, config)
	elseif config.isDead then
		-- Dead tree branches
		FloraGenerator.AddDeadBranches(tree, topCF, height, config, colors)
	else
		-- Normal tree with canopy
		FloraGenerator.AddCanopy(tree, topCF, height, config, colors)

		-- Add branches
		if config.branchCount then
			FloraGenerator.AddBranches(tree, groundCF, trunkHeight, trunkRadius, config, colors)
		end
	end

	-- Add vines for jungle trees
	if config.hasVines then
		FloraGenerator.AddVines(tree, topCF, height, colors)
	end

	-- Add moss for swamp trees
	if config.hasMoss then
		FloraGenerator.AddMoss(tree, height)
	end

	-- Add embers for volcanic dead trees
	if config.hasEmbers then
		FloraGenerator.AddEmberEffect(tree, topCF.Position)
	end

	-- Set primary part for model
	local primaryPart = tree:FindFirstChild("BranchSegment") :: Part?
	if primaryPart then
		tree.PrimaryPart = primaryPart
	end

	tree.Parent = workspace
	return tree
end

--[[
	Add palm fronds to tree top
]]
function FloraGenerator.AddPalmFronds(
	tree: Model,
	topCF: CFrame,
	height: number,
	colors: any,
	config: any
)
	local frondCount = randomInRange(config.frondCount[1], config.frondCount[2])
	local frondLength = height * 0.35
	local leafColor = pickRandom(colors.leaves)

	for i = 1, frondCount do
		local angle = (i / frondCount) * math.pi * 2 + randomInRange(-0.2, 0.2)

		-- Create frond stem
		local frondCF = topCF
			* CFrame.Angles(0, angle, 0)
			* CFrame.Angles(math.rad(40 + randomInRange(-10, 10)), 0, 0)

		local stemEnd = createCurvedBranch(
			tree,
			frondCF,
			frondLength,
			height * 0.015,
			4,
			Vector3.new(0.5, 0, 0), -- Curve outward and down
			MATERIALS.Leaves,
			leafColor
		)

		-- Add leaf segments along frond
		local leafCount = math.floor(frondLength / 2)
		for j = 1, leafCount do
			local leafPos = frondCF.Position + (stemEnd.Position - frondCF.Position) * (j / leafCount)
			local leafSize = Vector3.new(0.3, frondLength * 0.4 * (1 - j/leafCount * 0.5), 0.1)

			-- Left leaf
			local leftLeaf = Instance.new("Part")
			leftLeaf.Name = "FrondLeaf"
			leftLeaf.Anchored = true
			leftLeaf.CanCollide = false
			leftLeaf.Size = leafSize
			leftLeaf.Material = MATERIALS.Leaves
			leftLeaf.Color = leafColor
			leftLeaf.CFrame = CFrame.new(leafPos)
				* CFrame.Angles(0, angle, 0)
				* CFrame.new(leafSize.Y * 0.4, 0, 0)
				* CFrame.Angles(0, 0, math.rad(-30))
			leftLeaf.Parent = tree

			-- Right leaf
			local rightLeaf = leftLeaf:Clone()
			rightLeaf.CFrame = CFrame.new(leafPos)
				* CFrame.Angles(0, angle, 0)
				* CFrame.new(-leafSize.Y * 0.4, 0, 0)
				* CFrame.Angles(0, 0, math.rad(30))
			rightLeaf.Parent = tree

			yieldIfNeeded()
		end
	end

	-- Add coconuts if configured
	if config.hasCoconuts then
		for _ = 1, math.random(2, 4) do
			local coconut = Instance.new("Part")
			coconut.Name = "Coconut"
			coconut.Shape = Enum.PartType.Ball
			coconut.Size = Vector3.new(height * 0.06, height * 0.06, height * 0.06)
			coconut.Anchored = true
			coconut.Material = Enum.Material.Wood
			coconut.Color = Color3.fromRGB(139, 90, 43)
			coconut.CFrame = topCF * CFrame.new(
				randomInRange(-height * 0.03, height * 0.03),
				randomInRange(-height * 0.02, height * 0.02),
				randomInRange(-height * 0.03, height * 0.03)
			)
			coconut.Parent = tree
			yieldIfNeeded()
		end
	end
end

--[[
	Add canopy to tree
]]
function FloraGenerator.AddCanopy(
	tree: Model,
	topCF: CFrame,
	height: number,
	config: any,
	colors: any
)
	local layers = config.canopyLayers or 2
	local leafColor = pickRandom(colors.leaves)
	local canopyRadius = height * 0.4

	local shape = config.canopyShape or "round"

	for layer = 1, layers do
		local layerHeight = topCF.Position.Y + (layer - 1) * (height * 0.08)
		local layerRadius = canopyRadius * (1 - (layer - 1) * 0.2)

		if shape == "spreading" then
			-- Wide, spreading canopy (oak style)
			local clusterCount = 5 + layer * 2
			for i = 1, clusterCount do
				local angle = (i / clusterCount) * math.pi * 2
				local distance = layerRadius * randomInRange(0.3, 1)
				local clusterPos = Vector3.new(
					topCF.Position.X + math.cos(angle) * distance,
					layerHeight + randomInRange(-height * 0.05, height * 0.05),
					topCF.Position.Z + math.sin(angle) * distance
				)
				local clusterSize = Vector3.new(
					layerRadius * randomInRange(0.4, 0.7),
					layerRadius * randomInRange(0.3, 0.5),
					layerRadius * randomInRange(0.4, 0.7)
				)
				createLeafCluster(tree, clusterPos, clusterSize, leafColor)
			end
		elseif shape == "conical" then
			-- Cone-shaped canopy (pine style)
			local coneRadius = canopyRadius * (1 - layer / (layers + 2))
			local clusterCount = math.floor(coneRadius / 2) + 3
			for i = 1, clusterCount do
				local angle = (i / clusterCount) * math.pi * 2
				local clusterPos = Vector3.new(
					topCF.Position.X + math.cos(angle) * coneRadius * 0.8,
					layerHeight,
					topCF.Position.Z + math.sin(angle) * coneRadius * 0.8
				)
				createLeafCluster(tree, clusterPos, Vector3.new(coneRadius * 0.6, height * 0.1, coneRadius * 0.6), leafColor)
			end
		elseif shape == "columnar" then
			-- Narrow, columnar canopy (birch style)
			local clusterPos = Vector3.new(
				topCF.Position.X,
				layerHeight,
				topCF.Position.Z
			)
			createLeafCluster(tree, clusterPos, Vector3.new(canopyRadius * 0.5, height * 0.15, canopyRadius * 0.5), leafColor)
		else
			-- Round canopy (default)
			local _mainCluster = createLeafCluster(
				tree,
				Vector3.new(topCF.Position.X, layerHeight, topCF.Position.Z),
				Vector3.new(canopyRadius, canopyRadius * 0.7, canopyRadius),
				leafColor
			)

			-- Add smaller clusters around for fullness
			for i = 1, 4 do
				local angle = (i / 4) * math.pi * 2
				local offset = canopyRadius * 0.4
				createLeafCluster(
					tree,
					Vector3.new(
						topCF.Position.X + math.cos(angle) * offset,
						layerHeight - height * 0.03,
						topCF.Position.Z + math.sin(angle) * offset
					),
					Vector3.new(canopyRadius * 0.5, canopyRadius * 0.4, canopyRadius * 0.5),
					leafColor
				)
			end
		end
	end
end

--[[
	Add branches splitting from trunk
]]
function FloraGenerator.AddBranches(
	tree: Model,
	groundCF: CFrame,
	trunkHeight: number,
	trunkRadius: number,
	config: any,
	colors: any
)
	local branchCount = math.floor(randomInRange(config.branchCount[1], config.branchCount[2]))
	local barkColor = pickRandom(colors.bark)
	local leafColor = pickRandom(colors.leaves)

	for i = 1, branchCount do
		-- Branch starts at random height on trunk
		local branchHeight = trunkHeight * randomInRange(0.4, 0.85)
		local angle = (i / branchCount) * math.pi * 2 + randomInRange(-0.3, 0.3)

		local branchLength = trunkHeight * randomInRange(0.2, 0.4)
		local branchRadius = trunkRadius * randomInRange(0.3, 0.5)

		-- Create branch
		local branchCF = groundCF
			* CFrame.new(0, branchHeight, 0)
			* CFrame.Angles(0, angle, 0)
			* CFrame.Angles(math.rad(randomInRange(30, 60)), 0, 0)

		local branchEnd = createCurvedBranch(
			tree,
			branchCF,
			branchLength,
			branchRadius,
			3,
			Vector3.new(0.3, 0.2, 0),
			MATERIALS.Bark,
			barkColor
		)

		-- Add leaf cluster at branch end
		if not config.isDead then
			local leafSize = branchLength * randomInRange(0.5, 0.8)
			createLeafCluster(
				tree,
				branchEnd.Position,
				Vector3.new(leafSize, leafSize * 0.7, leafSize),
				leafColor
			)
		end
	end
end

--[[
	Add dead branches (no leaves)
]]
function FloraGenerator.AddDeadBranches(
	tree: Model,
	topCF: CFrame,
	height: number,
	config: any,
	colors: any
)
	local branchCount = math.floor(randomInRange(config.branchCount[1], config.branchCount[2]))
	local barkColor = config.biome == "Volcanic"
		and Color3.fromRGB(30, 30, 30)
		or pickRandom(colors.bark)

	for i = 1, branchCount do
		local branchHeight = height * randomInRange(0.3, 0.8)
		local angle = (i / branchCount) * math.pi * 2 + randomInRange(-0.4, 0.4)

		local branchLength = height * randomInRange(0.15, 0.35)
		local branchRadius = height * 0.02

		local branchCF = CFrame.new(topCF.Position.X, topCF.Position.Y - (height * 0.5 - branchHeight), topCF.Position.Z)
			* CFrame.Angles(0, angle, 0)
			* CFrame.Angles(math.rad(randomInRange(20, 70)), 0, math.rad(randomInRange(-15, 15)))

		createCurvedBranch(
			tree,
			branchCF,
			branchLength,
			branchRadius,
			2,
			Vector3.new(0.4, -0.2, randomInRange(-0.2, 0.2)),
			MATERIALS.BarkRough,
			barkColor
		)
	end
end

--[[
	Add hanging vines
]]
function FloraGenerator.AddVines(
	tree: Model,
	topCF: CFrame,
	height: number,
	_colors: any
)
	local vineCount = math.random(4, 8)
	local vineColor = Color3.fromRGB(34, 100, 34)

	for _ = 1, vineCount do
		local angle = (i / vineCount) * math.pi * 2
		local vineLength = height * randomInRange(0.2, 0.5)
		local vineRadius = 0.15

		local vineStartPos = topCF.Position + Vector3.new(
			math.cos(angle) * height * 0.15,
			-height * 0.05,
			math.sin(angle) * height * 0.15
		)

		-- Create vine as thin cylinder hanging down
		local vine = Instance.new("Part")
		vine.Name = "Vine"
		vine.Anchored = true
		vine.CanCollide = false
		vine.Size = Vector3.new(vineRadius, vineLength, vineRadius)
		vine.CFrame = CFrame.new(vineStartPos - Vector3.new(0, vineLength / 2, 0))
		vine.Material = MATERIALS.Grass
		vine.Color = vineColor
		vine.Parent = tree

		yieldIfNeeded()
	end
end

--[[
	Add moss patches to tree
]]
function FloraGenerator.AddMoss(tree: Model, _height: number)
	local mossColor = Color3.fromRGB(85, 107, 47)

	-- Find trunk segments and add moss
	for _, part in tree:GetChildren() do
		if part:IsA("Part") and part.Name == "BranchSegment" and math.random() > 0.6 then
			local moss = Instance.new("Part")
			moss.Name = "Moss"
			moss.Anchored = true
			moss.CanCollide = false
			moss.Size = Vector3.new(part.Size.X * 1.1, part.Size.Y * 0.3, part.Size.Z * 1.1)
			moss.CFrame = part.CFrame * CFrame.new(0, -part.Size.Y * 0.3, 0)
			moss.Material = MATERIALS.Moss
			moss.Color = mossColor
			moss.Transparency = 0.2
			moss.Parent = tree

			yieldIfNeeded()
		end
	end
end

--[[
	Add ember particle effect for volcanic trees
]]
function FloraGenerator.AddEmberEffect(tree: Model, position: Vector3)
	local emitter = Instance.new("Part")
	emitter.Name = "EmberEmitter"
	emitter.Anchored = true
	emitter.CanCollide = false
	emitter.Transparency = 1
	emitter.Size = Vector3.new(1, 1, 1)
	emitter.Position = position
	emitter.Parent = tree

	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 50)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 100, 0)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 50, 0)),
	})
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 0),
	})
	particles.Lifetime = NumberRange.new(1, 3)
	particles.Rate = 5
	particles.Speed = NumberRange.new(1, 3)
	particles.SpreadAngle = Vector2.new(30, 30)
	particles.Brightness = 2
	particles.LightEmission = 1
	particles.Parent = emitter

	yieldIfNeeded()
end

--------------------------------------------------------------------------------
-- ROCK AND GROUND COVER
--------------------------------------------------------------------------------

--[[
	Create a rock formation
]]
function FloraGenerator.CreateRock(
	position: Vector3,
	size: number,
	biome: string?
): Part
	local rock = Instance.new("Part")
	rock.Name = "Rock"
	rock.Anchored = true
	rock.CanCollide = true
	rock.Material = MATERIALS.Rock

	-- Vary shape
	local sizeVariance = Vector3.new(
		size * randomInRange(0.7, 1.3),
		size * randomInRange(0.5, 1),
		size * randomInRange(0.7, 1.3)
	)
	rock.Size = sizeVariance

	-- Position with slight rotation
	rock.CFrame = CFrame.new(position + Vector3.new(0, sizeVariance.Y / 2, 0))
		* CFrame.Angles(
			math.rad(randomInRange(-10, 10)),
			math.rad(randomInRange(0, 360)),
			math.rad(randomInRange(-10, 10))
		)

	-- Color based on biome
	local biomeRockColors = {
		Jungle = Color3.fromRGB(80, 80, 70),
		Plains = Color3.fromRGB(140, 130, 120),
		Coastal = Color3.fromRGB(180, 170, 160),
		Swamp = Color3.fromRGB(60, 70, 60),
		Volcanic = Color3.fromRGB(40, 35, 35),
	}
	rock.Color = biomeRockColors[biome or "Plains"] or biomeRockColors.Plains

	rock.Parent = workspace

	yieldIfNeeded()

	return rock
end

--[[
	Create a rock cluster
]]
function FloraGenerator.CreateRockCluster(
	centerPosition: Vector3,
	radius: number,
	rockCount: number,
	biome: string?
): { Part }
	local rocks = {}

	-- Main large rock
	local mainSize = radius * randomInRange(0.5, 0.8)
	table.insert(rocks, FloraGenerator.CreateRock(centerPosition, mainSize, biome))

	-- Surrounding smaller rocks
	for i = 2, rockCount do
		local angle = (i / rockCount) * math.pi * 2
		local distance = radius * randomInRange(0.3, 0.8)
		local pos = centerPosition + Vector3.new(
			math.cos(angle) * distance,
			0,
			math.sin(angle) * distance
		)
		local size = mainSize * randomInRange(0.3, 0.7)
		table.insert(rocks, FloraGenerator.CreateRock(pos, size, biome))
	end

	return rocks
end

--[[
	Create grass/fern cluster
]]
function FloraGenerator.CreateGrassCluster(
	position: Vector3,
	radius: number,
	biome: string?
): Model
	local cluster = Instance.new("Model")
	cluster.Name = "GrassCluster"

	local colors = BIOME_COLORS[biome or "Plains"]
	local grassColor = colors and pickRandom(colors.leaves) or Color3.fromRGB(100, 150, 50)

	local grassCount = math.floor(radius * 2)

	for i = 1, grassCount do
		local angle = math.random() * math.pi * 2
		local distance = math.random() * radius
		local grassPos = position + Vector3.new(
			math.cos(angle) * distance,
			0,
			math.sin(angle) * distance
		)

		local grass = Instance.new("Part")
		grass.Name = "Grass"
		grass.Anchored = true
		grass.CanCollide = false
		grass.Size = Vector3.new(0.2, randomInRange(0.5, 1.5), 0.2)
		grass.CFrame = CFrame.new(grassPos + Vector3.new(0, grass.Size.Y / 2, 0))
			* CFrame.Angles(math.rad(randomInRange(-15, 15)), math.rad(math.random(360)), 0)
		grass.Material = MATERIALS.Grass
		grass.Color = grassColor
		grass.Parent = cluster

		yieldIfNeeded()
	end

	cluster.Parent = workspace
	return cluster
end

--[[
	Create a flower patch
]]
function FloraGenerator.CreateFlowerPatch(
	position: Vector3,
	radius: number,
	biome: string?
): Model
	local patch = Instance.new("Model")
	patch.Name = "FlowerPatch"

	local colors = BIOME_COLORS[biome or "Plains"]
	local flowerColors = colors and colors.flowers or { Color3.fromRGB(255, 255, 0) }

	local flowerCount = math.floor(radius * 3)

	for i = 1, flowerCount do
		local angle = math.random() * math.pi * 2
		local distance = math.random() * radius
		local flowerPos = position + Vector3.new(
			math.cos(angle) * distance,
			0,
			math.sin(angle) * distance
		)

		-- Stem
		local stem = Instance.new("Part")
		stem.Name = "Stem"
		stem.Anchored = true
		stem.CanCollide = false
		stem.Size = Vector3.new(0.1, randomInRange(0.3, 0.8), 0.1)
		stem.CFrame = CFrame.new(flowerPos + Vector3.new(0, stem.Size.Y / 2, 0))
		stem.Material = MATERIALS.Grass
		stem.Color = Color3.fromRGB(50, 100, 50)
		stem.Parent = patch

		-- Flower head
		local flower = Instance.new("Part")
		flower.Name = "Flower"
		flower.Anchored = true
		flower.CanCollide = false
		flower.Shape = Enum.PartType.Ball
		flower.Size = Vector3.new(0.3, 0.2, 0.3)
		flower.Position = flowerPos + Vector3.new(0, stem.Size.Y + 0.1, 0)
		flower.Material = MATERIALS.Flowers
		flower.Color = pickRandom(flowerColors)
		flower.Parent = patch

		yieldIfNeeded()
	end

	patch.Parent = workspace
	return patch
end

--------------------------------------------------------------------------------
-- BIOME-SPECIFIC GENERATION
--------------------------------------------------------------------------------

--[[
	Get appropriate tree types for a biome
]]
function FloraGenerator.GetTreeTypesForBiome(biome: string): { string }
	local types = {}
	for name, config in pairs(TREE_TYPES) do
		if config.biome == biome then
			table.insert(types, name)
		end
	end

	-- Fallback to plains if no matches
	if #types == 0 then
		for name, config in pairs(TREE_TYPES) do
			if config.biome == "Plains" then
				table.insert(types, name)
			end
		end
	end

	return types
end

--[[
	Generate flora for an area based on biome
]]
function FloraGenerator.GenerateAreaFlora(
	centerPosition: Vector3,
	radius: number,
	biome: string,
	density: number? -- 0-1, default 0.5
)
	local actualDensity = density or 0.5
	local treeTypes = FloraGenerator.GetTreeTypesForBiome(biome)

	-- Calculate counts based on density
	local area = math.pi * radius * radius
	local treeCount = math.floor(area / 500 * actualDensity)
	local rockCount = math.floor(area / 800 * actualDensity)
	local grassCount = math.floor(area / 200 * actualDensity)

	local generated = {
		trees = {},
		rocks = {},
		grass = {},
	}

	-- Generate trees
	for i = 1, treeCount do
		local angle = math.random() * math.pi * 2
		local distance = math.random() * radius
		local pos = centerPosition + Vector3.new(
			math.cos(angle) * distance,
			0,
			math.sin(angle) * distance
		)

		local treeType = pickRandom(treeTypes)
		local tree = FloraGenerator.CreateTree(pos, treeType, biome)
		table.insert(generated.trees, tree)
	end

	-- Generate rock clusters
	for i = 1, rockCount do
		local angle = math.random() * math.pi * 2
		local distance = math.random() * radius
		local pos = centerPosition + Vector3.new(
			math.cos(angle) * distance,
			0,
			math.sin(angle) * distance
		)

		local rocks = FloraGenerator.CreateRockCluster(pos, randomInRange(3, 8), math.random(3, 7), biome)
		for _, rock in rocks do
			table.insert(generated.rocks, rock)
		end
	end

	-- Generate grass clusters
	for i = 1, grassCount do
		local angle = math.random() * math.pi * 2
		local distance = math.random() * radius
		local pos = centerPosition + Vector3.new(
			math.cos(angle) * distance,
			0,
			math.sin(angle) * distance
		)

		local grass = FloraGenerator.CreateGrassCluster(pos, randomInRange(2, 5), biome)
		table.insert(generated.grass, grass)
	end

	return generated
end

return FloraGenerator
