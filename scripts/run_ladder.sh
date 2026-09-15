#!/bin/bash
# run_ladder.sh — full serial verification ladder for friday-evacuation.
# Thin wrapper: real supervision lives in scripts/ladder_runner.py (Python 3.9,
# stdlib only) which provides timeouts, per-suite log files, success-evidence
# scanning, boot-error detection, and unique run directories.
#
# Environment overrides:
#   GODOT_BIN               godot executable (default /usr/local/bin/godot)
#   FE_LADDER_LOG_DIR       log root (default <repo>/docs/ui-continuation/evidence/ladder-runs)
#   FE_LADDER_TIMEOUT_SECONDS  per-suite timeout (default 300)
#
# Robust self-location: works for absolute, relative, and PATH-based launches
# (the symlink case is resolved via readlink -f when available).
set -uo pipefail
SELF="${BASH_SOURCE[0]:-$0}"
if command -v readlink >/dev/null 2>&1; then
    RESOLVED="$(readlink -f "$SELF" 2>/dev/null)" || RESOLVED=""
    if [ -n "$RESOLVED" ]; then
        SELF="$RESOLVED"
    fi
fi
SCRIPT_DIR="$(cd "$(dirname "$SELF")" && pwd -P)" || exit 1
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# git diff --check gate: real, but only meaningful inside an actual Git
# work tree. Harness temp dirs that are genuinely not Git repos skip it
# (and say so explicitly); a real checkout MUST pass it or the run fails.
cd "$REPO_ROOT" || exit 1
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if ! git diff --check > /tmp/fe_ladder_diff_check.$$ 2>&1; then
        echo "git diff --check FAILED (whitespace/conflict-marker errors;" \
             "full output below):" >&2
        cat /tmp/fe_ladder_diff_check.$$ >&2
        rm -f /tmp/fe_ladder_diff_check.$$
        exit 1
    fi
    rm -f /tmp/fe_ladder_diff_check.$$
    echo "git diff --check: clean"
else
    echo "git diff --check: SKIPPED (not a git work tree)"
fi

exec python3 "$SCRIPT_DIR/ladder_runner.py" "$@"
