--!strict
--[[
	BiomeData.lua
	=============
	Comprehensive biome definitions for Dino Royale
	Includes terrain, atmosphere, props, cover, and environmental details

	Based on PVP map design best practices:
	- Strategic cover placement
	- Verticality with risk/reward
	- Clear landmarks for navigation
	- 3-5 color palette per biome
	- Layered visual depth
]]

-- Main terrain biomes + POI biomes
export type BiomeType = "Jungle" | "Desert" | "Mountains" | "Plains" | "Volcanic" | "Swamp" | "Coast" | "Research"

-- Prop types for cover and environment
export type PropDefinition = {
	name: string,
	model: string?, -- Asset ID or primitive type
	size: Vector3,
	material: Enum.Material,
	color: Color3,
	canCollide: boolean,
	provideCover: boolean, -- Can players hide behind it?
	destructible: boolean,
	health: number?, -- For destructible props
}

-- Atmosphere settings
export type AtmosphereSettings = {
	density: number,
	offset: number,
	color: Color3,
	decay: Color3,
	glare: number,
	haze: number,
}

-- Lighting settings
export type LightingSettings = {
	ambient: Color3,
	outdoorAmbient: Color3,
	brightness: number,
	colorShift_Top: Color3,
	colorShift_Bottom: Color3,
	environmentDiffuseScale: number,
	environmentSpecularScale: number,
	globalShadows: boolean,
	shadowSoftness: number,
}

-- Ground detail settings
export type GroundDetailSettings = {
	grassDensity: number, -- 0-1
	rockDensity: number,
	debrisDensity: number,
	puddleDensity: number,
	crackDensity: number,
}

-- Particle effect settings
export type ParticleSettings = {
	name: string,
	enabled: boolean,
	rate: number,
	color: ColorSequence,
	size: NumberSequence,
	lifetime: NumberRange,
	speed: NumberRange,
	spreadAngle: Vector2,
}

export type BiomeConfig = {
	name: string,
	displayName: string,
	description: string,

	-- Angle-based sector (radians, map divided into thirds)
	sector: {
		startAngle: number,
		endAngle: number,
	},

	-- Minimap display
	minimapColor: Color3,

	-- Loot settings
	lootTier: string,
	lootDensity: number,

	-- Dinosaur spawning
	dinosaurTypes: { string },
	dinosaurDensity: number,

	-- Terrain materials
	primaryMaterial: Enum.Material,
	secondaryMaterial: Enum.Material,
	peakMaterial: Enum.Material,
	transitionMaterial: Enum.Material?, -- For biome edges

	-- Color palette (3-5 colors for visual cohesion)
	colorPalette: {
		primary: Color3,
		secondary: Color3,
		accent: Color3,
		highlight: Color3?,
		shadow: Color3?,
	},

	-- Environment
	ambientSound: string,
	weatherEffects: { string },
	hazards: { string },

	-- Atmosphere & Lighting
	atmosphere: AtmosphereSettings,
	lighting: LightingSettings,
	fogEnabled: boolean,
	fogStart: number,
	fogEnd: number,
	fogColor: Color3,

	-- Ground details
	groundDetails: GroundDetailSettings,

	-- Cover props (for PVP gameplay)
	coverProps: { PropDefinition },

	-- Decorative props
	decorativeProps: { PropDefinition },

	-- Ambient particles
	ambientParticles: { ParticleSettings },

	-- Landmarks (for navigation)
	landmarks: { {
		name: string,
		description: string,
		position: Vector3?,
		radius: number,
		visibility: number, -- How far it can be seen
	} },

	-- Verticality points (towers, cliffs, etc.)
	verticalitySpots: { {
		type: string, -- "tower" | "cliff" | "platform" | "roof"
		heightAdvantage: number,
		riskLevel: number, -- 1-5
	} },

	-- Sound design
	soundscape: {
		ambientVolume: number,
		musicIntensity: number,
		reverbPreset: string,
	},
}

local BiomeData = {}

-- Map configuration (4km x 4km per GDD Section 3.3)
BiomeData.MapSize = {
	width = 4000,
	height = 4000,
}
BiomeData.MapCenter = Vector3.new(0, 0, 0)

--------------------------------------------------------------------------------
-- SHARED PROP DEFINITIONS
--------------------------------------------------------------------------------

-- Cover props used across multiple biomes
local COVER_PROPS = {
	-- Barrels and containers
	MetalBarrel = {
		name = "MetalBarrel",
		size = Vector3.new(3, 4, 3),
		material = Enum.Material.Metal,
		color = Color3.fromRGB(80, 80, 90),
		canCollide = true,
		provideCover = true,
		destructible = true,
		health = 100,
	},
	WoodCrate = {
		name = "WoodCrate",
		size = Vector3.new(4, 4, 4),
		material = Enum.Material.Wood,
		color = Color3.fromRGB(139, 90, 43),
		canCollide = true,
		provideCover = true,
		destructible = true,
		health = 75,
	},
	MetalCrate = {
		name = "MetalCrate",
		size = Vector3.new(5, 5, 5),
		material = Enum.Material.DiamondPlate,
		color = Color3.fromRGB(100, 100, 110),
		canCollide = true,
		provideCover = true,
		destructible = false,
		health = 300,
	},
	ShippingContainer = {
		name = "ShippingContainer",
		size = Vector3.new(12, 8, 24),
		material = Enum.Material.Metal,
		color = Color3.fromRGB(150, 50, 50),
		canCollide = true,
		provideCover = true,
		destructible = false,
	},

	-- Natural cover
	Boulder = {
		name = "Boulder",
		size = Vector3.new(8, 6, 8),
		material = Enum.Material.Rock,
		color = Color3.fromRGB(120, 110, 100),
		canCollide = true,
		provideCover = true,
		destructible = false,
	},
	FallenLog = {
		name = "FallenLog",
		size = Vector3.new(3, 3, 15),
		material = Enum.Material.Wood,
		color = Color3.fromRGB(89, 60, 31),
		canCollide = true,
		provideCover = true,
		destructible = false,
	},
	ThickBush = {
		name = "ThickBush",
		size = Vector3.new(5, 4, 5),
		material = Enum.Material.LeafyGrass,
		color = Color3.fromRGB(34, 100, 34),
		canCollide = false,
		provideCover = true, -- Visual cover
		destructible = false,
	},

	-- Structural cover
	ConcreteBarrier = {
		name = "ConcreteBarrier",
		size = Vector3.new(8, 4, 2),
		material = Enum.Material.Concrete,
		color = Color3.fromRGB(180, 180, 180),
		canCollide = true,
		provideCover = true,
		destructible = false,
	},
	SandbagWall = {
		name = "SandbagWall",
		size = Vector3.new(6, 3, 2),
		material = Enum.Material.Fabric,
		color = Color3.fromRGB(194, 178, 128),
		canCollide = true,
		provideCover = true,
		destructible = true,
		health = 150,
	},
	WreckedVehicle = {
		name = "WreckedVehicle",
		size = Vector3.new(8, 5, 16),
		material = Enum.Material.Metal,
		color = Color3.fromRGB(60, 70, 60),
		canCollide = true,
		provideCover = true,
		destructible = false,
	},
}

-- Decorative props
local DECORATIVE_PROPS = {
	-- Jungle
	GiantFern = {
		name = "GiantFern",
		size = Vector3.new(6, 8, 6),
		material = Enum.Material.LeafyGrass,
		color = Color3.fromRGB(34, 139, 34),
		canCollide = false,
		provideCover = false,
		destructible = false,
	},
	MossyCrate = {
		name = "MossyCrate",
		size = Vector3.new(3, 3, 3),
		material = Enum.Material.Wood,
		color = Color3.fromRGB(71, 90, 43),
		canCollide = true,
		provideCover = true,
		destructible = true,
		health = 50,
	},
	VineCluster = {
		name = "VineCluster",
		size = Vector3.new(2, 15, 2),
		material = Enum.Material.Grass,
		color = Color3.fromRGB(34, 80, 34),
		canCollide = false,
		provideCover = false,
		destructible = false,
	},

	-- Desert
	Cactus = {
		name = "Cactus",
		size = Vector3.new(3, 12, 3),
		material = Enum.Material.Grass,
		color = Color3.fromRGB(60, 120, 60),
		canCollide = true,
		provideCover = true,
		destructible = false,
	},
	DesertSkull = {
		name = "DesertSkull",
		size = Vector3.new(4, 3, 5),
		material = Enum.Material.SmoothPlastic,
		color = Color3.fromRGB(240, 230, 210),
		canCollide = true,
		provideCover = false,
		destructible = false,
	},
	DriedBush = {
		name = "DriedBush",
		size = Vector3.new(4, 3, 4),
		material = Enum.Material.Grass,
		color = Color3.fromRGB(180, 160, 100),
		canCollide = false,
		provideCover = false,
		destructible = false,
	},

	-- Volcanic
	LavaRock = {
		name = "LavaRock",
		size = Vector3.new(6, 5, 6),
		material = Enum.Material.Basalt,
		color = Color3.fromRGB(40, 35, 35),
		canCollide = true,
		provideCover = true,
		destructible = false,
	},
	SteamVent = {
		name = "SteamVent",
		size = Vector3.new(3, 1, 3),
		material = Enum.Material.CrackedLava,
		color = Color3.fromRGB(80, 40, 20),
		canCollide = false,
		provideCover = false,
		destructible = false,
	},
	ObsidianSpike = {
		name = "ObsidianSpike",
		size = Vector3.new(2, 8, 2),
		material = Enum.Material.Glass,
		color = Color3.fromRGB(20, 20, 30),
		canCollide = true,
		provideCover = true,
		destructible = false,
	},

	-- Swamp
	DeadStump = {
		name = "DeadStump",
		size = Vector3.new(4, 3, 4),
		material = Enum.Material.Wood,
		color = Color3.fromRGB(60, 50, 40),
		canCollide = true,
		provideCover = true,
		destructible = false,
	},
	SwampReeds = {
		name = "SwampReeds",
		size = Vector3.new(3, 8, 3),
		material = Enum.Material.Grass,
		color = Color3.fromRGB(85, 107, 47),
		canCollide = false,
		provideCover = true,
		destructible = false,
	},
	MuddyPuddle = {
		name = "MuddyPuddle",
		size = Vector3.new(8, 0.3, 8),
		material = Enum.Material.Mud,
		color = Color3.fromRGB(80, 70, 50),
		canCollide = false,
		provideCover = false,
		destructible = false,
	},

	-- Research
	BrokenTerminal = {
		name = "BrokenTerminal",
		size = Vector3.new(3, 5, 2),
		material = Enum.Material.Metal,
		color = Color3.fromRGB(60, 60, 70),
		canCollide = true,
		provideCover = true,
		destructible = false,
	},
	LabEquipment = {
		name = "LabEquipment",
		size = Vector3.new(4, 6, 3),
		material = Enum.Material.Metal,
		color = Color3.fromRGB(200, 200, 210),
		canCollide = true,
		provideCover = true,
		destructible = true,
		health = 100,
	},
	BiohazardBarrel = {
		name = "BiohazardBarrel",
		size = Vector3.new(3, 4, 3),
		material = Enum.Material.Metal,
		color = Color3.fromRGB(255, 200, 0),
		canCollide = true,
		provideCover = true,
		destructible = true,
		health = 80,
	},
}

--------------------------------------------------------------------------------
-- BIOME DEFINITIONS
--------------------------------------------------------------------------------

BiomeData.Biomes = {
	Jungle = {
		name = "Jungle",
		displayName = "Primordial Jungle",
		description = "Dense tropical jungle teeming with raptors, towering trees, and ancient ruins",

		sector = {
			startAngle = 0,
			endAngle = math.pi * 2/3, -- 0 to 120
		},

		minimapColor = Color3.fromRGB(34, 139, 34),

		lootTier = "Medium",
		lootDensity = 1.2,

		dinosaurTypes = { "Velociraptor", "Dilophosaurus", "Compsognathus" },
		dinosaurDensity = 1.5,

		primaryMaterial = Enum.Material.LeafyGrass,
		secondaryMaterial = Enum.Material.Grass,
		peakMaterial = Enum.Material.Rock,
		transitionMaterial = Enum.Material.Ground,

		-- Jungle color palette (lush greens with earthy accents)
		colorPalette = {
			primary = Color3.fromRGB(34, 139, 34),    -- Forest green
			secondary = Color3.fromRGB(85, 107, 47),  -- Dark olive
			accent = Color3.fromRGB(255, 105, 180),   -- Tropical flowers
			highlight = Color3.fromRGB(50, 205, 50),  -- Lime accents
			shadow = Color3.fromRGB(0, 60, 0),        -- Deep shadow
		},

		ambientSound = "JungleAmbient",
		weatherEffects = { "Rain", "Fog", "Humidity" },
		hazards = { "RaptorNest", "QuicksandPit", "VenomousPlants" },

		-- Misty, humid atmosphere
		atmosphere = {
			density = 0.4,
			offset = 0.1,
			color = Color3.fromRGB(180, 200, 180),
			decay = Color3.fromRGB(100, 140, 100),
			glare = 0.2,
			haze = 0.5,
		},

		lighting = {
			ambient = Color3.fromRGB(80, 100, 80),
			outdoorAmbient = Color3.fromRGB(100, 130, 100),
			brightness = 1.5,
			colorShift_Top = Color3.fromRGB(180, 220, 180),
			colorShift_Bottom = Color3.fromRGB(40, 60, 40),
			environmentDiffuseScale = 0.8,
			environmentSpecularScale = 0.6,
			globalShadows = true,
			shadowSoftness = 0.4,
		},

		fogEnabled = true,
		fogStart = 100,
		fogEnd = 800,
		fogColor = Color3.fromRGB(180, 200, 180),

		groundDetails = {
			grassDensity = 0.9,
			rockDensity = 0.4,
			debrisDensity = 0.6,
			puddleDensity = 0.3,
			crackDensity = 0.1,
		},

		coverProps = {
			COVER_PROPS.Boulder,
			COVER_PROPS.FallenLog,
			COVER_PROPS.ThickBush,
			COVER_PROPS.WoodCrate,
			COVER_PROPS.WreckedVehicle,
		},

		decorativeProps = {
			DECORATIVE_PROPS.GiantFern,
			DECORATIVE_PROPS.MossyCrate,
			DECORATIVE_PROPS.VineCluster,
		},

		ambientParticles = {
			{
				name = "Spores",
				enabled = true,
				rate = 3,
				color = ColorSequence.new(Color3.fromRGB(200, 255, 200)),
				size = NumberSequence.new(0.3),
				lifetime = NumberRange.new(5, 10),
				speed = NumberRange.new(0.5, 2),
				spreadAngle = Vector2.new(180, 180),
			},
			{
				name = "Fireflies",
				enabled = true,
				rate = 1,
				color = ColorSequence.new(Color3.fromRGB(200, 255, 100)),
				size = NumberSequence.new(0.2),
				lifetime = NumberRange.new(3, 8),
				speed = NumberRange.new(1, 3),
				spreadAngle = Vector2.new(360, 360),
			},
		},

		landmarks = {
			{
				name = "Ancient Temple",
				description = "Crumbling stone temple rising above the canopy",
				radius = 80,
				visibility = 500,
			},
			{
				name = "Giant Kapok Tree",
				description = "Massive tree visible from across the jungle",
				radius = 40,
				visibility = 400,
			},
			{
				name = "Waterfall Cliff",
				description = "Thundering waterfall with caves behind",
				radius = 60,
				visibility = 350,
			},
		},

		verticalitySpots = {
			{ type = "cliff", heightAdvantage = 15, riskLevel = 2 },
			{ type = "platform", heightAdvantage = 10, riskLevel = 3 },
			{ type = "roof", heightAdvantage = 8, riskLevel = 4 },
		},

		soundscape = {
			ambientVolume = 0.7,
			musicIntensity = 0.5,
			reverbPreset = "Forest",
		},
	},

	Desert = {
		name = "Desert",
		displayName = "Scorched Dunes",
		description = "Vast desert expanse with ancient ruins and lurking predators",

		sector = {
			startAngle = math.pi * 2/3,
			endAngle = math.pi * 4/3, -- 120 to 240
		},

		minimapColor = Color3.fromRGB(210, 180, 140),

		lootTier = "Low",
		lootDensity = 0.8,

		dinosaurTypes = { "Gallimimus", "Pteranodon", "Carnotaurus" },
		dinosaurDensity = 0.7,

		primaryMaterial = Enum.Material.Sand,
		secondaryMaterial = Enum.Material.Sandstone,
		peakMaterial = Enum.Material.Sandstone,
		transitionMaterial = Enum.Material.Ground,

		-- Desert palette (warm tans with orange accents)
		colorPalette = {
			primary = Color3.fromRGB(210, 180, 140),   -- Tan
			secondary = Color3.fromRGB(194, 154, 108), -- Darker sand
			accent = Color3.fromRGB(255, 140, 0),      -- Sunset orange
			highlight = Color3.fromRGB(255, 220, 180), -- Bright sand
			shadow = Color3.fromRGB(120, 80, 40),      -- Deep shadow
		},

		ambientSound = "DesertAmbient",
		weatherEffects = { "Sandstorm", "HeatWave", "DustDevil" },
		hazards = { "Heatstroke", "Quicksand", "Scorpions" },

		-- Hazy, hot atmosphere
		atmosphere = {
			density = 0.25,
			offset = 0.2,
			color = Color3.fromRGB(255, 240, 200),
			decay = Color3.fromRGB(200, 160, 100),
			glare = 0.8,
			haze = 0.7,
		},

		lighting = {
			ambient = Color3.fromRGB(180, 160, 120),
			outdoorAmbient = Color3.fromRGB(220, 200, 160),
			brightness = 2.5,
			colorShift_Top = Color3.fromRGB(255, 240, 200),
			colorShift_Bottom = Color3.fromRGB(180, 140, 80),
			environmentDiffuseScale = 1.2,
			environmentSpecularScale = 0.9,
			globalShadows = true,
			shadowSoftness = 0.2,
		},

		fogEnabled = true,
		fogStart = 200,
		fogEnd = 1200,
		fogColor = Color3.fromRGB(255, 240, 210),

		groundDetails = {
			grassDensity = 0.1,
			rockDensity = 0.5,
			debrisDensity = 0.3,
			puddleDensity = 0.0,
			crackDensity = 0.6,
		},

		coverProps = {
			COVER_PROPS.Boulder,
			COVER_PROPS.SandbagWall,
			COVER_PROPS.WreckedVehicle,
			COVER_PROPS.ConcreteBarrier,
		},

		decorativeProps = {
			DECORATIVE_PROPS.Cactus,
			DECORATIVE_PROPS.DesertSkull,
			DECORATIVE_PROPS.DriedBush,
		},

		ambientParticles = {
			{
				name = "DustMotes",
				enabled = true,
				rate = 5,
				color = ColorSequence.new(Color3.fromRGB(220, 200, 160)),
				size = NumberSequence.new(0.5),
				lifetime = NumberRange.new(3, 8),
				speed = NumberRange.new(2, 5),
				spreadAngle = Vector2.new(90, 30),
			},
			{
				name = "HeatShimmer",
				enabled = true,
				rate = 2,
				color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
				size = NumberSequence.new(1),
				lifetime = NumberRange.new(1, 3),
				speed = NumberRange.new(0.5, 1),
				spreadAngle = Vector2.new(10, 180),
			},
		},

		landmarks = {
			{
				name = "Stone Pillars",
				description = "Ancient weathered stone columns",
				radius = 50,
				visibility = 600,
			},
			{
				name = "Crashed Plane",
				description = "Old cargo plane half-buried in sand",
				radius = 40,
				visibility = 400,
			},
			{
				name = "Oasis",
				description = "Rare water source with palm trees",
				radius = 60,
				visibility = 450,
			},
		},

		verticalitySpots = {
			{ type = "cliff", heightAdvantage = 20, riskLevel = 3 },
			{ type = "tower", heightAdvantage = 15, riskLevel = 4 },
			{ type = "platform", heightAdvantage = 8, riskLevel = 2 },
		},

		soundscape = {
			ambientVolume = 0.4,
			musicIntensity = 0.3,
			reverbPreset = "OpenAir",
		},
	},

	Mountains = {
		name = "Mountains",
		displayName = "Frost Peaks",
		description = "Treacherous snowy peaks with apex predators and high-value loot",

		sector = {
			startAngle = math.pi * 4/3,
			endAngle = math.pi * 2, -- 240 to 360
		},

		minimapColor = Color3.fromRGB(200, 200, 220),

		lootTier = "High",
		lootDensity = 1.5,

		dinosaurTypes = { "TRex", "Triceratops", "Indoraptor" },
		dinosaurDensity = 1.0,

		primaryMaterial = Enum.Material.Rock,
		secondaryMaterial = Enum.Material.Slate,
		peakMaterial = Enum.Material.Snow,
		transitionMaterial = Enum.Material.Ground,

		-- Cold palette (blues and whites with purple shadows)
		colorPalette = {
			primary = Color3.fromRGB(200, 200, 220),   -- Cool grey
			secondary = Color3.fromRGB(180, 190, 210), -- Blue-grey
			accent = Color3.fromRGB(100, 150, 255),    -- Ice blue
			highlight = Color3.fromRGB(255, 255, 255), -- Snow white
			shadow = Color3.fromRGB(80, 80, 120),      -- Purple shadow
		},

		ambientSound = "MountainAmbient",
		weatherEffects = { "Snow", "Wind", "Blizzard", "IceFog" },
		hazards = { "Avalanche", "IcySlope", "Frostbite", "ThinIce" },

		-- Cold, crisp atmosphere
		atmosphere = {
			density = 0.35,
			offset = 0.15,
			color = Color3.fromRGB(200, 210, 230),
			decay = Color3.fromRGB(150, 160, 200),
			glare = 0.5,
			haze = 0.3,
		},

		lighting = {
			ambient = Color3.fromRGB(150, 160, 180),
			outdoorAmbient = Color3.fromRGB(180, 190, 210),
			brightness = 2.0,
			colorShift_Top = Color3.fromRGB(200, 220, 255),
			colorShift_Bottom = Color3.fromRGB(100, 110, 140),
			environmentDiffuseScale = 1.0,
			environmentSpecularScale = 1.2,
			globalShadows = true,
			shadowSoftness = 0.3,
		},

		fogEnabled = true,
		fogStart = 150,
		fogEnd = 600,
		fogColor = Color3.fromRGB(220, 230, 245),

		groundDetails = {
			grassDensity = 0.2,
			rockDensity = 0.7,
			debrisDensity = 0.4,
			puddleDensity = 0.1, -- Ice
			crackDensity = 0.3,
		},

		coverProps = {
			COVER_PROPS.Boulder,
			COVER_PROPS.MetalCrate,
			COVER_PROPS.ConcreteBarrier,
			COVER_PROPS.WreckedVehicle,
			COVER_PROPS.ShippingContainer,
		},

		decorativeProps = {
			{
				name = "IceFormation",
				size = Vector3.new(5, 8, 4),
				material = Enum.Material.Ice,
				color = Color3.fromRGB(200, 220, 255),
				canCollide = true,
				provideCover = true,
				destructible = false,
			},
			{
				name = "FrozenTree",
				size = Vector3.new(4, 15, 4),
				material = Enum.Material.Wood,
				color = Color3.fromRGB(180, 190, 200),
				canCollide = true,
				provideCover = true,
				destructible = false,
			},
		},

		ambientParticles = {
			{
				name = "Snowfall",
				enabled = true,
				rate = 15,
				color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
				size = NumberSequence.new(0.3),
				lifetime = NumberRange.new(5, 10),
				speed = NumberRange.new(3, 8),
				spreadAngle = Vector2.new(30, 180),
			},
			{
				name = "IceSparkle",
				enabled = true,
				rate = 2,
				color = ColorSequence.new(Color3.fromRGB(200, 230, 255)),
				size = NumberSequence.new(0.1),
				lifetime = NumberRange.new(0.5, 1.5),
				speed = NumberRange.new(0, 0.5),
				spreadAngle = Vector2.new(360, 360),
			},
		},

		landmarks = {
			{
				name = "Summit Tower",
				description = "Communication tower at the highest peak",
				radius = 30,
				visibility = 800,
			},
			{
				name = "Glacier Cave",
				description = "Massive ice cave entrance",
				radius = 50,
				visibility = 400,
			},
			{
				name = "Frozen Waterfall",
				description = "Massive frozen cascade of ice",
				radius = 40,
				visibility = 500,
			},
		},

		verticalitySpots = {
			{ type = "cliff", heightAdvantage = 30, riskLevel = 4 },
			{ type = "tower", heightAdvantage = 25, riskLevel = 5 },
			{ type = "platform", heightAdvantage = 12, riskLevel = 3 },
		},

		soundscape = {
			ambientVolume = 0.5,
			musicIntensity = 0.6,
			reverbPreset = "Mountains",
		},
	},

	-- POI-specific biomes
	Plains = {
		name = "Plains",
		displayName = "Herbivore Valley",
		description = "Open grasslands with scattered outposts and grazing dinosaurs",

		sector = { startAngle = 0, endAngle = 0 },

		minimapColor = Color3.fromRGB(144, 238, 144),

		lootTier = "Medium",
		lootDensity = 1.0,

		dinosaurTypes = { "Gallimimus", "Triceratops", "Parasaurolophus" },
		dinosaurDensity = 0.8,

		primaryMaterial = Enum.Material.Grass,
		secondaryMaterial = Enum.Material.Ground,
		peakMaterial = Enum.Material.Rock,

		colorPalette = {
			primary = Color3.fromRGB(144, 238, 144),
			secondary = Color3.fromRGB(107, 142, 35),
			accent = Color3.fromRGB(255, 215, 0),
			highlight = Color3.fromRGB(200, 255, 150),
			shadow = Color3.fromRGB(60, 80, 40),
		},

		ambientSound = "PlainsAmbient",
		weatherEffects = { "Wind", "LightRain" },
		hazards = { "Stampede" },

		atmosphere = {
			density = 0.2,
			offset = 0.05,
			color = Color3.fromRGB(200, 220, 200),
			decay = Color3.fromRGB(150, 180, 150),
			glare = 0.3,
			haze = 0.2,
		},

		lighting = {
			ambient = Color3.fromRGB(140, 160, 140),
			outdoorAmbient = Color3.fromRGB(180, 200, 180),
			brightness = 2.2,
			colorShift_Top = Color3.fromRGB(200, 230, 200),
			colorShift_Bottom = Color3.fromRGB(80, 100, 80),
			environmentDiffuseScale = 1.0,
			environmentSpecularScale = 0.8,
			globalShadows = true,
			shadowSoftness = 0.3,
		},

		fogEnabled = false,
		fogStart = 500,
		fogEnd = 2000,
		fogColor = Color3.fromRGB(200, 220, 200),

		groundDetails = {
			grassDensity = 0.95,
			rockDensity = 0.2,
			debrisDensity = 0.1,
			puddleDensity = 0.15,
			crackDensity = 0.05,
		},

		coverProps = {
			COVER_PROPS.Boulder,
			COVER_PROPS.WoodCrate,
			COVER_PROPS.SandbagWall,
			COVER_PROPS.FallenLog,
		},

		decorativeProps = {
			{
				name = "TallGrass",
				size = Vector3.new(3, 4, 3),
				material = Enum.Material.Grass,
				color = Color3.fromRGB(140, 180, 100),
				canCollide = false,
				provideCover = true,
				destructible = false,
			},
			{
				name = "Wildflowers",
				size = Vector3.new(4, 2, 4),
				material = Enum.Material.Grass,
				color = Color3.fromRGB(255, 200, 100),
				canCollide = false,
				provideCover = false,
				destructible = false,
			},
		},

		ambientParticles = {
			{
				name = "GrassSeeds",
				enabled = true,
				rate = 2,
				color = ColorSequence.new(Color3.fromRGB(220, 240, 200)),
				size = NumberSequence.new(0.2),
				lifetime = NumberRange.new(5, 15),
				speed = NumberRange.new(1, 4),
				spreadAngle = Vector2.new(60, 60),
			},
		},

		landmarks = {
			{
				name = "Lone Oak",
				description = "Massive ancient oak tree",
				radius = 30,
				visibility = 500,
			},
		},

		verticalitySpots = {
			{ type = "platform", heightAdvantage = 6, riskLevel = 2 },
		},

		soundscape = {
			ambientVolume = 0.6,
			musicIntensity = 0.3,
			reverbPreset = "OpenAir",
		},
	},

	Volcanic = {
		name = "Volcanic",
		displayName = "Inferno Caldera",
		description = "Hellish volcanic landscape with lava flows and extreme danger",

		sector = { startAngle = 0, endAngle = 0 },

		minimapColor = Color3.fromRGB(255, 69, 0),

		lootTier = "High",
		lootDensity = 1.8,

		dinosaurTypes = { "TRex", "Pteranodon", "Carnotaurus" },
		dinosaurDensity = 0.5,

		primaryMaterial = Enum.Material.Basalt,
		secondaryMaterial = Enum.Material.Rock,
		peakMaterial = Enum.Material.CrackedLava,

		colorPalette = {
			primary = Color3.fromRGB(60, 50, 50),
			secondary = Color3.fromRGB(80, 40, 30),
			accent = Color3.fromRGB(255, 100, 0),
			highlight = Color3.fromRGB(255, 200, 50),
			shadow = Color3.fromRGB(20, 15, 15),
		},

		ambientSound = "VolcanicAmbient",
		weatherEffects = { "AshFall", "Smoke", "EmberShower" },
		hazards = { "LavaFlow", "Heat", "GeyserEruption", "VolcanicGas" },

		atmosphere = {
			density = 0.5,
			offset = 0.3,
			color = Color3.fromRGB(255, 150, 100),
			decay = Color3.fromRGB(150, 80, 50),
			glare = 0.4,
			haze = 0.8,
		},

		lighting = {
			ambient = Color3.fromRGB(150, 80, 50),
			outdoorAmbient = Color3.fromRGB(180, 100, 60),
			brightness = 1.8,
			colorShift_Top = Color3.fromRGB(255, 150, 80),
			colorShift_Bottom = Color3.fromRGB(100, 40, 20),
			environmentDiffuseScale = 0.7,
			environmentSpecularScale = 0.5,
			globalShadows = true,
			shadowSoftness = 0.5,
		},

		fogEnabled = true,
		fogStart = 50,
		fogEnd = 400,
		fogColor = Color3.fromRGB(100, 60, 40),

		groundDetails = {
			grassDensity = 0.0,
			rockDensity = 0.8,
			debrisDensity = 0.7,
			puddleDensity = 0.0,
			crackDensity = 0.9,
		},

		coverProps = {
			COVER_PROPS.Boulder,
			COVER_PROPS.MetalCrate,
			COVER_PROPS.ConcreteBarrier,
		},

		decorativeProps = {
			DECORATIVE_PROPS.LavaRock,
			DECORATIVE_PROPS.SteamVent,
			DECORATIVE_PROPS.ObsidianSpike,
		},

		ambientParticles = {
			{
				name = "Embers",
				enabled = true,
				rate = 8,
				color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 50)),
					ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 100, 0)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 30, 0)),
				}),
				size = NumberSequence.new(0.3),
				lifetime = NumberRange.new(2, 5),
				speed = NumberRange.new(2, 8),
				spreadAngle = Vector2.new(45, 180),
			},
			{
				name = "Ash",
				enabled = true,
				rate = 10,
				color = ColorSequence.new(Color3.fromRGB(80, 80, 80)),
				size = NumberSequence.new(0.4),
				lifetime = NumberRange.new(5, 12),
				speed = NumberRange.new(1, 3),
				spreadAngle = Vector2.new(90, 45),
			},
		},

		landmarks = {
			{
				name = "Volcano Crater",
				description = "Active volcanic crater with lava lake",
				radius = 100,
				visibility = 1000,
			},
			{
				name = "Obsidian Spires",
				description = "Towering black glass formations",
				radius = 40,
				visibility = 600,
			},
		},

		verticalitySpots = {
			{ type = "cliff", heightAdvantage = 20, riskLevel = 5 },
			{ type = "platform", heightAdvantage = 10, riskLevel = 4 },
		},

		soundscape = {
			ambientVolume = 0.8,
			musicIntensity = 0.7,
			reverbPreset = "Cave",
		},
	},

	Swamp = {
		name = "Swamp",
		displayName = "Toxic Bayou",
		description = "Murky swampland shrouded in fog with hidden predators",

		sector = { startAngle = 0, endAngle = 0 },

		minimapColor = Color3.fromRGB(85, 107, 47),

		lootTier = "Medium",
		lootDensity = 1.1,

		dinosaurTypes = { "Dilophosaurus", "Spinosaurus", "Baryonyx" },
		dinosaurDensity = 1.3,

		primaryMaterial = Enum.Material.Mud,
		secondaryMaterial = Enum.Material.Ground,
		peakMaterial = Enum.Material.Grass,

		colorPalette = {
			primary = Color3.fromRGB(85, 107, 47),
			secondary = Color3.fromRGB(60, 80, 50),
			accent = Color3.fromRGB(148, 0, 211),
			highlight = Color3.fromRGB(100, 255, 100),
			shadow = Color3.fromRGB(30, 40, 30),
		},

		ambientSound = "SwampAmbient",
		weatherEffects = { "Fog", "Rain", "Mist" },
		hazards = { "PoisonousGas", "Quicksand", "DeepWater", "Leeches" },

		atmosphere = {
			density = 0.6,
			offset = 0.2,
			color = Color3.fromRGB(150, 180, 150),
			decay = Color3.fromRGB(80, 100, 80),
			glare = 0.1,
			haze = 0.9,
		},

		lighting = {
			ambient = Color3.fromRGB(80, 100, 80),
			outdoorAmbient = Color3.fromRGB(100, 130, 100),
			brightness = 1.2,
			colorShift_Top = Color3.fromRGB(150, 180, 150),
			colorShift_Bottom = Color3.fromRGB(40, 60, 40),
			environmentDiffuseScale = 0.6,
			environmentSpecularScale = 0.4,
			globalShadows = true,
			shadowSoftness = 0.6,
		},

		fogEnabled = true,
		fogStart = 30,
		fogEnd = 300,
		fogColor = Color3.fromRGB(140, 160, 140),

		groundDetails = {
			grassDensity = 0.5,
			rockDensity = 0.2,
			debrisDensity = 0.4,
			puddleDensity = 0.8,
			crackDensity = 0.1,
		},

		coverProps = {
			COVER_PROPS.FallenLog,
			COVER_PROPS.ThickBush,
			COVER_PROPS.WoodCrate,
		},

		decorativeProps = {
			DECORATIVE_PROPS.DeadStump,
			DECORATIVE_PROPS.SwampReeds,
			DECORATIVE_PROPS.MuddyPuddle,
		},

		ambientParticles = {
			{
				name = "SwampMist",
				enabled = true,
				rate = 5,
				color = ColorSequence.new(Color3.fromRGB(180, 200, 180)),
				size = NumberSequence.new(2),
				lifetime = NumberRange.new(8, 15),
				speed = NumberRange.new(0.5, 2),
				spreadAngle = Vector2.new(180, 30),
			},
			{
				name = "Bugs",
				enabled = true,
				rate = 3,
				color = ColorSequence.new(Color3.fromRGB(50, 50, 50)),
				size = NumberSequence.new(0.1),
				lifetime = NumberRange.new(2, 5),
				speed = NumberRange.new(3, 8),
				spreadAngle = Vector2.new(360, 360),
			},
		},

		landmarks = {
			{
				name = "Dead Tree Grove",
				description = "Cluster of massive dead trees",
				radius = 60,
				visibility = 300,
			},
			{
				name = "Sunken Ruins",
				description = "Ancient structures half-submerged",
				radius = 50,
				visibility = 250,
			},
		},

		verticalitySpots = {
			{ type = "platform", heightAdvantage = 5, riskLevel = 2 },
			{ type = "roof", heightAdvantage = 8, riskLevel = 3 },
		},

		soundscape = {
			ambientVolume = 0.8,
			musicIntensity = 0.4,
			reverbPreset = "Underwater",
		},
	},

	Coast = {
		name = "Coast",
		displayName = "Primeval Shores",
		description = "Sandy beaches and coastal cliffs with marine life",

		sector = { startAngle = 0, endAngle = 0 },

		minimapColor = Color3.fromRGB(135, 206, 235),

		lootTier = "Low",
		lootDensity = 0.9,

		dinosaurTypes = { "Pteranodon", "Mosasaurus", "Dimorphodon" },
		dinosaurDensity = 0.6,

		primaryMaterial = Enum.Material.Sand,
		secondaryMaterial = Enum.Material.Rock,
		peakMaterial = Enum.Material.Slate,

		colorPalette = {
			primary = Color3.fromRGB(194, 178, 128),
			secondary = Color3.fromRGB(135, 206, 235),
			accent = Color3.fromRGB(255, 255, 255),
			highlight = Color3.fromRGB(255, 245, 220),
			shadow = Color3.fromRGB(100, 80, 60),
		},

		ambientSound = "CoastAmbient",
		weatherEffects = { "SeaSpray", "Storm", "SeaBreeze" },
		hazards = { "Tide", "RipCurrent", "Jellyfish" },

		atmosphere = {
			density = 0.25,
			offset = 0.1,
			color = Color3.fromRGB(200, 220, 240),
			decay = Color3.fromRGB(150, 180, 200),
			glare = 0.5,
			haze = 0.3,
		},

		lighting = {
			ambient = Color3.fromRGB(160, 180, 200),
			outdoorAmbient = Color3.fromRGB(200, 220, 240),
			brightness = 2.3,
			colorShift_Top = Color3.fromRGB(200, 230, 255),
			colorShift_Bottom = Color3.fromRGB(100, 140, 180),
			environmentDiffuseScale = 1.1,
			environmentSpecularScale = 1.0,
			globalShadows = true,
			shadowSoftness = 0.25,
		},

		fogEnabled = false,
		fogStart = 300,
		fogEnd = 1500,
		fogColor = Color3.fromRGB(200, 220, 240),

		groundDetails = {
			grassDensity = 0.3,
			rockDensity = 0.4,
			debrisDensity = 0.5,
			puddleDensity = 0.4,
			crackDensity = 0.0,
		},

		coverProps = {
			COVER_PROPS.Boulder,
			COVER_PROPS.WoodCrate,
			COVER_PROPS.ShippingContainer,
		},

		decorativeProps = {
			{
				name = "Driftwood",
				size = Vector3.new(2, 1, 10),
				material = Enum.Material.Wood,
				color = Color3.fromRGB(160, 140, 120),
				canCollide = true,
				provideCover = true,
				destructible = false,
			},
			{
				name = "Seashells",
				size = Vector3.new(3, 0.5, 3),
				material = Enum.Material.SmoothPlastic,
				color = Color3.fromRGB(255, 230, 200),
				canCollide = false,
				provideCover = false,
				destructible = false,
			},
		},

		ambientParticles = {
			{
				name = "SeaSpray",
				enabled = true,
				rate = 4,
				color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
				size = NumberSequence.new(0.5),
				lifetime = NumberRange.new(2, 5),
				speed = NumberRange.new(3, 8),
				spreadAngle = Vector2.new(60, 30),
			},
		},

		landmarks = {
			{
				name = "Lighthouse",
				description = "Tall lighthouse on rocky outcrop",
				radius = 30,
				visibility = 700,
			},
			{
				name = "Shipwreck",
				description = "Old wooden ship beached on shore",
				radius = 40,
				visibility = 400,
			},
		},

		verticalitySpots = {
			{ type = "cliff", heightAdvantage = 15, riskLevel = 3 },
			{ type = "tower", heightAdvantage = 20, riskLevel = 4 },
		},

		soundscape = {
			ambientVolume = 0.7,
			musicIntensity = 0.3,
			reverbPreset = "OpenAir",
		},
	},

	Research = {
		name = "Research",
		displayName = "InGen Complex",
		description = "Abandoned research facilities with experimental dangers and legendary loot",

		sector = { startAngle = 0, endAngle = 0 },

		minimapColor = Color3.fromRGB(192, 192, 192),

		lootTier = "Legendary",
		lootDensity = 2.0,

		dinosaurTypes = { "Indoraptor", "Velociraptor", "Compsognathus" },
		dinosaurDensity = 1.2,

		primaryMaterial = Enum.Material.Concrete,
		secondaryMaterial = Enum.Material.Metal,
		peakMaterial = Enum.Material.DiamondPlate,

		colorPalette = {
			primary = Color3.fromRGB(192, 192, 192),
			secondary = Color3.fromRGB(100, 100, 110),
			accent = Color3.fromRGB(0, 255, 0),
			highlight = Color3.fromRGB(255, 255, 255),
			shadow = Color3.fromRGB(40, 40, 50),
		},

		ambientSound = "ResearchAmbient",
		weatherEffects = {},
		hazards = { "SecuritySystem", "BiohazardLeak", "PowerSurge", "LockdownDoors" },

		atmosphere = {
			density = 0.15,
			offset = 0.05,
			color = Color3.fromRGB(200, 210, 220),
			decay = Color3.fromRGB(150, 160, 170),
			glare = 0.2,
			haze = 0.1,
		},

		lighting = {
			ambient = Color3.fromRGB(140, 150, 160),
			outdoorAmbient = Color3.fromRGB(180, 190, 200),
			brightness = 1.5,
			colorShift_Top = Color3.fromRGB(200, 210, 220),
			colorShift_Bottom = Color3.fromRGB(80, 90, 100),
			environmentDiffuseScale = 0.8,
			environmentSpecularScale = 1.0,
			globalShadows = true,
			shadowSoftness = 0.2,
		},

		fogEnabled = false,
		fogStart = 200,
		fogEnd = 800,
		fogColor = Color3.fromRGB(200, 200, 210),

		groundDetails = {
			grassDensity = 0.1,
			rockDensity = 0.1,
			debrisDensity = 0.8,
			puddleDensity = 0.2,
			crackDensity = 0.5,
		},

		coverProps = {
			COVER_PROPS.MetalBarrel,
			COVER_PROPS.MetalCrate,
			COVER_PROPS.ConcreteBarrier,
			COVER_PROPS.ShippingContainer,
		},

		decorativeProps = {
			DECORATIVE_PROPS.BrokenTerminal,
			DECORATIVE_PROPS.LabEquipment,
			DECORATIVE_PROPS.BiohazardBarrel,
		},

		ambientParticles = {
			{
				name = "Sparks",
				enabled = true,
				rate = 2,
				color = ColorSequence.new(Color3.fromRGB(255, 200, 100)),
				size = NumberSequence.new(0.2),
				lifetime = NumberRange.new(0.3, 0.8),
				speed = NumberRange.new(5, 15),
				spreadAngle = Vector2.new(45, 45),
			},
			{
				name = "Smoke",
				enabled = true,
				rate = 1,
				color = ColorSequence.new(Color3.fromRGB(100, 100, 100)),
				size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.5),
					NumberSequenceKeypoint.new(1, 2),
				}),
				lifetime = NumberRange.new(3, 8),
				speed = NumberRange.new(1, 3),
				spreadAngle = Vector2.new(30, 30),
			},
		},

		landmarks = {
			{
				name = "Control Tower",
				description = "Main facility control center",
				radius = 50,
				visibility = 500,
			},
			{
				name = "Containment Dome",
				description = "Large dome structure for dinosaur containment",
				radius = 80,
				visibility = 600,
			},
		},

		verticalitySpots = {
			{ type = "tower", heightAdvantage = 18, riskLevel = 3 },
			{ type = "roof", heightAdvantage = 12, riskLevel = 4 },
			{ type = "platform", heightAdvantage = 6, riskLevel = 2 },
		},

		soundscape = {
			ambientVolume = 0.5,
			musicIntensity = 0.6,
			reverbPreset = "Hallway",
		},
	},
}

--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------------

--[[
	Get biome at world position (angle-based for main terrain)
]]
function BiomeData.GetBiomeAtPosition(x: number, z: number): BiomeType
	local angle = math.atan2(z, x) + math.pi

	for biomeName, config in pairs(BiomeData.Biomes) do
		if config.sector.startAngle > 0 or config.sector.endAngle > 0 then
			if angle >= config.sector.startAngle and angle < config.sector.endAngle then
				return biomeName :: BiomeType
			end
		end
	end

	return "Jungle"
end

--[[
	Get biome config by name
]]
function BiomeData.GetBiomeConfig(biome: BiomeType): BiomeConfig
	return BiomeData.Biomes[biome]
end

--[[
	Get danger level for biome (1-5)
]]
function BiomeData.GetDangerLevel(biome: BiomeType): number
	local levels = {
		Jungle = 3,
		Desert = 2,
		Mountains = 4,
		Plains = 2,
		Volcanic = 5,
		Swamp = 3,
		Coast = 2,
		Research = 4,
	}
	return levels[biome] or 2
end

--[[
	Get loot multiplier for biome
]]
function BiomeData.GetLootMultiplier(biome: BiomeType): number
	local config = BiomeData.Biomes[biome]
	return config and config.lootDensity or 1.0
end

--[[
	Get main terrain biome names (angle-based map sectors)
]]
function BiomeData.GetTerrainBiomes(): { BiomeType }
	return { "Jungle", "Desert", "Mountains" }
end

--[[
	Get POI-specific biome names
]]
function BiomeData.GetPOIBiomes(): { BiomeType }
	return { "Plains", "Volcanic", "Swamp", "Coast", "Research" }
end

--[[
	Get all biome names
]]
function BiomeData.GetAllBiomes(): { BiomeType }
	return { "Jungle", "Desert", "Mountains", "Plains", "Volcanic", "Swamp", "Coast", "Research" }
end

--[[
	Get cover props for a biome
]]
function BiomeData.GetCoverProps(biome: BiomeType): { PropDefinition }
	local config = BiomeData.Biomes[biome]
	return config and config.coverProps or {}
end

--[[
	Get decorative props for a biome
]]
function BiomeData.GetDecorativeProps(biome: BiomeType): { PropDefinition }
	local config = BiomeData.Biomes[biome]
	return config and config.decorativeProps or {}
end

--[[
	Get atmosphere settings for a biome
]]
function BiomeData.GetAtmosphere(biome: BiomeType): AtmosphereSettings?
	local config = BiomeData.Biomes[biome]
	return config and config.atmosphere
end

--[[
	Get lighting settings for a biome
]]
function BiomeData.GetLighting(biome: BiomeType): LightingSettings?
	local config = BiomeData.Biomes[biome]
	return config and config.lighting
end

--[[
	Get ambient particles for a biome
]]
function BiomeData.GetAmbientParticles(biome: BiomeType): { ParticleSettings }
	local config = BiomeData.Biomes[biome]
	return config and config.ambientParticles or {}
end

--[[
	Get landmarks for a biome
]]
function BiomeData.GetLandmarks(biome: BiomeType): { any }
	local config = BiomeData.Biomes[biome]
	return config and config.landmarks or {}
end

--[[
	Get color palette for a biome
]]
function BiomeData.GetColorPalette(biome: BiomeType): { [string]: Color3 }
	local config = BiomeData.Biomes[biome]
	return config and config.colorPalette or {
		primary = Color3.fromRGB(128, 128, 128),
		secondary = Color3.fromRGB(100, 100, 100),
		accent = Color3.fromRGB(150, 150, 150),
	}
end

return BiomeData
