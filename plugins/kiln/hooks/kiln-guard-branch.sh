#!/bin/bash
# PreToolUse guard: no source mutation on main/master while a Kiln run is active.
# Applies to both conductor and members. Fail-open on any uncertainty.
set -uo pipefail
LIB="$(cd "$(dirname "$0")" && pwd)/lib-kiln-hook.sh"
# shellcheck source=/dev/null
. "$LIB" 2>/dev/null || exit 0

kiln_read_input
RUN_DIR=$(kiln_active_run_dir)
[ -z "$RUN_DIR" ] && exit 0

TOOL=$(kiln_field '.tool_name')
case "$TOOL" in Edit|Write|MultiEdit|NotebookEdit) : ;; *) exit 0 ;; esac

FP=$(kiln_field '.tool_input.file_path'); [ -z "$FP" ] && FP=$(kiln_field '.tool_input.notebook_path')
[ -z "$FP" ] && exit 0                                   # no path resolvable — fail-open
FP=$(kiln_normalize_path "$FP")
# Two trees are branch-protected: shipped source under <workspace>/repos/, and the installed
# plugin source under ~/.claude/plugins/ (a real git repo, normally on main — a member/conductor
# must never patch the live plugin copy on main; do it on a work branch in .worktrees/). Everything
# else — run folder, ticket-root docs, .handoffs/, scratch — is working space, allowed on any branch.
# Mirrors kiln-guard-conductor.sh's protected-tree model (they had drifted).
WS_ROOT="${RUN_DIR%%/projects/active/*}"
case "$FP" in
  "$WS_ROOT"/repos/*) : ;;                                # shipped source → fall through to the branch check
  "$HOME"/.claude/plugins/*) : ;;                         # installed plugin source → fall through to the branch check
  *) exit 0 ;;                                            # any non-source path → allow
esac

# Branch from an overridable signal: KILN_TEST_BRANCH lets the offline test drive
# both deny (main/master) and allow (work branch) deterministically; in real use the
# env var is unset and the live checkout is read. Resolve the branch from the EDITED
# FILE's repo (`git -C <file's dir>`), not the hook cwd: this OS launches from a
# non-git workspace and the edited source lives in a nested repo, so a bare
# `git symbolic-ref` from cwd would read the wrong repo (or none) and never fire.
BRANCH="${KILN_TEST_BRANCH:-$(git -C "$(dirname "$FP")" symbolic-ref --short HEAD 2>/dev/null || echo "")}"
if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
  kiln_deny "Refusing to modify source on '$BRANCH'. Create a work branch first per contentful-git-create-branch: git checkout -b <type>/<TICKET-KEY>-<short-description> (e.g. docs/EXT-7366-...)."
fi
exit 0
