#!/usr/bin/env bash
# The Smith — deterministic run-folder harvester. Read-only toward runs; writes retro.json only.
set -euo pipefail

RUN_DIR=""; OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --run-dir) RUN_DIR="$2"; shift 2 ;;
    --out)     OUT="$2";     shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -n "$RUN_DIR" ] && [ -n "$OUT" ] || { echo "usage: smith-harvest.sh --run-dir DIR --out FILE" >&2; exit 2; }
[ -d "$RUN_DIR" ] || { echo "no such run dir: $RUN_DIR" >&2; exit 2; }

run_id="$(basename "$(dirname "$RUN_DIR")")"

PROG="$RUN_DIR/progress.md"
friction_json="[]"; first_ts="null"; last_ts="null"; fix_loops=0
if [ -f "$PROG" ]; then
  # Friction lines (case-insensitive keyword match), preserved verbatim.
  while IFS= read -r line; do
    friction_json="$(jq --arg l "$line" '. + [$l]' <<<"$friction_json")"
  done < <(grep -iE 'DEVIATION|GAP|fix loop|escalate|reverted|user caught|HARD STOP' "$PROG" || true)
  # Timestamps: min/max of ISO stamps anywhere in the ledger. Kiln mixes
  # minute-only (...T14:48Z) and full-second (...T14:48:45Z) precision on
  # the same run, so a plain lexicographic sort on the raw strings mis-orders
  # same-minute pairs (':' sorts before 'Z'). Sort on a seconds-padded key,
  # but emit the ORIGINAL string verbatim.
  ts_pairs="$(grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]+Z' "$PROG" | awk '{
    orig=$0; key=$0
    if (key !~ /T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$/) { sub(/Z$/, ":00Z", key) }
    print key "\t" orig
  }' | sort || true)"
  if [ -n "$ts_pairs" ]; then
    first_ts="\"$(printf '%s\n' "$ts_pairs" | head -1 | cut -f2)\""
    last_ts="\"$(printf '%s\n' "$ts_pairs" | tail -1 | cut -f2)\""
  fi
  fix_loops="$(grep -icE 'fix loop|REDO' "$PROG" || true)"
fi

# Parse a single verdict file into a task object. Field grammar is the fixed
# Inspector output (spec:/quality:/criteria_met:/criteria_total:/critical_findings:).
parse_verdict() { # $1 = verdict file, $2 = task number
  local f="$1" n="$2" spec quality cmet ctot crit
  spec="$(grep -m1 '^spec:' "$f" | sed 's/^spec:[[:space:]]*//')"
  quality="$(grep -m1 '^quality:' "$f" | sed 's/^quality:[[:space:]]*//')"
  cmet="$(grep -m1 '^criteria_met:' "$f" | sed 's/^criteria_met:[[:space:]]*//')"
  ctot="$(grep -m1 '^criteria_total:' "$f" | sed 's/^criteria_total:[[:space:]]*//')"
  crit="$(grep -m1 '^critical_findings:' "$f" | sed 's/^critical_findings:[[:space:]]*//')"
  # ✅ → pass; anything else present → fail; absent → unknown
  case "$spec" in *✅*) spec="pass" ;; "" ) spec="unknown" ;; *) spec="fail" ;; esac
  [ -n "$quality" ] || quality="unknown"
  jq -n --argjson n "$n" \
        --arg spec "$spec" --arg quality "$quality" \
        --arg cmet "${cmet:-0}" --arg ctot "${ctot:-0}" --arg crit "${crit:-0}" \
        '{n:$n, spec:$spec, quality:$quality,
          criteria_met:($cmet|tonumber), criteria_total:($ctot|tonumber),
          critical_findings:($crit|tonumber)}'
}

# Task number extraction covers both verdict filename conventions:
#   legacy:  verdict-3.md               -> 3
#   current: task-3-<slug>-verdict.md   -> 3
verdict_task_number() { # $1 = basename
  local b="$1"
  if [[ "$b" =~ ^verdict-([0-9]+) ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo "$b" | sed -E 's/^task-([0-9]+)-.*/\1/'
  fi
}

tasks_json="[]"
# Two globs, not one combined pattern: `task-*-verdict.md` never matches
# `verdict-*.md` (that pattern requires the basename to START with
# "verdict"), so a file can only land in one of these two loops — no
# double-counting.
for vf in "$RUN_DIR"/verdict-*.md "$RUN_DIR"/task-*-verdict.md; do
  [ -e "$vf" ] || continue
  n="$(verdict_task_number "$(basename "$vf")")"
  obj="$(parse_verdict "$vf" "$n")"
  tasks_json="$(jq --argjson o "$obj" '. + [$o]' <<<"$tasks_json")"
done

jq -n --arg run_id "$run_id" --argjson tasks "$tasks_json" \
   --argjson friction "$friction_json" \
   --argjson first_ts "$first_ts" --argjson last_ts "$last_ts" \
   --argjson fix_loops "$fix_loops" \
   '{run_id:$run_id, tasks:$tasks, friction:$friction,
     first_ts:$first_ts, last_ts:$last_ts, fix_loops:$fix_loops}' > "$OUT"
