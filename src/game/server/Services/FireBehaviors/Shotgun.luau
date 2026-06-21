--!strict
--[[
	Shotgun.luau
	Fires `gun.pellets` independent pellets, each a single hitscan ray with its own
	spread sample. Pellets do not penetrate.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Types = require(ReplicatedStorage.Shared.Weapons.Types)
local Util = require(script.Parent.Util)

local Shotgun = {}

function Shotgun.fire(ctx: Types.FireContext)
	local gun = ctx.gun
	local pellets = gun.pellets or 1
	local exclude = { ctx.character }
	local connected, headshot = false, false

	for _ = 1, pellets do
		local dir = Util.applySpread(ctx.direction, ctx.spreadDeg)
		local result = Workspace:Raycast(ctx.origin, dir * gun.range, Util.makeParams(exclude))
		if result then
			local zombie = Util.getZombieFromPart(result.Instance)
			if zombie then
				local isHead = result.Instance.Name == "Head"
				local dmg = if isHead then gun.damage * gun.headshotMultiplier else gun.damage
				ctx.damageZombie(zombie, dmg, ctx.player)
				connected = true
				headshot = headshot or isHead
			end
		end
	end

	if connected then
		ctx.reportHit(headshot)
	end
end

return Shotgun
