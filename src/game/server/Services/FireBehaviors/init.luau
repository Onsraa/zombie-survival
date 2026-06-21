--!strict
--[[
	FireBehaviors (init)
	Maps a gun's FireType to its server behavior. Add a new exotic weapon type by
	adding a behavior module here + a matching FireType in shared/Weapons/Enums.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums = require(ReplicatedStorage.Shared.Weapons.Enums)
local Types = require(ReplicatedStorage.Shared.Weapons.Types)

type Behavior = { fire: (ctx: Types.FireContext) -> () }

local FireBehaviors: { [string]: Behavior } = {
	[Enums.FireType.Hitscan] = require(script.Hitscan),
	[Enums.FireType.Shotgun] = require(script.Shotgun),
	[Enums.FireType.Projectile] = require(script.Projectile),
}

return FireBehaviors
