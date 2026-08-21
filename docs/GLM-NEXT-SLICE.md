# GLM Next Slice — Friday 5PM: Evacuation

Status: implementation-ready handoff
Owner: GLM 5.2/5.3 polish lane
Priority: P0 gameplay depth + player-facing clarity

## Baseline evidence

- `git diff --check` passes.
- Full verification ladder green at commit `09ff442` (10 test scripts + real boot).
- Real two-machine Wi-Fi and physical-device QA remain unverified.

## COMPLETED slice: Phase 4B power-up variety + dead-wiring fixes

Done in this working session (see git log for the exact commit):

- Six pickup kinds with weighted 60/15/10/8/4/3 distribution
  (coffee, energy drink, stapler x3, spill x2, printer, extinguisher).
- Item charges on PlayerChair (`give_item`, `_use_item`, Q fires item first,
  falls back to sabotage trap when empty). Mobile sabotage action added.
- New `scripts/StaplerBolt.gd` projectile: fast forward shot, stuns +
  knockbacks, never hits the firer, self-cleans.
- Spill item drops a wide forced-type trap (physics-safe wide CylinderShape3D).
- Printer pickup: paper-plane visual burst + blind flash for nearby players
  (respects `flash_effects_enabled`).
- Extinguisher pickup: stuns ALL players within 8u for 2s (self-misuse allowed).
- Colorblind-safe: every pickup carries a Label3D name; effects captioned.
- HUD.gd is now actually wired into Evacuation (was dead code): speed bar,
  boost state with true cooldown, item readout, minimap, floor label.
- SubtitleOverlay is now mounted in all 4 modes (captions were dead wiring
  everywhere). New `SubtitleOverlay.mount()` dedupes.
- MobileControls mounted on Android/iOS in Evacuation (was never instantiated);
  move/action signals wired to the local chair.
- Removed duplicate powerup pickup connect in Evacuation.gd.
- `PowerUpSmokeTest.gd`: 31 checks, all passing.
- BootTest now also compiles StaplerBolt.gd, HUD.gd, Minimap.gd.

## COMPLETED slice: Phase 4A themed floors (commit `18bdbda`)

All four floors now have distinct identities; see ROADMAP Phase 4A STATUS
line for the full inventory. Key facts for follow-up slices:

- Floor 3 has REAL fall-through gaps; `_floor3_landing_layout()` in
  Evacuation.gd is the single source of truth and is mirrored in
  LevelClearTest.gd `FLOOR3_LANDINGS` — keep both in sync on any change.
- `PlayerChair.set_surface(mult)` / `clear_surface()` is the grip API;
  `SurfaceZone.gd` (Area3D) applies it on enter/exit. tile 0.55,
  carpet 1.8, ice 0.16, lot 1.4.
- `StunFixture.gd` = StaticBody3D + Area3D stun bubble (water cooler
  solid; spill roll-through). Reusable for 4C hazards.
- Checkpoints: elevators set `body.respawn_point` on teleport;
  `Evacuation._respawn_if_fell()` watches during racing.

## Next vertical slice: Phase 4C dynamic hazards (recommended)

ROADMAP 4C: Rogue Roombas (wander AI, contact stun + knockback, 2-3 per
floor), swinging doors (floors 1+4, sin-wave rotation, hit = knockback +
0.5s stun), fire-drill alarm every 30s (red strobe lights 5Hz for 5s,
+50% friction panic, HUD announce), falling ceiling debris on floor 3
(warn 1s then fall; hit = 1s stun; despawn after landing).

Implementation notes:

- Build `scripts/Hazards.gd` as a Node3D spawner + per-entity inner or
  companion scripts; reuse `StunFixture`'s bump pattern for contact stun.
- Roombas: AnimatableBody3D or CharacterBody3D, pick a direction every
  3-5s, 4 u/s; keep them ON the landings for floor 3 (sample from
  `_floor3_landing_layout()` rectangles) or they fall through the gaps.
- Doors: AnimatableBody3D with rotation driven by sin(time), collision
  follows automatically; place in floor 1 corridor mouths + floor 4
  cafeteria entrances.
- Fire drill: timer in Evacuation.gd, drive existing ceiling-light nodes'
  energy, bump all chairs' friction via a temporary surface multiplier,
  HUD status + caption "FIRE DRILL! EVERYBODY PANIC!".
- Debris: floor 3 only; spawn ABOVE landings (never over gaps), shake 1s
  (respects reduced_motion), fall, Area3D hit test, queue_free 2s later.

## Verification ladder (run all, in order)

## Verification ladder (run all, in order)

```bash
git diff --check
/usr/local/bin/godot --headless --script scripts/BootTest.gd
/usr/local/bin/godot --headless --path . --script scripts/ThemedFloorsSmokeTest.gd
/usr/local/bin/godot --headless --path . --script scripts/PowerUpSmokeTest.gd
/usr/local/bin/godot --headless --path . --script scripts/PauseMenuSmokeTest.gd
/usr/local/bin/godot --headless --path . --script scripts/ModeSmokeTest.gd
/usr/local/bin/godot --headless --path . --script scripts/NetworkSmokeTest.gd
/usr/local/bin/godot --headless --path . --script scripts/LevelClearTest.gd
/usr/local/bin/godot --headless --path . --script scripts/AccessibilitySmokeTest.gd
/usr/local/bin/godot --headless --path . --script scripts/RaceModifiersSmokeTest.gd
/usr/local/bin/godot --headless --path . --script scripts/GhostRacerSmokeTest.gd
/usr/local/bin/godot --headless --path . --script scripts/StatsRoundTripTest.gd
/usr/local/bin/godot --headless --path . --quit-after 3
```

## Constraints

- Do not break the existing pause menu or stats persistence.
- Do not pause a live network match.
- Do not claim real multiplayer or device QA from headless tests.
- Keep Compatibility renderer and MacBook Air performance constraints.
- Update `ROADMAP.md` with exact verification output and known hardware limitations.
