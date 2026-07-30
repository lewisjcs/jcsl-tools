#!/usr/bin/env bash
# The Smith — deterministic run-folder harvester. Read-only toward runs; writes retro.json only.
set -euo pipefail

RUN_DIR=""; OUT=""; WORKSPACE=""; LAST=""
while [ $# -gt 0 ]; do
  case "$1" in
    --run-dir)   RUN_DIR="$2";   shift 2 ;;
    --out)       OUT="$2";       shift 2 ;;
    --workspace) WORKSPACE="$2"; shift 2 ;;
    --last)      LAST="$2";      shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -n "$WORKSPACE" ]; then
  if [ -n "$LAST" ]; then
    case "$LAST" in
      *[!0-9]*|0) echo "usage: smith-harvest.sh --workspace DIR --last N (N must be a positive integer)" >&2; exit 2 ;;
    esac
  else
    LAST=10
  fi
  # N most-recently-modified run ledgers. Bash-3.2-safe: no mapfile/readarray/
  # arrays (macOS ships bash 3.2 as /bin/bash, and this script's shebang picks
  # up whatever bash is first on PATH — mapfile is a bash-4+ builtin and would
  # hard-fail with "command not found" there). Capture the newline-separated
  # list into a plain string and stream it through `while read` off a heredoc,
  # the same idiom lib-kiln-hook.sh uses to avoid the bash-3.2 empty-array trap
  # under `set -u` — a heredoc of an empty string is simply zero iterations.
  # `|| true` absorbs the nonzero pipeline exit `ls` produces when the glob
  # matches nothing (unexpanded literal path passed to `ls`), which `pipefail`
  # would otherwise propagate and trip `set -e`.
  ledgers="$(ls -t "$WORKSPACE"/projects/active/*/kiln/progress.md 2>/dev/null | head -n "$LAST" || true)"
  # Batch-cached Langfuse liveness (finding 4): probe the substrate ONCE here rather
  # than paying a per-run health-check round trip (5s timeout each) across the batch.
  # Only meaningful for the default reader hitting a real (possibly-down) substrate;
  # an injected reader (tests) or a missing .env needs no network, so skip the probe.
  if [ -z "${SMITH_LANGFUSE_COST:-}" ]; then
    ENV_FILE="${SMITH_LANGFUSE_ENV:-$HOME/Development/jcslOS/substrate/langfuse-observability/.env}"
    if [ -f "$ENV_FILE" ]; then
      # shellcheck disable=SC1090
      set -a; . "$ENV_FILE"; set +a
      BASE="${CC_LANGFUSE_BASE_URL:-${LANGFUSE_BASE_URL:-http://localhost:3000}}"
      case "$BASE" in
        http://localhost:*|http://127.0.0.1:*)
          curl -sf -o /dev/null --max-time 5 "$BASE/api/public/health" \
            || export SMITH_LANGFUSE_DOWN=1 ;;
        *) export SMITH_LANGFUSE_DOWN=1 ;;
      esac
    fi
  fi
  while IFS= read -r pg; do
    [ -n "$pg" ] || continue
    rd="$(dirname "$pg")"
    # Build filter (sentinel-first, spine-fallback): a real Kiln run has either
    # a run sentinel (.active live / .completed retired — same signal Slice 1.5's
    # curator preserves) OR a plan spine (tasklist.md AND plan.md, which survive
    # COMPLETE). Folders with neither are stray notes (support/audit dumps), not
    # builds — skip them so the accuracy denominator counts only real runs.
    if [ ! -f "$rd/.active" ] && [ ! -f "$rd/.completed" ] \
       && { [ ! -f "$rd/tasklist.md" ] || [ ! -f "$rd/plan.md" ]; }; then
      continue
    fi
    "$0" --run-dir "$rd" --out "$rd/retro.json"
    echo "$rd/retro.json"
  done <<EOF
$ledgers
EOF
  exit 0
fi

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

CCUSAGE="${SMITH_CCUSAGE:-ccusage session --json}"
# session_id_str is a plain string; "" is the sentinel for "no session id"
# (converted to JSON null in the jq body below) since a hand-quoted raw
# --argjson literal would let a STAMP file containing '"'/'\' break the write.
session_id_str=""; cost_usd="null"; cost_note=""
# A live run stamps .active; the Curator retires it to .completed at COMPLETE
# (both hold the session id on their first line). Prefer .active (live/HALTed
# runs), fall back to .completed (cleanly finished runs) so cost joins in every
# terminal state, not just interrupted ones.
STAMP="$RUN_DIR/.active"; [ -f "$STAMP" ] || STAMP="$RUN_DIR/.completed"
if [ ! -f "$STAMP" ]; then
  cost_note="no session stamp (run predates stamping or has neither .active nor .completed)"
else
  sid="$(head -1 "$STAMP" | tr -d '[:space:]')"
  if [ -z "$sid" ]; then
    cost_note="empty session stamp (legacy/unowned run)"
  else
    session_id_str="$sid"
    # Guard ccusage major version (>=20 dedupes on message.id). ver_raw is
    # empty when `ccusage` isn't installed (command not found) and "0" when
    # it IS installed but prints a version this anchor can't parse — both
    # collapse to ver=0 for the `-lt 20` comparison, but the note below must
    # still tell absent apart from old so it doesn't warn about double-counting
    # a binary that was never invoked.
    ver_raw="$(ccusage --version 2>/dev/null | grep -oE '^[0-9]+' || true)"
    ver="${ver_raw:-0}"
    if [ "$ver" -lt 20 ] && [ -z "${SMITH_CCUSAGE:-}" ]; then
      if [ -z "$ver_raw" ]; then
        cost_note="ccusage not found; cost withheld"
      else
        cost_note="ccusage <20 (double-counts); cost withheld"
      fi
    else
      raw="$($CCUSAGE 2>/dev/null || true)"
      c="$(jq -r --arg s "$sid" \
            '(.session // [])[] | select(.period==$s) | .totalCost' <<<"$raw" 2>/dev/null | head -1)"
      if [ -z "$c" ] || [ "$c" = "null" ]; then
        cost_note="no ccusage row for session $sid"
      elif jq -e 'tonumber' >/dev/null 2>&1 <<<"$c"; then
        # $c is confirmed valid JSON that parses to a number — safe for --argjson.
        cost_usd="$c"
      else
        cost_note="malformed cost value from ccusage: $c"
      fi
    fi
  fi
fi

# Per-member cost (Slice 3a): join Langfuse per-subagent trace cost onto this run
# by session id. Additive to the coarse cost_usd above; the ccusage path is untouched.
# Fail-open: any reader failure yields the empty object, never a harvest failure.
# SMITH_LANGFUSE_COST override mirrors SMITH_CCUSAGE (keeps the test offline).
cost_by_member='{"members":[],"conductor_cost_usd":null,"note":"no session id"}'
if [ -n "$session_id_str" ]; then
  READER="${SMITH_LANGFUSE_COST:-bash $(dirname "$0")/smith-langfuse-cost.sh}"
  cbm="$($READER "$session_id_str" 2>/dev/null || true)"
  # Only accept valid JSON whose `members` is actually an array (not merely present —
  # a string/object there would corrupt the documented contract); else fail-open default.
  if [ -n "$cbm" ] && jq -e '(.members|type)=="array"' >/dev/null 2>&1 <<<"$cbm"; then
    cost_by_member="$cbm"
  else
    cost_by_member='{"members":[],"conductor_cost_usd":null,"note":"reader unavailable"}'
  fi
fi

if [ "$first_ts" = "null" ] || [ "$last_ts" = "null" ]; then
  duration_note="duration unavailable (no parseable timestamps in ledger)"
else
  duration_note="calendar span (includes idle/human-gated time), not active-work time"
fi

jq -n --arg run_id "$run_id" --argjson tasks "$tasks_json" \
   --argjson friction "$friction_json" \
   --argjson first_ts "$first_ts" --argjson last_ts "$last_ts" \
   --argjson fix_loops "$fix_loops" \
   --arg session_id_str "$session_id_str" --argjson cost_usd "$cost_usd" \
   --arg cost_note "$cost_note" --arg duration_note "$duration_note" \
   --argjson cost_by_member "$cost_by_member" \
   '{run_id:$run_id, tasks:$tasks, friction:$friction,
     first_ts:$first_ts, last_ts:$last_ts, duration_note:$duration_note, fix_loops:$fix_loops,
     session_id:(if $session_id_str == "" then null else $session_id_str end),
     cost_usd:$cost_usd, cost_note:$cost_note, cost_by_member:$cost_by_member}' > "$OUT"
