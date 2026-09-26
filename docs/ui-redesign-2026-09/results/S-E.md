# S-E RESULTS — How-to overlay rework (spec section 6, board f4-howto)

Implementer: GLM 5.3 Flash, 2026-09-26, canonical repo
(/Volumes/SERVER/sol-workspace/repos/friday-evacuation). Base: ffc125e.

## Scope

`scripts/PreMatchModal.gd` rewritten to the locked "After Hours" spec:
hazard-tape strip (drawn vector, single use per screen per R7), "HOW IT
WORKS" header with step-count meta, one card per objective line (drawn
46px circle picto flag/lift/home, 01/02/03 tabular numerals, ORANGE
title, muted copy), keycap chips + pad circles in two hairline-divided
columns with action labels right at #c4c4d2, touch line, pause note,
and the CLOCK OUT — GO gate (INK on ORANGE per R6, SPACE / A hint
parked inside the button). The in-match HUD layers ("UI" legacy +
`hud_ext`/`mode_hud`) hide while the modal is up and restore on agree
(spec: paused = invisible).

## Behavior preserved

Mount pauses the tree first; agree (button / Enter / Space / pad A /
Start) restores HUD, unpauses, frees; suppress_next() single-shot;
CLOCK OUT is the same agree_button contract; touch line logic
unchanged; all four modes mount it unchanged.

## Key findings (for the next session)

1. CanvasLayer children have NO sized parent: grow-direction centering
   (grow BOTH + PRESET_CENTER) collapses the panel to an edge (measured
   off-screen right, then left). A full-rect CenterContainer centers it
   reliably. Settings.gd's PRESET_CENTER + manual position works but is
   hand-math; CenterContainer is the durable pattern.
2. Same-name siblings are auto-renamed by Godot: three "StepCard" nodes
   became StepCard/StepCard2/StepCard3 and name-based finds saw ONE.
   Name children uniquely (StepCard%d, Keycap_<GLYPH>).
3. Chip kind must come from the COLUMN, not the glyph: WASD contains an
   "A" and would classify as a pad circle.
4. Evacuation._ready mounts the modal BEFORE _setup_hud creates hud_ext,
   so the modal's immediate HUD hide misses it — a deferred (one-frame)
   re-hide catches it; it no-ops if already dismissed.
5. Keycaps show the REAL default binds (W/A/S/D, SPACE, E, Q, ESC; LS/A/
   X/B/RS/START), not the board's design-mock binds (SHIFT/RT) — honesty
   rule beats the mock; RT pressure-boost hint remains in ControlsOverlay.

## Verification

- PreMatchModalSmokeTest: 27/27 (was 15 checks; +12 S-E checks: tape,
  scrim 0.8, 3 STEPS meta, parsed DRIVE/CLIMB/ESCAPE titles, pictos,
  keycap/pad counts, CTA text + hint, HUD hidden + restored).
- Adjacent suites rc=0: ModeSmokeTest, ControlsOverlaySmokeTest,
  TouchControlsSmokeTest, GamepadSupportTest, MenuDepartureSmokeTest
  (101/101), SplashGateTest (11).
- Vision QA: movie frames of the real Evacuation boot — panel centered,
  tape strip, pictos, numerals, columns, CTA all render per board;
  nothing clipped; muted scene + faint ControlsOverlay recap behind
  scrim (pre-existing, fades post-dismiss).
- Full ladder: PASS 61/61 (60 suites + boot), run-20260926-120102,
  from the canonical SERVER working copy.
