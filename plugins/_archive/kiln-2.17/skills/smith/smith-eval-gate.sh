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
  [ -r "$df" ] || { echo "anti-gaming: cannot read diff file: $df" >&2; return 2; }
  # Scan diff HEADER lines only (never +/- content lines): ---/+++ (unified, with or
  # without a/ b/ prefix), diff --git (both sides), and rename from/rename to (pure
  # renames carry no ---/+++ lines at all). Anchor on the path SUFFIX
  # eval/(expected|scenarios)/... rather than a hardcoded full prefix, so the check
  # survives --no-prefix diffs and diffs rooted below plugins/kiln/skills/fire/.
  bad="$(grep -E '^(--- |\+\+\+ |diff --git |rename from |rename to )' "$df" \
    | sed -E 's#^(--- |\+\+\+ |diff --git |rename from |rename to )##' \
    | tr ' ' '\n' \
    | sed -E 's#^(a|b)/##' \
    | grep -oE '([^[:space:]]*/)?eval/(expected|scenarios)/[^[:space:]]+' \
    | head -1 || true)"
  if [ -n "$bad" ]; then echo "REJECTED: proposal diff touches a fixture/scenario: $bad" >&2; return 3; fi
  return 0
}

cmd_guard_relax() { # $1 = unified diff file -> exit 5 if an ADDED line authorizes a guard-forbidden action
  local df="$1" bad
  [ -r "$df" ] || { echo "guard-relax: cannot read diff file: $df" >&2; return 2; }
  # Scan ADDED content lines only (^+ but not the +++ header). The guard forbids the
  # main-thread conductor editing shipped source inline / skipping the Crafter; flag prose
  # that authorizes it. A fixed-phrase whitelist is trivially evaded by rephrasing and can
  # split a single authorization across two added lines, so we instead:
  #   1. JOIN all added lines into one stream (a clause may straddle a line break),
  #   2. split that stream into CLAUSES on . ; : boundaries,
  #   3. flag a clause that matches a relaxation CATEGORY (semantic, not one fixed phrase)
  #      AND carries no negation token — so "the conductor may NEVER edit inline" (a
  #      tightening) is not misread as authorization.
  # Bash-3.2/macOS-awk-safe: no \b (unsupported by BWK awk) — normalize punctuation to
  # spaces and match space-padded ` token ` forms instead. Clause-level negation scoping
  # biases toward missing a relaxation over misflagging a tightening; the structural
  # guard-hook pairing (eval-gate.md Step -1) is the backstop against a missed prose match.
  bad="$(grep -E '^\+([^+]|$)' "$df" | sed -E 's/^\+//' | awk '
    { buf = buf " " tolower($0) }
    END {
      n = split(buf, cl, /[.;:]/)
      for (i = 1; i <= n; i++) {
        c = cl[i]
        gsub(/[^a-z0-9]+/, " ", c); c = " " c " "
        # negation guard: a clause that forbids the action is a tightening, not a relaxation
        if (c ~ / (not|never|cannot|cant|dont|doesnt|wont) /) continue
        # relaxation categories (conductor edits shipped source inline / skips the Crafter):
        if (c ~ /(authoriz|permit|allow|may|can|able to|free to|allowed to).*(edit|writ|apply|modif|chang).*(inline|in place|directly|itself|without dispatch|without a crafter|without the crafter|without dispatching)/ ||
            c ~ /(edit|writ|apply|modif|chang).*(inline|in place|directly).*(without|instead of|rather than).*(crafter|dispatch|member)/ ||
            c ~ /(skip|skips|bypass|forgo|forego|avoid|omit|without).*(crafter|craft|dispatch|member|delegat)/ ||
            c ~ /inline fast path/) {
          gsub(/^ +| +$/, "", c); print c; exit
        }
      }
    }' || true)"
  if [ -n "$bad" ]; then echo "RELAXATION: ${bad}" >&2; return 5; fi
  return 0
}

cmd_classify() { # $1 = unified diff file -> space-separated dream-class set (always exit 0)
  local df="$1" classes="" hdrs h
  hdrs="$(grep -E '^(--- |\+\+\+ |diff --git )' "$df" | sed -E 's#^(--- |\+\+\+ |diff --git )##' | tr ' ' '\n' | sed -E 's#^(a|b)/##' | grep -v '^$' | sort -u)"
  # path-based classes: match each header path INDIVIDUALLY (case globs match
  # newlines too, so matching against the whole multi-line $hdrs blob lets a
  # pattern bleed across two unrelated paths on a multi-file diff).
  while IFS= read -r h; do
    [ -n "$h" ] || continue
    # guard hook CODE edit — the guard hooks themselves AND their test harness
    # (test-kiln-guards.sh is the control eval-gate.md names for this class; the bare
    # kiln-guard-*.sh glob does not match it, so name it explicitly).
    case "$h" in *hooks/kiln-guard-*.sh|*hooks/test-kiln-guards.sh) classes="$classes guard-hook-code" ;; esac
    # routing-output: edits a routing-bearing prose file (suffix match — header
    # paths carry the diff's root prefix, e.g. plugins/kiln/skills/fire/gates.md)
    case "$h" in *skills/fire/lanes.md|*skills/fire/gates.md|*skills/fire/scenarios.md|*skills/fire/SKILL.md) classes="$classes routing-output" ;; esac
  done <<EOF
$hdrs
EOF
  # guard-relaxation prose (reuse the Task-1 scan): only an actual relaxation
  # match (exit 5) adds the class. An unreadable file (exit 2) falls through
  # to unsure like any other unmatched input, rather than being misclassified.
  cmd_guard_relax "$df" >/dev/null 2>&1; case $? in 5) classes="$classes guard-relaxation" ;; esac
  # detection/perf prose (speed of a decision, no routing-output token) — heuristic phrase set
  if grep -E '^\+([^+]|$)' "$df" | grep -iqE 'fast-detect|short-circuit|without waiting|reached faster|redundant work|how fast'; then classes="$classes detection-perf"; fi
  classes="$(printf '%s\n' $classes | grep -v '^$' | sort -u | tr '\n' ' ' | sed 's/[[:space:]]*$//')"
  [ -z "$classes" ] && classes="unsure"
  printf '%s\n' "$classes"
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

cmd_canon() { # $1 = marker file -> canonical single line; exit 2 if unparseable
  local mf="$1" parsed
  parsed="$(parse_marker "$mf")"
  if [ -z "$parsed" ]; then echo "FAIL: unparseable marker (no kiln-routing block)" >&2; return 2; fi
  local lane tier blast st gates disp skip halt
  lane="$(marker_val "$parsed" lane)";           tier="$(marker_val "$parsed" tier)"
  blast="$(marker_val "$parsed" blast_radius)";  st="$(marker_val "$parsed" scenario_type)"
  gates="$(norm_list "$(marker_val "$parsed" gates_fired)")"
  disp="$(norm_list "$(marker_val "$parsed" agents_dispatched)")"
  skip="$(norm_list "$(marker_val "$parsed" agents_skipped)")"
  halt="$(marker_val "$parsed" halt_reason)"; [ "$halt" = "null" ] && halt=""
  printf '%s|%s|%s|%s|%s|%s|%s|%s\n' "$lane" "$tier" "$blast" "$st" "$gates" "$disp" "$skip" "$halt"
}

cmd_majority() { # $@ = marker files -> mode canonical line, or UNSTABLE (exit 4)
  local tmp; tmp="$(mktemp)"
  local mf
  for mf in "$@"; do cmd_canon "$mf" >> "$tmp" || { rm -f "$tmp"; return 2; }; done
  # tally identical canonical lines; sort by count desc
  local top topn runner runnern
  top="$(sort "$tmp" | uniq -c | sort -rn | head -1)"
  runner="$(sort "$tmp" | uniq -c | sort -rn | sed -n '2p')"
  topn="$(printf '%s' "$top" | awk '{print $1}')"
  runnern="$(printf '%s' "$runner" | awk '{print $1}')"; runnern="${runnern:-0}"
  rm -f "$tmp"
  if [ "$topn" -le "$runnern" ]; then echo "UNSTABLE"; return 4; fi
  printf '%s\n' "$top" | sed -E 's/^[[:space:]]*[0-9]+[[:space:]]+//'
}

cmd_diff_pair() { # $1 = baseline canon, $2 = proposal canon -> SAME|CHANGED|UNSTABLE-side
  local b p; b="$(cat "$1")"; p="$(cat "$2")"
  if [ "$b" = "UNSTABLE" ]; then echo "UNSTABLE-side: baseline" >&2; return 4; fi
  if [ "$p" = "UNSTABLE" ]; then echo "UNSTABLE-side: proposal" >&2; return 4; fi
  if [ "$b" = "$p" ]; then echo "SAME"; return 0; fi
  # name each differing pipe-field
  local names="lane tier blast_radius scenario_type gates_fired agents_dispatched agents_skipped halt_reason"
  local i=1 out=""
  local IFS='|'; local ba=($b); local pa=($p); unset IFS
  for fld in $names; do
    local bv="${ba[$((i-1))]:-}" pv="${pa[$((i-1))]:-}"
    if [ "$bv" != "$pv" ]; then out="${out:+$out; }${fld}=${bv}→${pv}"; fi
    i=$((i+1))
  done
  echo "CHANGED: $out"; return 1
}

cmd_cache_key() { # $1=scenario $2=K $3.. = prose files
  local scenario="$1" k="$2"; shift 2
  # Fail loud with zero prose files rather than block on stdin (cat with no args reads
  # stdin) or silently hash the empty string — the cache key must reflect real prose.
  if [ "$#" -eq 0 ]; then echo "cache-key: no prose files given (need >=1)" >&2; return 2; fi
  local h; h="$(cat "$@" | shasum -a 256 | cut -c1-12)"
  printf '%s.%s.%s\n' "$scenario" "$k" "$h"
}
cmd_cache_path() { printf '%s/%s.canon\n' "$1" "$2"; }

cmd_reproduces() { # $1 = predicted diff file, $2 = repo dir
  local df="$1" rd="$2"
  [ -r "$df" ] || { echo "reproduces: cannot read diff file: $df" >&2; return 2; }
  git -C "$rd" rev-parse --git-dir >/dev/null 2>&1 || { echo "reproduces: not a git repo: $rd" >&2; return 2; }
  # Zero-hunk guard FIRST: a predicted diff with no `@@` hunk is a complete no-op —
  # the change is already fully present. `git apply` on an empty patch exits 128
  # (fatal), not 0, so this case must be caught before the git probe and mapped to
  # already-applied (return 1), the purest staleness.
  if ! grep -q '^@@ ' "$df"; then
    echo "reproduces: empty/zero-hunk diff — change already present (already-applied)" >&2
    return 1
  fi
  # already-applied: the edit reverse-applies cleanly against current source.
  if git -C "$rd" apply --reverse --check "$df" >/dev/null 2>&1; then
    return 1
  fi
  # still-open: the edit forward-applies cleanly (deficiency present, fix not yet in tree).
  if git -C "$rd" apply --check "$df" >/dev/null 2>&1; then
    return 0
  fi
  # Neither direction applies. Disambiguate git's exit code: 1 = patch does not apply
  # (genuine context drift → write + flag, return 6); 128 = fatal/malformed input
  # (fail-loud, return 2). Re-run forward --check to capture the distinguishing code.
  git -C "$rd" apply --check "$df" >/dev/null 2>&1
  case "$?" in
    1) echo "reproduces: context drift — cannot confirm freshness (freshness-unverified)" >&2; return 6 ;;
    *) echo "reproduces: malformed diff (git exit 128)" >&2; return 2 ;;
  esac
}

case "${1:-}" in
  diff)        shift; cmd_diff "$@" ;;
  anti-gaming) shift; cmd_anti_gaming "$@" ;;
  guard-relax) shift; cmd_guard_relax "$@" ;;
  classify)    shift; cmd_classify "$@" ;;
  tally)       shift; cmd_tally "$@" ;;
  canon)       shift; cmd_canon "$@" ;;
  majority)    shift; cmd_majority "$@" ;;
  diff-pair)   shift; cmd_diff_pair "$@" ;;
  cache-key)   shift; cmd_cache_key "$@" ;;
  cache-path)  shift; cmd_cache_path "$@" ;;
  reproduces)  shift; cmd_reproduces "$@" ;;
  *) echo "usage: smith-eval-gate.sh {diff <marker> <expected>|anti-gaming <diff>|guard-relax <diff>|classify <diff>|tally <results> <thresholds>|canon <marker>|majority <marker>...|diff-pair <baseline> <proposal>|cache-key <scenario> <K> <prose-file>...|cache-path <cache-dir> <key>|reproduces <diff> <repo-dir>}" >&2; exit 2 ;;
esac
