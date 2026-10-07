#!/usr/bin/env bash

set -euo pipefail
umask 077

readonly STATE_ROOT="${TMPDIR:?TMPDIR is required}swappy-local-dev"
readonly API_PID_FILE="$STATE_ROOT/api-internal.pid"

if [[ ! -f "$API_PID_FILE" || -L "$API_PID_FILE" ]]; then
  exit 0
fi

api_pid="$(awk 'NR == 1 {print; exit}' "$API_PID_FILE")"
if [[ ! "$api_pid" =~ ^[0-9]+$ ]] || ! kill -0 "$api_pid" 2>/dev/null; then
  rm -f "$API_PID_FILE"
  exit 0
fi

api_command="$(ps -p "$api_pid" -o command= 2>/dev/null || true)"
if [[ "$api_command" != *"pnpm dev:api:internal"* ]]; then
  echo "Refusing to stop an unrecognized process recorded in $API_PID_FILE." >&2
  exit 1
fi

collect_descendants() {
  local parent="$1"
  local child
  while read -r child; do
    [[ -z "$child" ]] && continue
    collect_descendants "$child"
  done < <(pgrep -P "$parent" 2>/dev/null || true)
  echo "$parent"
}

api_processes="$(collect_descendants "$api_pid")"
# Word splitting is intentional: every value came from pgrep and was checked
# through the parent/child process tree rooted at the recorded guarded PID.
# shellcheck disable=SC2086
kill -TERM $api_processes 2>/dev/null || true

for _ in {1..20}; do
  if ! kill -0 "$api_pid" 2>/dev/null; then
    rm -f "$API_PID_FILE"
    echo "Stopped the guarded Swappy internal API."
    exit 0
  fi
  sleep 0.25
done

echo "The guarded API did not stop cleanly; inspect PID $api_pid." >&2
exit 1
