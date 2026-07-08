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

# Source mutation: deny unless the target is inside THIS active run's folder (run
# artifacts are allowed). Scoped to the resolved $RUN_DIR, not the run-folder shape —
# a write into some other run's kiln/ dir is still source mutation from this run's view.
case "$TOOL" in
  Edit|Write|MultiEdit|NotebookEdit)
    FP=$(kiln_field '.tool_input.file_path')
    [ -z "$FP" ] && FP=$(kiln_field '.tool_input.notebook_path')
    case "$FP" in
      "$RUN_DIR"/*) exit 0 ;;  # this run's artifact — allowed
      "") exit 0 ;;            # no path resolvable — fail-open
      *) kiln_deny "The Kiln conductor cannot edit source files inline. Dispatch the Crafter member — it holds Edit/Write." ;;
    esac ;;
esac

exit 0
