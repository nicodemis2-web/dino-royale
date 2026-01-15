--!strict
--[[
	Main.server.lua
	===============
	Server entry point for Dino Royale
	SIMPLIFIED VERSION - Focus on getting basic spawning working
]]

print("===========================================")
print("  DINO ROYALE SERVER - INITIALIZING")
print("===========================================")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

-- STEP 1: Disable auto-spawning FIRST
Players.CharacterAutoLoads = false
print("[Server] CharacterAutoLoads = false")

-- STEP 2: Create a TEMPORARY spawn platform immediately
-- This will be replaced by MapManager once terrain is generated
local function createTempSpawnPlatform()
	print("[Server] Creating temporary spawn platform...")

	-- Remove ALL existing spawn locations first
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("SpawnLocation") then
			obj:Destroy()
		end
	end

	-- Remove old platforms (use consistent naming for cleanup)
	local oldPlatform = Workspace:FindFirstChild("TempSpawnPlatform")
	if oldPlatform then oldPlatform:Destroy() end
	local oldSpawn = Workspace:FindFirstChild("TempSpawn")
	if oldSpawn then oldSpawn:Destroy() end

	-- Create a large, visible platform (TEMPORARY - will be replaced by MapManager)
	local platform = Instance.new("Part")
	platform.Name = "TempSpawnPlatform"
	platform.Size = Vector3.new(100, 10, 100)
	platform.Position = Vector3.new(0, 50, 0)  -- 50 studs up
	platform.Anchored = true
	platform.CanCollide = true
	platform.BrickColor = BrickColor.new("Bright green")
	platform.Material = Enum.Material.Grass
	platform.TopSurface = Enum.SurfaceType.Smooth
	platform.BottomSurface = Enum.SurfaceType.Smooth
	platform.Parent = Workspace

	-- Create spawn location ON the platform
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "TempSpawn"
	spawn.Size = Vector3.new(20, 1, 20)
	spawn.Position = Vector3.new(0, 56, 0)  -- On top of platform
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 0.5
	spawn.BrickColor = BrickColor.new("White")
	spawn.Neutral = true
	spawn.Duration = 0  -- No force field
	spawn.Parent = Workspace

	print("[Server] Temporary spawn platform created at Y=50, spawn at Y=56")
	return platform, spawn
end

-- Create TEMP platform RIGHT NOW (MapManager will replace with proper biome terrain)
local tempSpawnPlatform, tempSpawnLocation = createTempSpawnPlatform()

-- STEP 3: Track players waiting to spawn
local playersToSpawn: {Player} = {}
local systemReady = false

-- STEP 4: Handle player joining - queue them for spawning
Players.PlayerAdded:Connect(function(player)
	print(`[Server] Player joined: {player.Name}`)

	if systemReady then
		-- System is ready, spawn immediately
		print(`[Server] Spawning {player.Name} immediately`)
		task.spawn(function()
			task.wait(0.5)  -- Small delay to ensure everything is ready
			player:LoadCharacter()
		end)
	else
		-- Queue for later
		print(`[Server] Queueing {player.Name} for spawn`)
		table.insert(playersToSpawn, player)
	end
end)

-- Handle players who are already connected
for _, player in ipairs(Players:GetPlayers()) do
	print(`[Server] Existing player found: {player.Name}`)
	table.insert(playersToSpawn, player)
end

-- STEP 5: Handle player leaving
Players.PlayerRemoving:Connect(function(player)
	print(`[Server] Player leaving: {player.Name}`)
	-- Remove from queue if present
	for i, p in ipairs(playersToSpawn) do
		if p == player then
			table.remove(playersToSpawn, i)
			break
		end
	end
end)

-- STEP 6: Wait for shared modules
print("[Server] Waiting for shared modules...")
local Shared = ReplicatedStorage:WaitForChild("Shared", 10)
if not Shared then
	warn("[Server] WARNING: Shared folder not found after 10 seconds!")
else
	print("[Server] Shared modules found")
end

-- STEP 7: Try to load Events module
local Events
local eventsLoaded = pcall(function()
	Events = require(ReplicatedStorage.Shared.Events)
	Events.Initialize()
	print("[Server] Events initialized")
end)

if not eventsLoaded then
	warn("[Server] WARNING: Failed to load Events module")
end

-- STEP 8: Declare module variables
local GameManager: any = nil
local StormManager: any = nil
local DeploymentManager: any = nil
local WeaponManager: any = nil
local InventoryManager: any = nil
local EliminationManager: any = nil
local DinosaurManager: any = nil
local BossEventManager: any = nil
local VehicleManager: any = nil
local MapManager: any = nil
local EnvironmentalEventManager: any = nil
local RevivalManager: any = nil
local RebootBeaconManager: any = nil
local ProgressionManager: any = nil
local PingManager: any = nil
local LootManager: any = nil
local CombatManager: any = nil
local HealingManager: any = nil
local BattlePassManager: any = nil
local ShopManager: any = nil
local TutorialManager: any = nil
local PartyManager: any = nil
local RankedManager: any = nil
local AccessibilityManager: any = nil
local AdminConsole: any = nil

-- STEP 9: Load modules safely
print("[Server] Loading modules...")

local function safeRequire(path, name)
	local success, result = pcall(function()
		return require(path)
	end)
	if success then
		print(`[Server] Loaded: {name}`)
		return result
	else
		warn(`[Server] FAILED to load {name}: {result}`)
		return nil
	end
end

local Core = script.Parent:FindFirstChild("Core")
local Player = script.Parent:FindFirstChild("Player")
local Weapons = script.Parent:FindFirstChild("Weapons")
local AI = script.Parent:FindFirstChild("AI")
local Vehicles = script.Parent:FindFirstChild("Vehicles")
local EventsFolder = script.Parent:FindFirstChild("Events")
local Map = script.Parent:FindFirstChild("Map")
local Loot = script.Parent:FindFirstChild("Loot")
local Combat = script.Parent:FindFirstChild("Combat")

if Core then
	GameManager = safeRequire(Core:FindFirstChild("GameManager"), "GameManager")
	StormManager = safeRequire(Core:FindFirstChild("StormManager"), "StormManager")
	DeploymentManager = safeRequire(Core:FindFirstChild("DeploymentManager"), "DeploymentManager")
	AdminConsole = safeRequire(Core:FindFirstChild("AdminConsole"), "AdminConsole")
end

if Map then
	MapManager = safeRequire(Map:FindFirstChild("MapManager"), "MapManager")
	EnvironmentalEventManager = safeRequire(Map:FindFirstChild("EnvironmentalEventManager"), "EnvironmentalEventManager")
end

if Weapons then
	WeaponManager = safeRequire(Weapons:FindFirstChild("WeaponManager"), "WeaponManager")
end

if Player then
	InventoryManager = safeRequire(Player:FindFirstChild("InventoryManager"), "InventoryManager")
	EliminationManager = safeRequire(Player:FindFirstChild("EliminationManager"), "EliminationManager")
	RevivalManager = safeRequire(Player:FindFirstChild("RevivalManager"), "RevivalManager")
	RebootBeaconManager = safeRequire(Player:FindFirstChild("RebootBeaconManager"), "RebootBeaconManager")
	ProgressionManager = safeRequire(Player:FindFirstChild("ProgressionManager"), "ProgressionManager")
	PingManager = safeRequire(Player:FindFirstChild("PingManager"), "PingManager")
	BattlePassManager = safeRequire(Player:FindFirstChild("BattlePassManager"), "BattlePassManager")
	ShopManager = safeRequire(Player:FindFirstChild("ShopManager"), "ShopManager")
	TutorialManager = safeRequire(Player:FindFirstChild("TutorialManager"), "TutorialManager")
	PartyManager = safeRequire(Player:FindFirstChild("PartyManager"), "PartyManager")
	RankedManager = safeRequire(Player:FindFirstChild("RankedManager"), "RankedManager")
	AccessibilityManager = safeRequire(Player:FindFirstChild("AccessibilityManager"), "AccessibilityManager")
end

if AI then
	DinosaurManager = safeRequire(AI:FindFirstChild("DinosaurManager"), "DinosaurManager")
end

if EventsFolder then
	BossEventManager = safeRequire(EventsFolder:FindFirstChild("BossEventManager"), "BossEventManager")
end

if Vehicles then
	VehicleManager = safeRequire(Vehicles:FindFirstChild("VehicleManager"), "VehicleManager")
end

if Loot then
	LootManager = safeRequire(Loot:FindFirstChild("LootManager"), "LootManager")
end

if Combat then
	CombatManager = safeRequire(Combat:FindFirstChild("CombatManager"), "CombatManager")
	HealingManager = safeRequire(Combat:FindFirstChild("HealingManager"), "HealingManager")
end

print("[Server] Module loading complete")

-- STEP 10: Initialize systems safely
print("[Server] Initializing systems...")

local function safeInit(manager, name)
	if manager and manager.Initialize then
		local success, err = pcall(function()
			manager.Initialize()
		end)
		if success then
			print(`[Server] Initialized: {name}`)
		else
			warn(`[Server] FAILED to initialize {name}: {err}`)
		end
	end
end

safeInit(GameManager, "GameManager")
-- Initialize MapManager to generate terrain with biomes (Jungle, Desert, Mountains)
-- This will replace the temporary spawn platform with proper biome-based spawning
safeInit(MapManager, "MapManager")
safeInit(WeaponManager, "WeaponManager")
safeInit(InventoryManager, "InventoryManager")
safeInit(EliminationManager, "EliminationManager")
safeInit(RevivalManager, "RevivalManager")
safeInit(RebootBeaconManager, "RebootBeaconManager")
safeInit(ProgressionManager, "ProgressionManager")
safeInit(PingManager, "PingManager")
safeInit(DinosaurManager, "DinosaurManager")
safeInit(BossEventManager, "BossEventManager")
safeInit(VehicleManager, "VehicleManager")
safeInit(EnvironmentalEventManager, "EnvironmentalEventManager")
safeInit(LootManager, "LootManager")
safeInit(CombatManager, "CombatManager")
safeInit(HealingManager, "HealingManager")
safeInit(BattlePassManager, "BattlePassManager")
safeInit(ShopManager, "ShopManager")
safeInit(TutorialManager, "TutorialManager")
safeInit(PartyManager, "PartyManager")
safeInit(RankedManager, "RankedManager")
safeInit(AccessibilityManager, "AccessibilityManager")

-- Set up manager references
if GameManager and StormManager then
	pcall(function() GameManager.SetStormManager(StormManager) end)
end
if GameManager and DeploymentManager then
	pcall(function() GameManager.SetDeploymentManager(DeploymentManager) end)
end
if GameManager and EliminationManager then
	pcall(function() GameManager.SetEliminationManager(EliminationManager) end)
end
if StormManager and CombatManager then
	pcall(function() StormManager.SetCombatManager(CombatManager) end)
end
if EliminationManager then
	if GameManager then pcall(function() EliminationManager.SetGameManager(GameManager) end) end
	if InventoryManager then pcall(function() EliminationManager.SetInventoryManager(InventoryManager) end) end
	if CombatManager then pcall(function() EliminationManager.SetCombatManager(CombatManager) end) end
end

-- Initialize StormManager with map parameters
if StormManager and StormManager.Initialize then
	pcall(function()
		StormManager.Initialize(Vector3.new(0, 0, 0), 2000)
	end)
end

-- Admin console
if AdminConsole then
	if GameManager then pcall(function() AdminConsole.SetGameManager(GameManager) end) end
	safeInit(AdminConsole, "AdminConsole")
end

print("[Server] System initialization complete")

-- STEP 11: Mark system as ready and spawn queued players
systemReady = true
print("[Server] System ready - spawning queued players...")

for _, player in ipairs(playersToSpawn) do
	if player and player.Parent then  -- Make sure player is still connected
		print(`[Server] Spawning queued player: {player.Name}`)
		task.spawn(function()
			-- Initialize player systems
			if InventoryManager and InventoryManager.InitializePlayer then
				pcall(function() InventoryManager.InitializePlayer(player) end)
			end
			if WeaponManager and WeaponManager.InitializePlayer then
				pcall(function() WeaponManager.InitializePlayer(player) end)
			end

			-- Small delay then spawn
			task.wait(0.5)
			player:LoadCharacter()
			print(`[Server] {player.Name} spawned!`)
		end)
	end
end

playersToSpawn = {}

-- STEP 12: Set initial game state
if GameManager and GameManager.SetState then
	pcall(function()
		GameManager.SetState("Lobby")
		print("[Server] Game state set to Lobby")
	end)
end

print("===========================================")
print("  DINO ROYALE SERVER - READY!")
print("  Terrain: Jungle, Desert, Mountains biomes")
print("  Spawn: Jungle biome area (200, Y, 200)")
print("===========================================")

-- STEP 13: Handle respawning on death
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Connect(function()
			print(`[Server] {player.Name} died, respawning in 3 seconds...`)
			task.wait(3)
			if player and player.Parent then
				player:LoadCharacter()
			end
		end)
	end)
end)
