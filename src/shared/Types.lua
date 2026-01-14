--!strict
--[[
    Types.lua
    =========
    Type definitions for Dino Royale
]]

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"

export type WeaponStats = {
    damage: number,
    fireRate: number,
    magSize: number,
    reloadTime: number,
    range: number,
    spread: number,
}

export type WeaponState = {
    currentAmmo: number,
    reserveAmmo: number,
    isReloading: boolean,
    lastFireTime: number,
}

export type PlayerState = {
    health: number,
    shield: number,
    stamina: number,
    isAlive: boolean,
    isDowned: boolean,
}

export type DinosaurTier = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"

export type DinosaurState = "Idle" | "Patrol" | "Alert" | "Chase" | "Attack" | "Flee"

export type MatchState = "Lobby" | "Loading" | "Deploying" | "Playing" | "Ending" | "Resetting"

export type StormPhase = {
	phase: number,
	waitTime: number,
	shrinkTime: number,
	damage: number,
	startRadius: number,
	endRadius: number,
}

export type CircleData = {
	center: Vector3,
	radius: number,
}

export type FlightPath = {
	startPoint: Vector3,
	endPoint: Vector3,
	duration: number,
}

return nil
