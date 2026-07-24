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
   '{run_id:$run_id, tasks:$tasks}' > "$OUT"
