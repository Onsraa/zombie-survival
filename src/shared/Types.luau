--!strict
--[[
	Types.luau
	Shared Luau type definitions used across server and client.
	Extended per-epic as systems are added.
]]

-- Round lifecycle phases (PvE co-op waves).
export type RoundPhase = "Intermission" | "Active" | "GameOver"

-- Replicated snapshot of round state, broadcast to clients for the HUD.
export type RoundSnapshot = {
	phase: RoundPhase,
	round: number,
	zombiesRemaining: number, -- still to spawn this round + alive
	zombiesAlive: number,
	timeLeft: number?, -- intermission countdown, when applicable
}

-- Server-only, in-memory per-player session state (MVP is session-only; no DataStore).
export type PlayerSession = {
	points: number,
	kills: number,
	joinedAt: number,
}

return nil
