--!strict
--[[
	BiomeData.lua
	=============
	Defines all biome types and their properties for Dino Royale
	Map divided into 3 biomes: Jungle, Desert, Mountains
]]

-- Main terrain biomes + legacy POI biomes for compatibility
export type BiomeType = "Jungle" | "Desert" | "Mountains" | "Plains" | "Volcanic" | "Swamp" | "Coast" | "Research"

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

	-- Environment
	ambientSound: string,
	weatherEffects: { string },
	hazards: { string },
}

local BiomeData = {}

-- Map configuration (4km x 4km per GDD Section 3.3)
BiomeData.MapSize = {
	width = 4000,
	height = 4000,
}
BiomeData.MapCenter = Vector3.new(0, 0, 0)

BiomeData.Biomes: { [BiomeType]: BiomeConfig } = {
	Jungle = {
		name = "Jungle",
		displayName = "Jungle Zone",
		description = "Dense tropical jungle with raptors and lush vegetation",

		sector = {
			startAngle = 0,
			endAngle = math.pi * 2/3, -- 0° to 120°
		},

		minimapColor = Color3.fromRGB(34, 139, 34),

		lootTier = "Medium",
		lootDensity = 1.2,

		dinosaurTypes = { "Velociraptor", "Dilophosaurus", "Compsognathus" },
		dinosaurDensity = 1.5,

		primaryMaterial = Enum.Material.LeafyGrass,
		secondaryMaterial = Enum.Material.Grass,
		peakMaterial = Enum.Material.Rock,

		ambientSound = "JungleAmbient",
		weatherEffects = { "Rain", "Fog" },
		hazards = { "RaptorNest", "QuicksandPit" },
	},

	Desert = {
		name = "Desert",
		displayName = "Desert Dunes",
		description = "Arid desert with sand dunes and ancient ruins",

		sector = {
			startAngle = math.pi * 2/3,
			endAngle = math.pi * 4/3, -- 120° to 240°
		},

		minimapColor = Color3.fromRGB(210, 180, 140),

		lootTier = "Low",
		lootDensity = 0.8,

		dinosaurTypes = { "Gallimimus", "Pteranodon" },
		dinosaurDensity = 0.7,

		primaryMaterial = Enum.Material.Sand,
		secondaryMaterial = Enum.Material.Sandstone,
		peakMaterial = Enum.Material.Sandstone,

		ambientSound = "DesertAmbient",
		weatherEffects = { "Sandstorm" },
		hazards = { "Heatstroke", "Quicksand" },
	},

	Mountains = {
		name = "Mountains",
		displayName = "Mountain Peaks",
		description = "Snowy mountain peaks with treacherous cliffs and predators",

		sector = {
			startAngle = math.pi * 4/3,
			endAngle = math.pi * 2, -- 240° to 360°
		},

		minimapColor = Color3.fromRGB(200, 200, 220),

		lootTier = "High",
		lootDensity = 1.5,

		dinosaurTypes = { "TRex", "Triceratops", "Indoraptor" },
		dinosaurDensity = 1.0,

		primaryMaterial = Enum.Material.Rock,
		secondaryMaterial = Enum.Material.Slate,
		peakMaterial = Enum.Material.Snow,

		ambientSound = "MountainAmbient",
		weatherEffects = { "Snow", "Wind" },
		hazards = { "Avalanche", "IcySlope" },
	},

	-- POI-specific biomes (used for environmental effects and POI categorization)
	Plains = {
		name = "Plains",
		displayName = "Open Plains",
		description = "Open grasslands with scattered outposts",

		sector = { startAngle = 0, endAngle = 0 }, -- POI biome, not angle-based

		minimapColor = Color3.fromRGB(144, 238, 144),

		lootTier = "Medium",
		lootDensity = 1.0,

		dinosaurTypes = { "Gallimimus", "Triceratops" },
		dinosaurDensity = 0.8,

		primaryMaterial = Enum.Material.Grass,
		secondaryMaterial = Enum.Material.Ground,
		peakMaterial = Enum.Material.Rock,

		ambientSound = "PlainsAmbient",
		weatherEffects = { "Wind" },
		hazards = { "Stampede" },
	},

	Volcanic = {
		name = "Volcanic",
		displayName = "Volcanic Zone",
		description = "Dangerous volcanic region with lava flows and geothermal vents",

		sector = { startAngle = 0, endAngle = 0 }, -- POI biome, not angle-based

		minimapColor = Color3.fromRGB(255, 69, 0),

		lootTier = "High",
		lootDensity = 1.8,

		dinosaurTypes = { "TRex", "Pteranodon" },
		dinosaurDensity = 0.5,

		primaryMaterial = Enum.Material.Basalt,
		secondaryMaterial = Enum.Material.Rock,
		peakMaterial = Enum.Material.CrackedLava,

		ambientSound = "VolcanicAmbient",
		weatherEffects = { "AshFall", "Smoke" },
		hazards = { "LavaFlow", "Heat", "GeyserEruption" },
	},

	Swamp = {
		name = "Swamp",
		displayName = "Murky Swamp",
		description = "Foggy swampland with hidden dangers",

		sector = { startAngle = 0, endAngle = 0 }, -- POI biome, not angle-based

		minimapColor = Color3.fromRGB(85, 107, 47),

		lootTier = "Medium",
		lootDensity = 1.1,

		dinosaurTypes = { "Dilophosaurus", "Spinosaurus" },
		dinosaurDensity = 1.3,

		primaryMaterial = Enum.Material.Mud,
		secondaryMaterial = Enum.Material.Ground,
		peakMaterial = Enum.Material.Grass,

		ambientSound = "SwampAmbient",
		weatherEffects = { "Fog", "Rain" },
		hazards = { "PoisonousGas", "Quicksand", "DeepWater" },
	},

	Coast = {
		name = "Coast",
		displayName = "Coastal Shores",
		description = "Beaches and coastal cliffs with marine life",

		sector = { startAngle = 0, endAngle = 0 }, -- POI biome, not angle-based

		minimapColor = Color3.fromRGB(135, 206, 235),

		lootTier = "Low",
		lootDensity = 0.9,

		dinosaurTypes = { "Pteranodon", "Mosasaurus" },
		dinosaurDensity = 0.6,

		primaryMaterial = Enum.Material.Sand,
		secondaryMaterial = Enum.Material.Rock,
		peakMaterial = Enum.Material.Slate,

		ambientSound = "CoastAmbient",
		weatherEffects = { "SeaSpray", "Storm" },
		hazards = { "Tide", "RipCurrent" },
	},

	Research = {
		name = "Research",
		displayName = "Research Facility",
		description = "Abandoned research facilities with experimental dangers",

		sector = { startAngle = 0, endAngle = 0 }, -- POI biome, not angle-based

		minimapColor = Color3.fromRGB(192, 192, 192),

		lootTier = "Legendary",
		lootDensity = 2.0,

		dinosaurTypes = { "Indoraptor", "Velociraptor" },
		dinosaurDensity = 1.2,

		primaryMaterial = Enum.Material.Concrete,
		secondaryMaterial = Enum.Material.Metal,
		peakMaterial = Enum.Material.DiamondPlate,

		ambientSound = "ResearchAmbient",
		weatherEffects = {},
		hazards = { "SecuritySystem", "BiohazardLeak", "PowerSurge" },
	},
}

--[[
	Get biome at world position (angle-based)
]]
function BiomeData.GetBiomeAtPosition(x: number, z: number): BiomeType
	local angle = math.atan2(z, x) + math.pi -- Convert to 0-2π range

	for biomeName, config in pairs(BiomeData.Biomes) do
		if angle >= config.sector.startAngle and angle < config.sector.endAngle then
			return biomeName :: BiomeType
		end
	end

	return "Jungle" -- Default fallback
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
	Get all biome names (terrain + POI biomes)
]]
function BiomeData.GetAllBiomes(): { BiomeType }
	return { "Jungle", "Desert", "Mountains", "Plains", "Volcanic", "Swamp", "Coast", "Research" }
end

return BiomeData
