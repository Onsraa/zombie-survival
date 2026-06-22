--!strict
local Weapons = script.Parent.Parent
local Enums = require(Weapons.Enums)
local Types = require(Weapons.Types)

type GunDef = Types.GunDef
local C, F, T = Enums.Category, Enums.FireMode, Enums.FireType

return {
	olympia = {
		id = "olympia",
		name = "Olympia",
		category = C.Shotgun,
		fireMode = F.SingleShot,
		fireType = T.Shotgun,
		rpm = 200,
		damage = 25, -- per pellet
		headshotMultiplier = 1.5,
		penetration = 1,
		penetrationFalloff = 1.0,
		range = 60,
		pellets = 8,
		spread = { base = 5.0, max = 8.0, bloomPerShot = 1.0, recover = 6 },
		recoil = { vertical = 2.0, horizontal = 0.6, recover = 12 },
		magSize = 2,
		reserveAmmo = 48,
		reloadTime = 3.0,
		wallBuyCost = 1500,
		ammoCost = 500,
		upgrade = "hades",
		assets = {},
	} :: GunDef,

	-- Pack-a-Punch variant.
	hades = {
		id = "hades",
		name = "Hades",
		category = C.Shotgun,
		fireMode = F.SingleShot,
		fireType = T.Shotgun,
		rpm = 200,
		damage = 50, -- per pellet
		headshotMultiplier = 1.5,
		penetration = 2,
		penetrationFalloff = 0.9,
		range = 80,
		pellets = 10,
		spread = { base = 5.0, max = 8.0, bloomPerShot = 1.0, recover = 6 },
		recoil = { vertical = 2.0, horizontal = 0.6, recover = 12 },
		magSize = 4,
		reserveAmmo = 64,
		reloadTime = 3.0,
		ammoCost = 1000,
		assets = {},
	} :: GunDef,
}
