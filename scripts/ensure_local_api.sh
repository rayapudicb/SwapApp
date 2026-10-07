#!/usr/bin/env bash

set -euo pipefail
umask 077

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly MOBILE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly BACKEND_ROOT="$(
  cd "${SWAPPY_BACKEND_ROOT:-$MOBILE_ROOT/../dev/Swappy}" 2>/dev/null && pwd || true
)"
readonly BACKEND_ENV="$BACKEND_ROOT/apps/api/.env"
readonly API_BASE_URL="http://127.0.0.1:3100"
readonly INTERNAL_PROBE_ID="00000000-0000-4000-8000-000000000000"
readonly STATE_ROOT="${TMPDIR:?TMPDIR is required}swappy-local-dev"
readonly API_LOG="$STATE_ROOT/api-internal.log"
readonly API_PID_FILE="$STATE_ROOT/api-internal.pid"
readonly START_LOCK="$STATE_ROOT/api-starting"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required local command is missing: $1" >&2
    exit 1
  fi
}

read_env_value() {
  awk -F= -v key="$1" '
    $1 == key {
      value = substr($0, index($0, "=") + 1)
      gsub(/^[[:space:]"]+|[[:space:]"]+$/, "", value)
      print value
      exit
    }
  ' "$BACKEND_ENV"
}

health_contract_is_ready() {
  local response
  response="$(curl --silent --show-error --fail --max-time 2 \
    "$API_BASE_URL/health" 2>/dev/null || true)"
  jq --exit-status '
    type == "object" and
    (keys | sort) == ["service", "status", "version"] and
    .status == "ok" and
    .service == "swappy-api" and
    .version == "0.1.0"
  ' >/dev/null 2>&1 <<<"$response"
}

internal_otp_capability_is_ready() {
  local response
  response="$(curl --silent --show-error --max-time 2 \
    "$API_BASE_URL/internal/v1/otp-challenges/$INTERNAL_PROBE_ID" \
    2>/dev/null || true)"
  jq --exit-status '
    type == "object" and
    .code == "INTERNAL_OTP_CHALLENGE_NOT_FOUND"
  ' >/dev/null 2>&1 <<<"$response"
}

api_is_ready() {
  health_contract_is_ready && internal_otp_capability_is_ready
}

listener_belongs_to_backend() {
  local listener_pid listener_cwd listener_uid
  listener_pid="$(
    lsof -nP -iTCP:3100 -sTCP:LISTEN -t 2>/dev/null | awk 'NR == 1 {print; exit}'
  )"
  [[ "$listener_pid" =~ ^[0-9]+$ ]] || return 1
  listener_cwd="$(
    lsof -a -p "$listener_pid" -d cwd -Fn 2>/dev/null |
      awk 'substr($0, 1, 1) == "n" {print substr($0, 2); exit}'
  )"
  listener_uid="$(
    lsof -a -p "$listener_pid" -d cwd -Fu 2>/dev/null |
      awk 'substr($0, 1, 1) == "u" {print substr($0, 2); exit}'
  )"
  [[ "$listener_uid" == "$(id -u)" ]] || return 1
  case "$listener_cwd" in
    "$BACKEND_ROOT" | "$BACKEND_ROOT"/*) return 0 ;;
    *) return 1 ;;
  esac
}

for command in awk curl id jq lsof mkdir pg_isready pnpm ps rg stat; do
  require_command "$command"
done

if [[ ! -f "$BACKEND_ROOT/package.json" || ! -f "$BACKEND_ENV" ]]; then
  echo "Configured Swappy backend is incomplete: $BACKEND_ROOT" >&2
  echo "Set SWAPPY_BACKEND_ROOT to the backend repository path." >&2
  exit 1
fi

if [[ -L "$BACKEND_ENV" || "$(stat -f '%Su' "$BACKEND_ENV")" != "$(id -un)" || \
  "$(stat -f '%Lp' "$BACKEND_ENV")" != "600" ]]; then
  echo "Backend .env must be a current-user-owned regular file with mode 0600." >&2
  exit 1
fi

if [[ "$(read_env_value NODE_ENV)" != "development" || \
  "$(read_env_value SWAPPY_INTERNAL_OTP_INSPECTION_ENABLED)" != "true" ]]; then
  echo "Internal OTP requires NODE_ENV=development and explicit inspection enablement." >&2
  exit 1
fi

database_url="$(read_env_value DATABASE_URL)"
if [[ ! "$database_url" =~ ^postgres(ql)?://[^@]+@(127\.0\.0\.1|localhost|\[::1\])(:([0-9]+))?/ ]]; then
  echo "Internal OTP refuses a non-loopback DATABASE_URL." >&2
  exit 1
fi
database_host="${BASH_REMATCH[2]}"
database_port="${BASH_REMATCH[4]:-5432}"
if [[ "$database_host" == "[::1]" ]]; then
  database_host="::1"
fi
unset database_url

if lsof -nP -iTCP:3100 -sTCP:LISTEN -t >/dev/null 2>&1; then
  if listener_belongs_to_backend && api_is_ready; then
    echo "Swappy internal API is ready at $API_BASE_URL."
    exit 0
  else
    echo "Port 3100 is occupied, but it is not the configured Swappy internal API." >&2
    echo "Stop the other process and run this preflight again." >&2
    exit 1
  fi
fi

if ! pg_isready -h "$database_host" -p "$database_port" >/dev/null 2>&1; then
  echo "The configured loopback PostgreSQL service is not ready." >&2
  echo "Start the local PostgreSQL service before launching Swappy." >&2
  exit 1
fi
unset database_host database_port

if [[ -L "$STATE_ROOT" ]]; then
  echo "Refusing a symbolic-link local state directory: $STATE_ROOT" >&2
  exit 1
fi
mkdir -p "$STATE_ROOT"
chmod 700 "$STATE_ROOT"
if [[ "$(stat -f '%Su' "$STATE_ROOT")" != "$(id -un)" ]]; then
  echo "Local state directory is not owned by the current user." >&2
  exit 1
fi

for path in "$API_LOG" "$API_PID_FILE"; do
  if [[ -L "$path" ]]; then
    echo "Refusing symbolic-link local state: $path" >&2
    exit 1
  fi
done

if [[ -d "$START_LOCK" ]]; then
  starter_pid="$(awk 'NR == 1 {print; exit}' "$START_LOCK/pid" 2>/dev/null || true)"
  starter_command="$(ps -p "$starter_pid" -o command= 2>/dev/null || true)"
  if [[ ! "$starter_pid" =~ ^[0-9]+$ ]] || \
    ! kill -0 "$starter_pid" 2>/dev/null || \
    [[ "$starter_command" != *"ensure_local_api.sh"* ]]; then
    rm -f "$START_LOCK/pid"
    rmdir "$START_LOCK" 2>/dev/null || true
  fi
fi

if mkdir "$START_LOCK" 2>/dev/null; then
  echo "$$" >"$START_LOCK/pid"
  trap 'rm -f "$START_LOCK/pid"; rmdir "$START_LOCK" 2>/dev/null || true' EXIT
  (
    cd "$BACKEND_ROOT"
    nohup pnpm dev:api:internal >"$API_LOG" 2>&1 &
    echo "$!" >"$API_PID_FILE"
  )
  echo "Starting the loopback-only Swappy internal API."
else
  echo "Another guarded launcher is starting the Swappy API; waiting."
fi

for _ in {1..60}; do
  if api_is_ready; then
    echo "Swappy internal API is ready at $API_BASE_URL."
    exit 0
  fi
  if [[ -f "$API_LOG" ]] && \
    rg --quiet 'DATABASE_RUNTIME_BOUNDARY_INVALID' "$API_LOG"; then
    "$SCRIPT_DIR/stop_local_api.sh" >/dev/null 2>&1 || true
    echo "The Swappy API refused its database security boundary." >&2
    echo "Apply the approved local migrations with the migration-only role." >&2
    exit 1
  fi
  sleep 1
done

"$SCRIPT_DIR/stop_local_api.sh" >/dev/null 2>&1 || true
echo "Swappy internal API did not become ready within 60 seconds." >&2
echo "Review the current-user-only log: $API_LOG" >&2
exit 1
