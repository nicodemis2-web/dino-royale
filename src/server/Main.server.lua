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

-- STEP 1.5: FORCE CLEANUP of any old spawn platforms from .rbxlx file
-- This removes legacy spawn locations that may have been saved in the place file
local cleanupList = {
	"LobbySpawn", "LobbyPlatform", "SpawnPlatform", "TempSpawnPlatform",
	"TempLobbyPlatform", "FallbackSpawnPlatform", "TempSpawn", "OldMainSpawn"
}
for _, name in ipairs(cleanupList) do
	local obj = Workspace:FindFirstChild(name)
	if obj then
		obj:Destroy()
		print(`[Server] Removed legacy spawn object: {name}`)
	end
end
-- Remove only OLD SpawnLocation objects (not ones we create)
-- We'll create our own MainSpawn after terrain generation
for _, child in ipairs(Workspace:GetChildren()) do
	if child:IsA("SpawnLocation") then
		child:Destroy()
		print(`[Server] Removed old SpawnLocation: {child.Name}`)
	end
end
print("[Server] Legacy spawn cleanup complete")

-- STEP 2: State tracking
local playersToSpawn: {Player} = {}
local worldReady = false
local spawnPosition: Vector3 = Vector3.new(200, 50, 200) -- Jungle center on terrain

-- Connection tracking for cleanup
local playerConnections: { [Player]: { RBXScriptConnection } } = {}

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
local Inventory = script.Parent:FindFirstChild("Inventory")

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

if Inventory then
	InventoryManager = safeRequire(Inventory:FindFirstChild("InventoryManager"), "InventoryManager")
end

if Player then
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

-- Wait briefly for terrain to fully register
task.wait(0.1)

-- Find terrain height at spawn location using raycast
local function getTerrainSpawnHeight(x: number, z: number): number
	local rayOrigin = Vector3.new(x, 500, z)
	local rayResult = Workspace:Raycast(rayOrigin, Vector3.new(0, -1000, 0))
	if rayResult then
		print(`[Server] Raycast hit at Y={rayResult.Position.Y}, material={rayResult.Material}`)
		return rayResult.Position.Y + 5 -- 5 studs above terrain
	end
	print("[Server] WARNING: Raycast missed terrain! Using fallback height.")
	return 30 -- Fallback height (terrain is at ~25)
end

-- Set spawn position on terrain
local spawnY = getTerrainSpawnHeight(200, 200)
spawnPosition = Vector3.new(200, spawnY, 200)
print(`[Server] Spawn position set to terrain at {spawnPosition}`)

-- CRITICAL: Create a SpawnLocation so LoadCharacter() doesn't spawn players at void
-- This ensures players spawn at the correct position from the start
local mainSpawnLocation = Instance.new("SpawnLocation")
mainSpawnLocation.Name = "MainSpawn"
mainSpawnLocation.Size = Vector3.new(20, 1, 20)
mainSpawnLocation.Position = spawnPosition
mainSpawnLocation.Anchored = true
mainSpawnLocation.CanCollide = true -- Players can stand on it
mainSpawnLocation.Transparency = 0.8 -- Slightly visible for debugging
mainSpawnLocation.BrickColor = BrickColor.new("Bright green")
mainSpawnLocation.Material = Enum.Material.Neon
mainSpawnLocation.Neutral = true -- All teams can spawn here
mainSpawnLocation.Duration = 0 -- No spawn protection delay
mainSpawnLocation.Parent = Workspace
print(`[Server] Created SpawnLocation at {spawnPosition}`)

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
if GameManager and MapManager then
	pcall(function() GameManager.SetMapManager(MapManager) end)
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
-- STEP 14: PLAYER SPAWNING (DIRECT TO TERRAIN)
-- ============================================

-- Configure character when spawned (immediately ready to move)
local function configureCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if not humanoid then
		warn(`[Server] Could not find Humanoid for {player.Name}`)
		return
	end

	-- Configure per GDD Appendix A
	humanoid.MaxHealth = Constants.PLAYER.MAX_HEALTH
	humanoid.Health = humanoid.MaxHealth
	humanoid.WalkSpeed = Constants.PLAYER.WALK_SPEED
	humanoid.JumpPower = Constants.PLAYER.JUMP_POWER

	print(`[Server] Configured {player.Name}: Ready to play!`)
end

-- Load GameConfig for debug settings
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

-- Spawn a player directly on terrain (no countdown)
local function spawnPlayer(player: Player)
	print(`[Server] Spawning {player.Name} on terrain...`)

	-- Initialize player systems
	if InventoryManager and InventoryManager.InitializePlayer then
		pcall(function() InventoryManager.InitializePlayer(player) end)
	end
	if WeaponManager and WeaponManager.InitializePlayer then
		pcall(function() WeaponManager.InitializePlayer(player) end)
	end

	-- Load character - SpawnLocation "MainSpawn" should position them correctly
	player:LoadCharacter()

	-- Wait for character to load
	local character = player.Character or player.CharacterAdded:Wait()

	-- Wait for HumanoidRootPart
	local rootPart = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not rootPart then
		warn(`[Server] Could not find HumanoidRootPart for {player.Name}`)
		return
	end

	-- Small delay to let physics settle
	task.wait(0.2)

	-- Safety check: Ensure player is at valid position
	-- If they somehow spawned in void or wrong location, teleport them
	local currentPos = rootPart.Position
	print(`[Server] {player.Name} spawned at position: {currentPos}`)

	-- Check if position is invalid (falling in void or too high)
	local needsTeleport = currentPos.Y < 0 or currentPos.Y > 500 or
		(math.abs(currentPos.X - 200) > 100 and math.abs(currentPos.Z - 200) > 100)

	if needsTeleport then
		print(`[Server] {player.Name} at invalid position, teleporting to spawn...`)
		-- Raycast to find terrain
		local rayOrigin = Vector3.new(200, 500, 200)
		local rayResult = Workspace:Raycast(rayOrigin, Vector3.new(0, -1000, 0))
		local safeY = rayResult and (rayResult.Position.Y + 5) or 30
		local safePos = Vector3.new(200, safeY, 200)
		rootPart.CFrame = CFrame.new(safePos)
		rootPart.AssemblyLinearVelocity = Vector3.zero -- Stop any falling
		print(`[Server] Teleported {player.Name} to {safePos}`)
	else
		-- Just make sure they're not falling
		rootPart.AssemblyLinearVelocity = Vector3.zero
	end

	-- Configure character (ready to move immediately)
	configureCharacter(player, character)

	-- Give starting weapons and ammo (always give loadout on spawn)
	task.defer(function()
		task.wait(0.5) -- Wait for inventory to be fully initialized

		if InventoryManager then
			-- Give starter pistol (RangerSidearm is the pistol weapon ID)
			pcall(function()
				local result = InventoryManager.AddWeapon(player, "RangerSidearm", "Common")
				if result.success then
					print(`[Server] Gave {player.Name} starting RangerSidearm (slot {result.slot})`)
				else
					warn(`[Server] Failed to give RangerSidearm to {player.Name}`)
				end
			end)

			-- Give starter assault rifle (RangerAR is the AR weapon ID)
			pcall(function()
				local result = InventoryManager.AddWeapon(player, "RangerAR", "Common")
				if result.success then
					print(`[Server] Gave {player.Name} starting RangerAR (slot {result.slot})`)
				else
					warn(`[Server] Failed to give RangerAR to {player.Name}`)
				end
			end)

			-- Give starter SMG for variety
			pcall(function()
				local result = InventoryManager.AddWeapon(player, "RaptorSMG", "Common")
				if result.success then
					print(`[Server] Gave {player.Name} starting RaptorSMG (slot {result.slot})`)
				end
			end)

			-- Give starting ammo
			pcall(function()
				InventoryManager.AddAmmo(player, "LightAmmo", 150)
				InventoryManager.AddAmmo(player, "MediumAmmo", 120)
				print(`[Server] Gave {player.Name} starting ammo`)
			end)

			-- Give some healing items
			pcall(function()
				InventoryManager.AddConsumable(player, "Bandage", 5)
				InventoryManager.AddConsumable(player, "MiniShield", 3)
				print(`[Server] Gave {player.Name} starting consumables`)
			end)

			-- Force send inventory update to client
			pcall(function()
				InventoryManager.SendInventoryUpdate(player)
				print(`[Server] Sent inventory update to {player.Name}`)
			end)
		end
	end)

	print(`[Server] {player.Name} spawned and ready!`)

	-- Send welcome notification to client
	task.defer(function()
		task.wait(1) -- Wait for client to be ready
		Events.FireClient("GameState", "WelcomeMessage", player, {
			title = "WELCOME TO DINO ROYALE",
			message = "Explore the island, find weapons, and watch out for dinosaurs!",
			controls = {
				{ key = "WASD", action = "Move" },
				{ key = "Shift", action = "Sprint" },
				{ key = "C", action = "Crouch" },
				{ key = "1-5", action = "Switch Weapons" },
				{ key = "R", action = "Reload" },
				{ key = "E", action = "Interact" },
			},
		})
	end)
end

-- Handle death/respawn
local function setupRespawnHandler(player: Player)
	-- Initialize connection tracking for this player
	playerConnections[player] = playerConnections[player] or {}

	local characterAddedConn = player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
		if humanoid then
			humanoid.WalkSpeed = Constants.PLAYER.WALK_SPEED
			humanoid.JumpPower = Constants.PLAYER.JUMP_POWER
			humanoid.MaxHealth = Constants.PLAYER.MAX_HEALTH
			humanoid.Health = humanoid.MaxHealth

			-- Teleport to terrain on respawn (in case default spawn is wrong)
			task.spawn(function()
				task.wait(0.2) -- Wait for character to fully load
				local rootPart = character:FindFirstChild("HumanoidRootPart")
				if rootPart then
					-- Check if player is at wrong position (like at 0,0,0 or falling)
					if rootPart.Position.Y < 0 or rootPart.Position.Y > 200 then
						local spawnX, spawnZ = 200, 200
						local rayResult = Workspace:Raycast(Vector3.new(spawnX, 500, spawnZ), Vector3.new(0, -1000, 0))
						local spawnY = rayResult and (rayResult.Position.Y + 5) or 30
						rootPart.CFrame = CFrame.new(spawnX, spawnY, spawnZ)
						print(`[Server] Corrected {player.Name} position to terrain`)
					end
				end
			end)

			-- Handle death (no need to track - humanoid is destroyed with character)
			humanoid.Died:Connect(function()
				print(`[Server] {player.Name} died, respawning in 3 seconds...`)
				task.wait(3)
				if player and player.Parent then
					player:LoadCharacter()
				end
			end)
		end
	end)

	table.insert(playerConnections[player], characterAddedConn)
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
			spawnPlayer(player)
		end)
	else
		-- Queue for later
		table.insert(playersToSpawn, player)
	end
end)

-- Handle player leaving
Players.PlayerRemoving:Connect(function(player)
	print(`[Server] Player leaving: {player.Name}`)

	-- Clean up player connections
	local connections = playerConnections[player]
	if connections then
		for _, conn in ipairs(connections) do
			conn:Disconnect()
		end
		playerConnections[player] = nil
	end

	-- Remove from spawn queue
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
			spawnPlayer(player)
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
