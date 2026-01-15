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
	"StormUpdate", -- Server -> All: {phase, center, radius, nextRadius, timeRemaining}
	"PlayerCountUpdate", -- Server -> All: {alivePlayers, totalPlayers}
	"CountdownStarted", -- Server -> All: {duration}
	"CountdownUpdate", -- Server -> All: {remaining}
	"DeployReady", -- Server -> All: {flightPath}
	"PlayerJumped", -- Client -> Server: {}
	"GliderInput", -- Client -> Server: {pitch, yaw}
	"GliderEnabled", -- Server -> Client: {position, forced?}
	"GliderDisabled", -- Server -> Client: {}
	"GliderLanded", -- Server -> Client: {position}
	"JumpDenied", -- Server -> Client: {reason}
	"PlayerJumpedFromHelicopter", -- Server -> All: {playerId, position}
	"SupplyDropIncoming", -- Server -> All: {position}
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
	"BossSpawned", -- Server -> All: {bossId, species, position}
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
	"ClaimReward", -- Client -> Server: {tier}
	"ProgressUpdate", -- Server -> Client: {tier, xp, rewards}
	"RewardClaimed", -- Server -> Client: {tier, reward}
}

--[[
	TUTORIAL EVENTS
	Player tutorials and onboarding
]]
Events.Tutorial = {
	"GetStatus", -- Client -> Server: {}
	"Complete", -- Client -> Server: {tutorialId}
	"Skip", -- Client -> Server: {}
	"StatusUpdate", -- Server -> Client: {completedTutorials}
}

--[[
	ACCESSIBILITY EVENTS
	Accessibility settings
]]
Events.Accessibility = {
	"GetSettings", -- Client -> Server: {}
	"UpdateSettings", -- Client -> Server: {settings}
	"SettingsUpdate", -- Server -> Client: {settings}
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
	"QueueMatch", -- Client -> Server: {}
	"LeaveQueue", -- Client -> Server: {}
	"StatsUpdate", -- Server -> Client: {rank, points, wins}
}

--[[
	PARTY EVENTS
	Party/squad system
]]
Events.Party = {
	"Create", -- Client -> Server: {}
	"Invite", -- Client -> Server: {playerId}
	"Join", -- Client -> Server: {partyId}
	"Leave", -- Client -> Server: {}
	"Kick", -- Client -> Server: {playerId}
	"PartyUpdate", -- Server -> Client: {members, leader}
	"InviteReceived", -- Server -> Client: {partyId, leaderName}
}

--[[
	REBOOT EVENTS
	Reboot beacon system
]]
Events.Reboot = {
	"RequestReboot", -- Client -> Server: {beaconId, cardPlayerId}
	"CancelReboot", -- Client -> Server: {}
	"RebootStarted", -- Server -> All: {beaconId, userId}
	"RebootComplete", -- Server -> All: {beaconId, rebootedPlayers}
	"RebootCancelled", -- Server -> All: {beaconId}
}

--[[
	SHOP EVENTS
	In-game shop
]]
Events.Shop = {
	"GetItems", -- Client -> Server: {}
	"Purchase", -- Client -> Server: {itemId}
	"ItemsUpdate", -- Server -> Client: {items}
	"PurchaseResult", -- Server -> Client: {success, itemId, error?}
}

--[[
	LOOT EVENTS
	Loot spawning and interaction
]]
Events.Loot = {
	"RequestPickup", -- Client -> Server: {lootId}
	"LootSpawned", -- Server -> Nearby: {lootId, position, itemType}
	"LootPickedUp", -- Server -> All: {lootId, playerId}
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
