--!strict
--[[
	ZombieConfig.luau
	Difficulty scaling for zombies, expressed as TUNABLE FORMULAS — no per-round
	hardcoded special cases. This module is PURE (no Roblox APIs) so it can be unit
	tested with Lune (see tests/).

	Spec:
	- Health: flat increase per round up to round 9, then +10% compounding each round.
	- Speed:  walk -> trot -> sprint -> super-sprint as rounds climb.
	- Concurrent zombie count is hard-capped.
]]

local ZombieConfig = {}

-- ---- Tunables -------------------------------------------------------------

-- Health
ZombieConfig.BASE_HEALTH = 150 -- round 1 health
ZombieConfig.FLAT_HEALTH_PER_ROUND = 100 -- added each round through the linear phase
ZombieConfig.HEALTH_LINEAR_UNTIL_ROUND = 9 -- last round of flat growth
ZombieConfig.HEALTH_GROWTH = 0.10 -- compounding multiplier per round after the linear phase

-- Movement: WalkSpeed per tier, and the last round each tier applies to.
ZombieConfig.SPEED_TIERS = {
	{ name = "walk", until_round = 3, walkSpeed = 8 },
	{ name = "trot", until_round = 6, walkSpeed = 12 },
	{ name = "sprint", until_round = 9, walkSpeed = 16 },
	{ name = "superSprint", until_round = math.huge, walkSpeed = 22 },
}

-- Spawn pool per round
ZombieConfig.BASE_SPAWN = 6
ZombieConfig.SPAWN_PER_ROUND = 2
ZombieConfig.PLAYER_SCALE = 0.5 -- extra fraction of the pool per additional player

-- Concurrency / combat / rewards
ZombieConfig.MAX_CONCURRENT = 24 -- hard cap on alive zombies at once
ZombieConfig.CONTACT_DAMAGE = 20 -- damage per melee hit on a player
ZombieConfig.ATTACK_COOLDOWN = 1.0 -- seconds between a zombie's melee hits
ZombieConfig.POINTS_PER_HIT = 10 -- awarded to the shooter on a non-killing hit
ZombieConfig.POINTS_PER_KILL = 50 -- bonus awarded on a kill (on top of the hit)

-- AI tuning
ZombieConfig.ATTACK_RANGE = 5 -- studs; within this a zombie melees its target
ZombieConfig.REPATH_INTERVAL = 0.5 -- seconds between path recomputes (staggered per zombie)

-- ---- Derived formulas (pure) ---------------------------------------------

-- Zombie max health for a given round (integer).
function ZombieConfig.getHealth(round: number): number
	local linearCapRound = ZombieConfig.HEALTH_LINEAR_UNTIL_ROUND
	if round <= linearCapRound then
		return ZombieConfig.BASE_HEALTH + ZombieConfig.FLAT_HEALTH_PER_ROUND * (round - 1)
	end

	local healthAtCap = ZombieConfig.BASE_HEALTH + ZombieConfig.FLAT_HEALTH_PER_ROUND * (linearCapRound - 1)
	local exponent = round - linearCapRound
	local scaled = healthAtCap * (1 + ZombieConfig.HEALTH_GROWTH) ^ exponent
	return math.floor(scaled + 0.5)
end

-- The active speed tier for a round (returns the tier table).
function ZombieConfig.getSpeedTier(round: number): { name: string, until_round: number, walkSpeed: number }
	for _, tier in ZombieConfig.SPEED_TIERS do
		if round <= tier.until_round then
			return tier
		end
	end
	-- SPEED_TIERS always ends with until_round = math.huge, so this is unreachable;
	-- return the last tier defensively only at a real boundary.
	return ZombieConfig.SPEED_TIERS[#ZombieConfig.SPEED_TIERS]
end

-- Zombie WalkSpeed for a round.
function ZombieConfig.getWalkSpeed(round: number): number
	return ZombieConfig.getSpeedTier(round).walkSpeed
end

-- Total zombies to spawn this round, scaled by player count (integer >= 1).
function ZombieConfig.getSpawnCount(round: number, playerCount: number): number
	local base = ZombieConfig.BASE_SPAWN + ZombieConfig.SPAWN_PER_ROUND * round
	local multiplier = 1 + ZombieConfig.PLAYER_SCALE * (math.max(playerCount, 1) - 1)
	return math.ceil(base * multiplier)
end

return ZombieConfig
