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

## Next vertical slice: Phase 4A themed floors (recommended)

ROADMAP Phase 4A asks for distinct themed floors: cubicle farm, open office
with carpet/tile speed zones, stairwell chaos with floor gaps, slippery
cafeteria + parking-lot exit treatment, plus checkpoint/respawn logic.

Suggested approach in priority order:

1. Cubicle partitions + plants on floor 1 (visual variety, cheap boxes).
2. Checkpoint zones at each elevator entrance + `PlayerChair.respawn()`
   (fall below checkpoint floor - 5u => respawn at last checkpoint).
3. Slippery cafeteria floor 4 (low-friction physics material on the floor
   StaticBody3D; PlayerChair already supports it via standard friction).
4. Water-cooler permanent stun fixtures on floor 2.
5. Painted parking-lot treatment behind the exit on floor 4.

Constraints: keep primitive meshes, per-floor noise seeds, elevator pads stay
as the only floor-to-floor traversal (do NOT reintroduce ramps), and keep
LevelClearTest passing (it recreates floor/elevator geometry itself — extend
it if geometry changes).

## Verification ladder (run all, in order)

```bash
git diff --check
/usr/local/bin/godot --headless --script scripts/BootTest.gd
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
