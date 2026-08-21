#!/bin/bash
# run_multiplayer_sync_test.sh — Phase 5 two-process multiplayer sync driver.
# Boots the host and client as separate Godot processes over UDP loopback,
# streams both outputs, and fails if either side reports a failure.
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/usr/local/bin/godot}"
PORT="${PORT:-15005}"

echo "=== MULTIPLAYER SYNC TEST (two processes, UDP loopback :$PORT) ==="

HOST_LOG=$(mktemp)
CLIENT_LOG=$(mktemp)

"$GODOT" --headless --path . --script scripts/MultiplayerSyncHost.gd -- --port="$PORT" >"$HOST_LOG" 2>&1 &
HOST_PID=$!
sleep 2
"$GODOT" --headless --path . --script scripts/MultiplayerSyncClient.gd -- --port="$PORT" >"$CLIENT_LOG" 2>&1
CLIENT_RC=$?
wait "$HOST_PID"
HOST_RC=$?

echo "--- HOST OUTPUT (rc=$HOST_RC) ---"
grep -vE "^Godot|WARNING|viewport_set|OpenGL|IMKClient|Saving" "$HOST_LOG"
echo "--- CLIENT OUTPUT (rc=$CLIENT_RC) ---"
grep -vE "^Godot|WARNING|viewport_set|OpenGL|IMKClient|Saving" "$CLIENT_LOG"

if [ "$HOST_RC" -ne 0 ] || [ "$CLIENT_RC" -ne 0 ]; then
  echo "=== MULTIPLAYER SYNC TEST: FAILED (host rc=$HOST_RC client rc=$CLIENT_RC) ==="
  rm -f "$HOST_LOG" "$CLIENT_LOG"
  exit 1
fi
echo "=== MULTIPLAYER SYNC TEST: PASS ==="
rm -f "$HOST_LOG" "$CLIENT_LOG"
exit 0
