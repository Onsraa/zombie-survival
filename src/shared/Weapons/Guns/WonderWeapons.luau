--!strict
local Weapons = script.Parent.Parent
local Enums = require(Weapons.Enums)
local Types = require(Weapons.Types)

type GunDef = Types.GunDef
local C, F, T = Enums.Category, Enums.FireMode, Enums.FireType

return {
	raygun = {
		id = "raygun",
		name = "Ray Gun",
		category = C.Wonder,
		fireMode = F.SemiAuto,
		fireType = T.Projectile,
		rpm = 300,
		damage = 1000, -- huge direct hit; Projectile behavior adds splash
		headshotMultiplier = 1.0, -- AoE ignores headshots
		penetration = 1,
		penetrationFalloff = 1.0,
		range = 500,
		spread = { base = 0.0, max = 0.0, bloomPerShot = 0.0, recover = 0 }, -- pinpoint
		recoil = { vertical = 1.5, horizontal = 0.2, recover = 12 },
		magSize = 20,
		reserveAmmo = 160,
		reloadTime = 3.0,
		wallBuyCost = nil, -- mystery box only
		ammoCost = 4950,
		upgrade = "porters_x2",
		assets = {},
	} :: GunDef,

	-- Pack-a-Punch variant.
	porters_x2 = {
		id = "porters_x2",
		name = "Porter's X2 Ray Gun",
		category = C.Wonder,
		fireMode = F.SemiAuto,
		fireType = T.Projectile,
		rpm = 360,
		damage = 2000,
		headshotMultiplier = 1.0,
		penetration = 1,
		penetrationFalloff = 1.0,
		range = 500,
		spread = { base = 0.0, max = 0.0, bloomPerShot = 0.0, recover = 0 },
		recoil = { vertical = 1.5, horizontal = 0.2, recover = 12 },
		magSize = 40,
		reserveAmmo = 200,
		reloadTime = 3.0,
		ammoCost = 5000,
		assets = {},
	} :: GunDef,
}
