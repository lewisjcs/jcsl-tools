#!/usr/bin/env bash
# Render + load the Smith cadence launchd job. Fails LOUD — a half-installed
# job is worse than none.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$HERE/com.jcsl.smith-cadence.plist.template"
LABEL="com.jcsl.smith-cadence"

escape_sed_repl() { # escapes backslash, & and | for safe use as sed `s|...|repl|` replacement text
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/&/\\&/g' -e 's/|/\\|/g'
}

render_plist() { # $1 = target path; reads R_* from env
  local target="$1"
  local e_wrapper e_workspace e_log_dir e_hour e_minute e_path
  e_wrapper="$(escape_sed_repl "$R_WRAPPER")"
  e_workspace="$(escape_sed_repl "$R_WORKSPACE")"
  e_log_dir="$(escape_sed_repl "$R_LOG_DIR")"
  e_hour="$(escape_sed_repl "$R_HOUR")"
  e_minute="$(escape_sed_repl "$R_MINUTE")"
  e_path="$(escape_sed_repl "$R_PATH")"
  sed -e "s|__WRAPPER__|${e_wrapper}|g" \
      -e "s|__WORKSPACE__|${e_workspace}|g" \
      -e "s|__LOG_DIR__|${e_log_dir}|g" \
      -e "s|__HOUR__|${e_hour}|g" \
      -e "s|__MINUTE__|${e_minute}|g" \
      -e "s|__PATH__|${e_path}|g" \
      "$TEMPLATE" > "$target"
}

validate_range() { # $1=flag name $2=value $3=min $4=max; fails LOUD before render/load
  # $3/$4 are always 0-59 in this script (hour 0-23, minute 0-59), so any valid
  # in-range value is at most 2 digits. Bound the accepted form to 1-2 digits
  # BEFORE the numeric comparison below — otherwise an arbitrarily long
  # all-digit string (e.g. one past LLONG_MAX) makes `[ ... -lt/-gt ... ]`
  # error out on both sides of the `||`, which bash then reads as false,
  # letting the bad value silently pass validate_range.
  case "$2" in
    [0-9]|[0-9][0-9]) : ;;
    *)
      echo "install-cadence: --$1 must be an integer (got: '$2')" >&2
      exit 2
      ;;
  esac
  if [ "$2" -lt "$3" ] || [ "$2" -gt "$4" ]; then
    echo "install-cadence: --$1 must be between $3 and $4 (got: $2)" >&2
    exit 2
  fi
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
validate_range "hour" "$HOUR" 0 23
validate_range "minute" "$MINUTE" 0 59

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
