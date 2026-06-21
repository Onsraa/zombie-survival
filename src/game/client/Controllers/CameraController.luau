--!strict
--[[
	CameraController.luau
	Locks the camera to first-person (COD-style FPS). The aim direction used by
	WeaponController is the camera's LookVector, so shots line up with the center
	crosshair drawn by the HUD. CameraMode is a Player property and persists across
	respawns, so it only needs to be set once.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local CameraController = {}

function CameraController.start()
	Players.LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
	-- Hide the OS cursor; the HUD crosshair is the aim point.
	UserInputService.MouseIconEnabled = false
end

return CameraController
