#!/bin/bash
# Offline unit tests for Kiln guard hooks. No Claude session needed.
# Feeds synthetic PreToolUse stdin JSON to each guard and asserts deny/allow.
set -uo pipefail
HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
FAILS=0

# A guard "denies" if its stdout contains permissionDecision":"deny".
# KILN_TEST_BRANCH (if set in the caller's env) is exported through to the guard
# subprocess so branch-dependent guards can be driven deterministically.
assert_deny() { # $1=label $2=script $3=stdin_json
  local out; out=$(printf '%s' "$3" | KILN_TEST_BRANCH="${KILN_TEST_BRANCH:-}" bash "$HOOKS_DIR/$2")
  if echo "$out" | grep -q '"permissionDecision":"deny"'; then
    echo "ok   - $1"
  else echo "FAIL - $1 (expected deny, got: ${out:-<empty/allow>})"; FAILS=$((FAILS+1)); fi
}
assert_allow() { # $1=label $2=script $3=stdin_json
  local out; out=$(printf '%s' "$3" | KILN_TEST_BRANCH="${KILN_TEST_BRANCH:-}" bash "$HOOKS_DIR/$2")
  if echo "$out" | grep -q '"permissionDecision":"deny"'; then
    echo "FAIL - $1 (expected allow, got deny)"; FAILS=$((FAILS+1));
  else echo "ok   - $1"; fi
}

# Fixtures use a throwaway run dir so the sentinel check has something real to find.
RUN_DIR="$(git rev-parse --show-toplevel)/projects/active/TEST-0/kiln"
mkdir -p "$RUN_DIR"; : > "$RUN_DIR/.active"
SRC="$(git rev-parse --show-toplevel)/plugins/kiln/skills/fire/SKILL.md"

# --- conductor guard ---
assert_deny  "conductor: main-thread Edit to source while active" kiln-guard-conductor.sh \
  "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$SRC\"}}"
assert_allow "conductor: subagent Edit to source (has agent_id)" kiln-guard-conductor.sh \
  "{\"agent_id\":\"a1\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$SRC\"}}"
assert_allow "conductor: main-thread Write to run folder" kiln-guard-conductor.sh \
  "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$RUN_DIR/progress.md\"}}"
assert_deny  "conductor: main-thread Compounds mutation while active" kiln-guard-conductor.sh \
  "{\"tool_name\":\"mcp__compounds-dev__generate_tasks\",\"tool_input\":{}}"
assert_allow "conductor: main-thread Compounds READ while active" kiln-guard-conductor.sh \
  "{\"tool_name\":\"mcp__compounds-dev__get_task\",\"tool_input\":{}}"

# --- no active run → everything allowed ---
rm -f "$RUN_DIR/.active"
assert_allow "conductor: main-thread Edit to source when NO active run" kiln-guard-conductor.sh \
  "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$SRC\"}}"

rmdir "$RUN_DIR" 2>/dev/null; rmdir "$(dirname "$RUN_DIR")" 2>/dev/null
echo "---"; [ "$FAILS" -eq 0 ] && echo "ALL PASS" || { echo "$FAILS FAILED"; exit 1; }
