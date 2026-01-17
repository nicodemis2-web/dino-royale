--!strict
--[[
	EnvironmentalPropsGenerator.lua
	================================
	Generates environmental props for strategic gameplay based on PVP best practices.

	DESIGN PRINCIPLES (from Roblox DevForum research):
	- Strategic cover placement at corners and borders
	- Verticality spots with risk/reward positioning
	- Clear landmarks for navigation
	- Multiple entrances to prevent camping
	- 32-stud wide pathways with connecting alleys
	- Balance detail vs performance

	PROP CATEGORIES:
	- Cover Props: Barrels, crates, boulders, walls (for PVP combat)
	- Decorative Props: Ferns, stumps, debris (for atmosphere)
	- Landmark Props: Unique structures visible from distance

	@server
]]

local BiomeData = require(game.ReplicatedStorage.Shared.BiomeData)

local EnvironmentalPropsGenerator = {}

--------------------------------------------------------------------------------
-- CONFIGURATION
--------------------------------------------------------------------------------

-- Performance settings
local BATCH_SIZE = 20
local YIELD_INTERVAL = 0.02

-- Prop density settings (props per 100x100 stud area)
local DENSITY = {
	coverProps = 0.8,      -- Cover props per 10k studs
	decorativeProps = 1.2,  -- Decorative props per 10k studs
	groundDebris = 2.0,     -- Small debris per 10k studs
}

-- Prop placement settings
local COVER_PLACEMENT = {
	minDistanceFromOther = 15,  -- Minimum distance between cover props
	maxDistanceFromPath = 40,   -- Maximum distance from main paths
	cornerBias = 0.7,           -- Preference for corner/edge placement
	clusterChance = 0.3,        -- Chance to create a cluster of props
	clusterRadius = 12,         -- Radius for clustered props
	clusterCount = { 2, 4 },    -- Min/max props in a cluster
}

-- Path settings for strategic placement
local _PATH_WIDTH = 32
local _ALLEY_WIDTH = 16

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------

local generatedProps: { [string]: { Model | Part } } = {}
local propCounter = 0

--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------------

local function yieldIfNeeded()
	propCounter = propCounter + 1
	if propCounter >= BATCH_SIZE then
		propCounter = 0
		task.wait(YIELD_INTERVAL)
	end
end

local function randomInRange(min: number, max: number): number
	return min + math.random() * (max - min)
end

local function pickRandom<T>(array: { T }): T
	return array[math.random(1, #array)]
end

local function getGroundLevel(x: number, z: number, defaultHeight: number): number
	local rayOrigin = Vector3.new(x, 500, z)
	local rayDirection = Vector3.new(0, -1000, 0)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	rayParams.FilterDescendantsInstances = { workspace.Terrain }

	local result = workspace:Raycast(rayOrigin, rayDirection, rayParams)
	if result then
		return result.Position.Y
	end
	return defaultHeight
end

local function isPositionValid(position: Vector3, minDistance: number): boolean
	-- Check distance from existing props
	for _, props in pairs(generatedProps) do
		for _, prop in ipairs(props) do
			local propPos = prop:IsA("Model") and prop:GetPivot().Position or (prop :: Part).Position
			if (propPos - position).Magnitude < minDistance then
				return false
			end
		end
	end
	return true
end

--------------------------------------------------------------------------------
-- PROP CREATION
--------------------------------------------------------------------------------

--[[
	Create a prop from definition
]]
local function createProp(definition: BiomeData.PropDefinition, position: Vector3, biome: string): Part
	local prop: Part

	-- Create base part
	prop = Instance.new("Part")
	prop.Name = definition.name
	prop.Anchored = true
	prop.CanCollide = definition.canCollide
	prop.Size = definition.size
	prop.Material = definition.material
	prop.Color = definition.color
	prop.CastShadow = true

	-- Add slight rotation for natural look
	local rotation = CFrame.Angles(
		math.rad(randomInRange(-3, 3)),
		math.rad(randomInRange(0, 360)),
		math.rad(randomInRange(-3, 3))
	)

	-- Get ground level
	local groundY = getGroundLevel(position.X, position.Z, position.Y)
	prop.CFrame = CFrame.new(position.X, groundY + definition.size.Y / 2, position.Z) * rotation

	-- Add attributes for game systems
	prop:SetAttribute("PropType", definition.name)
	prop:SetAttribute("Biome", biome)
	prop:SetAttribute("ProvidesCover", definition.provideCover)

	if definition.destructible then
		prop:SetAttribute("Destructible", true)
		prop:SetAttribute("Health", definition.health or 100)
		prop:SetAttribute("MaxHealth", definition.health or 100)
	end

	-- Add to appropriate folder
	local folder = workspace:FindFirstChild("EnvironmentalProps")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "EnvironmentalProps"
		folder.Parent = workspace
	end

	local biomeFolder = folder:FindFirstChild(biome)
	if not biomeFolder then
		biomeFolder = Instance.new("Folder")
		biomeFolder.Name = biome
		biomeFolder.Parent = folder
	end

	prop.Parent = biomeFolder

	yieldIfNeeded()

	return prop
end

--[[
	Create a prop cluster (multiple props grouped together)
]]
local function createPropCluster(
	definition: BiomeData.PropDefinition,
	centerPosition: Vector3,
	biome: string,
	count: number,
	radius: number
): { Part | Model }
	local props = {}

	-- Main prop at center
	local mainProp = createProp(definition, centerPosition, biome)
	table.insert(props, mainProp)

	-- Surrounding smaller props
	for i = 2, count do
		local angle = (i / count) * math.pi * 2
		local distance = randomInRange(radius * 0.3, radius * 0.8)
		local offset = Vector3.new(
			math.cos(angle) * distance,
			0,
			math.sin(angle) * distance
		)
		local pos = centerPosition + offset

		-- Scale down surrounding props slightly
		local scaledDef = table.clone(definition)
		scaledDef.size = definition.size * randomInRange(0.6, 0.9)

		local prop = createProp(scaledDef, pos, biome)
		table.insert(props, prop)
	end

	return props
end

--------------------------------------------------------------------------------
-- STRATEGIC PLACEMENT
--------------------------------------------------------------------------------

--[[
	Generate cover props for an area with strategic placement
]]
function EnvironmentalPropsGenerator.GenerateCoverProps(
	centerPosition: Vector3,
	radius: number,
	biome: BiomeData.BiomeType
): { Part | Model }
	local config = BiomeData.GetBiomeConfig(biome)
	if not config then return {} end

	local coverProps = config.coverProps
	if not coverProps or #coverProps == 0 then return {} end

	local props = {}
	local area = math.pi * radius * radius
	local count = math.floor(area / 10000 * DENSITY.coverProps * (config.groundDetails.debrisDensity or 0.5))

	print(`[EnvironmentalPropsGenerator] Generating {count} cover props for {biome}`)

	for _ = 1, count do
		-- Strategic placement: prefer corners and edges
		local angle: number
		local distance: number

		if math.random() < COVER_PLACEMENT.cornerBias then
			-- Place near edges
			angle = math.random() * math.pi * 2
			distance = radius * randomInRange(0.6, 0.95)
		else
			-- Random distribution
			angle = math.random() * math.pi * 2
			distance = radius * math.sqrt(math.random()) -- Square root for even distribution
		end

		local position = centerPosition + Vector3.new(
			math.cos(angle) * distance,
			0,
			math.sin(angle) * distance
		)

		-- Check if position is valid
		if isPositionValid(position, COVER_PLACEMENT.minDistanceFromOther) then
			local definition = pickRandom(coverProps)

			if math.random() < COVER_PLACEMENT.clusterChance then
				-- Create cluster
				local clusterCount = math.random(
					COVER_PLACEMENT.clusterCount[1],
					COVER_PLACEMENT.clusterCount[2]
				)
				local clusterProps = createPropCluster(
					definition,
					position,
					biome,
					clusterCount,
					COVER_PLACEMENT.clusterRadius
				)
				for _, prop in clusterProps do
					table.insert(props, prop)
				end
			else
				-- Single prop
				local prop = createProp(definition, position, biome)
				table.insert(props, prop)
			end
		end
	end

	-- Store for later reference
	generatedProps[biome .. "_cover"] = props

	return props
end

--[[
	Generate decorative props for atmosphere
]]
function EnvironmentalPropsGenerator.GenerateDecorativeProps(
	centerPosition: Vector3,
	radius: number,
	biome: BiomeData.BiomeType
): { Part | Model }
	local config = BiomeData.GetBiomeConfig(biome)
	if not config then return {} end

	local decorativeProps = config.decorativeProps
	if not decorativeProps or #decorativeProps == 0 then return {} end

	local props = {}
	local area = math.pi * radius * radius
	local count = math.floor(area / 10000 * DENSITY.decorativeProps * (config.groundDetails.grassDensity or 0.5))

	print(`[EnvironmentalPropsGenerator] Generating {count} decorative props for {biome}`)

	for _ = 1, count do
		local angle = math.random() * math.pi * 2
		local distance = radius * math.sqrt(math.random())

		local position = centerPosition + Vector3.new(
			math.cos(angle) * distance,
			0,
			math.sin(angle) * distance
		)

		local definition = pickRandom(decorativeProps)
		local prop = createProp(definition, position, biome)
		table.insert(props, prop)
	end

	generatedProps[biome .. "_decorative"] = props

	return props
end

--[[
	Generate ground debris (small scattered details)
]]
function EnvironmentalPropsGenerator.GenerateGroundDebris(
	centerPosition: Vector3,
	radius: number,
	biome: BiomeData.BiomeType
): { Part }
	local config = BiomeData.GetBiomeConfig(biome)
	if not config then return {} end

	local palette = config.colorPalette
	local groundDetails = config.groundDetails

	local debris = {}
	local area = math.pi * radius * radius
	local count = math.floor(area / 10000 * DENSITY.groundDebris * (groundDetails.debrisDensity or 0.5))

	-- Debris types based on biome
	local debrisTypes = {
		Jungle = {
			{ name = "LeafLitter", size = Vector3.new(2, 0.2, 2), material = Enum.Material.Grass, color = palette.secondary },
			{ name = "TwigPile", size = Vector3.new(1.5, 0.3, 1.5), material = Enum.Material.Wood, color = Color3.fromRGB(80, 60, 40) },
			{ name = "FallenFruit", size = Vector3.new(0.8, 0.8, 0.8), material = Enum.Material.SmoothPlastic, color = palette.accent },
		},
		Desert = {
			{ name = "BoneFragment", size = Vector3.new(1, 0.3, 2), material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(230, 220, 200) },
			{ name = "SandDrift", size = Vector3.new(3, 0.5, 2), material = Enum.Material.Sand, color = palette.primary },
			{ name = "DriedPlant", size = Vector3.new(1, 1.5, 1), material = Enum.Material.Grass, color = Color3.fromRGB(160, 140, 100) },
		},
		Mountains = {
			{ name = "IceChunk", size = Vector3.new(1.5, 1, 1.5), material = Enum.Material.Ice, color = Color3.fromRGB(200, 220, 255) },
			{ name = "SnowDrift", size = Vector3.new(3, 0.8, 2), material = Enum.Material.Snow, color = Color3.fromRGB(255, 255, 255) },
			{ name = "FrozenBranch", size = Vector3.new(0.5, 0.5, 3), material = Enum.Material.Wood, color = Color3.fromRGB(150, 160, 170) },
		},
		Volcanic = {
			{ name = "LavaRock", size = Vector3.new(1, 0.8, 1), material = Enum.Material.Basalt, color = Color3.fromRGB(40, 35, 35) },
			{ name = "AshPile", size = Vector3.new(2, 0.3, 2), material = Enum.Material.Slate, color = Color3.fromRGB(60, 60, 60) },
			{ name = "ObsidianShard", size = Vector3.new(0.5, 1.2, 0.5), material = Enum.Material.Glass, color = Color3.fromRGB(20, 20, 30) },
		},
		Swamp = {
			{ name = "MossClump", size = Vector3.new(1.5, 0.5, 1.5), material = Enum.Material.Grass, color = Color3.fromRGB(70, 90, 50) },
			{ name = "DeadLeaves", size = Vector3.new(2, 0.2, 2), material = Enum.Material.Grass, color = Color3.fromRGB(100, 80, 60) },
			{ name = "MushroomCluster", size = Vector3.new(1, 1, 1), material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(200, 180, 150) },
		},
		Coast = {
			{ name = "Seaweed", size = Vector3.new(1.5, 0.3, 2), material = Enum.Material.Grass, color = Color3.fromRGB(50, 100, 80) },
			{ name = "ShellCluster", size = Vector3.new(1, 0.3, 1), material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(255, 240, 220) },
			{ name = "SandRipple", size = Vector3.new(3, 0.2, 2), material = Enum.Material.Sand, color = palette.primary },
		},
		Research = {
			{ name = "BrokenGlass", size = Vector3.new(1, 0.1, 1), material = Enum.Material.Glass, color = Color3.fromRGB(200, 220, 230) },
			{ name = "MetalScrap", size = Vector3.new(1.5, 0.3, 1), material = Enum.Material.Metal, color = Color3.fromRGB(100, 100, 110) },
			{ name = "PaperDebris", size = Vector3.new(1, 0.1, 1.5), material = Enum.Material.SmoothPlastic, color = Color3.fromRGB(240, 240, 230) },
		},
		Plains = {
			{ name = "GrassClump", size = Vector3.new(1.5, 1, 1.5), material = Enum.Material.Grass, color = palette.primary },
			{ name = "WildflowerPatch", size = Vector3.new(2, 0.8, 2), material = Enum.Material.Grass, color = palette.accent },
			{ name = "Pebbles", size = Vector3.new(1, 0.3, 1), material = Enum.Material.Pebble, color = Color3.fromRGB(140, 130, 120) },
		},
	}

	local biomeDebris = debrisTypes[biome] or debrisTypes.Plains

	for _ = 1, count do
		local angle = math.random() * math.pi * 2
		local distance = radius * math.sqrt(math.random())

		local position = centerPosition + Vector3.new(
			math.cos(angle) * distance,
			0,
			math.sin(angle) * distance
		)

		local debrisType = pickRandom(biomeDebris)

		local part = Instance.new("Part")
		part.Name = debrisType.name
		part.Anchored = true
		part.CanCollide = false
		part.Size = debrisType.size * randomInRange(0.7, 1.3)
		part.Material = debrisType.material
		part.Color = debrisType.color
		part.CastShadow = false

		local groundY = getGroundLevel(position.X, position.Z, position.Y)
		part.CFrame = CFrame.new(position.X, groundY + part.Size.Y / 2, position.Z)
			* CFrame.Angles(
				math.rad(randomInRange(-5, 5)),
				math.rad(randomInRange(0, 360)),
				math.rad(randomInRange(-5, 5))
			)

		part:SetAttribute("Debris", true)
		part:SetAttribute("Biome", biome)

		-- Parent to debris folder
		local folder = workspace:FindFirstChild("GroundDebris")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "GroundDebris"
			folder.Parent = workspace
		end

		part.Parent = folder
		table.insert(debris, part)

		yieldIfNeeded()
	end

	generatedProps[biome .. "_debris"] = debris

	return debris
end

--[[
	Generate ambient particle emitters for a biome
]]
function EnvironmentalPropsGenerator.GenerateAmbientParticles(
	centerPosition: Vector3,
	radius: number,
	biome: BiomeData.BiomeType
): { Part }
	local particles = BiomeData.GetAmbientParticles(biome)
	if not particles or #particles == 0 then return {} end

	local emitters = {}

	-- Create particle emitter zones
	local emitterCount = math.floor(radius / 100) + 2

	for i = 1, emitterCount do
		local angle = (i / emitterCount) * math.pi * 2
		local distance = radius * randomInRange(0.3, 0.8)

		local position = centerPosition + Vector3.new(
			math.cos(angle) * distance,
			10, -- Elevated for particle spread
			math.sin(angle) * distance
		)

		local emitterPart = Instance.new("Part")
		emitterPart.Name = "AmbientEmitter_" .. biome
		emitterPart.Anchored = true
		emitterPart.CanCollide = false
		emitterPart.Transparency = 1
		emitterPart.Size = Vector3.new(20, 1, 20) -- Large area emitter
		emitterPart.Position = position

		-- Add particle emitters based on biome config
		for _, particleConfig in ipairs(particles) do
			if particleConfig.enabled then
				local emitter = Instance.new("ParticleEmitter")
				emitter.Name = particleConfig.name
				emitter.Color = particleConfig.color
				emitter.Size = particleConfig.size
				emitter.Lifetime = particleConfig.lifetime
				emitter.Rate = particleConfig.rate
				emitter.Speed = particleConfig.speed
				emitter.SpreadAngle = particleConfig.spreadAngle
				emitter.RotSpeed = NumberRange.new(-30, 30)
				emitter.Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.3),
					NumberSequenceKeypoint.new(0.8, 0.5),
					NumberSequenceKeypoint.new(1, 1),
				})
				emitter.Parent = emitterPart
			end
		end

		-- Parent to folder
		local folder = workspace:FindFirstChild("AmbientParticles")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "AmbientParticles"
			folder.Parent = workspace
		end

		emitterPart.Parent = folder
		table.insert(emitters, emitterPart)

		yieldIfNeeded()
	end

	return emitters
end

--------------------------------------------------------------------------------
-- LANDMARK GENERATION
--------------------------------------------------------------------------------

--[[
	Generate landmark structure for navigation
]]
function EnvironmentalPropsGenerator.GenerateLandmark(
	landmarkConfig: { name: string, description: string, radius: number, visibility: number },
	position: Vector3,
	biome: BiomeData.BiomeType
): Model
	local landmark = Instance.new("Model")
	landmark.Name = "Landmark_" .. landmarkConfig.name

	-- Create base structure based on landmark type
	local baseHeight = landmarkConfig.visibility / 20
	local baseWidth = landmarkConfig.radius / 2

	-- Main tower/structure
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Anchored = true
	base.CanCollide = true
	base.Size = Vector3.new(baseWidth, baseHeight, baseWidth)

	local groundY = getGroundLevel(position.X, position.Z, position.Y)
	base.CFrame = CFrame.new(position.X, groundY + baseHeight / 2, position.Z)

	-- Color based on biome
	local palette = BiomeData.GetColorPalette(biome)
	base.Color = palette.secondary
	base.Material = Enum.Material.Rock

	base.Parent = landmark

	-- Add beacon light for visibility
	local beaconLight = Instance.new("Part")
	beaconLight.Name = "BeaconLight"
	beaconLight.Anchored = true
	beaconLight.CanCollide = false
	beaconLight.Size = Vector3.new(baseWidth * 0.5, baseWidth * 0.5, baseWidth * 0.5)
	beaconLight.Shape = Enum.PartType.Ball
	beaconLight.Position = base.Position + Vector3.new(0, baseHeight / 2 + 2, 0)
	beaconLight.Material = Enum.Material.Neon
	beaconLight.Color = palette.accent
	beaconLight.Parent = landmark

	-- Add point light
	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = landmarkConfig.visibility / 10
	light.Color = palette.accent
	light.Parent = beaconLight

	-- Set attributes
	landmark:SetAttribute("LandmarkName", landmarkConfig.name)
	landmark:SetAttribute("Description", landmarkConfig.description)
	landmark:SetAttribute("Biome", biome)

	landmark.PrimaryPart = base

	-- Parent to folder
	local folder = workspace:FindFirstChild("Landmarks")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Landmarks"
		folder.Parent = workspace
	end

	landmark.Parent = folder

	return landmark
end

--------------------------------------------------------------------------------
-- MAIN GENERATION FUNCTIONS
--------------------------------------------------------------------------------

--[[
	Generate all environmental props for an area
]]
function EnvironmentalPropsGenerator.GenerateAreaProps(
	centerPosition: Vector3,
	radius: number,
	biome: BiomeData.BiomeType
)
	print(`[EnvironmentalPropsGenerator] Generating props for {biome} at {centerPosition}`)

	-- Generate in order of importance
	local coverProps = EnvironmentalPropsGenerator.GenerateCoverProps(centerPosition, radius, biome)
	local decorativeProps = EnvironmentalPropsGenerator.GenerateDecorativeProps(centerPosition, radius, biome)
	local debris = EnvironmentalPropsGenerator.GenerateGroundDebris(centerPosition, radius, biome)
	local _particles = EnvironmentalPropsGenerator.GenerateAmbientParticles(centerPosition, radius, biome)

	-- Generate landmarks
	local landmarks = BiomeData.GetLandmarks(biome)
	for _, landmarkConfig in ipairs(landmarks) do
		local landmarkPos = landmarkConfig.position or (centerPosition + Vector3.new(
			randomInRange(-radius * 0.5, radius * 0.5),
			0,
			randomInRange(-radius * 0.5, radius * 0.5)
		))
		EnvironmentalPropsGenerator.GenerateLandmark(landmarkConfig, landmarkPos, biome)
	end

	print(`[EnvironmentalPropsGenerator] Generated {#coverProps} cover, {#decorativeProps} decorative, {#debris} debris props for {biome}`)
end

--[[
	Generate props for the entire map based on biome regions
]]
function EnvironmentalPropsGenerator.GenerateMapProps()
	print("[EnvironmentalPropsGenerator] Starting map prop generation...")

	-- Generate for each main biome region
	local biomeRegions = {
		{ biome = "Jungle", center = Vector3.new(1000, 0, 1000), radius = 800 },
		{ biome = "Desert", center = Vector3.new(-1000, 0, 0), radius = 800 },
		{ biome = "Mountains", center = Vector3.new(0, 0, -1000), radius = 800 },
		{ biome = "Plains", center = Vector3.new(-1200, 0, 0), radius = 500 },
		{ biome = "Volcanic", center = Vector3.new(0, 0, -1400), radius = 400 },
		{ biome = "Swamp", center = Vector3.new(1200, 0, 0), radius = 500 },
		{ biome = "Coast", center = Vector3.new(0, 0, 1400), radius = 600 },
	}

	for _, region in ipairs(biomeRegions) do
		EnvironmentalPropsGenerator.GenerateAreaProps(region.center, region.radius, region.biome :: BiomeData.BiomeType)
		task.wait(0.1) -- Yield between biomes
	end

	print("[EnvironmentalPropsGenerator] Map prop generation complete!")
end

--[[
	Clear all generated props (for reset)
]]
function EnvironmentalPropsGenerator.ClearAllProps()
	-- Clear folders
	local folders = { "EnvironmentalProps", "GroundDebris", "AmbientParticles", "Landmarks" }
	for _, folderName in ipairs(folders) do
		local folder = workspace:FindFirstChild(folderName)
		if folder then
			folder:ClearAllChildren()
		end
	end

	generatedProps = {}
	propCounter = 0

	print("[EnvironmentalPropsGenerator] Cleared all props")
end

--[[
	Reset for new match
]]
function EnvironmentalPropsGenerator.Reset()
	-- Only clear destructible props that were destroyed
	for _biome, props in pairs(generatedProps) do
		for i = #props, 1, -1 do
			local prop = props[i]
			if not prop or not prop.Parent then
				table.remove(props, i)
			elseif prop:GetAttribute("Destructible") and prop:GetAttribute("Health") <= 0 then
				-- Respawn destroyed prop
				local health = prop:GetAttribute("MaxHealth")
				prop:SetAttribute("Health", health)
				prop.Transparency = 0
			end
		end
	end

	print("[EnvironmentalPropsGenerator] Reset complete")
end

return EnvironmentalPropsGenerator
