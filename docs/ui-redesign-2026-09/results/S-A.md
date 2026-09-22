# S-A — UITheme tokens v2 + MenuBackdrop office dressing

Status: DONE (parent to verify; not claiming VERIFIED).

## Files changed
- scripts/UITheme.gd — added consts only (nothing renamed/removed):
  TEXT_FAIR "9a9aae", PAPER "f2ecdc", GREEN "2fa05a", YELLOW "f2c230",
  RED "e04a3a", INK "231303", TICKER_BG Color(0,0,0,0.35),
  DIM Color(0.02,0.02,0.04,0.72). No helpers added (kept minimal per
  instruction: constants only this slice).
- scripts/MenuBackdrop.gd — added _draw_office_props() called from _draw()
  after skyline, before _draw_office_foreground (mullions/troffer/floor).
  All existing drawing untouched. Additions, all opaque fills, deterministic
  (no random):
  - Water cooler at x 0.06w: rounded-top box, faint cyan-teal bottle glow
    rect (Color(0.22,0.34,0.38)).
  - Copier at x 0.40w: low box with paper-tray lip.
  - Ficus at x 0.74w: trunk + 3-circle round canopy.
  - Prop color Color(0.09,0.09,0.13), lifted ~10-15% above floor pool
    (0.05,0.04,0.06).
  - EXIT sign top-right: green 2fa05a rect 84x30 at (sz.x-120, 36), inner
    white border (4 thin rects), white right-arrow (shaft + 2 head rects).
    No glow, no alpha.
  - Helpers for tests: _office_props() -> Array[Rect2] (3 prop rects),
    _exit_sign_rect() -> Rect2.
  - Grain: skipped as instructed.
- scripts/MenuBackdropPropsTest.gd — NEW test (only new file). SceneTree
  --script style copied from ChairSkinSmokeTest.gd structure.

## Test commands + raw tails

1. /usr/local/bin/godot --headless --path . --script scripts/MenuBackdropPropsTest.gd
   [PASS] MenuBackdropPropsTest: 16 checks — draw cycles, prop rects, exit sign bounds

2. /usr/local/bin/godot --headless --path . --script scripts/MenuLayoutSmokeTest.gd
   [PASS] desktop nav column min fits the ink field (265)
   [PASS] hero panel visible on desktop
   [PASS] hero panel inside right field + viewport ([P: (904.0, 36.0), S: (340.0, 260.0)])
   [PASS] desktop viewport reports 1280x720
   === MENU LAYOUT SMOKE TEST PASS (23/23) ===

3. /usr/local/bin/godot --headless --path . --script scripts/BootTest.gd
   [PASS] res://scenes/ShopSeek.tscn loads
   [PASS] res://scenes/PizzaColony.tscn loads
   [PASS] res://scenes/objects/SabotageTrap.tscn loads
   === ALL CHECKS PASSED ===

Script error scan: grep -iE "script error|parse error|error" over the new
test run output -> zero matches (exit 1, no lines).

git diff --check -> clean (no output).

## Deviations
- tape_style(): not added — slice text says "Keep it minimal: constants only
  this slice" and the tape strip is explicitly deferred to Main.gd later.
- EXIT sign drawn at fixed (sz.x-120, 36) per slice text, not proportional.
- Test assertion "props within bounds" checks the returned sill-band rects
  (prop base rects). The canopy circles visually extend slightly above the
  returned ficus rect; the rect API stays conservative for S-B layout use.
- Draw-order note: _draw_office_props is called AFTER skyline and BEFORE
  mullions/troffer/floor as specified, so the floor band partially overlaps
  prop bases — intentional: props read as standing behind the sill line.
