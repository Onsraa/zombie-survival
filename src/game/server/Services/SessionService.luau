--!strict
--[[
	SessionService.luau
	In-memory, per-player session state for the match. MVP is session-only: nothing
	is persisted to a DataStore (that arrives in Epic 4 via ProfileStore). All
	gameplay-authoritative values (points, kills) live here on the server (SE-2).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

type PlayerSession = Types.PlayerSession

local SessionService = {}

local sessions: { [Player]: PlayerSession } = {}

function SessionService.create(player: Player): PlayerSession
	local session: PlayerSession = {
		points = 0,
		kills = 0,
		joinedAt = os.time(),
	}
	sessions[player] = session
	return session
end

function SessionService.get(player: Player): PlayerSession?
	return sessions[player]
end

function SessionService.remove(player: Player)
	sessions[player] = nil
end

function SessionService.addPoints(player: Player, amount: number): number
	local session = sessions[player]
	if not session then
		return 0
	end
	session.points += amount
	return session.points
end

function SessionService.addKill(player: Player): number
	local session = sessions[player]
	if not session then
		return 0
	end
	session.kills += 1
	return session.kills
end

return SessionService
