--!strict
--[[
	WeaponController.luau
	Client weapon input. Sends a camera ray { origin, direction } (so bullets land on
	the crosshair); the server owns raycast/damage/ammo/spread. Fire mode (auto / semi /
	single / burst) comes from the gun's GunDef. Recoil is a visual effect (WeaponEffects).
]]

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Enums = require(ReplicatedStorage.Shared.Weapons.Enums)
local GunRegistry = require(ReplicatedStorage.Shared.Weapons.GunRegistry)
local Types = require(ReplicatedStorage.Shared.Weapons.Types)
local WeaponEffects = require(script.Parent.WeaponEffects)

type GunDef = Types.GunDef

local WeaponController = {}

local shootRemote: RemoteEvent? = nil
local reloadRemote: RemoteEvent? = nil

local currentGun: GunDef? = GunRegistry.get(GunRegistry.STARTING_WEAPON)
local lastFire = 0
local firing = false
local bursting = false

-- Mirror of the server-authoritative WeaponState (kept in sync by the WeaponState
-- remote). The client gates fire on this so it never shows a shot the server rejects.
local magAmmo = 0
local reserveAmmo = 0
local reloading = false
local fireRateMult = 1 -- Double Tap perk; server-authoritative, mirrored here for cadence

-- Ask the server to reload (server re-validates). Used by manual R and auto-reload.
local function requestReload()
	if reloadRemote and not reloading and reserveAmmo > 0 then
		reloadRemote:FireServer()
	end
end

local function fireOnce()
	local gun = currentGun
	local camera = Workspace.CurrentCamera
	if not gun or not camera or not shootRemote then
		return
	end
	-- Don't fire effects/remote the server would reject (reloading or empty).
	if reloading then
		return
	end
	if magAmmo <= 0 then
		requestReload() -- auto-reload when trying to fire on empty
		return
	end
	local now = os.clock()
	if now - lastFire < 60 / gun.rpm / fireRateMult then
		return
	end
	lastFire = now
	magAmmo -= 1 -- optimistic; the server's WeaponState broadcast reconciles the truth
	-- Aim from the camera so the shot lines up with the center crosshair.
	shootRemote:FireServer({
		origin = camera.CFrame.Position,
		direction = camera.CFrame.LookVector,
	})
	WeaponEffects.onFire()
end

local function doBurst(gun: GunDef)
	if bursting then
		return
	end
	bursting = true
	task.spawn(function()
		for _ = 1, gun.burstCount or 3 do
			fireOnce()
			task.wait(60 / gun.rpm / fireRateMult)
		end
		bursting = false
	end)
end

local function onAction(
	actionName: string,
	inputState: Enum.UserInputState,
	_input: InputObject
): Enum.ContextActionResult
	if actionName == "Shoot" then
		local gun = currentGun
		if inputState == Enum.UserInputState.Begin and gun then
			if gun.fireMode == Enums.FireMode.Burst then
				doBurst(gun)
			elseif gun.fireMode == Enums.FireMode.Automatic then
				firing = true
				fireOnce()
			else -- SemiAuto / SingleShot: one shot per pull
				fireOnce()
			end
		elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
			firing = false
		end
	elseif actionName == "Reload" then
		if inputState == Enum.UserInputState.Begin then
			requestReload()
		end
	end
	return Enum.ContextActionResult.Sink
end

function WeaponController.start()
	shootRemote = Remotes.get(Remotes.Names.Shoot)
	reloadRemote = Remotes.get(Remotes.Names.Reload)

	local weaponState = Remotes.get(Remotes.Names.WeaponState)
	if weaponState then
		weaponState.OnClientEvent:Connect(function(state)
			if typeof(state) ~= "table" then
				return
			end
			if type(state.weaponId) == "string" then
				currentGun = GunRegistry.get(state.weaponId)
			end
			if type(state.magAmmo) == "number" then
				magAmmo = state.magAmmo
			end
			if type(state.reserveAmmo) == "number" then
				reserveAmmo = state.reserveAmmo
			end
			if type(state.fireRateMult) == "number" then
				fireRateMult = state.fireRateMult
			end
			reloading = state.reloading == true
			-- Auto-reload the instant the mag runs dry and there's reserve to load.
			if magAmmo <= 0 and reserveAmmo > 0 and not reloading then
				requestReload()
			end
		end)
	end

	ContextActionService:BindAction("Shoot", onAction, true, Enum.UserInputType.MouseButton1, Enum.UserInputType.Touch)
	ContextActionService:BindAction("Reload", onAction, true, Enum.KeyCode.R)

	-- Held-fire for automatics (semi/burst/single fire on the Begin event).
	RunService.Heartbeat:Connect(function()
		if firing then
			local gun = currentGun
			if gun and gun.fireMode == Enums.FireMode.Automatic then
				fireOnce()
			end
		end
	end)

	print("[WeaponController] Started")
end

return WeaponController
