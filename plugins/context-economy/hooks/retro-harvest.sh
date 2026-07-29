#!/usr/bin/env bash
# Context-Economy retro harvester. Read-only toward spine + transcripts; writes
# ce-retro-<session>.json digests only. bash-3.2-safe, fail-open.
set -u
STATE_DIR="$HOME/.claude/hooks/state"; LAST=10
while [ $# -gt 0 ]; do
  case "$1" in
    --last)      LAST="$2"; shift 2 ;;
    --state-dir) STATE_DIR="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
case "$LAST" in *[!0-9]*|0) echo "usage: retro-harvest.sh --last N (positive int)" >&2; exit 2 ;; esac
command -v jq >/dev/null || { echo "jq required" >&2; exit 3; }
command -v python3 >/dev/null || { echo "python3 required" >&2; exit 3; }
ROI="$(cd "$(dirname "$0")" && pwd)/retro-roi.py"
SKILLS="context-economy context-assembly delegating-to-subagents handoff observer"

# N most-recently-modified spine files.
spines="$(ls -t "$STATE_DIR"/ce-events-*.jsonl 2>/dev/null | head -n "$LAST" || true)"
while IFS= read -r sp; do
  [ -n "$sp" ] || continue
  session="$(basename "$sp" | sed 's/^ce-events-//; s/\.jsonl$//')"
  transcript="$(jq -r 'select(.transcript!=null) | .transcript' "$sp" 2>/dev/null | tail -n1)"

  # Firing set: skill events' skill names, stripped of any "plugin:" prefix.
  fired="$(jq -r 'select(.kind=="skill") | .skill' "$sp" 2>/dev/null | sed 's/.*://' | sort -u)"
  fired_json="[]"; never_json="[]"
  for s in $SKILLS; do
    if echo "$fired" | grep -qx "$s"; then fired_json="$(jq -c --arg s "$s" '. + [$s]' <<<"$fired_json")"
    else never_json="$(jq -c --arg s "$s" '. + [$s]' <<<"$never_json")"; fi
  done

  # Boundaries + ROI per boundary.
  boundaries_json="[]"
  while IFS= read -r bline; do
    [ -n "$bline" ] || continue
    bturn="$(jq -r '.turn' <<<"$bline")"; bkind="$(jq -r '.boundary' <<<"$bline")"; bload="$(jq -r '.load' <<<"$bline")"
    roi='{"model":"optimistic","error":"no transcript"}'
    if [ -n "$transcript" ] && [ "$transcript" != "null" ] && [ -f "$transcript" ]; then
      roi="$(python3 "$ROI" "$transcript" "$bturn" 2>/dev/null || echo '{"model":"optimistic","error":"roi failed"}')"
    fi
    boundaries_json="$(jq -c --arg k "$bkind" --argjson t "$bturn" --argjson l "$bload" --argjson roi "$roi" \
      '. + [{kind:$k, turn:$t, load:$l} + $roi]' <<<"$boundaries_json")"
  done <<EOF
$(jq -c 'select(.kind=="boundary")' "$sp" 2>/dev/null)
EOF

  # Cross-clear link: a resumed-from event → read predecessor session from the handoff file.
  cross='null'
  hf="$(jq -r 'select(.kind=="resumed-from") | .handoff' "$sp" 2>/dev/null | tail -n1)"
  if [ -n "$hf" ] && [ "$hf" != "null" ] && [ -f "$hf" ]; then
    pred="$(grep -m1 -oE 'ce-session: *[^ ]+' "$hf" 2>/dev/null | sed 's/ce-session: *//')"
    [ -n "$pred" ] || pred="null"
    cross="$(jq -nc --arg p "$pred" '{linked_predecessor:$p, link_source:"marker", post_resume_rereads:null}')"
  fi

  turns_total="$(jq -rs '[.[].turn] | max // 0' "$sp" 2>/dev/null)"
  first_ts="$(jq -r '.ts // empty' "$sp" 2>/dev/null | head -n1)"
  last_ts="$(jq -r '.ts // empty' "$sp" 2>/dev/null | tail -n1)"

  out="$STATE_DIR/ce-retro-$session.json"
  jq -nc \
    --arg s "$session" --arg f "$first_ts" --arg l "$last_ts" --argjson tt "${turns_total:-0}" \
    --argjson fired "$fired_json" --argjson never "$never_json" \
    --argjson bnd "$boundaries_json" --argjson cross "$cross" \
    '{session:$s, first_ts:$f, last_ts:$l, turns_total:$tt,
      firing:{fired:$fired, never_fired:$never, denominator:5},
      boundaries:$bnd,
      rework:{within_session:{correction_turns:null, repeated_file_reads:null}, cross_clear:$cross},
      lenses_available:(["firing"] + (if ($bnd|length)>0 then ["roi"] else [] end) + (if $cross!=null then ["accuracy"] else [] end)),
      notes:[]}' > "$out" 2>/dev/null || continue
  echo "$out"
done <<EOF
$spines
EOF
exit 0
