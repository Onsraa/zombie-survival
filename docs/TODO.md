# TODO / Backlog

Actionable, near-term. Older items move to "Done". See ROADMAP.md for the big picture.

## Sprint 0 — Foundation (current)
- [x] Pin toolchain via rokit (rojo, wally, selene, stylua, lune)
- [x] Config: wally.toml, selene.toml, stylua.toml, .luaurc, .vscode
- [x] Restructure `src/` (shared, game/server, game/client); remove hello-world stubs
- [x] Shared: Constants, Types, Remotes, Config/ZombieConfig, Config/WeaponConfig, Util/Trove
- [x] Server: GameManager (Init/Start), RemoteHandler, Services/SessionService
- [x] Client: ClientController
- [x] docs/ (ROADMAP, FEATURES, TODO, ARCHITECTURE)
- [x] `rojo build` validates; selene + stylua clean
- [x] Sync to Studio + MCP play-test: init/start logs, session handshake, no errors

## Sprint 1 — Arena + Config tests ✅
- [x] ArenaService: enclosed greybox arena, player spawns, perimeter zombie nodes (tagged)
- [x] Register collision groups (Zombies non-collidable with each other; Characters)
- [x] tests/: Lune unit tests for ZombieConfig (16/16)
- [x] Verify in Studio via MCP (Arena 23 descendants, 12 nodes / 4 spawns tagged, groups set) + screenshot

## Sprint 2 — ZombieService ✅
- [x] R6 greybox zombie template (CreateHumanoidModelFromDescriptionAsync); clone/destroy — pooling deferred (measured 113fps @ 24, YAGNI for now)
- [x] Spawn at tagged nodes; Zombies collision group; tag Zombie; server network ownership
- [x] Throttled, staggered pathfinding chase (CreatePath/ComputeAsync, MoveTo next waypoint, direct fallback)
- [x] Melee contact damage (verified: swarm killed player 100→0); death → points hook + Trove cleanup
- [x] Hard cap 24 (30 attempts → 24 alive); replication verified (24/24 on client) + 113 fps

## Sprint 3 — RoundService ✅
- [x] Wave state machine: Intermission → Active → (pool exhausted & all dead) → next round
- [x] Per-round scaling via ZombieConfig (count / health / speed) — verified live R1(8,hp150)→R2(10,hp250)
- [x] Round state broadcast (RoundState remote), change-based; client consumer in ClientController
- [x] Co-op shared rounds; CharacterAutoLoads=false + respawn each round; all-down → game over → restart
- [x] Verified: completion + game-over→restart in Studio

## Merge — adopted AI-agent zombie ✅
- [x] Themed Zombie model is the ZombieService template (greybox dropped)
- [x] ZombieController ported to src/ (gore: head<15%, legs<40%→crawl; resilient animations)
- [x] Deleted ZombieDemo + in-place ZombieController + stray ZombiePreview model
- [ ] PROD: upload the 6 KeyframeSequence animations → reference as Animation (AnimationId) for playback in published game
- [ ] Decide art versioning: commit base place vs export Assets → assets.rbxmx (model+animations not yet in git)

## Sprint 4 — Weapons (core ✅, wall-buys pending)
- [x] WeaponService: server-authoritative raycast hitscan, ammo, reload (verified: 8 shots = 200 dmg, tamper = 0)
- [x] Pistol start; points earn via damageZombie (hit/kill, server-side — no client points remote)
- [x] WeaponController: desktop mouse (semi/auto) + mobile ContextActionService shoot/reload
- [x] Fixed: round spawn loop stops on game over (generation guard) — verified no over-spawn (R1 caps at 8)
- [ ] Wall-buys: arena buy spots + Buy remote → points SPEND (rifle/shotgun/ammo)

## Sprint 5 — roblox-ts + React HUD ✅
- [x] roblox-ts toolchain + @rbxts/react UI sub-project (ui/), Rojo-wired (rbxts_include + @rbxts/@rbxts-js scopes + UI out)
- [x] HUD: round, health bar, points, ammo, zombies remaining — verified rendering live
- [x] PlayerStats + RequestSync remotes; HUD syncs current state on mount (ammo shows immediately)
- [x] Mobile-safe layout (UDim2.fromScale, CoreUISafeInsets)
- [ ] Mobile device-simulator pass (rbx-device-simulator-lua) across phone/tablet

## FPS feel ✅
- [x] First-person locked camera + center crosshair
- [x] Recoil (camera kick), tracers + impact sparks (client cosmetic, immediate)
- [x] Hit markers (server ShotResult → HUD, white / red-headshot)
- [ ] Gun viewmodel + muzzle flash (needs a gun model asset)
- [ ] Sound (gunshot / reload / hit) — needs audio asset IDs

## Weapon system (modular) ✅
- [x] Data-driven GunDef + GunRegistry (Weapons/Enums/Types/Ballistics); fire-behavior strategies (Hitscan/Shotgun/Projectile)
- [x] Spread (spray) accuracy + bloom = real mechanic; per-gun visual recoil (up, snappy); RPM cooldown; penetration + falloff
- [x] Camera-origin aim (bullets hit the crosshair); hide cursor; fire modes (auto/semi/single/burst)
- [x] Starter guns: M1911 · M16 · AK74u · Olympia · RPK · Ray Gun. Verified: registry valid, hitscan damage, RPK pierces 2
- [ ] Backlog: add the rest of the COD roster as GunDef data; exotic behaviors (Melee/grenades/Thundergun); per-gun models/sounds/anims; Pack-a-Punch upgrades (Epic 3)

## Next options
- [ ] Wall-buys (Sprint 4b): arena buy spots + Buy remote → points SPEND
- [ ] Upload the 6 zombie animations → AnimationId (production playback)
- [ ] Epic 3 signature systems (perks/box/pack-a-punch/barriers/down&revive)
- [ ] Epic 2 lobby + parties (reserved-server teleport)

## Decisions
- UI = roblox-ts + **@rbxts/react**, hybrid (UI ↔ gameplay only via RemoteEvents). Toolchain stood up at **S5**. Node v24 / npm 11 present.

## Parking lot (decide later)
- StreamingEnabled on/off (decide by arena part budget in Sprint 1–2)
- Lighting Technology Voxel vs Future (perf vs atmosphere — revisit in Epic 5 polish)
- Wally dep for cleanup util vs vendored Trove (currently vendored)
- Zombie separation: non-colliding zombies overlap into one mass on the target — add light flocking/offset for visual spread (polish, Epic 5)
- Zombie pooling: revisit only if profiling on real mobile shows clone/destroy churn matters
