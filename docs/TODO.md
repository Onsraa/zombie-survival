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

## Next — Sprint 3 (RoundService)
- [ ] Wave state machine: Intermission → Active → (pool exhausted & all dead) → next round
- [ ] Per-round scaling via ZombieConfig (spawnWave count / health / speed)
- [ ] Round state broadcast (round #, zombies remaining) via RemoteEvent
- [ ] Co-op shared rounds; player death → spectate; all-down → game over → restart
- [ ] Verify: 3 rounds solo + 2-client; scaling correct; no leaks across rounds

## Decisions
- UI = roblox-ts + **@rbxts/react**, hybrid (UI ↔ gameplay only via RemoteEvents). Toolchain stood up at **S5**. Node v24 / npm 11 present.

## Parking lot (decide later)
- StreamingEnabled on/off (decide by arena part budget in Sprint 1–2)
- Lighting Technology Voxel vs Future (perf vs atmosphere — revisit in Epic 5 polish)
- Wally dep for cleanup util vs vendored Trove (currently vendored)
- Zombie separation: non-colliding zombies overlap into one mass on the target — add light flocking/offset for visual spread (polish, Epic 5)
- Zombie pooling: revisit only if profiling on real mobile shows clone/destroy churn matters
