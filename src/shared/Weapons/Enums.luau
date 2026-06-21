--!strict
--[[
	Enums.luau
	String enums for the weapon system. Pure (no Roblox APIs).
	- Category: the COD weapon class (drives Mystery Box pools, UI grouping, etc.)
	- FireMode: how the trigger behaves
	- FireType: which server fire-behavior strategy handles the shot
]]

local WeaponEnums = {}

WeaponEnums.Category = {
	AssaultRifle = "AssaultRifle",
	SMG = "SMG",
	Shotgun = "Shotgun",
	LMG = "LMG",
	Handgun = "Handgun",
	Explosive = "Explosive",
	Special = "Special",
	Wonder = "Wonder",
}

WeaponEnums.FireMode = {
	Automatic = "Automatic", -- hold to keep firing
	SemiAuto = "SemiAuto", -- one shot per trigger pull
	SingleShot = "SingleShot", -- like SemiAuto; semantic for break-action / bolt guns
	Burst = "Burst", -- N shots per trigger pull
}

WeaponEnums.FireType = {
	Hitscan = "Hitscan", -- instant raycast (most guns), supports penetration
	Shotgun = "Shotgun", -- multiple pellets per shot
	Projectile = "Projectile", -- Ray Gun / explosives (AoE)
	Melee = "Melee", -- knives
}

return WeaponEnums
