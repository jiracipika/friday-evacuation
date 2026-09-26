# S-F RESULTS — Results panel + Pause menu (spec section 7)

Implementer: GLM 5.3 Flash, 2026-09-26, canonical repo
(/Volumes/SERVER/sol-workspace/repos/friday-evacuation). Base: dad55bc.

## Scope

- **UITheme.gd**: two new shared primitives — `TapeStrip` (moved from
  PreMatchModal so pause/results/how-to share one drawn tape; R7 one
  use per screen) and `MeterBar` (honest meter: track + ORANGE fill +
  reference tick, clamped; R5). Inner-class literals duplicated with a
  sync comment — inner classes cannot reach outer-class statics, and a
  class_name self-reference breaks raw SceneTree compiles.
- **Evacuation.gd results** (spec S5): tape strip + RESULTS header +
  tilted red FORM EX-02 stamp (R1: red = stamps); stats grid (TOP SPEED
  with MeterBar + reference tick at the previous personal best — hidden
  on the first race — TRAPS HIT, TIME); LIME record pills row
  ("★ NEW TOP-SPEED RECORD" / "◆ NEW CHAIR: …"); StatsLabel demoted to
  the muted modifiers caption; winner restyled white. Buttons were
  already UITheme primary/secondary. confetti unchanged (D5).
- **PauseMenu.gd**: hazard-tape header strip, white PAUSED title, and
  the panel re-parented under a full-rect CenterContainer.

## Behavior preserved

`_end_race` flow (StatsManager record, unlocks, announcer, captions),
Rematch/Menu wiring, pause resume/settings/quit lifecycle, and the
`PauseRoot/PausePanel` node (now `PauseRoot/PauseCenter/PausePanel` —
test updated).

## Key findings

1. MeterBar's track in SURFACE (#1c1c2e) was invisible on the
   SURFACE_RAISED panel — the track is SURFACE_HOVER (#25253a). Caught
   by movie-frame vision QA, not by code checks.
2. The Node method for a child's sibling position is `get_index()` —
   `get_node_index()` does not exist (CheckpointBotTest's real-race
   `_end_race` call caught the runtime error the compiler missed).
3. Unnamed nodes get auto-names that do NOT match their script class —
   name TapeStrip instances explicitly or find_child misses them.
4. `real_pause` in UISurveyCapture is ignored once match_state ==
   finished (Evacuation gates pause) — capture pause BEFORE finishing.

## Verification

- PauseMenuSmokeTest ALL PASS (panel path updated + tape-header check
  added, 4 modes x 2 opens); PreMatchModalSmokeTest 27/27 (tape now
  shared from UITheme); VisualDesignSmokeTest PASS (+ TapeStrip/MeterBar
  primitive checks); CheckpointBotTest ALL PASS 12 (drives a REAL race
  through the new `_end_race` populate); LevelClearTest PASS;
  StatsRoundTripTest PASS; ModeSmokeTest PASSED.
- Vision QA movie frames: results panel (tape, stamp, grid, tick,
  pills-when-earned, REMATCH/MAIN MENU) and pause menu (tape, white
  title, centered, muted game) both render per spec; meter track fix
  verified in the same capture round.
- Full ladder: PASS 61/61 (60 suites + boot), run-20260926-124202,
  from the canonical SERVER working copy.
