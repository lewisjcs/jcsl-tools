#!/bin/bash
# PreToolUse guard: keep the Kiln conductor (main thread) structurally thin.
# While a run is active, the main thread may NOT mutate source or call Compounds
# mutation verbs. Dispatched members (subagents, agent_id present) are exempt.
# Fail-open: any uncertainty → allow (exit 0, no deny).
set -uo pipefail
LIB="$(cd "$(dirname "$0")" && pwd)/lib-kiln-hook.sh"
# shellcheck source=/dev/null
. "$LIB" 2>/dev/null || exit 0

kiln_read_input

# Members (subagents) are exempt — they hold the working tools by design.
kiln_is_subagent && exit 0

# Only enforce while a Kiln run is active.
RUN_DIR=$(kiln_active_run_dir)
[ -z "$RUN_DIR" ] && exit 0

TOOL=$(kiln_field '.tool_name')

# Compounds mutation verbs are conductor-forbidden; reads pass.
case "$TOOL" in
  mcp__compounds-dev__plan_change|mcp__compounds-dev__gen_spec|mcp__compounds-dev__gen_master_spec|\
  mcp__compounds-dev__gen_project_spec|mcp__compounds-dev__generate_tasks|mcp__compounds-dev__create_project|\
  mcp__compounds-dev__add_task|mcp__compounds-dev__update_task|mcp__compounds-dev__implement_task|\
  mcp__compounds-dev__implement_task_finalize|mcp__compounds-dev__implement_all_tasks|mcp__compounds-dev__value_receipt)
    kiln_deny "The Kiln conductor cannot call Compounds mutation tools inline. Dispatch the Planner or Crafter member; the member holds these tools." ;;
esac

# Lexically resolve `..`/`.`/duplicate-slash segments in an absolute path — a pure
# string operation, NOT an existence check (the target need not exist on disk). This
# is required because PreToolUse hooks receive tool_input.file_path exactly as the
# model wrote it, unmodified by Claude Code — a literal "../../repos/x" segment would
# otherwise dodge the `"$WS_ROOT"/repos/*` glob below despite lexically landing inside
# it. Deliberately NOT realpath/readlink -f: those hit the filesystem (can fail or
# differ macOS vs Linux) and this guard must stay fail-open-safe on a path that may
# not exist yet (e.g. a new file under an existing directory).
kiln_normalize_path() {
  local path="$1" part
  local -a out=()
  case "$path" in
    /*) : ;;
    *) printf '%s' "$path"; return 0 ;;   # relative — nothing to anchor traversal against; pass through
  esac
  local IFS='/'
  for part in $path; do
    case "$part" in
      ''|'.') continue ;;
      '..') [ ${#out[@]} -gt 0 ] && unset 'out[${#out[@]}-1]' ;;
      *) out+=("$part") ;;
    esac
  done
  printf '/%s' "${out[*]:-}"
}

# Source mutation: the ONLY protected tree is shipped source under <workspace>/repos/.
# Everything else the conductor may write — workspace project space, /tmp scratch, memory,
# journal — is working space, not shipped source. Deny ONLY writes whose target resolves
# under <workspace>/repos/. Anchoring on the workspace root (derived below) — not a bare
# */repos/* glob — avoids matching an unrelated "repos" segment elsewhere in a path.
WS_ROOT="${RUN_DIR%%/projects/active/*}"
case "$TOOL" in
  Edit|Write|MultiEdit|NotebookEdit)
    FP=$(kiln_field '.tool_input.file_path')
    [ -z "$FP" ] && FP=$(kiln_field '.tool_input.notebook_path')
    [ -z "$FP" ] && exit 0                       # no path resolvable — fail-open
    FP=$(kiln_normalize_path "$FP")
    case "$FP" in
      "$WS_ROOT"/repos/*)
        kiln_deny "The Kiln conductor cannot edit shipped source under repos/ inline. Dispatch the Crafter member — it holds Edit/Write." ;;
    esac
    exit 0 ;;                                     # any non-source path — allowed
esac

exit 0
