--!strict
--[[
	Ballistics.luau
	Pure weapon math (no Roblox APIs) so it is unit-testable with Lune. Used by the
	server WeaponService / fire behaviors. Keeps the testable logic separate from the
	Roblox-bound bits (raycasts, CFrame spread application live in the fire behaviors).
]]

local Ballistics = {}

-- Seconds between shots derived from rate of fire (rounds per minute).
function Ballistics.rpmToCooldown(rpm: number): number
	if rpm <= 0 then
		return 0
	end
	return 60 / rpm
end

-- Spread (degrees) after firing one shot: grow by bloomPerShot, clamped to max.
function Ballistics.bloomSpread(
	current: number,
	spread: { base: number, max: number, bloomPerShot: number, recover: number }
): number
	return math.min(spread.max, math.max(current, spread.base) + spread.bloomPerShot)
end

-- Spread (degrees) after `dt` seconds of not firing: recover toward base.
function Ballistics.recoverSpread(
	current: number,
	spread: { base: number, max: number, bloomPerShot: number, recover: number },
	dt: number
): number
	return math.max(spread.base, current - spread.recover * dt)
end

-- Damage for a bullet that has already pierced `pierceIndex` zombies (0 = first hit).
function Ballistics.pierceDamage(baseDamage: number, falloff: number, pierceIndex: number): number
	return baseDamage * falloff ^ pierceIndex
end

return Ballistics
