# Integration Result — menu lane + loading lane into friday-evacuation

Date: 2026-09-15
Lanes merged: fe-menu-lane, fe-loading-lane -> friday-evacuation
No commits, no push (parent handles). No untouched files modified.

## Files copied (exact list)

From fe-menu-lane:
- scripts/Main.gd
- scripts/Main.gd.uid
- scenes/Main.tscn
- scripts/MenuLayoutSmokeTest.gd
- scripts/MenuLayoutSmokeTest.gd.uid
- scripts/MenuDepartureSmokeTest.gd (new in main)
- scripts/MenuDepartureSmokeTest.gd.uid (new in main)
- scripts/SubviewWrap.gd (new in main)
- scripts/SubviewWrap.gd.uid (new in main)
- docs/living-office/menu-FIX-RESULT.md (new in main)

From fe-loading-lane:
- scripts/LoadingScreen.gd
- scripts/LoadingScreen.gd.uid
- scripts/LoadingFlowSmokeTest.gd (new in main)
- scripts/LoadingFlowSmokeTest.gd.uid (new in main)
- tests/loading/ (whole directory, 8 files: LoadingFixture.tscn, NeverReadyFixture.gd + .tscn, PausedPendingFixture.gd + .tscn, PendingFixture.gd + .tscn)
- docs/living-office/loading-FINAL-RESULT.md (new in main)

## Verification (run in main repo, all headless)

| # | Command | Expected | Result | Exit code |
|---|---------|----------|--------|-----------|
| 1 | godot --headless --path . --quit-after 60 | zero SCRIPT ERROR / Parse Error | 0 errors | 0 |
| 2 | godot --headless --path . --script scripts/MenuLayoutSmokeTest.gd --quit-after 150 | PASS 23/23 | === MENU LAYOUT SMOKE TEST PASS (23/23) === | 0 |
| 3 | godot --headless --path . --script scripts/MenuDepartureSmokeTest.gd --quit-after 150 | PASS 101/101 | === MENU DEPARTURE SMOKE TEST PASS (101/101) === | 0 |
| 4 | godot --headless --path . --script scripts/SettingsRoundTripTest.gd --quit-after 150 | 9/9 | SettingsRoundTripTest: 9/9 checks passed | 0 |
| 5 | godot --headless --path . --script scripts/LoadingFlowSmokeTest.gd --quit-after 180 | 53/53 | LoadingFlowSmokeTest: 53/53 checks passed | 0 |

## Fixes made during merge

None. No missing .uid files, no path/name collisions, no merge-level breakage.

## Conflicts between lanes

None. Menu lane's Main.gd/Main.tscn and loading lane's LoadingScreen.gd/LoadingFlowSmokeTest.gd
coexist cleanly; boot and both smoke suites pass together in the merged tree.

## Untouched (verified via git status — only pre-existing modifications)

PLAN.md, scripts/PlayerChair.gd, scripts/HeroAssemblySmokeTest.gd (+.uid), models/hero_assembly.glb,
scripts/run_ladder.sh, scripts/Evacuation.gd, scripts/EntryAcceptanceTest.gd.
automated-newsletter and pitch-therapy/pitchforge not touched.
