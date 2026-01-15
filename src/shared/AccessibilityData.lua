--!strict
--[[
	AccessibilityData.lua
	=====================
	Accessibility options configuration
	Based on GDD Section 9.3: Accessibility Options
]]

export type AccessibilitySettings = {
	-- Visual
	colorblindMode: string, -- "None", "Deuteranopia", "Protanopia", "Tritanopia"
	highContrastUI: boolean,
	reducedMotion: boolean,
	screenShakeIntensity: number, -- 0-1
	subtitlesEnabled: boolean,
	subtitleSize: string, -- "Small", "Medium", "Large"
	subtitleBackground: boolean,
	uiScale: number, -- 0.75-1.5

	-- Audio
	masterVolume: number,
	musicVolume: number,
	sfxVolume: number,
	voiceVolume: number,
	monoAudio: boolean,
	visualSoundIndicators: boolean, -- Show visual cues for important sounds

	-- Controls
	aimAssist: boolean,
	autoSprint: boolean,
	toggleCrouch: boolean,
	toggleAim: boolean,
	mouseSensitivity: number,
	invertY: boolean,
	controllerVibration: boolean,

	-- Gameplay
	simplifiedCombat: boolean, -- Easier aiming, longer reaction windows
	extendedTimers: boolean, -- More time for item pickups, etc.
	autoPickupItems: boolean,
	pingHighlight: boolean, -- Extra visual emphasis on pings
}

local AccessibilityData = {}

-- Default settings
AccessibilityData.Defaults = {
	-- Visual
	colorblindMode = "None",
	highContrastUI = false,
	reducedMotion = false,
	screenShakeIntensity = 1,
	subtitlesEnabled = true,
	subtitleSize = "Medium",
	subtitleBackground = true,
	uiScale = 1,

	-- Audio
	masterVolume = 1,
	musicVolume = 0.7,
	sfxVolume = 1,
	voiceVolume = 1,
	monoAudio = false,
	visualSoundIndicators = false,

	-- Controls
	aimAssist = true,
	autoSprint = false,
	toggleCrouch = false,
	toggleAim = false,
	mouseSensitivity = 0.5,
	invertY = false,
	controllerVibration = true,

	-- Gameplay
	simplifiedCombat = false,
	extendedTimers = false,
	autoPickupItems = false,
	pingHighlight = true,
}

-- Colorblind modes
AccessibilityData.ColorblindModes = {
	"None",
	"Deuteranopia", -- Red-green (most common)
	"Protanopia", -- Red-green
	"Tritanopia", -- Blue-yellow
}

-- Colorblind correction matrices (simplified for UI coloring)
AccessibilityData.ColorblindCorrections = {
	None = {
		enemy = Color3.fromRGB(255, 80, 80),
		friendly = Color3.fromRGB(80, 200, 80),
		legendary = Color3.fromRGB(255, 200, 50),
		epic = Color3.fromRGB(200, 100, 255),
		rare = Color3.fromRGB(80, 150, 255),
		uncommon = Color3.fromRGB(80, 200, 80),
		common = Color3.fromRGB(180, 180, 180),
	},
	Deuteranopia = {
		enemy = Color3.fromRGB(255, 150, 50), -- Orange instead of red
		friendly = Color3.fromRGB(80, 150, 255), -- Blue instead of green
		legendary = Color3.fromRGB(255, 200, 50),
		epic = Color3.fromRGB(200, 100, 255),
		rare = Color3.fromRGB(80, 150, 255),
		uncommon = Color3.fromRGB(80, 150, 255),
		common = Color3.fromRGB(180, 180, 180),
	},
	Protanopia = {
		enemy = Color3.fromRGB(255, 200, 50), -- Yellow instead of red
		friendly = Color3.fromRGB(80, 200, 255), -- Cyan instead of green
		legendary = Color3.fromRGB(255, 200, 50),
		epic = Color3.fromRGB(200, 100, 255),
		rare = Color3.fromRGB(80, 150, 255),
		uncommon = Color3.fromRGB(80, 200, 255),
		common = Color3.fromRGB(180, 180, 180),
	},
	Tritanopia = {
		enemy = Color3.fromRGB(255, 100, 150), -- Pink instead of red
		friendly = Color3.fromRGB(80, 200, 80),
		legendary = Color3.fromRGB(255, 180, 100),
		epic = Color3.fromRGB(255, 100, 150),
		rare = Color3.fromRGB(100, 200, 180),
		uncommon = Color3.fromRGB(80, 200, 80),
		common = Color3.fromRGB(180, 180, 180),
	},
}

-- Subtitle sizes
AccessibilityData.SubtitleSizes = {
	Small = 14,
	Medium = 18,
	Large = 24,
}

-- UI scale options
AccessibilityData.UIScaleOptions = { 0.75, 0.85, 1, 1.15, 1.25, 1.5 }

-- Settings categories for UI organization
AccessibilityData.Categories = {
	{
		id = "Visual",
		name = "Visual Accessibility",
		settings = {
			{ id = "colorblindMode", name = "Colorblind Mode", type = "dropdown", options = AccessibilityData.ColorblindModes },
			{ id = "highContrastUI", name = "High Contrast UI", type = "toggle" },
			{ id = "reducedMotion", name = "Reduced Motion", type = "toggle" },
			{ id = "screenShakeIntensity", name = "Screen Shake", type = "slider", min = 0, max = 1 },
			{ id = "subtitlesEnabled", name = "Subtitles", type = "toggle" },
			{ id = "subtitleSize", name = "Subtitle Size", type = "dropdown", options = { "Small", "Medium", "Large" } },
			{ id = "subtitleBackground", name = "Subtitle Background", type = "toggle" },
			{ id = "uiScale", name = "UI Scale", type = "slider", min = 0.75, max = 1.5, step = 0.05 },
		},
	},
	{
		id = "Audio",
		name = "Audio Settings",
		settings = {
			{ id = "masterVolume", name = "Master Volume", type = "slider", min = 0, max = 1 },
			{ id = "musicVolume", name = "Music Volume", type = "slider", min = 0, max = 1 },
			{ id = "sfxVolume", name = "Sound Effects", type = "slider", min = 0, max = 1 },
			{ id = "voiceVolume", name = "Voice Volume", type = "slider", min = 0, max = 1 },
			{ id = "monoAudio", name = "Mono Audio", type = "toggle" },
			{ id = "visualSoundIndicators", name = "Visual Sound Indicators", type = "toggle" },
		},
	},
	{
		id = "Controls",
		name = "Controls",
		settings = {
			{ id = "aimAssist", name = "Aim Assist", type = "toggle" },
			{ id = "autoSprint", name = "Auto Sprint", type = "toggle" },
			{ id = "toggleCrouch", name = "Toggle Crouch", type = "toggle" },
			{ id = "toggleAim", name = "Toggle Aim", type = "toggle" },
			{ id = "mouseSensitivity", name = "Mouse Sensitivity", type = "slider", min = 0.1, max = 2, step = 0.05 },
			{ id = "invertY", name = "Invert Y-Axis", type = "toggle" },
			{ id = "controllerVibration", name = "Controller Vibration", type = "toggle" },
		},
	},
	{
		id = "Gameplay",
		name = "Gameplay Assists",
		settings = {
			{ id = "simplifiedCombat", name = "Simplified Combat", type = "toggle" },
			{ id = "extendedTimers", name = "Extended Timers", type = "toggle" },
			{ id = "autoPickupItems", name = "Auto Pickup Items", type = "toggle" },
			{ id = "pingHighlight", name = "Ping Highlight", type = "toggle" },
		},
	},
}

-- Validate settings
function AccessibilityData.Validate(settings: any): AccessibilitySettings
	local validated = table.clone(AccessibilityData.Defaults)

	if type(settings) ~= "table" then
		return validated
	end

	-- Validate each setting
	for key, defaultValue in pairs(AccessibilityData.Defaults) do
		local value = settings[key]
		if value ~= nil then
			local valueType = type(defaultValue)
			if type(value) == valueType then
				if valueType == "number" then
					-- Clamp numeric values
					if key == "uiScale" then
						validated[key] = math.clamp(value, 0.75, 1.5)
					elseif key == "mouseSensitivity" then
						validated[key] = math.clamp(value, 0.1, 2)
					else
						validated[key] = math.clamp(value, 0, 1)
					end
				elseif valueType == "string" then
					-- Validate string options
					if key == "colorblindMode" then
						if table.find(AccessibilityData.ColorblindModes, value) then
							validated[key] = value
						end
					elseif key == "subtitleSize" then
						if table.find({ "Small", "Medium", "Large" }, value) then
							validated[key] = value
						end
					else
						validated[key] = value
					end
				else
					validated[key] = value
				end
			end
		end
	end

	return validated
end

-- Get color for colorblind mode
function AccessibilityData.GetColor(colorKey: string, colorblindMode: string?): Color3
	local mode = colorblindMode or "None"
	local corrections = AccessibilityData.ColorblindCorrections[mode]

	if not corrections then
		corrections = AccessibilityData.ColorblindCorrections.None
	end

	return corrections[colorKey] or Color3.fromRGB(255, 255, 255)
end

-- Get subtitle text size
function AccessibilityData.GetSubtitleSize(sizeKey: string): number
	return AccessibilityData.SubtitleSizes[sizeKey] or 18
end

return AccessibilityData
