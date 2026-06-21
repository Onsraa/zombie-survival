--!strict
--[[
	WeaponController.luau
	Client weapon input. Sends only the aim *direction* (camera look vector) to the
	server, which owns the raycast, damage, and ammo. Supports desktop (mouse + R)
	and mobile (ContextActionService touch buttons). The HUD (S5) will render the
	WeaponState; for now this tracks the equipped weapon for fire cadence.
]]

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local WeaponConfig = require(ReplicatedStorage.Shared.Config.WeaponConfig)
local WeaponEffects = require(script.Parent.WeaponEffects)

local WeaponController = {}

local shootRemote: RemoteEvent? = nil
local reloadRemote: RemoteEvent? = nil

local currentWeaponId = WeaponConfig.STARTING_WEAPON
local lastFire = 0
local firing = false

local function fire()
	local weapon = WeaponConfig.get(currentWeaponId)
	local camera = Workspace.CurrentCamera
	if not weapon or not camera or not shootRemote then
		return
	end
	local now = os.clock()
	if now - lastFire < weapon.fireCooldown then
		return
	end
	lastFire = now
	shootRemote:FireServer(camera.CFrame.LookVector)
	WeaponEffects.onFire()
end

local function onAction(
	actionName: string,
	inputState: Enum.UserInputState,
	_input: InputObject
): Enum.ContextActionResult
	if actionName == "Shoot" then
		if inputState == Enum.UserInputState.Begin then
			firing = true
			fire() -- immediate shot (covers semi-auto)
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
	WeaponEffects.start()
	shootRemote = Remotes.get(Remotes.Names.Shoot)
	reloadRemote = Remotes.get(Remotes.Names.Reload)

	local weaponState = Remotes.get(Remotes.Names.WeaponState)
	if weaponState then
		weaponState.OnClientEvent:Connect(function(state)
			if typeof(state) == "table" and type(state.weaponId) == "string" then
				currentWeaponId = state.weaponId
			end
		end)
	end

	-- Shoot: mouse (desktop) + touch button (mobile). Reload: R / touch button.
	ContextActionService:BindAction("Shoot", onAction, true, Enum.UserInputType.MouseButton1, Enum.UserInputType.Touch)
	ContextActionService:BindAction("Reload", onAction, true, Enum.KeyCode.R)

	-- Auto-fire while held (semi-auto is handled by the Begin shot above).
	RunService.Heartbeat:Connect(function()
		if firing then
			local weapon = WeaponConfig.get(currentWeaponId)
			if weapon and weapon.auto then
				fire()
			end
		end
	end)

	print("[WeaponController] Started")
end

return WeaponController
