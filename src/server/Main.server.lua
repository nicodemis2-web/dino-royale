--!strict
--[[
	Main.server.lua
	===============
	Server entry point for Dino Royale
	Proper initialization: Terrain -> Spawns -> Players -> Dinosaurs
]]

print("===========================================")
print("  DINO ROYALE SERVER - INITIALIZING")
print("===========================================")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

-- STEP 1: Disable auto-spawning - we control when players spawn
Players.CharacterAutoLoads = false
print("[Server] CharacterAutoLoads = false")

-- STEP 2: State tracking
local playersToSpawn: {Player} = {}
local worldReady = false
local spawnPosition: Vector3 = Vector3.new(400, 50, 400) -- Will be updated by MapManager
local COUNTDOWN_SECONDS = 10

-- STEP 3: Wait for shared modules
print("[Server] Waiting for shared modules...")
local Shared = ReplicatedStorage:WaitForChild("Shared", 10)
if not Shared then
	error("[Server] FATAL: Shared folder not found!")
end
print("[Server] Shared modules found")

-- STEP 4: Load Events module FIRST
print("[Server] Initializing Events...")
local Events = require(ReplicatedStorage.Shared.Events)
Events.Initialize()
print("[Server] Events initialized")

-- STEP 5: Load Constants
local Constants = require(ReplicatedStorage.Shared.Constants)

-- STEP 6: Declare all manager variables
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

-- STEP 7: Safe require helper
local function safeRequire(path: any, name: string): any
	if not path then
		warn(`[Server] Module path not found for: {name}`)
		return nil
	end
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

-- STEP 8: Safe init helper
local function safeInit(manager: any, name: string)
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

-- STEP 9: Load all modules
print("[Server] Loading modules...")
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

-- ============================================
-- STEP 10: INITIALIZE WORLD (TERRAIN FIRST!)
-- ============================================
print("[Server] GENERATING 4KM x 4KM WORLD...")

-- Initialize MapManager FIRST - this generates terrain
safeInit(MapManager, "MapManager")

-- Find the spawn location created by MapManager
local lobbySpawn = Workspace:FindFirstChild("LobbySpawn")
if lobbySpawn and lobbySpawn:IsA("SpawnLocation") then
	spawnPosition = lobbySpawn.Position
	print(`[Server] Found LobbySpawn at {spawnPosition}`)
else
	-- FALLBACK: Create a guaranteed spawn area if MapManager failed
	warn("[Server] LobbySpawn not found! Creating fallback spawn...")

	-- Create a large, visible spawn platform at jungle center (200, Y, 200)
	local fallbackPlatform = Instance.new("Part")
	fallbackPlatform.Name = "FallbackSpawnPlatform"
	fallbackPlatform.Size = Vector3.new(100, 10, 100)
	fallbackPlatform.Position = Vector3.new(200, 30, 200)
	fallbackPlatform.Anchored = true
	fallbackPlatform.CanCollide = true
	fallbackPlatform.BrickColor = BrickColor.new("Bright green")
	fallbackPlatform.Material = Enum.Material.Grass
	fallbackPlatform.Parent = Workspace
	print("[Server] Created fallback platform at (200, 30, 200)")

	-- Create spawn location on top
	local fallbackSpawn = Instance.new("SpawnLocation")
	fallbackSpawn.Name = "LobbySpawn"
	fallbackSpawn.Size = Vector3.new(50, 1, 50)
	fallbackSpawn.Position = Vector3.new(200, 37, 200)
	fallbackSpawn.Anchored = true
	fallbackSpawn.Transparency = 0.5
	fallbackSpawn.CanCollide = false
	fallbackSpawn.Neutral = true
	fallbackSpawn.Duration = 0
	fallbackSpawn.Parent = Workspace

	spawnPosition = fallbackSpawn.Position
	print(`[Server] Created fallback spawn at {spawnPosition}`)
end

print("[Server] World generation complete!")

-- ============================================
-- STEP 11: INITIALIZE OTHER SYSTEMS
-- ============================================
print("[Server] Initializing game systems...")

safeInit(GameManager, "GameManager")
safeInit(WeaponManager, "WeaponManager")
safeInit(InventoryManager, "InventoryManager")
safeInit(EliminationManager, "EliminationManager")
safeInit(RevivalManager, "RevivalManager")
safeInit(RebootBeaconManager, "RebootBeaconManager")
safeInit(ProgressionManager, "ProgressionManager")
safeInit(PingManager, "PingManager")
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
		StormManager.Initialize(Vector3.new(0, 0, 0), 2000) -- 4km map = 2000 stud radius
	end)
end

-- Admin console
if AdminConsole then
	if GameManager then pcall(function() AdminConsole.SetGameManager(GameManager) end) end
	safeInit(AdminConsole, "AdminConsole")
end

print("[Server] Game systems initialized")

-- ============================================
-- STEP 12: INITIALIZE DINOSAURS (AFTER TERRAIN!)
-- ============================================
print("[Server] Initializing dinosaur system...")
safeInit(DinosaurManager, "DinosaurManager")
print("[Server] Dinosaur system ready")

-- ============================================
-- STEP 13: MARK WORLD READY
-- ============================================
worldReady = true
print("[Server] WORLD IS READY!")

-- ============================================
-- STEP 14: PLAYER SPAWNING WITH COUNTDOWN
-- ============================================

-- Configure character when spawned
local function configureCharacter(player: Player, character: Model, freezeMovement: boolean)
	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if not humanoid then
		warn(`[Server] Could not find Humanoid for {player.Name}`)
		return
	end

	-- Configure per GDD Appendix A
	humanoid.MaxHealth = Constants.PLAYER.MAX_HEALTH
	humanoid.Health = humanoid.MaxHealth
	humanoid.JumpPower = Constants.PLAYER.JUMP_POWER

	if freezeMovement then
		humanoid.WalkSpeed = 0 -- Frozen during countdown
		humanoid.JumpPower = 0
	else
		humanoid.WalkSpeed = Constants.PLAYER.WALK_SPEED
		humanoid.JumpPower = Constants.PLAYER.JUMP_POWER
	end

	print(`[Server] Configured {player.Name}: WalkSpeed={humanoid.WalkSpeed}`)
end

-- Unfreeze player after countdown
local function unfreezePlayer(player: Player)
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = Constants.PLAYER.WALK_SPEED
		humanoid.JumpPower = Constants.PLAYER.JUMP_POWER
		print(`[Server] {player.Name} can now move!`)
	end
end

-- Spawn a player with countdown
local function spawnPlayerWithCountdown(player: Player)
	print(`[Server] Spawning {player.Name} with {COUNTDOWN_SECONDS}s countdown...`)

	-- Initialize player systems
	if InventoryManager and InventoryManager.InitializePlayer then
		pcall(function() InventoryManager.InitializePlayer(player) end)
	end
	if WeaponManager and WeaponManager.InitializePlayer then
		pcall(function() WeaponManager.InitializePlayer(player) end)
	end

	-- Load character
	player:LoadCharacter()

	-- Wait for character to load
	local character = player.Character or player.CharacterAdded:Wait()

	-- Configure with frozen movement
	configureCharacter(player, character, true)

	-- Send countdown to client (they can show UI)
	for i = COUNTDOWN_SECONDS, 1, -1 do
		print(`[Server] {player.Name} countdown: {i}`)
		-- Could fire event to client here for UI
		task.wait(1)
	end

	-- Unfreeze after countdown
	unfreezePlayer(player)
	print(`[Server] {player.Name} GO!`)
end

-- Handle death/respawn
local function setupRespawnHandler(player: Player)
	player.CharacterAdded:Connect(function(character)
		-- Only freeze on initial spawn, not respawns
		local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
		if humanoid then
			humanoid.WalkSpeed = Constants.PLAYER.WALK_SPEED
			humanoid.JumpPower = Constants.PLAYER.JUMP_POWER
			humanoid.MaxHealth = Constants.PLAYER.MAX_HEALTH
			humanoid.Health = humanoid.MaxHealth

			-- Handle death
			humanoid.Died:Connect(function()
				print(`[Server] {player.Name} died, respawning in 3 seconds...`)
				task.wait(3)
				if player and player.Parent then
					player:LoadCharacter()
				end
			end)
		end
	end)
end

-- ============================================
-- STEP 15: HANDLE PLAYER CONNECTIONS
-- ============================================

-- Queue existing players
for _, player in ipairs(Players:GetPlayers()) do
	table.insert(playersToSpawn, player)
	setupRespawnHandler(player)
end

-- Handle new players
Players.PlayerAdded:Connect(function(player)
	print(`[Server] Player joined: {player.Name}`)
	setupRespawnHandler(player)

	if worldReady then
		-- World ready, spawn immediately with countdown
		task.spawn(function()
			spawnPlayerWithCountdown(player)
		end)
	else
		-- Queue for later
		table.insert(playersToSpawn, player)
	end
end)

-- Handle player leaving
Players.PlayerRemoving:Connect(function(player)
	print(`[Server] Player leaving: {player.Name}`)
	for i, p in ipairs(playersToSpawn) do
		if p == player then
			table.remove(playersToSpawn, i)
			break
		end
	end
end)

-- ============================================
-- STEP 16: SPAWN QUEUED PLAYERS
-- ============================================
print(`[Server] Spawning {#playersToSpawn} queued players...`)

for _, player in ipairs(playersToSpawn) do
	if player and player.Parent then
		task.spawn(function()
			spawnPlayerWithCountdown(player)
		end)
	end
end

playersToSpawn = {}

-- ============================================
-- STEP 17: SET GAME STATE
-- ============================================
if GameManager and GameManager.SetState then
	pcall(function()
		GameManager.SetState("Lobby")
		print("[Server] Game state set to Lobby")
	end)
end

print("===========================================")
print("  DINO ROYALE SERVER - READY!")
print("  Map: Isla Primordial (4km x 4km)")
print("  Terrain: Jungle, Desert, Mountains")
print(`  Spawn: Jungle biome at {spawnPosition}`)
print("===========================================")
