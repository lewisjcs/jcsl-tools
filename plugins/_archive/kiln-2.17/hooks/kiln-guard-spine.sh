#!/bin/bash
# PreToolUse guard: no member dispatch before the progress spine exists.
# Denies a main-thread Agent call when a run is active (.active present) but the
# spine sentinel (.spine) has not been written. Fail-open on uncertainty.
set -uo pipefail
LIB="$(cd "$(dirname "$0")" && pwd)/lib-kiln-hook.sh"
# shellcheck source=/dev/null
. "$LIB" 2>/dev/null || exit 0

kiln_read_input
kiln_is_subagent && exit 0            # nested dispatches are not the conductor's first dispatch
[ "$(kiln_field '.tool_name')" = "Agent" ] || exit 0

RUN_DIR=$(kiln_active_run_dir)
[ -z "$RUN_DIR" ] && exit 0           # no active run → not a Kiln dispatch

if [ ! -f "$RUN_DIR/.spine" ]; then
  kiln_deny "Create the TaskCreate progress spine before dispatching a member. The spine is the conductor's first action after announcing the lane."
fi
exit 0
