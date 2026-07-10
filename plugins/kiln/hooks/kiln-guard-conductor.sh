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

# Source mutation: deny unless the target is workspace project space. The exemption is the
# whole `<workspace>/projects/active/` tree, anchored on the resolved workspace root — run
# folders (`.../<run-id>/kiln/`), ticket-root docs (`.../<run-id>/grounding.md`, spec/plan),
# and `.handoffs/` all live there and are conductor working space, NOT shipped source. Shipped
# source lives under `<workspace>/repos/` (outside `projects/`), which stays denied. This is
# intentionally NOT per-run scoped: the conductor may write any project folder (user direction) —
# the boundary is "project space vs source repo", not "whose run". Anchoring on the workspace
# root (not a bare `*/projects/active/*` glob) defeats a source repo that nests its own
# `projects/active/` subtree — the same path-confusion class the memory-decoy case guards.
# $RUN_DIR is `<workspace>/projects/active/<run-id>/kiln`; strip at `/projects/active/` for the root.
WS_PROJECTS="${RUN_DIR%%/projects/active/*}/projects/active"
case "$TOOL" in
  Edit|Write|MultiEdit|NotebookEdit)
    FP=$(kiln_field '.tool_input.file_path')
    [ -z "$FP" ] && FP=$(kiln_field '.tool_input.notebook_path')
    case "$FP" in
      "$WS_PROJECTS"/*) exit 0 ;;  # workspace project space — allowed
      "") exit 0 ;;                # no path resolvable — fail-open
    esac
    # Housekeeping allow-path (spec §5a): the conductor may write workspace housekeeping —
    # OS memory files and the daily journal — which are categorically NOT shipped source.
    # Matched STRUCTURALLY (no hard-coded user path): a memory file lives under
    # `.../.claude/projects/<slug>/memory/`, and a journal entry is `journal/YYYY/MM/DD.md`.
    case "$FP" in
      "${HOME:-}"/.claude/projects/*/memory/*) exit 0 ;;        # OS memory dir (anchored under $HOME/.claude)
    esac
    if printf '%s' "$FP" | grep -Eq '(^|/)journal/[0-9]{4}/[0-9]{2}/[0-9]{2}\.md$'; then
      exit 0                                                     # daily journal
    fi
    kiln_deny "The Kiln conductor cannot edit source files inline. Dispatch the Crafter member — it holds Edit/Write." ;;
esac

exit 0
