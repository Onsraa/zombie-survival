--!strict
--[[
	WallBuyService.luau
	Server-authoritative wall-buys. A pedestal per buyable gun is placed around the inner
	perimeter of the arena; a ProximityPrompt drives the purchase (mobile-native, and no
	custom remote means the client can't forge a buy). On trigger the server re-checks
	proximity, then spends points to either give the gun (first purchase → wallBuyCost) or
	refill its ammo (already holding it → ammoCost).

	Buyable guns = every GunDef with a wallBuyCost; placement auto-distributes them, so
	adding a wall gun is just a data entry. The starting pistol / box-only guns (no
	wallBuyCost) don't appear on a wall.

	Public API:
		WallBuyService.build()   -- create the pedestals (call after ArenaService.build)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ArenaConfig = require(ReplicatedStorage.Shared.Config.ArenaConfig)
local GunRegistry = require(ReplicatedStorage.Shared.Weapons.GunRegistry)
local Types = require(ReplicatedStorage.Shared.Weapons.Types)
local SessionService = require(script.Parent.SessionService)
local WeaponService = require(script.Parent.WeaponService)

type GunDef = Types.GunDef

local PEDESTAL_SIZE = Vector3.new(4, 4, 1)
local PEDESTAL_COLOR = Color3.fromRGB(122, 96, 44)
local RING_INSET = 8 -- studs inside the perimeter wall
local ACTIVATION_DISTANCE = 10 -- ProximityPrompt range
local VALIDATE_DISTANCE = 16 -- server anti-exploit re-check (> activation, with margin)

local WallBuyService = {}

local function ringPosition(index: number, count: number, radius: number, y: number): Vector3
	local angle = (index - 1) / count * math.pi * 2
	return Vector3.new(math.cos(angle) * radius, y, math.sin(angle) * radius)
end

local function onBuy(player: Player, gun: GunDef, pedestal: BasePart)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	-- Anti-exploit: the buyer must actually be at the pedestal (don't trust the prompt).
	if (root.Position - pedestal.Position).Magnitude > VALIDATE_DISTANCE then
		return
	end

	if WeaponService.getWeaponId(player) == gun.id then
		-- Already holding this gun: the wall sells ammo.
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

local function makeLabel(gun: GunDef, parent: BasePart)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(8, 2)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 60
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 226, 150)
	label.TextStrokeTransparency = 0.4
	label.TextScaled = true
	label.Text = `{gun.name}\n[{gun.wallBuyCost}]`
	label.Parent = billboard
end

local function makePedestal(gun: GunDef, position: Vector3): BasePart
	local pedestal = Instance.new("Part")
	pedestal.Name = "WallBuy_" .. gun.id
	pedestal.Anchored = true
	pedestal.Size = PEDESTAL_SIZE
	pedestal.Position = position
	pedestal.Color = PEDESTAL_COLOR
	pedestal.Material = Enum.Material.Wood

	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = gun.name
	prompt.ActionText = `Buy [{gun.wallBuyCost}]`
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = ACTIVATION_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = pedestal
	prompt.Triggered:Connect(function(player: Player)
		onBuy(player, gun, pedestal)
	end)

	makeLabel(gun, pedestal)
	return pedestal
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
	local y = ArenaConfig.FLOOR_Y + PEDESTAL_SIZE.Y / 2
	for i, gun in guns do
		local pos = ringPosition(i, #guns, radius, y)
		makePedestal(gun, pos).Parent = folder
	end

	folder.Parent = arena or Workspace
	print(`[WallBuyService] {#guns} wall-buys placed`)
end

return WallBuyService
