--!strict
--[[
    Constants.lua
    =============
    Game-wide constants for Dino Royale
]]

local Constants = {}

-- Player
Constants.PLAYER = {
    MAX_HEALTH = 100,
    MAX_SHIELD = 100,
    MAX_STAMINA = 100,

    WALK_SPEED = 16,
    SPRINT_SPEED = 24,
    CROUCH_SPEED = 8,
    PRONE_SPEED = 4,

    STAMINA_SPRINT_COST = 10, -- per second
    STAMINA_JUMP_COST = 15,
    STAMINA_REGEN = 20, -- per second
}

-- Combat
Constants.COMBAT = {
    HEADSHOT_MULTIPLIER = 2.0,
    BODY_MULTIPLIER = 1.0,
    LIMB_MULTIPLIER = 0.75,
}

-- Match
Constants.MATCH = {
    MIN_PLAYERS = 20,
    MAX_PLAYERS = 100,
    LOBBY_WAIT_TIME = 60,
    DEPLOY_TIME = 90,
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
