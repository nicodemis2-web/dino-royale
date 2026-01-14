--!strict
--[[
	AccessibilityManager.lua
	========================
	Server-side accessibility settings persistence
	Based on GDD Section 9.3: Accessibility Options
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Events = require(ReplicatedStorage.Shared.Events)
local AccessibilityData = require(ReplicatedStorage.Shared.AccessibilityData)

local AccessibilityManager = {}

-- State
local playerSettings: { [Player]: AccessibilityData.AccessibilitySettings } = {}
local isInitialized = false

--[[
	Initialize the accessibility manager
]]
function AccessibilityManager.Initialize()
	if isInitialized then return end
	isInitialized = true

	print("[AccessibilityManager] Initializing...")

	-- Setup client events
	Events.OnServerEvent("Accessibility", function(player, action, data)
		if action == "RequestSettings" then
			AccessibilityManager.SendSettings(player)
		elseif action == "SaveSettings" then
			AccessibilityManager.SaveSettings(player, data.settings)
		end
	end)

	-- Setup player tracking
	Players.PlayerAdded:Connect(function(player)
		AccessibilityManager.InitializePlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		AccessibilityManager.SavePlayer(player)
		AccessibilityManager.CleanupPlayer(player)
	end)

	-- Initialize existing players
	for _, player in ipairs(Players:GetPlayers()) do
		AccessibilityManager.InitializePlayer(player)
	end

	print("[AccessibilityManager] Initialized")
end

--[[
	Initialize player settings
]]
function AccessibilityManager.InitializePlayer(player: Player)
	-- TODO: Load from DataStore
	playerSettings[player] = AccessibilityData.Defaults

	task.defer(function()
		AccessibilityManager.SendSettings(player)
	end)
end

--[[
	Save player settings
]]
function AccessibilityManager.SavePlayer(player: Player)
	local settings = playerSettings[player]
	if not settings then return end

	-- TODO: Save to DataStore
	print(`[AccessibilityManager] Saving settings for {player.Name}`)
end

--[[
	Save settings from client
]]
function AccessibilityManager.SaveSettings(player: Player, settings: any)
	local validated = AccessibilityData.Validate(settings)
	playerSettings[player] = validated

	-- TODO: Persist to DataStore
	print(`[AccessibilityManager] Updated settings for {player.Name}`)
end

--[[
	Cleanup player
]]
function AccessibilityManager.CleanupPlayer(player: Player)
	playerSettings[player] = nil
end

--[[
	Send settings to player
]]
function AccessibilityManager.SendSettings(player: Player)
	local settings = playerSettings[player]
	if not settings then return end

	Events.FireClient(player, "Accessibility", "SettingsLoaded", {
		settings = settings,
	})
end

--[[
	Get player settings
]]
function AccessibilityManager.GetSettings(player: Player): AccessibilityData.AccessibilitySettings?
	return playerSettings[player]
end

return AccessibilityManager
