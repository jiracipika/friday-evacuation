# Living Office / Frictionless Entry Implementation Plan

> For Hermes: use subagent-driven-development; Astra owns design and final acceptance, GLM 5.3 Flash owns bounded implementation and evidence collection.

Goal: replace the main menu, remove artificial loading friction, and evolve Evacuation into a believable occupied office with optional worker interactions and item-for-powerup trades.
Architecture: retain Godot 4.7, chair physics, four modes and ENet. Separate entry UX, reusable office assemblies, cosmetic workers and host-authoritative trading. Integrate one tested phase at a time.
Tech stack: GDScript, Godot Forward+ desktop / Compatibility Android, authored GLB assets, existing FridayUITheme and test scripts.

## Authority and continuity

This plan is the active entry point for this request. Existing docs/redesign/REDESIGN-PLAN-v2.md and step1/{ART-BIBLE,MODEL-SHEETS,PRESETS,EVACUATION-COMPOSITION}.md remain binding. This plan supersedes step1/UI-LAYOUTS.md sections 3–4 where conflicting: remove mandatory splash acknowledgement, simplify initial navigation, and remove artificial loading delays. Other sections remain binding.

Starting commit: cf83183. Active checkout: /Users/rs-mac/projects/friday-evacuation. Cold backup is /Volumes/HARD/projects/friday-evacuation.
Pre-existing uncommitted files: scripts/PlayerChair.gd, scripts/run_ladder.sh, scripts/HeroAssemblySmokeTest.gd, models/hero_assembly.glb. Do not change, stage or discard these. No active game/worker process observed during discovery.

## Engine decision

Keep Godot. R.E.P.O. uses Unity (source: https://blog.photonengine.com/r-e-p-o-multiplayer-success-powered-by-photon/). Its expressive low-poly shapes, coherent lighting and physical comedy are references, not reasons to port. No copied models, branding, audio or UI. Unity migration would replace working GDScript, physics tuning, LAN and tests. Revisit only for a documented capability Godot cannot provide, not generic graphics dissatisfaction.

Retain RX 580 8GB + i5-8400 / 720p30 construction target, not a verified frame-rate claim. No performance-measurement phase. Keep existing bounded geometry, lights, materials and FX ceilings; never turn on expensive effects to disguise weak assets.

## Phase status

- [x] 0: repo discovery, engine decision, durable plan and initial lane contracts.
- [ ] 1A: entirely restructured menu; no forced start splash; all existing configuration reachable.
- [ ] 1B: truthful scene loading; no timed fake progress; duplicate and failure protection.
- [ ] 1C: incremental procedural setup if scene creation still blocks visible loading; preserve readiness/countdown authority.
- [ ] 1D: actual input-path and visual acceptance, regression ladder, commit/push.
- [ ] 2: believable cubicle/workstation assemblies integrated with real routes.
- [ ] 3: seated working NPCs, bounded local idle animation, contextual dialogue.
- [ ] 4: optional host-authoritative item-for-powerup trade loop.
- [ ] 5: coherent asset/lighting finish and full integrated acceptance.

## Phase 1A — menu design: Friday departure board

Files: scripts/Main.gd, scenes/Main.tscn; new scripts/MenuDepartureSmokeTest.gd. Existing helpers may be used without redesigning them. Preserve public Main properties/methods needed by tests where practical.

At 1280x720: opaque ink navigation occupies x0–512; right side retains office/ride art. Left margin 32, right 32. Brand at y40: FRIDAY 5PM / EVACUATION, ivory 42px, orange 14px kicker `YOUR SHIFT IS OVER.`. Main route is a 52px orange `EVACUATE` button, then a 52px secondary `PLAY WITH FRIENDS`, then `OTHER MODES`, `CUSTOMIZE RIDE`, `OFFICE SETUP`, `SETTINGS`, `CREDITS` as readable secondary actions. No four-card wall, dense stat block, modifiers or dual dropdown rows on initial view. No compulsory splash or briefing acknowledgement simply to reach navigation. The main CTA always starts Evacuation. Selecting OTHER MODES opens an in-menu subview with existing four modes and explicit selection/play/back actions. PLAY WITH FRIENDS opens existing LAN lobby, not a new networking implementation.

CUSTOMIZE RIDE opens rider/chair selectors and details; OFFICE SETUP exposes all existing map variants, modifier controls and touch override. Persist choices with current methods, maintain unlocked/locked behavior. Avoid duplicating signal connections on repeated opens. Back/Escape returns to home and restores focus. Root Escape should not quit unexpectedly. Settings and credits retain actual overlays.

Right composition: existing MenuBackdrop plus MenuHero, no new expensive viewport. Opaque YOUR RIDE panel, ivory/amber, no purple/neon local colors. Left text is left-aligned, no pulsing title. Backdrop motion policy remains restrained; no new flashing. Under 960px hide nonessential preview and use a full-width padded navigation. At short heights scroll content but keep main actions reachable; minimum 48px actionable targets, essential text >=14px. Use Container layout, resize signals, not per-frame geometry churn.

TDD: create tests first for direct CTA, submenu back/focus, all modes/configuration reachable and viewport bounds at 1280x720, 960x540, 640x360. Run old MenuLayoutSmokeTest to distinguish superseded structural assertions from regressions; do not silently delete tests. Show real screenshots for wide and compact layouts. Parent validates actual appearance, not node count alone.

## Phase 1B — truthful loading

Files: scripts/LoadingScreen.gd; new scripts/LoadingFlowSmokeTest.gd and small fixture scenes only if necessary.
Existing issue established from source: MIN_SHOW_TIME=0.8, elapsed-derived progress, synchronous change_scene_to_file, timed dismissal regardless of readiness; no failure handling.

Keep static show_loading(path) compatible with all callers. Mount one root-owned loader, block duplicate requests while active. Render overlay before work. ResourceLoader.load_threaded_request/get_status/get handles resource loading; never get until status LOADED. Percentage is only actual resource-load fraction. Distinct `PREPARING OFFICE` stage after resource load, with no fake percentage. Scene change via loaded PackedScene; dismiss only after target scene exists and readiness is established. No minimum dwell or mandatory fade. Small optional cosmetic fade must not gate input. Invalid paths/type/request/scene errors leave readable error with BACK, release lock and preserve/restore menu. Lifecycle must not free the new scene or leak overlays. Prevent input from double-triggering scene transitions.

Opaque BG #0A0A0F; ivory title 24px; orange progress width320 height12; centered constrained container fits 640x360. Status `LOADING RESOURCES`, `PREPARING OFFICE`, or actionable error. No random obsolete control tips or claims about green arrows. Keyboard/gamepad back action must work on failure. LAN countdown must not be altered.

TDD: nonexistent target, non-PackedScene target, duplicate request, successful transition, overlay cleanup, real progress source/no MIN_SHOW_TIME, failed-then-valid retry. Test actual SceneTree transitions, not source checks alone. Capture stderr and enforce timeout.

## Phase 1C — procedural readiness (dependent lane, not parallel with integration)

Inspect scripts/Evacuation.gd _ready and resource/material builders after 1B. Threaded resource loading does NOT make procedural _ready work asynchronous. If construction remains a blocking monolith, partition construction into bounded deferred main-thread batches with genuine completed-stage reporting. Never touch scene nodes from a worker thread. Preserve setup order, player spawning, floor culling, HUD, network state, briefing and countdown. Add a readiness signal/service and test that countdown/input are gated until ready, without masking partial office geometry. Apply to secondary modes only with individual tests. Do not claim total loading friction fixed merely because the fake timer disappeared.

## Phase 2 — believable office assemblies

Primary files: scripts/OfficeDressing.gd, scripts/LevelLayouts.gd, scripts/Evacuation.gd; new scripts/OfficeWorkstation.gd and scripts/OfficeOccupancySmokeTest.gd. Assign shared-file integration to ONE worker only.

Design: retain clear racing routes and existing four-floor ascent. Add perimeter paired/back-to-back desks with felt half-height partitions, desk return, cable tray, monitor facing seated occupant, keyboard, desk phone, paper tray, mug and personal plant as deliberately varied sets. Partitions ~1.25m tall, 0.08m thick; workstation footprint about 2.4x2.4m. Warm laminate, desaturated teal felt, ivory plastic, graphite frame. Realism through coherent scale and function, not random clutter/noise. Keep door openings >=2m and existing route clearances at least as wide as before. No desk legs/props protruding into reserved racing corridors. No new decorative rigid bodies or shadowed lights.

Start with 2 occupied bays on solid floor 1 plus 2 quiet desk bays; validate then extend to solid usable areas on other stories. Never spawn on story-03 voids, elevator triggers, transfer landings or exit area. Culling ownership must match floor. Use deterministic layout seed and shared materials/meshes. Tests assert safe footprints, seated desk orientation, bounded counts and real scene integration; LevelClearTest and CheckpointBotTest must pass. Save chase-camera and close-up evidence before extending population.

## Phase 3 — office workers and conversation

New scripts/OfficeWorker.gd, scripts/OfficeDialogue.gd, scripts/OfficeWorkersSmokeTest.gd; integrate through workstation controller, not player physics.

Eight maximum detailed active decorative workers, distant simplified/static silhouettes. Adults with existing roster language, no floating capsules: hips on seat, feet at floor, forearms above keyboard, eye line to monitor. Three local cosmetic states: typing, reading, coffee pause. Seated workers do not wander into racing routes. Typing is small wrist/shoulder motion; head glance max12 degrees. Reduced motion uses neutral pose. Animate only current/adjacent visible floors; no decorative replication packets.

Nearby NPC emits one short caption at a time through existing subtitle system, explicit speaker name, max two lines, no modal pause. Example authored lines: `MARA: The fire drill is not billable.` / `DEV: I saved your spreadsheet. You're welcome.` / `SAM: Still waiting for this to print.` Proximity cooldown, repeat suppression, pause/end cleanup. Dialogue never obscures objective or blocks chair control. Test distance/cooldown/reset/scene cleanup and noninterference with races. Actual text may be extended by Astra, not generated dynamically by a network service.

## Phase 4 — optional item trades

Before implementation inspect scripts/PowerUp.gd or actual pickup inventory API, scripts/Network.gd and PlayerChair inventory ownership; record exact hooks here. Do not guess existing item identifiers. New scripts/OfficeTradeService.gd, scripts/OfficeTradePrompt.gd, scripts/OfficeTradeSmokeTest.gd; shared-file integration serialized.

Design: one trade worker in a side alcove on floor1, another optional on floor2. Existing carried item exchanged for one existing bounded powerup; no new currency or mandatory fetch quest. Prompt shows explicit offered item, wanted item, binding and result; available only within 2.2m, low speed, running round, correct item. No E collision (E is jump): resolve current input map and assign a separate remappable interaction action. Desktop/gamepad/touch parity. Trade is deliberate press, not proximity consumption. Insufficient item message does not consume anything. Cosmetic speech does not require trade.

Host owns transaction, validates peer/player, round, worker id, distance, item and capacity. Atomic consume+grant; request-id idempotence; rate limiting; snapshot/reset behavior. Client cannot grant itself powerups or select reward. Per-round worker stock consistent across peers; late join receives state. Tests: valid trade, wrong item, out of range, full inventory, duplicate/replayed request, unauthorized peer, disconnect, rematch reset, two real local ENet peers. Do not claim physical Wi-Fi validated without it.

## Phase 5 — finish and acceptance

Authored furniture/worker silhouette improvements precede additional tiny props. Follow ART-BIBLE/PRESETS for quiet materials, amber/cool hierarchy, reflection/shadow restrictions. No runtime dependency on generated concept images. Screenshot review at gameplay camera distances, menu/input exercises, full serial test ladder and clean real boot. Verify all four modes and LAN entry still work. Report actual tested scope and remaining hardware QA honestly.

## Worker operating contract

Use explicit `hermes chat --provider zai --model glm-5.3-flash --ignore-rules --toolsets terminal,file --oneshot --max-turns 28 --run-budget 1200 --query-file <absolute prompt>` only after a successful routing probe. Never silently substitute glm-5.3 or glm-5.2 if requested id fails. No persistent profile/model changes. Up to three CLI workers permitted by the user's current instruction; start two independent implementation lanes plus a read-only integration audit, then reuse available slots for review/vision. Stop on 429, preserve work and report. Vision worker may use vision toolset; record actual auxiliary model used, do not mislabel vision as Flash if provider uses another model.

Isolated git worktrees per writer. Do not work on automated-newsletter or pitchforge. No worker commits/pushes, no shared-working-tree edits, no edits outside explicit ownership. Report changed files, commands, failures and limitations. Tests run serially per checkout; integration runs serially after workers stop. Parent reviews spec compliance then code quality, exercises final artifact, commits only owned changes to main and pushes; verify origin/main exact hash. No fabricated PASS output. Read combined stdout/stderr and time out hung Godot processes; exit code alone is insufficient.

## Resume procedure

1. Read this file and docs/redesign/step1/STATUS.md; inspect git status/log, git pull --ff-only.
2. Identify live workers before touching their lane. Read docs/living-office/STATUS.md and prompts/results.
3. Preserve listed foreign character files. Recover only completed lane diffs.
4. Continue first unchecked phase, not a fresh redesign. Update phase state with evidence and blockers.
5. Commit/push verified bounded phases. Keep this plan as the handoff even if usage expires.
