--!strict
--[[
	ClientController.client.luau
	Client entry point for the Game place. Runs once per player, persists across
	respawns (StarterPlayerScripts). Boots client controllers (input, weapon, HUD)
	as they land in Epic 1. For Sprint 0 it verifies the client<->server pipeline.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local player = Players.LocalPlayer

local function onCharacterAdded(_character: Model)
	print("[ClientController] Character spawned")
end

local function init()
	print("[ClientController] Initializing...")

	local sessionReady = Remotes.get(Remotes.Names.SessionReady)
	if sessionReady then
		sessionReady.OnClientEvent:Connect(function()
			print("[ClientController] Session ready (server handshake received)")
		end)
	end

	-- Consume round-state broadcasts (the S5 React HUD will render these). Connecting
	-- now also keeps the RemoteEvent queue drained. Log only on round change.
	local lastRoundNumber = 0
	local roundState = Remotes.get(Remotes.Names.RoundState)
	if roundState then
		roundState.OnClientEvent:Connect(function(snapshot)
			if typeof(snapshot) == "table" and snapshot.round ~= lastRoundNumber then
				lastRoundNumber = snapshot.round
				print(`[ClientController] Round {snapshot.round} ({snapshot.phase})`)
			end
		end)
	end

	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)

	-- Start client controllers.
	require(script.Parent.Controllers.WeaponController).start()

	print("[ClientController] Initialized")
end

init()
