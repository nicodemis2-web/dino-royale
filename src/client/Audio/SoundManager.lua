--!strict
--[[
	SoundManager.lua
	================
	Manages all game sound effects
	Handles 3D spatial audio, sound pooling, and effect variations
]]

local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")

local Events = require(game.ReplicatedStorage.Shared.Events)

local SoundManager = {}

-- Local player reference
local localPlayer = Players.LocalPlayer

-- Sound groups
local soundGroups = {
	Master = nil :: SoundGroup?,
	SFX = nil :: SoundGroup?,
	Weapons = nil :: SoundGroup?,
	Vehicles = nil :: SoundGroup?,
	Dinosaurs = nil :: SoundGroup?,
	UI = nil :: SoundGroup?,
	Ambient = nil :: SoundGroup?,
}

-- Sound pools for frequently used sounds
local soundPools = {} :: { [string]: { Sound } }
local POOL_SIZE = 5

-- Active sounds for management
local activeSounds = {} :: { [string]: Sound }

-- Volume settings
local volumes = {
	Master = 1.0,
	SFX = 0.8,
	Weapons = 0.9,
	Vehicles = 0.7,
	Dinosaurs = 0.8,
	UI = 1.0,
	Ambient = 0.5,
}

-- Sound definitions
local SoundDefinitions = {
	-- Weapon sounds
	Weapons = {
		AssaultRifleFire = { id = "rbxassetid://0", volume = 1.0, pitch = { 0.95, 1.05 } },
		ShotgunFire = { id = "rbxassetid://0", volume = 1.0, pitch = { 0.9, 1.0 } },
		SMGFire = { id = "rbxassetid://0", volume = 0.9, pitch = { 1.0, 1.1 } },
		SniperFire = { id = "rbxassetid://0", volume = 1.0, pitch = { 0.95, 1.0 } },
		PistolFire = { id = "rbxassetid://0", volume = 0.8, pitch = { 1.0, 1.05 } },
		Reload = { id = "rbxassetid://0", volume = 0.7, pitch = { 0.95, 1.05 } },
		ReloadMag = { id = "rbxassetid://0", volume = 0.6, pitch = { 0.98, 1.02 } },
		DryFire = { id = "rbxassetid://0", volume = 0.5, pitch = { 1.0, 1.0 } },
		Equip = { id = "rbxassetid://0", volume = 0.5, pitch = { 0.95, 1.05 } },
		BulletImpact = { id = "rbxassetid://0", volume = 0.6, pitch = { 0.9, 1.1 } },
		BulletWhiz = { id = "rbxassetid://0", volume = 0.4, pitch = { 0.8, 1.2 } },
	},

	-- Player sounds
	Player = {
		Footstep_Grass = { id = "rbxassetid://0", volume = 0.3, pitch = { 0.9, 1.1 } },
		Footstep_Concrete = { id = "rbxassetid://0", volume = 0.4, pitch = { 0.9, 1.1 } },
		Footstep_Sand = { id = "rbxassetid://0", volume = 0.25, pitch = { 0.9, 1.1 } },
		Footstep_Water = { id = "rbxassetid://0", volume = 0.5, pitch = { 0.9, 1.1 } },
		Jump = { id = "rbxassetid://0", volume = 0.4, pitch = { 0.95, 1.05 } },
		Land = { id = "rbxassetid://0", volume = 0.5, pitch = { 0.9, 1.1 } },
		Hurt = { id = "rbxassetid://0", volume = 0.7, pitch = { 0.9, 1.1 } },
		Death = { id = "rbxassetid://0", volume = 0.8, pitch = { 1.0, 1.0 } },
		Heal = { id = "rbxassetid://0", volume = 0.6, pitch = { 1.0, 1.0 } },
		ShieldUp = { id = "rbxassetid://0", volume = 0.6, pitch = { 1.0, 1.05 } },
	},

	-- Vehicle sounds
	Vehicles = {
		EngineStart = { id = "rbxassetid://0", volume = 0.7, pitch = { 0.95, 1.05 } },
		EngineLoop = { id = "rbxassetid://0", volume = 0.6, pitch = { 0.8, 1.2 }, looped = true },
		EngineStop = { id = "rbxassetid://0", volume = 0.5, pitch = { 0.95, 1.05 } },
		Horn = { id = "rbxassetid://0", volume = 0.8, pitch = { 1.0, 1.0 } },
		Crash = { id = "rbxassetid://0", volume = 0.9, pitch = { 0.9, 1.1 } },
		TireSqueal = { id = "rbxassetid://0", volume = 0.6, pitch = { 0.9, 1.1 } },
		HelicopterRotor = { id = "rbxassetid://0", volume = 0.7, pitch = { 0.9, 1.1 }, looped = true },
		BoatEngine = { id = "rbxassetid://0", volume = 0.5, pitch = { 0.9, 1.1 }, looped = true },
		BoatSplash = { id = "rbxassetid://0", volume = 0.5, pitch = { 0.9, 1.1 } },
	},

	-- Dinosaur sounds
	Dinosaurs = {
		RaptorCall = { id = "rbxassetid://0", volume = 0.8, pitch = { 0.9, 1.1 } },
		RaptorAttack = { id = "rbxassetid://0", volume = 0.9, pitch = { 0.95, 1.05 } },
		TRexRoar = { id = "rbxassetid://0", volume = 1.0, pitch = { 0.95, 1.0 } },
		TRexStomp = { id = "rbxassetid://0", volume = 0.9, pitch = { 0.9, 1.0 } },
		DiloSpit = { id = "rbxassetid://0", volume = 0.7, pitch = { 0.95, 1.05 } },
		TrikeCharge = { id = "rbxassetid://0", volume = 0.8, pitch = { 0.9, 1.0 } },
		PteranodonScreech = { id = "rbxassetid://0", volume = 0.7, pitch = { 1.0, 1.2 } },
		DinoFootstep = { id = "rbxassetid://0", volume = 0.5, pitch = { 0.8, 1.2 } },
		DinoHurt = { id = "rbxassetid://0", volume = 0.7, pitch = { 0.9, 1.1 } },
		DinoDeath = { id = "rbxassetid://0", volume = 0.8, pitch = { 0.95, 1.05 } },
	},

	-- UI sounds
	UI = {
		ButtonClick = { id = "rbxassetid://0", volume = 0.5, pitch = { 1.0, 1.0 } },
		ButtonHover = { id = "rbxassetid://0", volume = 0.3, pitch = { 1.0, 1.0 } },
		MenuOpen = { id = "rbxassetid://0", volume = 0.4, pitch = { 1.0, 1.0 } },
		MenuClose = { id = "rbxassetid://0", volume = 0.4, pitch = { 0.95, 0.95 } },
		ItemPickup = { id = "rbxassetid://0", volume = 0.5, pitch = { 1.0, 1.1 } },
		ItemDrop = { id = "rbxassetid://0", volume = 0.4, pitch = { 0.9, 1.0 } },
		WeaponSwap = { id = "rbxassetid://0", volume = 0.4, pitch = { 1.0, 1.05 } },
		Notification = { id = "rbxassetid://0", volume = 0.5, pitch = { 1.0, 1.0 } },
		KillConfirm = { id = "rbxassetid://0", volume = 0.6, pitch = { 1.0, 1.0 } },
		Countdown = { id = "rbxassetid://0", volume = 0.6, pitch = { 1.0, 1.0 } },
		MatchStart = { id = "rbxassetid://0", volume = 0.7, pitch = { 1.0, 1.0 } },
		Victory = { id = "rbxassetid://0", volume = 0.8, pitch = { 1.0, 1.0 } },
		Defeat = { id = "rbxassetid://0", volume = 0.7, pitch = { 1.0, 1.0 } },
	},

	-- Environment sounds
	Environment = {
		Explosion = { id = "rbxassetid://0", volume = 1.0, pitch = { 0.9, 1.1 } },
		DoorOpen = { id = "rbxassetid://0", volume = 0.5, pitch = { 0.95, 1.05 } },
		DoorClose = { id = "rbxassetid://0", volume = 0.5, pitch = { 0.95, 1.05 } },
		ChestOpen = { id = "rbxassetid://0", volume = 0.6, pitch = { 1.0, 1.0 } },
		LootDrop = { id = "rbxassetid://0", volume = 0.5, pitch = { 0.95, 1.05 } },
		StormAmbient = { id = "rbxassetid://0", volume = 0.4, pitch = { 1.0, 1.0 }, looped = true },
		StormClose = { id = "rbxassetid://0", volume = 0.6, pitch = { 1.0, 1.0 } },
	},
}

-- State
local isInitialized = false
local connections = {} :: { RBXScriptConnection }

--[[
	Create sound groups
]]
local function createSoundGroups()
	-- Master group
	soundGroups.Master = Instance.new("SoundGroup")
	soundGroups.Master.Name = "Master"
	soundGroups.Master.Volume = volumes.Master
	soundGroups.Master.Parent = SoundService

	-- Sub-groups
	for name, _ in pairs(volumes) do
		if name ~= "Master" then
			local group = Instance.new("SoundGroup")
			group.Name = name
			group.Volume = volumes[name]
			group.Parent = soundGroups.Master
			soundGroups[name] = group
		end
	end
end

--[[
	Create sound from definition
]]
local function createSound(category: string, soundName: string): Sound?
	local categoryDef = SoundDefinitions[category]
	if not categoryDef then
		return nil
	end

	local def = categoryDef[soundName]
	if not def then
		return nil
	end

	local sound = Instance.new("Sound")
	sound.Name = soundName
	sound.SoundId = def.id
	sound.Volume = def.volume or 1.0

	-- Assign to sound group
	local groupName = category
	if category == "Player" or category == "Environment" then
		groupName = "SFX"
	end

	if soundGroups[groupName] then
		sound.SoundGroup = soundGroups[groupName]
	end

	-- Apply looped setting
	if def.looped then
		sound.Looped = true
	end

	return sound
end

--[[
	Get random pitch from range
]]
local function getRandomPitch(pitchRange: { number }?): number
	if not pitchRange then
		return 1.0
	end
	return pitchRange[1] + math.random() * (pitchRange[2] - pitchRange[1])
end

--[[
	Get sound from pool or create new
]]
local function getSoundFromPool(category: string, soundName: string): Sound?
	local poolKey = `{category}_{soundName}`

	-- Create pool if it doesn't exist
	if not soundPools[poolKey] then
		soundPools[poolKey] = {}
		for _ = 1, POOL_SIZE do
			local sound = createSound(category, soundName)
			if sound then
				table.insert(soundPools[poolKey], sound)
			end
		end
	end

	-- Find available sound in pool
	for _, sound in ipairs(soundPools[poolKey]) do
		if not sound.IsPlaying then
			return sound
		end
	end

	-- All sounds in use, create temporary one
	return createSound(category, soundName)
end

--[[
	Play a sound effect
	@param category Sound category
	@param soundName Sound name
	@param options Optional settings (position, parent, volume modifier)
	@return Sound instance
]]
function SoundManager.Play(category: string, soundName: string, options: { position: Vector3?, parent: Instance?, volumeMod: number?, pitchMod: number? }?): Sound?
	if not isInitialized then
		return nil
	end

	local sound = getSoundFromPool(category, soundName)
	if not sound then
		return nil
	end

	local opts = options or {}
	local def = SoundDefinitions[category] and SoundDefinitions[category][soundName]

	-- Apply pitch variation
	local pitch = getRandomPitch(def and def.pitch)
	if opts.pitchMod then
		pitch = pitch * opts.pitchMod
	end
	sound.PlaybackSpeed = pitch

	-- Apply volume modifier
	if opts.volumeMod then
		sound.Volume = (def and def.volume or 1.0) * opts.volumeMod
	end

	-- Parent for 3D sound
	if opts.position then
		-- Create temporary part for 3D positioning
		local part = Instance.new("Part")
		part.Name = "SoundEmitter"
		part.Anchored = true
		part.CanCollide = false
		part.Transparency = 1
		part.Size = Vector3.new(1, 1, 1)
		part.Position = opts.position
		part.Parent = workspace

		sound.Parent = part
		sound.RollOffMode = Enum.RollOffMode.Linear
		sound.RollOffMinDistance = 10
		sound.RollOffMaxDistance = 200

		-- Cleanup after sound ends
		sound.Ended:Once(function()
			task.delay(0.1, function()
				part:Destroy()
			end)
		end)
	elseif opts.parent then
		sound.Parent = opts.parent
	else
		sound.Parent = SoundService
	end

	sound:Play()

	return sound
end

--[[
	Play a 3D sound at a position
]]
function SoundManager.Play3D(category: string, soundName: string, position: Vector3, volumeMod: number?): Sound?
	return SoundManager.Play(category, soundName, {
		position = position,
		volumeMod = volumeMod,
	})
end

--[[
	Play a UI sound (no 3D positioning)
]]
function SoundManager.PlayUI(soundName: string): Sound?
	return SoundManager.Play("UI", soundName)
end

--[[
	Start a looped sound
]]
function SoundManager.StartLoop(category: string, soundName: string, parent: Instance?): Sound?
	local sound = createSound(category, soundName)
	if not sound then
		return nil
	end

	sound.Looped = true
	sound.Parent = parent or SoundService
	sound:Play()

	-- Track for cleanup
	local key = `{category}_{soundName}_{tick()}`
	activeSounds[key] = sound

	return sound
end

--[[
	Stop a looped sound
]]
function SoundManager.StopLoop(sound: Sound)
	if sound then
		sound:Stop()

		-- Remove from tracking
		for key, tracked in pairs(activeSounds) do
			if tracked == sound then
				activeSounds[key] = nil
				break
			end
		end
	end
end

--[[
	Set volume for a sound group
]]
function SoundManager.SetVolume(groupName: string, volume: number)
	volumes[groupName] = math.clamp(volume, 0, 1)

	if soundGroups[groupName] then
		soundGroups[groupName].Volume = volumes[groupName]
	end
end

--[[
	Get volume for a sound group
]]
function SoundManager.GetVolume(groupName: string): number
	return volumes[groupName] or 1.0
end

--[[
	Set master volume
]]
function SoundManager.SetMasterVolume(volume: number)
	SoundManager.SetVolume("Master", volume)
end

--[[
	Stop all sounds
]]
function SoundManager.StopAll()
	for _, sound in pairs(activeSounds) do
		if sound and sound.Parent then
			sound:Stop()
		end
	end
	activeSounds = {}
end

--[[
	Setup event listeners
]]
local function setupEvents()
	-- Weapon fire sounds
	local fireConn = Events.OnClientEvent("Weapon", "Fire", function(data)
		local weaponType = data.weaponType or "AssaultRifle"
		local soundName = weaponType .. "Fire"
		SoundManager.Play3D("Weapons", soundName, data.position)
	end)
	table.insert(connections, fireConn)

	-- Bullet impacts
	local impactConn = Events.OnClientEvent("Weapon", "Impact", function(data)
		SoundManager.Play3D("Weapons", "BulletImpact", data.position, 0.8)
	end)
	table.insert(connections, impactConn)

	-- Dinosaur sounds
	local dinoConn = Events.OnClientEvent("Dinosaur", "Sound", function(data)
		SoundManager.Play3D("Dinosaurs", data.soundName, data.position)
	end)
	table.insert(connections, dinoConn)

	-- Vehicle sounds
	local vehicleConn = Events.OnClientEvent("Vehicle", "Sound", function(data)
		SoundManager.Play3D("Vehicles", data.soundName, data.position)
	end)
	table.insert(connections, vehicleConn)
end

--[[
	Initialize the sound manager
]]
function SoundManager.Initialize()
	if isInitialized then
		return
	end

	createSoundGroups()
	setupEvents()

	isInitialized = true
	print("[SoundManager] Initialized")
end

--[[
	Cleanup
]]
function SoundManager.Cleanup()
	isInitialized = false

	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	connections = {}

	SoundManager.StopAll()

	-- Destroy sound pools
	for _, pool in pairs(soundPools) do
		for _, sound in ipairs(pool) do
			sound:Destroy()
		end
	end
	soundPools = {}

	-- Destroy sound groups
	if soundGroups.Master then
		soundGroups.Master:Destroy()
	end

	soundGroups = {}
end

return SoundManager
