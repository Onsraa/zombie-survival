--!strict
--[[
	SessionService.luau
	In-memory, per-player session state for the match. MVP is session-only: nothing
	is persisted to a DataStore (that arrives in Epic 4 via ProfileStore). All
	gameplay-authoritative values (points, kills) live here on the server (SE-2).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RemoteHandler = require(script.Parent.Parent.RemoteHandler)

type PlayerSession = Types.PlayerSession

local SessionService = {}

local sessions: { [Player]: PlayerSession } = {}

-- Push points/kills to the player's HUD whenever they change.
local function broadcast(player: Player)
	local session = sessions[player]
	if session then
		RemoteHandler.fireClient(Remotes.Names.PlayerStats, player, {
			points = session.points,
			kills = session.kills,
		})
	end
end

function SessionService.create(player: Player): PlayerSession
	local session: PlayerSession = {
		points = 0,
		kills = 0,
		joinedAt = os.time(),
	}
	sessions[player] = session
	broadcast(player)
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
	broadcast(player)
	return session.points
end

function SessionService.addKill(player: Player): number
	local session = sessions[player]
	if not session then
		return 0
	end
	session.kills += 1
	broadcast(player)
	return session.kills
end

-- Push current points/kills to one player (HUD sync-on-mount).
function SessionService.pushStats(player: Player)
	broadcast(player)
end

return SessionService
