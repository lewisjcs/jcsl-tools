#!/bin/bash
# PostToolUse telemetry recorder: on a Skill/TodoWrite/Bash tool call, append a
# skill-firing or task-boundary event (todo/commit/pr) to the session event log,
# with a distinct-turn count and token-load proxy. Fail-open in every branch —
# telemetry must never block the harness.
command -v jq >/dev/null      || exit 0
command -v python3 >/dev/null || exit 0

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
SKILL=$(echo "$INPUT" | jq -r '.tool_input.skill // "unknown"' 2>/dev/null)
[ -n "$HOME" ] || exit 0
[ -n "$SESSION_ID" ] || exit 0

STATE_DIR="$HOME/.claude/hooks/state"

# Decide what event (if any) this tool call represents.
KIND=""; FIELD=""; VAL=""
case "$TOOL" in
  Skill)
    KIND="skill"; FIELD="skill"; VAL="$SKILL" ;;
  TodoWrite)
    # Claude Code resends the FULL todo list every call, so "any item completed" is a
    # level, not an edge — it would fire a boundary on every call for the rest of the
    # session once the first item completes. Track the completed COUNT's high-water
    # mark per session and only fire when it grows (a genuinely new completion).
    COMPLETED_N=$(echo "$INPUT" | jq '[.tool_input.todos[]? | select(.status=="completed")] | length' 2>/dev/null)
    [[ "$COMPLETED_N" =~ ^[0-9]+$ ]] || COMPLETED_N=0
    TODO_MARK="$STATE_DIR/todo-completed-n-$SESSION_ID"
    PREV_N=$(cat "$TODO_MARK" 2>/dev/null); [[ "$PREV_N" =~ ^[0-9]+$ ]] || PREV_N=0
    if [ "$COMPLETED_N" -gt "$PREV_N" ]; then
      mkdir -p "$STATE_DIR" 2>/dev/null && echo "$COMPLETED_N" > "$TODO_MARK" 2>/dev/null
      KIND="boundary"; FIELD="boundary"; VAL="todo"
    fi ;;
  Bash)
    CMD=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
    # Anchor to command position (start-of-string or after &&/;/|/||), not any substring
    # match, so a mention like `git log --grep="git commit"` doesn't false-fire.
    if echo "$CMD" | grep -Eq '(^|&&|\;|\|\||\|)[[:space:]]*(gh[[:space:]]+pr[[:space:]]+create|create_pull_request)\b'; then KIND="boundary"; FIELD="boundary"; VAL="pr"
    elif echo "$CMD" | grep -Eq '(^|&&|\;|\|\||\|)[[:space:]]*git[[:space:]]+commit\b'; then KIND="boundary"; FIELD="boundary"; VAL="commit"
    fi ;;
  Read)
    FPATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null)
    # Only a handoff file signals a resume. Match basename handoff-*.md.
    case "$(basename "$FPATH")" in
      handoff-*.md)
        RESUMED_MARK="$STATE_DIR/resumed-from-$SESSION_ID"
        if [ ! -f "$RESUMED_MARK" ]; then
          mkdir -p "$STATE_DIR" 2>/dev/null && : > "$RESUMED_MARK" 2>/dev/null
          KIND="resumed-from"; FIELD="handoff"; VAL="$FPATH"
        fi ;;
    esac ;;
esac
[ -n "$KIND" ] || exit 0
LOG="$STATE_DIR/ce-events-$SESSION_ID.jsonl"

# turn count + token-load proxy from the transcript (dedup asst usage by message.id).
METRICS=$(python3 - "$TRANSCRIPT" <<'PY'
import sys, json, os
path = sys.argv[1] if len(sys.argv) > 1 else ""
seen=set(); turns=0; last_load=0
if path and os.path.isfile(path):
    try:
        with open(path, errors="replace") as f:
            for lineno, line in enumerate(f):
                try: o=json.loads(line)
                except: continue
                if o.get("type")!="assistant": continue
                msg=o.get("message") or {}
                mid=msg.get("id")
                key=mid if mid else f"__noid_{lineno}"
                if key in seen: continue
                seen.add(key); turns+=1
                u=msg.get("usage") or {}
                load=(u.get("input_tokens",0) or 0)+(u.get("cache_read_input_tokens",0) or 0)+(u.get("cache_creation_input_tokens",0) or 0)
                if load: last_load=load
    except Exception:
        pass
print(turns, last_load)
PY
)
TURN="${METRICS%% *}"
LOAD="${METRICS##* }"
[[ "$TURN" =~ ^[0-9]+$ ]] || TURN=0
[[ "$LOAD" =~ ^[0-9]+$ ]] || LOAD=0

mkdir -p "$STATE_DIR" 2>/dev/null || exit 0
find "$STATE_DIR" -name 'ce-events-*.jsonl' -type f -mtime +30 -delete 2>/dev/null

{ jq -nc --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg s "$SESSION_ID" \
         --arg kind "$KIND" --arg field "$FIELD" --arg val "$VAL" \
         --argjson turn "$TURN" --argjson load "$LOAD" \
    '{ts:$ts, session:$s, kind:$kind} + {($field):$val} + {turn:$turn, load:$load}' \
    >> "$LOG"; } 2>/dev/null || true
exit 0
