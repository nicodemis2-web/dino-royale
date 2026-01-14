--!strict
--[[
	BehaviorTree.lua
	================
	Simple behavior tree implementation for dinosaur AI
	Supports Selector, Sequence, Decorator, and Leaf nodes
]]

local BehaviorTree = {}

-- Status enum
export type Status = "Success" | "Failure" | "Running"

-- AI Context passed to all nodes
export type AIContext = {
	dinosaur: any, -- DinosaurBase instance
	dt: number,
	target: Player?,
	lastTargetPosition: Vector3?,
	alertLevel: number,
	customData: { [string]: any },
}

-- Base node interface
export type Node = {
	Run: (self: Node, context: AIContext) -> Status,
	Reset: ((self: Node) -> ())?,
	name: string?,
}

--[[
	====================
	NODE IMPLEMENTATIONS
	====================
]]

--[[
	Selector Node
	Tries children in order until one succeeds
]]
local SelectorNode = {}
SelectorNode.__index = SelectorNode

function BehaviorTree.Selector(children: { Node }, name: string?): Node
	local self = setmetatable({}, SelectorNode)
	self.children = children
	self.name = name or "Selector"
	self.runningIndex = 0
	return self :: any
end

function SelectorNode:Run(context: AIContext): Status
	-- Continue from running child if any
	local startIndex = self.runningIndex > 0 and self.runningIndex or 1

	for i = startIndex, #self.children do
		local child = self.children[i]
		local status = child:Run(context)

		if status == "Running" then
			self.runningIndex = i
			return "Running"
		elseif status == "Success" then
			self.runningIndex = 0
			return "Success"
		end
		-- Failure continues to next child
	end

	self.runningIndex = 0
	return "Failure"
end

function SelectorNode:Reset()
	self.runningIndex = 0
	for _, child in ipairs(self.children) do
		if child.Reset then
			child:Reset()
		end
	end
end

--[[
	Sequence Node
	Runs children in order until one fails
]]
local SequenceNode = {}
SequenceNode.__index = SequenceNode

function BehaviorTree.Sequence(children: { Node }, name: string?): Node
	local self = setmetatable({}, SequenceNode)
	self.children = children
	self.name = name or "Sequence"
	self.runningIndex = 0
	return self :: any
end

function SequenceNode:Run(context: AIContext): Status
	-- Continue from running child if any
	local startIndex = self.runningIndex > 0 and self.runningIndex or 1

	for i = startIndex, #self.children do
		local child = self.children[i]
		local status = child:Run(context)

		if status == "Running" then
			self.runningIndex = i
			return "Running"
		elseif status == "Failure" then
			self.runningIndex = 0
			return "Failure"
		end
		-- Success continues to next child
	end

	self.runningIndex = 0
	return "Success"
end

function SequenceNode:Reset()
	self.runningIndex = 0
	for _, child in ipairs(self.children) do
		if child.Reset then
			child:Reset()
		end
	end
end

--[[
	Decorator Nodes
	Modify child behavior
]]

-- Inverter: Flips Success/Failure
local InverterNode = {}
InverterNode.__index = InverterNode

function BehaviorTree.Inverter(child: Node, name: string?): Node
	local self = setmetatable({}, InverterNode)
	self.child = child
	self.name = name or "Inverter"
	return self :: any
end

function InverterNode:Run(context: AIContext): Status
	local status = self.child:Run(context)
	if status == "Success" then
		return "Failure"
	elseif status == "Failure" then
		return "Success"
	end
	return "Running"
end

function InverterNode:Reset()
	if self.child.Reset then
		self.child:Reset()
	end
end

-- Repeater: Repeats child N times (or infinitely if count is 0)
local RepeaterNode = {}
RepeaterNode.__index = RepeaterNode

function BehaviorTree.Repeater(child: Node, count: number, name: string?): Node
	local self = setmetatable({}, RepeaterNode)
	self.child = child
	self.maxCount = count
	self.currentCount = 0
	self.name = name or "Repeater"
	return self :: any
end

function RepeaterNode:Run(context: AIContext): Status
	local status = self.child:Run(context)

	if status == "Running" then
		return "Running"
	end

	self.currentCount = self.currentCount + 1

	-- Reset child for next iteration
	if self.child.Reset then
		self.child:Reset()
	end

	-- Check if we've hit max count
	if self.maxCount > 0 and self.currentCount >= self.maxCount then
		self.currentCount = 0
		return "Success"
	end

	return "Running" -- Keep repeating
end

function RepeaterNode:Reset()
	self.currentCount = 0
	if self.child.Reset then
		self.child:Reset()
	end
end

-- Succeeder: Always returns Success
local SucceederNode = {}
SucceederNode.__index = SucceederNode

function BehaviorTree.Succeeder(child: Node, name: string?): Node
	local self = setmetatable({}, SucceederNode)
	self.child = child
	self.name = name or "Succeeder"
	return self :: any
end

function SucceederNode:Run(context: AIContext): Status
	local status = self.child:Run(context)
	if status == "Running" then
		return "Running"
	end
	return "Success"
end

function SucceederNode:Reset()
	if self.child.Reset then
		self.child:Reset()
	end
end

-- UntilFail: Repeats until child fails
local UntilFailNode = {}
UntilFailNode.__index = UntilFailNode

function BehaviorTree.UntilFail(child: Node, name: string?): Node
	local self = setmetatable({}, UntilFailNode)
	self.child = child
	self.name = name or "UntilFail"
	return self :: any
end

function UntilFailNode:Run(context: AIContext): Status
	local status = self.child:Run(context)

	if status == "Failure" then
		return "Success"
	elseif status == "Running" then
		return "Running"
	end

	-- Success - reset and continue
	if self.child.Reset then
		self.child:Reset()
	end
	return "Running"
end

function UntilFailNode:Reset()
	if self.child.Reset then
		self.child:Reset()
	end
end

--[[
	Leaf Nodes
	Actual actions and conditions
]]

-- Condition: Check a condition function
local ConditionNode = {}
ConditionNode.__index = ConditionNode

function BehaviorTree.Condition(checkFn: (context: AIContext) -> boolean, name: string?): Node
	local self = setmetatable({}, ConditionNode)
	self.checkFn = checkFn
	self.name = name or "Condition"
	return self :: any
end

function ConditionNode:Run(context: AIContext): Status
	if self.checkFn(context) then
		return "Success"
	end
	return "Failure"
end

-- Action: Execute an action function
local ActionNode = {}
ActionNode.__index = ActionNode

function BehaviorTree.Action(actionFn: (context: AIContext) -> Status, name: string?): Node
	local self = setmetatable({}, ActionNode)
	self.actionFn = actionFn
	self.name = name or "Action"
	return self :: any
end

function ActionNode:Run(context: AIContext): Status
	return self.actionFn(context)
end

-- Wait: Wait for specified duration
local WaitNode = {}
WaitNode.__index = WaitNode

function BehaviorTree.Wait(seconds: number, name: string?): Node
	local self = setmetatable({}, WaitNode)
	self.duration = seconds
	self.elapsed = 0
	self.name = name or "Wait"
	return self :: any
end

function WaitNode:Run(context: AIContext): Status
	self.elapsed = self.elapsed + context.dt

	if self.elapsed >= self.duration then
		self.elapsed = 0
		return "Success"
	end

	return "Running"
end

function WaitNode:Reset()
	self.elapsed = 0
end

-- RandomSelector: Randomly picks one child to run
local RandomSelectorNode = {}
RandomSelectorNode.__index = RandomSelectorNode

function BehaviorTree.RandomSelector(children: { Node }, name: string?): Node
	local self = setmetatable({}, RandomSelectorNode)
	self.children = children
	self.selectedIndex = 0
	self.name = name or "RandomSelector"
	return self :: any
end

function RandomSelectorNode:Run(context: AIContext): Status
	if self.selectedIndex == 0 then
		self.selectedIndex = math.random(1, #self.children)
	end

	local status = self.children[self.selectedIndex]:Run(context)

	if status ~= "Running" then
		self.selectedIndex = 0
	end

	return status
end

function RandomSelectorNode:Reset()
	self.selectedIndex = 0
	for _, child in ipairs(self.children) do
		if child.Reset then
			child:Reset()
		end
	end
end

-- Parallel: Runs all children simultaneously
local ParallelNode = {}
ParallelNode.__index = ParallelNode

function BehaviorTree.Parallel(children: { Node }, successThreshold: number?, name: string?): Node
	local self = setmetatable({}, ParallelNode)
	self.children = children
	self.successThreshold = successThreshold or #children -- All must succeed by default
	self.name = name or "Parallel"
	return self :: any
end

function ParallelNode:Run(context: AIContext): Status
	local successCount = 0
	local failureCount = 0
	local runningCount = 0

	for _, child in ipairs(self.children) do
		local status = child:Run(context)

		if status == "Success" then
			successCount = successCount + 1
		elseif status == "Failure" then
			failureCount = failureCount + 1
		else
			runningCount = runningCount + 1
		end
	end

	-- Check success threshold
	if successCount >= self.successThreshold then
		return "Success"
	end

	-- Check if success is still possible
	local maxPossibleSuccess = successCount + runningCount
	if maxPossibleSuccess < self.successThreshold then
		return "Failure"
	end

	return "Running"
end

function ParallelNode:Reset()
	for _, child in ipairs(self.children) do
		if child.Reset then
			child:Reset()
		end
	end
end

--[[
	====================
	BEHAVIOR TREE CLASS
	====================
]]

export type BehaviorTreeInstance = {
	root: Node,
	context: AIContext,
	Run: (self: BehaviorTreeInstance, dt: number) -> Status,
	Reset: (self: BehaviorTreeInstance) -> (),
	SetTarget: (self: BehaviorTreeInstance, target: Player?) -> (),
}

local BehaviorTreeClass = {}
BehaviorTreeClass.__index = BehaviorTreeClass

--[[
	Create a new behavior tree
	@param root The root node of the tree
	@param dinosaur The dinosaur this tree controls
]]
function BehaviorTree.new(root: Node, dinosaur: any): BehaviorTreeInstance
	local self = setmetatable({}, BehaviorTreeClass)

	self.root = root
	self.context = {
		dinosaur = dinosaur,
		dt = 0,
		target = nil,
		lastTargetPosition = nil,
		alertLevel = 0,
		customData = {},
	} :: AIContext

	return self :: any
end

--[[
	Run the behavior tree
	@param dt Delta time
	@return Status of the root node
]]
function BehaviorTreeClass:Run(dt: number): Status
	self.context.dt = dt
	return self.root:Run(self.context)
end

--[[
	Reset the behavior tree
]]
function BehaviorTreeClass:Reset()
	if self.root.Reset then
		self.root:Reset()
	end
	self.context.alertLevel = 0
	self.context.customData = {}
end

--[[
	Set the current target
	@param target Target player or nil
]]
function BehaviorTreeClass:SetTarget(target: Player?)
	self.context.target = target
	if target and target.Character then
		local rootPart = target.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if rootPart then
			self.context.lastTargetPosition = rootPart.Position
		end
	end
end

return BehaviorTree
