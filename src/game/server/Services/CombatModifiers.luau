--!strict
--[[
	CombatModifiers.luau
	Global, power-up-driven combat modifiers, read by ZombieService on each hit. A leaf
	module (no service requires) so ZombieService and PowerUpService can both use it
	without a require cycle.
]]

local CombatModifiers = {}

local instaKill = false
local pointsMultiplier = 1

function CombatModifiers.setInstaKill(value: boolean)
	instaKill = value
end

function CombatModifiers.isInstaKill(): boolean
	return instaKill
end

function CombatModifiers.setPointsMultiplier(multiplier: number)
	pointsMultiplier = multiplier
end

function CombatModifiers.getPointsMultiplier(): number
	return pointsMultiplier
end

return CombatModifiers
