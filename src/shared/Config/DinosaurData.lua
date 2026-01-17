--!strict
--[[
	DinosaurData.lua
	================
	Complete dinosaur definitions for Dino Royale
	Includes stats, behaviors, abilities, animations, sounds, and loot tables

	BEHAVIOR TYPES:
	- Swarm: Small groups that attack in waves
	- Flee: Runs from threats, may stampede
	- Territorial: Defends a specific area
	- PackHunter: Coordinates with pack members
	- Ambush: Waits for prey, then strikes
	- Pursuit: Relentlessly chases targets
	- Apex: Dominant predator, all behaviors
	- Stalker: Patient, intelligent hunter

	ABILITY SYSTEM:
	Each ability has cooldown, duration, damage/effect values
]]

local Types = require(script.Parent.Parent.Types)

--------------------------------------------------------------------------------
-- TYPE DEFINITIONS
--------------------------------------------------------------------------------

export type AbilityDefinition = {
	name: string,
	cooldown: number,
	duration: number?,
	damage: number?,
	range: number?,
	effect: string?,
	animation: string?,
	sound: string?,
	particles: string?,
}

export type BehaviorPattern = {
	name: string,
	phases: { string },
	aggroThreshold: number,
	fleeThreshold: number?,
	packCoordination: boolean,
	nightBehavior: string?,
}

export type VisualEffects = {
	eyeGlow: Color3?,
	trailEffect: string?,
	ambientParticles: string?,
	impactEffect: string?,
	deathEffect: string?,
}

export type SoundDesign = {
	idle: { string },
	alert: string,
	attack: string,
	hurt: string,
	death: string,
	special: { [string]: string }?,
	footsteps: string?,
	ambient: string?,
}

export type AnimationSet = {
	idle: string,
	walk: string,
	run: string,
	attack: string,
	special: { [string]: string }?,
	hurt: string,
	death: string,
	roar: string?,
}

export type DinosaurDefinition = {
	name: string,
	displayName: string,
	description: string,
	tier: Types.DinosaurTier,

	-- Base stats
	health: number,
	damage: number,
	speed: number,
	turnSpeed: number,
	attackRate: number, -- Attacks per second
	attackRange: number,

	-- Detection
	detectionRange: number,
	hearingRange: number,
	smellRange: number?,
	nightVisionRange: number?,

	-- Size for hitbox and visuals
	size: Vector3,
	mass: number,

	-- Behavior
	behavior: BehaviorPattern,
	packSize: { number }?,
	territorySize: number?,

	-- Abilities
	abilities: { AbilityDefinition },

	-- Combat modifiers
	armorReduction: number?,
	critChance: number?,
	knockback: number?,

	-- Movement
	canSwim: boolean,
	canFly: boolean,
	swimSpeed: number?,
	flySpeed: number?,
	climbAngle: number?,

	-- Visuals
	visuals: VisualEffects,
	colors: {
		primary: Color3,
		secondary: Color3,
		accent: Color3,
	},

	-- Audio
	sounds: SoundDesign,

	-- Animations
	animations: AnimationSet,

	-- AI tuning
	aggroDecay: number,
	memoryDuration: number,
	patrolRadius: number?,
	idleVariety: number, -- 0-1, how varied idle behavior is
}

export type LootTableEntry = {
	itemType: string,
	chance: number,
	countMin: number,
	countMax: number,
}

local DinosaurData = {}

--------------------------------------------------------------------------------
-- COMMON TIER - Low threat, common spawns
--------------------------------------------------------------------------------

DinosaurData.Common = {
	Compsognathus = {
		name = "Compsognathus",
		displayName = "Compy",
		description = "Tiny but dangerous in swarms. Their coordinated attacks can overwhelm unprepared survivors.",
		tier = "Common" :: Types.DinosaurTier,

		health = 20,
		damage = 5,
		speed = 20,
		turnSpeed = 8,
		attackRate = 2,
		attackRange = 3,

		detectionRange = 15,
		hearingRange = 25,

		size = Vector3.new(1, 0.8, 2),
		mass = 5,

		behavior = {
			name = "Swarm",
			phases = { "Idle", "Alert", "Swarm", "Retreat" },
			aggroThreshold = 0.3,
			fleeThreshold = 0.2,
			packCoordination = true,
			nightBehavior = "Aggressive",
		},
		packSize = { 5, 10 },

		abilities = {
			{
				name = "SwarmCall",
				cooldown = 8,
				range = 30,
				effect = "CallNearbyCompys",
				sound = "CompyChirp",
			},
			{
				name = "NipAndRun",
				cooldown = 2,
				damage = 3,
				effect = "QuickBite",
				animation = "QuickBite",
			},
		},

		canSwim = false,
		canFly = false,

		visuals = {
			trailEffect = "SmallDust",
			ambientParticles = "None",
			impactEffect = "SmallBlood",
			deathEffect = "SmallCorpse",
		},
		colors = {
			primary = Color3.fromRGB(80, 120, 60),
			secondary = Color3.fromRGB(100, 80, 50),
			accent = Color3.fromRGB(200, 50, 50),
		},

		sounds = {
			idle = { "CompyChirp1", "CompyChirp2", "CompyChirp3" },
			alert = "CompyAlert",
			attack = "CompyBite",
			hurt = "CompyHurt",
			death = "CompyDeath",
			footsteps = "SmallClaws",
		},

		animations = {
			idle = "CompyIdle",
			walk = "CompyWalk",
			run = "CompyRun",
			attack = "CompyBite",
			hurt = "CompyFlinch",
			death = "CompyDeath",
		},

		aggroDecay = 0.2,
		memoryDuration = 10,
		idleVariety = 0.7,
	},

	Gallimimus = {
		name = "Gallimimus",
		displayName = "Galli",
		description = "Swift herbivores that flee at the first sign of danger. Their stampedes can trample anything in their path.",
		tier = "Common" :: Types.DinosaurTier,

		health = 50,
		damage = 10,
		speed = 35,
		turnSpeed = 6,
		attackRate = 0.5,
		attackRange = 5,

		detectionRange = 40,
		hearingRange = 60,

		size = Vector3.new(2, 4, 6),
		mass = 150,

		behavior = {
			name = "Flee",
			phases = { "Grazing", "Alert", "Flee", "Stampede" },
			aggroThreshold = 0.1,
			fleeThreshold = 0.8,
			packCoordination = true,
		},
		packSize = { 3, 6 },

		abilities = {
			{
				name = "Stampede",
				cooldown = 15,
				duration = 5,
				damage = 25,
				effect = "TramplePlayers",
				sound = "StampedeRumble",
				particles = "DustCloud",
			},
			{
				name = "PanicRun",
				cooldown = 10,
				duration = 3,
				effect = "SpeedBoost",
			},
		},

		canSwim = true,
		canFly = false,
		swimSpeed = 15,

		visuals = {
			trailEffect = "DustKicks",
			ambientParticles = "None",
			impactEffect = "MediumBlood",
			deathEffect = "MediumCorpse",
		},
		colors = {
			primary = Color3.fromRGB(180, 160, 120),
			secondary = Color3.fromRGB(140, 120, 80),
			accent = Color3.fromRGB(200, 180, 140),
		},

		sounds = {
			idle = { "GalliCall1", "GalliCall2" },
			alert = "GalliAlert",
			attack = "GalliKick",
			hurt = "GalliPain",
			death = "GalliDeath",
			footsteps = "LargeHooves",
		},

		animations = {
			idle = "GalliIdle",
			walk = "GalliWalk",
			run = "GalliRun",
			attack = "GalliKick",
			hurt = "GalliFlinch",
			death = "GalliDeath",
		},

		aggroDecay = 0.3,
		memoryDuration = 5,
		patrolRadius = 100,
		idleVariety = 0.5,
	},
}

--------------------------------------------------------------------------------
-- UNCOMMON TIER - Moderate threat, territorial
--------------------------------------------------------------------------------

DinosaurData.Uncommon = {
	Dilophosaurus = {
		name = "Dilophosaurus",
		displayName = "Dilo",
		description = "Venomous predator with a distinctive frill. Spits blinding venom before closing for the kill.",
		tier = "Uncommon" :: Types.DinosaurTier,

		health = 80,
		damage = 15,
		speed = 18,
		turnSpeed = 5,
		attackRate = 1,
		attackRange = 4,

		detectionRange = 25,
		hearingRange = 35,
		smellRange = 40,

		size = Vector3.new(2, 3, 5),
		mass = 200,

		behavior = {
			name = "Territorial",
			phases = { "Patrol", "Stalk", "VenomAttack", "Bite", "Retreat" },
			aggroThreshold = 0.4,
			fleeThreshold = 0.3,
			packCoordination = false,
			nightBehavior = "Stalker",
		},
		territorySize = 50,

		abilities = {
			{
				name = "VenomSpit",
				cooldown = 6,
				damage = 5,
				range = 15,
				effect = "BlindAndSlow",
				animation = "DiloSpit",
				sound = "DiloSpit",
				particles = "VenomSpray",
			},
			{
				name = "FrillDisplay",
				cooldown = 10,
				duration = 2,
				effect = "IntimidatePlayers",
				animation = "FrillOpen",
				sound = "FrillRattle",
			},
			{
				name = "AmbushPounce",
				cooldown = 12,
				damage = 25,
				range = 8,
				effect = "Knockdown",
				animation = "DiloPounce",
			},
		},

		canSwim = false,
		canFly = false,

		visuals = {
			eyeGlow = Color3.fromRGB(255, 200, 0),
			trailEffect = "None",
			ambientParticles = "VenomDrip",
			impactEffect = "VenomSplash",
			deathEffect = "MediumCorpse",
		},
		colors = {
			primary = Color3.fromRGB(60, 80, 60),
			secondary = Color3.fromRGB(255, 150, 50),
			accent = Color3.fromRGB(200, 255, 100),
		},

		sounds = {
			idle = { "DiloChirp1", "DiloChirp2" },
			alert = "DiloHiss",
			attack = "DiloBite",
			hurt = "DiloScreech",
			death = "DiloDeath",
			special = {
				VenomSpit = "DiloSpit",
				FrillDisplay = "FrillRattle",
			},
		},

		animations = {
			idle = "DiloIdle",
			walk = "DiloWalk",
			run = "DiloRun",
			attack = "DiloBite",
			special = {
				VenomSpit = "DiloSpit",
				FrillDisplay = "FrillOpen",
			},
			hurt = "DiloFlinch",
			death = "DiloDeath",
		},

		aggroDecay = 0.1,
		memoryDuration = 30,
		patrolRadius = 40,
		idleVariety = 0.6,
	},

	Triceratops = {
		name = "Triceratops",
		displayName = "Trike",
		description = "Massive armored herbivore. Normally docile, but deadly when provoked. Its charge can demolish structures.",
		tier = "Uncommon" :: Types.DinosaurTier,

		health = 300,
		damage = 40,
		speed = 22,
		turnSpeed = 3,
		attackRate = 0.7,
		attackRange = 6,

		detectionRange = 20,
		hearingRange = 40,

		size = Vector3.new(4, 4, 8),
		mass = 6000,

		behavior = {
			name = "Territorial",
			phases = { "Grazing", "Warning", "Charge", "Gore" },
			aggroThreshold = 0.5,
			fleeThreshold = 0.1,
			packCoordination = false,
		},
		territorySize = 60,

		abilities = {
			{
				name = "Charge",
				cooldown = 12,
				duration = 3,
				damage = 60,
				range = 30,
				effect = "DestroyCovers",
				animation = "TrikeCharge",
				sound = "ChargeRumble",
				particles = "DustStorm",
			},
			{
				name = "HornGore",
				cooldown = 5,
				damage = 50,
				effect = "Bleed",
				animation = "TrikeGore",
				sound = "HornImpact",
			},
			{
				name = "HeadShake",
				cooldown = 8,
				damage = 30,
				range = 8,
				effect = "AreaKnockback",
				animation = "TrikeHeadShake",
			},
		},

		armorReduction = 0.2,
		knockback = 2.0,

		canSwim = false,
		canFly = false,

		visuals = {
			trailEffect = "HeavyDust",
			impactEffect = "LargeBlood",
			deathEffect = "LargeCorpse",
		},
		colors = {
			primary = Color3.fromRGB(100, 90, 80),
			secondary = Color3.fromRGB(80, 70, 60),
			accent = Color3.fromRGB(150, 100, 50),
		},

		sounds = {
			idle = { "TrikeGrunt1", "TrikeGrunt2", "TrikeBellow" },
			alert = "TrikeWarning",
			attack = "TrikeRoar",
			hurt = "TrikePain",
			death = "TrikeDeath",
			footsteps = "HeavySteps",
		},

		animations = {
			idle = "TrikeIdle",
			walk = "TrikeWalk",
			run = "TrikeRun",
			attack = "TrikeGore",
			hurt = "TrikeFlinch",
			death = "TrikeDeath",
		},

		aggroDecay = 0.15,
		memoryDuration = 20,
		patrolRadius = 50,
		idleVariety = 0.3,
	},
}

--------------------------------------------------------------------------------
-- RARE TIER - High threat, advanced behaviors
--------------------------------------------------------------------------------

DinosaurData.Rare = {
	Velociraptor = {
		name = "Velociraptor",
		displayName = "Raptor",
		description = "Cunning pack hunters with deadly coordination. They test defenses, communicate, and strike from multiple angles.",
		tier = "Rare" :: Types.DinosaurTier,

		health = 100,
		damage = 30,
		speed = 28,
		turnSpeed = 7,
		attackRate = 1.5,
		attackRange = 4,

		detectionRange = 50,
		hearingRange = 60,
		smellRange = 80,

		size = Vector3.new(1.5, 2, 4),
		mass = 80,

		behavior = {
			name = "PackHunter",
			phases = { "Stalk", "Surround", "AlphaCall", "CoordinatedStrike", "Pursue" },
			aggroThreshold = 0.4,
			packCoordination = true,
			nightBehavior = "Aggressive",
		},
		packSize = { 3, 5 },
		territorySize = 80,

		abilities = {
			{
				name = "PackCall",
				cooldown = 15,
				range = 100,
				effect = "SummonPackMembers",
				sound = "RaptorCall",
			},
			{
				name = "Flank",
				cooldown = 8,
				effect = "CircleTarget",
				animation = "RaptorSprint",
			},
			{
				name = "Pounce",
				cooldown = 6,
				damage = 40,
				range = 10,
				effect = "Knockdown",
				animation = "RaptorPounce",
				sound = "RaptorShriek",
			},
			{
				name = "ClawSlash",
				cooldown = 2,
				damage = 25,
				effect = "Bleed",
				animation = "RaptorSlash",
			},
		},

		critChance = 0.15,

		canSwim = true,
		canFly = false,
		swimSpeed = 12,

		visuals = {
			eyeGlow = Color3.fromRGB(255, 180, 0),
			trailEffect = "SprintDust",
			impactEffect = "MediumBlood",
			deathEffect = "MediumCorpse",
		},
		colors = {
			primary = Color3.fromRGB(80, 60, 40),
			secondary = Color3.fromRGB(120, 80, 50),
			accent = Color3.fromRGB(200, 100, 50),
		},

		sounds = {
			idle = { "RaptorChirp1", "RaptorChirp2", "RaptorGrowl" },
			alert = "RaptorAlert",
			attack = "RaptorShriek",
			hurt = "RaptorPain",
			death = "RaptorDeath",
			special = {
				PackCall = "RaptorCall",
				Pounce = "RaptorPounce",
			},
			footsteps = "QuickClaws",
		},

		animations = {
			idle = "RaptorIdle",
			walk = "RaptorWalk",
			run = "RaptorRun",
			attack = "RaptorSlash",
			special = {
				Pounce = "RaptorPounce",
				PackCall = "RaptorCall",
			},
			hurt = "RaptorFlinch",
			death = "RaptorDeath",
		},

		aggroDecay = 0.05,
		memoryDuration = 60,
		patrolRadius = 60,
		idleVariety = 0.8,
	},

	Baryonyx = {
		name = "Baryonyx",
		displayName = "Barry",
		description = "Semi-aquatic predator that lurks near water. Lightning fast in rivers and lakes, deadly to swimmers.",
		tier = "Rare" :: Types.DinosaurTier,

		health = 200,
		damage = 35,
		speed = 20,
		turnSpeed = 4,
		attackRate = 1,
		attackRange = 5,

		detectionRange = 40,
		hearingRange = 50,
		smellRange = 60,

		size = Vector3.new(2, 3, 7),
		mass = 1500,

		behavior = {
			name = "Ambush",
			phases = { "Submerge", "Wait", "Strike", "Drag" },
			aggroThreshold = 0.3,
			packCoordination = false,
		},
		territorySize = 70,

		abilities = {
			{
				name = "WaterAmbush",
				cooldown = 10,
				damage = 50,
				range = 8,
				effect = "SurpriseAttack",
				animation = "BaryLunge",
				sound = "WaterSplash",
				particles = "WaterExplosion",
			},
			{
				name = "TailSwipe",
				cooldown = 6,
				damage = 20,
				range = 6,
				effect = "Knockback",
				animation = "BaryTailSwipe",
			},
			{
				name = "WaterSpeed",
				cooldown = 15,
				duration = 8,
				effect = "DoubleSwimSpeed",
			},
		},

		canSwim = true,
		canFly = false,
		swimSpeed = 35,

		visuals = {
			trailEffect = "WaterRipples",
			impactEffect = "LargeBlood",
			deathEffect = "LargeCorpse",
		},
		colors = {
			primary = Color3.fromRGB(60, 80, 70),
			secondary = Color3.fromRGB(80, 100, 90),
			accent = Color3.fromRGB(150, 180, 160),
		},

		sounds = {
			idle = { "BaryGrowl1", "BaryGrowl2" },
			alert = "BaryHiss",
			attack = "BarySnap",
			hurt = "BaryPain",
			death = "BaryDeath",
			footsteps = "WetSteps",
		},

		animations = {
			idle = "BaryIdle",
			walk = "BaryWalk",
			run = "BaryRun",
			attack = "BaryBite",
			hurt = "BaryFlinch",
			death = "BaryDeath",
		},

		aggroDecay = 0.1,
		memoryDuration = 45,
		patrolRadius = 50,
		idleVariety = 0.4,
	},

	Pteranodon = {
		name = "Pteranodon",
		displayName = "Ptera",
		description = "Deadly flier that swoops from above. Patrols the skies and dives on unsuspecting prey.",
		tier = "Rare" :: Types.DinosaurTier,

		health = 80,
		damage = 25,
		speed = 15, -- Ground speed
		turnSpeed = 6,
		attackRate = 1,
		attackRange = 4,

		detectionRange = 100,
		hearingRange = 80,

		size = Vector3.new(8, 2, 3), -- Wingspan
		mass = 30,

		behavior = {
			name = "Swoop",
			phases = { "Soar", "Spot", "Dive", "Grab", "Retreat" },
			aggroThreshold = 0.5,
			fleeThreshold = 0.4,
			packCoordination = false,
		},

		abilities = {
			{
				name = "DiveBomb",
				cooldown = 10,
				damage = 40,
				range = 50,
				effect = "Knockdown",
				animation = "PteraDive",
				sound = "WingSwoosh",
			},
			{
				name = "TalonGrab",
				cooldown = 15,
				damage = 20,
				effect = "LiftAndDrop",
				animation = "PteraGrab",
			},
			{
				name = "Screech",
				cooldown = 12,
				range = 30,
				effect = "DisorientPlayers",
				sound = "PteraScreech",
			},
		},

		canSwim = false,
		canFly = true,
		flySpeed = 40,

		visuals = {
			trailEffect = "WindTrail",
			impactEffect = "SmallBlood",
			deathEffect = "FlyingCorpse",
		},
		colors = {
			primary = Color3.fromRGB(120, 100, 80),
			secondary = Color3.fromRGB(180, 150, 120),
			accent = Color3.fromRGB(255, 100, 100),
		},

		sounds = {
			idle = { "PteraCall1", "PteraCall2" },
			alert = "PteraScreech",
			attack = "PteraDive",
			hurt = "PteraPain",
			death = "PteraDeath",
		},

		animations = {
			idle = "PteraIdle",
			walk = "PteraWalk",
			run = "PteraHop",
			attack = "PteraDive",
			hurt = "PteraFlinch",
			death = "PteraDeath",
		},

		aggroDecay = 0.2,
		memoryDuration = 20,
		patrolRadius = 200,
		idleVariety = 0.6,
	},

	Dimorphodon = {
		name = "Dimorphodon",
		displayName = "Dimorph",
		description = "Small but aggressive fliers that attack in swarms. They harass and distract while bigger predators close in.",
		tier = "Rare" :: Types.DinosaurTier,

		health = 40,
		damage = 15,
		speed = 12,
		turnSpeed = 8,
		attackRate = 2,
		attackRange = 3,

		detectionRange = 60,
		hearingRange = 70,

		size = Vector3.new(3, 1, 1.5),
		mass = 5,

		behavior = {
			name = "Swarm",
			phases = { "Circle", "Dive", "Harass", "Scatter" },
			aggroThreshold = 0.3,
			fleeThreshold = 0.2,
			packCoordination = true,
		},
		packSize = { 4, 8 },

		abilities = {
			{
				name = "SwarmDive",
				cooldown = 5,
				damage = 10,
				effect = "MultipleHits",
				animation = "DimorphDive",
			},
			{
				name = "Distract",
				cooldown = 8,
				duration = 3,
				effect = "ObscureVision",
				animation = "DimorphCircle",
			},
		},

		canSwim = false,
		canFly = true,
		flySpeed = 35,

		visuals = {
			trailEffect = "None",
			impactEffect = "SmallBlood",
			deathEffect = "SmallCorpse",
		},
		colors = {
			primary = Color3.fromRGB(100, 80, 60),
			secondary = Color3.fromRGB(150, 50, 50),
			accent = Color3.fromRGB(200, 200, 100),
		},

		sounds = {
			idle = { "DimorphChirp1", "DimorphChirp2" },
			alert = "DimorphScreech",
			attack = "DimorphBite",
			hurt = "DimorphPain",
			death = "DimorphDeath",
		},

		animations = {
			idle = "DimorphIdle",
			walk = "DimorphHop",
			run = "DimorphHop",
			attack = "DimorphDive",
			hurt = "DimorphFlinch",
			death = "DimorphDeath",
		},

		aggroDecay = 0.25,
		memoryDuration = 15,
		patrolRadius = 80,
		idleVariety = 0.7,
	},
}

--------------------------------------------------------------------------------
-- EPIC TIER - Major threat, powerful abilities
--------------------------------------------------------------------------------

DinosaurData.Epic = {
	Carnotaurus = {
		name = "Carnotaurus",
		displayName = "Carno",
		description = "Relentless pursuit predator. Once it locks onto prey, it never stops chasing. Destroys cover in its path.",
		tier = "Epic" :: Types.DinosaurTier,

		health = 400,
		damage = 60,
		speed = 32,
		turnSpeed = 4,
		attackRate = 0.8,
		attackRange = 6,

		detectionRange = 70,
		hearingRange = 90,
		smellRange = 100,

		size = Vector3.new(3, 4, 8),
		mass = 2000,

		behavior = {
			name = "Pursuit",
			phases = { "Hunt", "Chase", "Rampage", "Kill" },
			aggroThreshold = 0.3,
			packCoordination = false,
			nightBehavior = "Aggressive",
		},
		territorySize = 120,

		abilities = {
			{
				name = "BreakCover",
				cooldown = 8,
				damage = 30,
				range = 8,
				effect = "DestroyDestructibles",
				animation = "CarnoCharge",
				sound = "CrashImpact",
				particles = "DebrisExplosion",
			},
			{
				name = "Rampage",
				cooldown = 20,
				duration = 8,
				effect = "IncreasedSpeedAndDamage",
				animation = "CarnoRoar",
				sound = "CarnoRoar",
			},
			{
				name = "HeadButt",
				cooldown = 5,
				damage = 45,
				effect = "Stun",
				animation = "CarnoButt",
			},
		},

		knockback = 1.5,

		canSwim = false,
		canFly = false,

		visuals = {
			eyeGlow = Color3.fromRGB(255, 50, 0),
			trailEffect = "ChargeDust",
			impactEffect = "LargeBlood",
			deathEffect = "LargeCorpse",
		},
		colors = {
			primary = Color3.fromRGB(80, 40, 40),
			secondary = Color3.fromRGB(120, 60, 50),
			accent = Color3.fromRGB(200, 50, 30),
		},

		sounds = {
			idle = { "CarnoGrowl1", "CarnoGrowl2" },
			alert = "CarnoBellow",
			attack = "CarnoBite",
			hurt = "CarnoPain",
			death = "CarnoDeath",
			special = {
				Rampage = "CarnoRoar",
				BreakCover = "CrashImpact",
			},
			footsteps = "HeavyThud",
		},

		animations = {
			idle = "CarnoIdle",
			walk = "CarnoWalk",
			run = "CarnoRun",
			attack = "CarnoBite",
			special = {
				Rampage = "CarnoRoar",
				HeadButt = "CarnoButt",
			},
			hurt = "CarnoFlinch",
			death = "CarnoDeath",
			roar = "CarnoRoar",
		},

		aggroDecay = 0.02,
		memoryDuration = 120,
		patrolRadius = 100,
		idleVariety = 0.4,
	},

	Spinosaurus = {
		name = "Spinosaurus",
		displayName = "Spino",
		description = "Massive semi-aquatic apex predator. Dominates rivers and lakesides. Its sail makes it visible from far away.",
		tier = "Epic" :: Types.DinosaurTier,

		health = 500,
		damage = 70,
		speed = 18,
		turnSpeed = 2,
		attackRate = 0.6,
		attackRange = 8,

		detectionRange = 50,
		hearingRange = 60,
		smellRange = 80,

		size = Vector3.new(4, 6, 12),
		mass = 8000,

		behavior = {
			name = "Territorial",
			phases = { "Patrol", "Warning", "Attack", "Defend" },
			aggroThreshold = 0.4,
			packCoordination = false,
		},
		territorySize = 100,

		abilities = {
			{
				name = "JawCrush",
				cooldown = 8,
				damage = 80,
				effect = "ArmorPierce",
				animation = "SpinoBite",
				sound = "BonesCrunch",
			},
			{
				name = "TailSweep",
				cooldown = 6,
				damage = 40,
				range = 10,
				effect = "AreaKnockback",
				animation = "SpinoTailSweep",
			},
			{
				name = "AquaticDominance",
				cooldown = 0, -- Passive
				effect = "WaterSpeedBoost",
			},
			{
				name = "Submerge",
				cooldown = 15,
				duration = 10,
				effect = "HideUnderwater",
				animation = "SpinoSubmerge",
			},
		},

		armorReduction = 0.15,

		canSwim = true,
		canFly = false,
		swimSpeed = 28,

		visuals = {
			trailEffect = "WaterWake",
			impactEffect = "MassiveBlood",
			deathEffect = "MassiveCorpse",
		},
		colors = {
			primary = Color3.fromRGB(60, 80, 60),
			secondary = Color3.fromRGB(80, 100, 80),
			accent = Color3.fromRGB(200, 150, 100),
		},

		sounds = {
			idle = { "SpinoGrowl1", "SpinoGrowl2" },
			alert = "SpinoRoar",
			attack = "SpinoSnap",
			hurt = "SpinoPain",
			death = "SpinoDeath",
			footsteps = "HeavyWetSteps",
		},

		animations = {
			idle = "SpinoIdle",
			walk = "SpinoWalk",
			run = "SpinoRun",
			attack = "SpinoBite",
			hurt = "SpinoFlinch",
			death = "SpinoDeath",
			roar = "SpinoRoar",
		},

		aggroDecay = 0.08,
		memoryDuration = 60,
		patrolRadius = 80,
		idleVariety = 0.3,
	},

	Mosasaurus = {
		name = "Mosasaurus",
		displayName = "Mosa",
		description = "Terror of the deep. This ocean predator attacks swimmers and boaters, dragging them to watery graves.",
		tier = "Epic" :: Types.DinosaurTier,

		health = 800,
		damage = 90,
		speed = 8, -- On land (nearly immobile)
		turnSpeed = 3,
		attackRate = 0.5,
		attackRange = 10,

		detectionRange = 100, -- Underwater detection
		hearingRange = 150,

		size = Vector3.new(6, 4, 20),
		mass = 15000,

		behavior = {
			name = "Ambush",
			phases = { "Lurk", "Track", "SurfaceStrike", "Drag" },
			aggroThreshold = 0.2,
			packCoordination = false,
		},
		territorySize = 150,

		abilities = {
			{
				name = "SurfaceStrike",
				cooldown = 15,
				damage = 100,
				range = 15,
				effect = "GrabAndDrag",
				animation = "MosaLunge",
				sound = "MassiveSplash",
				particles = "WaterExplosion",
			},
			{
				name = "DeepDive",
				cooldown = 20,
				duration = 15,
				effect = "BecomeUndetectable",
				animation = "MosaDive",
			},
			{
				name = "TailLash",
				cooldown = 8,
				damage = 60,
				range = 12,
				effect = "CreateWaves",
				animation = "MosaTailLash",
			},
			{
				name = "BoatDestroyer",
				cooldown = 25,
				damage = 150,
				effect = "DestroyWatercraft",
				animation = "MosaRam",
			},
		},

		armorReduction = 0.3,

		canSwim = true,
		canFly = false,
		swimSpeed = 30,

		visuals = {
			trailEffect = "DeepWaterWake",
			impactEffect = "MassiveBlood",
			deathEffect = "MassiveCorpse",
		},
		colors = {
			primary = Color3.fromRGB(40, 60, 80),
			secondary = Color3.fromRGB(60, 80, 100),
			accent = Color3.fromRGB(200, 200, 220),
		},

		sounds = {
			idle = { "MosaGroan1", "MosaGroan2" },
			alert = "MosaRoar",
			attack = "MosaBite",
			hurt = "MosaPain",
			death = "MosaDeath",
			ambient = "UnderwaterRumble",
		},

		animations = {
			idle = "MosaIdle",
			walk = "MosaSlither",
			run = "MosaSwim",
			attack = "MosaBite",
			hurt = "MosaFlinch",
			death = "MosaDeath",
		},

		aggroDecay = 0.05,
		memoryDuration = 90,
		patrolRadius = 120,
		idleVariety = 0.2,
	},
}

--------------------------------------------------------------------------------
-- LEGENDARY TIER (BOSSES) - Maximum threat
--------------------------------------------------------------------------------

DinosaurData.Legendary = {
	TRex = {
		name = "Tyrannosaurus Rex",
		displayName = "T-Rex",
		description = "The apex predator. Enormous, powerful, and terrifying. Its roar freezes prey in fear. Few survive an encounter.",
		tier = "Legendary" :: Types.DinosaurTier,

		health = 2000,
		damage = 100,
		speed = 25,
		turnSpeed = 2,
		attackRate = 0.5,
		attackRange = 10,

		detectionRange = 100,
		hearingRange = 150,
		smellRange = 200,

		size = Vector3.new(5, 8, 15),
		mass = 9000,

		behavior = {
			name = "Apex",
			phases = { "Hunt", "Intimidate", "Chase", "Destroy" },
			aggroThreshold = 0.2,
			packCoordination = false,
			nightBehavior = "Hunter",
		},
		territorySize = 200,

		abilities = {
			{
				name = "Roar",
				cooldown = 20,
				duration = 2,
				range = 60,
				effect = "FearAndSlow",
				animation = "TRexRoar",
				sound = "TRexRoar",
				particles = "ShockwaveRing",
			},
			{
				name = "Stomp",
				cooldown = 10,
				damage = 50,
				range = 15,
				effect = "AreaKnockdown",
				animation = "TRexStomp",
				sound = "MassiveImpact",
				particles = "GroundShake",
			},
			{
				name = "TailSwipe",
				cooldown = 8,
				damage = 60,
				range = 12,
				effect = "MassiveKnockback",
				animation = "TRexTailSwipe",
			},
			{
				name = "CrushingBite",
				cooldown = 5,
				damage = 120,
				effect = "InstantKillIfLowHealth",
				animation = "TRexBite",
				sound = "BonesCrunch",
			},
			{
				name = "SmellWounded",
				cooldown = 30,
				range = 200,
				effect = "DetectLowHealthPlayers",
			},
		},

		armorReduction = 0.3,
		knockback = 3.0,

		canSwim = false,
		canFly = false,

		visuals = {
			eyeGlow = Color3.fromRGB(255, 200, 0),
			trailEffect = "MassiveDust",
			ambientParticles = "IntimidationAura",
			impactEffect = "MassiveBlood",
			deathEffect = "BossCorpse",
		},
		colors = {
			primary = Color3.fromRGB(60, 50, 40),
			secondary = Color3.fromRGB(80, 70, 60),
			accent = Color3.fromRGB(100, 50, 30),
		},

		sounds = {
			idle = { "TRexBreath1", "TRexGrowl1", "TRexGrowl2" },
			alert = "TRexSnarl",
			attack = "TRexBite",
			hurt = "TRexRoarPain",
			death = "TRexDeath",
			special = {
				Roar = "TRexRoar",
				Stomp = "MassiveImpact",
			},
			footsteps = "EarthShake",
			ambient = "TRexBreathing",
		},

		animations = {
			idle = "TRexIdle",
			walk = "TRexWalk",
			run = "TRexRun",
			attack = "TRexBite",
			special = {
				Roar = "TRexRoar",
				Stomp = "TRexStomp",
				TailSwipe = "TRexTailSwipe",
			},
			hurt = "TRexFlinch",
			death = "TRexDeath",
			roar = "TRexRoar",
		},

		aggroDecay = 0.01,
		memoryDuration = 180,
		patrolRadius = 150,
		idleVariety = 0.3,
	},

	Indoraptor = {
		name = "Indoraptor",
		displayName = "Indo",
		description = "Genetically engineered nightmare. Intelligent, stealthy, and sadistic. It toys with prey before the kill.",
		tier = "Legendary" :: Types.DinosaurTier,

		health = 1500,
		damage = 80,
		speed = 30,
		turnSpeed = 6,
		attackRate = 1.2,
		attackRange = 6,

		detectionRange = 80,
		hearingRange = 120,
		smellRange = 100,
		nightVisionRange = 150,

		size = Vector3.new(2, 4, 7),
		mass = 500,

		behavior = {
			name = "Stalker",
			phases = { "Observe", "Stalk", "Terrorize", "Strike", "Toy" },
			aggroThreshold = 0.3,
			packCoordination = false,
			nightBehavior = "Dominant",
		},
		territorySize = 150,

		abilities = {
			{
				name = "Echolocation",
				cooldown = 10,
				range = 150,
				effect = "DetectAllNearbyPlayers",
				sound = "IndoClick",
			},
			{
				name = "NightVision",
				cooldown = 0, -- Passive
				effect = "PerfectDarkVision",
			},
			{
				name = "OpenDoors",
				cooldown = 5,
				effect = "BypassDoorObstacles",
				animation = "IndoOpenDoor",
			},
			{
				name = "SilentStalk",
				cooldown = 15,
				duration = 10,
				effect = "NoFootstepSounds",
				animation = "IndoCreep",
			},
			{
				name = "SavagePounce",
				cooldown = 8,
				damage = 100,
				range = 15,
				effect = "PinAndMaul",
				animation = "IndoPounce",
				sound = "IndoShriek",
			},
			{
				name = "TerrorScream",
				cooldown = 25,
				range = 40,
				effect = "DisableHUD",
				animation = "IndoScream",
				sound = "IndoScream",
			},
		},

		critChance = 0.25,

		canSwim = true,
		canFly = false,
		swimSpeed = 15,
		climbAngle = 60,

		visuals = {
			eyeGlow = Color3.fromRGB(255, 255, 0),
			trailEffect = "ShadowTrail",
			ambientParticles = "DarkMist",
			impactEffect = "LargeBlood",
			deathEffect = "BossCorpse",
		},
		colors = {
			primary = Color3.fromRGB(20, 20, 25),
			secondary = Color3.fromRGB(40, 40, 50),
			accent = Color3.fromRGB(255, 200, 0),
		},

		sounds = {
			idle = { "IndoBreath1", "IndoGrowl1", "IndoClick1" },
			alert = "IndoSnarl",
			attack = "IndoShriek",
			hurt = "IndoPain",
			death = "IndoDeath",
			special = {
				Echolocation = "IndoClick",
				TerrorScream = "IndoScream",
			},
			footsteps = "SilentClaws",
			ambient = "IndoBreathing",
		},

		animations = {
			idle = "IndoIdle",
			walk = "IndoCreep",
			run = "IndoRun",
			attack = "IndoSlash",
			special = {
				SavagePounce = "IndoPounce",
				OpenDoors = "IndoOpenDoor",
				TerrorScream = "IndoScream",
			},
			hurt = "IndoFlinch",
			death = "IndoDeath",
			roar = "IndoScream",
		},

		aggroDecay = 0.02,
		memoryDuration = 300, -- Never forgets
		patrolRadius = 100,
		idleVariety = 0.9,
	},
}

--------------------------------------------------------------------------------
-- LOOT TABLES
--------------------------------------------------------------------------------

DinosaurData.LootTables = {
	Common = {
		{ itemType = "Bandage", chance = 0.5, countMin = 1, countMax = 3 },
		{ itemType = "LightAmmo", chance = 0.6, countMin = 15, countMax = 30 },
		{ itemType = "MediumAmmo", chance = 0.3, countMin = 10, countMax = 20 },
	},
	Uncommon = {
		{ itemType = "Bandage", chance = 0.6, countMin = 2, countMax = 5 },
		{ itemType = "MedKit", chance = 0.2, countMin = 1, countMax = 1 },
		{ itemType = "ShieldSerum", chance = 0.3, countMin = 1, countMax = 2 },
		{ itemType = "MediumAmmo", chance = 0.5, countMin = 20, countMax = 40 },
		{ itemType = "Shells", chance = 0.3, countMin = 5, countMax = 10 },
	},
	Rare = {
		{ itemType = "MedKit", chance = 0.5, countMin = 1, countMax = 2 },
		{ itemType = "ShieldSerum", chance = 0.5, countMin = 1, countMax = 3 },
		{ itemType = "MegaSerum", chance = 0.2, countMin = 1, countMax = 1 },
		{ itemType = "FragGrenade", chance = 0.3, countMin = 1, countMax = 2 },
		{ itemType = "HeavyAmmo", chance = 0.4, countMin = 5, countMax = 15 },
		{ itemType = "RareWeapon", chance = 0.3, countMin = 1, countMax = 1 },
	},
	Epic = {
		{ itemType = "MedKit", chance = 0.7, countMin = 1, countMax = 2 },
		{ itemType = "MegaSerum", chance = 0.5, countMin = 1, countMax = 2 },
		{ itemType = "SlurpCanteen", chance = 0.2, countMin = 1, countMax = 1 },
		{ itemType = "FragGrenade", chance = 0.5, countMin = 2, countMax = 4 },
		{ itemType = "GrappleHook", chance = 0.3, countMin = 1, countMax = 1 },
		{ itemType = "EpicWeapon", chance = 0.5, countMin = 1, countMax = 1 },
	},
	Legendary = {
		{ itemType = "DinoAdrenaline", chance = 1.0, countMin = 1, countMax = 2 },
		{ itemType = "SlurpCanteen", chance = 0.8, countMin = 1, countMax = 2 },
		{ itemType = "LegendaryWeapon", chance = 1.0, countMin = 2, countMax = 3 },
		{ itemType = "GrappleHook", chance = 0.7, countMin = 1, countMax = 1 },
		{ itemType = "MotionSensor", chance = 0.5, countMin = 2, countMax = 3 },
	},
}

--------------------------------------------------------------------------------
-- SPAWN WEIGHTS BY BIOME
--------------------------------------------------------------------------------

DinosaurData.SpawnWeights = {
	Jungle = {
		Compsognathus = 10,
		Gallimimus = 5,
		Dilophosaurus = 8,
		Velociraptor = 6,
		Carnotaurus = 2,
		Dimorphodon = 4,
	},
	Desert = {
		Gallimimus = 8,
		Pteranodon = 6,
		Carnotaurus = 4,
		Dimorphodon = 3,
	},
	Mountains = {
		Triceratops = 6,
		Carnotaurus = 4,
		TRex = 1,
		Pteranodon = 5,
	},
	Plains = {
		Gallimimus = 10,
		Triceratops = 8,
		Velociraptor = 4,
		Carnotaurus = 3,
		TRex = 1,
	},
	Swamp = {
		Compsognathus = 8,
		Dilophosaurus = 10,
		Baryonyx = 8,
		Spinosaurus = 3,
	},
	Coast = {
		Gallimimus = 6,
		Pteranodon = 10,
		Baryonyx = 5,
		Dimorphodon = 6,
		Mosasaurus = 2,
	},
	Volcanic = {
		Carnotaurus = 8,
		TRex = 2,
		Velociraptor = 5,
		Pteranodon = 4,
	},
	Research = {
		Velociraptor = 8,
		Indoraptor = 1,
		Dilophosaurus = 4,
		Compsognathus = 6,
	},
}

--------------------------------------------------------------------------------
-- TIER SPAWN RATES
--------------------------------------------------------------------------------

DinosaurData.TierSpawnRates = {
	Common = 0.40,
	Uncommon = 0.30,
	Rare = 0.20,
	Epic = 0.08,
	Legendary = 0.02,
}

--------------------------------------------------------------------------------
-- LOOKUP TABLES
--------------------------------------------------------------------------------

DinosaurData.AllDinosaurs = {} :: { [string]: DinosaurDefinition }
DinosaurData.ByTier = {} :: { [string]: { string } }

-- Populate lookup tables
for _, tier in pairs({ "Common", "Uncommon", "Rare", "Epic", "Legendary" }) do
	DinosaurData.ByTier[tier] = {}
	for dinoId, dinoDef in pairs(DinosaurData[tier]) do
		DinosaurData.AllDinosaurs[dinoId] = dinoDef
		table.insert(DinosaurData.ByTier[tier], dinoId)
	end
end

--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------------

function DinosaurData.GetDinosaur(dinoId: string): DinosaurDefinition?
	return DinosaurData.AllDinosaurs[dinoId]
end

function DinosaurData.GetDinosaursByTier(tier: Types.DinosaurTier): { [string]: DinosaurDefinition }
	return DinosaurData[tier] or {}
end

function DinosaurData.GetLootTable(tier: Types.DinosaurTier): { LootTableEntry }
	return DinosaurData.LootTables[tier] or {}
end

function DinosaurData.GetSpawnWeightsForBiome(biome: string): { [string]: number }
	return DinosaurData.SpawnWeights[biome] or {}
end

function DinosaurData.HasAbility(dinoId: string, abilityName: string): boolean
	local dino = DinosaurData.AllDinosaurs[dinoId]
	if not dino or not dino.abilities then
		return false
	end

	for _, ability in ipairs(dino.abilities) do
		if ability.name == abilityName then
			return true
		end
	end

	return false
end

function DinosaurData.GetAbility(dinoId: string, abilityName: string): AbilityDefinition?
	local dino = DinosaurData.AllDinosaurs[dinoId]
	if not dino or not dino.abilities then
		return nil
	end

	for _, ability in ipairs(dino.abilities) do
		if ability.name == abilityName then
			return ability
		end
	end

	return nil
end

function DinosaurData.GetDinosaurColors(dinoId: string): { primary: Color3, secondary: Color3, accent: Color3 }?
	local dino = DinosaurData.AllDinosaurs[dinoId]
	return dino and dino.colors
end

function DinosaurData.GetDinosaurSounds(dinoId: string): SoundDesign?
	local dino = DinosaurData.AllDinosaurs[dinoId]
	return dino and dino.sounds
end

function DinosaurData.CanSwim(dinoId: string): boolean
	local dino = DinosaurData.AllDinosaurs[dinoId]
	return dino and dino.canSwim or false
end

function DinosaurData.CanFly(dinoId: string): boolean
	local dino = DinosaurData.AllDinosaurs[dinoId]
	return dino and dino.canFly or false
end

function DinosaurData.GetBehaviorPhases(dinoId: string): { string }
	local dino = DinosaurData.AllDinosaurs[dinoId]
	return dino and dino.behavior.phases or {}
end

return DinosaurData
