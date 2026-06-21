--!strict
--[[
	Hitscan.luau
	Instant single-bullet raycast with penetration: the bullet pierces up to
	`gun.penetration` zombies, losing `penetrationFalloff` of its damage per pierce,
	and stops at the first wall.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Ballistics = require(ReplicatedStorage.Shared.Weapons.Ballistics)
local Types = require(ReplicatedStorage.Shared.Weapons.Types)
local Util = require(script.Parent.Util)

local Hitscan = {}

function Hitscan.fire(ctx: Types.FireContext)
	local gun = ctx.gun
	local exclude: { Instance } = { ctx.character }
	local origin = ctx.origin
	local dir = Util.applySpread(ctx.direction, ctx.spreadDeg)
	local connected, headshot = false, false

	for pierce = 0, math.max(gun.penetration, 1) - 1 do
		local result = Workspace:Raycast(origin, dir * gun.range, Util.makeParams(exclude))
		if not result then
			break
		end
		local zombie = Util.getZombieFromPart(result.Instance)
		if not zombie then
			break -- hit world; bullet stops
		end
		local isHead = result.Instance.Name == "Head"
		local dmg = Ballistics.pierceDamage(gun.damage, gun.penetrationFalloff, pierce)
		if isHead then
			dmg *= gun.headshotMultiplier
		end
		ctx.damageZombie(zombie, dmg, ctx.player)
		connected = true
		headshot = headshot or isHead
		table.insert(exclude, zombie) -- pierce through this zombie
		origin = result.Position
	end

	if connected then
		ctx.reportHit(headshot)
	end
end

return Hitscan
