--!strict
--[[
	Events/init.lua
	===============
	Defines and creates all RemoteEvents for Dino Royale
	Central event management for client-server communication
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Events = {}

--[[
	COMBAT EVENTS
	Weapon firing, damage, and eliminations
]]
Events.Combat = {
	"WeaponFire", -- Client -> Server: {weaponId, origin, direction}
	"WeaponReload", -- Client -> Server: {weaponId}
	"RequestHit", -- Client -> Server: {targetId, weaponId, hitPosition, hitPart}
	"RequestMelee", -- Client -> Server: {targetId}
	"DamageDealt", -- Server -> Client: {targetId, damage, hitPart, isCritical}
	"DamageTaken", -- Server -> Client: {amount, armorDamage, health, armor, sourceId, sourceType, isHeadshot, isCritical}
	"PlayerEliminated", -- Server -> All: {victimId, killerId, weapon, placement}
	"YouWereEliminated", -- Server -> Client: {placement, eliminator, weapon}
	"HitConfirm", -- Server -> Client: {isHeadshot}
	"ArmorBroken", -- Server -> Client: {}
	"Healed", -- Server -> Client: {amount, health, source}
	"ArmorAdded", -- Server -> Client: {amount, armor, armorType}
	"ArmorUpdated", -- Server -> Client: {armor}
	"HealthUpdate", -- Server -> Client: {health, maxHealth, armor, maxArmor}
	"Kill", -- Server -> Client: {victimId, victimName, killStreak, weaponId}
	"Assist", -- Server -> Client: {victimId, victimName}
	"StatusEffect", -- Server -> Client: {effect, duration}
	"EcholocationDetected", -- Server -> Client: {}
	"RevealPosition", -- Server -> Client: {position}
}

--[[
	INVENTORY EVENTS
	Item pickup, drop, use, and management
]]
Events.Inventory = {
	"PickupItem", -- Client -> Server: {itemInstanceId}
	"DropItem", -- Client -> Server: {slotIndex}
	"UseItem", -- Client -> Server: {slotIndex}
	"SwapSlots", -- Client -> Server: {slot1, slot2}
	"InventoryUpdate", -- Server -> Client: {fullInventory}
}

--[[
	GAME STATE EVENTS
	Match flow, storm, and player status
]]
Events.GameState = {
	"MatchStateChanged", -- Server -> All: {newState, data}
	"StateChanged", -- Server -> All: {newState, oldState} (alias for UI)
	"StormUpdate", -- Server -> All: {phase, center, radius, nextRadius, timeRemaining}
	"PlayerCountUpdate", -- Server -> All: {alivePlayers, totalPlayers}
	"CountdownStarted", -- Server -> All: {duration}
	"CountdownUpdate", -- Server -> All: {remaining}
	"CountdownCancelled", -- Server -> All: {}
	"DeployReady", -- Server -> All: {flightPath}
	"PlayerJumped", -- Client -> Server: {}
	"GliderInput", -- Client -> Server: {pitch, yaw}
	"GliderEnabled", -- Server -> Client: {position, forced?}
	"GliderDisabled", -- Server -> Client: {}
	"GliderLanded", -- Server -> Client: {position}
	"JumpDenied", -- Server -> Client: {reason}
	"PlayerJumpedFromHelicopter", -- Server -> All: {playerId, position}
	"SupplyDropIncoming", -- Server -> All: {position}
	"WelcomeMessage", -- Server -> Client: {title, message, controls}
	"LobbyUpdate", -- Server -> All: {players}
	"ToggleReady", -- Client -> Server: {ready}
	"ReturnToLobby", -- Client -> Server: {}
	-- Boss events
	"BossEvent", -- Server -> All: {eventType, bossId, data}
	"BossLootDropped", -- Server -> All: {bossId, position, loot}
	"BossEventEnded", -- Server -> All: {bossId, reason}
}

--[[
	DINOSAUR EVENTS
	Dinosaur spawns, AI states, and interactions
]]
Events.Dinosaur = {
	"DinosaurSpawned", -- Server -> Nearby: {dinoId, species, position}
	"DinosaurAlert", -- Server -> Nearby: {dinoId, alertLevel, targetId}
	"DinosaurAttacked", -- Server -> Nearby: {dinoId, targetId, damage}
	"DinosaurDamaged", -- Server -> Client: {dinoId, damage, newHealth}
	"DinosaurKilled", -- Server -> All: {dinoId, killerId, species}
	"DinosaurWarning", -- Server -> Nearby: {dinoId, species, position}
	"DinosaurCharge", -- Server -> Nearby: {dinoId, targetPosition}
	"BossSpawned", -- Server -> All: {bossId, species, position}
	"BossKilled", -- Server -> All: {bossId, killerId, rewards}
	"BossPhaseChange", -- Server -> All: {bossId, phase, health}
	-- Species-specific events
	"PteranodonDive", -- Server -> Nearby: {dinoId, targetPosition}
	"IndoraptorEcho", -- Server -> Nearby: {dinoId, position}
	"IndoraptorAmbush", -- Server -> Nearby: {dinoId, targetId}
	"IndoraptorOpenDoor", -- Server -> Nearby: {dinoId, doorId}
	"RaptorLeap", -- Server -> Nearby: {dinoId, targetId}
	"DilosaurSpit", -- Server -> Nearby: {dinoId, targetPosition}
	"TRexStomp", -- Server -> All: {dinoId, position, radius}
	"TRexTailSwipe", -- Server -> Nearby: {dinoId, targetIds}
	"TRexRoar", -- Server -> All: {dinoId, position}
	"PackAttacking", -- Server -> Nearby: {packId, targetId}
	"PackCall", -- Server -> Nearby: {packId, position}
}

--[[
	BOSS EVENTS
	Boss encounters and special events
]]
Events.Boss = {
	"Spawned", -- Server -> All: {bossId, bossType, position}
	"Damaged", -- Server -> All: {bossId, damage, health}
	"Defeated", -- Server -> All: {bossId, killerId, rewards}
}

--[[
	VEHICLE EVENTS
	Vehicle entry, exit, and control
]]
Events.Vehicle = {
	"EnterVehicle", -- Client -> Server: {vehicleId, seat}
	"ExitVehicle", -- Client -> Server: {}
	"VehicleInput", -- Client -> Server: {throttle, steer, brake}
	"VehicleDamaged", -- Server -> Nearby: {vehicleId, newHealth}
	"VehicleDestroyed", -- Server -> All: {vehicleId, position}
	"VehicleSpawned", -- Server -> Nearby: {vehicleId, vehicleType, position}
	"PlayerEntered", -- Server -> All: {vehicleId, playerId, seat}
	"PlayerExited", -- Server -> All: {vehicleId, playerId}
	"Horn", -- Server -> Nearby: {vehicleId}
	-- Boat events
	"BoatEnterWater", -- Server -> All: {vehicleId}
	"BoatExitWater", -- Server -> All: {vehicleId}
	"BoatBoost", -- Server -> Nearby: {vehicleId, active}
	"BoatWake", -- Server -> Nearby: {vehicleId, intensity}
	-- Motorcycle events
	"MotorcycleNitro", -- Server -> All: {vehicleId, active}
	"MotorcycleLean", -- Server -> Nearby: {vehicleId, angle}
	"MotorcycleWheelie", -- Server -> Nearby: {vehicleId, active}
	"MotorcycleStunt", -- Server -> Nearby: {vehicleId, stuntType}
	-- ATV events
	"ATVWheelie", -- Server -> Nearby: {vehicleId, active}
	"ATVDrift", -- Server -> Nearby: {vehicleId, angle}
	"ATVLanded", -- Server -> Nearby: {vehicleId, force}
	"ATVJump", -- Server -> Nearby: {vehicleId, height}
	-- Helicopter events
	"HelicopterStartup", -- Server -> All: {vehicleId}
	"HelicopterShutdown", -- Server -> All: {vehicleId}
	"HelicopterCrash", -- Server -> All: {vehicleId, position}
	"HelicopterRotor", -- Server -> Nearby: {vehicleId, speed}
	-- Jeep events
	"TurretFire", -- Server -> Nearby: {vehicleId, targetPosition}
}

--[[
	TEAM EVENTS
	Squad/duo specific events
]]
Events.Team = {
	"PlayerDowned", -- Server -> Team: {playerId, position}
	"ReviveStart", -- Client -> Server: {targetId}
	"ReviveComplete", -- Server -> Team: {reviverId, revivedId}
	"RebootCardDropped", -- Server -> Team: {playerId, position}
	"RebootInitiated", -- Server -> Team: {beaconId}
}

--[[
	MAP EVENTS
	Map data and POI information
]]
Events.Map = {
	"RequestMapData", -- Client -> Server: {}
	"MapData", -- Server -> Client: {mapData}
	"RequestPOIInfo", -- Client -> Server: {poiName}
	"POIInfo", -- Server -> Client: {name, config, state}
	"BiomeChanged", -- Server -> Client: {biome, config}
	"POILooted", -- Server -> All: {poiName, looterId}
	"POIEvent", -- Server -> All: {poiName, eventType, data}
}

--[[
	PROGRESSION EVENTS
	XP, levels, challenges, and rewards
]]
Events.Progression = {
	"ClaimReward", -- Client -> Server: {level}
	"GetProgress", -- Client -> Server: {}
	"ProgressUpdate", -- Server -> Client: {totalXP, level, stats, challenges, etc.}
	"XPGained", -- Server -> Client: {amount, source, totalXP, level, levelProgress}
	"LevelUp", -- Server -> Client: {level, rewards}
	"RewardClaimed", -- Server -> Client: {level, rewards}
	"ChallengeCompleted", -- Server -> Client: {challenge}
	"MatchSummary", -- Server -> Client: {placement, stats, xpEarned}
}

--[[
	REVIVAL EVENTS
	Downed state and teammate revival
]]
Events.Revival = {
	"StartRevive", -- Client -> Server: {targetId}
	"CancelRevive", -- Client -> Server: {}
	"CrawlMove", -- Client -> Server: {position}
	"PlayerDowned", -- Server -> All: {playerId, playerName, teamId, bleedOutTime, position}
	"ReviveStarted", -- Server -> All: {reviverId, targetId, reviveTime}
	"ReviveCancelled", -- Server -> All: {reviverId, targetId}
	"PlayerRevived", -- Server -> All: {reviverId, targetId, reviverName, targetName}
	"PlayerBledOut", -- Server -> All: {playerId, playerName}
	"ReviveProgress", -- Server -> Client: {progress, targetId}
	"BeingRevived", -- Server -> Client: {progress, reviverId}
}

--[[
	HEALING EVENTS
	Health items and buff management
]]
Events.Healing = {
	"StartUse", -- Client -> Server: {itemId}
	"CancelUse", -- Client -> Server: {}
	"UseStarted", -- Server -> Client: {itemId, useTime, canMove}
	"UseCancelled", -- Server -> Client: {}
	"UseCompleted", -- Server -> Client: {itemId, healAmount, armorAmount}
	"BuffApplied", -- Server -> Client: {buffType, value, duration}
	"BuffExpired", -- Server -> Client: {buffType}
}

--[[
	BATTLE PASS EVENTS
	Season pass progression
]]
Events.BattlePass = {
	"GetProgress", -- Client -> Server: {}
	"RequestData", -- Client -> Server: {} (alias)
	"ClaimReward", -- Client -> Server: {tier, isPremium?}
	"PurchasePremium", -- Client -> Server: {}
	"ProgressUpdate", -- Server -> Client: {tier, xp, rewards}
	"DataUpdate", -- Server -> Client: {tier, xp, isPremium, rewards} (alias)
	"RewardClaimed", -- Server -> Client: {tier, reward}
	"TierUp", -- Server -> Client: {tier, rewards}
	"XPGained", -- Server -> Client: {amount, newTotal}
	"PremiumPurchased", -- Server -> Client: {rewards}
}

--[[
	TUTORIAL EVENTS
	Player tutorials and onboarding
]]
Events.Tutorial = {
	"GetStatus", -- Client -> Server: {}
	"RequestProgress", -- Client -> Server: {} (alias)
	"Complete", -- Client -> Server: {tutorialId}
	"Skip", -- Client -> Server: {}
	"SkipTutorial", -- Client -> Server: {} (alias)
	"StartTutorial", -- Client -> Server: {}
	"AcknowledgeTip", -- Client -> Server: {tipId}
	"StatusUpdate", -- Server -> Client: {completedTutorials}
	"PromptStart", -- Server -> Client: {tutorialId}
	"StartStage", -- Server -> Client: {stageId, instructions}
	"StageCompleted", -- Server -> Client: {stageId}
	"TutorialCompleted", -- Server -> Client: {tutorialId}
	"TutorialSkipped", -- Server -> Client: {}
	"ShowTip", -- Server -> Client: {tipId, content}
	"EnterTraining", -- Server -> Client: {areaId}
	"ProgressUpdate", -- Server -> Client: {progress}
}

--[[
	ACCESSIBILITY EVENTS
	Accessibility settings
]]
Events.Accessibility = {
	"GetSettings", -- Client -> Server: {}
	"RequestSettings", -- Client -> Server: {} (alias)
	"UpdateSettings", -- Client -> Server: {settings}
	"SaveSettings", -- Client -> Server: {settings} (alias)
	"SettingsUpdate", -- Server -> Client: {settings}
	"SettingsLoaded", -- Server -> Client: {settings} (alias)
}

--[[
	PING EVENTS
	Player ping/marker system
]]
Events.Ping = {
	"CreatePing", -- Client -> Server: {position, pingType}
	"RemovePing", -- Client -> Server: {pingId}
	"PingCreated", -- Server -> All: {pingId, position, pingType, playerId}
	"PingRemoved", -- Server -> All: {pingId}
}

--[[
	RANKED EVENTS
	Competitive mode
]]
Events.Ranked = {
	"GetStats", -- Client -> Server: {}
	"RequestData", -- Client -> Server: {} (alias)
	"RequestLeaderboard", -- Client -> Server: {}
	"QueueMatch", -- Client -> Server: {}
	"LeaveQueue", -- Client -> Server: {}
	"StatsUpdate", -- Server -> Client: {rank, points, wins}
	"DataUpdate", -- Server -> Client: {rank, points, stats} (alias)
	"MatchResult", -- Server -> Client: {result, pointsChange}
	"LeaderboardUpdate", -- Server -> Client: {leaderboard}
	"SeasonRewards", -- Server -> Client: {rewards}
}

--[[
	PARTY EVENTS
	Party/squad system
]]
Events.Party = {
	"Create", -- Client -> Server: {gameMode?}
	"Invite", -- Client -> Server: {playerId}
	"Join", -- Client -> Server: {partyId}
	"AcceptInvite", -- Client -> Server: {inviteId} (alias)
	"DeclineInvite", -- Client -> Server: {inviteId}
	"Leave", -- Client -> Server: {}
	"Kick", -- Client -> Server: {playerId}
	"SetReady", -- Client -> Server: {ready}
	"RequestData", -- Client -> Server: {}
	"PartyUpdate", -- Server -> Client: {members, leader}
	"DataUpdate", -- Server -> Client: {party} (alias)
	"InviteReceived", -- Server -> Client: {invite, gameMode, memberCount}
	"InviteSent", -- Server -> Client: {targetName}
	"InviteDeclined", -- Server -> Client: {targetName}
	"InvitesUpdate", -- Server -> Client: {invites}
	"Created", -- Server -> Client: {party}
	"Joined", -- Server -> Client: {party}
	"Left", -- Server -> Client: {}
	"Disbanded", -- Server -> Client: {}
	"Kicked", -- Server -> Client: {}
	"MemberJoined", -- Server -> Client: {member}
	"MemberLeft", -- Server -> Client: {userId, name, newLeader}
	"MemberKicked", -- Server -> Client: {userId}
	"MemberReady", -- Server -> Client: {userId, isReady}
	"AllReady", -- Server -> Client: {}
	"GameModeChanged", -- Server -> Client: {gameMode, maxSize}
	"LeaderChanged", -- Server -> Client: {newLeader}
	"Error", -- Server -> Client: {message}
}

--[[
	REBOOT EVENTS
	Reboot beacon system
]]
Events.Reboot = {
	"RequestReboot", -- Client -> Server: {beaconId, cardPlayerId}
	"CancelReboot", -- Client -> Server: {}
	"CardDropped", -- Server -> All: {playerId, playerName, teamId, position}
	"CardCollected", -- Server -> All: {collectorId, cardPlayerId}
	"CardExpired", -- Server -> All: {playerId, playerName}
	"RebootStarted", -- Server -> All: {beaconId, playerId, targetPlayerId, rebootTime}
	"RebootProgress", -- Server -> Client: {progress, beaconId}
	"RebootComplete", -- Server -> All: {beaconId, rebootedPlayers}
	"RebootCompleted", -- Server -> All: {rebooterId, rebootedId, beaconId} (alias)
	"RebootCancelled", -- Server -> All: {beaconId, playerId}
	"BeaconOnCooldown", -- Server -> Client: {beaconId, cooldownRemaining}
	"BeaconStateChanged", -- Server -> All: {beaconId, isActive}
}

--[[
	SHOP EVENTS
	In-game shop
]]
Events.Shop = {
	"GetItems", -- Client -> Server: {}
	"RequestData", -- Client -> Server: {} (alias)
	"RequestInventory", -- Client -> Server: {}
	"Purchase", -- Client -> Server: {itemId}
	"ItemsUpdate", -- Server -> Client: {items}
	"DataUpdate", -- Server -> Client: {items, featured} (alias)
	"InventoryUpdate", -- Server -> Client: {inventory}
	"PurchaseResult", -- Server -> Client: {success, itemId, error?}
	"PurchaseSuccess", -- Server -> Client: {itemId, newBalance} (alias)
	"PurchaseFailed", -- Server -> Client: {itemId, reason} (alias)
}

--[[
	LOOT EVENTS
	Loot spawning and interaction
]]
Events.Loot = {
	"RequestPickup", -- Client -> Server: {lootId}
	"PickupLoot", -- Client -> Server: {lootId} (alias)
	"LootSpawned", -- Server -> Nearby: {lootId, position, itemType}
	"LootPickedUp", -- Server -> All: {lootId, playerId}
	"LootDropped", -- Server -> All: {lootId, position, itemType}
	"ChestSpawned", -- Server -> Nearby: {chestId, position, tier}
	"ChestOpened", -- Server -> All: {chestId, openerId, loot}
}

--[[
	ENVIRONMENT EVENTS
	Environmental hazards and weather
]]
Events.Environment = {
	"EventWarning", -- Server -> All: {eventType, position, timeUntil}
	"EventStarted", -- Server -> All: {eventType, data}
	"EventEnded", -- Server -> All: {eventType}
	"LavaBomb", -- Server -> Nearby: {position, radius}
	"StampedeStart", -- Server -> All: {startPosition, direction, count}
	"PowerOutage", -- Server -> All: {duration, affectedAreas}
	"MonsoonStart", -- Server -> All: {intensity, duration}
}

--[[
	UI EVENTS
	User interface updates
]]
Events.UI = {
	"ShowBossHealthBar", -- Server -> All: {bossId, bossName, health, maxHealth}
	"UpdateBossHealthBar", -- Server -> All: {bossId, health, maxHealth}
	"HideBossHealthBar", -- Server -> All: {bossId}
	"RequestFullMap", -- Client -> Server: {}
	"ShowNotification", -- Server -> Client: {title, message, type}
}

--[[
	AI EVENTS
	AI and dinosaur behavior
]]
Events.AI = {
	"LoudNoise", -- Server -> All: {position, radius, intensity}
	"DinosaurNearby", -- Server -> Client: {isNearby, dinoId, species}
}

--[[
	MATCH EVENTS
	Match-specific events
]]
Events.Match = {
	"Victory", -- Server -> Client: {placement, stats}
	"Defeat", -- Server -> Client: {placement, stats}
	"Top10", -- Server -> Client: {placement}
}

--[[
	STORM EVENTS
	Storm-specific client events
]]
Events.Storm = {
	"PlayerInStorm", -- Server -> Client: {isInStorm, damage}
}

--[[
	ADMIN CONSOLE EVENTS
	Admin commands and server management
]]
Events.AdminConsole = {
	"ExecuteCommand", -- Client -> Server: {command, args}
	"CommandResult", -- Server -> Client: {success, message}
	"Feedback", -- Server -> Client: {success, message} (alias)
	"LogMessage", -- Server -> Client: {level, message, timestamp}
}

-- Cache for created events folder
local eventsFolder: Folder? = nil

--[[
	Initialize all RemoteEvents in ReplicatedStorage
	Should only be called once on the server
]]
function Events.Initialize(): Folder
	-- Check if already initialized
	local existing = ReplicatedStorage:FindFirstChild("Events")
	if existing then
		eventsFolder = existing :: Folder
		return eventsFolder :: Folder
	end

	-- Create main events folder
	local folder = Instance.new("Folder")
	folder.Name = "Events"
	folder.Parent = ReplicatedStorage

	-- Create category folders and events
	for category, eventList in pairs(Events) do
		-- Skip functions (Initialize, Get, etc.)
		if type(eventList) ~= "table" then
			continue
		end

		-- Skip if it's not an array of event names
		if #eventList == 0 then
			continue
		end

		local categoryFolder = Instance.new("Folder")
		categoryFolder.Name = category
		categoryFolder.Parent = folder

		for _, eventName in ipairs(eventList) do
			local remoteEvent = Instance.new("RemoteEvent")
			remoteEvent.Name = eventName
			remoteEvent.Parent = categoryFolder
		end
	end

	eventsFolder = folder
	return folder
end

--[[
	Get a RemoteEvent by category and name
	@param category The event category (Combat, Inventory, etc.)
	@param eventName The specific event name
	@return The RemoteEvent instance
]]
function Events.Get(category: string, eventName: string): RemoteEvent
	if not eventsFolder then
		eventsFolder = ReplicatedStorage:WaitForChild("Events") :: Folder
	end

	local categoryFolder = eventsFolder:FindFirstChild(category)
	if not categoryFolder then
		error(`Event category '{category}' not found`)
	end

	local event = categoryFolder:FindFirstChild(eventName)
	if not event then
		error(`Event '{eventName}' not found in category '{category}'`)
	end

	return event :: RemoteEvent
end

--[[
	Wait for the Events folder to be ready (client-side)
	@return The Events folder
]]
function Events.WaitForReady(): Folder
	eventsFolder = ReplicatedStorage:WaitForChild("Events") :: Folder
	return eventsFolder :: Folder
end

--[[
	Fire a server event to a specific client
	@param category The event category
	@param eventName The event name
	@param player The target player
	@param ... Arguments to send
]]
function Events.FireClient(category: string, eventName: string, player: Player, ...: any)
	local event = Events.Get(category, eventName)
	event:FireClient(player, ...)
end

--[[
	Fire a server event to all clients
	@param category The event category
	@param eventName The event name
	@param ... Arguments to send
]]
function Events.FireAllClients(category: string, eventName: string, ...: any)
	local event = Events.Get(category, eventName)
	event:FireAllClients(...)
end

--[[
	Fire a client event to the server
	@param category The event category
	@param eventName The event name
	@param ... Arguments to send
]]
function Events.FireServer(category: string, eventName: string, ...: any)
	local event = Events.Get(category, eventName)
	event:FireServer(...)
end

--[[
	Connect a server-side handler to an event
	@param category The event category
	@param eventName The event name
	@param handler The callback function
	@return The connection
]]
function Events.OnServerEvent(
	category: string,
	eventName: string,
	handler: (player: Player, ...any) -> ()
): RBXScriptConnection
	local event = Events.Get(category, eventName)
	return event.OnServerEvent:Connect(handler)
end

--[[
	Connect a client-side handler to an event
	@param category The event category
	@param eventName The event name
	@param handler The callback function
	@return The connection
]]
function Events.OnClientEvent(category: string, eventName: string, handler: (...any) -> ()): RBXScriptConnection
	local event = Events.Get(category, eventName)
	return event.OnClientEvent:Connect(handler)
end

return Events
