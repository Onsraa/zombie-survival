--!strict
--[[
	PartyService.luau (Lobby place)
	Owns the lobby's parties — create / join / leave / ready — and broadcasts a snapshot of
	every party to all clients. Server-authoritative. Pure party ops live in shared/Party.

	Lobby remotes are created here directly: the Lobby place doesn't include the Game place's
	RemoteHandler, and party traffic is low-frequency + UI-driven. (A future cleanup could
	move RemoteHandler to shared so both places share the rate-limit/validation layer.)

	Public API:
		PartyService.init()
		PartyService.getParty(player) -> Party?   (for MatchmakingService in pt2)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Party = require(ReplicatedStorage.Shared.Party)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MatchmakingService = require(script.Parent.MatchmakingService)

local PartyService = {}

local parties: { [number]: Party.Party } = {}
local playerParty: { [Player]: number } = {}
local nextId = 0

local stateRemote: RemoteEvent

local function ensureRemote(name: string): RemoteEvent
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	local remote = (folder :: Folder):FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	return remote :: RemoteEvent
end

local function snapshot()
	local list = {}
	for _, party in parties do
		local members = {}
		for _, member in party.members do
			table.insert(members, { userId = member.userId, name = member.name, ready = member.ready })
		end
		table.insert(list, { id = party.id, leaderUserId = party.leaderUserId, members = members })
	end
	return { parties = list }
end

local function broadcast()
	stateRemote:FireAllClients(snapshot())
end

local function leaveCurrent(player: Player)
	local id = playerParty[player]
	if not id then
		return
	end
	playerParty[player] = nil
	local party = parties[id]
	if party then
		Party.removeMember(party, player.UserId)
		if Party.count(party) == 0 then
			parties[id] = nil
		end
	end
end

function PartyService.getParty(player: Player): Party.Party?
	local id = playerParty[player]
	return id and parties[id]
end

local function onCreate(player: Player)
	leaveCurrent(player)
	nextId += 1
	parties[nextId] = Party.new(nextId, player.UserId, player.Name)
	playerParty[player] = nextId
	broadcast()
end

local function onJoin(player: Player, partyId: any)
	if typeof(partyId) ~= "number" then
		return
	end
	local party = parties[partyId]
	if not party then
		return
	end
	leaveCurrent(player)
	if Party.addMember(party, player.UserId, player.Name) then
		playerParty[player] = partyId
		broadcast()
	end
end

local function onLeave(player: Player)
	leaveCurrent(player)
	broadcast()
end

local function onSetReady(player: Player, ready: any)
	local party = PartyService.getParty(player)
	if party then
		Party.setReady(party, player.UserId, ready == true)
		broadcast()
	end
end

local function onStart(player: Player)
	local party = PartyService.getParty(player)
	if not party or party.leaderUserId ~= player.UserId then
		return -- only the leader can start
	end
	if not Party.allReady(party) then
		return
	end
	MatchmakingService.start(party) -- ReserveServer + TeleportAsync into a fresh Game server
end

function PartyService.init()
	stateRemote = ensureRemote(Remotes.Names.PartyState)
	ensureRemote(Remotes.Names.CreateParty).OnServerEvent:Connect(onCreate)
	ensureRemote(Remotes.Names.JoinParty).OnServerEvent:Connect(onJoin)
	ensureRemote(Remotes.Names.LeaveParty).OnServerEvent:Connect(onLeave)
	ensureRemote(Remotes.Names.SetReady).OnServerEvent:Connect(onSetReady)
	ensureRemote(Remotes.Names.StartMatch).OnServerEvent:Connect(onStart)

	Players.PlayerRemoving:Connect(function(player)
		leaveCurrent(player)
		broadcast()
	end)

	print("[PartyService] Initialized")
end

return PartyService
