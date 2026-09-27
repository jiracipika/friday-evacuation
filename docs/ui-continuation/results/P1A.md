# P1A — menu input-path contract: COMPLETE (parent-resumed on main)

## Provenance
- Original worker brief: docs/ui-continuation/tasks/P1A.md (isolated worktree
  /Users/rs-mac/projects/fe-ui-p1a-flash, branch work/ui-p1a-flash, base 65c9dae).
  The 2026-09-15 worker was interrupted at RED with two bugs in its own draft
  (phantom `FridayUITheme` identifier in Main.gd:379 — never committed — and a
  `_block_navigation` assignment that only failed because the script-less
  Control fallback couldn't take it). Evidence preserved in that worktree
  (evidence/P1A/inputpath-red.log).
- Resumed 2026-09-27 by the CampaignGoal parent ON MAIN (base d590450): the
  overnight menu work already absorbed part of P1A's checklist into
  MenuDepartureSmokeTest (real Escape via InputEventAction, focus restoration,
  connection-dedupe, saved-setup-before-EVACUATE). The genuinely missing
  coverage was the REAL mouse/keyboard activation path.

## Delivered
- scripts/MenuInputPathTest.gd (NEW, 13 checks): hover-lands-on-EVACUATE proof
  (gui_get_hovered_control at the rect center), real mouse press/release on
  EVACUATE selects Evacuation, real Enter activates the focused OTHER MODES,
  real Escape KEY closes the layer + restores focus, clicking a HIDDEN
  control's rect does not activate it, real click on subview BACK closes +
  restores focus.
- scripts/ladder_runner.py: MenuInputPathTest registered in PRODUCTION_SUITES
  + pass-pattern table.
- Tests-only change: no Main.gd repairs were needed — every real-input path
  already behaves correctly on main. Reported honestly per the brief's TDD
  rule (all new coverage passed first run).

## Verification
- Command: /usr/local/bin/godot --headless --path . --script
  scripts/MenuInputPathTest.gd -- --test-mode (bounded 120s subprocess)
- Result: === MENU INPUT PATH TEST PASS (13/13) === EXIT=0
- Log: /tmp/p1a-green.log (stdout noise: pre-existing ModeCard _draw_icon
  draw-outside-_draw errors, cosmetic, unrelated — flagged for P2 cleanup).

## Gaps / next
- ui_accept covered via KEY_ENTER; Space could be added but the action mapping
  is already exercised by SplashGateTest.
- The worktree /Users/rs-mac/projects/fe-ui-p1a-flash is now RETIRED — its
  only unique content was docs + logs, superseded by this file. Safe to delete
  after this commit lands.
