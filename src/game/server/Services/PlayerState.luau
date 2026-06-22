--!strict
--[[
	PlayerState.luau
	Shared per-player runtime flags. A leaf module (no service requires) so WeaponService
	and ZombieService can read "downed" without a require cycle back to DownService (which
	owns the down/revive logic).
]]

local PlayerState = {}

local downed: { [Player]: boolean } = {}

function PlayerState.setDowned(player: Player, value: boolean)
	downed[player] = if value then true else nil
end

function PlayerState.isDowned(player: Player): boolean
	return downed[player] == true
end

return PlayerState
