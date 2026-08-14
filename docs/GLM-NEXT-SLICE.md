# GLM Next Slice — Friday 5PM: Evacuation

Status: implementation-ready handoff
Owner: GLM 5.2/5.3 polish lane
Priority: P0 accessibility and player-facing clarity

## Baseline evidence

- `git diff --check` passes.
- Godot BootTest passes.
- ModeSmokeTest passes.
- NetworkSmokeTest passes.
- LevelClearTest passes.
- Current verified feature commit: `428ed74`.
- Real two-machine Wi-Fi and physical-device QA remain unverified.

## First vertical slice: accessibility feedback

Implement only shared accessibility feedback and settings. Do not add race modifiers or new game modes in this slice.

Target files:

- `scripts/Settings.gd`
- `scripts/HUD.gd`
- `scripts/ModeHUD.gd`
- `scripts/Evacuation.gd`
- new `scripts/SubtitleOverlay.gd`
- new focused smoke test under `scripts/`

## Required settings

Persist through the existing settings system:

- `screen_shake_enabled`
- `flash_effects_enabled`
- `reduced_motion_enabled`
- `high_contrast_enabled`
- `subtitles_enabled`
- `time_scale` for single-player only

Multiplayer must force `time_scale = 1.0`.

## Color-independent feedback

Do not communicate these states through color alone:

- Coffee: cup icon/label
- Exit: `EXIT` label plus directional marker
- Elevator: elevator/arrow marker
- Trap: type label/icon
- Success: check icon plus text
- Failure/danger: warning icon plus text

Reuse existing procedural/UI style. Avoid external asset dependencies.

## Subtitle contract

`SubtitleOverlay.gd` should expose a small method such as:

```gdscript
show_caption(text: String, duration := 1.5)
```

Use it for at least:

- `GO!`
- `BOOST READY`
- `BOOST!`
- `TRAP HIT`
- `COFFEE COLLECTED`
- `ELEVATOR`
- `FINISH`

Captions must respect the setting, clean themselves up, and remain readable on narrow screens.

## TDD / verification

Add a focused smoke test before implementation for:

- settings persistence/defaults
- multiplayer time-scale clamp
- subtitle visibility toggle
- repeated caption replacement/cleanup

Then run:

```bash
git diff --check
/usr/local/bin/godot --headless --script scripts/BootTest.gd
/usr/local/bin/godot --headless --path . --script scripts/PauseMenuSmokeTest.gd
/usr/local/bin/godot --headless --path . --script scripts/ModeSmokeTest.gd
/usr/local/bin/godot --headless --path . --script scripts/NetworkSmokeTest.gd
/usr/local/bin/godot --headless --path . --script scripts/LevelClearTest.gd
/usr/local/bin/godot --headless --path . --quit-after 3
```

## Constraints

- Do not break the existing pause menu or stats persistence.
- Do not pause a live network match.
- Do not claim real multiplayer or device QA from headless tests.
- Keep Compatibility renderer and MacBook Air performance constraints.
- Update `ROADMAP.md` with exact verification output and known hardware limitations.
