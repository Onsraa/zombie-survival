--!strict
--[[
	WeaponEffects.luau
	Client-side shot cosmetics: bullet tracers + impact sparks. No camera recoil —
	accuracy is the server's spread, and any gun "kick" will be a viewmodel animation
	once gun models exist (per design, COD recoil ≈ animation, not camera movement).
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local WeaponEffects = {}

local TRACER_LIFETIME = 0.05
local IMPACT_LIFETIME = 0.08
local MAX_RANGE = 600

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

-- Called once per shot: draw a tracer from the muzzle to where the camera points.
function WeaponEffects.onFire()
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

return WeaponEffects
