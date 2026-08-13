# GLM Visual Feedback Polish — Commit 6158f64

GLM 4.7 focused on low-risk visual feedback and environmental variety improvements. These make the game easier to read and more polished without touching the hard networking or device testing work left for GLM 5.2.

## Changes

### Power-ups (PowerUpVisual.gd)

- Added dynamic OmniLight3D that pulses with the coffee cup
- Glow light now floats/bobs with the cup
- Glow range and intensity pulse on a separate phase
- Larger pickup radius from 0.6 to 0.7
- Pulsing torus ring underneath for ground-plane visibility
- Pickup now triggers its own burst effect and sound via _on_body_entered
- Removed duplicate boost-apply logic from Evacuation.gd — power-ups are self-contained now

### Floor variety (Evacuation.gd)

- Floor numbers (1-4) now appear as faint billboarded labels on each floor
- Exit direction indicators (green cones) on floor 4 pointing toward Z+
- Carpet noise seeds now vary per floor so each floor has different grain
- Per-floor color and material are still preserved; this only makes textures distinct

### Exit clarity (Evacuation.gd)

- Added glowing green EXIT marker box at the actual finish line
- Added billboarded "EXIT" label that reads clearly from any angle
- Previous exit logic (ExitZone) is unchanged; this is visual only

### Lighting tweaks (Evacuation.gd)

- Ceiling fixtures now show more distinct warmth
- Light range increased from 16 to 22
- Ambient light increased from 0.32 to 0.42
- Fog and glow remain disabled for mobile performance — this is safe

## Files Modified

- `scripts/Evacuation.gd` — floor numbers, exit indicators, EXIT label, lighting tweaks, floor-specific noise seeds
- `scripts/PowerUpVisual.gd` — pulsing glow light, self-contained pickup logic, visual ring, larger collision

## Verification

All smoke tests passed:

- `git diff --check` — clean
- `godot --headless --script scripts/BootTest.gd` — 16/16 checks passed
- `godot --headless --path . --script scripts/NetworkSmokeTest.gd` — PASSED
- `godot --headless --path . --script scripts/ModeSmokeTest.gd` — PASSED
- `godot --headless --path . --quit-after 3` — no errors or warnings

## What’s Still for GLM 5.2

This pass avoided the hard work intentionally:

- Real two-machine LAN validation and firewall testing
- Network hardening: authority correctness, spawn timing, disconnect recovery, match restart
- Authoritative trap/power-up replication
- Ping display, host migration, reconnect logic
- Real-device touch/safe-area/mobile controls QA
- Export signing and platform packaging
- Steam integration

Those remain as documented in `GLM_HANDOFF.md` and are better suited to GLM 5.2’s design and deployment strengths.