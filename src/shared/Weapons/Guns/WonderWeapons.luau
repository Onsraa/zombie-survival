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
		assets = {},
	} :: GunDef,
}
