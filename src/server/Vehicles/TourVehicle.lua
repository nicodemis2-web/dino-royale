--!strict
--[[
	TourVehicle.lua
	===============
	6-seat tour vehicle that follows rail paths
	Very safe but predictable movement
	Based on GDD Section 6.3: Vehicles
]]

local _ReplicatedStorage = game:GetService("ReplicatedStorage")

local VehicleBase = require(script.Parent.VehicleBase)

local TourVehicle = {}
TourVehicle.__index = TourVehicle
setmetatable(TourVehicle, { __index = VehicleBase })

-- Tour Vehicle stats
TourVehicle.Stats = {
	name = "TourVehicle",
	displayName = "Tour Vehicle",
	description = "Safe automated tour vehicle that follows rail paths through the park",
	vehicleType = "Land",

	-- Capacity
	maxPassengers = 6,
	seatPositions = {
		{ x = -2, y = 2, z = 3 },   -- Driver (can override)
		{ x = 2, y = 2, z = 3 },    -- Front passenger
		{ x = -2, y = 2, z = 0 },   -- Middle left
		{ x = 2, y = 2, z = 0 },    -- Middle right
		{ x = -2, y = 2, z = -3 },  -- Back left
		{ x = 2, y = 2, z = -3 },   -- Back right
	},

	-- Health
	maxHealth = 1000, -- Very durable

	-- Movement
	maxSpeed = 35, -- Medium speed
	acceleration = 8,
	deceleration = 15,
	turnSpeed = 0.3, -- Slow turning (follows rails)

	-- Rail following
	railSpeed = 25, -- Speed when on rails
	offRailSpeedPenalty = 0.5, -- 50% speed off rails

	-- Physics
	mass = 3000,
	groundFriction = 0.9,

	-- Features
	hasHeadlights = true,
	hasRoof = true, -- Protected from aerial attacks
	hasAutoNav = true,
	hasIntercom = true,
}

-- Rail path data
local TOUR_PATHS = {
	MainLoop = {
		name = "Main Tour Loop",
		waypoints = {
			Vector3.new(2000, 50, 2000), -- Visitor Center
			Vector3.new(1700, 45, 1800), -- Raptor Paddock
			Vector3.new(1000, 30, 2000), -- Herbivore Valley
			Vector3.new(800, 35, 2200),  -- Safari Lodge
			Vector3.new(1200, 32, 1800), -- Feeding Station
			Vector3.new(1800, 70, 400),  -- T-Rex Paddock (distant view)
			Vector3.new(2000, 50, 2000), -- Back to start
		},
		isLoop = true,
	},
	CoastalRoute = {
		name = "Coastal Tour",
		waypoints = {
			Vector3.new(2000, 50, 2000), -- Start
			Vector3.new(2000, 10, 3400), -- Harbor
			Vector3.new(1800, 20, 3200), -- Aviary
			Vector3.new(2400, 8, 3500),  -- Beach Resort
			Vector3.new(1600, 15, 3600), -- Lighthouse
			Vector3.new(2000, 50, 2000), -- Return
		},
		isLoop = true,
	},
	ResearchExpress = {
		name = "Research Express",
		waypoints = {
			Vector3.new(2000, 50, 2000), -- Visitor Center
			Vector3.new(2100, 90, 2200), -- Hammond's Villa
			Vector3.new(2400, 40, 1600), -- Main Lab
			Vector3.new(2600, 38, 1500), -- Hatchery
			Vector3.new(2000, 50, 2000), -- Return
		},
		isLoop = true,
	},
}

-- Tour vehicle state
export type TourVehicleState = {
	currentPath: string?,
	currentWaypointIndex: number,
	isOnRails: boolean,
	isAutoMode: boolean,
	isPaused: boolean,
	intercomMessage: string?,
	roofClosed: boolean,
	emergencyStopActive: boolean,
}

--[[
	Create a new Tour Vehicle
]]
function TourVehicle.new(position: Vector3, config: any?): any
	local self = VehicleBase.new(position, TourVehicle.Stats, config)
	setmetatable(self, TourVehicle)

	-- Tour-specific state
	self.tourState = {
		currentPath = nil,
		currentWaypointIndex = 1,
		isOnRails = false,
		isAutoMode = true,
		isPaused = false,
		intercomMessage = nil,
		roofClosed = true,
		emergencyStopActive = false,
	} :: TourVehicleState

	return self
end

--[[
	Start following a tour path
]]
function TourVehicle:StartTour(pathName: string): boolean
	local path = TOUR_PATHS[pathName]
	if not path then
		warn("[TourVehicle] Unknown path: " .. pathName)
		return false
	end

	self.tourState.currentPath = pathName
	self.tourState.currentWaypointIndex = 1
	self.tourState.isOnRails = true
	self.tourState.isAutoMode = true
	self.tourState.isPaused = false

	-- Announce tour start
	self:PlayIntercom(`Welcome aboard! Starting the {path.name}.`)

	return true
end

--[[
	Stop tour and switch to manual control
]]
function TourVehicle:StopTour()
	self.tourState.isOnRails = false
	self.tourState.isAutoMode = false
	self.tourState.currentPath = nil

	self:PlayIntercom("Manual control activated. Please drive safely.")
end

--[[
	Pause/resume tour
]]
function TourVehicle:TogglePause()
	self.tourState.isPaused = not self.tourState.isPaused

	if self.tourState.isPaused then
		self:PlayIntercom("Tour paused. Press the button to continue.")
	else
		self:PlayIntercom("Resuming tour.")
	end
end

--[[
	Emergency stop
]]
function TourVehicle:EmergencyStop()
	self.tourState.emergencyStopActive = true
	self.tourState.isPaused = true
	self.velocity = Vector3.zero

	self:PlayIntercom("EMERGENCY STOP ACTIVATED. Please remain calm.")

	-- Auto-resume after 10 seconds
	task.delay(10, function()
		if self.tourState.emergencyStopActive then
			self.tourState.emergencyStopActive = false
			self.tourState.isPaused = false
			self:PlayIntercom("Emergency stop cleared. Resuming tour.")
		end
	end)
end

--[[
	Play intercom message
]]
function TourVehicle:PlayIntercom(message: string)
	self.tourState.intercomMessage = message

	-- Broadcast to passengers
	for _, passenger in ipairs(self.passengers) do
		if self.onIntercom then
			self.onIntercom(passenger, message)
		end
	end

	-- Clear message after delay
	task.delay(5, function()
		if self.tourState.intercomMessage == message then
			self.tourState.intercomMessage = nil
		end
	end)
end

--[[
	Get current waypoint
]]
function TourVehicle:GetCurrentWaypoint(): Vector3?
	if not self.tourState.currentPath then return nil end

	local path = TOUR_PATHS[self.tourState.currentPath]
	if not path then return nil end

	return path.waypoints[self.tourState.currentWaypointIndex]
end

--[[
	Advance to next waypoint
]]
function TourVehicle:AdvanceWaypoint()
	if not self.tourState.currentPath then return end

	local path = TOUR_PATHS[self.tourState.currentPath]
	if not path then return end

	self.tourState.currentWaypointIndex = self.tourState.currentWaypointIndex + 1

	-- Check if reached end
	if self.tourState.currentWaypointIndex > #path.waypoints then
		if path.isLoop then
			self.tourState.currentWaypointIndex = 1
			self:PlayIntercom("Starting another loop of the tour.")
		else
			self:PlayIntercom("Tour complete. Thank you for riding!")
			self:StopTour()
		end
	else
		-- Announce approaching POI
		local waypoint = path.waypoints[self.tourState.currentWaypointIndex]
		local poiMessage = self:GetPOIMessage(waypoint)
		if poiMessage then
			self:PlayIntercom(poiMessage)
		end
	end
end

--[[
	Get POI announcement message
]]
function TourVehicle:GetPOIMessage(position: Vector3): string?
	-- Simplified POI detection based on position
	local messages = {
		{ pos = Vector3.new(1700, 45, 1800), msg = "Approaching the Raptor Paddock. Please keep hands inside the vehicle." },
		{ pos = Vector3.new(1000, 30, 2000), msg = "Welcome to Herbivore Valley. Watch for Triceratops!" },
		{ pos = Vector3.new(1800, 70, 400), msg = "T-Rex territory ahead. The fence is... mostly intact." },
		{ pos = Vector3.new(2000, 10, 3400), msg = "Arriving at the Harbor. Watch for Pteranodons!" },
		{ pos = Vector3.new(1800, 20, 3200), msg = "The Aviary. Home to our flying reptiles." },
		{ pos = Vector3.new(2400, 40, 1600), msg = "Research Complex. Restricted access beyond this point." },
		{ pos = Vector3.new(2100, 90, 2200), msg = "Hammond's Villa. The founder's residence." },
	}

	for _, entry in ipairs(messages) do
		if (position - entry.pos).Magnitude < 100 then
			return entry.msg
		end
	end

	return nil
end

--[[
	Update auto-navigation
]]
function TourVehicle:UpdateAutoNav(deltaTime: number)
	if not self.tourState.isAutoMode then return end
	if self.tourState.isPaused then return end

	local waypoint = self:GetCurrentWaypoint()
	if not waypoint then return end

	local toWaypoint = waypoint - self.position
	local distance = toWaypoint.Magnitude

	-- Check if reached waypoint
	if distance < 15 then
		self:AdvanceWaypoint()
		return
	end

	-- Navigate toward waypoint
	local direction = toWaypoint.Unit
	local targetSpeed = self.tourState.isOnRails and TourVehicle.Stats.railSpeed or (TourVehicle.Stats.maxSpeed * TourVehicle.Stats.offRailSpeedPenalty)

	-- Smooth acceleration
	local currentSpeed = self.velocity.Magnitude
	local newSpeed = currentSpeed + (targetSpeed - currentSpeed) * deltaTime * 2

	self.velocity = direction * newSpeed

	-- Update position
	self.position = self.position + self.velocity * deltaTime

	-- Update facing
	self.facing = direction
end

--[[
	Override throttle - allows manual override
]]
function TourVehicle:SetThrottle(value: number)
	if value ~= 0 then
		-- Player taking control
		self.tourState.isAutoMode = false
		self.tourState.isOnRails = false

		if self.tourState.currentPath then
			self:PlayIntercom("Manual override detected. Auto-navigation disabled.")
		end
	end

	VehicleBase.SetThrottle(self, value)
end

--[[
	Toggle roof
]]
function TourVehicle:ToggleRoof()
	self.tourState.roofClosed = not self.tourState.roofClosed

	if self.tourState.roofClosed then
		self:PlayIntercom("Roof closed. You are protected from aerial threats.")
	else
		self:PlayIntercom("Roof opened. Watch the skies!")
	end
end

--[[
	Override take damage - very durable
]]
function TourVehicle:TakeDamage(amount: number, source: any?)
	-- Reduced damage due to armored construction
	local reducedAmount = amount * 0.7

	-- Roof provides protection from above
	if self.tourState.roofClosed and source then
		local sourcePos = source.position or source.Position
		if sourcePos and sourcePos.Y > self.position.Y + 5 then
			reducedAmount = reducedAmount * 0.5 -- 50% reduction from aerial
		end
	end

	VehicleBase.TakeDamage(self, reducedAmount, source)

	-- Emergency stop on heavy damage
	if self.health < TourVehicle.Stats.maxHealth * 0.3 then
		self:EmergencyStop()
		self:PlayIntercom("Vehicle damage critical! Initiating emergency stop!")
	end
end

--[[
	Override update
]]
function TourVehicle:Update(deltaTime: number)
	-- Update auto-navigation
	self:UpdateAutoNav(deltaTime)

	-- Base update for physics
	VehicleBase.Update(self, deltaTime)
end

--[[
	Override enter - welcome message
]]
function TourVehicle:Enter(player: any, seatIndex: number?): boolean
	local success = VehicleBase.Enter(self, player, seatIndex)

	if success then
		local passengerCount = #self.passengers

		if passengerCount == 1 then
			self:PlayIntercom("Welcome aboard! Press E to start a tour or take manual control.")
		else
			self:PlayIntercom(`Passenger {passengerCount} of {TourVehicle.Stats.maxPassengers} seated.`)
		end
	end

	return success
end

--[[
	Override exit
]]
function TourVehicle:Exit(player: any)
	VehicleBase.Exit(self, player)

	if #self.passengers == 0 then
		-- Stop tour when empty
		self.tourState.isPaused = true
		self:PlayIntercom("All passengers have exited. Tour paused.")
	end
end

--[[
	Get available tour paths
]]
function TourVehicle.GetAvailablePaths(): { { name: string, displayName: string } }
	local paths = {}
	for pathId, pathData in pairs(TOUR_PATHS) do
		table.insert(paths, {
			name = pathId,
			displayName = pathData.name,
		})
	end
	return paths
end

--[[
	Get display info
]]
function TourVehicle:GetDisplayInfo(): any
	local baseInfo = VehicleBase.GetDisplayInfo(self)
	baseInfo.isOnTour = self.tourState.currentPath ~= nil
	baseInfo.tourPath = self.tourState.currentPath
	baseInfo.isAutoMode = self.tourState.isAutoMode
	baseInfo.isPaused = self.tourState.isPaused
	baseInfo.roofClosed = self.tourState.roofClosed
	baseInfo.intercomMessage = self.tourState.intercomMessage
	return baseInfo
end

return TourVehicle
