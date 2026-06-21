# Roadmap

Co-op round-based zombie survival (COD-zombies style). MVP-first, iterative. Each sprint ends
with a concrete verification (MCP play-test and/or Lune unit test) before moving on.

Status legend: ✅ done · 🚧 in progress · ⬜ not started

---

## Epic 0 — Foundation & Tooling
| Sprint | Deliverable | Verify | Status |
|---|---|---|---|
| S0 | rokit + wally + selene + stylua + lune; `src/` layout; ported scaffold (session-only); `docs/` | `rojo build` ok; selene + stylua clean; MCP play-test shows init/start logs, no errors | ✅ |

## Epic 1 — Core Survival Loop (Game place = MVP vertical slice)
| Sprint | Deliverable | Verify | Status |
|---|---|---|---|
| S1 | Arena (player spawns + perimeter zombie nodes); `ZombieConfig`/`WeaponConfig` | arena loads, nodes tagged; Lune tests of difficulty formulas (r=1,9,10,20) | ✅ |
| S2 | `ZombieService`: pooled Humanoid zombies, throttled pathfinding, melee, death→points, collision group, cap 24 | spawn 24 healthy FPS (mobile emu); path to player; cap holds | ✅ |
| S3 | `RoundService`: wave state machine, scaling, "pool exhausted & all dead → next", intermission; co-op shared; mid-round join = spectate | 3 rounds solo + 2-client; scaling correct; no leaks | ✅ |
| S4 | `WeaponService` raycast hitscan (server-auth, ammo, reload); pistol + wall-buys; points earn/spend | 2-client kills; client point-tamper rejected; wall-buy works | 🚧 (shooting+points ✅; wall-buys pending) |
| S5 | Stand up roblox-ts + @rbxts/react UI toolchain; HUD (round/health/points/ammo/zombies-left) in React; mobile touch controls; death→spectate; all-down→game over→restart | device simulator phone/tablet; full match on touch | ⬜ |

## Epic 2 — Lobby, Parties & Server Orchestration
| Sprint | Deliverable | Verify | Status |
|---|---|---|---|
| S6 | Lobby place: hub, party UI (create/join/leave/ready), queue | party + UI + queue logic in Studio (mockable) | ⬜ |
| S7 | `MatchmakingService`: ReserveServer + TeleportAsync + TeleportData; Game place seats party; retry/errors; rejoin; BindToClose | full party→reserved-server→match on a published test universe (needs PlaceIds) | ⬜ |

## Epic 3 — Signature COD Systems
| Sprint | Deliverable | Verify | Status |
|---|---|---|---|
| S8 | Perks + Power-ups (Jugg/Speed…; Max Ammo, Insta-Kill, Nuke, Double Points) | integration + Lune drop-table tests | ⬜ |
| S9 | Mystery Box + Pack-a-Punch | integration + Lune upgrade-math tests | ⬜ |
| S10 | Barriers/Windows (breach + repair) | integration play-test | ⬜ |
| S11 | Down & Revive (bleed-out, revive, co-op fail) | integration + Lune bleed-out timing tests | ⬜ |

## Epic 4 — Persistence & Monetization foundation
| Sprint | Deliverable | Verify | Status |
|---|---|---|---|
| S12 | ProfileStore (SE-1): best round, total kills, unlock currency | rejoin persists | ⬜ |
| S13 | Loot boxes (weapon/clothing skins), `ProcessReceipt` (SE-3), inventory + equip, lobby shop | receipt double-fire grants once; skins equip/replicate | ⬜ |

## Epic 5 — Performance, Polish & Ship
| Sprint | Deliverable | Verify | Status |
|---|---|---|---|
| S14 | Parallel Luau AI (only if profiled-needed); StreamingEnabled tuning; part-count/MicroProfiler audit | 60fps target @ round 20, 24 zombies, 4 players (mobile emu) | ⬜ |
| S15 | VFX/audio/animation polish; security audit; publish checklist; analytics | audits pass | ⬜ |

---

### Dependencies / flags
- **Epic 2 full teleport** needs published PlaceIds (your Roblox universe). Gameplay is built/tested
  single-place first so this never blocks the core.
- **24 Humanoids on mobile**: mitigated by cap + collision groups + pooling + throttled AI first;
  escalate to custom movement / parallel Luau only if profiling (Epic 5) demands.
