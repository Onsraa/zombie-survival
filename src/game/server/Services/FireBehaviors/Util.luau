--!strict
--[[
	Util.luau (FireBehaviors)
	Shared Roblox-bound helpers for the fire behaviors: raycast params, spread cone
	application, and zombie lookups. The pure math lives in shared/Weapons/Ballistics.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)

local Util = {}

function Util.makeParams(exclude: { Instance }): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	return params
end

-- Rotate a direction by a random angle within a cone of `spreadDeg` degrees.
function Util.applySpread(direction: Vector3, spreadDeg: number): Vector3
	if spreadDeg <= 0 then
		return direction.Unit
	end
	local rad = math.rad(spreadDeg)
	local base = CFrame.lookAt(Vector3.zero, direction)
	local h = (math.random() * 2 - 1) * rad
	local v = (math.random() * 2 - 1) * rad
	return (base * CFrame.Angles(v, h, 0)).LookVector
end

-- Walk up from a hit part to the tagged Zombie model, if any.
function Util.getZombieFromPart(part: BasePart): Model?
	local current: Instance? = part
	while current do
		if current:IsA("Model") and CollectionService:HasTag(current, Constants.Tags.Zombie) then
			return current
		end
		current = current.Parent
	end
	return nil
end

return Util
