--!strict
--[[
	TutorialUI.lua
	==============
	Client-side tutorial display and context tips
	Based on GDD Section 10: Tutorial & Onboarding
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Events = require(ReplicatedStorage.Shared.Events)
local TutorialData = require(ReplicatedStorage.Shared.TutorialData)

local TutorialUI = {}

-- State
local player = Players.LocalPlayer
local screenGui: ScreenGui? = nil
local tipFrame: Frame? = nil
local objectiveFrame: Frame? = nil
local promptFrame: Frame? = nil
local __currentStage: TutorialData.TutorialStage? = nil
local currentTip: string? = nil
local isInTutorial = false

-- Constants
local TIP_DISPLAY_TIME = 5
local TIP_FADE_TIME = 0.3

--[[
	Initialize the tutorial UI
]]
function TutorialUI.Initialize()
	print("[TutorialUI] Initializing...")

	TutorialUI.CreateUI()
	TutorialUI.SetupEventListeners()

	-- Request progress
	Events.FireServer("Tutorial", "RequestProgress", {})

	print("[TutorialUI] Initialized")
end

--[[
	Create UI elements
]]
function TutorialUI.CreateUI()
	local playerGui = player:WaitForChild("PlayerGui")

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TutorialGui"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	-- Tutorial prompt frame
	promptFrame = Instance.new("Frame")
	promptFrame.Name = "TutorialPrompt"
	promptFrame.Size = UDim2.fromOffset(450, 250)
	promptFrame.Position = UDim2.fromScale(0.5, 0.5)
	promptFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	promptFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	promptFrame.BorderSizePixel = 0
	promptFrame.Visible = false
	promptFrame.Parent = screenGui

	local promptCorner = Instance.new("UICorner")
	promptCorner.CornerRadius = UDim.new(0, 12)
	promptCorner.Parent = promptFrame

	local promptTitle = Instance.new("TextLabel")
	promptTitle.Name = "Title"
	promptTitle.Size = UDim2.new(1, 0, 0, 40)
	promptTitle.Position = UDim2.fromOffset(0, 20)
	promptTitle.BackgroundTransparency = 1
	promptTitle.TextColor3 = Color3.fromRGB(255, 200, 50)
	promptTitle.TextSize = 24
	promptTitle.Font = Enum.Font.GothamBold
	promptTitle.Text = "Welcome to Dino Royale!"
	promptTitle.Parent = promptFrame

	local promptDesc = Instance.new("TextLabel")
	promptDesc.Name = "Description"
	promptDesc.Size = UDim2.new(1, -40, 0, 60)
	promptDesc.Position = UDim2.fromOffset(20, 70)
	promptDesc.BackgroundTransparency = 1
	promptDesc.TextColor3 = Color3.fromRGB(180, 180, 180)
	promptDesc.TextSize = 14
	promptDesc.Font = Enum.Font.Gotham
	promptDesc.TextWrapped = true
	promptDesc.Text = "Would you like to complete the tutorial? Learn movement, combat, and how to survive dinosaur encounters."
	promptDesc.Parent = promptFrame

	local startButton = Instance.new("TextButton")
	startButton.Name = "StartButton"
	startButton.Size = UDim2.fromOffset(150, 45)
	startButton.Position = UDim2.new(0.3, 0, 1, -70)
	startButton.AnchorPoint = Vector2.new(0.5, 0)
	startButton.BackgroundColor3 = Color3.fromRGB(80, 180, 80)
	startButton.BorderSizePixel = 0
	startButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	startButton.TextSize = 16
	startButton.Font = Enum.Font.GothamBold
	startButton.Text = "Start Tutorial"
	startButton.Parent = promptFrame

	local startCorner = Instance.new("UICorner")
	startCorner.CornerRadius = UDim.new(0, 8)
	startCorner.Parent = startButton

	startButton.MouseButton1Click:Connect(function()
		TutorialUI.StartTutorial()
	end)

	local skipButton = Instance.new("TextButton")
	skipButton.Name = "SkipButton"
	skipButton.Size = UDim2.fromOffset(150, 45)
	skipButton.Position = UDim2.new(0.7, 0, 1, -70)
	skipButton.AnchorPoint = Vector2.new(0.5, 0)
	skipButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
	skipButton.BorderSizePixel = 0
	skipButton.TextColor3 = Color3.fromRGB(200, 200, 200)
	skipButton.TextSize = 16
	skipButton.Font = Enum.Font.GothamBold
	skipButton.Text = "Skip"
	skipButton.Parent = promptFrame

	local skipCorner = Instance.new("UICorner")
	skipCorner.CornerRadius = UDim.new(0, 8)
	skipCorner.Parent = skipButton

	skipButton.MouseButton1Click:Connect(function()
		TutorialUI.SkipTutorial()
	end)

	-- Context tip frame
	tipFrame = Instance.new("Frame")
	tipFrame.Name = "TipFrame"
	tipFrame.Size = UDim2.fromOffset(400, 60)
	tipFrame.Position = UDim2.new(0.5, 0, 0, 150)
	tipFrame.AnchorPoint = Vector2.new(0.5, 0)
	tipFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	tipFrame.BackgroundTransparency = 0.1
	tipFrame.BorderSizePixel = 0
	tipFrame.Visible = false
	tipFrame.Parent = screenGui

	local tipCorner = Instance.new("UICorner")
	tipCorner.CornerRadius = UDim.new(0, 8)
	tipCorner.Parent = tipFrame

	local tipIcon = Instance.new("TextLabel")
	tipIcon.Name = "Icon"
	tipIcon.Size = UDim2.new(0, 40, 1, 0)
	tipIcon.Position = UDim2.fromOffset(10, 0)
	tipIcon.BackgroundTransparency = 1
	tipIcon.TextColor3 = Color3.fromRGB(255, 200, 50)
	tipIcon.TextSize = 24
	tipIcon.Font = Enum.Font.GothamBold
	tipIcon.Text = "TIP"
	tipIcon.Parent = tipFrame

	local tipText = Instance.new("TextLabel")
	tipText.Name = "Text"
	tipText.Size = UDim2.new(1, -70, 1, -10)
	tipText.Position = UDim2.fromOffset(55, 5)
	tipText.BackgroundTransparency = 1
	tipText.TextColor3 = Color3.fromRGB(220, 220, 220)
	tipText.TextSize = 14
	tipText.Font = Enum.Font.Gotham
	tipText.TextXAlignment = Enum.TextXAlignment.Left
	tipText.TextWrapped = true
	tipText.Text = ""
	tipText.Parent = tipFrame

	-- Objective tracker frame (for active tutorial)
	objectiveFrame = Instance.new("Frame")
	objectiveFrame.Name = "Objectives"
	objectiveFrame.Size = UDim2.fromOffset(300, 200)
	objectiveFrame.Position = UDim2.new(1, -20, 0.5, 0)
	objectiveFrame.AnchorPoint = Vector2.new(1, 0.5)
	objectiveFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	objectiveFrame.BackgroundTransparency = 0.2
	objectiveFrame.BorderSizePixel = 0
	objectiveFrame.Visible = false
	objectiveFrame.Parent = screenGui

	local objCorner = Instance.new("UICorner")
	objCorner.CornerRadius = UDim.new(0, 8)
	objCorner.Parent = objectiveFrame

	local objTitle = Instance.new("TextLabel")
	objTitle.Name = "Title"
	objTitle.Size = UDim2.new(1, 0, 0, 30)
	objTitle.BackgroundTransparency = 1
	objTitle.TextColor3 = Color3.fromRGB(255, 200, 50)
	objTitle.TextSize = 16
	objTitle.Font = Enum.Font.GothamBold
	objTitle.Text = "TUTORIAL"
	objTitle.Parent = objectiveFrame

	local objList = Instance.new("Frame")
	objList.Name = "List"
	objList.Size = UDim2.new(1, -20, 1, -40)
	objList.Position = UDim2.fromOffset(10, 35)
	objList.BackgroundTransparency = 1
	objList.Parent = objectiveFrame

	local objLayout = Instance.new("UIListLayout")
	objLayout.Padding = UDim.new(0, 5)
	objLayout.Parent = objList
end

--[[
	Setup event listeners
]]
function TutorialUI.SetupEventListeners()
	Events.OnClientEvent("Tutorial", function(action, data)
		if action == "PromptStart" then
			TutorialUI.ShowPrompt()
		elseif action == "StartStage" then
			TutorialUI.ShowStage(data.stage)
		elseif action == "StageCompleted" then
			TutorialUI.OnStageCompleted(data)
		elseif action == "TutorialCompleted" then
			TutorialUI.OnTutorialCompleted()
		elseif action == "TutorialSkipped" then
			TutorialUI.OnTutorialSkipped()
		elseif action == "ShowTip" then
			TutorialUI.ShowTip(data.tipId, data.message)
		elseif action == "ProgressUpdate" then
			TutorialUI.OnProgressUpdate(data)
		end
	end)
end

--[[
	Show tutorial prompt
]]
function TutorialUI.ShowPrompt()
	if not promptFrame then return end
	promptFrame.Visible = true
end

--[[
	Hide tutorial prompt
]]
function TutorialUI.HidePrompt()
	if not promptFrame then return end
	promptFrame.Visible = false
end

--[[
	Start tutorial
]]
function TutorialUI.StartTutorial()
	TutorialUI.HidePrompt()
	isInTutorial = true
	Events.FireServer("Tutorial", "StartTutorial", {})
end

--[[
	Skip tutorial
]]
function TutorialUI.SkipTutorial()
	TutorialUI.HidePrompt()
	Events.FireServer("Tutorial", "SkipTutorial", {})
end

--[[
	Show a tutorial stage
]]
function TutorialUI.ShowStage(stage: TutorialData.TutorialStage)
	if not objectiveFrame then return end

	_currentStage = stage
	isInTutorial = true
	objectiveFrame.Visible = true

	-- Update title
	local title = objectiveFrame:FindFirstChild("Title") :: TextLabel?
	if title then
		title.Text = stage.name:upper()
	end

	-- Update objectives list
	local list = objectiveFrame:FindFirstChild("List") :: Frame?
	if list then
		-- Clear existing
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end

		-- Add objectives
		for i, objective in ipairs(stage.objectives) do
			local objLabel = Instance.new("TextLabel")
			objLabel.Name = `Objective_{i}`
			objLabel.Size = UDim2.new(1, 0, 0, 25)
			objLabel.BackgroundTransparency = 1
			objLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
			objLabel.TextSize = 12
			objLabel.Font = Enum.Font.Gotham
			objLabel.TextXAlignment = Enum.TextXAlignment.Left
			objLabel.TextWrapped = true
			objLabel.Text = `[ ] {objective}`
			objLabel.LayoutOrder = i
			objLabel.Parent = list
		end
	end
end

--[[
	Mark objective as complete
]]
function TutorialUI.CompleteObjective(index: number)
	if not objectiveFrame then return end

	local list = objectiveFrame:FindFirstChild("List") :: Frame?
	if not list then return end

	local objLabel = list:FindFirstChild(`Objective_{index}`) :: TextLabel?
	if objLabel then
		objLabel.TextColor3 = Color3.fromRGB(100, 200, 100)
		objLabel.Text = objLabel.Text:gsub("%[ %]", "[X]")
	end
end

--[[
	On stage completed
]]
function TutorialUI.OnStageCompleted(data: any)
	-- Show completion feedback
	print(`[TutorialUI] Stage completed: {data.stageId}`)
end

--[[
	On tutorial completed
]]
function TutorialUI.OnTutorialCompleted()
	isInTutorial = false
	_currentStage = nil

	if objectiveFrame then
		objectiveFrame.Visible = false
	end

	-- Show completion message
	TutorialUI.ShowTip("completed", "Tutorial Complete! You're ready to survive Isla Primordial!")
end

--[[
	On tutorial skipped
]]
function TutorialUI.OnTutorialSkipped()
	isInTutorial = false
	_currentStage = nil

	if objectiveFrame then
		objectiveFrame.Visible = false
	end
end

--[[
	Show a context tip
]]
function TutorialUI.ShowTip(tipId: string, message: string)
	if not tipFrame then return end
	if currentTip then return end -- Don't interrupt current tip

	currentTip = tipId

	local textLabel = tipFrame:FindFirstChild("Text") :: TextLabel?
	if textLabel then
		textLabel.Text = message
	end

	-- Animate in
	tipFrame.Position = UDim2.new(0.5, 0, 0, 100)
	tipFrame.BackgroundTransparency = 1
	tipFrame.Visible = true

	TweenService:Create(tipFrame, TweenInfo.new(TIP_FADE_TIME), {
		Position = UDim2.new(0.5, 0, 0, 150),
		BackgroundTransparency = 0.1,
	}):Play()

	-- Auto hide after delay
	task.delay(TIP_DISPLAY_TIME, function()
		if currentTip == tipId then
			TutorialUI.HideTip()
		end
	end)
end

--[[
	Hide current tip
]]
function TutorialUI.HideTip()
	if not tipFrame then return end
	if not currentTip then return end

	local tipId = currentTip

	local tween = TweenService:Create(tipFrame, TweenInfo.new(TIP_FADE_TIME), {
		Position = UDim2.new(0.5, 0, 0, 100),
		BackgroundTransparency = 1,
	})

	tween:Play()
	tween.Completed:Connect(function()
		if currentTip == tipId then
			tipFrame.Visible = false
			currentTip = nil

			-- Acknowledge tip was seen
			Events.FireServer("Tutorial", "AcknowledgeTip", { tipId = tipId })
		end
	end)
end

--[[
	On progress update
]]
function TutorialUI.OnProgressUpdate(_data: any)
	-- Could update UI to show which stages are complete
end

--[[
	Check if in tutorial
]]
function TutorialUI.IsInTutorial(): boolean
	return isInTutorial
end

return TutorialUI
