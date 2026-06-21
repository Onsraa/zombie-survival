--!strict
--[[
	WeaponService.luau
	Server-authoritative weapons. The client sends only an aim *direction*; the server
	owns the raycast, damage, ammo, and reload. Points are awarded through
	ZombieService.damageZombie (server-side, SE-2). Weapon stats come from WeaponConfig.

	Remotes:
		Shoot   (client -> server) : fire intent, payload = aim direction (Vector3)
		Reload  (client -> server) : reload request
		WeaponState (server -> client) : { weaponId, magAmmo, reserveAmmo, magSize, reloading }
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)
local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local RemoteHandler = require(script.Parent.Parent.RemoteHandler)
local ZombieService = require(script.Parent.ZombieService)

local SHOOT_RATE_LIMIT = 120 -- backstop per rate window; real cadence is weapon.fireCooldown

type WeaponState = {
	weaponId: string,
	magAmmo: number,
	reserveAmmo: number,
	lastFire: number,
	reloading: boolean,
}

local WeaponService = {}

local states: { [Player]: WeaponState } = {}

-- Walk up from a hit part to the tagged Zombie model, if any.
local function getZombieFromPart(part: BasePart): Model?
	local current: Instance? = part
	while current do
		if current:IsA("Model") and CollectionService:HasTag(current, Constants.Tags.Zombie) then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function broadcastState(player: Player)
	local state = states[player]
	if not state then
		return
	end
	local weapon = WeaponConfig.get(state.weaponId)
	RemoteHandler.fireClient(Remotes.Names.WeaponState, player, {
		weaponId = state.weaponId,
		magAmmo = state.magAmmo,
		reserveAmmo = state.reserveAmmo,
		magSize = weapon and weapon.magSize or 0,
		reloading = state.reloading,
	})
end

function WeaponService.giveWeapon(player: Player, weaponId: string)
	local weapon = WeaponConfig.get(weaponId)
	if not weapon then
		return
	end
	states[player] = {
		weaponId = weaponId,
		magAmmo = weapon.magSize,
		reserveAmmo = weapon.reserveAmmo,
		lastFire = 0,
		reloading = false,
	}
	broadcastState(player)
end

local function getCharacterParts(player: Player): (Humanoid?, BasePart?)
	local char = player.Character
	if not char then
		return nil, nil
	end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local origin = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
	return humanoid, origin :: BasePart?
end

local function onShoot(player: Player, direction: any)
	if typeof(direction) ~= "Vector3" or direction.Magnitude < 0.1 then
		return
	end

	local state = states[player]
	if not state or state.reloading or state.magAmmo <= 0 then
		return
	end

	local weapon = WeaponConfig.get(state.weaponId)
	if not weapon then
		return
	end

	local humanoid, origin = getCharacterParts(player)
	if not humanoid or humanoid.Health <= 0 or not origin then
		return
	end

	local now = os.clock()
	if now - state.lastFire < weapon.fireCooldown then
		return
	end
	state.lastFire = now
	state.magAmmo -= 1

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance }
	local result = Workspace:Raycast(origin.Position, direction.Unit * weapon.range, params)

	if result then
		local zombie = getZombieFromPart(result.Instance)
		if zombie then
			local headshot = result.Instance.Name == "Head"
			local damage = weapon.damage
			if headshot then
				damage *= weapon.headshotMultiplier
			end
			ZombieService.damageZombie(zombie, damage, player)
			-- Tell the shooter they connected (for the HUD hit marker).
			RemoteHandler.fireClient(Remotes.Names.ShotResult, player, headshot)
		end
	end

	broadcastState(player)
end

local function onReload(player: Player)
	local state = states[player]
	if not state or state.reloading then
		return
	end

	local weapon = WeaponConfig.get(state.weaponId)
	if not weapon then
		return
	end
	if state.magAmmo >= weapon.magSize or state.reserveAmmo <= 0 then
		return
	end

	state.reloading = true
	broadcastState(player)

	task.delay(weapon.reloadTime, function()
		local current = states[player]
		if not current or current ~= state then
			return -- player left or re-armed
		end
		local need = weapon.magSize - state.magAmmo
		local take = math.min(need, state.reserveAmmo)
		state.magAmmo += take
		state.reserveAmmo -= take
		state.reloading = false
		broadcastState(player)
	end)
end

-- Push current weapon state to one player (used by the HUD sync-on-mount request).
function WeaponService.pushState(player: Player)
	broadcastState(player)
end

function WeaponService.init()
	RemoteHandler.createRemote(Remotes.Names.WeaponState, "Event")
	RemoteHandler.createRemote(Remotes.Names.ShotResult, "Event")
	RemoteHandler.register({
		Name = Remotes.Names.Shoot,
		Type = "Event",
		Handler = onShoot,
		RateLimit = SHOOT_RATE_LIMIT,
	})
	RemoteHandler.register({
		Name = Remotes.Names.Reload,
		Type = "Event",
		Handler = onReload,
		RateLimit = 10,
	})

	local function setup(player: Player)
		WeaponService.giveWeapon(player, WeaponConfig.STARTING_WEAPON)
		-- Top up the magazine on each (re)spawn so players aren't stranded empty.
		player.CharacterAdded:Connect(function()
			local state = states[player]
			local weapon = state and WeaponConfig.get(state.weaponId)
			if state and weapon then
				state.magAmmo = weapon.magSize
				state.reloading = false
				broadcastState(player)
			end
		end)
	end

	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		setup(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)

	print("[WeaponService] Initialized")
end

return WeaponService
