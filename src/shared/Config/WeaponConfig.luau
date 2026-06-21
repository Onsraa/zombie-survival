--!strict
--[[
	WeaponConfig.luau
	Weapon definitions and the points economy for buying weapons / ammo.
	PURE data (no Roblox APIs) so it can be unit tested with Lune.

	Times are in seconds, ranges in studs, damage in HP. fireCooldown is the
	minimum seconds between shots (auto weapons hold to fire).
]]

export type WeaponDef = {
	id: string,
	name: string,
	damage: number,
	headshotMultiplier: number,
	fireCooldown: number,
	auto: boolean,
	magSize: number,
	reserveAmmo: number,
	reloadTime: number,
	range: number,
	wallBuyCost: number?, -- nil = starting weapon (not purchasable off a wall)
	ammoCost: number, -- points to refill reserve ammo
}

local WeaponConfig = {}

WeaponConfig.STARTING_WEAPON = "pistol"

WeaponConfig.Weapons = {
	pistol = {
		id = "pistol",
		name = "M1911",
		damage = 25,
		headshotMultiplier = 1.5,
		fireCooldown = 0.25,
		auto = false,
		magSize = 12,
		reserveAmmo = 96,
		reloadTime = 1.5,
		range = 300,
		wallBuyCost = nil,
		ammoCost = 250,
	} :: WeaponDef,

	rifle = {
		id = "rifle",
		name = "AK-74u",
		damage = 35,
		headshotMultiplier = 1.5,
		fireCooldown = 0.1,
		auto = true,
		magSize = 30,
		reserveAmmo = 210,
		reloadTime = 2.2,
		range = 400,
		wallBuyCost = 1200,
		ammoCost = 600,
	} :: WeaponDef,

	shotgun = {
		id = "shotgun",
		name = "Olympia",
		damage = 90,
		headshotMultiplier = 1.5,
		fireCooldown = 0.6,
		auto = false,
		magSize = 6,
		reserveAmmo = 48,
		reloadTime = 3.0,
		range = 50,
		wallBuyCost = 1500,
		ammoCost = 500,
	} :: WeaponDef,
}

-- Look up a weapon definition by id.
function WeaponConfig.get(id: string): WeaponDef?
	return WeaponConfig.Weapons[id]
end

return WeaponConfig
