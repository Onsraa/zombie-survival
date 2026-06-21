--!strict
--[[
	Types.luau
	Shared weapon type definitions. Pure (returns nil, exports types only).
]]

-- Purely visual camera kick per shot (COD "recoil" ≈ animation). Degrees + recover speed.
export type RecoilProfile = {
	vertical: number,
	horizontal: number,
	recover: number,
}

-- The authoritative accuracy mechanic: a spray cone that blooms with sustained fire.
-- All values in degrees (recover is degrees/second).
export type SpreadProfile = {
	base: number,
	max: number,
	bloomPerShot: number,
	recover: number,
}

-- Asset references (placeholders for now; populated when assets exist).
export type GunAssets = {
	model: string?,
	fireSound: string?,
	reloadSound: string?,
	fireAnim: string?,
	reloadAnim: string?,
}

export type GunDef = {
	id: string,
	name: string,
	category: string, -- Enums.Category
	fireMode: string, -- Enums.FireMode
	fireType: string, -- Enums.FireType
	rpm: number, -- rate of fire; cooldown = 60 / rpm
	damage: number,
	headshotMultiplier: number,
	penetration: number, -- number of zombies a bullet passes through (1 = no pierce)
	penetrationFalloff: number, -- damage multiplier applied per zombie already pierced
	range: number,
	pellets: number?, -- Shotgun: pellets per shot
	spread: SpreadProfile,
	recoil: RecoilProfile,
	magSize: number,
	reserveAmmo: number,
	reloadTime: number,
	wallBuyCost: number?, -- nil = not on a wall (box-only / starting)
	ammoCost: number,
	assets: GunAssets,
	upgrade: string?, -- Pack-a-Punch variant id (Epic 3) — schema-ready, unused now
	burstCount: number?, -- Burst fire mode: shots per pull
}

-- Passed by WeaponService to a fire behavior for one trigger pull.
export type FireContext = {
	player: Player,
	gun: GunDef,
	origin: Vector3, -- camera position (validated near the player)
	direction: Vector3, -- aim direction (camera look)
	spreadDeg: number, -- current accuracy cone for this shot
	character: Instance, -- excluded from raycasts
	damageZombie: (model: Model, damage: number, killer: Player?) -> (),
	reportHit: (headshot: boolean) -> (), -- call once if the shot connected (HUD marker)
	-- AoE: damage + blow the legs off (→ crawl) for zombies in the blast. Returns hit count.
	explode: (position: Vector3, radius: number, damage: number, killer: Player?) -> number,
}

return nil
