--!strict
--[[
	WeaponService.luau
	Server-authoritative weapons. The client sends a camera ray { origin, direction };
	the server validates it, applies the gun's spread, and dispatches to the gun's
	fire behavior (Hitscan / Shotgun / Projectile). Guns are data-driven (GunRegistry);
	pure math (cooldown, spread, falloff) lives in Ballistics.

	Accuracy model (COD-style): recoil is a client-side visual kick; the real spread is
	server-side here — a per-gun cone that blooms with sustained fire and recovers.

	Remotes:
		Shoot   (client -> server) : { origin: Vector3, direction: Vector3 }
		Reload  (client -> server)
		WeaponState (server -> client) : { weaponId, magAmmo, reserveAmmo, magSize, reloading }
		ShotResult  (server -> shooter) : headshot: boolean (HUD hit marker)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GunRegistry = require(ReplicatedStorage.Shared.Weapons.GunRegistry)
local Ballistics = require(ReplicatedStorage.Shared.Weapons.Ballistics)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local RemoteHandler = require(script.Parent.Parent.RemoteHandler)
local ZombieService = require(script.Parent.ZombieService)
local FireBehaviors = require(script.Parent.FireBehaviors)

local SHOOT_RATE_LIMIT = 150 -- anti-flood backstop; real cadence is the gun's RPM
local MAX_ORIGIN_OFFSET = 12 -- studs the camera origin may differ from the head (anti-exploit)

type WeaponState = {
	weaponId: string,
	magAmmo: number,
	reserveAmmo: number,
	lastFire: number,
	reloading: boolean,
	spread: number, -- current accuracy cone (degrees)
}

local WeaponService = {}

local states: { [Player]: WeaponState } = {}

local function broadcastState(player: Player)
	local state = states[player]
	if not state then
		return
	end
	local gun = GunRegistry.get(state.weaponId)
	RemoteHandler.fireClient(Remotes.Names.WeaponState, player, {
		weaponId = state.weaponId,
		magAmmo = state.magAmmo,
		reserveAmmo = state.reserveAmmo,
		magSize = gun and gun.magSize or 0,
		reloading = state.reloading,
	})
end

function WeaponService.giveWeapon(player: Player, weaponId: string)
	local gun = GunRegistry.get(weaponId)
	if not gun then
		return
	end
	states[player] = {
		weaponId = weaponId,
		magAmmo = gun.magSize,
		reserveAmmo = gun.reserveAmmo,
		lastFire = 0,
		reloading = false,
		spread = gun.spread.base,
	}
	broadcastState(player)
end

local function onShoot(player: Player, payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	local origin = payload.origin
	local direction = payload.direction
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" or direction.Magnitude < 0.1 then
		return
	end

	local state = states[player]
	if not state or state.reloading or state.magAmmo <= 0 then
		return
	end
	local gun = GunRegistry.get(state.weaponId)
	if not gun then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local head = character and (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart"))
	if not character or not humanoid or humanoid.Health <= 0 or not head then
		return
	end
	-- Anti-exploit: the camera origin must be near the player's head.
	if (origin - (head :: BasePart).Position).Magnitude > MAX_ORIGIN_OFFSET then
		return
	end

	local now = os.clock()
	if now - state.lastFire < Ballistics.rpmToCooldown(gun.rpm) then
		return
	end

	-- Spread: recover for idle time, fire at the current cone, then bloom.
	state.spread = Ballistics.recoverSpread(state.spread, gun.spread, now - state.lastFire)
	local spreadForShot = state.spread
	state.spread = Ballistics.bloomSpread(state.spread, gun.spread)
	state.lastFire = now
	state.magAmmo -= 1

	local behavior = FireBehaviors[gun.fireType]
	if behavior then
		behavior.fire({
			player = player,
			gun = gun,
			origin = origin,
			direction = direction.Unit,
			spreadDeg = spreadForShot,
			character = character,
			damageZombie = ZombieService.damageZombie,
			reportHit = function(headshot: boolean)
				RemoteHandler.fireClient(Remotes.Names.ShotResult, player, headshot)
			end,
			explode = ZombieService.explode,
		})
	end

	broadcastState(player)
end

local function onReload(player: Player)
	local state = states[player]
	if not state or state.reloading then
		return
	end
	local gun = GunRegistry.get(state.weaponId)
	if not gun then
		return
	end
	if state.magAmmo >= gun.magSize or state.reserveAmmo <= 0 then
		return
	end

	state.reloading = true
	broadcastState(player)

	task.delay(gun.reloadTime, function()
		if states[player] ~= state then
			return -- player left or re-armed
		end
		local need = gun.magSize - state.magAmmo
		local take = math.min(need, state.reserveAmmo)
		state.magAmmo += take
		state.reserveAmmo -= take
		state.reloading = false
		broadcastState(player)
	end)
end

-- Push current weapon state to one player (HUD sync-on-mount).
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
		WeaponService.giveWeapon(player, GunRegistry.STARTING_WEAPON)
		-- Top up the magazine on each (re)spawn so players aren't stranded empty.
		player.CharacterAdded:Connect(function()
			local state = states[player]
			local gun = state and GunRegistry.get(state.weaponId)
			if state and gun then
				state.magAmmo = gun.magSize
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
