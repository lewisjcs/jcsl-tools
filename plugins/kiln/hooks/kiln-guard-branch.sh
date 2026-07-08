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
case "$FP" in */projects/active/*/kiln/*) exit 0 ;; "") exit 0 ;; esac

# Branch from an overridable signal: KILN_TEST_BRANCH lets the offline test drive
# both deny (main/master) and allow (work branch) deterministically; in real use the
# env var is unset and the live checkout is read.
BRANCH="${KILN_TEST_BRANCH:-$(git symbolic-ref --short HEAD 2>/dev/null || echo "")}"
if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
  kiln_deny "Refusing to modify source on '$BRANCH'. Create a work branch first: git checkout -b kiln/<key>."
fi
exit 0
