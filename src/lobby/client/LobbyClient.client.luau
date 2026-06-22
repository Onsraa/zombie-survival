--!strict
--[[
	LobbyClient.client.luau (Lobby place)
	The party panel: create / join / leave / ready, and (leader) start. Rebuilds from the
	PartyState broadcast. Plain Luau UI (the React HUD is the Game place's; the lobby keeps
	its own lightweight panel). Server (PartyService) is authoritative.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

type MemberSnap = { userId: number, name: string, ready: boolean }
type PartySnap = { id: number, leaderUserId: number, members: { MemberSnap } }

local player = Players.LocalPlayer
local myId = player.UserId

local function remote(name: string): RemoteEvent?
	return Remotes.get(name)
end

local function fire(name: string, value: (boolean | number)?)
	local r = remote(name)
	if r then
		r:FireServer(value)
	end
end

-- ---- UI scaffold ----------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "LobbyUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Size = UDim2.fromScale(0.3, 0.62)
panel.Position = UDim2.fromScale(0.03, 0.19)
panel.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel = 0
panel.Parent = gui
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 10)
panelCorner.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.Text = "PARTIES"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 22
title.Parent = panel

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -20, 1, -56)
content.Position = UDim2.fromOffset(10, 48)
content.BackgroundTransparency = 1
content.Parent = panel
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = content

local order = 0

local function clearContent()
	order = 0
	for _, child in content:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function label(text: string, color: Color3?)
	order += 1
	local item = Instance.new("TextLabel")
	item.LayoutOrder = order
	item.Size = UDim2.new(1, 0, 0, 26)
	item.BackgroundTransparency = 1
	item.Text = text
	item.TextColor3 = color or Color3.fromRGB(220, 220, 220)
	item.Font = Enum.Font.Gotham
	item.TextSize = 15
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.Parent = content
end

local function button(text: string, color: Color3, onClick: () -> ())
	order += 1
	local item = Instance.new("TextButton")
	item.LayoutOrder = order
	item.Size = UDim2.new(1, 0, 0, 34)
	item.BackgroundColor3 = color
	item.BorderSizePixel = 0
	item.Text = text
	item.TextColor3 = Color3.fromRGB(255, 255, 255)
	item.Font = Enum.Font.GothamBold
	item.TextSize = 16
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = item
	item.Activated:Connect(onClick)
	item.Parent = content
end

-- ---- render ---------------------------------------------------------------

local function findMyParty(parties: { PartySnap }): PartySnap?
	for _, party in parties do
		for _, member in party.members do
			if member.userId == myId then
				return party
			end
		end
	end
	return nil
end

local function render(parties: { PartySnap })
	clearContent()
	local myParty = findMyParty(parties)

	if myParty then
		local amLeader = myParty.leaderUserId == myId
		local meReady = false
		local allReady = #myParty.members > 0
		for _, member in myParty.members do
			if not member.ready then
				allReady = false
			end
			if member.userId == myId then
				meReady = member.ready
			end
			local lead = if member.userId == myParty.leaderUserId then " (leader)" else ""
			local tick = if member.ready then "  [ready]" else ""
			label(member.name .. lead .. tick, if member.ready then Color3.fromRGB(120, 220, 120) else nil)
		end

		button(if meReady then "Unready" else "Ready", Color3.fromRGB(60, 130, 90), function()
			fire(Remotes.Names.SetReady, not meReady)
		end)
		if amLeader then
			local canStart = allReady
			button(
				if canStart then "START MATCH" else "Start (all must ready)",
				if canStart then Color3.fromRGB(205, 150, 40) else Color3.fromRGB(80, 70, 45),
				function()
					fire(Remotes.Names.StartMatch)
				end
			)
		end
		button("Leave Party", Color3.fromRGB(150, 50, 50), function()
			fire(Remotes.Names.LeaveParty)
		end)
	else
		button("Create Party", Color3.fromRGB(60, 110, 170), function()
			fire(Remotes.Names.CreateParty)
		end)
		label("Open parties:")
		local anyOpen = false
		for _, party in parties do
			anyOpen = true
			local leaderName = "Party"
			for _, member in party.members do
				if member.userId == party.leaderUserId then
					leaderName = member.name
				end
			end
			local partyId = party.id
			button(`Join {leaderName} ({#party.members})`, Color3.fromRGB(70, 90, 110), function()
				fire(Remotes.Names.JoinParty, partyId)
			end)
		end
		if not anyOpen then
			label("  (none yet — create one)", Color3.fromRGB(150, 150, 150))
		end
	end
end

local stateRemote = remote(Remotes.Names.PartyState)
if stateRemote then
	stateRemote.OnClientEvent:Connect(function(snap)
		if typeof(snap) == "table" and typeof(snap.parties) == "table" then
			render(snap.parties :: { PartySnap })
		end
	end)
end

render({})
