--!strict
--[[
	BiomeData.lua
	=============
	Defines all biome types and their properties for Isla Primordial
	Based on GDD Section 3: Map Design
]]

export type BiomeType = "Jungle" | "Plains" | "Volcanic" | "Swamp" | "Coast" | "Research"

export type BiomeConfig = {
	name: string,
	displayName: string,
	description: string,

	-- Map position (normalized 0-1 coordinates)
	region: {
		centerX: number,
		centerZ: number,
		radius: number,
	},

	-- World bounds (for minimap)
	bounds: {
		center: Vector3,
		radius: number,
	},

	-- Minimap display
	minimapColor: Color3,

	-- Loot settings
	lootTier: string, -- "Low" | "Medium" | "High" | "VeryHigh"
	lootDensity: number, -- Multiplier for spawn points

	-- Dinosaur spawning
	dinosaurTypes: { string },
	dinosaurDensity: number,

	-- Environment
	ambientSound: string,
	weatherEffects: { string },
	hazards: { string },

	-- Visual
	fogDensity: number,
	fogColor: { r: number, g: number, b: number },
	lighting: {
		ambient: { r: number, g: number, b: number },
		brightness: number,
	},
}

local BiomeData = {}

BiomeData.Biomes: { [BiomeType]: BiomeConfig } = {
	Jungle = {
		name = "Jungle",
		displayName = "Jungle Zone",
		description = "Dense tropical jungle with raptor paddocks and the iconic Visitor Center",

		region = {
			centerX = 0.5,
			centerZ = 0.5,
			radius = 0.25,
		},

		bounds = {
			center = Vector3.new(2000, 0, 2000),
			radius = 1000,
		},

		minimapColor = Color3.fromRGB(34, 139, 34),

		lootTier = "Medium-High",
		lootDensity = 1.2,

		dinosaurTypes = { "Velociraptor", "Dilophosaurus", "Compsognathus" },
		dinosaurDensity = 1.5,

		ambientSound = "JungleAmbient",
		weatherEffects = { "Rain", "Fog" },
		hazards = { "RaptorNest", "VenomPool" },

		fogDensity = 0.3,
		fogColor = { r = 100, g = 120, b = 80 },
		lighting = {
			ambient = { r = 80, g = 100, b = 60 },
			brightness = 0.8,
		},
	},

	Plains = {
		name = "Plains",
		displayName = "Open Plains",
		description = "Wide grasslands where herbivores roam - beginner friendly with good sightlines",

		region = {
			centerX = 0.25,
			centerZ = 0.5,
			radius = 0.2,
		},

		bounds = {
			center = Vector3.new(1000, 0, 2000),
			radius = 800,
		},

		minimapColor = Color3.fromRGB(154, 205, 50),

		lootTier = "Medium",
		lootDensity = 0.8,

		dinosaurTypes = { "Triceratops", "Gallimimus" },
		dinosaurDensity = 1.0,

		ambientSound = "PlainsAmbient",
		weatherEffects = { "Wind", "Dust" },
		hazards = { "Stampede" },

		fogDensity = 0.1,
		fogColor = { r = 200, g = 200, b = 180 },
		lighting = {
			ambient = { r = 180, g = 180, b = 160 },
			brightness = 1.2,
		},
	},

	Volcanic = {
		name = "Volcanic",
		displayName = "Volcanic Region",
		description = "Dangerous northern zone with lava flows and apex predators",

		region = {
			centerX = 0.5,
			centerZ = 0.15,
			radius = 0.2,
		},

		bounds = {
			center = Vector3.new(2000, 0, 600),
			radius = 800,
		},

		minimapColor = Color3.fromRGB(178, 34, 34),

		lootTier = "High",
		lootDensity = 1.5,

		dinosaurTypes = { "TRex", "Carnotaurus" },
		dinosaurDensity = 0.8,

		ambientSound = "VolcanicAmbient",
		weatherEffects = { "AshFall", "HeatWave" },
		hazards = { "LavaPool", "Eruption", "SteamVent" },

		fogDensity = 0.5,
		fogColor = { r = 80, g = 60, b = 50 },
		lighting = {
			ambient = { r = 200, g = 100, b = 50 },
			brightness = 0.9,
		},
	},

	Swamp = {
		name = "Swamp",
		displayName = "Swamplands",
		description = "Murky wetlands in the east, home to aquatic predators",

		region = {
			centerX = 0.8,
			centerZ = 0.5,
			radius = 0.18,
		},

		bounds = {
			center = Vector3.new(3200, 0, 2000),
			radius = 720,
		},

		minimapColor = Color3.fromRGB(85, 107, 47),

		lootTier = "Medium",
		lootDensity = 1.0,

		dinosaurTypes = { "Spinosaurus", "Baryonyx", "Pteranodon" },
		dinosaurDensity = 1.2,

		ambientSound = "SwampAmbient",
		weatherEffects = { "Fog", "Rain", "Monsoon" },
		hazards = { "Quicksand", "DeepWater" },

		fogDensity = 0.6,
		fogColor = { r = 80, g = 100, b = 80 },
		lighting = {
			ambient = { r = 60, g = 80, b = 60 },
			brightness = 0.6,
		},
	},

	Coast = {
		name = "Coast",
		displayName = "Coastal Area",
		description = "Southern beaches and harbor - mixed danger with water threats",

		region = {
			centerX = 0.5,
			centerZ = 0.85,
			radius = 0.15,
		},

		bounds = {
			center = Vector3.new(2000, 0, 3400),
			radius = 600,
		},

		minimapColor = Color3.fromRGB(135, 206, 235),

		lootTier = "Low-Medium",
		lootDensity = 0.7,

		dinosaurTypes = { "Pteranodon", "Dimorphodon" },
		dinosaurDensity = 0.6,

		ambientSound = "CoastAmbient",
		weatherEffects = { "SeaBreeze", "Storm" },
		hazards = { "Mosasaurus", "TidalWave" },

		fogDensity = 0.2,
		fogColor = { r = 180, g = 200, b = 220 },
		lighting = {
			ambient = { r = 150, g = 180, b = 200 },
			brightness = 1.3,
		},
	},

	Research = {
		name = "Research",
		displayName = "Research Complex",
		description = "Abandoned laboratory complex - highest loot but extreme danger",

		region = {
			centerX = 0.6,
			centerZ = 0.4,
			radius = 0.12,
		},

		bounds = {
			center = Vector3.new(2400, 0, 1600),
			radius = 480,
		},

		minimapColor = Color3.fromRGB(128, 128, 128),

		lootTier = "VeryHigh",
		lootDensity = 2.0,

		dinosaurTypes = { "Indoraptor", "Velociraptor" },
		dinosaurDensity = 0.5,

		ambientSound = "LabAmbient",
		weatherEffects = { "PowerFlicker" },
		hazards = { "Lockdown", "IndoraptorRelease" },

		fogDensity = 0.1,
		fogColor = { r = 150, g = 150, b = 160 },
		lighting = {
			ambient = { r = 200, g = 200, b = 220 },
			brightness = 0.7,
		},
	},
}

-- Map constants
BiomeData.MapSize = {
	width = 4000, -- studs (4km)
	height = 4000,
}

BiomeData.MapCenter = {
	x = 2000,
	z = 2000,
}

--[[
	Get biome at world position
]]
function BiomeData.GetBiomeAtPosition(x: number, z: number): BiomeType
	local normalizedX = x / BiomeData.MapSize.width
	local normalizedZ = z / BiomeData.MapSize.height

	local closestBiome: BiomeType = "Jungle"
	local closestDistance = math.huge

	for biomeName, config in pairs(BiomeData.Biomes) do
		local dx = normalizedX - config.region.centerX
		local dz = normalizedZ - config.region.centerZ
		local distance = math.sqrt(dx * dx + dz * dz)

		if distance < config.region.radius and distance < closestDistance then
			closestDistance = distance
			closestBiome = biomeName :: BiomeType
		end
	end

	return closestBiome
end

--[[
	Get danger level for a biome (1-5)
]]
function BiomeData.GetDangerLevel(biome: BiomeType): number
	local dangerLevels = {
		Plains = 1,
		Coast = 2,
		Jungle = 3,
		Swamp = 3,
		Volcanic = 4,
		Research = 5,
	}
	return dangerLevels[biome] or 2
end

--[[
	Get loot multiplier for biome
]]
function BiomeData.GetLootMultiplier(biome: BiomeType): number
	local config = BiomeData.Biomes[biome]
	if not config then return 1.0 end
	return config.lootDensity
end

return BiomeData
