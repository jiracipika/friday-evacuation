# Friday Evacuation UI / Menu Redesign — Resumable Implementation Plan

> **For Hermes:** Use subagent-driven-development to implement task-by-task. GPT-6 Astra owns planning, visual decisions, and acceptance. GLM-5.3 Flash owns implementation tool calls, coding, and evidence collection. Run one implementation worker at a time.

**Goal:** Finish a coherent, readable Friday departure-board interface without restarting completed redesign work, using small verified phases that survive session loss or a Mac restart.

**Architecture:** Retain Godot, existing Main subviews, FridayUITheme, scene-defined results, and existing LAN/readiness authority. Extend components in place; separate functional repairs from visual polish. Store progress in files and Git, never solely in conversation or live workers.

**Tech stack:** Godot / GDScript, existing Noto Sans design specification, Git, Hermes CLI with explicit zai / glm-5.3-flash routing.

## 1. Current evidence and authority

Discovery timestamp: 2026-09-15 08:05 EDT.

Active checkout: `/Users/rs-mac/projects/friday-evacuation`.
Cold backup: `/Volumes/HARD/projects/friday-evacuation`.
Private repository: `jiracipika/friday-evacuation`.

Observed active HEAD: `7088d86`, main tracking origin/main, clean working tree before this plan. Its recent commits:
- `7088d86`: office-chaos hint fit polish.
- `43eb8c3`: themed dropdowns and soft interior-light backdrop.
- `2899515`: truthful loading, menu subviews, hero assembly.

Observed backup HEAD: `8b780f9`, older UI generation. Do not implement there.
No remote refresh, test run, or visual capture was performed during this planning pass. Commit subjects/source inspection establish landed work, NOT fresh functional or visual acceptance.

`PLAN.md` and `docs/living-office/STATUS.md` have stale unchecked phase-1 work and old lane/foreign-file warnings. Reconcile them against actual Git state; never blindly resume old workers or reimplement their completed changes.

Binding design sources:
1. This plan controls the UI continuation order, reliability protocol, and explicitly stated UI deltas.
2. `PLAN.md` retains the no-forced-splash / truthful-loading departure-board decisions and the deferred living-office roadmap.
3. `docs/redesign/step1/UI-LAYOUTS.md`, `ART-BIBLE.md`, `PRESETS.md`, and `docs/redesign/REDESIGN-PLAN-v2.md` govern unchanged design areas.
4. Older `docs/design-panel/ui-design-spec.md` is historical where superseded. Do not restore its splash gate, neon palette, fallback typography, or dense four-card home screen.

This turn delivers planning only. Implementation phases below are NOT started or verified.

## 2. Scope and visual decisions

Preserve the existing departure-board concept, not a fresh website-style dashboard.

Home hierarchy:
- Small orange `YOUR SHIFT IS OVER.` kicker.
- Ivory two-line `FRIDAY 5PM / EVACUATION` brand.
- Dominant orange `EVACUATE`; always selects the primary mode and honors saved office setup.
- Secondary `PLAY WITH FRIENDS` opens existing LAN flow.
- `OTHER MODES`, `CUSTOMIZE RIDE`, `OFFICE SETUP` are in-menu destinations.
- `SETTINGS` and `CREDITS` are lower-emphasis utilities.
- No mandatory click-to-start screen, fake percentage, invented online population, or invented unlock progress.

Desktop at 1280x720: retain left 40% opaque ink navigation, 32px horizontal padding; keep right side for readable worker/chair silhouette and actual selected ride information. Do not add another live 3D viewport. Below 960 logical pixels, hide nonessential art and use full-width navigation. Under short heights, pin primary actions and scroll secondary content rather than shrinking targets or body copy. Keep home actions usable immediately, including keyboard focus.

Subview shell: opaque surface, clear 24px heading, one scroll region, persistent BACK action. Return focus to the opener. Escape pops only the topmost layer; root Escape does not unexpectedly quit. Never let a hidden underlying screen receive clicks or accept input.

Canonical UI palette: ink #0A0A0F, surface #121921, raised #1B2532, slate #263445, ivory #F3E7D3, muted #B8B5AE, orange #FF9A1A, butter #F2C66D, teal #2C8C91, coral #E45B4F, violet #8674B8. Use existing UITheme helpers/aliases. Main content panels are opaque; decorative shadows may remain translucent. No new local neon literals.

Typography: use packaged Noto Sans as specified; inspect existing assets first and do not download duplicates. Essential text >=14 logical px; explanatory text 16px; buttons 18px; section titles 24px; outcome 32px; brand 42px. Maintain wrapping and distinguish disabled, selected, focused, and hover states. Primary/secondary desktop actions >=52px; touch targets >=48dp after scaling, not merely 48 source pixels.

Motion: optional subview transition <=160ms, <=8px translation; cannot delay input. Neutral/static frame under reduced motion. Retain restrained chair comedy; fixed architecture and lighting, no pulsing navigation or new blur/postprocessing. Status changes need labels/icons, not color alone.

Not in this UI cycle: engine migration, new network protocol, office NPC/trades, new currencies, new game modes, bulk asset generation, global model/profile changes, benchmarking campaign. Living-office phases 2–5 remain deferred rather than canceled. Preserve the current rendering path and existing construction ceilings.

## 3. Crash-safe operating contract

- One Flash writer, one active slice, one Godot process at a time. No parallel worktrees, broad agent swarm, automatic reboot-resume loop, or new cron.
- First inspect mounted paths, `git status`, `git log`, and relevant live worker processes. Never write into a replacement empty mount directory.
- Before implementation, `git pull --ff-only` on clean main. If dirty/diverged, preserve changes and resolve ownership; no automatic stash/reset/clean. Planning did not pull because it was read-only.
- Use one small task per dispatch, normally a production file plus its focused test. Shared-file integration is serial. Stop at a coherent boundary rather than starting another file near budget exhaustion.
- Flash records STARTED before edits, EVIDENCE_READY after tests, and leaves VERIFIED/COMMITTED/PUSHED for independently checked acceptance. Missing evidence is NOT DONE.
- Durable records: `docs/ui-continuation/STATUS.md`, `docs/ui-continuation/tasks/P0A.md` etc., `docs/ui-continuation/results/P0A.md`, and `docs/ui-continuation/evidence/<task-id>/<attempt>/`.
- STATUS contains task ID/state, base SHA, exact owned files, worker PID/session if available, evidence paths, last successful command, next exact command, blockers, accepted SHA, remote SHA. Do not overwrite earlier attempt logs.
- Preserve combined stdout/stderr, command, exit code, and timeout outcome. A process cannot survive a power loss; disk records allow recovery, not uninterrupted execution.
- On restart: read plan + STATUS; inspect any live process; inspect uncommitted diff before dispatch. If prior worker died, mark INTERRUPTED and re-test its diff. Never duplicate a possibly live worker. Never trust old PID alone without checking command/start time.
- After acceptance, commit only explicitly owned files to main, push, and read remote main SHA back. If push fails, label LOCAL_COMMIT_ONLY; do not claim backup. Pull cold backup only after checking its cleanliness and verifying remote state.
- Stop on 429, I/O errors, engine crash, or repeated timeout; save BLOCKED with the actual error. Do not silently swap models. No changes to automated-newsletter or pitchforge.

## 4. Phase ledger

| Phase | Deliverable | Initial state |
|---|---|---|
| P0 | Reliable test/checkpoint foundation and fresh screen audit | NOT STARTED |
| P1 | Home navigation, focus, and short-height layout acceptance | NOT STARTED |
| P2 | Customization, modes, office setup, and utility consistency | NOT STARTED |
| P3 | LAN lobby, loading, briefing, pause transition clarity | NOT STARTED |
| P4 | Results and HUD final readability pass | NOT STARTED |
| P5 | Integrated input/visual/regression acceptance and handoff | NOT STARTED |

Every phase is a checkpoint, not permission for an unbounded run. Audit first: existing conforming behavior gets regression coverage, not a gratuitous rewrite.

## 5. P0 — reliability before more UI changes

### P0A: Make test results trustworthy
Files: modify `scripts/run_ladder.sh`; create `scripts/test_ladder_runner.py`; create STATUS/result documents only in the scope above.

Observed issues: runner treats missing suites as skipped, judges suites only by exit code, prints boot SCRIPT ERROR count without failing, has no per-test timeout, uses /tmp logs, and does not list MenuDepartureSmokeTest or LoadingFlowSmokeTest.

Steps:
1. Write a subprocess harness using a fake Godot executable, not fabricated game-test evidence. Explicit runner seams: `GODOT_BIN`, `FE_LADDER_LOG_DIR`, `FE_LADDER_TIMEOUT_SECONDS`. Use temporary directories for harness fixtures.
2. Show failing harness cases for zero-exit SCRIPT ERROR, missing required suite, boot error, timeout, and stale PASS log. Include a clean-success case.
3. Implement minimal runner correction: portable timeout supervision (Python subprocess is suitable), durable per-run logs, missing-required-test failure, inspect combined stderr/stdout, require each suite's real success contract. Inventory suite output formats instead of assuming one PASS regex. Record known benign teardown noise explicitly.
4. Include MenuDepartureSmokeTest and LoadingFlowSmokeTest in the required manifest after confirming current filenames. Keep test exceptions narrow; don't treat broad ERROR filtering as safe.
5. Run `python3 scripts/test_ladder_runner.py`, a real focused menu/loading test pair, and a real boot. Record actual results separately from synthetic harness results.
6. Review and commit this slice before UI edits.

### P0B: Refresh screen evidence and source-of-truth status
Files: `scripts/UISurveyCapture.gd` only if it cannot open current subviews; add `scripts/UIContinuationCapture.gd` instead if a separate narrowly scoped harness is clearer. Modify `PLAN.md` and `docs/living-office/STATUS.md` only to reconcile inspected completed work; preserve deferred world phases.

1. Read existing capture harness before choosing its exact invocation; identify supported capture arguments, output paths, and quit behavior.
2. Capture home, modes, customize, office setup, settings, lobby, loading/error, pause, HUD, and results from the real current game, one process at a time.
3. Capture 1280x720 and 640x360 first; add 960x540 and 390x844 menu checks for responsive boundaries. Portrait gameplay may retain its orientation guidance rather than promise playable portrait mode.
4. Use bounded GUI capture `--quit-after`; headless is not visual evidence. Ensure window/content-scale coordinates match. Different surface screenshots must actually differ; inspect duplicate hashes.
5. Astra reviews real images and writes specific defects by surface. If unavailable, label VISUAL_QA_BLOCKED; source inspection cannot replace visual acceptance.
6. Reconcile stale status using commit/diff evidence, explicitly distinguish landed from freshly tested.

## 6. P1 — home and navigation

### P1A: Focus/back/input contract
Files: `scripts/Main.gd`, `scripts/MenuDepartureSmokeTest.gd`.
1. Add behavioral tests for direct EVACUATE, saved setup, mouse/keyboard open and BACK, Escape returning one layer, opener focus restoration, no hidden activation, no duplicate connections after repeated opens.
2. Run failing new cases before modifying behavior; retain cases already passing.
3. Repair only observed failures; reuse existing Main public interfaces and lazy subviews.
4. Use `Input.parse_input_event`, not only direct handler calls. Set root.size and canvas/window scaling correctly; restore modified user preferences in tests.
5. Run MenuDepartureSmokeTest, MenuLayoutSmokeTest, SplashGateTest, InputPrefsSmokeTest. Capture affected screen if its geometry changed.

### P1B: Short-height composition
Files: `scenes/Main.tscn`, `scripts/Main.gd`, `scripts/MenuLayoutSmokeTest.gd` (separate from P1A).
1. Assert essential bounds/scroll reachability at 1280x720, 960x540, 640x360 and portrait menu 390x844.
2. Preserve 40% desktop split; full-width compact nav. Pin EVACUATE/friends where short height currently buries them; secondary actions scroll.
3. Keep font sizes/targets; eliminate clipped labels, ghost hero text, and overlays occupying hidden panels. Layout on resize, not each frame.
4. Re-run menu tests and capture both wide/compact states. Astra accepts spacing and silhouette balance before commit.

## 7. P2 — subviews and utilities

### P2A: Modes and customization
Files: `scripts/Main.gd`, `scripts/MenuDepartureSmokeTest.gd`; use `scripts/ChairSkinSmokeTest.gd` and `scripts/CharacterRosterSmokeTest.gd` for regression.
- Modes: selected state is a check/text cue, not disabled state; one selected description and one PLAY SELECTED action. Preserve actual playable labels unless evidence contradicts them.
- Customization: labeled rider/chair selectors, two readable detail lines, real selected preview and explicit lock reason. Popup styling must match button styling, including keyboard focus.
- Test all four choices, selection persistence, locked behavior, repeated open/close, and long labels. Capture the popup OPEN as well as closed.

### P2B: Office setup
Files: `scripts/ModifierMenu.gd`, `scripts/ModifierMenuSmokeTest.gd`; Main integration is a separate follow-up if needed.
- Preserve the recently landed hint-fit fix. Selected chips have check/text plus accent; no mid-word truncation. Limit columns based on actual available width; scroll full content rather than hiding configuration.
- Verify modifier toggle/persistence/reset, layout choice reachability, and initial EVACUATE honoring saved choices. Use RaceModifiersSmokeTest and SettingsRoundTripTest.

### P2C: Settings consistency
Files: discover the current settings controller through Main before dispatch; `scripts/UITheme.gd` only if a shared missing helper is demonstrated; test `scripts/SettingsRoundTripTest.gd` and `scripts/AccessibilitySmokeTest.gd`.
- VIDEO / AUDIO / ACCESSIBILITY / INPUT section rhythm; visible labels and values; pinned BACK; remapping error explanation. Respect reduced motion and existing save semantics.
- Do not reopen token migration globally. One helper change gets caller regression and popup capture.
- Exact settings production file must be recorded in the task brief before coding; do not guess its name.

## 8. P3 — transitions, LAN, and pause

### P3A: Lobby readability, no networking rewrite
Files: discover lobby controller via `Main.gd` preload/open handler before dispatch; tests `scripts/NetworkSmokeTest.gd`, `scripts/NetworkTwoPeerTest.gd`, `scripts/LanAvatarSyncTest.gd`.
- Setup left, real roster right at desktop size; single stacked scroll layout when compact. Name/address labels, truthful status/error, clear host-only start versus client ready behavior.
- Ready uses check + READY. Connecting/empty/error are distinct. Preserve current authority and actual LAN controls.
- Test invalid address, failed connection, retry/back, host/client readiness, repeated reopen. Two local ENet peers prove local protocol behavior, not physical Wi-Fi interoperability.

### P3B: Loader/briefing/pause integration
Files: `scripts/LoadingScreen.gd`, `scripts/LoadingFlowSmokeTest.gd`; separate slice for `scripts/PreMatchModal.gd` or `scripts/PauseMenu.gd` only after verifying filenames.
- Retain threaded resource loading and distinct preparation stage. No artificial dwell. Preparing progress cannot imply procedural readiness has completed.
- Test invalid target, duplicate transition, retry/back via actual input, cleanup, paused briefing, and no early countdown. Pause does not mean scene ready.
- Run LoadingFlowSmokeTest, PreMatchModalSmokeTest, PauseMenuSmokeTest, MenuDepartureSmokeTest. Capture loading error, briefing, pause and recovered menu.

## 9. P4 — results and HUD continuity

### P4A: Results outcome hierarchy
Files: `scenes/Evacuation.tscn`, `scripts/Evacuation.gd`; create `scripts/ResultsFlowSmokeTest.gd`. Inspect current results implementation first; older 'S5 pending' is not reliable status.
- Retain existing result/stat data. Center an opaque raised panel constrained to viewport margins; 600px preferred width, not mandatory fixed size. Outcome 32px, concise actual summary, two-column stats on wide screens / one column compact, visible REMATCH and MAIN MENU.
- Record/unlock pills appear only for real events. Reduced-motion/FX ceilings respected; no new confetti system merely to satisfy an obsolete spec.
- Existing authority controls rematch; clients cannot start independently. Hide gameplay-only HUD/inputs beneath results.
- Test win/loss, no false record/unlock, compact wrap, actual button paths, return-to-menu cleanup, rematch reset. Run ModeSmokeTest and network regression when authority paths touched.

### P4B: HUD readability audit and narrow fixes
Files: `scripts/HUD.gd`, `scripts/ArtHUDTest.gd`; relevant touch tests.
- Preserve current D2 hierarchy. Objective and timer first, player resources second; minimize central route obstruction. Labels plus shapes for danger/status. Reserve numeral width; no obsolete control tips.
- Test short-height HUD, long objective/subtitle, low-time warning, pause/results restoration, reduced motion and touch action separation.
- No camera/physics/world redesign in this slice. Capture real gameplay views, not just a standalone UI scene.

## 10. P5 — integrated acceptance

1. Add all new required tests to the repaired serial runner; verify no suites are silently skipped.
2. Run targeted tests after each slice and full ladder at phase boundaries when the machine is stable. Each test has a bounded timeout; run the long ladder as one background process with completion notification, never multiple ladders.
3. Run real boot, verify no SCRIPT ERROR/parse errors, exercise menu -> each mode -> pause -> results/menu, and host/client LAN flow.
4. Capture final representative wide/compact surfaces and open dropdown/error states. Astra signs off actual images and input evidence, not worker prose.
5. Record test commands/results, accepted commit, remote SHA, remaining physical hardware QA. No unmeasured performance claims.
6. Update plan ledger + STATUS with next exact action. Commit/push verified scope. Remote read-back is required before calling it safely backed up.

## 11. GLM dispatch template

Resolve the installed CLI with `hermes chat --help` (done during planning: flags below exist). Use explicit routing; do not change global parent/delegation configuration.

First execution routing probe:

    hermes chat --provider zai --model glm-5.3-flash --ignore-rules --toolsets terminal,file --oneshot --max-turns 3 --run-budget 120 -q 'Return ROUTE_OK only. Do not edit files or run tools.'

Then one task, using a saved brief and durable console log:

    hermes chat --provider zai --model glm-5.3-flash --ignore-rules --toolsets terminal,file --oneshot --max-turns 28 --run-budget 1200 --query-file /absolute/path/to/task-brief.md

Invoke from the active checkout using the terminal tool's workdir, background=true and notify=true for bounded implementation. Capture console output to the task's durable evidence directory. This provides session independence, not power-loss survival. Re-probe if routing fails; stop rather than substituting another GLM identifier. The routing probe was NOT run in this planning turn.

Each task brief must contain:
- Run step 1 immediately; minimal prose; actual tools and real evidence required.
- Exact base SHA, absolute checkout, source-of-truth plan path, allowed files, prohibited files.
- One task only, design rules copied verbatim, failing-test-first commands, success and stop conditions.
- Preserve unrelated changes. No commit/push by worker; no new agents; no broad rename/regex replacement; no other projects.
- Before exit write result with actual commands/rc/log paths, changed files, unresolved defects, next action. If budget warning occurs, stop expanding scope and write checkpoint.
- `--ignore-rules` omits injected project context: the brief must explicitly include all relevant constraints.

Parent review checks source diff and raw logs independently; runs acceptance tests separately before VERIFIED. Flash remains the coding executor. Any appearance-changing workaround returns to Astra.

## 12. First action after this plan

Create and execute ONLY P0A's brief with Flash after clean-tree ownership check and pull. Save this plan to a verified Git commit before code work so a restart can find it. Then P0B provides fresh visual evidence to refine remaining tasks; do not dispatch all phases together.

Resume instruction:

> Read `.hermes/plans/2026-09-15_080521-friday-ui-resumable-plan.md` and `docs/ui-continuation/STATUS.md` in `/Users/rs-mac/projects/friday-evacuation`. If STATUS is absent, implementation has not been checkpointed: inspect Git and processes, then begin P0A. Astra plans/reviews, glm-5.3-flash via zai implements one slice at a time. Preserve all partial work and verify before continuing.
