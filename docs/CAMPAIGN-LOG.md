
## 2026-09-27 — CampaignGoal day 1 (11:00–21:00 ET)

**Commits:** 8838b79 (P1A menu input-path contract), 5ed8059 (D5 results
celebration), 7709c1f (ladder IMPORT phase), 7107332 (LayoutPacingTest).

**Tests:** ResultsCelebrationTest 22/22 (new), MenuInputPathTest 13/13 (new),
LayoutPacingTest 9/9 (new), ArtBlenderPropsTest 18/18 (fixed), full ladder
64/64 suites + boot (final certification run in flight at log time).

**What improved (UI + game design):**
- D5 results celebration per ui-design-spec: fade+scale entrance (reduced-
  motion instant), 32px outlined orange winner banner, 24px stat values
  (TOP SPEED orange), VIOLET chair-unlock pills (top-speed stays LIME),
  win-only confetti (world burst + new ImpactFX.confetti_2d top-center
  CPUParticles2D), race HUD dims to 0.35 behind the panel. Vision-QA'd via
  movie frames (evidence/D5/).
- P1A menu real-input contract finished (was interrupted since 09-15): real
  mouse/keyboard paths can't be intercepted — 13 checks.
- Design instrumentation: LayoutPacingTest drives the checkpoint bot through
  all three shipped layouts; today's table 13.5/11.8/12.6s (spread 1.15x —
  balanced).

**Known issues / fixed today:**
- models/box_stack.glb shipped without importable metadata (gitignored by
  policy) → fresh clones failed GLB suites; ladder now has an IMPORT phase.
- The real race HUD is hud_ext (CanvasLayer layer 10) — CanvasLayer has no
  modulate; dimming must target its card groups.
- SceneTree tests assigning an untyped Array to Array[String]/[Dictionary]
  properties throw and hang the run (quit never reached) — type the staging.

**Next steps:** P0B fresh-screen audit (per STATUS.md), then P1B–P5; consider
human-playtest tuning of hazard cadence (software proxies in place).
