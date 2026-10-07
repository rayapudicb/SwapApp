#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly MOBILE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly SIMULATOR_NAME="${SWAPPY_IOS_SIMULATOR_NAME:-iPhone 17 Pro}"
readonly API_PID_FILE="${TMPDIR:?TMPDIR is required}swappy-local-dev/api-internal.pid"

api_pid_before="$(awk 'NR == 1 {print; exit}' "$API_PID_FILE" 2>/dev/null || true)"
"$SCRIPT_DIR/ensure_local_api.sh"
api_pid_after="$(awk 'NR == 1 {print; exit}' "$API_PID_FILE" 2>/dev/null || true)"
started_api=false
if [[ -n "$api_pid_after" && "$api_pid_after" != "$api_pid_before" ]]; then
  started_api=true
fi

cleanup() {
  if [[ "$started_api" == true ]]; then
    "$SCRIPT_DIR/stop_local_api.sh" || true
  fi
}
trap cleanup EXIT INT TERM

simulator_id="${SWAPPY_IOS_SIMULATOR_ID:-}"
if [[ -z "$simulator_id" ]]; then
  simulator_id="$(
    xcrun simctl list devices available |
      awk -F '[()]' -v name="$SIMULATOR_NAME" \
        '$0 ~ name && $0 ~ /Shutdown|Booted/ {print $2; exit}'
  )"
fi

if [[ -z "$simulator_id" ]]; then
  echo "No available '$SIMULATOR_NAME' simulator was found." >&2
  echo "Set SWAPPY_IOS_SIMULATOR_NAME or SWAPPY_IOS_SIMULATOR_ID." >&2
  exit 1
fi

xcrun simctl boot "$simulator_id" 2>/dev/null || true
open -a Simulator
xcrun simctl bootstatus "$simulator_id" -b

cd "$MOBILE_ROOT"
flutter run \
  -d "$simulator_id" \
  -t lib/main.dart \
  --dart-define=SWAPPY_API_BASE_URL=http://127.0.0.1:3100
