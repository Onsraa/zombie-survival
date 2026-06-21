--!strict
--[[
	RoundService.luau
	The co-op wave loop. A round runs Intermission → Active, and only ends once the
	round's entire spawn pool has been spawned AND every zombie is dead; then the
	next (harder) round begins. If all players are dead mid-round it's Game Over →
	brief reset → restart from round 1.

	Per-round difficulty (count/health/speed) comes from ZombieConfig. Round state is
	broadcast to clients (RoundState remote) for the HUD. Rounds are shared across all
	players in the server (drop-in co-op).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local ZombieConfig = require(ReplicatedStorage.Shared.Config.ZombieConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

local RemoteHandler = require(script.Parent.Parent.RemoteHandler)
local ArenaService = require(script.Parent.ArenaService)
local ZombieService = require(script.Parent.ZombieService)

local SPAWN_INTERVAL = 0.5 -- seconds between individual zombie spawns
local MONITOR_INTERVAL = 0.3 -- round-progress poll cadence
local GAMEOVER_TIME = 6 -- seconds on the Game Over screen before restart
local CHARACTER_LOAD_GRACE = 1 -- seconds for respawned characters to settle

type RoundPhase = Types.RoundPhase
type RoundResult = "complete" | "gameover" | "stopped"

local RoundService = {}

local phase: RoundPhase = "Intermission"
local round = 0
local toSpawn = 0
local spawned = 0
local running = false

-- ---- broadcast ------------------------------------------------------------

local function snapshot(timeLeft: number?): Types.RoundSnapshot
	local alive = ZombieService.getAliveCount()
	return {
		phase = phase,
		round = round,
		zombiesRemaining = (toSpawn - spawned) + alive,
		zombiesAlive = alive,
		timeLeft = timeLeft,
	}
end

local function broadcast(timeLeft: number?)
	RemoteHandler.fireAllClients(Remotes.Names.RoundState, snapshot(timeLeft))
end

-- ---- players --------------------------------------------------------------

local function countAlivePlayers(): number
	local count = 0
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local humanoid = char and char:FindFirstChildOfClass("Humanoid") :: Humanoid?
		if humanoid and humanoid.Health > 0 then
			count += 1
		end
	end
	return count
end

local function spawnPlayer(player: Player)
	player:LoadCharacter()
	local char = player.Character or player.CharacterAdded:Wait()
	local spawns = ArenaService.getPlayerSpawns()
	if char and #spawns > 0 then
		local spawn = spawns[math.random(1, #spawns)]
		char:PivotTo(spawn.CFrame + Vector3.new(0, 4, 0))
	end
end

-- Bring any player without a living character back for the new round.
local function respawnDeadPlayers()
	for _, player in Players:GetPlayers() do
		local char = player.Character
		local humanoid = char and char:FindFirstChildOfClass("Humanoid") :: Humanoid?
		if not (humanoid and humanoid.Health > 0) then
			task.spawn(spawnPlayer, player)
		end
	end
end

-- ---- phases ---------------------------------------------------------------

local function intermission()
	phase = "Intermission"
	toSpawn = 0
	spawned = 0
	print(`[RoundService] Round {round} — intermission`)
	for i = Constants.INTERMISSION_TIME, 1, -1 do
		if not running then
			return
		end
		broadcast(i)
		task.wait(1)
	end
end

local function activeRound(): RoundResult
	phase = "Active"
	local playerCount = math.max(#Players:GetPlayers(), 1)
	toSpawn = ZombieConfig.getSpawnCount(round, playerCount)
	spawned = 0
	print(
		`[RoundService] Round {round} — active, spawning {toSpawn} (hp {ZombieConfig.getHealth(round)}, speed {ZombieConfig.getWalkSpeed(
			round
		)})`
	)
	broadcast()

	-- Spawn the pool over time, never exceeding the concurrency cap.
	task.spawn(function()
		while running and spawned < toSpawn do
			if ZombieService.getAliveCount() < ZombieConfig.MAX_CONCURRENT then
				if ZombieService.spawn(round) then
					spawned += 1
					broadcast()
				end
			end
			task.wait(SPAWN_INTERVAL)
		end
	end)

	-- Monitor for round completion or wipe; broadcast only when the count changes.
	local lastRemaining = -1
	while running do
		if #Players:GetPlayers() > 0 and countAlivePlayers() == 0 then
			return "gameover"
		end
		if spawned >= toSpawn and ZombieService.getAliveCount() == 0 then
			return "complete"
		end
		local remaining = (toSpawn - spawned) + ZombieService.getAliveCount()
		if remaining ~= lastRemaining then
			lastRemaining = remaining
			broadcast()
		end
		task.wait(MONITOR_INTERVAL)
	end
	return "stopped"
end

local function gameOver()
	phase = "GameOver"
	print(`[RoundService] Game over at round {round}`)
	broadcast()
	ZombieService.despawnAll()
	task.wait(GAMEOVER_TIME)
	round = 0 -- next loop iteration restarts at round 1
end

-- ---- public ---------------------------------------------------------------

function RoundService.start()
	if running then
		return
	end
	running = true

	-- Round-based respawning: we control character spawns, not Roblox auto-spawn.
	Players.CharacterAutoLoads = false
	RemoteHandler.createRemote(Remotes.Names.RoundState, "Event")

	task.spawn(function()
		while running do
			round += 1
			respawnDeadPlayers()
			task.wait(CHARACTER_LOAD_GRACE)

			intermission()
			local result = activeRound()
			if result == "gameover" then
				gameOver()
			end
		end
	end)

	print("[RoundService] Started")
end

function RoundService.getSnapshot(): Types.RoundSnapshot
	return snapshot()
end

return RoundService
