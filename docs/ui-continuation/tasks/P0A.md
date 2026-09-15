# P0A — trustworthy serial test runner

Run step 1 immediately. Minimal prose. You are the sole GLM-5.3 Flash coding worker. Astra owns design and acceptance. Do not implement other phases.

Checkout: /Users/rs-mac/projects/friday-evacuation
Starting code base: 7088d86 (a documentation-only checkpoint may follow).

Allowed writes ONLY:
- scripts/run_ladder.sh
- scripts/test_ladder_runner.py (new)
- scripts/ladder_runner.py (new, if Python subprocess supervision is needed)
- docs/ui-continuation/STATUS.md
- docs/ui-continuation/results/P0A.md
- docs/ui-continuation/evidence/P0A/**
Do not change game code, other tests, profiles, skills, or any other repo. Never touch automated-newsletter or pitchforge. Do not commit/push. No new agents. Preserve foreign edits. One Godot process at a time. Stop on 429 or filesystem errors and save evidence.

Task:
1. Read scripts/run_ladder.sh and inspect actual suite success/error output patterns in relevant test sources. Write STATUS as STARTED with base SHA, owned paths, next command. Directory is durable; /tmp is not primary evidence.
2. Write unittest/subprocess harness scripts/test_ladder_runner.py FIRST. Use a temporary fake Godot executable to test the runner itself, explicitly distinguish these synthetic fixtures from real game validation. Cases: success; zero-exit SCRIPT ERROR; missing required suite; boot error; timeout; stale prior PASS cannot pass new run; nonzero exit. Run RED against existing runner and save combined output.
3. Minimally repair runner. Expose GODOT_BIN, FE_LADDER_LOG_DIR, FE_LADDER_TIMEOUT_SECONDS. Python subprocess supervision is allowed for portable timeout/process cleanup. Production manifest remains the existing suite list plus MenuDepartureSmokeTest and LoadingFlowSmokeTest. Missing required suite fails, boot errors fail, zero-exit parse/script errors fail. Require suite-specific actual success evidence (inspect formats; do not assume just one regex). Preserve known benign Godot teardown warnings without ignoring real failures. Unique run logs, combined stdout/stderr, explicit command/rc/timeout in results. No silent test skip. Small test-selection/test-root seams are okay if documented and production defaults cannot silently omit suites.
4. Run harness GREEN, then real MenuDepartureSmokeTest, LoadingFlowSmokeTest, and boot via the new runner (bounded serial). Verify Godot binary before use. Do NOT run full ladder yet. Save real logs separately from fake fixture logs. Never fabricate PASS. If existing game test fails, report it, don't modify out-of-scope code.
5. git diff --check. Write results/P0A.md: changed files, RED/GREEN commands and actual outputs, real-test results/log paths, unresolved gaps, exact next command. Mark STATUS EVIDENCE_READY only if evidence exists; otherwise BLOCKED. Do not label VERIFIED/COMMITTED/PUSHED — parent must independently review.

Context: existing run_ladder.sh has missing-suite skip, exit-code-only success, printed-but-nonfatal boot errors, no timeout, /tmp-only logs, and omits recently added menu/loading tests. This phase repairs trustworthiness, NOT menu design. Preserve public test behavior. Run budget is bounded; on budget warning stop expanding and write checkpoint. Do not spend the entire budget analysing.
