--!strict
--[[
	Projectile.luau
	Ray Gun / explosive behavior: raycast to an impact point, then deal the gun's
	damage to the direct hit AND every zombie within the splash radius. (v1 is an
	instant hitscan+splash; a travelling projectile can replace this behind the same
	FireType later without touching callers.)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Types = require(ReplicatedStorage.Shared.Weapons.Types)
local Util = require(script.Parent.Util)

local SPLASH_RADIUS = 10

local Projectile = {}

function Projectile.fire(ctx: Types.FireContext)
	local gun = ctx.gun
	local dir = ctx.direction.Unit
	local result = Workspace:Raycast(ctx.origin, dir * gun.range, Util.makeParams({ ctx.character }))
	local impact = if result then result.Position else ctx.origin + dir * gun.range

	local connected = false
	for _, zombie in Util.getZombiesInRadius(impact, SPLASH_RADIUS) do
		ctx.damageZombie(zombie, gun.damage, ctx.player)
		connected = true
	end

	if connected then
		ctx.reportHit(false)
	end
end

return Projectile
