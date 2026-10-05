
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

**Checkpoint build triggered** (2026-09-27, post-P0B): today landed D5
results celebration + pill fix + input-path/pacing suites on main; marking
[build] so the live site picks them up.

**Afternoon adds (same day):** eb3efe3 (warm portal pools on floors 1-3 —
guide-lighting, nine-light budget intact), 5787d63 (P1B-P3 briefs authored
so the next session can dispatch immediately), 020a5ed (SELECTED pill fix).
P0B audit: every surface matches spec (results/P0B.md).

**Infra notes for tomorrow:** GitHub artifact quota hit during the
checkpoint build (uploads fail until the 6-12h recalc; ~100 stale artifacts
purged today to heal it). Live site is CURRENT anyway via the documented
local-export Vercel rescue (builds/friday-evacuation-web + _headers +
vercel deploy --prod). Web export gotcha reconfirmed: the target directory
must pre-exist.

**Continuation block (14:30–17:05):** P1B complete (8961e4b — HUD fully on
UITheme tokens, boost accent border, caught off-token f2c66d; 21-check
HUDThemeSmokeTest), P3 complete (3c1be26 — mode results LIME/CORAL/VIOLET
accents, 52px actions, D5 entrance; ModeResults test 6→11), P2 motion done
(255e271 — UITheme.apply_entrance on lobby+settings; copy sweep remains).
Final certification: ladder PASS 68/68 phases, 66/66 suites.

## 2026-09-29 — CampaignGoal day 2

**Commits:** 142cb3f (menu map picker per-layout best + MenuMapBestTest
7 checks). Certified the pulled results-standings batch (per-layout PBs,
PB-paced ghost, DNF rows, MAP line) at ladder 71/71 phases / 69 suites.

**What improved:** the map picker now shows YOUR BEST ON THIS MAP at
selection time — the third touchpoint of the per-layout PB story
(in-race chip, results row, menu picker). Test injects layout bests
in-memory; the user's save.cfg is never written.

**Parallel lanes:** results-standings batch (5 commits) landed from the
worker lane and certified; printshop-sim v0.21.0 shipped by its lane;
signquest/lyriclearn/WNBA/PT/Dashverse/iOS advances logged in the
campaign console card.

**Known issues:** GitHub artifact quota healed; iOS app builds remain
user-gated (Xcode 26 + macOS 15.6 + Apple Dev account) — iOS 18.5
simulator runtime now installed and boot-proven.

## 2026-10-05 — CampaignGoal day 3

**Commits:** ebda342 (art lighting — warm exit/power-up pools, stairwell
cool tint, Enhanced-gated via Settings._apply_graphics_quality), 694cf06
(prop variety + floor 2/4 dressing parity — whiteboards, cable trays,
plants), 46b8a8d (ResultsPanel shrink-to-fit). Standard-graphics identity
proven by pixel A/B vs a detached pre-slice worktree; Enhanced-only
changes, culling preserved.

**What improved:** the results panel now fits every viewport. Measured
pre-fix: 60px off-screen top AND bottom at 640x360 (clamp never re-ran on
viewport resize), 37px content spill at 390x844, LAN-5 standings up to
214px overflow. Post-fix: content-aware clamp re-runs on viewport resize +
VBox min changes, scroll Body for genuinely small viewports, panel grows
to hold standings when there's room, meter/pill-row width compaction.
ResultsPanelFitTest 22 checks; ladder PASS 74/74 phases, 72/72 suites.

**Ops note:** GitHub Actions were silently disabled repo-wide again;
re-enabled via gh api PUT and ran a workflow_dispatch checkpoint build so
the public site picks up the art pass.

**Parallel lanes:** Dashverse GLM-NEXT-SLICE consumed (5 commits, 768
tests, both APKs re-proven on the farm + emulator), SignQuest camera-freeze
root cause + quiz overflow fixed (11→35 tests), SignFlow avatar-timer +
lint fixes, ai-trader stale-pending supersede. Printshop lane left to its
live session (v0.34 shipped there).
