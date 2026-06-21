--!strict
--[[
	MovementController.luau
	First-person stance + sprint for the local player.

	Stances (Stand / Crouch / Prone) are mutually exclusive postures; Sprint is a
	speed modifier available only while standing. Each stance sets the Humanoid's
	WalkSpeed (the real movement change) and a first-person CameraOffset so the view
	height reflects the posture immediately — no animation asset required. (A true
	third-person prone *pose* needs a rig animation, an asset gap shared with the gun
	and zombie animations; the mechanic here is complete and correct without it.)

	Inputs (ContextActionService → auto on-screen buttons on touch devices):
		Sprint : hold LeftShift / ButtonL3 / [Sprint]
		Crouch : toggle C / ButtonB / [Crouch]
		Prone  : toggle X / ButtonY / [Prone]
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)

local STANCE = { Stand = "Stand", Crouch = "Crouch", Prone = "Prone" }

-- First-person camera drop per stance (studs).
local CAMERA_OFFSET = {
	[STANCE.Stand] = Vector3.zero,
	[STANCE.Crouch] = Vector3.new(0, -1.5, 0),
	[STANCE.Prone] = Vector3.new(0, -2.8, 0),
}

local MovementController = {}

local player = Players.LocalPlayer
local humanoid: Humanoid? = nil
local stance = STANCE.Stand
local sprinting = false

local function speedFor(): number
	if stance == STANCE.Prone then
		return Constants.PRONE_SPEED
	elseif stance == STANCE.Crouch then
		return Constants.CROUCH_SPEED
	elseif sprinting then
		return Constants.SPRINT_SPEED
	end
	return Constants.WALK_SPEED
end

local function apply()
	local hum = humanoid
	if not hum then
		return
	end
	hum.WalkSpeed = speedFor()
	hum.CameraOffset = CAMERA_OFFSET[stance]
end

local function setStance(nextStance: string)
	stance = nextStance
	if stance ~= STANCE.Stand then
		sprinting = false -- can't sprint while crouched or prone
	end
	apply()
end

local function onSprint(_, state: Enum.UserInputState): Enum.ContextActionResult
	sprinting = state == Enum.UserInputState.Begin and stance == STANCE.Stand
	apply()
	return Enum.ContextActionResult.Pass
end

local function onCrouch(_, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		setStance(if stance == STANCE.Crouch then STANCE.Stand else STANCE.Crouch)
	end
	return Enum.ContextActionResult.Pass
end

local function onProne(_, state: Enum.UserInputState): Enum.ContextActionResult
	if state == Enum.UserInputState.Begin then
		setStance(if stance == STANCE.Prone then STANCE.Stand else STANCE.Prone)
	end
	return Enum.ContextActionResult.Pass
end

local function bindCharacter(character: Model)
	humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	stance = STANCE.Stand
	sprinting = false
	apply()
end

function MovementController.start()
	if player.Character then
		bindCharacter(player.Character)
	end
	player.CharacterAdded:Connect(bindCharacter)

	ContextActionService:BindAction("Sprint", onSprint, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
	ContextActionService:BindAction("Crouch", onCrouch, true, Enum.KeyCode.C, Enum.KeyCode.ButtonB)
	ContextActionService:BindAction("Prone", onProne, true, Enum.KeyCode.X, Enum.KeyCode.ButtonY)
end

return MovementController
