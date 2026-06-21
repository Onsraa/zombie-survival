--!strict
--[[
	Constants.luau
	Shared, tunable values used by both server and client.
	Gameplay-balance numbers that belong to a system live in that system's Config
	module (see Config/* and Weapons/*).
]]

local Constants = {
	-- Round pacing (seconds)
	INTERMISSION_TIME = 10,
	ROUND_START_DELAY = 3,

	-- Player defaults + movement stances (studs/sec)
	MAX_HEALTH = 100,
	WALK_SPEED = 16,
	SPRINT_SPEED = 22,
	CROUCH_SPEED = 8,
	PRONE_SPEED = 4,

	-- Remote security (consumed by RemoteHandler)
	MAX_REMOTE_RATE = 30, -- max fires per window before rate-limiting
	REMOTE_WINDOW = 10, -- rate-limit window (seconds)
	REMOTE_KICK_THRESHOLD = 8, -- kick after this many violations

	-- CollectionService tags (single source of truth)
	Tags = {
		Zombie = "Zombie",
		ZombieSpawn = "ZombieSpawn",
		PlayerSpawn = "PlayerSpawn",
	},

	-- Collision groups (registered by ArenaService)
	CollisionGroups = {
		Zombies = "Zombies",
		Characters = "Characters",
	},
}

return Constants
