--!strict
--[[
	GraphicsInitializer.lua
	=======================
	Master initialization script for all graphics and visual systems
	Coordinates startup sequence and integration between visual modules

	This module serves as the single entry point for graphics initialization,
	ensuring proper load order and dependency management between:
	- LightingManager (lighting, post-processing)
	- VisualQualityController (adaptive quality)
	- TerrainVisuals (terrain, water)
	- DinosaurVisualEffects (creature highlighting)
	- WeaponEffects (combat visuals)

	Initialization Order:
	1. VisualQualityController (determines initial quality level)
	2. LightingManager (sets up lighting based on quality)
	3. TerrainVisuals (configures terrain appearance)
	4. DinosaurVisualEffects (creature effects system)
	5. WeaponEffects (combat effects)
	6. Quality change listeners (connects all systems)

	Usage:
	local GraphicsInitializer = require(path.to.GraphicsInitializer)
	GraphicsInitializer.Initialize()
]]

local _ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Module references (lazy loaded)
local LightingManager: any = nil
local VisualQualityController: any = nil
local TerrainVisuals: any = nil
local DinosaurVisualEffects: any = nil
local WeaponEffects: any = nil

local GraphicsInitializer = {}

-- State
local isInitialized = false
local qualityChangeConnection: RBXScriptConnection? = nil

--[[
	Initialize all graphics systems in correct order
	Should be called once during client startup
]]
function GraphicsInitializer.Initialize()
	if isInitialized then
		warn("[GraphicsInitializer] Already initialized")
		return
	end

	print("[GraphicsInitializer] Starting graphics initialization...")
	local startTime = tick()

	-- Load modules
	GraphicsInitializer.LoadModules()

	-- Step 1: Initialize quality controller (determines device capabilities)
	if VisualQualityController then
		VisualQualityController.Initialize()
		print("[GraphicsInitializer] Quality controller ready")
	end

	-- Step 2: Initialize lighting (uses quality settings)
	if LightingManager then
		LightingManager.Initialize()
		print("[GraphicsInitializer] Lighting system ready")
	end

	-- Step 3: Initialize terrain visuals
	if TerrainVisuals then
		TerrainVisuals.Initialize()
		print("[GraphicsInitializer] Terrain visuals ready")
	end

	-- Step 4: Initialize dinosaur visual effects
	if DinosaurVisualEffects then
		DinosaurVisualEffects.Initialize()
		print("[GraphicsInitializer] Dinosaur effects ready")
	end

	-- Step 5: Initialize weapon effects
	if WeaponEffects then
		WeaponEffects.Initialize()
		print("[GraphicsInitializer] Weapon effects ready")
	end

	-- Step 6: Connect quality change listener
	GraphicsInitializer.ConnectQualityListener()

	-- Apply initial quality settings to all systems
	GraphicsInitializer.ApplyCurrentQualityToAll()

	isInitialized = true

	local elapsed = tick() - startTime
	print(`[GraphicsInitializer] All graphics systems initialized in {string.format("%.2f", elapsed)}s`)
end

--[[
	Load all graphics modules
	Uses pcall to handle missing modules gracefully
]]
function GraphicsInitializer.LoadModules()
	-- Load from client Graphics folder
	local clientScript = Players.LocalPlayer:WaitForChild("PlayerScripts")
	local _clientModules = clientScript:FindFirstChild("Client")

	-- Try to load each module
	local success, result

	-- LightingManager
	success, result = pcall(function()
		return require(script.Parent.LightingManager)
	end)
	if success then
		LightingManager = result
	else
		warn("[GraphicsInitializer] Failed to load LightingManager:", result)
	end

	-- VisualQualityController
	success, result = pcall(function()
		return require(script.Parent.VisualQualityController)
	end)
	if success then
		VisualQualityController = result
	else
		warn("[GraphicsInitializer] Failed to load VisualQualityController:", result)
	end

	-- TerrainVisuals
	success, result = pcall(function()
		return require(script.Parent.TerrainVisuals)
	end)
	if success then
		TerrainVisuals = result
	else
		warn("[GraphicsInitializer] Failed to load TerrainVisuals:", result)
	end

	-- DinosaurVisualEffects (in Effects folder)
	success, result = pcall(function()
		return require(script.Parent.Parent.Effects.DinosaurVisualEffects)
	end)
	if success then
		DinosaurVisualEffects = result
	else
		warn("[GraphicsInitializer] Failed to load DinosaurVisualEffects:", result)
	end

	-- WeaponEffects (in Effects folder)
	success, result = pcall(function()
		return require(script.Parent.Parent.Effects.WeaponEffects)
	end)
	if success then
		WeaponEffects = result
	else
		warn("[GraphicsInitializer] Failed to load WeaponEffects:", result)
	end
end

--[[
	Connect quality change listener to update all systems
]]
function GraphicsInitializer.ConnectQualityListener()
	if not VisualQualityController then return end

	qualityChangeConnection = VisualQualityController.OnQualityChanged:Connect(function(level, settings)
		GraphicsInitializer.OnQualityChanged(level, settings)
	end)
end

--[[
	Handle quality level changes
	Updates all visual systems with new quality settings
	@param level New quality level (1-5)
	@param settings Quality settings table
]]
function GraphicsInitializer.OnQualityChanged(level: number, settings: { [string]: any })
	print(`[GraphicsInitializer] Quality changed to level {level} ({settings.name})`)

	-- Update weapon effects quality
	if WeaponEffects and WeaponEffects.SetQualitySettings then
		WeaponEffects.SetQualitySettings({
			muzzleFlashEnabled = settings.muzzleFlashEnabled,
			shellCasingsEnabled = settings.shellCasingsEnabled,
			bulletTracersEnabled = settings.bulletTracersEnabled,
			impactEffectsEnabled = settings.impactEffectsEnabled,
			particleMultiplier = settings.particleMultiplier,
		})
	end

	-- Update terrain visuals for quality
	if TerrainVisuals then
		if level <= 2 then
			TerrainVisuals.ApplyPerformanceWater()
		elseif level >= 4 then
			TerrainVisuals.ApplyHighQualityWater()
		end
	end

	-- Lighting is automatically handled by VisualQualityController.ApplyQualityLevel
end

--[[
	Apply current quality settings to all systems
	Called after initialization to ensure consistent state
]]
function GraphicsInitializer.ApplyCurrentQualityToAll()
	if not VisualQualityController then return end

	local currentLevel = VisualQualityController.GetQualityLevel()
	local settings = VisualQualityController.GetQualitySettings(currentLevel)

	if settings then
		GraphicsInitializer.OnQualityChanged(currentLevel, settings)
	end
end

--[[
	Set lighting preset based on game state
	@param presetName Name of the lighting preset
	@param transitionTime Transition duration
]]
function GraphicsInitializer.SetLightingPreset(presetName: string, transitionTime: number?)
	if LightingManager then
		LightingManager.ApplyPreset(presetName, transitionTime)
	end
end

--[[
	Set terrain water preset based on biome
	@param biomeName Name of the biome
]]
function GraphicsInitializer.SetBiomeVisuals(biomeName: string)
	if TerrainVisuals then
		TerrainVisuals.SetBiomeWater(biomeName)
	end
end

--[[
	Register a dinosaur for visual effects
	@param model Dinosaur model
	@param species Species name
	@param threatLevel Threat classification
]]
function GraphicsInitializer.RegisterDinosaur(model: Model, species: string, threatLevel: string)
	if DinosaurVisualEffects then
		DinosaurVisualEffects.RegisterDinosaur(model, species, threatLevel)
	end
end

--[[
	Show damage effect on player (screen flash)
	@param intensity Damage intensity (0-1)
]]
function GraphicsInitializer.ShowDamageEffect(intensity: number)
	if LightingManager then
		LightingManager.DamageFlash(intensity)
	end
end

--[[
	Enable time-of-day cycle
	@param cycleDuration Duration of full day cycle in seconds
]]
function GraphicsInitializer.EnableTimeOfDay(cycleDuration: number?)
	if LightingManager then
		LightingManager.EnableTimeOfDay(cycleDuration)
	end
end

--[[
	Disable time-of-day cycle
]]
function GraphicsInitializer.DisableTimeOfDay()
	if LightingManager then
		LightingManager.DisableTimeOfDay()
	end
end

--[[
	Get current quality level
	@return Quality level (1-5)
]]
function GraphicsInitializer.GetQualityLevel(): number
	if VisualQualityController then
		return VisualQualityController.GetQualityLevel()
	end
	return 3 -- Default medium
end

--[[
	Set quality level manually
	@param level Quality level (1-5)
]]
function GraphicsInitializer.SetQualityLevel(level: number)
	if VisualQualityController then
		VisualQualityController.SetQualityLevel(level)
	end
end

--[[
	Enable/disable automatic quality adjustment
	@param enabled Whether to enable auto-adjust
]]
function GraphicsInitializer.SetAutoQuality(enabled: boolean)
	if VisualQualityController then
		VisualQualityController.SetAutoAdjust(enabled)
	end
end

--[[
	Get average FPS for performance monitoring
	@return Average FPS
]]
function GraphicsInitializer.GetAverageFPS(): number
	if VisualQualityController then
		return VisualQualityController.GetAverageFPS()
	end
	return 60
end

--[[
	Shutdown all graphics systems
	Call when leaving game or resetting
]]
function GraphicsInitializer.Shutdown()
	if not isInitialized then return end

	print("[GraphicsInitializer] Shutting down graphics systems...")

	-- Disconnect quality listener
	if qualityChangeConnection then
		qualityChangeConnection:Disconnect()
		qualityChangeConnection = nil
	end

	-- Shutdown each system
	if WeaponEffects and WeaponEffects.Cleanup then
		WeaponEffects.Cleanup()
	end

	if DinosaurVisualEffects and DinosaurVisualEffects.Shutdown then
		DinosaurVisualEffects.Shutdown()
	end

	if TerrainVisuals and TerrainVisuals.Shutdown then
		TerrainVisuals.Shutdown()
	end

	if LightingManager and LightingManager.Shutdown then
		LightingManager.Shutdown()
	end

	if VisualQualityController and VisualQualityController.Shutdown then
		VisualQualityController.Shutdown()
	end

	isInitialized = false
	print("[GraphicsInitializer] Shutdown complete")
end

return GraphicsInitializer
