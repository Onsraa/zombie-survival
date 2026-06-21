--!strict
local Weapons = script.Parent.Parent
local Enums = require(Weapons.Enums)
local Types = require(Weapons.Types)

type GunDef = Types.GunDef
local C, F, T = Enums.Category, Enums.FireMode, Enums.FireType

return {
	m16 = {
		id = "m16",
		name = "M16",
		category = C.AssaultRifle,
		fireMode = F.Burst,
		fireType = T.Hitscan,
		burstCount = 3,
		rpm = 700,
		damage = 45,
		headshotMultiplier = 1.5,
		penetration = 2,
		penetrationFalloff = 0.8,
		range = 500,
		spread = { base = 0.6, max = 3.0, bloomPerShot = 0.5, recover = 7 },
		recoil = { vertical = 1.2, horizontal = 0.4, recover = 13 },
		magSize = 30,
		reserveAmmo = 180,
		reloadTime = 2.4,
		wallBuyCost = 1200,
		ammoCost = 600,
		assets = {},
	} :: GunDef,
}
