--!strict
--[[
	WeaponEffects.luau
	Client-side shot cosmetics for FPS feel: camera recoil, bullet tracers, and
	impact sparks. These are purely visual and run immediately on fire (no server
	round-trip) — the server remains authoritative for damage. Hit markers are
	driven separately by the server's ShotResult remote (HUD).
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local WeaponEffects = {}

local RECOIL_PITCH = 1.6 -- degrees of upward kick per shot
local RECOIL_YAW = 0.5 -- random horizontal kick (degrees)
local RECOIL_RECOVER = 12 -- higher = snappier recovery
local TRACER_LIFETIME = 0.05
local IMPACT_LIFETIME = 0.08
local MAX_RANGE = 400

-- Accumulated transient recoil offset (x = pitch, y = yaw), in degrees. Decays to 0.
local recoil = Vector2.zero

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

-- Called once per shot (after the fire intent is sent).
function WeaponEffects.onFire()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	recoil += Vector2.new(RECOIL_PITCH, (math.random() - 0.5) * 2 * RECOIL_YAW)

	local origin = camera.CFrame.Position
	local direction = camera.CFrame.LookVector
	local result = Workspace:Raycast(origin, direction * MAX_RANGE, raycastParams())
	local finish = if result then result.Position else origin + direction * MAX_RANGE

	-- Start the tracer below-right of the eyeline so it reads as gunfire.
	local muzzle = (camera.CFrame * CFrame.new(0.6, -0.6, -1)).Position
	spawnTracer(muzzle, finish)
	if result then
		spawnImpact(finish)
	end
end

function WeaponEffects.start()
	-- Apply (and recover) recoil after the default camera updates each frame.
	RunService:BindToRenderStep("WeaponRecoil", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		if recoil.Magnitude > 0.01 then
			local camera = Workspace.CurrentCamera
			if camera then
				-- Negative pitch rotates the view upward (gun climb).
				camera.CFrame = camera.CFrame * CFrame.Angles(math.rad(-recoil.X), math.rad(recoil.Y), 0)
			end
		end
		recoil = recoil:Lerp(Vector2.zero, math.min(dt * RECOIL_RECOVER, 1))
	end)
end

return WeaponEffects
