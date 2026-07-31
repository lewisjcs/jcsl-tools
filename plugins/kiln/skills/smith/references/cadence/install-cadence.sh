#!/usr/bin/env bash
# Render + load the Smith cadence launchd job. Fails LOUD — a half-installed
# job is worse than none.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$HERE/com.jcsl.smith-cadence.plist.template"
LABEL="com.jcsl.smith-cadence"

render_plist() { # $1 = target path; reads R_* from env
  local target="$1"
  sed -e "s|__WRAPPER__|${R_WRAPPER}|g" \
      -e "s|__WORKSPACE__|${R_WORKSPACE}|g" \
      -e "s|__LOG_DIR__|${R_LOG_DIR}|g" \
      -e "s|__HOUR__|${R_HOUR}|g" \
      -e "s|__MINUTE__|${R_MINUTE}|g" \
      -e "s|__PATH__|${R_PATH}|g" \
      "$TEMPLATE" > "$target"
}

[ "${SMITH_CADENCE_LIB:-}" = "1" ] && return 0

# --- main ---
WS=""; HOUR="7"; MINUTE="30"
while [ $# -gt 0 ]; do
  case "$1" in
    --workspace) WS="$2"; shift 2 ;;
    --hour) HOUR="$2"; shift 2 ;;
    --minute) MINUTE="$2"; shift 2 ;;
    *) echo "install-cadence: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -n "$WS" ] && [ -d "$WS" ] || { echo "install-cadence: --workspace <dir> required (existing)" >&2; exit 2; }

LA_DIR="$HOME/Library/LaunchAgents"
PLIST="$LA_DIR/$LABEL.plist"
LOG_DIR="$WS/projects/active/kiln-smith/smith-suggestions/.cadence-logs"
mkdir -p "$LA_DIR" "$LOG_DIR"

R_WRAPPER="$HERE/smith-cadence.sh" R_WORKSPACE="$WS" R_LOG_DIR="$LOG_DIR" \
R_HOUR="$HOUR" R_MINUTE="$MINUTE" R_PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin" \
render_plist "$PLIST"

plutil -lint "$PLIST"   # fail loud on malformed plist

UID_NUM="$(id -u)"
launchctl bootout "gui/$UID_NUM/$LABEL" 2>/dev/null || true   # idempotent
launchctl bootstrap "gui/$UID_NUM" "$PLIST"
echo "installed: $PLIST (fires daily $HOUR:$MINUTE). Log dir: $LOG_DIR"
echo "manual trigger: launchctl kickstart gui/$UID_NUM/$LABEL"
