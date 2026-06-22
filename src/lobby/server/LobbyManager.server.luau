--!strict
--[[
	LobbyManager.server.luau (Lobby place)
	Entry point for the Lobby place: builds the social hub (a simple greybox floor + spawn)
	and starts the party system. Matchmaking/teleport into the Game place lands in pt2.
]]

local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local PartyService = require(ServerScriptService.LobbyServer.PartyService)

local function buildHub()
	if Workspace:FindFirstChild("Lobby") then
		return
	end
	local model = Instance.new("Model")
	model.Name = "Lobby"

	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.Size = Vector3.new(120, 1, 120)
	floor.Position = Vector3.new(0, 0, 0)
	floor.Color = Color3.fromRGB(58, 58, 70)
	floor.Material = Enum.Material.SmoothPlastic
	floor.Parent = model

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = Vector3.new(0, 1, 0)
	spawn.Color = Color3.fromRGB(60, 130, 90)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = model

	model.Parent = Workspace
end

buildHub()
PartyService.init()
print("[LobbyManager] Lobby ready")
