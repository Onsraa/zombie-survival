# Features

Per-feature spec + status. Status: ✅ done · 🚧 in progress · ⬜ planned.

| Feature | Epic | Spec summary | Status |
|---|---|---|---|
| Toolchain & scaffold | 0 | rokit-pinned tools, Rojo two-place-ready layout, Init/Start bootstrap, central remotes with rate-limit/validation, session-only data | 🚧 |
| Difficulty scaling | 1 | Health flat→×1.1 after R9; speed tiers walk→super-sprint; spawn pool scales w/ round & players; cap 24. Formulas in `ZombieConfig` | 🚧 (config in place) |
| Arena | 1 | Enclosed arena, player spawns, perimeter zombie spawn nodes (tagged) | ⬜ |
| Zombie AI | 1 | Server Humanoid zombies, pooled, throttled `PathfindingService` to nearest player, melee contact damage | ⬜ |
| Round loop | 1 | State machine Intermission→Active→GameOver; round ends when pool exhausted & all dead; co-op shared | ⬜ |
| Weapons & points | 1 | Server-auth hitscan/ammo/reload; modular gun framework; **wall-buys** (ProximityPrompt → points spend on guns + ammo); points earn/spend | ✅ |
| HUD & mobile UX | 1 | Responsive HUD (round/health/points/ammo/zombies-left); touch shoot/reload/interact | ⬜ |
| Player movement | 1 | First-person stances: sprint (LeftShift) · crouch (C) · prone (X); per-stance WalkSpeed + camera drop; mobile touch buttons. Pose animations pending | ✅ (mechanics) |
| Lobby & parties | 2 | Social hub place; create/join/leave parties; ready-up; queue | ⬜ |
| Matchmaking / reserved servers | 2 | ReserveServer + TeleportAsync(+TeleportData); seat party in Game place; retry/rejoin | ⬜ |
| Perks + Power-ups | 3 | Power-ups: drop on kill → team-wide Max Ammo / Nuke / Insta-Kill / Double Points / Carpenter (timed), HUD banner. Perks: Juggernog / Speed Cola / Double Tap / Quick Revive machines (per-player buffs, lost on respawn) | ✅ |
| Mystery Box + Pack-a-Punch | 3 | Box: 950-pt weighted random weapon roll (wonder rare). PaP: 5000-pt upgrade to a data-variant gun (Skullcrusher/Hades/…). Shared `BuyStation`, server-auth | ✅ |
| Barriers / windows | 3 | Each zombie breaches its perimeter window (tears planks, remove-planks anim) before chasing; players hold to repair planks for points; Carpenter power-up re-boards all | ✅ |
| Down & revive | 3 | Fatal hit → downed (ragdoll, can't move/shoot, 30s bleed-out); teammate revive prompt; co-op wipe only when all down; Quick Revive solo self-revive; bled-out respawn next round | ✅ |
| Persistence | 4 | ProfileStore session-locked: best round, kills, unlock currency | ⬜ |
| Monetization (loot boxes) | 4 | Weapon/clothing skins, `ProcessReceipt`, owned inventory + equip, lobby shop | ⬜ |
| Performance hardening | 5 | Parallel Luau (if needed), StreamingEnabled, part-count audit | ⬜ |
| Polish & ship | 5 | VFX/audio/animation; security + publish; analytics | ⬜ |
