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
# The memory allow-path anchors on $HOME/.claude; point HOME at the sandbox so the
# anchored match is exercised here (git init/symbolic-ref below need no HOME identity).
export HOME="$WORKSPACE"
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
# Ticket-root docs live one level ABOVE kiln/ (projects/active/<run-id>/): spec/plan/grounding
# docs per the OS project-doc layout. These are conductor working space, not shipped source,
# so they are allowed. (Regression guard for the parent-folder deny that forced `cat >>` bash
# workarounds: grounding.md and .handoffs/ writes were denied because the exemption was kiln/-only.)
assert_allow "conductor: Write to ticket-root doc (parent of kiln/)" kiln-guard-conductor.sh \
  "{$CWD\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$WORKSPACE/projects/active/TEST-0/grounding.md\"}}"
assert_allow "conductor: Write to ticket-root .handoffs/ (parent of kiln/)" kiln-guard-conductor.sh \
  "{$CWD\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$WORKSPACE/projects/active/TEST-0/.handoffs/handoff-2026-07-10.md\"}}"
# Any workspace project folder is conductor working space — INCLUDING another run's folder.
# The exemption is the whole <workspace>/projects/ tree (user direction: "write to those project
# folders in general, just not source repos"), NOT per-run scoping. This deliberately relaxes the
# prior cross-run isolation (project docs only); source under <workspace>/repos/ stays denied below.
assert_allow "conductor: Write to a DIFFERENT run's project folder (projects/ tree is exempt)" kiln-guard-conductor.sh \
  "{$CWD\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$WORKSPACE/projects/active/OTHER-9/kiln/plan.md\"}}"
assert_deny  "conductor: main-thread Compounds mutation while active" kiln-guard-conductor.sh \
  "{$CWD\"tool_name\":\"mcp__compounds-dev__generate_tasks\",\"tool_input\":{}}"
assert_allow "conductor: main-thread Compounds READ while active" kiln-guard-conductor.sh \
  "{$CWD\"tool_name\":\"mcp__compounds-dev__get_task\",\"tool_input\":{}}"

# Scratch paths outside <workspace>/repos/ are conductor working space — must ALLOW.
assert_allow "conductor: Write to /tmp scratch while active" kiln-guard-conductor.sh \
  "{$CWD\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"/tmp/ais-204-pr-body.md\"}}"
assert_allow "conductor: Write to \$TMPDIR-style scratch while active" kiln-guard-conductor.sh \
  "{$CWD\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$WORKSPACE/scratch/notes.md\"}}"

# --- housekeeping allow-path (spec §6a): memory dir + journal are conductor housekeeping, not source ---
# Memory dir mirrors the OS layout: <something>/.claude/projects/<slug>/memory/<file>.
MEMDIR="$WORKSPACE/.claude/projects/-some-workspace-slug/memory"
mkdir -p "$MEMDIR"
assert_allow "conductor: main-thread Write to OS memory dir while active" kiln-guard-conductor.sh \
  "{$CWD\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$MEMDIR/feedback_new_thing.md\"}}"
# Journal path shape: journal/YYYY/MM/DD.md under the workspace.
JOURNAL="$WORKSPACE/journal/2026/07/09.md"
mkdir -p "$(dirname "$JOURNAL")"
assert_allow "conductor: main-thread Write to journal/YYYY/MM/DD.md while active" kiln-guard-conductor.sh \
  "{$CWD\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$JOURNAL\"}}"
# Regression: repo source is STILL denied (proves the allowlist did not loosen source protection).
assert_deny  "conductor: repo source STILL denied after housekeeping allow added" kiln-guard-conductor.sh \
  "{$CWD\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$SRC\"}}"
# Path-confusion: a memory-SHAPED path nested INSIDE repo source (contains .claude/projects/<slug>/memory/
# but is NOT under $HOME/.claude) must still DENY — proves the anchor, not just the segment.
assert_deny  "conductor: memory-shaped decoy nested in repo source denied (path-confusion guard)" kiln-guard-conductor.sh \
  "{$CWD\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$WORKSPACE/repos/jcsl-tools/.claude/projects/some-slug/memory/evil.md\"}}"

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

# --- session-scoped run ownership (concurrent runs, one window each) ---
# The sentinel carries its owning session_id (first line; empty = legacy/unowned). The
# resolver binds a call to the run OWNED by the call's payload .session_id. This isolates
# concurrent windows and stops a non-conducting session from binding to a foreign parked run.
# Verified: payload .session_id == $CLAUDE_CODE_SESSION_ID for main-thread calls.
SID_A="11111111-aaaa-4aaa-8aaa-111111111111"   # session A (owns RUN_DIR)
SID_B="22222222-bbbb-4bbb-8bbb-222222222222"   # session B (a different window)
RUN_A="$RUN_DIR"                                # projects/active/TEST-0/kiln
RUN_B="$WORKSPACE/projects/active/TEST-B/kiln"; mkdir -p "$RUN_B"
SID() { printf '"session_id":"%s",' "$1"; }     # payload session_id snippet

# Two concurrent owned runs: A stamped to session A, B stamped to session B.
printf '%s\n' "$SID_A" > "$RUN_A/.active"
printf '%s\n' "$SID_B" > "$RUN_B/.active"

# Owner match: session A editing A's source is denied (bound to A's run).
assert_deny "ownership: session A main-thread source Edit denied (owns RUN_A)" kiln-guard-conductor.sh \
  "{$CWD$(SID "$SID_A")\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$SRC\"}}"
# Owner match: session A writing INTO A's run folder is allowed.
assert_allow "ownership: session A write into RUN_A allowed" kiln-guard-conductor.sh \
  "{$CWD$(SID "$SID_A")\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$RUN_A/progress.md\"}}"
# Session A writing into B's run folder is ALLOWED: the exemption covers the whole workspace
# projects/ tree, not the owning run. Ownership still governs SOURCE edits (below) — the write
# exemption is about "is this workspace project space vs shipped source", not "whose run is it".
assert_allow "ownership: session A write into RUN_B (still under projects/ tree)" kiln-guard-conductor.sh \
  "{$CWD$(SID "$SID_A")\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$RUN_B/progress.md\"}}"
# NON-CONDUCTING session: session C owns NO run. Its source edit must be ALLOWED (fail-open) even
# though A and B sentinels are live. Old mtime resolver bound C to the newest foreign run → false-deny
# (the exact friction that blocked unrelated main-thread work this session).
SID_C="33333333-cccc-4ccc-8ccc-333333333333"
assert_allow "ownership: non-conducting session C source Edit allowed (owns no run)" kiln-guard-conductor.sh \
  "{$CWD$(SID "$SID_C")\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$SRC\"}}"
# Subagent of ANY session is still exempt (agent_id present short-circuits before ownership).
assert_allow "ownership: subagent (agent_id) exempt regardless of session" kiln-guard-conductor.sh \
  "{$CWD$(SID "$SID_B")\"agent_id\":\"x1\",\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$SRC\"}}"
rm -f "$RUN_B/.active"

# BACKWARD-COMPAT: a single legacy (empty-owner) sentinel with a payload that has NO session_id
# must still resolve and deny — preserves the resume path and pre-ownership sentinels.
: > "$RUN_A/.active"   # empty = legacy/unowned
assert_deny "ownership: legacy empty sentinel + no payload session_id still denies" kiln-guard-conductor.sh \
  "{$CWD\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$SRC\"}}"
# A legacy empty sentinel is claimable by any single session (resume re-stamps it) — a session with
# an id and one unowned run present still binds (so /clear-resume, which mints a new id, isn't orphaned).
assert_deny "ownership: session with id binds to a lone unowned run (resume path)" kiln-guard-conductor.sh \
  "{$CWD$(SID "$SID_A")\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$SRC\"}}"
rm -f "$RUN_A/.active"
rmdir "$RUN_B" 2>/dev/null

echo "---"; [ "$FAILS" -eq 0 ] && echo "ALL PASS" || { echo "$FAILS FAILED"; exit 1; }
