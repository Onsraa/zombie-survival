--!strict
--[[
	WallBuyService.luau
	Wall-buys: a pedestal per gun with a wallBuyCost, placed around the arena perimeter.
	The shared BuyStation handles the pedestal/prompt/proximity; this service supplies the
	purchase logic — spend points to give the gun (first buy) or refill its ammo (already
	holding it). Server-authoritative (SE-2). Adding a wall gun = a wallBuyCost in data.

	Public API:
		WallBuyService.build()   -- call after ArenaService.build
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ArenaConfig = require(ReplicatedStorage.Shared.Config.ArenaConfig)
local GunRegistry = require(ReplicatedStorage.Shared.Weapons.GunRegistry)
local Types = require(ReplicatedStorage.Shared.Weapons.Types)
local BuyStation = require(script.Parent.BuyStation)
local SessionService = require(script.Parent.SessionService)
local WeaponService = require(script.Parent.WeaponService)

type GunDef = Types.GunDef

local PEDESTAL_COLOR = Color3.fromRGB(122, 96, 44)
local RING_INSET = 8 -- studs inside the perimeter wall

local WallBuyService = {}

local function ringPosition(index: number, count: number, radius: number, y: number): Vector3
	local angle = (index - 1) / count * math.pi * 2
	return Vector3.new(math.cos(angle) * radius, y, math.sin(angle) * radius)
end

-- Buy the gun (first purchase) or refill its ammo (already holding it).
local function buyHandler(gun: GunDef): (Player) -> ()
	return function(player: Player)
		if WeaponService.getWeaponId(player) == gun.id then
			if WeaponService.needsAmmo(player) and SessionService.spendPoints(player, gun.ammoCost) then
				WeaponService.refillAmmo(player)
			end
		else
			local cost = gun.wallBuyCost
			if cost and SessionService.spendPoints(player, cost) then
				WeaponService.giveWeapon(player, gun.id)
			end
		end
	end
end

function WallBuyService.build()
	local arena = Workspace:FindFirstChild("Arena")
	local existing = arena and arena:FindFirstChild("WallBuys")
	if existing then
		existing:Destroy()
	end

	-- Buyable guns (those with a wall cost), sorted by id for deterministic placement.
	local guns: { GunDef } = {}
	for _, gun in GunRegistry.getAll() do
		if gun.wallBuyCost then
			table.insert(guns, gun)
		end
	end
	table.sort(guns, function(a, b)
		return a.id < b.id
	end)

	local folder = Instance.new("Folder")
	folder.Name = "WallBuys"

	local radius = ArenaConfig.FLOOR_SIZE / 2 - ArenaConfig.WALL_THICKNESS - RING_INSET
	local y = ArenaConfig.FLOOR_Y + 2 -- pedestal half-height, so it rests on the floor
	for i, gun in guns do
		local pedestal = BuyStation.create({
			name = "WallBuy_" .. gun.id,
			position = ringPosition(i, #guns, radius, y),
			objectText = gun.name,
			actionText = `Buy [{gun.wallBuyCost}]`,
			labelText = `{gun.name}\n[{gun.wallBuyCost}]`,
			color = PEDESTAL_COLOR,
			onActivate = buyHandler(gun),
		})
		pedestal.Parent = folder
	end

	folder.Parent = arena or Workspace
	print(`[WallBuyService] {#guns} wall-buys placed`)
end

return WallBuyService
