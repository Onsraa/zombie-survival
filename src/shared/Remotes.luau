--!strict
--[[
	Remotes.luau
	Single source of truth for remote names, shared by server and client.
	The server (RemoteHandler) creates the instances; both sides resolve them by name.
	New remotes are added here as each system lands.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {
	-- Names grouped by direction for readability.
	Names = {
		-- Server -> Client
		SessionReady = "SessionReady", -- fired once per player after their session is created
		RoundState = "RoundState", -- round phase/number/zombies snapshot for the HUD
		WeaponState = "WeaponState", -- current weapon ammo/reload for the HUD
		-- Client -> Server
		Shoot = "Shoot", -- fire intent (aim direction)
		Reload = "Reload", -- reload request
	},
}

local WAIT_TIMEOUT = 10

-- Resolve a remote instance by name. Safe on both sides (waits with a timeout, SE-11).
function Remotes.get(name: string): RemoteEvent?
	local folder = ReplicatedStorage:WaitForChild("Remotes", WAIT_TIMEOUT)
	if not folder then
		warn(`[Remotes] Remotes folder not found after {WAIT_TIMEOUT}s`)
		return nil
	end

	local remote = folder:WaitForChild(name, WAIT_TIMEOUT)
	if not remote or not remote:IsA("RemoteEvent") then
		warn(`[Remotes] RemoteEvent "{name}" not found`)
		return nil
	end

	return remote
end

return Remotes
