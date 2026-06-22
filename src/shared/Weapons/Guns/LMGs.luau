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
		spread = { base = 0.0, max = 7.0, bloomPerShot = 0.4, recover = 5 },
		recoil = { vertical = 1.4, horizontal = 0.6, recover = 11 },
		magSize = 75,
		reserveAmmo = 225,
		reloadTime = 4.0,
		wallBuyCost = 1800,
		ammoCost = 750,
		upgrade = "r115_resonator",
		assets = {},
	} :: GunDef,

	-- Pack-a-Punch variant.
	r115_resonator = {
		id = "r115_resonator",
		name = "R115 Resonator",
		category = C.LMG,
		fireMode = F.Automatic,
		fireType = T.Hitscan,
		rpm = 600,
		damage = 100,
		headshotMultiplier = 1.5,
		penetration = 4,
		penetrationFalloff = 0.9,
		range = 600,
		spread = { base = 0.0, max = 7.0, bloomPerShot = 0.4, recover = 5 },
		recoil = { vertical = 1.4, horizontal = 0.6, recover = 11 },
		magSize = 100,
		reserveAmmo = 300,
		reloadTime = 4.0,
		ammoCost = 1500,
		assets = {},
	} :: GunDef,
}
