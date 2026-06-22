--!strict
local Weapons = script.Parent.Parent
local Enums = require(Weapons.Enums)
local Types = require(Weapons.Types)

type GunDef = Types.GunDef
local C, F, T = Enums.Category, Enums.FireMode, Enums.FireType

return {
	ak74u = {
		id = "ak74u",
		name = "AK-74u",
		category = C.SMG,
		fireMode = F.Automatic,
		fireType = T.Hitscan,
		rpm = 600,
		damage = 30,
		headshotMultiplier = 1.5,
		penetration = 1,
		penetrationFalloff = 1.0,
		range = 350,
		spread = { base = 0.0, max = 6.0, bloomPerShot = 0.6, recover = 8 },
		recoil = { vertical = 0.9, horizontal = 0.5, recover = 14 },
		magSize = 30,
		reserveAmmo = 210,
		reloadTime = 2.2,
		wallBuyCost = 1000,
		ammoCost = 600,
		upgrade = "ak74fu2",
		assets = {},
	} :: GunDef,

	-- Pack-a-Punch variant.
	ak74fu2 = {
		id = "ak74fu2",
		name = "AK-74fu2",
		category = C.SMG,
		fireMode = F.Automatic,
		fireType = T.Hitscan,
		rpm = 600,
		damage = 60,
		headshotMultiplier = 1.5,
		penetration = 2,
		penetrationFalloff = 0.9,
		range = 350,
		spread = { base = 0.0, max = 6.0, bloomPerShot = 0.6, recover = 8 },
		recoil = { vertical = 0.9, horizontal = 0.5, recover = 14 },
		magSize = 40,
		reserveAmmo = 300,
		reloadTime = 2.2,
		ammoCost = 1200,
		assets = {},
	} :: GunDef,
}
