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
	Play muzzle flash effect with enhanced visuals
	@param weaponModel The weapon model (optional)
	@param weaponType The weapon type/category
]]
function WeaponEffects.MuzzleFlash(weaponModel: Model?, weaponType: string)
	-- Find muzzle position from character
	local character = localPlayer.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then return end

	local camera = workspace.CurrentCamera
	if not camera then return end

	-- Calculate muzzle position (in front of camera)
	local muzzleOffset = Vector3.new(0.3, -0.2, -2) -- Right, down, forward
	local muzzlePosition = camera.CFrame:PointToWorldSpace(muzzleOffset)

	-- Flash intensity based on weapon type
	local flashIntensity = 3
	local flashRange = 10
	local flashDuration = 0.05

	if weaponType == "Shotgun" then
		flashIntensity = 5
		flashRange = 15
		flashDuration = 0.08
	elseif weaponType == "Sniper" then
		flashIntensity = 4
		flashRange = 12
		flashDuration = 0.06
	elseif weaponType == "SMG" or weaponType == "Pistol" then
		flashIntensity = 2
		flashRange = 8
		flashDuration = 0.04
	end

	-- Create flash light
	local flash = Instance.new("PointLight")
	flash.Brightness = flashIntensity
	flash.Range = flashRange
	flash.Color = Color3.fromRGB(255, 200, 100)
	flash.Parent = rootPart

	-- Create muzzle flash part (visual cone)
	local flashPart = Instance.new("Part")
	flashPart.Name = "MuzzleFlash"
	flashPart.Anchored = true
	flashPart.CanCollide = false
	flashPart.CanQuery = false
	flashPart.Size = Vector3.new(0.3, 0.3, 0.5)
	flashPart.Material = Enum.Material.Neon
	flashPart.Color = Color3.fromRGB(255, 180, 50)
	flashPart.Transparency = 0.3
	flashPart.CFrame = CFrame.new(muzzlePosition, muzzlePosition + camera.CFrame.LookVector)
	flashPart.Parent = workspace

	-- Add sparkle effect
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 200, 100))
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparkles.Lifetime = NumberRange.new(0.05, 0.1)
	sparkles.Rate = 0 -- Will emit manually
	sparkles.Speed = NumberRange.new(10, 20)
	sparkles.SpreadAngle = Vector2.new(30, 30)
	sparkles.Parent = flashPart
	sparkles:Emit(weaponType == "Shotgun" and 15 or 8)

	-- Quick flash cleanup
	Debris:AddItem(flash, flashDuration)
	Debris:AddItem(flashPart, flashDuration * 2)
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
	Eject shell casing with realistic physics
	@param origin Ejection origin
	@param weaponType The weapon type
]]
function WeaponEffects.ShellCasing(origin: Vector3, weaponType: string)
	local shell = getFromPool(shellPool)
	if not shell then
		return
	end

	local camera = workspace.CurrentCamera
	if not camera then return end

	-- Calculate ejection position (to the right of camera view)
	local ejectionOffset = Vector3.new(0.4, -0.1, -0.5) -- Right, slightly down, forward
	local ejectionPos = camera.CFrame:PointToWorldSpace(ejectionOffset)

	-- Size and color based on weapon type
	if weaponType == "Shotgun" then
		shell.Size = Vector3.new(0.2, 0.2, 0.6)
		shell.Color = Color3.fromRGB(200, 50, 50) -- Red shotgun shell
		shell.Material = Enum.Material.Plastic
	elseif weaponType == "Sniper" then
		shell.Size = Vector3.new(0.12, 0.12, 0.8)
		shell.Color = Color3.fromRGB(180, 150, 80) -- Large brass casing
	elseif weaponType == "AssaultRifle" or weaponType == "DMR" then
		shell.Size = Vector3.new(0.08, 0.08, 0.4)
		shell.Color = Color3.fromRGB(200, 170, 100) -- Standard brass
	elseif weaponType == "SMG" or weaponType == "Pistol" then
		shell.Size = Vector3.new(0.06, 0.06, 0.25)
		shell.Color = Color3.fromRGB(200, 170, 100) -- Small brass
	else
		shell.Size = Vector3.new(0.1, 0.1, 0.3)
		shell.Color = Color3.fromRGB(200, 170, 100)
	end

	-- Set position and enable physics
	shell.Position = ejectionPos
	shell.Anchored = false
	shell.Parent = workspace

	-- Calculate ejection direction (right and up relative to camera)
	local rightVector = camera.CFrame.RightVector
	local upVector = camera.CFrame.UpVector
	local backVector = -camera.CFrame.LookVector

	-- Add randomness to ejection
	local randomAngle = math.random() * 0.3 - 0.15
	local ejectDirection = (rightVector + upVector * 0.5 + backVector * 0.2).Unit
	ejectDirection = ejectDirection + Vector3.new(randomAngle, math.random() * 0.2, randomAngle)

	-- Apply velocity and spin
	local ejectSpeed = weaponType == "Shotgun" and 8 or 12
	shell.AssemblyLinearVelocity = ejectDirection * ejectSpeed
	shell.AssemblyAngularVelocity = Vector3.new(
		math.random() * 30 - 15,
		math.random() * 30 - 15,
		math.random() * 30 - 15
	)

	-- Play casing sound when it lands (delayed)
	task.delay(0.3, function()
		local clingSound = Instance.new("Sound")
		clingSound.Volume = 0.15
		clingSound.Pitch = 0.8 + math.random() * 0.4
		clingSound.RollOffMinDistance = 5
		clingSound.RollOffMaxDistance = 30
		clingSound.Parent = shell
		clingSound:Play()
		Debris:AddItem(clingSound, 0.5)
	end)

	-- Return to pool after landing
	task.delay(3, function()
		shell.Anchored = true
		shell.AssemblyLinearVelocity = Vector3.zero
		shell.AssemblyAngularVelocity = Vector3.zero
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
