--!strict
--[[
	WeaponEffects.lua
	=================
	Visual and audio effects for weapons
	Handles muzzle flash, tracers, impacts, and hit markers
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local WeaponBase = require(game.ReplicatedStorage.Shared.Weapons.WeaponBase)

-- Type imports
type WeaponInstance = WeaponBase.WeaponInstance

local WeaponEffects = {}

-- Local player reference
local localPlayer = Players.LocalPlayer

-- Effect pools for performance
local tracerPool = {} :: { Part }
local impactPool = {} :: { Part }
local shellPool = {} :: { Part }

-- Pool sizes
local POOL_SIZE = 20

-- Hit marker UI
local hitMarkerGui: ScreenGui? = nil
local hitMarkerImage: ImageLabel? = nil

--[[
	Initialize the effects system
]]
function WeaponEffects.Initialize()
	-- Create object pools
	WeaponEffects.InitializePools()

	-- Create hit marker UI
	WeaponEffects.CreateHitMarkerUI()
end

--[[
	Initialize object pools for performance
]]
function WeaponEffects.InitializePools()
	-- Tracer pool
	for _ = 1, POOL_SIZE do
		local tracer = Instance.new("Part")
		tracer.Name = "Tracer"
		tracer.Anchored = true
		tracer.CanCollide = false
		tracer.CanQuery = false
		tracer.Size = Vector3.new(0.1, 0.1, 1)
		tracer.Material = Enum.Material.Neon
		tracer.Color = Color3.fromRGB(255, 200, 100)
		tracer.Transparency = 0.3
		tracer.Parent = nil
		table.insert(tracerPool, tracer)
	end

	-- Impact pool
	for _ = 1, POOL_SIZE do
		local impact = Instance.new("Part")
		impact.Name = "Impact"
		impact.Anchored = true
		impact.CanCollide = false
		impact.CanQuery = false
		impact.Size = Vector3.new(0.3, 0.3, 0.3)
		impact.Shape = Enum.PartType.Ball
		impact.Material = Enum.Material.Neon
		impact.Transparency = 0.5
		impact.Parent = nil
		table.insert(impactPool, impact)
	end

	-- Shell casing pool
	for _ = 1, POOL_SIZE do
		local shell = Instance.new("Part")
		shell.Name = "Shell"
		shell.Anchored = false
		shell.CanCollide = true
		shell.Size = Vector3.new(0.1, 0.1, 0.3)
		shell.Material = Enum.Material.Metal
		shell.Color = Color3.fromRGB(200, 170, 100)
		shell.Parent = nil
		table.insert(shellPool, shell)
	end
end

--[[
	Get an item from a pool
]]
local function getFromPool(pool: { Part }): Part?
	for i, item in ipairs(pool) do
		if not item.Parent then
			return item
		end
	end
	return nil
end

--[[
	Create hit marker UI
]]
function WeaponEffects.CreateHitMarkerUI()
	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

	hitMarkerGui = Instance.new("ScreenGui")
	hitMarkerGui.Name = "HitMarkerGui"
	hitMarkerGui.ResetOnSpawn = false
	hitMarkerGui.IgnoreGuiInset = true
	hitMarkerGui.Parent = playerGui

	hitMarkerImage = Instance.new("ImageLabel")
	hitMarkerImage.Name = "HitMarker"
	hitMarkerImage.AnchorPoint = Vector2.new(0.5, 0.5)
	hitMarkerImage.Position = UDim2.fromScale(0.5, 0.5)
	hitMarkerImage.Size = UDim2.fromOffset(50, 50)
	hitMarkerImage.BackgroundTransparency = 1
	hitMarkerImage.Image = "" -- Would use actual hitmarker image
	hitMarkerImage.ImageTransparency = 1
	hitMarkerImage.Parent = hitMarkerGui

	-- Create X shape with frames as fallback
	local function createLine(rotation: number): Frame
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = UDim2.fromScale(0.5, 0.5)
		line.Size = UDim2.new(0, 3, 0, 30)
		line.Rotation = rotation
		line.BackgroundColor3 = Color3.new(1, 1, 1)
		line.BorderSizePixel = 0
		line.BackgroundTransparency = 1
		line.Parent = hitMarkerImage
		return line
	end

	createLine(45)
	createLine(-45)
end

--[[
	Play muzzle flash effect
	@param weaponModel The weapon model (optional)
	@param weaponType The weapon type/category
]]
function WeaponEffects.MuzzleFlash(weaponModel: Model?, weaponType: string)
	-- Find muzzle attachment or default position
	local muzzlePosition = Vector3.zero

	if weaponModel then
		local muzzle = weaponModel:FindFirstChild("Muzzle", true)
		if muzzle and muzzle:IsA("Attachment") then
			muzzlePosition = muzzle.WorldPosition
		elseif muzzle and muzzle:IsA("BasePart") then
			muzzlePosition = muzzle.Position
		end
	end

	-- Create flash light
	local flash = Instance.new("PointLight")
	flash.Brightness = 3
	flash.Range = 10
	flash.Color = Color3.fromRGB(255, 200, 100)

	-- Parent to character or workspace
	local character = localPlayer.Character
	if character then
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			flash.Parent = rootPart
		end
	end

	-- Quick flash
	Debris:AddItem(flash, 0.05)
end

--[[
	Create bullet tracer effect
	@param origin Start position
	@param target End position
	@param weaponType The weapon type/category
]]
function WeaponEffects.BulletTracer(origin: Vector3, target: Vector3, weaponType: string)
	local tracer = getFromPool(tracerPool)
	if not tracer then
		return
	end

	local distance = (target - origin).Magnitude
	local direction = (target - origin).Unit
	local midpoint = origin + direction * (distance / 2)

	tracer.Size = Vector3.new(0.1, 0.1, math.min(distance, 50))
	tracer.CFrame = CFrame.new(midpoint, target)
	tracer.Parent = workspace

	-- Animate tracer
	local tween = TweenService:Create(tracer, TweenInfo.new(0.1, Enum.EasingStyle.Linear), {
		Transparency = 1,
	})
	tween:Play()

	-- Return to pool
	task.delay(0.15, function()
		tracer.Parent = nil
		tracer.Transparency = 0.3
	end)
end

--[[
	Create impact effect at hit position
	@param position Hit position
	@param normal Surface normal
	@param material Surface material
]]
function WeaponEffects.ImpactEffect(position: Vector3, normal: Vector3, material: Enum.Material)
	local impact = getFromPool(impactPool)
	if not impact then
		return
	end

	-- Color based on material
	local color = Color3.fromRGB(200, 200, 200) -- Default

	if material == Enum.Material.Metal or material == Enum.Material.DiamondPlate then
		color = Color3.fromRGB(255, 200, 100) -- Sparks
	elseif material == Enum.Material.Grass or material == Enum.Material.LeafyGrass then
		color = Color3.fromRGB(100, 150, 100) -- Dirt
	elseif material == Enum.Material.Concrete or material == Enum.Material.Brick then
		color = Color3.fromRGB(180, 180, 180) -- Dust
	elseif material == Enum.Material.Wood or material == Enum.Material.WoodPlanks then
		color = Color3.fromRGB(150, 100, 50) -- Splinters
	end

	impact.Color = color
	impact.Position = position
	impact.Parent = workspace

	-- Animate
	local tween = TweenService:Create(impact, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(1, 1, 1),
		Transparency = 1,
	})
	tween:Play()

	-- Return to pool
	task.delay(0.35, function()
		impact.Parent = nil
		impact.Size = Vector3.new(0.3, 0.3, 0.3)
		impact.Transparency = 0.5
	end)
end

--[[
	Eject shell casing
	@param origin Ejection origin
	@param weaponType The weapon type
]]
function WeaponEffects.ShellCasing(origin: Vector3, weaponType: string)
	local shell = getFromPool(shellPool)
	if not shell then
		return
	end

	-- Size based on weapon type
	if weaponType == "Shotgun" then
		shell.Size = Vector3.new(0.2, 0.2, 0.5)
		shell.Color = Color3.fromRGB(200, 50, 50) -- Red shell
	elseif weaponType == "Sniper" then
		shell.Size = Vector3.new(0.15, 0.15, 0.6)
	else
		shell.Size = Vector3.new(0.1, 0.1, 0.3)
	end

	shell.Position = origin
	shell.Anchored = false
	shell.Parent = workspace

	-- Apply ejection velocity
	local ejectDirection = Vector3.new(math.random() - 0.5, 1, math.random() - 0.5).Unit
	shell.AssemblyLinearVelocity = ejectDirection * 10

	-- Return to pool after landing
	task.delay(2, function()
		shell.Anchored = true
		shell.Parent = nil
	end)
end

--[[
	Show hit marker
	@param isHeadshot Whether this was a headshot
]]
function WeaponEffects.HitMarker(isHeadshot: boolean)
	if not hitMarkerImage then
		return
	end

	-- Set color
	local color = isHeadshot and Color3.fromRGB(255, 200, 50) or Color3.new(1, 1, 1)

	for _, child in ipairs(hitMarkerImage:GetChildren()) do
		if child:IsA("Frame") then
			child.BackgroundColor3 = color
			child.BackgroundTransparency = 0
		end
	end

	-- Scale animation
	hitMarkerImage.Size = UDim2.fromOffset(60, 60)

	local tween = TweenService:Create(
		hitMarkerImage,
		TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Size = UDim2.fromOffset(50, 50),
		}
	)
	tween:Play()

	-- Fade out
	task.delay(0.1, function()
		for _, child in ipairs(hitMarkerImage:GetChildren()) do
			if child:IsA("Frame") then
				local fadeTween =
					TweenService:Create(child, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						BackgroundTransparency = 1,
					})
				fadeTween:Play()
			end
		end
	end)
end

--[[
	Show floating damage number
	@param worldPosition Position in world
	@param damage Damage amount
	@param isCritical Whether this was critical damage
]]
function WeaponEffects.DamageNumber(worldPosition: Vector3, damage: number, isCritical: boolean)
	local playerGui = localPlayer:WaitForChild("PlayerGui") :: PlayerGui

	-- Create billboard
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(100, 50)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 100

	-- Create anchor part (invisible)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Position = worldPosition
	anchor.Parent = workspace

	billboard.Adornee = anchor
	billboard.Parent = playerGui

	-- Create text
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = tostring(math.floor(damage))
	text.TextColor3 = isCritical and Color3.fromRGB(255, 200, 50) or Color3.new(1, 1, 1)
	text.TextSize = isCritical and 28 or 24
	text.Font = Enum.Font.GothamBold
	text.TextStrokeTransparency = 0.5
	text.Parent = billboard

	-- Animate float up and fade
	local startPos = worldPosition
	local endPos = startPos + Vector3.new(0, 3, 0)

	task.spawn(function()
		for i = 0, 1, 0.05 do
			anchor.Position = startPos:Lerp(endPos, i)
			text.TextTransparency = i * 0.8
			text.TextStrokeTransparency = 0.5 + i * 0.5
			task.wait(0.02)
		end

		billboard:Destroy()
		anchor:Destroy()
	end)
end

--[[
	Apply camera recoil
	@param weapon The weapon that fired
]]
function WeaponEffects.ApplyRecoil(weapon: WeaponInstance)
	-- Get recoil from weapon (would need method added to weapon classes)
	local vertical = 0.5
	local horizontal = (math.random() - 0.5) * 0.2

	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	-- Apply recoil rotation
	local currentCFrame = camera.CFrame
	local recoilCFrame = CFrame.Angles(-math.rad(vertical), math.rad(horizontal), 0)
	camera.CFrame = currentCFrame * recoilCFrame
end

--[[
	Play weapon fire sound
	@param weapon The weapon that fired
]]
function WeaponEffects.PlayFireSound(weapon: WeaponInstance)
	-- Would use actual sound IDs
	local sound = Instance.new("Sound")
	sound.Volume = 0.5
	sound.RollOffMode = Enum.RollOffMode.Linear
	sound.RollOffMinDistance = 10
	sound.RollOffMaxDistance = 200

	-- Different sounds per weapon category
	local category = weapon.definition.category
	-- sound.SoundId = SoundData.GetFireSound(category)

	local character = localPlayer.Character
	if character then
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			sound.Parent = rootPart
			sound:Play()
			Debris:AddItem(sound, 2)
		end
	end
end

--[[
	Play reload sound
	@param weapon The weapon being reloaded
]]
function WeaponEffects.PlayReloadSound(weapon: WeaponInstance)
	local sound = Instance.new("Sound")
	sound.Volume = 0.3

	local character = localPlayer.Character
	if character then
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			sound.Parent = rootPart
			sound:Play()
			Debris:AddItem(sound, weapon.stats.reloadTime + 0.5)
		end
	end
end

--[[
	Cleanup effects system
]]
function WeaponEffects.Cleanup()
	-- Clear pools
	for _, tracer in ipairs(tracerPool) do
		tracer:Destroy()
	end
	tracerPool = {}

	for _, impact in ipairs(impactPool) do
		impact:Destroy()
	end
	impactPool = {}

	for _, shell in ipairs(shellPool) do
		shell:Destroy()
	end
	shellPool = {}

	-- Destroy UI
	if hitMarkerGui then
		hitMarkerGui:Destroy()
		hitMarkerGui = nil
	end
end

return WeaponEffects
