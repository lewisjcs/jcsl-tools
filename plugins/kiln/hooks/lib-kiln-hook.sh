#!/bin/bash
# Shared helpers for Kiln guard hooks. Sourced, not executed.
# Fail-open everywhere: any internal failure must allow the call (exit 0 / return non-deny).

# Declared default so a guard sourced under `set -u` never trips on an unbound
# KILN_INPUT if kiln_field is ever reached before kiln_read_input (a non-zero exit
# under set -u would be read as a deny — i.e. fail-CLOSED, the opposite of our posture).
KILN_INPUT=""

kiln_read_input() { KILN_INPUT=$(cat); }

kiln_field() { # $1 = jq path, e.g. .tool_input.file_path
  command -v jq >/dev/null 2>&1 || { echo ""; return 0; }
  printf '%s' "$KILN_INPUT" | jq -r "$1 // empty" 2>/dev/null || echo ""
}

# Echo the path of the active run dir (one containing a .active sentinel), or empty.
# Resolves the run whose .active is NEWEST: a crashed/escalated run deliberately
# leaves its sentinels behind for resume (see SKILL.md), so an unordered first-match
# could bind the guards to a stale run and fail-open on the live one. `ls -t` orders
# by mtime and is portable (macOS BSD `find` has no `-printf`); `-exec … +` never runs
# `ls` on zero matches, so no stray output when no run is active.
kiln_active_run_dir() {
  local root; root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo ""; return 0; }
  local sentinel
  sentinel=$(find "$root/projects/active" -maxdepth 3 -name ".active" -path "*/kiln/.active" \
    -exec ls -t {} + 2>/dev/null | head -1)
  [ -n "$sentinel" ] && dirname "$sentinel"
}

# Return 0 if this hook fired inside a subagent (agent_id present), else 1.
kiln_is_subagent() {
  local aid; aid=$(kiln_field '.agent_id')
  [ -n "$aid" ]
}

kiln_deny() { # $1 = reason
  # Build via jq so a reason containing quotes/backslashes can't corrupt the JSON.
  # jq is already a dependency (kiln_field). Fall back to raw printf if it is absent —
  # the lib is fail-open, and every current caller passes a static, quote-free reason.
  if command -v jq >/dev/null 2>&1; then
    jq -nc --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  else
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$1"
  fi
  exit 0
}
