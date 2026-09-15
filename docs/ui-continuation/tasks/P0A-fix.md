# P0A corrective Flash slice — spec review failed
Run step 1 immediately, minimal prose. Previous P0A worker PID4483 has stopped without results/P0A.md. Preserve its partial implementation. P1A worker is active separately in /Users/rs-mac/projects/fe-ui-p1a-flash: do not touch it. User permits two GLM-5.3 Flash agents. You are replacement runner lane.
Workdir /Users/rs-mac/projects/friday-evacuation. Allowed writes scripts/run_ladder.sh, scripts/ladder_runner.py, scripts/test_ladder_runner.py, docs/ui-continuation/STATUS.md, docs/ui-continuation/results/P0A.md, docs/ui-continuation/evidence/P0A/** ONLY. No commits/push, no new agents, no game code, no global config. Never touch automated-newsletter or pitchforge. Parent's plan edits are foreign.

Parent independently ran harness: 14 tests PASS. But these reproducible spec failures block acceptance:
- SUCCESS_PATTERNS['LoadingFlowSmokeTest'] matches 'LoadingFlowSmokeTest: 1/10 checks passed'. All numeric result summaries must require equal positive passed/total, not just regex shape.
- HeroAssemblySmokeTest accepts '[PASS] first check\n[FAIL] final check' at rc0. Detect explicit suite failure markers even when a success marker exists. Do not blanket-match prose mentioning intentional failing fixtures; inspect exact test formats.
- scan_for_hard_errors('WARNING: leaked SCRIPT ERROR: real failure') returns [] because broad warning exemption precedes hard-error detection. SCRIPT ERROR and Parse Error must NEVER be masked by benign-whitelist lines. Restrict whitelist to actual known teardown patterns; do not blanket ignore arbitrary Condition/index errors.
- Original git diff --check gate vanished from run_ladder.sh. Restore it for real production checkout while allowing temp synthetic fixtures in harness to run without claiming they are real Git repos.
- --suites with zero values plus --no-boot can yield vacuous success. Reject empty suite selection / zero executed phases, bad/nonpositive timeout, and invalid suite identifiers. Label subset runs explicitly so a targeted PASS is not confused with full-ladder PASS.
- Harness docstring falsely says real tests were run and recorded in missing result file. Remove unsupported completion claim. Record actual validation only.

Steps:
1. Read existing runner/harness and P0A brief. Update STATUS IN_REVIEW_FIX with exact next command.
2. Add regression tests FIRST proving above failures via real runner subprocess and synthetic fixtures, not only regex tests. Capture RED to evidence/P0A/review-fix/.
3. Repair minimally, run harness GREEN. Keep suite manifest intact and shared logs durable. One synthetic subprocess at a time. Harness must never accidentally run actual old full ladder against real Godot.
4. No real Godot while P1A worker or any Godot process is live. Do not kill or wait endlessly. This corrective slice can finish harness-only; mark REAL_GAME_VALIDATION_PENDING if test slot is unavailable. Parent will serialize targeted real menu/loading/boot later. Never claim synthetic results validate the game.
5. git diff --check. Write results/P0A.md and STATUS with actual RED/GREEN evidence, scope, commands, unresolved real test gate, exact next action. No VERIFIED/COMMITTED/PUSHED claims.

Budget 20min/28 turns. Stop expanding scope on wrap-up warning and write checkpoint. Stop on 429/I/O errors. No other plan phases.
