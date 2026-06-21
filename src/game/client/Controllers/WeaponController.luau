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

local function fireOnce()
	local gun = currentGun
	local camera = Workspace.CurrentCamera
	if not gun or not camera or not shootRemote then
		return
	end
	local now = os.clock()
	if now - lastFire < 60 / gun.rpm then
		return
	end
	lastFire = now
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
			task.wait(60 / gun.rpm)
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
		if inputState == Enum.UserInputState.Begin and reloadRemote then
			reloadRemote:FireServer()
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
			if typeof(state) == "table" and type(state.weaponId) == "string" then
				currentGun = GunRegistry.get(state.weaponId)
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
