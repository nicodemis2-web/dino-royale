--!strict
--[[
	GameConfig.lua
	==============
	Central game configuration
	All tunable values and settings for Dino Royale
]]

local GameConfig = {}

-- Match settings
GameConfig.Match = {
	MinPlayers = 2, -- Minimum to start (for testing, normally 20+)
	MaxPlayers = 100,
	LobbyCountdown = 60, -- Seconds in lobby before match starts
	DeploymentDuration = 120, -- Seconds for deployment phase
	MatchTimeout = 1800, -- 30 minute max match
}

-- Player settings
GameConfig.Player = {
	MaxHealth = 100,
	MaxShield = 100,
	SprintSpeed = 24,
	WalkSpeed = 16,
	CrouchSpeed = 8,
	JumpPower = 50,

	-- Revive settings
	DownedDuration = 30, -- Seconds before bleed out
	ReviveTime = 5, -- Seconds to revive
	ReviveHealth = 30, -- Health after revive

	-- Reboot settings
	RebootCardDuration = 90, -- Seconds before card expires
	RebootRespawnDelay = 3,
	RebootProtectionTime = 5,
}

-- Inventory settings
GameConfig.Inventory = {
	MaxSlots = 5,
	MaxMaterials = 999,
	MaxAmmoPerType = 999,

	-- Stack sizes
	AmmoStack = {
		Light = 60,
		Medium = 50,
		Heavy = 20,
		Shells = 25,
		Rockets = 6,
	},

	HealingStack = {
		Bandage = 15,
		Medkit = 3,
		ShieldPotion = 3,
		MiniShield = 6,
	},
}

-- Storm/Zone settings
GameConfig.Storm = {
	Phases = {
		{
			waitTime = 180, -- 3 min before first shrink
			shrinkTime = 120, -- 2 min to shrink
			damagePerTick = 1,
			finalRadius = 0.7, -- % of previous
		},
		{
			waitTime = 120,
			shrinkTime = 90,
			damagePerTick = 2,
			finalRadius = 0.6,
		},
		{
			waitTime = 90,
			shrinkTime = 60,
			damagePerTick = 5,
			finalRadius = 0.5,
		},
		{
			waitTime = 60,
			shrinkTime = 45,
			damagePerTick = 8,
			finalRadius = 0.4,
		},
		{
			waitTime = 45,
			shrinkTime = 30,
			damagePerTick = 10,
			finalRadius = 0.3,
		},
		{
			waitTime = 30,
			shrinkTime = 20,
			damagePerTick = 15,
			finalRadius = 0,
		},
	},

	TickInterval = 1, -- Damage every 1 second
	InitialRadius = 1000, -- Starting zone radius
}

-- Weapon settings
GameConfig.Weapons = {
	-- Damage multipliers
	HeadshotMultiplier = 2.0,
	LimbshotMultiplier = 0.75,

	-- Fall-off
	DamageFalloffStart = 50, -- Studs before damage falls off
	DamageFalloffEnd = 150, -- Full falloff at this distance
	DamageFalloffMin = 0.5, -- Minimum damage multiplier

	-- Spread
	BaseSpread = 0.02,
	MovingSpreadMultiplier = 1.5,
	JumpingSpreadMultiplier = 2.0,
	CrouchingSpreadMultiplier = 0.7,
	ADSSpreadMultiplier = 0.5,
}

-- Vehicle settings
GameConfig.Vehicles = {
	MaxVehicles = 30,

	SpawnCounts = {
		Jeep = 8,
		ATV = 10,
		Boat = 6,
		Helicopter = 2,
		Motorcycle = 8,
	},

	-- General
	ExitDamageThreshold = 30, -- Take damage if exiting above this speed
	CollisionDamageMultiplier = 0.5,
}

-- Dinosaur settings
GameConfig.Dinosaurs = {
	MaxDinosaurs = 50,

	-- Spawn density (per 100x100 stud area)
	SpawnDensity = {
		Common = 0.5,
		Uncommon = 0.2,
		Rare = 0.1,
	},

	-- Aggro settings
	AggroDecayRate = 0.1, -- Per second
	NoiseSensitivity = 1.5,
	SightRange = 100,

	-- Loot drops
	LootDropChance = {
		Common = 0.3,
		Uncommon = 0.5,
		Rare = 0.7,
		Boss = 1.0,
	},
}

-- Boss settings
GameConfig.Bosses = {
	TRex = {
		Health = 2000,
		Damage = 100,
		SpawnPhases = { 3, 4 }, -- Storm phases where T-Rex can spawn
		SpawnChance = 0.3,
	},

	Indoraptor = {
		Health = 1200,
		Damage = 75,
		PlayerThreshold = 10, -- Spawns when <= 10 players remain
	},
}

-- Loot settings
GameConfig.Loot = {
	-- Rarity weights (higher = more common)
	RarityWeights = {
		Common = 45,
		Uncommon = 30,
		Rare = 15,
		Epic = 8,
		Legendary = 2,
	},

	-- Floor loot spawn chance
	FloorLootChance = 0.3,

	-- Chest contents
	ChestItemCount = { min = 2, max = 4 },
	SupplyDropItemCount = { min = 3, max = 5 },
}

-- Audio settings
GameConfig.Audio = {
	DefaultMusicVolume = 0.7,
	DefaultSFXVolume = 0.8,
	DefaultAmbientVolume = 0.5,

	-- 3D audio
	RolloffStart = 10,
	RolloffEnd = 200,
}

-- UI settings
GameConfig.UI = {
	DamageNumberDuration = 1.0,
	KillFeedEntryDuration = 5.0,
	KillFeedMaxEntries = 6,
}

-- Debug settings
GameConfig.Debug = {
	Enabled = true, -- Set to true for development testing
	ShowHitboxes = false,
	ShowAIDebug = false,
	GodMode = false,
	InfiniteAmmo = false,

	-- Solo testing mode - bypasses player count requirements
	SoloTestMode = true,
	SkipLobbyCountdown = true,
	QuickDeploy = true, -- Shorter deployment phase for testing

	-- Admin user IDs who can use debug commands (add your Roblox UserId)
	AdminUserIds = {},
}

return GameConfig
