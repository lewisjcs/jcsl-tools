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

rework_for() {  # $1=transcript path → prints "CORRECTIONS REPEATED"
  python3 - "$1" <<'PY'
import sys, json, os
p = sys.argv[1] if len(sys.argv)>1 else ""
corr=0; reads={}
CUES=("no","wrong","undo","re-read","reread","that's not","thats not","not right","revert")
if p and os.path.isfile(p):
    prev_assistant=False
    with open(p, errors="replace") as f:
        for line in f:
            try: o=json.loads(line)
            except: continue
            t=o.get("type")
            if t=="user":
                msg=o.get("message") or {}; c=msg.get("content")
                text = c if isinstance(c,str) else " ".join(
                    b.get("text","") for b in c if isinstance(b,dict)) if isinstance(c,list) else ""
                low=text.strip().lower()
                if prev_assistant and len(low)<=40 and any(low.startswith(q) or q in low for q in CUES):
                    corr+=1
                prev_assistant=False
            elif t=="assistant":
                prev_assistant=True
                for b in ((o.get("message") or {}).get("content") or []):
                    if isinstance(b,dict) and b.get("name")=="Read":
                        fp=(b.get("input") or {}).get("file_path")
                        if fp: reads[fp]=reads.get(fp,0)+1
repeated=sum(1 for v in reads.values() if v>1)
print(corr, repeated)
PY
}

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

  # Post-resume re-reads: files Read in both the predecessor transcript and this one.
  # TODO(tuning): scope to pre-first-boundary window
  if [ "$cross" != "null" ]; then
    pred_sp="$STATE_DIR/ce-events-$pred.jsonl"
    pred_tr="$(jq -r 'select(.transcript!=null) | .transcript' "$pred_sp" 2>/dev/null | tail -n1)"
    if [ -n "$pred_tr" ] && [ "$pred_tr" != "null" ] && [ -f "$pred_tr" ] && [ -n "$transcript" ] && [ "$transcript" != "null" ] && [ -f "$transcript" ]; then
      rr="$(python3 - "$pred_tr" "$transcript" <<'PY'
import sys, json, os
def reads_of(p):
    files=set()
    if not (p and os.path.isfile(p)): return files
    with open(p, errors="replace") as f:
        for line in f:
            try: o=json.loads(line)
            except: continue
            if o.get("type")!="assistant": continue
            for b in ((o.get("message") or {}).get("content") or []):
                if isinstance(b,dict) and b.get("name")=="Read":
                    fp=(b.get("input") or {}).get("file_path")
                    if fp: files.add(fp)
    return files
pred=reads_of(sys.argv[1]); cur=reads_of(sys.argv[2])
print(len(pred & cur))
PY
)"
      [[ "$rr" =~ ^[0-9]+$ ]] || rr=0
      cross="$(jq -c --argjson rr "$rr" '.post_resume_rereads=$rr' <<<"$cross")"
    fi
  fi

  # Within-session rework: short user corrections + repeated file reads.
  rw="0 0"
  if [ -n "$transcript" ] && [ "$transcript" != "null" ] && [ -f "$transcript" ]; then rw="$(rework_for "$transcript")"; fi
  corr="${rw%% *}"; rep="${rw##* }"
  [[ "$corr" =~ ^[0-9]+$ ]] || corr=0; [[ "$rep" =~ ^[0-9]+$ ]] || rep=0

  turns_total="$(jq -rs '[.[].turn] | max // 0' "$sp" 2>/dev/null)"
  first_ts="$(jq -r '.ts // empty' "$sp" 2>/dev/null | head -n1)"
  last_ts="$(jq -r '.ts // empty' "$sp" 2>/dev/null | tail -n1)"

  out="$STATE_DIR/ce-retro-$session.json"
  jq -nc \
    --arg s "$session" --arg f "$first_ts" --arg l "$last_ts" --argjson tt "${turns_total:-0}" \
    --argjson fired "$fired_json" --argjson never "$never_json" \
    --argjson bnd "$boundaries_json" --argjson cross "$cross" \
    --argjson corr "$corr" --argjson rep "$rep" \
    '{session:$s, first_ts:$f, last_ts:$l, turns_total:$tt,
      firing:{fired:$fired, never_fired:$never, denominator:5},
      boundaries:$bnd,
      rework:{within_session:{correction_turns:$corr, repeated_file_reads:$rep}, cross_clear:$cross},
      lenses_available:(["firing"] + (if ($bnd|length)>0 then ["roi"] else [] end) + (if $cross!=null then ["accuracy"] else [] end)),
      notes:[]}' > "$out" 2>/dev/null || continue
  echo "$out"
done <<EOF
$spines
EOF
exit 0
