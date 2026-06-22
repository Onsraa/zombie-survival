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
- [x] ZombieController ported to src/ (gore: head<15% near death; legs detach on explosion impact→crawl; resilient animations)
- [x] Deleted ZombieDemo + in-place ZombieController + stray ZombiePreview model
- [ ] PROD: upload the 6 KeyframeSequence animations → reference as Animation (AnimationId) for playback in published game
- [ ] Decide art versioning: commit base place vs export Assets → assets.rbxmx (model+animations not yet in git)

## Sprint 4 — Weapons (core ✅, wall-buys pending)
- [x] WeaponService: server-authoritative raycast hitscan, ammo, reload (verified: 8 shots = 200 dmg, tamper = 0)
- [x] Pistol start; points earn via damageZombie (hit/kill, server-side — no client points remote)
- [x] WeaponController: desktop mouse (semi/auto) + mobile ContextActionService shoot/reload
- [x] Fixed: round spawn loop stops on game over (generation guard) — verified no over-spawn (R1 caps at 8)
- [x] Wall-buys: arena pedestals + ProximityPrompt → points SPEND — gun buy (`wallBuyCost`) + ammo refill (`ammoCost`), server-auth proximity re-check (`WallBuyService`). MCP-verified: 4 pedestals, afford/deduct/swap, no charge when ammo full

## Sprint 5 — roblox-ts + React HUD ✅
- [x] roblox-ts toolchain + @rbxts/react UI sub-project (ui/), Rojo-wired (rbxts_include + @rbxts/@rbxts-js scopes + UI out)
- [x] HUD: round, health bar, points, ammo, zombies remaining — verified rendering live
- [x] PlayerStats + RequestSync remotes; HUD syncs current state on mount (ammo shows immediately)
- [x] Mobile-safe layout (UDim2.fromScale, CoreUISafeInsets)
- [ ] Mobile device-simulator pass (rbx-device-simulator-lua) across phone/tablet

## FPS feel ✅
- [x] First-person locked camera + center crosshair
- [x] Tracers + impact sparks (client cosmetic, immediate) — recoil camera-kick later removed (see Latest fixes)
- [x] Hit markers (server ShotResult → HUD, white / red-headshot)
- [ ] Gun viewmodel + muzzle flash (needs a gun model asset)
- [ ] Sound (gunshot / reload / hit) — needs audio asset IDs

## Weapon system (modular) ✅
- [x] Data-driven GunDef + GunRegistry (Weapons/Enums/Types/Ballistics); fire-behavior strategies (Hitscan/Shotgun/Projectile)
- [x] Spread (spray) accuracy + bloom = real mechanic; RPM cooldown; penetration + falloff (recoil = data only, no camera kick)
- [x] Camera-origin aim (bullets hit the crosshair); hide cursor; fire modes (auto/semi/single/burst)
- [x] Starter guns: M1911 · M16 · AK74u · Olympia · RPK · Ray Gun. Verified: registry valid, hitscan damage, RPK pierces 2
- [ ] Backlog: add the rest of the COD roster as GunDef data; exotic behaviors (Melee/grenades/Thundergun); per-gun models/sounds/anims; Pack-a-Punch upgrades (Epic 3)

## Latest fixes (combat + movement) ✅ — MCP-verified
- [x] Removed recoil camera-kick entirely (WeaponEffects = tracer/impact only; `recoil` profile kept as schema-ready data for a future viewmodel animation)
- [x] Exact-cursor aim: `spread.base = 0` on standard guns (first shot dead-on) + crosshair at true viewport center (`ScreenInsets = None`). Verified: 40 dmg to a target on the screen-center ray at 30 studs
- [x] Impact-zone gore: legs detach via `ZombieService.explode` (grenade / Ray-Gun ground shot) → crawl; removed the health-based leg detach. Verified: blast detaches legs + 100 dmg; 6% HP leaves legs intact (head still pops near death)
- [x] Movement stances (`MovementController`): Stand 16 / Crouch `C` 8 / Prone `X` 4 / Sprint hold `LeftShift` 22, sprint blocked while crouched/prone; `CameraOffset` view drop; ContextActionService touch buttons for mobile. Verified live via simulated input
- [ ] Asset gap: true third-person crouch/prone *pose* + gun viewmodel need rig animations (mechanics complete; poses pending upload, same gap as zombie anims)

## Latest fixes (ammo · anims · death) ✅ — MCP-verified
- [x] Weapon fires off authoritative `WeaponState`: client gates on ammo/reloading (no tracer/effect when empty or reloading) + optimistic mag decrement + **auto-reload** on empty. Verified: mag 8→0 auto-reloads to 8 (reserve 80→72), server never goes negative. Server unchanged
- [x] Zombie animations via uploaded AnimationIds — new `shared/Config/ZombieAnimations.luau` (fill after exporting); `ZombieController` prefers ids, falls back to the committed KeyframeSequence for Studio preview. Fixes arms-forward `ZombieWalk` not posing at runtime (temp KS id loads a track but doesn't pose). **User action: export the 6–7 clips, paste ids**
- [x] Explicit immediate death: `BreakJointsOnDeath=false` + `ZombieController:Collapse()` → scripted ragdoll (loosen R6 joints incl. `Root` + drop impulse), or a `Death` animation if its id is set. Verified live + fresh: all 6 core joints loosen instantly, killing the ~0.2s ambiguous flop

## Next options
- [x] Wall-buys (Sprint 4b): arena pedestals + ProximityPrompt → points SPEND (WallBuyService)
- [ ] Upload the 6 zombie animations → AnimationId (production playback)
- [x] Epic 3: Mystery Box + Pack-a-Punch (box weighted random roll · PaP data variants via `GunDef.upgrade` · shared `BuyStation`) — MCP-verified
- [x] Epic 3: Power-ups (drop-on-kill → team-wide Max Ammo / Nuke / Insta-Kill / Double Points · `CombatModifiers` flags · HUD banner) — MCP-verified
- [x] Epic 3: Perks (Juggernog / Speed Cola / Double Tap via `BuyStation` · per-player `WeaponService` reload/fire-rate modifiers · Jugg max-health · lost on respawn) — MCP-verified
- [x] Epic 3: Down & revive (downed/ragdoll/bleed-out · teammate revive prompt · co-op wipe = all-down · Quick Revive solo self-revive · `PlayerState` leaf + routed melee) — MCP-verified
- [x] Epic 3: Barriers/windows (each zombie breaches its perimeter window before chasing · repair planks for points · Carpenter power-up) — MCP-verified (live zombies tore 30 planks, 5/6 breached)
- [x] **Epic 3 signature systems COMPLETE**: Mystery Box · Pack-a-Punch · Power-ups · Perks · Down & Revive · Barriers
- [x] Epic 2 pt1: Lobby place (`lobby.project.json`) — party system (create/join/leave/ready/leader-start) · pure `Party` model (Lune-tested, 27/27) · Luau party UI. Gate-verified (open the lobby place in Studio to play-test)
- [ ] Epic 2 pt2: matchmaking + reserved-server teleport (`ReserveServer`/`TeleportAsync`/`TeleportData` + game `GetJoinData`) — needs published universe + `GAME_PLACE_ID`

## Decisions
- UI = roblox-ts + **@rbxts/react**, hybrid (UI ↔ gameplay only via RemoteEvents). Toolchain stood up at **S5**. Node v24 / npm 11 present.

## Parking lot (decide later)
- StreamingEnabled on/off (decide by arena part budget in Sprint 1–2)
- Lighting Technology Voxel vs Future (perf vs atmosphere — revisit in Epic 5 polish)
- Wally dep for cleanup util vs vendored Trove (currently vendored)
- Zombie separation: non-colliding zombies overlap into one mass on the target — add light flocking/offset for visual spread (polish, Epic 5)
- Zombie pooling: revisit only if profiling on real mobile shows clone/destroy churn matters
