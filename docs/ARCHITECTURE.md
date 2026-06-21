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
- **`ZombieController`** (server, one per zombie): animation playback + health-driven gore (head detaches
  < 15% HP, legs detach < 40% → crawl), with cleanup of ragdolled parts.
- **Animations**: the 6 `Assets/Animations/*` are **KeyframeSequences**. Played via
  `KeyframeSequenceProvider` for **Studio preview only**. For a published game, upload them and reference
  as `Animation` objects (with `AnimationId`). The controller loads either form, pcall-guarded, so a
  missing animation never breaks a zombie.
- **`RoundService`** (server): co-op wave state machine; broadcasts `RoundState` (change-based) for the HUD.
- **`WeaponService`** (server): server-authoritative raycast shooting — the client sends only an aim
  *direction*; the server raycasts, applies damage (+headshot), manages ammo/reload, and awards points
  via `damageZombie`. `WeaponController` (client) handles input (desktop mouse + mobile touch).

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
