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

# Fixtures use a throwaway NON-GIT workspace sandbox — NOT the repo — because the
# guards must anchor on the OS workspace (where CC launched), not a git repo.
# Anchoring the fixtures on `git rev-parse` (as this test previously did) and running
# from inside the repo MASKED the production bug: the guards fail-open when invoked
# from the non-git workspace root. $WORKSPACE mirrors that layout; the guard is handed
# the workspace via the payload `.cwd` field (its real anchor) spliced into every
# fixture, and by running with cwd=$WORKSPACE. cd once so $PWD fallback also resolves.
WORKSPACE="$(mktemp -d)"
trap 'rm -rf "$WORKSPACE"' EXIT
cd "$WORKSPACE" || { echo "FAIL - could not cd to sandbox workspace"; exit 1; }
RUN_DIR="$WORKSPACE/projects/active/TEST-0/kiln"
mkdir -p "$RUN_DIR"; : > "$RUN_DIR/.active"
# "Source" lives in a nested (non-git) repo path under the workspace, outside any run folder.
SRC="$WORKSPACE/repos/jcsl-tools/plugins/kiln/skills/fire/SKILL.md"
mkdir -p "$(dirname "$SRC")"; : > "$SRC"
# The `.cwd` snippet spliced into the front of every fixture payload so the guard's
# primary anchor (payload .cwd = session cwd = the OS workspace) resolves the run folder.
CWD="\"cwd\":\"$WORKSPACE\","

# --- conductor guard ---
assert_deny  "conductor: main-thread Edit to source while active" kiln-guard-conductor.sh \
  "{$CWD\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$SRC\"}}"
assert_deny  "conductor: main-thread MultiEdit to source while active" kiln-guard-conductor.sh \
  "{$CWD\"tool_name\":\"MultiEdit\",\"tool_input\":{\"file_path\":\"$SRC\"}}"
assert_deny  "conductor: main-thread NotebookEdit to source while active" kiln-guard-conductor.sh \
  "{$CWD\"tool_name\":\"NotebookEdit\",\"tool_input\":{\"notebook_path\":\"$SRC\"}}"
assert_allow "conductor: subagent Edit to source (has agent_id)" kiln-guard-conductor.sh \
  "{$CWD\"agent_id\":\"a1\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$SRC\"}}"
assert_allow "conductor: main-thread Write to run folder" kiln-guard-conductor.sh \
  "{$CWD\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$RUN_DIR/progress.md\"}}"
assert_allow "conductor: main-thread MultiEdit to run folder" kiln-guard-conductor.sh \
  "{$CWD\"tool_name\":\"MultiEdit\",\"tool_input\":{\"file_path\":\"$RUN_DIR/plan.md\"}}"
# N-2: a write shaped like a run folder but NOT the active run must still deny.
assert_deny  "conductor: Write to a DIFFERENT run's kiln folder while active" kiln-guard-conductor.sh \
  "{$CWD\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$WORKSPACE/projects/active/OTHER-9/kiln/plan.md\"}}"
assert_deny  "conductor: main-thread Compounds mutation while active" kiln-guard-conductor.sh \
  "{$CWD\"tool_name\":\"mcp__compounds-dev__generate_tasks\",\"tool_input\":{}}"
assert_allow "conductor: main-thread Compounds READ while active" kiln-guard-conductor.sh \
  "{$CWD\"tool_name\":\"mcp__compounds-dev__get_task\",\"tool_input\":{}}"

# N-3 regression (workspace anchor): the payload `.cwd` must be the anchor even when the
# hook process cwd is somewhere else entirely. Run the guard from `/` (no projects/active/
# there) with the workspace ONLY in the payload — a correct guard still resolves the run
# folder and denies. Against the old git-rev-parse lib this ALLOWS (fail-open) → the bug.
DIVERGE_OUT=$( (cd / && printf '%s' \
  "{$CWD\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$SRC\"}}" \
  | bash "$HOOKS_DIR/kiln-guard-conductor.sh") )
if echo "$DIVERGE_OUT" | grep -q '"permissionDecision":"deny"'; then
  echo "ok   - conductor: denies via payload .cwd even when process cwd diverges (run from /)"
else
  echo "FAIL - conductor: payload .cwd anchor (got: ${DIVERGE_OUT:-<empty/allow>})"; FAILS=$((FAILS+1))
fi

# --- no active run → everything allowed ---
rm -f "$RUN_DIR/.active"
assert_allow "conductor: main-thread Edit to source when NO active run" kiln-guard-conductor.sh \
  "{$CWD\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$SRC\"}}"

# --- branch guard --- (re-create the active sentinel for these cases)
: > "$RUN_DIR/.active"
# Deny path: simulate being on main. Allow path: simulate a work branch. Both run every invocation.
KILN_TEST_BRANCH=main assert_deny "branch: Edit to source while on main (simulated)" kiln-guard-branch.sh \
  "{$CWD\"agent_id\":\"a1\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$SRC\"}}"
KILN_TEST_BRANCH=master assert_deny "branch: Edit to source while on master (simulated)" kiln-guard-branch.sh \
  "{$CWD\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$SRC\"}}"
KILN_TEST_BRANCH=main assert_deny "branch: MultiEdit to source while on main (simulated)" kiln-guard-branch.sh \
  "{$CWD\"tool_name\":\"MultiEdit\",\"tool_input\":{\"file_path\":\"$SRC\"}}"
KILN_TEST_BRANCH=kiln/TEST-0 assert_allow "branch: Edit to source while on work branch (simulated)" kiln-guard-branch.sh \
  "{$CWD\"agent_id\":\"a1\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$SRC\"}}"
KILN_TEST_BRANCH=main assert_allow "branch: Write to run folder allowed even on main" kiln-guard-branch.sh \
  "{$CWD\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$RUN_DIR/progress.md\"}}"

# N-3 regression (branch resolved from the EDITED FILE's repo, not hook cwd): the previous
# tests all use KILN_TEST_BRANCH; none exercised real `git -C <file dir>` resolution. Create
# a REAL git repo inside the workspace so the un-overridden path is proven. Against the old
# bare-`git symbolic-ref` lib (read from the non-git workspace cwd) this ALLOWS → the bug.
GITREPO="$WORKSPACE/repos/realrepo"
mkdir -p "$GITREPO/src"
git -C "$GITREPO" init -q
git -C "$GITREPO" symbolic-ref HEAD refs/heads/main   # deterministically "on main", no commit needed
GITSRC="$GITREPO/src/thing.md"; : > "$GITSRC"
assert_deny "branch: real git repo on main denies (git -C <file dir>, no override)" kiln-guard-branch.sh \
  "{$CWD\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$GITSRC\"}}"
git -C "$GITREPO" symbolic-ref HEAD refs/heads/kiln/TEST-0   # move to a work branch
assert_allow "branch: real git repo on work branch allows (git -C <file dir>, no override)" kiln-guard-branch.sh \
  "{$CWD\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$GITSRC\"}}"
rm -f "$RUN_DIR/.active"

# --- spine guard ---
: > "$RUN_DIR/.active"; rm -f "$RUN_DIR/.spine"
assert_deny "spine: Agent dispatch before spine exists" kiln-guard-spine.sh \
  "{$CWD\"tool_name\":\"Agent\",\"tool_input\":{\"subagent_type\":\"kiln:crafter\"}}"
: > "$RUN_DIR/.spine"
assert_allow "spine: Agent dispatch after spine exists" kiln-guard-spine.sh \
  "{$CWD\"tool_name\":\"Agent\",\"tool_input\":{\"subagent_type\":\"kiln:crafter\"}}"
rm -f "$RUN_DIR/.active" "$RUN_DIR/.spine"

echo "---"; [ "$FAILS" -eq 0 ] && echo "ALL PASS" || { echo "$FAILS FAILED"; exit 1; }
