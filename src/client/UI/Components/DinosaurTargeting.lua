--!strict
--[[
	DinosaurTargeting.lua
	=====================
	Shows health bars and info above dinosaurs when player looks at them
	Also handles targeting highlight for dinosaurs in view
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local DinosaurTargeting = {}

-- State
local localPlayer = Players.LocalPlayer
local currentTarget: Model? = nil
local healthBarGui: BillboardGui? = nil
local targetInfoGui: ScreenGui? = nil
local updateConnection: RBXScriptConnection? = nil
local isInitialized = false

-- Settings
local MAX_TARGET_DISTANCE = 100
local HEALTH_BAR_OFFSET = Vector3.new(0, 3, 0)
local FADE_DURATION = 0.2

-- Tier colors
local TIER_COLORS = {
	Common = Color3.fromRGB(150, 150, 150),
	Uncommon = Color3.fromRGB(50, 200, 50),
	Rare = Color3.fromRGB(50, 100, 255),
	Epic = Color3.fromRGB(150, 50, 255),
	Legendary = Color3.fromRGB(255, 180, 50),
}

--[[
	Create health bar billboard GUI
]]
local function createHealthBarGui(): BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "DinoHealthBar"
	billboard.Size = UDim2.fromOffset(120, 40)
	billboard.StudsOffset = HEALTH_BAR_OFFSET
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = MAX_TARGET_DISTANCE
	billboard.Enabled = false

	-- Background frame
	local bgFrame = Instance.new("Frame")
	bgFrame.Name = "Background"
	bgFrame.Size = UDim2.fromScale(1, 1)
	bgFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	bgFrame.BackgroundTransparency = 0.3
	bgFrame.BorderSizePixel = 0
	bgFrame.Parent = billboard

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = UDim.new(0, 6)
	bgCorner.Parent = bgFrame

	-- Name label
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, -10, 0, 16)
	nameLabel.Position = UDim2.fromOffset(5, 2)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextSize = 12
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Text = "Dinosaur"
	nameLabel.Parent = bgFrame

	-- Tier indicator
	local tierLabel = Instance.new("TextLabel")
	tierLabel.Name = "TierLabel"
	tierLabel.Size = UDim2.new(0, 50, 0, 12)
	tierLabel.Position = UDim2.new(1, -55, 0, 3)
	tierLabel.BackgroundTransparency = 1
	tierLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	tierLabel.TextSize = 10
	tierLabel.Font = Enum.Font.Gotham
	tierLabel.TextXAlignment = Enum.TextXAlignment.Right
	tierLabel.Text = "Common"
	tierLabel.Parent = bgFrame

	-- Health bar background
	local healthBg = Instance.new("Frame")
	healthBg.Name = "HealthBg"
	healthBg.Size = UDim2.new(1, -10, 0, 10)
	healthBg.Position = UDim2.new(0, 5, 0, 20)
	healthBg.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
	healthBg.BorderSizePixel = 0
	healthBg.Parent = bgFrame

	local healthBgCorner = Instance.new("UICorner")
	healthBgCorner.CornerRadius = UDim.new(0, 4)
	healthBgCorner.Parent = healthBg

	-- Health bar fill
	local healthFill = Instance.new("Frame")
	healthFill.Name = "HealthFill"
	healthFill.Size = UDim2.fromScale(1, 1)
	healthFill.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
	healthFill.BorderSizePixel = 0
	healthFill.Parent = healthBg

	local healthFillCorner = Instance.new("UICorner")
	healthFillCorner.CornerRadius = UDim.new(0, 4)
	healthFillCorner.Parent = healthFill

	-- Health text
	local healthText = Instance.new("TextLabel")
	healthText.Name = "HealthText"
	healthText.Size = UDim2.new(1, 0, 0, 10)
	healthText.Position = UDim2.new(0, 0, 0, 32)
	healthText.BackgroundTransparency = 1
	healthText.TextColor3 = Color3.fromRGB(255, 255, 255)
	healthText.TextSize = 10
	healthText.Font = Enum.Font.GothamBold
	healthText.Text = "100/100"
	healthText.Parent = bgFrame

	return billboard
end

--[[
	Update health bar for current target
]]
local function updateHealthBar()
	if not currentTarget or not healthBarGui then
		return
	end

	-- Get dinosaur data from attributes
	local health = currentTarget:GetAttribute("Health") or 100
	local maxHealth = currentTarget:GetAttribute("MaxHealth") or 100
	local species = currentTarget:GetAttribute("Species") or "Unknown"
	local tier = currentTarget:GetAttribute("Tier") or "Common"

	local bgFrame = healthBarGui:FindFirstChild("Background") :: Frame?
	if not bgFrame then return end

	-- Update name
	local nameLabel = bgFrame:FindFirstChild("NameLabel") :: TextLabel?
	if nameLabel then
		nameLabel.Text = species
	end

	-- Update tier
	local tierLabel = bgFrame:FindFirstChild("TierLabel") :: TextLabel?
	if tierLabel then
		tierLabel.Text = tier
		tierLabel.TextColor3 = TIER_COLORS[tier] or TIER_COLORS.Common
	end

	-- Update health bar
	local healthBg = bgFrame:FindFirstChild("HealthBg") :: Frame?
	if healthBg then
		local healthFill = healthBg:FindFirstChild("HealthFill") :: Frame?
		if healthFill then
			local healthPercent = math.clamp(health / maxHealth, 0, 1)
			healthFill.Size = UDim2.fromScale(healthPercent, 1)

			-- Color based on health
			if healthPercent > 0.6 then
				healthFill.BackgroundColor3 = Color3.fromRGB(80, 200, 80)
			elseif healthPercent > 0.3 then
				healthFill.BackgroundColor3 = Color3.fromRGB(255, 180, 50)
			else
				healthFill.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
			end
		end
	end

	-- Update health text
	local healthText = bgFrame:FindFirstChild("HealthText") :: TextLabel?
	if healthText then
		healthText.Text = `{math.floor(health)}/{math.floor(maxHealth)}`
	end
end

--[[
	Set the current target dinosaur
]]
local function setTarget(dinosaur: Model?)
	if dinosaur == currentTarget then
		return
	end

	-- Clear previous target
	if currentTarget and healthBarGui then
		healthBarGui.Adornee = nil
		healthBarGui.Enabled = false
	end

	currentTarget = dinosaur

	if dinosaur and healthBarGui then
		-- Find the head or primary part to attach to
		local attachPart = dinosaur:FindFirstChild("Head") or dinosaur.PrimaryPart
		if attachPart then
			healthBarGui.Adornee = attachPart
			healthBarGui.Enabled = true
			updateHealthBar()
		end
	end
end

--[[
	Find dinosaur the player is looking at
]]
local function findTargetDinosaur(): Model?
	local camera = workspace.CurrentCamera
	if not camera then return nil end

	local character = localPlayer.Character
	if not character then return nil end

	-- Raycast from camera
	local origin = camera.CFrame.Position
	local direction = camera.CFrame.LookVector * MAX_TARGET_DISTANCE

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character }

	local result = workspace:Raycast(origin, direction, rayParams)
	if not result then return nil end

	-- Check if we hit a dinosaur
	local hitPart = result.Instance
	local model = hitPart:FindFirstAncestorOfClass("Model")

	if model then
		-- Check for dinosaur tag or attribute
		if model:HasTag("Dinosaur") or model:GetAttribute("Species") then
			return model
		end
	end

	return nil
end

--[[
	Update loop
]]
local function update()
	if not isInitialized then return end

	-- Find what player is looking at
	local target = findTargetDinosaur()
	setTarget(target)

	-- Update health bar if we have a target
	if currentTarget then
		updateHealthBar()
	end
end

--[[
	Initialize the targeting system
]]
function DinosaurTargeting.Initialize()
	if isInitialized then return end

	-- Create health bar GUI
	healthBarGui = createHealthBarGui()

	-- Parent to player GUI
	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui
	healthBarGui.Parent = playerGui

	-- Start update loop
	updateConnection = RunService.Heartbeat:Connect(update)

	isInitialized = true
	print("[DinosaurTargeting] Initialized")
end

--[[
	Get current target
]]
function DinosaurTargeting.GetCurrentTarget(): Model?
	return currentTarget
end

--[[
	Check if a specific dinosaur is being targeted
]]
function DinosaurTargeting.IsTargeting(dinosaur: Model): boolean
	return currentTarget == dinosaur
end

--[[
	Cleanup
]]
function DinosaurTargeting.Cleanup()
	isInitialized = false

	if updateConnection then
		updateConnection:Disconnect()
		updateConnection = nil
	end

	if healthBarGui then
		healthBarGui:Destroy()
		healthBarGui = nil
	end

	currentTarget = nil
end

return DinosaurTargeting
