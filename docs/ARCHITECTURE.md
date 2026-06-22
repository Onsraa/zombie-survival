# Architecture

## Universe = two places (one experience)
- **Lobby place** (start place): social hub, party UI, queue, shop (later). Public servers.
- **Game place**: the survival match. One **reserved server** per party/match.

Built first: the Game place (testable solo + drop-in). The Lobby place is added in Epic 2. Shared
code is reused by both via `src/shared`.

## Repo layout (Rojo)
```
src/
  shared/                 → ReplicatedStorage.Shared (both places)
    Constants.luau        tunable, non-system-specific values
    Types.luau            shared Luau types
    Remotes.luau          remote NAME registry + resolver (get)
    Config/
      ZombieConfig.luau   difficulty FORMULAS (pure → Lune-testable)
      WeaponConfig.luau   weapon data + economy (pure → Lune-testable)
    Util/
      Trove.luau          cleanup container (SE-4)
  game/
    server/               → ServerScriptService.Server
      GameManager.server.luau   bootstrap (Init → Start), player lifecycle
      RemoteHandler.luau        remote create/validate/rate-limit/cooldown
      Services/
        SessionService.luau     in-memory per-player session (points/kills)
    client/               → StarterPlayer.StarterPlayerScripts.Client
      ClientController.client.luau   bootstrap
docs/   tests/   rokit.toml  wally.toml  selene.toml  stylua.toml  .luaurc
default.project.json (Game place)   [lobby.project.json added in Epic 2]
```

## Boot sequence (Game place)
1. `GameManager` (Script) runs. No yields at require time (SE-8).
2. `init()`: `RemoteHandler.init()` → create remotes → connect `PlayerAdded`/`PlayerRemoving` →
   handle already-present players.
3. `start()`: gameplay services start (RoundService etc., from Epic 1).
4. Per join: `SessionService.create` → fire `SessionReady` to that client.

## Networking model
- **Single source of truth for names**: `shared/Remotes.luau`. Instances created by `RemoteHandler`.
- **All client→server remotes** registered via `RemoteHandler.register` → automatic rate-limit
  (SE-5), cooldown, and validator gating. Server→client via `fireClient` / `fireAllClients`.
- **Server-authoritative** everything (damage, kills, points, ammo). Client sends *intent*, never
  *outcome* (SE-2).
- **Zombie movement is auto-replicated** (server-owned Humanoid models in Workspace). No per-frame
  position remotes — this is the core anti-lag decision.
- `UnreliableRemoteEvent` reserved for purely cosmetic high-frequency fx, if any.

## Data
- **MVP: session-only**, in-memory (`SessionService`). No DataStore yet.
- **Epic 4**: ProfileStore (session-locked, SE-1) for best round / kills / unlock currency, plus
  owned-skin inventory; purchases via idempotent `ProcessReceipt` (SE-3).

## UI workflow (roblox-ts + @rbxts/react)
- UI (HUD, menus, lobby, shop) is authored in **TypeScript via roblox-ts**, compiled to Luau that
  Rojo includes. Component library: **@rbxts/react**.
- Lives in a self-contained `ui/` sub-project (package.json, tsconfig) compiling to `ui/out/` (Luau),
  mapped by Rojo into the client. `rbxtsc -w` runs alongside `rojo serve`.
- TS-UI talks to Luau gameplay **only through RemoteEvents** (the network boundary) — no cross-language
  module requires. Remote names are mirrored as TS constants.
- Gameplay (server/shared) stays hand-written Luau. **Build step:** `cd ui && npm install && npm run
  build` (rbxtsc) compiles `ui/src` → `ui/out`. Rojo maps `ui/out` → `StarterPlayerScripts.UI` and
  `ui/include` + `ui/node_modules/{@rbxts,@rbxts-js}` → `ReplicatedStorage.rbxts_include`.
- The HUD requests a full state push on mount via the `RequestSync` remote (so ammo/points/round show
  immediately regardless of mount timing). Server pushes `WeaponState` / `PlayerStats` / `RoundState`.
- `ui/out`, `ui/include`, `ui/node_modules` are generated/gitignored — run the build step after cloning.

## Zombies
- **Model**: cloned from `ReplicatedStorage.Assets.Models.Zombie` (themed Motor6D rig). Art content
  currently lives in the place (not yet version-controlled — see art-versioning TODO).
- **`ZombieService`** (server): spawn / cap-24 / throttled pathfinding chase / melee / points; zombies
  are server-owned so movement auto-replicates (no per-frame remotes).
- **`ZombieController`** (server, one per zombie): animation playback + gore. The head detaches near death
  (< 15% HP); the **legs are blown off by explosions** (`ZombieService.explode` → `:DetachLegs()`),
  switching the zombie to crawling. Crawl is **impact-driven**, never a health threshold. Ragdolled parts
  clean up after a delay. On death it does an explicit **ragdoll collapse** (loosens the R6 joints + a drop
  impulse; `BreakJointsOnDeath` is off) — or plays a `Death` animation if that id is set — so the kill reads
  instantly instead of the default ~0.2s gravity flop.
- **Animations**: playback prefers uploaded `AnimationId`s from `Config/ZombieAnimations`; any blank id falls
  back to the committed `KeyframeSequence` via `KeyframeSequenceProvider` (**Studio preview only** — the temp
  id loads a track but won't pose the rig in a published game until the id is filled). Resilient/pcall-guarded
  so a missing clip never breaks a zombie.
- **`RoundService`** (server): co-op wave state machine; broadcasts `RoundState` (change-based) for the HUD.
- **Weapons (modular, data-driven)**: guns are `GunDef` entries in `shared/Weapons/Guns/*` (by category),
  aggregated by `GunRegistry`. Each has fire mode, RPM, damage, penetration, **spread** (an accuracy cone
  that blooms with sustained fire — the real COD accuracy mechanic), a schema-ready `recoil` profile (for a
  future viewmodel animation — **not** a camera kick), ammo, an `upgrade` field naming the gun's Pack-a-Punch
  data variant, and asset placeholders. Pure math is in `Weapons/Ballistics`
  (Lune-tested). Adding a standard gun = one data entry; exotic guns = a data entry + a fire behavior.
- **`WeaponService`** (server): per-player state, RPM cooldown, spread bloom, **camera-origin raycast**
  (origin validated near the head, so shots land on the crosshair), then dispatch to a **fire behavior**
  by `fireType` (`FireBehaviors/`: Hitscan w/ penetration · Shotgun pellets · Projectile/Ray-Gun that
  **blasts the impact zone** via `explode` — AoE damage + leg-detach). First shot is exact (`spread.base = 0`
  on standard guns). Client sends `{ origin, direction }`; server stays authoritative, awards points via
  `damageZombie`.
- **Buy stations** (server): `BuyStation` builds a pedestal + `ProximityPrompt` + label and, on trigger,
  re-checks the buyer is at the pedestal (anti-exploit) before calling the handler — shared by all three
  spend systems. Points are spent server-side only via `SessionService.spendPoints` (SE-2):
  - **`WallBuyService`** — one pedestal per gun with a `wallBuyCost`; spend → `giveWeapon` (first buy) or
    `refillAmmo` (already holding it). Buyable guns auto-distribute; adding a wall gun is a data field.
  - **`MysteryBoxService`** — 950-point weighted random roll from the base-gun pool (no starter / no PaP
    variants; wonder weapons rare), a short reveal on the label, then `giveWeapon`.
  - **`PackAPunchService`** — 5000-point upgrade of the held gun to its `GunDef.upgrade` data variant
    (Skullcrusher, Hades, Mustang & Sally, …); upgraded guns have no `upgrade`, so they can't be re-PaP'd.
  - **`PerkService`** — perk machines granting a persistent per-player buff until respawn: Juggernog
    (max health 100→250), Speed Cola (0.5× reload), Double Tap (1.33× fire rate). Reload/fire-rate run
    through per-player `WeaponService` multipliers (fire-rate is mirrored to the client via `WeaponState`
    so the client's cadence matches the server's); perks clear on respawn.
- **`PowerUpService`** + **`CombatModifiers`** (server): on a zombie kill (via `ZombieService`'s kill hook) a
  small chance drops a floating pickup; the first touch fires a team-wide effect — Max Ammo (refill all),
  Nuke (`ZombieService.nukeKill` + points), Insta-Kill and Double Points (timed flags in `CombatModifiers`,
  which `ZombieService.damageZombie` reads each hit). A `PowerUp` remote drives the HUD banner.
  `CombatModifiers` is a leaf module so ZombieService/PowerUpService share it without a require cycle.
- **`DownService`** + **`PlayerState`** (server): a fatal zombie hit **downs** a player instead of killing
  them — ragdolled (`PlatformStand`), frozen, can't shoot, bleeding out (30s). A teammate holds a revive
  `ProximityPrompt`; solo, the **Quick Revive** perk grants one self-revive. The `PlayerState` leaf holds the
  "downed" flag (read by Zombie/Weapon services without a cycle); zombie melee is routed through `DownService`
  via ZombieService's registered player-damage handler. `RoundService` ends the game only when **no player is
  up** (everyone downed/dead = co-op wipe); bled-out players respawn next round if the team survives.
- **`BarrierService`** (server): boarded windows on the perimeter. Each newly spawned zombie is assigned a
  barrier and **breaches** it — tearing planks (the remove-planks animation) before it can chase
  (the breach phase in `ZombieService.runAi`). Players hold a repair prompt to re-board planks for points; the
  **Carpenter** power-up re-boards every barrier. MVP: a logical gate at the spawn point — planks are visual,
  the AI breach phase is the real gate (no physical hole in the sealed wall).
- **`WeaponController` / `WeaponEffects`** (client): input + fire modes (auto/semi/single/burst). It mirrors
  the authoritative `WeaponState` (ammo/reloading) so it never fires effects the server would reject (empty
  or reloading) and **auto-reloads** when the mag runs dry; the server stays the source of truth. There is
  **no recoil camera kick** — accuracy is the server's spread; a viewmodel animation will supply visual kick
  once gun models exist. `WeaponEffects` draws cosmetic tracers/impacts. `CameraController` locks first-person
  and hides the OS cursor; the crosshair sits at the **true viewport center** (`ScreenInsets = None`) so it
  matches where the camera shoots.
- **`MovementController`** (client): first-person stance machine — Stand / Crouch (`C`) / Prone (`X`) set the
  Humanoid `WalkSpeed` + a `CameraOffset` view drop; Sprint (hold `LeftShift`) speeds up only while standing.
  Bound via `ContextActionService` with auto touch buttons for mobile. Speeds in `Constants`
  (walk 16 / crouch 8 / prone 4 / sprint 22).

## Lobby & parties (Epic 2)
- **Two places, one universe.** `default.project.json` builds the **Game** place; `lobby.project.json`
  builds the **Lobby** place. Both map `ReplicatedStorage.Shared → src/shared` (Remotes, Party, Constants),
  so remote names and the pure `Party` model are shared.
- **`Party`** (`src/shared`, pure): party data model + ops (create / add / remove / ready / allReady),
  Lune-tested; leadership reassigns when the leader leaves.
- **`PartyService`** (Lobby server): owns the live parties, broadcasts a `PartyState` snapshot of every
  party to all clients. Creates its own lobby remotes (the Lobby place doesn't include the Game's
  `RemoteHandler`; party traffic is low-frequency).
- **`LobbyClient`** (Lobby client): a plain-Luau party panel (create / join / leave / ready, leader start)
  that rebuilds from `PartyState`. The React HUD stays the Game place's.
- **`MatchmakingService`** (Lobby server): leader Start → `ReserveServer` + `TeleportAsync` with the party as
  `TeleportData`; the Game place reads `GetJoinData()` on arrival. Server-initiated, so the TeleportData is
  trusted. Code-complete; activates once both places are published into one universe and
  `Config/PlaceIds.GAME_PLACE_ID` is set (no-ops with a warning until then).

## Conventions / quality gates
- `--!strict` on module APIs; no type escape hatches.
- `task.*` only (never `wait`/`spawn`/`delay`).
- Every `:Connect` tracked in a `Trove`; cleaned on player leave / entity death (SE-4).
- `WaitForChild` always with a timeout (SE-11).
- Tunable balance numbers live in `Config/*`; no magic numbers / per-case hacks.
- selene + stylua clean; pure logic covered by Lune tests.
- Mobile: <10k visible parts (SE-7); collision groups; UDim2.fromScale UI; ScreenInsets safe-area.

## Sharp-edges acceptance checklist (from the skill, applied continuously)
SE-1 ProfileStore (Epic 4) · SE-2 server-auth currency · SE-3 ProcessReceipt order (Epic 4) ·
SE-4 Trove cleanup · SE-5 RemoteHandler rate-limit · SE-6 parallel BindToClose saves (Epic 4) ·
SE-7 mobile part budget · SE-8 no yields in require · SE-11 WaitForChild timeouts.
