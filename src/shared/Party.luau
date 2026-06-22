--!strict
--[[
	Party.luau
	Pure party data model + operations (no Roblox APIs) so the logic is Lune-testable.
	PartyService (lobby server) owns the live state and wraps these; matchmaking reads them.
]]

export type PartyMember = {
	userId: number,
	name: string,
	ready: boolean,
}

export type Party = {
	id: number,
	leaderUserId: number,
	members: { PartyMember },
}

local Party = {}

function Party.new(id: number, leaderUserId: number, leaderName: string): Party
	return {
		id = id,
		leaderUserId = leaderUserId,
		members = { { userId = leaderUserId, name = leaderName, ready = false } },
	}
end

function Party.find(party: Party, userId: number): PartyMember?
	for _, member in party.members do
		if member.userId == userId then
			return member
		end
	end
	return nil
end

function Party.addMember(party: Party, userId: number, name: string): boolean
	if Party.find(party, userId) then
		return false
	end
	table.insert(party.members, { userId = userId, name = name, ready = false })
	return true
end

-- Remove a member; if the leader left, hand leadership to the next member.
function Party.removeMember(party: Party, userId: number)
	for index, member in party.members do
		if member.userId == userId then
			table.remove(party.members, index)
			break
		end
	end
	if party.leaderUserId == userId and #party.members > 0 then
		party.leaderUserId = party.members[1].userId
	end
end

function Party.setReady(party: Party, userId: number, ready: boolean)
	local member = Party.find(party, userId)
	if member then
		member.ready = ready
	end
end

function Party.count(party: Party): number
	return #party.members
end

function Party.allReady(party: Party): boolean
	if #party.members == 0 then
		return false
	end
	for _, member in party.members do
		if not member.ready then
			return false
		end
	end
	return true
end

return Party
