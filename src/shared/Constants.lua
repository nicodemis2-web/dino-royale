--!strict
--[[
    Constants.lua
    =============
    Game-wide constants for Dino Royale
]]

local Constants = {}

-- Player (per GDD Appendix A)
Constants.PLAYER = {
    MAX_HEALTH = 100,
    MAX_SHIELD = 100,
    MAX_STAMINA = 100,

    -- Movement speeds (studs/sec per GDD)
    WALK_SPEED = 16,
    SPRINT_SPEED = 24,
    CROUCH_SPEED = 8,
    PRONE_SPEED = 4,

    -- Jump (GDD: 7 studs height)
    JUMP_HEIGHT = 7,
    JUMP_POWER = 50, -- Roblox default, gives ~7 stud jump

    -- Stamina
    STAMINA_SPRINT_COST = 10, -- per second
    STAMINA_JUMP_COST = 15,
    STAMINA_REGEN = 20, -- per second

    -- Revival (per GDD Section 8.1)
    REVIVE_TIME = 5, -- seconds to revive teammate
    BLEEDOUT_TIME = 90, -- seconds before death when downed
}

-- Combat
Constants.COMBAT = {
    HEADSHOT_MULTIPLIER = 2.0,
    BODY_MULTIPLIER = 1.0,
    LIMB_MULTIPLIER = 0.75,
}

-- Match (per GDD Section 2.2)
Constants.MATCH = {
    MIN_PLAYERS = 20, -- Minimum to start match
    MAX_PLAYERS = 100, -- 100-player battle royale
    LOBBY_WAIT_TIME = 60, -- Pre-Game Lobby: 60 seconds
    DEPLOY_TIME = 90, -- Deployment phase: 90 seconds
    MATCH_TIMEOUT = 1200, -- 20 minute max match (GDD: 15-20 min end game)
}

-- Rarity
Constants.RARITY = {
    COMMON = { name = "Common", multiplier = 1.0, color = Color3.fromHex("#9CA3AF") },
    UNCOMMON = { name = "Uncommon", multiplier = 1.1, color = Color3.fromHex("#22C55E") },
    RARE = { name = "Rare", multiplier = 1.2, color = Color3.fromHex("#3B82F6") },
    EPIC = { name = "Epic", multiplier = 1.3, color = Color3.fromHex("#A855F7") },
    LEGENDARY = { name = "Legendary", multiplier = 1.4, color = Color3.fromHex("#F59E0B") },
}

return Constants
