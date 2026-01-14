--!strict
--[[
	BiomeManager.lua
	================
	Server-side biome management
	Handles biome effects, hazards, and environmental conditions
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local BiomeData = require(ReplicatedStorage.Shared.BiomeData)
local Events = require(ReplicatedStorage.Shared.Events)

local BiomeManager = {}

-- State
local isInitialized = false
local activeBiomeEffects: { [string]: any } = {}
local playerBiomes: { [Player]: BiomeData.BiomeType } = {}

-- Update interval
local BIOME_CHECK_INTERVAL = 1.0 -- seconds

--[[
	Get the biome a player is currently in
]]
function BiomeManager.GetPlayerBiome(player: Player): BiomeData.BiomeType?
	return playerBiomes[player]
end

--[[
	Check and update player biome
]]
local function updatePlayerBiome(player: Player)
	local character = player.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local position = rootPart.Position
	local newBiome = BiomeData.GetBiomeAtPosition(position.X, position.Z)
	local oldBiome = playerBiomes[player]

	if newBiome ~= oldBiome then
		playerBiomes[player] = newBiome

		-- Notify client of biome change
		Events.FireClient(player, "Map", "BiomeChanged", {
			biome = newBiome,
			config = BiomeData.Biomes[newBiome],
		})

		-- Apply biome-specific effects
		BiomeManager.ApplyBiomeEffects(player, newBiome, oldBiome)
	end
end

--[[
	Apply biome-specific effects to player
]]
function BiomeManager.ApplyBiomeEffects(player: Player, newBiome: BiomeData.BiomeType, oldBiome: BiomeData.BiomeType?)
	local config = BiomeData.Biomes[newBiome]
	if not config then return end

	-- Remove old biome effects
	if oldBiome then
		BiomeManager.RemoveBiomeEffects(player, oldBiome)
	end

	-- Apply new biome hazard checks
	if newBiome == "Volcanic" then
		-- Start heat damage check
		BiomeManager.StartHazardEffect(player, "Heat", {
			damagePerTick = 1,
			tickRate = 5,
			message = "The volcanic heat is draining your health!",
		})
	elseif newBiome == "Swamp" then
		-- Slow movement in swamp
		BiomeManager.ApplyMovementModifier(player, "SwampSlow", 0.85)
	end
end

--[[
	Remove biome effects from player
]]
function BiomeManager.RemoveBiomeEffects(player: Player, biome: BiomeData.BiomeType)
	local effectKey = player.UserId .. "_" .. biome

	if activeBiomeEffects[effectKey] then
		-- Cancel any running effect
		if activeBiomeEffects[effectKey].cancel then
			activeBiomeEffects[effectKey].cancel()
		end
		activeBiomeEffects[effectKey] = nil
	end

	-- Remove movement modifiers
	if biome == "Swamp" then
		BiomeManager.RemoveMovementModifier(player, "SwampSlow")
	end
end

--[[
	Start a hazard effect on player
]]
function BiomeManager.StartHazardEffect(player: Player, hazardType: string, config: any)
	local effectKey = player.UserId .. "_" .. hazardType
	local running = true

	activeBiomeEffects[effectKey] = {
		cancel = function()
			running = false
		end,
	}

	task.spawn(function()
		while running do
			task.wait(config.tickRate or 1)

			if not running then break end

			local character = player.Character
			if not character then continue end

			local humanoid = character:FindFirstChild("Humanoid")
			if not humanoid then continue end

			-- Check if player is still in hazard zone
			local rootPart = character:FindFirstChild("HumanoidRootPart")
			if not rootPart then continue end

			local currentBiome = BiomeData.GetBiomeAtPosition(rootPart.Position.X, rootPart.Position.Z)

			if hazardType == "Heat" and currentBiome == "Volcanic" then
				-- Apply damage
				humanoid:TakeDamage(config.damagePerTick or 1)

				-- Notify client
				Events.FireClient(player, "Map", "HazardDamage", {
					hazardType = hazardType,
					damage = config.damagePerTick,
					message = config.message,
				})
			end
		end
	end)
end

--[[
	Apply movement speed modifier
]]
function BiomeManager.ApplyMovementModifier(player: Player, modifierName: string, multiplier: number)
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	-- Store original speed if not stored
	local originalSpeed = humanoid:GetAttribute("OriginalWalkSpeed") or humanoid.WalkSpeed
	humanoid:SetAttribute("OriginalWalkSpeed", originalSpeed)
	humanoid:SetAttribute("Modifier_" .. modifierName, multiplier)

	-- Calculate new speed with all modifiers
	local newSpeed = originalSpeed
	for _, attr in ipairs(humanoid:GetAttributes()) do
		if string.find(tostring(attr), "Modifier_") then
			local mod = humanoid:GetAttribute(tostring(attr))
			if mod then
				newSpeed = newSpeed * mod
			end
		end
	end

	humanoid.WalkSpeed = newSpeed
end

--[[
	Remove movement speed modifier
]]
function BiomeManager.RemoveMovementModifier(player: Player, modifierName: string)
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	humanoid:SetAttribute("Modifier_" .. modifierName, nil)

	-- Recalculate speed
	local originalSpeed = humanoid:GetAttribute("OriginalWalkSpeed") or 16
	local newSpeed = originalSpeed

	for name, value in pairs(humanoid:GetAttributes()) do
		if string.find(name, "Modifier_") then
			newSpeed = newSpeed * value
		end
	end

	humanoid.WalkSpeed = newSpeed
end

--[[
	Get danger level at position
]]
function BiomeManager.GetDangerLevelAtPosition(x: number, z: number): number
	local biome = BiomeData.GetBiomeAtPosition(x, z)
	return BiomeData.GetDangerLevel(biome)
end

--[[
	Get loot multiplier at position
]]
function BiomeManager.GetLootMultiplierAtPosition(x: number, z: number): number
	local biome = BiomeData.GetBiomeAtPosition(x, z)
	return BiomeData.GetLootMultiplier(biome)
end

--[[
	Get dinosaur spawn config for position
]]
function BiomeManager.GetDinosaurConfigAtPosition(x: number, z: number): { types: { string }, density: number }
	local biome = BiomeData.GetBiomeAtPosition(x, z)
	local config = BiomeData.Biomes[biome]

	if config then
		return {
			types = config.dinosaurTypes,
			density = config.dinosaurDensity,
		}
	end

	return {
		types = {},
		density = 1.0,
	}
end

--[[
	Initialize the biome manager
]]
function BiomeManager.Initialize()
	if isInitialized then return end

	-- Track player biomes
	task.spawn(function()
		while true do
			task.wait(BIOME_CHECK_INTERVAL)

			for _, player in ipairs(Players:GetPlayers()) do
				updatePlayerBiome(player)
			end
		end
	end)

	-- Clean up when players leave
	Players.PlayerRemoving:Connect(function(player)
		-- Clean up effects
		for key, effect in pairs(activeBiomeEffects) do
			if string.find(key, tostring(player.UserId)) then
				if effect.cancel then
					effect.cancel()
				end
				activeBiomeEffects[key] = nil
			end
		end

		playerBiomes[player] = nil
	end)

	isInitialized = true
	print("[BiomeManager] Initialized")
end

--[[
	Reset for new match
]]
function BiomeManager.Reset()
	-- Clear all effects
	for key, effect in pairs(activeBiomeEffects) do
		if effect.cancel then
			effect.cancel()
		end
	end
	activeBiomeEffects = {}
	playerBiomes = {}

	print("[BiomeManager] Reset")
end

return BiomeManager
