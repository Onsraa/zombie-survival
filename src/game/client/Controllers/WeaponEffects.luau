--!strict
--[[
	WeaponEffects.luau
	Client-side shot cosmetics: a snappy visual recoil kick (COD "recoil" is basically
	animation — the real accuracy is the server's spread), plus bullet tracers and
	impact sparks. The recoil profile comes per-gun from its GunDef.

	Recoil is captured AFTER the shot's aim is read (see WeaponController.fireOnce), and
	recovers quickly, so it's effectively visual and doesn't corrupt aim.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Types = require(ReplicatedStorage.Shared.Weapons.Types)

local WeaponEffects = {}

local TRACER_LIFETIME = 0.05
local IMPACT_LIFETIME = 0.08
local MAX_RANGE = 600
local DEFAULT_RECOVER = 14

-- Transient recoil offset (x = pitch UP, y = yaw). Decays to zero each frame.
local recoil = Vector2.zero
local recoverRate = DEFAULT_RECOVER

local function raycastParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local char = Players.LocalPlayer.Character
	params.FilterDescendantsInstances = if char then { char } else {}
	return params
end

local function spawnTracer(origin: Vector3, finish: Vector3)
	local dist = (finish - origin).Magnitude
	if dist < 0.1 then
		return
	end
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(255, 226, 150)
	part.Size = Vector3.new(0.07, 0.07, dist)
	part.CFrame = CFrame.lookAt(origin, finish) * CFrame.new(0, 0, -dist / 2)
	part.Parent = Workspace
	Debris:AddItem(part, TRACER_LIFETIME)
end

local function spawnImpact(pos: Vector3)
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(255, 200, 120)
	part.Size = Vector3.new(0.5, 0.5, 0.5)
	part.CFrame = CFrame.new(pos)
	part.Parent = Workspace
	Debris:AddItem(part, IMPACT_LIFETIME)
end

-- Called once per shot with the gun's recoil profile.
function WeaponEffects.onFire(recoilProfile: Types.RecoilProfile)
	recoverRate = recoilProfile.recover
	recoil += Vector2.new(recoilProfile.vertical, (math.random() * 2 - 1) * recoilProfile.horizontal)

	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local origin = camera.CFrame.Position
	local direction = camera.CFrame.LookVector
	local result = Workspace:Raycast(origin, direction * MAX_RANGE, raycastParams())
	local finish = if result then result.Position else origin + direction * MAX_RANGE

	local muzzle = (camera.CFrame * CFrame.new(0.6, -0.6, -1)).Position
	spawnTracer(muzzle, finish)
	if result then
		spawnImpact(finish)
	end
end

function WeaponEffects.start()
	RunService:BindToRenderStep("WeaponRecoil", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		if recoil.Magnitude > 0.01 then
			local camera = Workspace.CurrentCamera
			if camera then
				-- Positive pitch kicks the view UP.
				camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(recoil.X), math.rad(recoil.Y), 0)
			end
		end
		recoil = recoil:Lerp(Vector2.zero, math.min(dt * recoverRate, 1))
	end)
end

return WeaponEffects
