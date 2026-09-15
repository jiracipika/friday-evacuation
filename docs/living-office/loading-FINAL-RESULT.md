# loading-FINAL-RESULT.md

Lane: fe-loading-lane (LoadingScreen + LoadingFlowSmokeTest). Workers ran out of
budget twice; parent (GLM) completed verification and the remaining fixes directly.

## Fixes applied (all verified by LoadingFlowSmokeTest)

1. LoadingScreen.gd `_input()` — error state no longer consumes ALL events.
   While loading, events are still fully suppressed (sentinel tests confirm zero
   leaks). In the error state, mouse events reach the visible BACK button's GUI
   handling and ui_accept/ui_cancel trigger BACK directly.
   [Regression: REAL parsed mouse click on BACK global rect dismisses overlay.]

2. LoadingScreen.gd readiness loop — removed `tree.paused` early-break. The
   loader now polls until actual readiness or the safety timeout; a paused tree
   with a PROCESS_MODE_ALWAYS target no longer dismisses prematurely.
   [Regression: PausedPendingFixture keeps overlay until is_loading_complete(),
   pause intact, >=5 real frames waited.]

3. LoadingScreen.gd — added static `set_readiness_timeout()` /
   `_readiness_timeout()` override (test-only knob; production default 10.0s).

4. LoadingScreen.gd `_go_back()` — post-swap error recovery now RESTORES the
   menu when the loader had already swapped in a broken/incomplete scene
   (tracked via `_swapped`). Pre-swap failures keep the menu untouched.

5. LoadingFlowSmokeTest.gd — repaired the scripted-dedent parse errors
   (lines ~369/385), restored missing menu stand-ins in the GUI-BACK and
   Enter-BACK sections, fixed `READINESS_TIMEOUT_S` → `TIMEOUT_S`,
   resized the bare-SceneTree window (headless default 64x64) before the GUI
   click, and scaled window->canvas coordinates for the parsed mouse click
   (content-scale 2x mismatch made the click land outside the button rect).

## Final results

- LoadingFlowSmokeTest: 53/53 checks passed (3 consecutive clean runs), rc=0
- Boot sanity: `godot --headless --path . --quit-after 60` — 0 SCRIPT/Parse errors

## Known limitations

- Real gamepad hardware events unexercised (headless).
- Coordinate-scaling fix is test-side; production builds use the normal window
  and are unaffected.
