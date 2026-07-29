#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../smith-eval-gate.sh"
FIX="$HERE/fixtures/eval-gate"
fail=0
assert_eq() { if [ "$2" != "$3" ]; then echo "FAIL: $1 — expected [$2] got [$3]"; fail=1; else echo "ok: $1"; fi; }
assert_exit() { # $1=desc $2=expected-code $3=actual-code
  if [ "$2" != "$3" ]; then echo "FAIL: $1 — expected exit $2 got $3"; fail=1; else echo "ok: $1"; fi; }

# --- diff: good marker matches its fixture -> PASS, exit 0 ---
out="$(bash "$SCRIPT" diff "$FIX/marker-01-good.txt" "$FIX/expected-01.json")"; rc=$?
assert_eq  "diff good: says PASS" "PASS" "$out"
assert_exit "diff good: exit 0" "0" "$rc"

# --- diff: wrong lane -> FAIL names the field, exit 1 ---
out="$(bash "$SCRIPT" diff "$FIX/marker-01-wronglane.txt" "$FIX/expected-01.json")"; rc=$?
assert_eq  "diff wrong-lane: names lane" "true" "$(printf '%s' "$out" | grep -q 'FAIL: lane' && echo true || echo false)"
assert_exit "diff wrong-lane: exit 1" "1" "$rc"

# --- diff: wrong gate -> FAIL names the gate, exit 1 ---
out="$(bash "$SCRIPT" diff "$FIX/marker-03-wronggate.txt" "$FIX/expected-03.json")"; rc=$?
assert_eq  "diff wrong-gate: names PLAN-GATE" "true" "$(printf '%s' "$out" | grep -q 'PLAN-GATE' && echo true || echo false)"
assert_exit "diff wrong-gate: exit 1" "1" "$rc"

# --- diff: unparseable marker -> exit 2 (fail-loud, NOT a pass) ---
bash "$SCRIPT" diff "$FIX/marker-garbage.txt" "$FIX/expected-01.json" >/dev/null 2>&1; rc=$?
assert_exit "diff garbage: exit 2 (fail-loud)" "2" "$rc"

# --- anti-gaming: clean diff (touches lanes.md) -> exit 0 ---
bash "$SCRIPT" anti-gaming "$FIX/diff-clean.patch" >/dev/null 2>&1; rc=$?
assert_exit "anti-gaming clean: exit 0" "0" "$rc"

# --- anti-gaming: diff touches expected/ -> exit 3, names it ---
out="$(bash "$SCRIPT" anti-gaming "$FIX/diff-touches-fixture.patch" 2>&1)"; rc=$?
assert_exit "anti-gaming fixture: exit 3" "3" "$rc"
assert_eq  "anti-gaming fixture: names expected/" "true" "$(printf '%s' "$out" | grep -q 'expected/' && echo true || echo false)"

# --- anti-gaming: --no-prefix diff (no a/ b/ prefix) touching expected/ -> exit 3 ---
out="$(bash "$SCRIPT" anti-gaming "$FIX/diff-noprefix-touches-fixture.patch" 2>&1)"; rc=$?
assert_exit "anti-gaming no-prefix: exit 3" "3" "$rc"
assert_eq  "anti-gaming no-prefix: names expected/" "true" "$(printf '%s' "$out" | grep -q 'expected/' && echo true || echo false)"

# --- anti-gaming: subdir-rooted diff (no plugins/kiln/skills/fire/ segment) touching expected/ -> exit 3 ---
out="$(bash "$SCRIPT" anti-gaming "$FIX/diff-subdirrooted-touches-fixture.patch" 2>&1)"; rc=$?
assert_exit "anti-gaming subdir-rooted: exit 3" "3" "$rc"
assert_eq  "anti-gaming subdir-rooted: names expected/" "true" "$(printf '%s' "$out" | grep -q 'expected/' && echo true || echo false)"

# --- anti-gaming: pure-rename diff (diff --git/rename from/rename to, no ---/+++) moving scenario -> exit 3 ---
out="$(bash "$SCRIPT" anti-gaming "$FIX/diff-rename-touches-scenario.patch" 2>&1)"; rc=$?
assert_exit "anti-gaming rename: exit 3" "3" "$rc"
assert_eq  "anti-gaming rename: names scenarios/" "true" "$(printf '%s' "$out" | grep -q 'scenarios/' && echo true || echo false)"

# --- anti-gaming: a + content line MENTIONING eval/expected/ (header touches lanes.md only) -> exit 0 ---
# Guards the header-only scan: mentioning a fixture path in prose is not touching the fixture file.
bash "$SCRIPT" anti-gaming "$FIX/diff-content-mentions-fixture.patch" >/dev/null 2>&1; rc=$?
assert_exit "anti-gaming content-mention: exit 0 (content line ignored)" "0" "$rc"

# --- anti-gaming: unreadable/missing diff file -> exit 2, fail-loud (never a silent 0/3 pass) ---
bash "$SCRIPT" anti-gaming "$FIX/does-not-exist-nonexistent.patch" >/dev/null 2>&1; rc=$?
assert_exit "anti-gaming missing file: exit 2 (fail-loud)" "2" "$rc"

# --- tally: all pass -> RECOMMENDED, exit 0 ---
out="$(bash "$SCRIPT" tally "$FIX/results-all-pass.txt" "$FIX/thresholds.yaml")"; rc=$?
assert_eq  "tally all-pass: RECOMMENDED" "true" "$(printf '%s' "$out" | grep -q 'RECOMMENDED' && echo true || echo false)"
assert_exit "tally all-pass: exit 0" "0" "$rc"

# --- tally: one regression -> OBSERVATION-ONLY names it, exit 1 ---
out="$(bash "$SCRIPT" tally "$FIX/results-one-fail.txt" "$FIX/thresholds.yaml")"; rc=$?
assert_eq  "tally one-fail: OBSERVATION-ONLY" "true" "$(printf '%s' "$out" | grep -q 'OBSERVATION-ONLY' && echo true || echo false)"
assert_eq  "tally one-fail: names scenario 09" "true" "$(printf '%s' "$out" | grep -q '09' && echo true || echo false)"
assert_exit "tally one-fail: exit 1" "1" "$rc"

# --- canon: two markers differing only in list ORDER canonicalize identically ---
a="$(bash "$SCRIPT" canon "$FIX/marker-order-a.txt")"
b="$(bash "$SCRIPT" canon "$FIX/marker-order-b.txt")"
assert_eq "canon: order-insensitive" "$a" "$b"

# --- canon: unparseable marker -> exit 2 (fail-loud) ---
bash "$SCRIPT" canon "$FIX/marker-garbage.txt" >/dev/null 2>&1; rc=$?
assert_exit "canon garbage: exit 2" "2" "$rc"

# --- majority: 3 markers, 2 agree -> prints the agreed canonical form, exit 0 ---
out="$(bash "$SCRIPT" majority "$FIX/marker-01-good.txt" "$FIX/marker-01-good.txt" "$FIX/marker-01-wronglane.txt")"; rc=$?
assert_eq  "majority 2:1: picks the pair" "$(bash "$SCRIPT" canon "$FIX/marker-01-good.txt")" "$out"
assert_exit "majority 2:1: exit 0" "0" "$rc"

# --- majority: 1:1:1 tie -> UNSTABLE, exit 4 ---
out="$(bash "$SCRIPT" majority "$FIX/marker-01-good.txt" "$FIX/marker-01-wronglane.txt" "$FIX/marker-03-wronggate.txt")"; rc=$?
assert_eq  "majority tie: UNSTABLE" "UNSTABLE" "$out"
assert_exit "majority tie: exit 4" "4" "$rc"

# --- diff-pair: identical majorities -> SAME, exit 0 ---
maj="$(bash "$SCRIPT" canon "$FIX/marker-01-good.txt")"
printf '%s\n' "$maj" > "$FIX/tmp-base.canon"; printf '%s\n' "$maj" > "$FIX/tmp-prop.canon"
out="$(bash "$SCRIPT" diff-pair "$FIX/tmp-base.canon" "$FIX/tmp-prop.canon")"; rc=$?
assert_eq  "diff-pair same: SAME" "SAME" "$out"
assert_exit "diff-pair same: exit 0" "0" "$rc"

# --- diff-pair: lane differs -> CHANGED names the field, exit 1 ---
bash "$SCRIPT" canon "$FIX/marker-01-wronglane.txt" > "$FIX/tmp-prop.canon"
out="$(bash "$SCRIPT" diff-pair "$FIX/tmp-base.canon" "$FIX/tmp-prop.canon")"; rc=$?
assert_eq  "diff-pair changed: names lane" "true" "$(printf '%s' "$out" | grep -qi 'CHANGED' && printf '%s' "$out" | grep -q 'TRIVIAL' && echo true || echo false)"
assert_exit "diff-pair changed: exit 1" "1" "$rc"

# --- diff-pair: UNSTABLE side propagates -> exit 4 ---
printf 'UNSTABLE\n' > "$FIX/tmp-prop.canon"
bash "$SCRIPT" diff-pair "$FIX/tmp-base.canon" "$FIX/tmp-prop.canon" >/dev/null 2>&1; rc=$?
assert_exit "diff-pair unstable: exit 4" "4" "$rc"
rm -f "$FIX/tmp-base.canon" "$FIX/tmp-prop.canon"

# --- cache-key: deterministic for same inputs ---
k1="$(bash "$SCRIPT" cache-key 01-trivial 3 "$FIX/marker-01-good.txt")"
k2="$(bash "$SCRIPT" cache-key 01-trivial 3 "$FIX/marker-01-good.txt")"
assert_eq "cache-key: deterministic" "$k1" "$k2"

# --- cache-key: changes when K changes ---
k3="$(bash "$SCRIPT" cache-key 01-trivial 5 "$FIX/marker-01-good.txt")"
assert_eq "cache-key: K-sensitive" "false" "$([ "$k1" = "$k3" ] && echo true || echo false)"

# --- cache-key: changes when prose changes ---
k4="$(bash "$SCRIPT" cache-key 01-trivial 3 "$FIX/marker-01-wronglane.txt")"
assert_eq "cache-key: prose-sensitive" "false" "$([ "$k1" = "$k4" ] && echo true || echo false)"

# --- cache-key: fails loud with zero prose files (never blocks on stdin or hashes empty) ---
bash "$SCRIPT" cache-key 01-trivial 3 </dev/null >/dev/null 2>&1; rc=$?
assert_exit "cache-key no-files: exit 2 (fail-loud)" "2" "$rc"

# --- cache-path: composes dir + key + .canon ---
out="$(bash "$SCRIPT" cache-path /tmp/smith-cache "$k1")"
assert_eq "cache-path: composes" "/tmp/smith-cache/$k1.canon" "$out"

# --- guard-relax: proposal-A-shaped diff (adds inline-edit prose) -> exit 5, names the line ---
out="$(bash "$SCRIPT" guard-relax "$FIX/diff-guard-relax.patch" 2>&1)"; rc=$?
assert_exit "guard-relax A-shape: exit 5" "5" "$rc"
assert_eq  "guard-relax A-shape: flags RELAXATION" "true" "$(printf '%s' "$out" | grep -q 'RELAXATION' && echo true || echo false)"

# --- guard-relax: routing-only diff (no relaxation phrase) -> exit 0 ---
bash "$SCRIPT" guard-relax "$FIX/diff-guard-clean.patch" >/dev/null 2>&1; rc=$?
assert_exit "guard-relax clean: exit 0" "0" "$rc"

# --- guard-relax: content-line mention only in a REMOVED (-) line is not a relaxation add -> exit 0 ---
# Guards the added-lines-only scan: removing inline-edit prose is a tightening, not a relaxation.
bash "$SCRIPT" guard-relax "$FIX/diff-guard-removal.patch" >/dev/null 2>&1; rc=$?
assert_exit "guard-relax removal-only: exit 0" "0" "$rc"

# --- guard-relax: unreadable/missing diff file -> exit 2, fail-loud (never a silent 0/5 pass) ---
bash "$SCRIPT" guard-relax "$FIX/does-not-exist-nonexistent.patch" >/dev/null 2>&1; rc=$?
assert_exit "guard-relax missing file: exit 2 (fail-loud)" "2" "$rc"

# --- guard-relax: PARAPHRASE evasion — authorizes inline edit in words that dodge the fixed
# phrase set ("authorized to write the fix in place without dispatching a crafter") -> exit 5 ---
out="$(bash "$SCRIPT" guard-relax "$FIX/diff-guard-paraphrase.patch" 2>&1)"; rc=$?
assert_exit "guard-relax paraphrase: exit 5 (not evaded)" "5" "$rc"

# --- guard-relax: SPLIT across two added lines — "skip the crafter / dispatch and apply the edit"
# straddles a line break; single-line matching would miss it, joined matching catches it -> exit 5 ---
bash "$SCRIPT" guard-relax "$FIX/diff-guard-split.patch" >/dev/null 2>&1; rc=$?
assert_exit "guard-relax split-lines: exit 5 (joined-line match)" "5" "$rc"

# --- guard-relax: NEGATION tightening — "the conductor may never edit shipped source inline"
# TIGHTENS the guard; it must NOT be misflagged as a relaxation -> exit 0 ---
bash "$SCRIPT" guard-relax "$FIX/diff-guard-tighten.patch" >/dev/null 2>&1; rc=$?
assert_exit "guard-relax negation-tighten: exit 0 (not a false positive)" "0" "$rc"

# --- classify: guard-relaxation prose (proposal-A shape) -> includes guard-relaxation (+ routing-output, since it edits SKILL.md routing prose) ---
out="$(bash "$SCRIPT" classify "$FIX/diff-guard-relax.patch")"
assert_eq "classify A-shape: has guard-relaxation" "true" "$(printf '%s' "$out" | grep -q 'guard-relaxation' && echo true || echo false)"

# --- classify: edits the guard hook code itself -> guard-hook-code ---
out="$(bash "$SCRIPT" classify "$FIX/diff-hookcode.patch")"
assert_eq "classify hook-code: has guard-hook-code" "true" "$(printf '%s' "$out" | grep -q 'guard-hook-code' && echo true || echo false)"

# --- classify: edits the guard TEST HARNESS (test-kiln-guards.sh) — the file eval-gate.md names
# as the guard-hook-code control — must also classify guard-hook-code so the control routes ---
out="$(bash "$SCRIPT" classify "$FIX/diff-testharness.patch")"
assert_eq "classify test-harness: has guard-hook-code" "true" "$(printf '%s' "$out" | grep -q 'guard-hook-code' && echo true || echo false)"

# --- classify: PARAPHRASE relaxation prose still classifies guard-relaxation (classify reuses
# guard-relax; the evasion fix must close the classify path too, not just the standalone check) ---
out="$(bash "$SCRIPT" classify "$FIX/diff-guard-paraphrase.patch")"
assert_eq "classify paraphrase: has guard-relaxation" "true" "$(printf '%s' "$out" | grep -q 'guard-relaxation' && echo true || echo false)"

# --- classify: routing table edit only -> routing-output, no guard/perf ---
out="$(bash "$SCRIPT" classify "$FIX/diff-routing-only.patch")"
assert_eq "classify routing: has routing-output" "true" "$(printf '%s' "$out" | grep -q 'routing-output' && echo true || echo false)"
assert_eq "classify routing: no guard-relaxation" "false" "$(printf '%s' "$out" | grep -q 'guard-relaxation' && echo true || echo false)"

# --- classify: detection-speed prose only (proposal-B shape) -> detection-perf ---
out="$(bash "$SCRIPT" classify "$FIX/diff-detection-perf.patch")"
assert_eq "classify B-shape: has detection-perf" "true" "$(printf '%s' "$out" | grep -q 'detection-perf' && echo true || echo false)"

# --- classify: empty/unmatched diff -> unsure ---
out="$(bash "$SCRIPT" classify "$FIX/diff-guard-clean.patch")"
# diff-guard-clean touches lanes.md routing table -> routing-output; use a truly-unmatched fixture for unsure:
out2="$(bash "$SCRIPT" classify "$FIX/diff-unrelated.patch")"
assert_eq "classify unrelated: unsure" "true" "$(printf '%s' "$out2" | grep -q 'unsure' && echo true || echo false)"

# --- classify: multi-file diff touching a non-script hooks/kiln-guard-* path PLUS an
# unrelated .sh file must NOT bleed across lines into guard-hook-code (case globs match
# newlines; matching per-line, not against the whole multi-line header blob, prevents this) ---
out="$(bash "$SCRIPT" classify "$FIX/diff-multifile-nohook.patch")"
assert_eq "classify multifile no-hook: no guard-hook-code (no cross-line bleed)" "false" "$(printf '%s' "$out" | grep -q 'guard-hook-code' && echo true || echo false)"

# --- classify: multi-file diff touching TWO real routing files -> routing-output
# appears exactly once (dedup holds across multiple matching files) ---
out="$(bash "$SCRIPT" classify "$FIX/diff-multifile-tworouting.patch")"
assert_eq "classify multifile two-routing: routing-output present" "true" "$(printf '%s' "$out" | grep -q 'routing-output' && echo true || echo false)"
assert_eq "classify multifile two-routing: routing-output appears exactly once" "1" "$(printf '%s' "$out" | tr ' ' '\n' | grep -c '^routing-output$')"

# --- classify: missing/unreadable file degrades to unsure, NOT guard-relaxation
# (cmd_guard_relax exit 2 = unreadable must not be conflated with exit 5 = relaxation match) ---
out="$(bash "$SCRIPT" classify "$FIX/does-not-exist-nonexistent.patch" 2>/dev/null)"; rc=$?
assert_eq "classify missing file: unsure" "true" "$(printf '%s' "$out" | grep -q 'unsure' && echo true || echo false)"
assert_eq "classify missing file: no guard-relaxation" "false" "$(printf '%s' "$out" | grep -q 'guard-relaxation' && echo true || echo false)"
assert_exit "classify missing file: exit 0 (always advisory)" "0" "$rc"

exit $fail
