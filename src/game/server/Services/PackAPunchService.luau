--!strict
--[[
	PackAPunchService.luau
	Pack-a-Punch: spend points to upgrade the held gun to its data-defined variant
	(GunDef.upgrade). The shared BuyStation handles pedestal/prompt/proximity. Upgraded
	guns have no `upgrade` of their own, so they can't be re-PaP'd (and aren't charged).
	Server-authoritative (SE-2).

	Public API:
		PackAPunchService.build()   -- call after ArenaService.build
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ArenaConfig = require(ReplicatedStorage.Shared.Config.ArenaConfig)
local GunRegistry = require(ReplicatedStorage.Shared.Weapons.GunRegistry)
local BuyStation = require(script.Parent.BuyStation)
local SessionService = require(script.Parent.SessionService)
local WeaponService = require(script.Parent.WeaponService)

local PAP_COST = 5000
local PAP_COLOR = Color3.fromRGB(60, 120, 180)

local PackAPunchService = {}

local function onUpgrade(player: Player)
	local id = WeaponService.getWeaponId(player)
	local gun = id and GunRegistry.get(id)
	if not gun then
		return
	end
	local upgradeId = gun.upgrade
	if not upgradeId or not GunRegistry.get(upgradeId) then
		return -- no variant (already upgraded, or none defined) — no charge
	end
	if SessionService.spendPoints(player, PAP_COST) then
		WeaponService.giveWeapon(player, upgradeId)
	end
end

function PackAPunchService.build()
	local arena = Workspace:FindFirstChild("Arena")
	local existing = arena and arena:FindFirstChild("PackAPunch")
	if existing then
		existing:Destroy()
	end

	local quarter = ArenaConfig.FLOOR_SIZE * 0.22
	local y = ArenaConfig.FLOOR_Y + 2
	local machine = BuyStation.create({
		name = "PackAPunch",
		position = Vector3.new(-quarter, y, quarter),
		objectText = "Pack-a-Punch",
		actionText = `Upgrade [{PAP_COST}]`,
		labelText = `Pack-a-Punch\n[{PAP_COST}]`,
		color = PAP_COLOR,
		onActivate = onUpgrade,
	})
	machine.Parent = arena or Workspace
	print("[PackAPunchService] machine placed")
end

return PackAPunchService
