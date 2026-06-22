--!strict
--[[
	GameManager.server.luau
	Server entry point for the Game place. Boots core systems in two phases
	(Init -> Start) and owns the player lifecycle. Gameplay services (rounds,
	zombies, weapons) are registered here as they land in Epic 1.

	No yields run at require time (SE-8): this Script drives initialization.
]]

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Server = ServerScriptService:WaitForChild("Server")

local RemoteHandler = require(Server.RemoteHandler)
local SessionService = require(Server.Services.SessionService)
local ArenaService = require(Server.Services.ArenaService)
local ZombieService = require(Server.Services.ZombieService)
local WeaponService = require(Server.Services.WeaponService)
local WallBuyService = require(Server.Services.WallBuyService)
local MysteryBoxService = require(Server.Services.MysteryBoxService)
local PackAPunchService = require(Server.Services.PackAPunchService)
local RoundService = require(Server.Services.RoundService)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local function onPlayerAdded(player: Player)
	SessionService.create(player)
	-- Hand the client a green light once its server session exists.
	RemoteHandler.fireClient(Remotes.Names.SessionReady, player)
	print(`[GameManager] Session ready for {player.Name}`)
end

local function onPlayerRemoving(player: Player)
	SessionService.remove(player)
	RemoteHandler.cleanupPlayer(player)
end

local function init()
	print("[GameManager] Initializing...")

	RemoteHandler.init()
	RemoteHandler.createRemote(Remotes.Names.SessionReady, "Event")
	RemoteHandler.createRemote(Remotes.Names.PlayerStats, "Event")

	-- HUD requests a full state push once its listeners are connected.
	RemoteHandler.register({
		Name = Remotes.Names.RequestSync,
		Type = "Event",
		Handler = function(player: Player)
			WeaponService.pushState(player)
			SessionService.pushStats(player)
			RoundService.pushState(player)
		end,
		RateLimit = 5,
	})

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	-- Players who joined before this script ran (Studio fast-start edge case).
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	print("[GameManager] Initialization complete")
end

local function start()
	-- Build the arena: registers collision groups and creates spawn nodes.
	ArenaService.build()
	-- Prepare the zombie template + weapons, then start the co-op wave loop.
	ZombieService.init()
	WeaponService.init()
	-- Buy stations depend on the arena (placement) and weapons (give on purchase).
	WallBuyService.build()
	MysteryBoxService.build()
	PackAPunchService.build()
	RoundService.start()
	print("[GameManager] Started")
end

game:BindToClose(function()
	-- MVP is session-only: nothing to persist yet. ProfileStore save lands in Epic 4.
	print("[GameManager] Shutting down")
end)

init()
start()
