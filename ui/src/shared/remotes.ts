// Bridge to the Luau gameplay layer. The UI talks to the server only through these
// RemoteEvents (names mirror src/shared/Remotes.luau). No cross-language requires.

const ReplicatedStorage = game.GetService("ReplicatedStorage");

export const RemoteNames = {
	RoundState: "RoundState",
	WeaponState: "WeaponState",
	PlayerStats: "PlayerStats",
	RequestSync: "RequestSync",
	ShotResult: "ShotResult",
} as const;

export interface RoundSnapshot {
	phase: string;
	round: number;
	zombiesRemaining: number;
	zombiesAlive: number;
	timeLeft?: number;
}

export interface WeaponSnapshot {
	weaponId: string;
	magAmmo: number;
	reserveAmmo: number;
	magSize: number;
	reloading: boolean;
}

export interface StatsSnapshot {
	points: number;
	kills: number;
}

export function getRemote(name: string): RemoteEvent | undefined {
	const folder = ReplicatedStorage.WaitForChild("Remotes", 10);
	if (folder === undefined) return undefined;
	const remote = folder.WaitForChild(name, 10);
	if (remote !== undefined && remote.IsA("RemoteEvent")) {
		return remote;
	}
	return undefined;
}
