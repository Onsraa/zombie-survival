--!strict
local Weapons = script.Parent.Parent
local Enums = require(Weapons.Enums)
local Types = require(Weapons.Types)

type GunDef = Types.GunDef
local C, F, T = Enums.Category, Enums.FireMode, Enums.FireType

return {
	rpk = {
		id = "rpk",
		name = "RPK",
		category = C.LMG,
		fireMode = F.Automatic,
		fireType = T.Hitscan,
		rpm = 600,
		damage = 50,
		headshotMultiplier = 1.5,
		penetration = 3,
		penetrationFalloff = 0.85,
		range = 600,
		spread = { base = 1.5, max = 7.0, bloomPerShot = 0.4, recover = 5 },
		recoil = { vertical = 1.4, horizontal = 0.6, recover = 11 },
		magSize = 75,
		reserveAmmo = 225,
		reloadTime = 4.0,
		wallBuyCost = 1800,
		ammoCost = 750,
		assets = {},
	} :: GunDef,
}
