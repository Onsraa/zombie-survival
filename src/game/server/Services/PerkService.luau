--!strict
--[[
	PerkService.luau
	Perk machines (built on the shared BuyStation): spend points for a persistent per-player
	buff that lasts until you respawn (classic — perks are lost on death). Reload and
	fire-rate perks run through WeaponService's per-player multipliers; Juggernog raises the
	character's max health. Server-authoritative (SE-2).

		Juggernog   (2500) — max health 100 -> 250
		Speed Cola  (3000) — reload 0.5x time
		Double Tap  (2000) — fire rate 1.33x

	Public API:
		PerkService.init()    -- per-player lifecycle (clear perks on respawn)
		PerkService.build()   -- place the machines (call after ArenaService.build)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ArenaConfig = require(ReplicatedStorage.Shared.Config.ArenaConfig)
local BuyStation = require(script.Parent.BuyStation)
local SessionService = require(script.Parent.SessionService)
local WeaponService = require(script.Parent.WeaponService)

type Perk = {
	id: string,
	label: string,
	cost: number,
	color: Color3,
	maxHealth: number?,
	reloadMult: number?,
	fireRateMult: number?,
}

local PERKS: { Perk } = {
	{ id = "Juggernog", label = "Juggernog", cost = 2500, color = Color3.fromRGB(200, 40, 40), maxHealth = 250 },
	{ id = "SpeedCola", label = "Speed Cola", cost = 3000, color = Color3.fromRGB(40, 170, 70), reloadMult = 0.5 },
	{ id = "DoubleTap", label = "Double Tap", cost = 2000, color = Color3.fromRGB(220, 180, 40), fireRateMult = 1.33 },
}

local RING_RADIUS_FRACTION = 0.15 -- inner ring, clear of the box / pack-a-punch / wall-buys

local PerkService = {}

local owned: { [Player]: { [string]: boolean } } = {}

local function ringPosition(index: number, count: number, radius: number, y: number): Vector3
	local angle = (index - 1) / count * math.pi * 2
	return Vector3.new(math.cos(angle) * radius, y, math.sin(angle) * radius)
end

local function applyPerk(player: Player, perk: Perk)
	if perk.maxHealth then
		local char = player.Character
		local humanoid = char and char:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.MaxHealth = perk.maxHealth
			humanoid.Health = perk.maxHealth
		end
	end
	if perk.reloadMult then
		WeaponService.setReloadMultiplier(player, perk.reloadMult)
	end
	if perk.fireRateMult then
		WeaponService.setFireRateMultiplier(player, perk.fireRateMult)
	end
end

local function clearPerks(player: Player)
	owned[player] = {}
	WeaponService.setReloadMultiplier(player, 1)
	WeaponService.setFireRateMultiplier(player, 1)
end

local function buyHandler(perk: Perk): (Player) -> ()
	return function(player: Player)
		local set = owned[player]
		if not set then
			set = {}
			owned[player] = set
		end
		if set[perk.id] then
			return -- already owned this life
		end
		if not SessionService.spendPoints(player, perk.cost) then
			return
		end
		set[perk.id] = true
		applyPerk(player, perk)
	end
end

function PerkService.build()
	local arena = Workspace:FindFirstChild("Arena")
	local existing = arena and arena:FindFirstChild("Perks")
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "Perks"

	local radius = ArenaConfig.FLOOR_SIZE * RING_RADIUS_FRACTION
	local y = ArenaConfig.FLOOR_Y + 2
	for i, perk in PERKS do
		local machine = BuyStation.create({
			name = "Perk_" .. perk.id,
			position = ringPosition(i, #PERKS, radius, y),
			objectText = perk.label,
			actionText = `Buy [{perk.cost}]`,
			labelText = `{perk.label}\n[{perk.cost}]`,
			color = perk.color,
			onActivate = buyHandler(perk),
		})
		machine.Parent = folder
	end

	folder.Parent = arena or Workspace
	print(`[PerkService] {#PERKS} perk machines placed`)
end

function PerkService.init()
	local function hookPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			clearPerks(player) -- perks are lost on death / respawn
		end)
		if player.Character then
			clearPerks(player)
		end
	end

	Players.PlayerAdded:Connect(hookPlayer)
	for _, player in Players:GetPlayers() do
		hookPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
	end)
	print("[PerkService] Initialized")
end

return PerkService
