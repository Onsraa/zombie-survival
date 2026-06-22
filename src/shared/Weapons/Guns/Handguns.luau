--!strict
local Weapons = script.Parent.Parent
local Enums = require(Weapons.Enums)
local Types = require(Weapons.Types)

type GunDef = Types.GunDef
local C, F, T = Enums.Category, Enums.FireMode, Enums.FireType

return {
	m1911 = {
		id = "m1911",
		name = "M1911",
		category = C.Handgun,
		fireMode = F.SemiAuto,
		fireType = T.Hitscan,
		rpm = 400,
		damage = 40,
		headshotMultiplier = 1.5,
		penetration = 1,
		penetrationFalloff = 1.0,
		range = 300,
		spread = { base = 0.0, max = 4.0, bloomPerShot = 0.8, recover = 6 },
		recoil = { vertical = 1.0, horizontal = 0.3, recover = 14 },
		magSize = 8,
		reserveAmmo = 80,
		reloadTime = 1.6,
		wallBuyCost = nil,
		ammoCost = 250,
		upgrade = "mustang_sally",
		assets = {},
	} :: GunDef,

	-- Pack-a-Punch variant: explosive rounds (Projectile → AoE via explode).
	mustang_sally = {
		id = "mustang_sally",
		name = "Mustang & Sally",
		category = C.Handgun,
		fireMode = F.SemiAuto,
		fireType = T.Projectile,
		rpm = 400,
		damage = 150,
		headshotMultiplier = 1.0,
		penetration = 1,
		penetrationFalloff = 1.0,
		range = 300,
		spread = { base = 0.0, max = 2.0, bloomPerShot = 0.4, recover = 8 },
		recoil = { vertical = 1.2, horizontal = 0.3, recover = 14 },
		magSize = 16,
		reserveAmmo = 100,
		reloadTime = 2.0,
		ammoCost = 1000,
		assets = {},
	} :: GunDef,
}
