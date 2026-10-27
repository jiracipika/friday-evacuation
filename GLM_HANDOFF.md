# Friday 5PM: Evacuation — GLM Handoff

Repository: `jiracipika/friday-evacuation`
Engine: Godot 4.7.1
Primary mode: Evacuation
Latest verified commit at handoff: `4058dd9` (external re-verification,
2026-10-27: full ladder 83/83 phases / 81 suites + boot PASS on Godot
4.7.stable.official.5b4e0cb0; two-process multiplayer sync test PASS on
UDP loopback including the new avatar/design roster assertions;
`--import --quit` and `git diff --check` clean. Evidence run dir:
docs/ui-continuation/evidence/ladder-runs/run-20261027-180910.)

This document is the repository-visible handoff for future GLM polish, visual treatment, cleanup, and cross-platform QA. It intentionally records what is implemented, what was verified, and what remains unverified.

## Product

Friday 5PM: Evacuation is a comedic office-chair physics multiplayer game.

Modes:

1. Evacuation — primary, playable race through a four-floor office
2. Hauled — hostile-cargo delivery loop
3. Shop & Seek — timed grocery discovery loop
4. Pizza Colony — territory/survival loop

Target platforms:

- macOS ARM/desktop
- Windows/Linux desktop
- Android
- iOS
- Web is possible later but not a current shipping target

Steam integration is intentionally deferred. Stabilize LAN multiplayer first.

## Architecture

Autoloads configured in `project.godot`:

- `GameManager` → `res://scripts/GameManager.gd`
- `Network` → `res://scripts/Network.gd`
- `AudioManager` → `res://scripts/AudioManager.gd`

Important scenes:

- `scenes/Main.tscn` — main menu and mode selection
- `scenes/Evacuation.tscn` — primary office-race mode
- `scenes/PlayerChair.tscn` — CharacterBody3D chair player prefab
- `scenes/Hauled.tscn`
- `scenes/ShopSeek.tscn`
- `scenes/PizzaColony.tscn`
- `scenes/objects/SabotageTrap.tscn`

Procedural generation is used throughout. Runtime-created meshes, materials, particles, audio, HUD controls, and environment objects are preferred while external assets are absent.

Design language:

- Background: `#0a0a0f`
- Cards: `#1c1c2e`
- Text: white with opacity tiers
- Primary accent: orange `#ff9a1a`
- Low-cost procedural/mobile-friendly rendering is preferred

## Completed Implementation History

### Phase 0 — Project foundation

- Created the Godot project and metadata
- Configured input actions and platform metadata
- Added `GameManager.gd`
- Added ENet networking foundation
- Added office-chair CharacterBody3D controller
- Added main menu and four mode selection
- Added Evacuation scene and three secondary mode scenes
- Added sabotage trap scene
- Added `.gitignore`
- Added headless validation scripts
- Initialized GitHub repository and pushed the project

### Phase 1 — Visual identity

- Procedural carpet and wood materials
- Four-floor office environment
- Warm ceiling-light grids
- Emissive fixtures
- Fog/glow/bloom tuning
- Procedural office-chair model
- Coffee power-up visuals
- Deterministic obstacles and environment setup

### Phase 2 — Game feel and audio

Player feel:

- Acceleration/friction smoothing
- Speed clamping
- Smooth facing
- Render-frame chase-camera following
- Velocity-aware camera offset
- Look-ahead camera targeting
- Chair squash/stretch
- Landing compression
- Jump extension
- Boost wheelie feedback
- Wheel animation
- Stun spin/wobble and recovery

Feedback/audio:

- Runtime boost particles
- Procedural pooled PCM audio
- Boost, jump, landing, trap-hit, power-up, go-horn, victory, and wall-bonk effects
- `AudioManager.gd` autoload
- Real `SFX` and `Music` AudioServer buses
- Settings-driven bus volume

### Phase 3 — UI and settings

- Animated main-menu title
- Four mode cards with title, subtitle, and capability state
- Play button
- Settings overlay
- Graphics-quality controls
- Master/music/SFX volume sliders
- Screen-shake toggle
- Persistent settings at `user://settings.cfg`
- In-match HUD with timer, floor, speed, boost state, and speed bar
- Results panel with winner, top speed, and traps placed
- Rematch and Main Menu actions

### Polish slice

- Speed-based FOV kick
- Camera shake signal and decay
- Corrected boost visual timer progression
- Rolling dust particles
- Trap-impact particle bursts
- Finish confetti
- Lightweight HUD minimap
- Player/floor/exit minimap mapping
- Graphics quality now applies to fog/glow/shadows

### High-value gameplay/platform pass

- `ImpactFX.gd` for procedural trap bursts and victory confetti
- `MobileControls.gd` with virtual joystick, boost button, and jump button
- Mobile controls wired to `PlayerChair.set_mobile_input()` and `trigger_mobile_action()`
- Main menu card readability improved
- Remote chair spawn/removal baseline
- Remote position/velocity replication baseline
- Hauled cargo tracking and delivery progress
- Shop & Seek six-target discovery loop
- Pizza Colony territory and survival loop

### Software-only completion pass

- `ModeHUD.gd` reusable secondary-mode timer/progress/failure HUD
- `ModeCard.gd` configured mode-card style control
- `Lobby.gd` host/join/ready lobby UI
- Hauled live 180-second timer, delivery progress, success, and timeout failure state
- Shop & Seek live 60-second timer, target progress, success, and timeout failure state
- Pizza Colony live 90-second timer, territory progress, and survival completion state
- `ModeSmokeTest.gd` runtime instantiation test for all secondary modes
- Fixed PlayerChair nested mesh path: `$ModelParent/ChairMesh`
- Fixed Hauled typed-array/body callback mismatch
- Fixed ModeHUD deferred initialization ordering
- Fixed Lobby collision with native `Control.ready`

### LAN multiplayer implementation

`Network.gd` now provides:

- ENet host on UDP port `5005`
- ENet client join by LAN IP
- UDP discovery on port `5006`
- Broadcast host advertisement with host name and player count
- Client discovery requests and host responses
- Host-authoritative roster
- Reliable roster synchronization
- Host-authoritative ready state
- All-player-ready gate
- Host-authoritative match-start RPC
- Server-relayed player position/velocity snapshots
- Remote player state tracking
- Disconnect cleanup

`Lobby.gd` now provides:

- Host button
- Join button
- LAN address input
- Scan Local Wi-Fi button
- Discovered-host list
- Selectable discovered host rows
- Player list with ready state
- Ready-up button
- Host-only Start Match button
- Connection failure/status feedback

`Evacuation.gd` consumes the synchronized roster when the match scene initializes and creates remote chairs for known peers.

## Current Important Files

- `scripts/GameManager.gd` — global mode/player state
- `scripts/Network.gd` — LAN discovery, ENet, lobby authority, roster, ready, match start, state relay
- `scripts/AudioManager.gd` — pooled procedural audio and AudioServer buses
- `scripts/PlayerChair.gd` — player movement, boost, jump, stun, mobile input, visuals, particles, SFX
- `scripts/Main.gd` — menu, mode selection, settings/lobby overlays
- `scripts/Evacuation.gd` — primary race, HUD, remote players, results, camera
- `scripts/HUD.gd` — reusable Evacuation HUD and minimap integration
- `scripts/ModeHUD.gd` — secondary-mode objective/timer/progress HUD
- `scripts/ModeCard.gd` — styled mode button control
- `scripts/Lobby.gd` — LAN lobby UI
- `scripts/MobileControls.gd` — touch joystick/action controls
- `scripts/ImpactFX.gd` — procedural burst/confetti effects
- `scripts/Settings.gd` — persistent settings and renderer/audio application
- `scripts/Hauled.gd` — cargo-delivery mode
- `scripts/ShopSeek.gd` — timed grocery-discovery mode
- `scripts/PizzaColony.gd` — territory/survival mode
- `scripts/ModeSmokeTest.gd` — runtime secondary-mode smoke test
- `scripts/NetworkSmokeTest.gd` — local ENet host/ready/start smoke test
- `scripts/BootTest.gd` — script and scene validation
- `ROADMAP.md` — implementation roadmap

## Verification Commands

Run from the repository root:

```bash
git pull --ff-only
git diff --check
godot --headless --script scripts/BootTest.gd
godot --headless --path . --script scripts/NetworkSmokeTest.gd
godot --headless --path . --script scripts/ModeSmokeTest.gd
godot --headless --path . --quit-after 3
```

All of these were clean for commit `c060c56`.

The checks prove:

- Scripts compile
- Scenes load
- Secondary modes instantiate for multiple frames
- A local ENet host can be created
- Host ready state is accepted
- Authoritative match start works
- Real autoload-enabled project boot is clean

They do not prove two-machine Wi-Fi reachability, firewall behavior, touch feel, target-device performance, or store packaging.

## GLM Next-Pass Priorities

### Priority 1 — Real LAN validation and hardening

Use two actual machines on the same Wi-Fi network.

Acceptance criteria:

- Host appears in Scan Local Wi-Fi on the client
- Client joins without manual IP entry
- Both players appear in the roster
- Both ready states synchronize
- Host can start only when all players are ready
- Both machines enter Evacuation together
- Remote chairs spawn once and do not duplicate
- Remote chairs interpolate without obvious jitter
- Disconnect removes the remote chair and updates the roster
- Host disconnect returns clients to a clear error/menu state

Likely follow-up areas:

- macOS firewall permission and UDP reachability
- Discovery socket lifecycle
- Host migration or explicit host-disconnect handling
- Match restart/rematch synchronization
- Ping/latency display
- Network diagnostics overlay

### Priority 2 — Multiplayer authority correctness

The current replication is a practical baseline, not a production lockstep model.

Improve:

- Server-authoritative player positions or server reconciliation
- Input snapshots instead of trusting client transforms
- Spawn positions by peer ID
- Finish-order replication
- Trap placement/hit replication
- Power-up pickup replication
- Match timer synchronization from the host
- Deterministic rematch/reset
- Full-mode network rules for Hauled, Shop & Seek, and Pizza Colony

### Priority 3 — Visual polish

- Replace primitive placeholder geometry where valuable
- Add stronger office theming per floor
- Improve chair silhouettes and readable player colors
- Add environmental storytelling: desk clutter, signs, evacuation arrows, break-room props
- Improve trap readability and impact timing
- Add distinct secondary-mode visual identities
- Preserve mobile performance and avoid expensive lighting/post-processing

### Priority 4 — UX/accessibility

- Add a clear lobby connection indicator
- Add ping/host name/player count rows
- Add keyboard/controller navigation to lobby
- Add safe-area handling for touch controls
- Add text labels for mobile actions
- Add colorblind-safe player markers
- Add pause/disconnect/retry states
- Make failure and timeout states actionable

### Priority 5 — Shipping prep

- Configure export presets
- Test desktop exports
- Test macOS ARM export
- Test Android/iOS exports
- Add signing only when credentials are available
- Add crash/log collection strategy
- Avoid Steam until LAN multiplayer is proven stable

## Non-negotiable Development Rules

- Always run `git pull --ff-only` before repo work
- Work directly on `main` for this project
- Never claim a feature is complete without exercising it
- Run the full verification ladder after changes
- Inspect stderr, not only final PASS lines
- Use `git diff --check`
- Keep procedural systems self-cleaning
- Keep mobile performance in mind
- Treat Steam as future work, not current scope
- Do not add secrets, API keys, tokens, or credentials to this repository
- Preserve honest PLAYABLE/PROTOTYPE labels

## Handoff Summary

The project is beyond a scaffold: Evacuation is playable, the UI/settings/game-feel layers are implemented, all three secondary modes have concrete loops and HUDs, and the LAN lobby/discovery/authority baseline exists. The highest-value next step is not more speculative features; it is connecting two real machines over Wi-Fi, finding the lifecycle/authority issues, and then hardening those findings before Steam integration.
