# GLM Next Slice — Friday 5PM: Evacuation

Status: implementation-ready handoff
Branch: `main`
Latest code commits:
- `abed921` — Phase 6A Hauled physics delivery
- `201b4e8` — Phase 7A touch controls

## Verified baseline

All commands below passed serially after `201b4e8`:

```bash
git diff --check
/usr/local/bin/godot --headless --path . --script scripts/BootTest.gd
/usr/local/bin/godot --headless --path . --script scripts/HauledSmokeTest.gd
/usr/local/bin/godot --headless --path . --script scripts/TouchControlsSmokeTest.gd
/usr/local/bin/godot --headless --path . --script scripts/ModeSmokeTest.gd
/usr/local/bin/godot --headless --path . --script scripts/NetworkSmokeTest.gd
/usr/local/bin/godot --headless --path . --script scripts/LevelClearTest.gd
/usr/local/bin/godot --headless --path . --script scripts/HazardsSmokeTest.gd
/usr/local/bin/godot --headless --path . --script scripts/ThemedFloorsSmokeTest.gd
/usr/local/bin/godot --headless --path . --script scripts/PowerUpSmokeTest.gd
/usr/local/bin/godot --headless --path . --script scripts/PauseMenuSmokeTest.gd
/usr/local/bin/godot --headless --path . --script scripts/AccessibilitySmokeTest.gd
/usr/local/bin/godot --headless --path . --script scripts/RaceModifiersSmokeTest.gd
/usr/local/bin/godot --headless --path . --script scripts/GhostRacerSmokeTest.gd
/usr/local/bin/godot --headless --path . --script scripts/StatsRoundTripTest.gd
/usr/local/bin/godot --headless --path . --script scripts/VisualDesignSmokeTest.gd
/usr/local/bin/godot --headless --path . --quit-after 3
```

## Completed: Phase 6A — Hauled (`abed921`)

`scripts/Hauled.gd` is now a three-round, playable physics-delivery mode:

- Six cargo types: fridge of bees, haunted sofa, angry vending machine,
  wet cardboard, exploding cake, sentient plant.
- Behaviors: proximity bee stun, random haunted impulses, vending-can
  projectiles, held-cake explosion, and plant mass growth.
- E grabs/releases cargo; carry reduces speed by 30% and locks boost.
- Four terrain gauntlets: pendulum gates, conveyor, wrong-way escalator,
  flat crate field.
- Damage, destruction, delivery scoring, gentleness/speed/co-op bonuses,
  three-round total score, HUD/banners/end panel.
- `HauledSmokeTest.gd`: 22 checks. It caught and fixed two real issues:
  `ModeHUD.configure` needed a time-limit argument; releasing cargo also had
  to clear `RigidBody3D.freeze`.

## Completed: Phase 7A — Touch Controls (`201b4e8`)

`scripts/MobileControls.gd` is a shared custom-drawn Control mounted in all
four modes. It activates on Android/iOS or with `FE_TOUCH=1` desktop preview.

- Left half: multi-touch virtual joystick.
- Right half: BOOST/JUMP/TRAP buttons with press feedback.
- BOOST consults the chair's cooldown synchronously, preventing a stale-frame
  second press; it dims while locked.
- `mount_for_mode(parent, chair)` wires move/action signals directly to the
  provided chair in every mode. Do not duplicate routing in a mode script.
- Stun uses `Input.vibrate_handheld(60)` (desktop-safe no-op).
- `TouchControlsSmokeTest.gd`: 20 checks, all passing.

## Next vertical slice: Phase 6B — Shop & Seek (do next)

Rewrite `scripts/ShopSeek.gd` from its current target-collection loop into
one real supermarket hide-and-seek round. Keep the existing Phase 7A mobile
mount in `_spawn_player()`.

Minimum acceptance criteria:

1. Build 6–8 shelf aisles, checkout, produce, frozen section procedurally.
2. Spawn at least 20 labeled disguise objects with distinct primitive meshes.
3. E near an object toggles disguise: 2-second freeze, then 50% speed;
   a wobble remains as the visual tell. E again undisguises.
4. Single-player fallback: shopper list of 5 items plus a patrolling security
   guard. Preserve a 60-second failure timer.
5. Multiplayer-ready role state: seeker/hider state data, scan cooldown, red
   seeker vest; do not claim real-peer authority until it is replicated.
6. Add `ShopSeekSmokeTest.gd` that instantiates the real scene for frames and
   verifies layout, 20+ disguises, enter/exit disguise state, shopper list,
   guard, and timer HUD. Add the script to BootTest if it has new standalone
   dependencies.

## After 6B

- Phase 6C Pizza Colony: real pepperoni ownership, resources, chef attacks,
  elimination/win condition.
- Phase 7B export presets and builds; then device QA.
- Real two-machine Wi-Fi QA remains required for Phase 5 despite loopback
  coverage.

## Guardrails

- Run `git pull --ff-only` before editing.
- Do not work concurrently in this repository from multiple Hermes sessions.
  The prior Phase 6/7 collision mixed a full rewrite with touch mounts.
- `FLOOR3_LANDINGS` remains mirrored in Evacuation, LevelClearTest, Hazards.
- Godot binary is `/usr/local/bin/godot`.
