--!strict
--[[
	PartyUI.lua
	===========
	Client-side party display and management
	Based on GDD Section 11: Social Features
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Events = require(ReplicatedStorage.Shared.Events)
local PartyData = require(ReplicatedStorage.Shared.PartyData)

local PartyUI = {}

-- State
local player = Players.LocalPlayer
local screenGui: ScreenGui? = nil
local partyFrame: Frame? = nil
local invitePopup: Frame? = nil
local memberFrames: { [number]: Frame } = {}
local currentParty: PartyData.Party? = nil
local pendingInvites: { any } = {}
local isVisible = false

-- Constants
local MEMBER_HEIGHT = 50
local INVITE_DISPLAY_TIME = 60

--[[
	Initialize the party UI
]]
function PartyUI.Initialize()
	print("[PartyUI] Initializing...")

	PartyUI.CreateUI()
	PartyUI.SetupEventListeners()

	-- Request initial data
	Events.FireServer("Party", "RequestData", {})

	print("[PartyUI] Initialized")
end

--[[
	Create UI elements
]]
function PartyUI.CreateUI()
	local playerGui = player:WaitForChild("PlayerGui")

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PartyGui"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	-- Party panel (left side)
	partyFrame = Instance.new("Frame")
	partyFrame.Name = "PartyPanel"
	partyFrame.Size = UDim2.new(0, 220, 0, 280)
	partyFrame.Position = UDim2.new(0, 20, 0.5, -140)
	partyFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	partyFrame.BackgroundTransparency = 0.1
	partyFrame.BorderSizePixel = 0
	partyFrame.Visible = false
	partyFrame.Parent = screenGui

	local partyCorner = Instance.new("UICorner")
	partyCorner.CornerRadius = UDim.new(0, 8)
	partyCorner.Parent = partyFrame

	-- Party header
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 40)
	header.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	header.BorderSizePixel = 0
	header.Parent = partyFrame

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 8)
	headerCorner.Parent = header

	local headerTitle = Instance.new("TextLabel")
	headerTitle.Name = "Title"
	headerTitle.Size = UDim2.new(1, -50, 1, 0)
	headerTitle.Position = UDim2.fromOffset(10, 0)
	headerTitle.BackgroundTransparency = 1
	headerTitle.TextColor3 = Color3.fromRGB(255, 200, 50)
	headerTitle.TextSize = 16
	headerTitle.Font = Enum.Font.GothamBold
	headerTitle.TextXAlignment = Enum.TextXAlignment.Left
	headerTitle.Text = "PARTY"
	headerTitle.Parent = header

	local gameModeLabel = Instance.new("TextLabel")
	gameModeLabel.Name = "GameMode"
	gameModeLabel.Size = UDim2.new(1, -10, 0, 20)
	gameModeLabel.Position = UDim2.new(0, 5, 0, 42)
	gameModeLabel.BackgroundTransparency = 1
	gameModeLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
	gameModeLabel.TextSize = 12
	gameModeLabel.Font = Enum.Font.Gotham
	gameModeLabel.TextXAlignment = Enum.TextXAlignment.Left
	gameModeLabel.Text = "Squads (0/4)"
	gameModeLabel.Parent = partyFrame

	-- Members list
	local membersList = Instance.new("Frame")
	membersList.Name = "MembersList"
	membersList.Size = UDim2.new(1, -10, 0, 160)
	membersList.Position = UDim2.new(0, 5, 0, 65)
	membersList.BackgroundTransparency = 1
	membersList.Parent = partyFrame

	local membersLayout = Instance.new("UIListLayout")
	membersLayout.Padding = UDim.new(0, 5)
	membersLayout.Parent = membersList

	-- Buttons container
	local buttonsFrame = Instance.new("Frame")
	buttonsFrame.Name = "Buttons"
	buttonsFrame.Size = UDim2.new(1, -10, 0, 40)
	buttonsFrame.Position = UDim2.new(0, 5, 1, -50)
	buttonsFrame.BackgroundTransparency = 1
	buttonsFrame.Parent = partyFrame

	local buttonsLayout = Instance.new("UIListLayout")
	buttonsLayout.FillDirection = Enum.FillDirection.Horizontal
	buttonsLayout.Padding = UDim.new(0, 5)
	buttonsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	buttonsLayout.Parent = buttonsFrame

	-- Ready button
	local readyButton = Instance.new("TextButton")
	readyButton.Name = "ReadyButton"
	readyButton.Size = UDim2.new(0, 90, 0, 35)
	readyButton.BackgroundColor3 = Color3.fromRGB(80, 180, 80)
	readyButton.BorderSizePixel = 0
	readyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	readyButton.TextSize = 14
	readyButton.Font = Enum.Font.GothamBold
	readyButton.Text = "Ready"
	readyButton.Parent = buttonsFrame

	local readyCorner = Instance.new("UICorner")
	readyCorner.CornerRadius = UDim.new(0, 6)
	readyCorner.Parent = readyButton

	readyButton.MouseButton1Click:Connect(function()
		PartyUI.ToggleReady()
	end)

	-- Leave button
	local leaveButton = Instance.new("TextButton")
	leaveButton.Name = "LeaveButton"
	leaveButton.Size = UDim2.new(0, 90, 0, 35)
	leaveButton.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
	leaveButton.BorderSizePixel = 0
	leaveButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	leaveButton.TextSize = 14
	leaveButton.Font = Enum.Font.GothamBold
	leaveButton.Text = "Leave"
	leaveButton.Parent = buttonsFrame

	local leaveCorner = Instance.new("UICorner")
	leaveCorner.CornerRadius = UDim.new(0, 6)
	leaveCorner.Parent = leaveButton

	leaveButton.MouseButton1Click:Connect(function()
		PartyUI.LeaveParty()
	end)

	-- Invite popup (appears when receiving invites)
	invitePopup = Instance.new("Frame")
	invitePopup.Name = "InvitePopup"
	invitePopup.Size = UDim2.new(0, 350, 0, 120)
	invitePopup.Position = UDim2.new(0.5, 0, 0, -130)
	invitePopup.AnchorPoint = Vector2.new(0.5, 0)
	invitePopup.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	invitePopup.BorderSizePixel = 0
	invitePopup.Visible = false
	invitePopup.Parent = screenGui

	local inviteCorner = Instance.new("UICorner")
	inviteCorner.CornerRadius = UDim.new(0, 10)
	inviteCorner.Parent = invitePopup

	local inviteTitle = Instance.new("TextLabel")
	inviteTitle.Name = "Title"
	inviteTitle.Size = UDim2.new(1, 0, 0, 30)
	inviteTitle.Position = UDim2.fromOffset(0, 10)
	inviteTitle.BackgroundTransparency = 1
	inviteTitle.TextColor3 = Color3.fromRGB(255, 200, 50)
	inviteTitle.TextSize = 16
	inviteTitle.Font = Enum.Font.GothamBold
	inviteTitle.Text = "Party Invite"
	inviteTitle.Parent = invitePopup

	local inviteDesc = Instance.new("TextLabel")
	inviteDesc.Name = "Description"
	inviteDesc.Size = UDim2.new(1, -20, 0, 30)
	inviteDesc.Position = UDim2.new(0, 10, 0, 40)
	inviteDesc.BackgroundTransparency = 1
	inviteDesc.TextColor3 = Color3.fromRGB(200, 200, 200)
	inviteDesc.TextSize = 14
	inviteDesc.Font = Enum.Font.Gotham
	inviteDesc.TextWrapped = true
	inviteDesc.Text = "PlayerName invited you to play Squads"
	inviteDesc.Parent = invitePopup

	-- Accept button
	local acceptButton = Instance.new("TextButton")
	acceptButton.Name = "AcceptButton"
	acceptButton.Size = UDim2.new(0, 120, 0, 35)
	acceptButton.Position = UDim2.new(0.3, 0, 1, -50)
	acceptButton.AnchorPoint = Vector2.new(0.5, 0)
	acceptButton.BackgroundColor3 = Color3.fromRGB(80, 180, 80)
	acceptButton.BorderSizePixel = 0
	acceptButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	acceptButton.TextSize = 14
	acceptButton.Font = Enum.Font.GothamBold
	acceptButton.Text = "Accept"
	acceptButton.Parent = invitePopup

	local acceptCorner = Instance.new("UICorner")
	acceptCorner.CornerRadius = UDim.new(0, 6)
	acceptCorner.Parent = acceptButton

	acceptButton.MouseButton1Click:Connect(function()
		PartyUI.AcceptInvite()
	end)

	-- Decline button
	local declineButton = Instance.new("TextButton")
	declineButton.Name = "DeclineButton"
	declineButton.Size = UDim2.new(0, 120, 0, 35)
	declineButton.Position = UDim2.new(0.7, 0, 1, -50)
	declineButton.AnchorPoint = Vector2.new(0.5, 0)
	declineButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
	declineButton.BorderSizePixel = 0
	declineButton.TextColor3 = Color3.fromRGB(200, 200, 200)
	declineButton.TextSize = 14
	declineButton.Font = Enum.Font.GothamBold
	declineButton.Text = "Decline"
	declineButton.Parent = invitePopup

	local declineCorner = Instance.new("UICorner")
	declineCorner.CornerRadius = UDim.new(0, 6)
	declineCorner.Parent = declineButton

	declineButton.MouseButton1Click:Connect(function()
		PartyUI.DeclineInvite()
	end)
end

--[[
	Setup event listeners
]]
function PartyUI.SetupEventListeners()
	Events.OnClientEvent("Party", function(action, data)
		if action == "Created" then
			PartyUI.OnPartyCreated(data.party)
		elseif action == "Joined" then
			PartyUI.OnPartyJoined(data.party)
		elseif action == "Left" then
			PartyUI.OnPartyLeft()
		elseif action == "Disbanded" then
			PartyUI.OnPartyDisbanded()
		elseif action == "Kicked" then
			PartyUI.OnPartyKicked()
		elseif action == "MemberJoined" then
			PartyUI.OnMemberJoined(data.member)
		elseif action == "MemberLeft" then
			PartyUI.OnMemberLeft(data.userId)
		elseif action == "MemberKicked" then
			PartyUI.OnMemberLeft(data.userId)
		elseif action == "MemberReady" then
			PartyUI.OnMemberReady(data.userId, data.isReady)
		elseif action == "LeaderChanged" then
			PartyUI.OnLeaderChanged(data.newLeader)
		elseif action == "GameModeChanged" then
			PartyUI.OnGameModeChanged(data.gameMode, data.maxSize)
		elseif action == "DataUpdate" then
			PartyUI.OnDataUpdate(data.party)
		elseif action == "InviteReceived" then
			PartyUI.OnInviteReceived(data)
		elseif action == "InvitesUpdate" then
			PartyUI.OnInvitesUpdate(data.invites)
		elseif action == "InviteSent" then
			print(`[PartyUI] Invite sent to {data.targetName}`)
		elseif action == "InviteDeclined" then
			print(`[PartyUI] {data.targetName} declined your invite`)
		elseif action == "Error" then
			warn(`[PartyUI] Error: {data.message}`)
		end
	end)
end

--[[
	On party created
]]
function PartyUI.OnPartyCreated(party: PartyData.Party)
	currentParty = party
	PartyUI.UpdatePartyDisplay()
	PartyUI.Show()
end

--[[
	On party joined
]]
function PartyUI.OnPartyJoined(party: PartyData.Party)
	currentParty = party
	PartyUI.UpdatePartyDisplay()
	PartyUI.Show()
	PartyUI.HideInvitePopup()
end

--[[
	On party left
]]
function PartyUI.OnPartyLeft()
	currentParty = nil
	PartyUI.ClearMemberFrames()
	PartyUI.Hide()
end

--[[
	On party disbanded
]]
function PartyUI.OnPartyDisbanded()
	currentParty = nil
	PartyUI.ClearMemberFrames()
	PartyUI.Hide()
end

--[[
	On party kicked
]]
function PartyUI.OnPartyKicked()
	currentParty = nil
	PartyUI.ClearMemberFrames()
	PartyUI.Hide()
end

--[[
	On member joined
]]
function PartyUI.OnMemberJoined(member: PartyData.PartyMember)
	if not currentParty then return end
	table.insert(currentParty.members, member)
	PartyUI.UpdatePartyDisplay()
end

--[[
	On member left
]]
function PartyUI.OnMemberLeft(userId: number)
	if not currentParty then return end

	for i, member in ipairs(currentParty.members) do
		if member.userId == userId then
			table.remove(currentParty.members, i)
			break
		end
	end

	PartyUI.UpdatePartyDisplay()
end

--[[
	On member ready state changed
]]
function PartyUI.OnMemberReady(userId: number, isReady: boolean)
	if not currentParty then return end

	for _, member in ipairs(currentParty.members) do
		if member.userId == userId then
			member.isReady = isReady
			break
		end
	end

	PartyUI.UpdateMemberReady(userId, isReady)
end

--[[
	On leader changed
]]
function PartyUI.OnLeaderChanged(newLeader: number)
	if not currentParty then return end

	currentParty.leader = newLeader
	for _, member in ipairs(currentParty.members) do
		member.isLeader = member.userId == newLeader
	end

	PartyUI.UpdatePartyDisplay()
end

--[[
	On game mode changed
]]
function PartyUI.OnGameModeChanged(gameMode: string, maxSize: number)
	if not currentParty then return end

	currentParty.gameMode = gameMode
	currentParty.maxSize = maxSize

	PartyUI.UpdateGameModeLabel()
end

--[[
	On data update
]]
function PartyUI.OnDataUpdate(party: PartyData.Party?)
	currentParty = party

	if party then
		PartyUI.UpdatePartyDisplay()
		PartyUI.Show()
	else
		PartyUI.ClearMemberFrames()
		PartyUI.Hide()
	end
end

--[[
	On invite received
]]
function PartyUI.OnInviteReceived(data: any)
	table.insert(pendingInvites, data)
	PartyUI.ShowInvitePopup()
end

--[[
	On invites update
]]
function PartyUI.OnInvitesUpdate(invites: { any })
	pendingInvites = invites
	if #invites > 0 then
		PartyUI.ShowInvitePopup()
	end
end

--[[
	Update party display
]]
function PartyUI.UpdatePartyDisplay()
	if not currentParty then return end
	if not partyFrame then return end

	PartyUI.UpdateGameModeLabel()
	PartyUI.UpdateMembersList()
end

--[[
	Update game mode label
]]
function PartyUI.UpdateGameModeLabel()
	if not currentParty then return end
	if not partyFrame then return end

	local label = partyFrame:FindFirstChild("GameMode") :: TextLabel?
	if label then
		label.Text = `{currentParty.gameMode} ({#currentParty.members}/{currentParty.maxSize})`
	end
end

--[[
	Update members list
]]
function PartyUI.UpdateMembersList()
	if not currentParty then return end
	if not partyFrame then return end

	local membersList = partyFrame:FindFirstChild("MembersList") :: Frame?
	if not membersList then return end

	-- Clear existing frames
	PartyUI.ClearMemberFrames()

	-- Create member frames
	for i, member in ipairs(currentParty.members) do
		local frame = PartyUI.CreateMemberFrame(member)
		frame.LayoutOrder = i
		frame.Parent = membersList
		memberFrames[member.userId] = frame
	end
end

--[[
	Create member frame
]]
function PartyUI.CreateMemberFrame(member: PartyData.PartyMember): Frame
	local frame = Instance.new("Frame")
	frame.Name = `Member_{member.userId}`
	frame.Size = UDim2.new(1, 0, 0, 38)
	frame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
	frame.BorderSizePixel = 0

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	-- Crown icon for leader
	if member.isLeader then
		local crown = Instance.new("TextLabel")
		crown.Name = "Crown"
		crown.Size = UDim2.new(0, 20, 1, 0)
		crown.Position = UDim2.fromOffset(5, 0)
		crown.BackgroundTransparency = 1
		crown.TextColor3 = Color3.fromRGB(255, 200, 50)
		crown.TextSize = 14
		crown.Font = Enum.Font.GothamBold
		crown.Text = string.char(0x1F451) -- Crown emoji fallback
		crown.Parent = frame
	end

	-- Name label
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(1, -80, 1, 0)
	nameLabel.Position = UDim2.fromOffset(member.isLeader and 25 or 10, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
	nameLabel.TextSize = 14
	nameLabel.Font = Enum.Font.GothamMedium
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Text = member.displayName
	nameLabel.Parent = frame

	-- Ready indicator
	local readyIndicator = Instance.new("Frame")
	readyIndicator.Name = "ReadyIndicator"
	readyIndicator.Size = UDim2.new(0, 12, 0, 12)
	readyIndicator.Position = UDim2.new(1, -25, 0.5, -6)
	readyIndicator.BackgroundColor3 = member.isReady and Color3.fromRGB(80, 180, 80) or Color3.fromRGB(100, 100, 100)
	readyIndicator.Parent = frame

	local indicatorCorner = Instance.new("UICorner")
	indicatorCorner.CornerRadius = UDim.new(1, 0)
	indicatorCorner.Parent = readyIndicator

	return frame
end

--[[
	Update member ready status
]]
function PartyUI.UpdateMemberReady(userId: number, isReady: boolean)
	local frame = memberFrames[userId]
	if not frame then return end

	local indicator = frame:FindFirstChild("ReadyIndicator") :: Frame?
	if indicator then
		indicator.BackgroundColor3 = isReady and Color3.fromRGB(80, 180, 80) or Color3.fromRGB(100, 100, 100)
	end
end

--[[
	Clear member frames
]]
function PartyUI.ClearMemberFrames()
	for _, frame in pairs(memberFrames) do
		frame:Destroy()
	end
	memberFrames = {}
end

--[[
	Show invite popup
]]
function PartyUI.ShowInvitePopup()
	if not invitePopup then return end
	if #pendingInvites == 0 then return end

	local invite = pendingInvites[1]

	local desc = invitePopup:FindFirstChild("Description") :: TextLabel?
	if desc then
		desc.Text = `{invite.invite.fromName} invited you to play {invite.gameMode}`
	end

	-- Animate in
	invitePopup.Position = UDim2.new(0.5, 0, 0, -130)
	invitePopup.Visible = true

	TweenService:Create(invitePopup, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 20),
	}):Play()
end

--[[
	Hide invite popup
]]
function PartyUI.HideInvitePopup()
	if not invitePopup then return end

	local tween = TweenService:Create(invitePopup, TweenInfo.new(0.2), {
		Position = UDim2.new(0.5, 0, 0, -130),
	})

	tween:Play()
	tween.Completed:Connect(function()
		invitePopup.Visible = false
	end)
end

--[[
	Accept current invite
]]
function PartyUI.AcceptInvite()
	if #pendingInvites == 0 then return end

	local invite = pendingInvites[1]
	table.remove(pendingInvites, 1)

	Events.FireServer("Party", "AcceptInvite", {
		inviteId = invite.invite.id,
	})

	if #pendingInvites > 0 then
		PartyUI.ShowInvitePopup()
	else
		PartyUI.HideInvitePopup()
	end
end

--[[
	Decline current invite
]]
function PartyUI.DeclineInvite()
	if #pendingInvites == 0 then return end

	local invite = pendingInvites[1]
	table.remove(pendingInvites, 1)

	Events.FireServer("Party", "DeclineInvite", {
		inviteId = invite.invite.id,
	})

	if #pendingInvites > 0 then
		PartyUI.ShowInvitePopup()
	else
		PartyUI.HideInvitePopup()
	end
end

--[[
	Toggle ready state
]]
function PartyUI.ToggleReady()
	if not currentParty then return end

	-- Find our member
	for _, member in ipairs(currentParty.members) do
		if member.userId == player.UserId then
			Events.FireServer("Party", "SetReady", {
				isReady = not member.isReady,
			})
			break
		end
	end
end

--[[
	Leave party
]]
function PartyUI.LeaveParty()
	Events.FireServer("Party", "Leave", {})
end

--[[
	Create party
]]
function PartyUI.CreateParty(gameMode: string?)
	Events.FireServer("Party", "Create", {
		gameMode = gameMode or "Squads",
	})
end

--[[
	Invite player
]]
function PartyUI.InvitePlayer(targetUserId: number)
	Events.FireServer("Party", "Invite", {
		targetUserId = targetUserId,
	})
end

--[[
	Show party UI
]]
function PartyUI.Show()
	if not partyFrame then return end
	isVisible = true
	partyFrame.Visible = true
end

--[[
	Hide party UI
]]
function PartyUI.Hide()
	if not partyFrame then return end
	isVisible = false
	partyFrame.Visible = false
end

--[[
	Check if in party
]]
function PartyUI.IsInParty(): boolean
	return currentParty ~= nil
end

--[[
	Get current party
]]
function PartyUI.GetParty(): PartyData.Party?
	return currentParty
end

return PartyUI
