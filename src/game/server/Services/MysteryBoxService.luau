--!strict
--[[
	MysteryBoxService.luau
	The Mystery Box: spend points for a random weapon. The shared BuyStation handles the
	pedestal/prompt/proximity; this service rolls a weighted-random gun from the base-gun
	pool (excludes the starting pistol and Pack-a-Punch variants; wonder weapons are
	rarer), flashes a short reveal on the box label, then gives the gun. Server-authoritative.

	Public API:
		MysteryBoxService.build()   -- call after ArenaService.build
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ArenaConfig = require(ReplicatedStorage.Shared.Config.ArenaConfig)
local Enums = require(ReplicatedStorage.Shared.Weapons.Enums)
local GunRegistry = require(ReplicatedStorage.Shared.Weapons.GunRegistry)
local Types = require(ReplicatedStorage.Shared.Weapons.Types)
local BuyStation = require(script.Parent.BuyStation)
local SessionService = require(script.Parent.SessionService)
local WeaponService = require(script.Parent.WeaponService)

type GunDef = Types.GunDef

local BOX_COST = 950
local BOX_COLOR = Color3.fromRGB(120, 80, 30)
local WONDER_WEIGHT = 1 -- wonder weapons (Ray Gun) are the rare jackpot
local COMMON_WEIGHT = 5
local REVEAL_TICKS = 12
local REVEAL_INTERVAL = 0.08
local HOLD_TIME = 1.5

local MysteryBoxService = {}

local function defaultLabel(): string
	return `Mystery Box\n[{BOX_COST}]`
end

-- Weighted roll pool: base guns only (no starting pistol, no PaP variants), wonder rarer.
local function buildPool(): { GunDef }
	local upgradeIds: { [string]: boolean } = {}
	for _, gun in GunRegistry.getAll() do
		if gun.upgrade then
			upgradeIds[gun.upgrade] = true
		end
	end

	local pool: { GunDef } = {}
	for id, gun in GunRegistry.getAll() do
		if id ~= GunRegistry.STARTING_WEAPON and not upgradeIds[id] then
			local weight = if gun.category == Enums.Category.Wonder then WONDER_WEIGHT else COMMON_WEIGHT
			for _ = 1, weight do
				table.insert(pool, gun)
			end
		end
	end
	return pool
end

function MysteryBoxService.build()
	local arena = Workspace:FindFirstChild("Arena")
	local existing = arena and arena:FindFirstChild("MysteryBox")
	if existing then
		existing:Destroy()
	end

	local pool = buildPool()
	if #pool == 0 then
		warn("[MysteryBoxService] empty pool — no box placed")
		return
	end

	local quarter = ArenaConfig.FLOOR_SIZE * 0.22
	local y = ArenaConfig.FLOOR_Y + 2

	local busy = false
	local box: BasePart
	local function onOpen(player: Player)
		if busy then
			return -- a roll is already revealing
		end
		if not SessionService.spendPoints(player, BOX_COST) then
			return
		end
		busy = true
		local result = pool[math.random(#pool)]
		task.spawn(function()
			local label = box:FindFirstChild("Label", true) :: TextLabel?
			for _ = 1, REVEAL_TICKS do
				if label then
					label.Text = pool[math.random(#pool)].name
				end
				task.wait(REVEAL_INTERVAL)
			end
			if label then
				label.Text = result.name .. "!"
			end
			WeaponService.giveWeapon(player, result.id)
			task.wait(HOLD_TIME)
			if label then
				label.Text = defaultLabel()
			end
			busy = false
		end)
	end

	box = BuyStation.create({
		name = "MysteryBox",
		position = Vector3.new(quarter, y, -quarter),
		objectText = "Mystery Box",
		actionText = `Open [{BOX_COST}]`,
		labelText = defaultLabel(),
		color = BOX_COLOR,
		onActivate = onOpen,
	})
	box.Parent = arena or Workspace
	print(`[MysteryBoxService] box placed ({#pool} weighted entries)`)
end

return MysteryBoxService
