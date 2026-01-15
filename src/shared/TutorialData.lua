--!strict
--[[
	TutorialData.lua
	================
	Tutorial stages and tips configuration
	Based on GDD Section 10: Tutorial & Onboarding
]]

export type TutorialStage = {
	id: string,
	name: string,
	description: string,
	duration: number, -- Estimated minutes
	objectives: { string },
	rewards: { string }?,
}

export type ContextTip = {
	id: string,
	trigger: string,
	message: string,
	showCount: number, -- How many times to show
	priority: number,
}

local TutorialData = {}

-- Tutorial stages for new players
TutorialData.Stages = {
	{
		id = "Movement",
		name = "Movement Basics",
		description = "Learn to navigate the island",
		duration = 2,
		objectives = {
			"Walk forward using W or joystick",
			"Sprint by holding Shift",
			"Jump with Space",
			"Crouch with Ctrl or C",
			"Go prone with Z",
		},
	},
	{
		id = "Looting",
		name = "Looting & Inventory",
		description = "Gear up for survival",
		duration = 3,
		objectives = {
			"Pick up a weapon with E",
			"Open inventory with Tab",
			"Equip items to weapon slots",
			"Pick up healing items",
			"Understand ammo types",
		},
	},
	{
		id = "Combat",
		name = "Combat Training",
		description = "Master your weapons",
		duration = 4,
		objectives = {
			"Fire your weapon with Left Mouse",
			"Aim down sights with Right Mouse",
			"Reload with R",
			"Land a headshot on a target",
			"Switch weapons with 1-5 keys",
		},
	},
	{
		id = "Dinosaurs",
		name = "Dinosaur Encounters",
		description = "Survive prehistoric threats",
		duration = 3,
		objectives = {
			"Identify different dinosaur types",
			"Understand threat levels",
			"Use Dino Repellent to create safe zone",
			"Use Meat Bait to lure dinosaurs",
			"Crouch to reduce detection",
		},
	},
	{
		id = "Vehicles",
		name = "Vehicle Basics",
		description = "Master island transportation",
		duration = 2,
		objectives = {
			"Enter a vehicle with E",
			"Drive using WASD",
			"Exit the vehicle",
			"Understand vehicle types",
		},
	},
	{
		id = "Storm",
		name = "Storm Survival",
		description = "Stay inside the safe zone",
		duration = 2,
		objectives = {
			"Open the map with M",
			"Identify the safe zone",
			"Understand storm timing",
			"Practice rotating to safety",
		},
	},
	{
		id = "Practice",
		name = "Practice Match",
		description = "Put it all together",
		duration = 5,
		objectives = {
			"Drop from the helicopter",
			"Loot weapons and supplies",
			"Survive against bot players",
			"Reach Top 10",
		},
		rewards = {
			"Skin_TutorialGrad",
			"XPBoost_100",
		},
	},
}

-- Context-sensitive tips shown during first matches
TutorialData.ContextTips = {
	{
		id = "FirstLanding",
		trigger = "PlayerLanded",
		message = "Press E to pick up weapons and items quickly!",
		showCount = 3,
		priority = 1,
	},
	{
		id = "LowHealth",
		trigger = "HealthBelow50",
		message = "Use bandages or Med Kits to heal. Open inventory with TAB.",
		showCount = 5,
		priority = 2,
	},
	{
		id = "NearDinosaur",
		trigger = "DinosaurNearby",
		message = "Crouch to reduce detection! Dinosaurs hunt by sight and sound.",
		showCount = 5,
		priority = 1,
	},
	{
		id = "StormApproaching",
		trigger = "StormWarning",
		message = "The Extinction Wave is coming! Check your map (M) for safe zones.",
		showCount = 5,
		priority = 1,
	},
	{
		id = "FirstElimination",
		trigger = "PlayerGotKill",
		message = "Great shot! Eliminated players drop all their loot.",
		showCount = 1,
		priority = 3,
	},
	{
		id = "DownedInDuos",
		trigger = "PlayerDowned",
		message = "Your teammate can revive you! Crawl to safety.",
		showCount = 3,
		priority = 1,
	},
	{
		id = "FoundVehicle",
		trigger = "NearVehicle",
		message = "Press E to enter vehicles. They make noise that attracts dinosaurs!",
		showCount = 3,
		priority = 2,
	},
	{
		id = "RareLoot",
		trigger = "FoundEpicOrHigher",
		message = "Purple and Gold items are powerful! Manage inventory space wisely.",
		showCount = 3,
		priority = 3,
	},
	{
		id = "RaptorNearby",
		trigger = "RaptorDetected",
		message = "Raptors hunt in packs. If you see one, others are close!",
		showCount = 3,
		priority = 1,
	},
	{
		id = "Top10",
		trigger = "ReachedTop10",
		message = "You made Top 10! Play carefully - the circle is small now.",
		showCount = 3,
		priority = 2,
	},
	{
		id = "InStorm",
		trigger = "TakingStormDamage",
		message = "You're in the storm! Check your map and run to the safe zone.",
		showCount = 3,
		priority = 1,
	},
	{
		id = "NoWeapon",
		trigger = "NoWeaponEquipped",
		message = "You need a weapon! Look for loot in buildings and chests.",
		showCount = 2,
		priority = 1,
	},
	{
		id = "LowAmmo",
		trigger = "AmmoBelow10",
		message = "Low on ammo! Look for ammo boxes or eliminate players for more.",
		showCount = 5,
		priority = 2,
	},
	{
		id = "ShieldAvailable",
		trigger = "HasShieldItem",
		message = "Use Shield Potions to add extra protection beyond health.",
		showCount = 2,
		priority = 3,
	},
	{
		id = "BossSpawned",
		trigger = "BossEvent",
		message = "A powerful dinosaur has appeared! Defeat it for legendary loot.",
		showCount = 3,
		priority = 1,
	},
}

-- Training grounds configuration
TutorialData.TrainingGrounds = {
	weaponRange = {
		name = "Weapon Range",
		description = "Test all weapons at all rarities",
		features = { "Target practice", "Damage comparison", "Recoil testing" },
	},
	targetPractice = {
		name = "Target Practice",
		description = "Improve your aim",
		features = { "Stationary targets", "Moving targets", "Hit tracking" },
	},
	dinoArena = {
		name = "Dino Arena",
		description = "Practice dinosaur encounters",
		features = { "Spawn any dinosaur", "Practice combat", "Test equipment" },
	},
	vehicleCourse = {
		name = "Vehicle Course",
		description = "Master all vehicles",
		features = { "Test all vehicles", "Obstacle course", "Time trials" },
	},
	privateDuels = {
		name = "Private Duels",
		description = "Practice with friends",
		features = { "1v1 matches", "Custom settings", "No stakes" },
	},
}

-- Get stage by ID
function TutorialData.GetStage(stageId: string): TutorialStage?
	for _, stage in ipairs(TutorialData.Stages) do
		if stage.id == stageId then
			return stage
		end
	end
	return nil
end

-- Get tip by trigger
function TutorialData.GetTipByTrigger(trigger: string): ContextTip?
	for _, tip in ipairs(TutorialData.ContextTips) do
		if tip.trigger == trigger then
			return tip
		end
	end
	return nil
end

-- Get all tips for a trigger (multiple may match)
function TutorialData.GetTipsForTrigger(trigger: string): { ContextTip }
	local result = {}
	for _, tip in ipairs(TutorialData.ContextTips) do
		if tip.trigger == trigger then
			table.insert(result, tip)
		end
	end
	table.sort(result, function(a, b)
		return a.priority < b.priority
	end)
	return result
end

-- Get total tutorial duration
function TutorialData.GetTotalDuration(): number
	local total = 0
	for _, stage in ipairs(TutorialData.Stages) do
		total = total + stage.duration
	end
	return total
end

return TutorialData
