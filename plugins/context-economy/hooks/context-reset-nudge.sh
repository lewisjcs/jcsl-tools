#!/bin/bash
# Reset-nudge Stop hook: nudges once per session at CONTEXT_NUDGE_TURNS assistant turns.
# Trigger is turn-count (hooks get no context-%); fire-once via a marker keyed by session_id.
#
# Contract: NEVER block Stop, NEVER misfire. Every uncertain state — missing dependency,
# unparseable input, non-numeric config, empty count — exits 0 silently. The hook fires
# only when it can PROVE a numeric turn count has reached a numeric threshold (fail-closed).

# Hard dependencies. Absent → exit silently; a context nudge is never worth blocking Stop.
command -v jq >/dev/null      || exit 0
command -v python3 >/dev/null || exit 0

INPUT=$(cat)

# Never fire during a hook-driven continuation.
[ "$(echo "$INPUT" | jq -r '.stop_hook_active // false')" = "true" ] && exit 0

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty')
THRESHOLD="${CONTEXT_NUDGE_TURNS:-150}"  # backstop default: sits behind the mid-session load+boundary nudge (trial 2026-07-29). Lower via env to nudge sooner.
MIN_USER_TURNS="${CONTEXT_NUDGE_MIN_USER_TURNS:-5}"  # fleet N=185: human_turns≥5 eliminates 100% of agentic FPs
STATE_DIR="$HOME/.claude/hooks/state"
# Marker is namespaced (nudged-ce-) so the prune below can never touch another tool's
# fire-once markers that happen to share this state dir.
MARKER="$STATE_DIR/nudged-ce-$SESSION_ID"

# HOME must be set, or STATE_DIR resolves to a root-anchored /.claude path we can't own.
[ -n "$HOME" ] || exit 0

# Threshold must be a positive integer (>=1); zero is digits but would fire on turn 1.
[[ "$THRESHOLD" =~ ^[0-9]+$ ]] || exit 0
[ "$THRESHOLD" -ge 1 ] || exit 0

# MIN_USER_TURNS must be a non-negative integer; non-numeric config → skip check (fail-open).
[[ "$MIN_USER_TURNS" =~ ^[0-9]+$ ]] || MIN_USER_TURNS=""

# Missing inputs → exit silently (never block the Stop event).
[ -z "$SESSION_ID" ] && exit 0
{ [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; } && exit 0

# Already nudged this session.
[ -f "$MARKER" ] && exit 0

# Count distinct assistant turns and human turns from the transcript JSONL.
# Dedup assistant turns on message.id (resumed/compacted sessions copy prior turns forward);
# for id-less entries, fall back to a per-line key (deterministic distinct-turn count).
# Human turns are counted by line (no dedup needed — they are never replayed forward).
# Claude Code uses type="user" in current transcripts; type="human" supported for compat.
# Output: two whitespace-separated integers: <asst_turns> <human_turns>
COUNTS=$(python3 - "$TRANSCRIPT" <<'PY'
import sys, json
seen=set(); human=0
try:
    with open(sys.argv[1], errors="replace") as f:
        for lineno, line in enumerate(f):
            try: o=json.loads(line)
            except: continue
            t=o.get("type")
            if t=="assistant":
                mid=(o.get("message") or {}).get("id")
                seen.add(mid if mid else f"__noid_{lineno}")
            elif t in ("human", "user"):
                human+=1
except Exception:
    print("0 0"); sys.exit(0)
print(len(seen), human)
PY
)

TURNS="${COUNTS%% *}"
HUMAN_TURNS="${COUNTS##* }"

# Counts must be numbers and assistant turns must have reached the threshold.
# Positive fire-condition (fail-closed): we fire only on a proven count >= threshold.
[[ "$TURNS" =~ ^[0-9]+$ ]] || exit 0
[ "$TURNS" -ge "$THRESHOLD" ] || exit 0

# Human turn floor: if MIN_USER_TURNS is set and parseable, enforce the AND gate.
# If human turn count cannot be validated, skip the check (fail-open — don't suppress a
# valid nudge because the parser returned a bad count).
if [ -n "$MIN_USER_TURNS" ] && [[ "$HUMAN_TURNS" =~ ^[0-9]+$ ]]; then
    [ "$HUMAN_TURNS" -ge "$MIN_USER_TURNS" ] || exit 0
fi

# Fire once: write the marker FIRST and gate the nudge on it. If the state dir is unwritable
# we cannot record that we fired, so staying silent is the only way to honor fire-once — a
# nudge emitted without a marker would re-fire on every subsequent Stop this session.
mkdir -p "$STATE_DIR" 2>/dev/null || exit 0
touch "$MARKER" 2>/dev/null || exit 0
find "$STATE_DIR" -name 'nudged-ce-*' -type f -mtime +7 -delete 2>/dev/null

# Append an auditable fire record (best-effort — logging is observability, NOT a gate:
# a failed log write must never suppress the nudge or block Stop, so it fails open).
printf '%s session=%s turns=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SESSION_ID" "$TURNS" \
  >> "$STATE_DIR/context-nudge.log" 2>/dev/null || true

jq -nc --arg n "$TURNS" --arg h "$HUMAN_TURNS" '{
  hookSpecificOutput: {
    hookEventName: "Stop",
    additionalContext: ("~\($n) assistant turns / \($h) human turns and no mid-session handoff nudge has landed — backstop reminder. Invoke the context-economy skill lever router: handoff+clear at a task boundary, compact only if uncheckpointable. Reminder, not a block.")
  }
}'
exit 0
