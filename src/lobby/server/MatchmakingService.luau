--!strict
--[[
	MatchmakingService.luau (Lobby place)
	Sends a ready party to a fresh reserved Game server: ReserveServer + TeleportAsync with
	the party as TeleportData. The leader's StartMatch triggers this via PartyService, so the
	teleport is server-initiated (TeleportData is trusted on arrival). Until GAME_PLACE_ID is
	set (post-publish) it logs and no-ops, so Studio playtests don't error.

	Public API:
		MatchmakingService.start(party)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local PlaceIds = require(ReplicatedStorage.Shared.Config.PlaceIds)
local Party = require(ReplicatedStorage.Shared.Party)

local MatchmakingService = {}

function MatchmakingService.start(party: Party.Party)
	if PlaceIds.GAME_PLACE_ID == 0 then
		warn("[MatchmakingService] GAME_PLACE_ID not set — publish the Game place + set Config/PlaceIds")
		return
	end

	local players: { Player } = {}
	local members = {}
	for _, member in party.members do
		local p = Players:GetPlayerByUserId(member.userId)
		if p then
			table.insert(players, p)
		end
		table.insert(members, { userId = member.userId, name = member.name })
	end
	if #players == 0 then
		return
	end

	-- Reserve a private server in the Game place so the whole party lands together.
	local ok, accessCode = pcall(function()
		return TeleportService:ReserveServer(PlaceIds.GAME_PLACE_ID)
	end)
	if not ok or typeof(accessCode) ~= "string" then
		warn(`[MatchmakingService] ReserveServer failed: {tostring(accessCode)}`)
		return
	end

	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = accessCode
	options:SetTeleportData({ partyId = party.id, members = members })

	local teleportOk, err = pcall(function()
		TeleportService:TeleportAsync(PlaceIds.GAME_PLACE_ID, players, options)
	end)
	if not teleportOk then
		warn(`[MatchmakingService] TeleportAsync failed: {tostring(err)}`)
	end
end

return MatchmakingService
