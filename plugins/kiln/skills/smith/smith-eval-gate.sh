#!/usr/bin/env bash
# The Smith — deterministic eval-gate core. Never dispatches an agent; operates on
# a captured kiln-routing marker vs a gold expected/*.json fixture. Bash-3.2-safe.
set -uo pipefail

# Parse a ```kiln-routing fenced block into flat `key=value` pairs on stdout.
# Exits 2 (fail-loud) if no fenced block is present.
parse_marker() { # $1 = marker file
  awk '
    /^```kiln-routing/ { inb=1; next }
    inb && /^```/      { inb=0; next }
    inb                { print }
  ' "$1"
}

marker_val() { # $1 = parsed-lines, $2 = key -> value (trimmed), lists kept as-is
  printf '%s\n' "$1" | sed -n "s/^$2:[[:space:]]*//p" | head -1
}
# Normalize a list "[a, b]" or JSON array to sorted space-joined tokens for comparison.
norm_list() { printf '%s' "$1" | tr -d '[]"' | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$' | sort | tr '\n' ' ' | sed 's/[[:space:]]*$//'; }

cmd_diff() { # $1 = marker file, $2 = expected json
  local mf="$1" ef="$2" parsed rc=0
  parsed="$(parse_marker "$mf")"
  if [ -z "$parsed" ]; then echo "FAIL: unparseable marker (no kiln-routing block)" >&2; return 2; fi
  # scalar routing fields
  local f
  for f in lane tier blast_radius scenario_type; do
    local got want
    got="$(marker_val "$parsed" "$f")"
    want="$(jq -r --arg k "$f" '.routing[$k] // "N/A"' "$ef")"
    if [ "$got" != "$want" ]; then echo "FAIL: $f expected=$want got=$got"; rc=1; fi
  done
  # gates: each expected gate key must match the marker's gates_fired membership
  local fired; fired="$(norm_list "$(marker_val "$parsed" gates_fired)")"
  local gk
  for gk in $(jq -r '.gates | keys[]' "$ef"); do
    local wantfired; wantfired="$(jq -r --arg g "$gk" '.gates[$g]' "$ef")"
    local isfired=false
    case " $fired " in *" $gk "*) isfired=true ;; esac
    if [ "$wantfired" = "true" ] && [ "$isfired" = "false" ]; then echo "FAIL: gate $gk expected=fired got=not-fired"; rc=1; fi
    if [ "$wantfired" = "false" ] && [ "$isfired" = "true" ]; then echo "FAIL: gate $gk expected=not-fired got=fired"; rc=1; fi
  done
  # dispatched / skipped members
  local gotd wantd gots wants
  gotd="$(norm_list "$(marker_val "$parsed" agents_dispatched)")"
  wantd="$(norm_list "$(jq -r '.agents_dispatched // [] | @json' "$ef")")"
  [ "$gotd" != "$wantd" ] && { echo "FAIL: agents_dispatched expected=[$wantd] got=[$gotd]"; rc=1; }
  gots="$(norm_list "$(marker_val "$parsed" agents_skipped)")"
  wants="$(norm_list "$(jq -r '.agents_skipped // [] | @json' "$ef")")"
  [ "$gots" != "$wants" ] && { echo "FAIL: agents_skipped expected=[$wants] got=[$gots]"; rc=1; }
  [ "$rc" = 0 ] && echo "PASS"
  return "$rc"
}

cmd_anti_gaming() { # $1 = unified diff file
  local df="$1" bad
  bad="$(grep -E '^\+\+\+ |^--- ' "$df" | grep -oE '(a|b)/plugins/kiln/skills/fire/eval/(expected|scenarios)/[^[:space:]]+' | head -1 || true)"
  if [ -n "$bad" ]; then echo "REJECTED: proposal diff touches a fixture/scenario: $bad" >&2; return 3; fi
  return 0
}

cmd_tally() { # $1 = results file (lines "<scenario> PASS|FAIL"), $2 = thresholds.yaml
  local rf="$1" regressions=0
  # A scenario at pass_rate 1.0 fails the bar on any FAIL. (All bars are 1.0 today;
  # a sub-1.0 bar would need run-count aggregation — out of scope, all thresholds are 1.0.)
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    local sc st; sc="${line%% *}"; st="${line##* }"
    if [ "$st" = "FAIL" ]; then echo "OBSERVATION-ONLY: $sc regressed"; regressions=$((regressions+1)); fi
  done < "$rf"
  if [ "$regressions" = 0 ]; then echo "RECOMMENDED"; return 0; fi
  return 1
}

case "${1:-}" in
  diff)        shift; cmd_diff "$@" ;;
  anti-gaming) shift; cmd_anti_gaming "$@" ;;
  tally)       shift; cmd_tally "$@" ;;
  *) echo "usage: smith-eval-gate.sh {diff <marker> <expected>|anti-gaming <diff>|tally <results> <thresholds>}" >&2; exit 2 ;;
esac
