--!strict
--[[
	TutorialManager.lua
	===================
	Server-side tutorial progress and tip tracking
	Based on GDD Section 10: Tutorial & Onboarding
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Events = require(ReplicatedStorage.Shared.Events)
local TutorialData = require(ReplicatedStorage.Shared.TutorialData)

local TutorialManager = {}

-- Types
export type PlayerTutorialProgress = {
	completedStages: { [string]: boolean },
	shownTips: { [string]: number }, -- tip id -> times shown
	matchesPlayed: number,
	tutorialCompleted: boolean,
	trainingCompleted: boolean,
}

-- State
local playerProgress: { [Player]: PlayerTutorialProgress } = {}
local isInitialized = false

-- Constants
local TIPS_ACTIVE_MATCHES = 10 -- Show tips for first N matches

-- Signals
local onStageCompleted = Instance.new("BindableEvent")
local onTutorialCompleted = Instance.new("BindableEvent")

TutorialManager.OnStageCompleted = onStageCompleted.Event
TutorialManager.OnTutorialCompleted = onTutorialCompleted.Event

--[[
	Initialize the tutorial manager
]]
function TutorialManager.Initialize()
	if isInitialized then return end
	isInitialized = true

	print("[TutorialManager] Initializing...")

	-- Setup client events
	Events.OnServerEvent("Tutorial", "Complete", function(player, data)
		if typeof(data) == "table" and typeof(data.tutorialId) == "string" then
			TutorialManager.CompleteStage(player, data.tutorialId)
		end
	end)

	Events.OnServerEvent("Tutorial", "Skip", function(player)
		TutorialManager.SkipTutorial(player)
	end)

	Events.OnServerEvent("Tutorial", "GetStatus", function(player)
		TutorialManager.SendProgress(player)
	end)

	-- Setup player tracking
	Players.PlayerAdded:Connect(function(player)
		TutorialManager.InitializePlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		TutorialManager.SavePlayer(player)
		TutorialManager.CleanupPlayer(player)
	end)

	-- Initialize existing players
	for _, player in ipairs(Players:GetPlayers()) do
		TutorialManager.InitializePlayer(player)
	end

	print("[TutorialManager] Initialized")
end

--[[
	Initialize player tutorial progress
]]
function TutorialManager.InitializePlayer(player: Player)
	-- TODO: Load from DataStore
	local progress: PlayerTutorialProgress = {
		completedStages = {},
		shownTips = {},
		matchesPlayed = 0,
		tutorialCompleted = false,
		trainingCompleted = false,
	}

	playerProgress[player] = progress

	task.defer(function()
		TutorialManager.SendProgress(player)

		-- Check if new player needs tutorial prompt
		if not progress.tutorialCompleted and progress.matchesPlayed == 0 then
			TutorialManager.PromptTutorial(player)
		end
	end)
end

--[[
	Save player progress
]]
function TutorialManager.SavePlayer(player: Player)
	local progress = playerProgress[player]
	if not progress then return end

	-- TODO: Save to DataStore
	print(`[TutorialManager] Saving progress for {player.Name}`)
end

--[[
	Cleanup player
]]
function TutorialManager.CleanupPlayer(player: Player)
	playerProgress[player] = nil
end

--[[
	Prompt new player to start tutorial
]]
function TutorialManager.PromptTutorial(player: Player)
	Events.FireClient(player, "Tutorial", "PromptStart", {
		totalDuration = TutorialData.GetTotalDuration(),
		rewards = { "Starter Skin", "100 XP Boost" },
	})
end

--[[
	Start tutorial for player
]]
function TutorialManager.StartTutorial(player: Player)
	local progress = playerProgress[player]
	if not progress then return end

	-- Get first incomplete stage
	local nextStage = TutorialManager.GetNextStage(player)
	if not nextStage then
		-- Already completed
		TutorialManager.CompleteTutorial(player)
		return
	end

	Events.FireClient(player, "Tutorial", "StartStage", {
		stage = nextStage,
	})

	print(`[TutorialManager] {player.Name} started tutorial stage: {nextStage.id}`)
end

--[[
	Get next incomplete stage
]]
function TutorialManager.GetNextStage(player: Player): TutorialData.TutorialStage?
	local progress = playerProgress[player]
	if not progress then return nil end

	for _, stage in ipairs(TutorialData.Stages) do
		if not progress.completedStages[stage.id] then
			return stage
		end
	end

	return nil
end

--[[
	Complete a tutorial stage
]]
function TutorialManager.CompleteStage(player: Player, stageId: string)
	local progress = playerProgress[player]
	if not progress then return end

	-- Validate stage exists
	local stage = TutorialData.GetStage(stageId)
	if not stage then return end

	-- Mark as complete
	progress.completedStages[stageId] = true

	-- Grant rewards if any
	if stage.rewards then
		for _, rewardId in ipairs(stage.rewards) do
			TutorialManager.GrantReward(player, rewardId)
		end
	end

	Events.FireClient(player, "Tutorial", "StageCompleted", {
		stageId = stageId,
		rewards = stage.rewards,
	})

	onStageCompleted:Fire(player, stageId)
	print(`[TutorialManager] {player.Name} completed stage: {stageId}`)

	-- Check if tutorial is complete
	local nextStage = TutorialManager.GetNextStage(player)
	if not nextStage then
		TutorialManager.CompleteTutorial(player)
	else
		-- Start next stage
		Events.FireClient(player, "Tutorial", "StartStage", {
			stage = nextStage,
		})
	end
end

--[[
	Complete entire tutorial
]]
function TutorialManager.CompleteTutorial(player: Player)
	local progress = playerProgress[player]
	if not progress then return end

	progress.tutorialCompleted = true

	-- Grant completion rewards
	TutorialManager.GrantReward(player, "TutorialCompletion")

	Events.FireClient(player, "Tutorial", "TutorialCompleted", {
		rewards = { "Starter Skin", "100 XP Boost" },
	})

	onTutorialCompleted:Fire(player)
	print(`[TutorialManager] {player.Name} completed tutorial!`)
end

--[[
	Skip tutorial
]]
function TutorialManager.SkipTutorial(player: Player)
	local progress = playerProgress[player]
	if not progress then return end

	progress.tutorialCompleted = true
	-- Mark all stages as skipped (not completed, but no longer needed)

	Events.FireClient(player, "Tutorial", "TutorialSkipped", {})
	print(`[TutorialManager] {player.Name} skipped tutorial`)
end

--[[
	Grant a reward
]]
function TutorialManager.GrantReward(player: Player, rewardId: string)
	-- TODO: Integrate with cosmetics/progression system
	print(`[TutorialManager] Granting reward {rewardId} to {player.Name}`)
end

--[[
	Trigger a context tip
]]
function TutorialManager.TriggerTip(player: Player, trigger: string)
	local progress = playerProgress[player]
	if not progress then return end

	-- Don't show tips after N matches
	if progress.matchesPlayed > TIPS_ACTIVE_MATCHES then return end

	-- Get tips for this trigger
	local tips = TutorialData.GetTipsForTrigger(trigger)
	if #tips == 0 then return end

	for _, tip in ipairs(tips) do
		local timesShown = progress.shownTips[tip.id] or 0
		if timesShown < tip.showCount then
			-- Show this tip
			Events.FireClient(player, "Tutorial", "ShowTip", {
				tipId = tip.id,
				message = tip.message,
				priority = tip.priority,
			})

			progress.shownTips[tip.id] = timesShown + 1
			return -- Only show one tip at a time
		end
	end
end

--[[
	Acknowledge a tip (player dismissed it)
]]
function TutorialManager.AcknowledgeTip(player: Player, tipId: string)
	local progress = playerProgress[player]
	if not progress then return end

	-- Mark as shown one more time to reduce future shows
	local timesShown = progress.shownTips[tipId] or 0
	progress.shownTips[tipId] = timesShown + 1
end

--[[
	Record match played
]]
function TutorialManager.RecordMatchPlayed(player: Player)
	local progress = playerProgress[player]
	if not progress then return end

	progress.matchesPlayed = progress.matchesPlayed + 1
end

--[[
	Enter training grounds
]]
function TutorialManager.EnterTrainingGrounds(player: Player, mode: string)
	-- TODO: Teleport to training grounds place or instance
	print(`[TutorialManager] {player.Name} entering training: {mode}`)

	Events.FireClient(player, "Tutorial", "EnterTraining", {
		mode = mode,
	})
end

--[[
	Send progress to client
]]
function TutorialManager.SendProgress(player: Player)
	local progress = playerProgress[player]
	if not progress then return end

	local stageProgress = {}
	for _, stage in ipairs(TutorialData.Stages) do
		stageProgress[stage.id] = progress.completedStages[stage.id] or false
	end

	Events.FireClient(player, "Tutorial", "ProgressUpdate", {
		completedStages = stageProgress,
		matchesPlayed = progress.matchesPlayed,
		tutorialCompleted = progress.tutorialCompleted,
		trainingCompleted = progress.trainingCompleted,
	})
end

--[[
	Check if player needs tutorial
]]
function TutorialManager.NeedsTutorial(player: Player): boolean
	local progress = playerProgress[player]
	return progress and not progress.tutorialCompleted or false
end

--[[
	Check if player completed tutorial
]]
function TutorialManager.HasCompletedTutorial(player: Player): boolean
	local progress = playerProgress[player]
	return progress and progress.tutorialCompleted or false
end

return TutorialManager
