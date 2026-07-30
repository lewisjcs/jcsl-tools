#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../smith-harvest.sh"
FIX="$HERE/fixtures"
fail=0
assert_eq() { # $1=desc $2=expected $3=actual
  if [ "$2" != "$3" ]; then echo "FAIL: $1 — expected [$2] got [$3]"; fail=1; else echo "ok: $1"; fi
}

# --- Task 1: structured verdict parse (legacy verdict-N.md convention) ---
out="$(mktemp)"
bash "$SCRIPT" --run-dir "$FIX/clean-run/kiln" --out "$out"
assert_eq "run_id" "clean-run" "$(jq -r '.run_id' "$out")"
assert_eq "task1 spec" "pass" "$(jq -r '.tasks[0].spec' "$out")"
assert_eq "task1 quality" "approved" "$(jq -r '.tasks[0].quality' "$out")"
assert_eq "task1 criteria_met" "4" "$(jq -r '.tasks[0].criteria_met' "$out")"
assert_eq "task1 critical" "0" "$(jq -r '.tasks[0].critical_findings' "$out")"

# --- Task 1: structured verdict parse (current task-N-<slug>-verdict.md convention) ---
out2="$(mktemp)"
bash "$SCRIPT" --run-dir "$FIX/new-convention-run/kiln" --out "$out2"
assert_eq "new-convention run_id" "new-convention-run" "$(jq -r '.run_id' "$out2")"
assert_eq "new-convention task n" "1" "$(jq -r '.tasks[0].n' "$out2")"
assert_eq "new-convention task spec" "pass" "$(jq -r '.tasks[0].spec' "$out2")"
assert_eq "new-convention task quality" "approved" "$(jq -r '.tasks[0].quality' "$out2")"
assert_eq "new-convention task criteria_met" "4" "$(jq -r '.tasks[0].criteria_met' "$out2")"
assert_eq "new-convention task critical" "0" "$(jq -r '.tasks[0].critical_findings' "$out2")"

# --- Task 2: friction + timestamps ---
assert_eq "fix_loops" "1" "$(jq -r '.fix_loops' "$out")"
assert_eq "friction has deviation" "true" \
  "$(jq -r '[.friction[] | test("DEVIATION")] | any' "$out")"
assert_eq "first_ts" "2026-07-13T17:26:00Z" "$(jq -r '.first_ts' "$out")"
assert_eq "last_ts" "2026-07-13T18:52:00Z" "$(jq -r '.last_ts' "$out")"

# --- Task 2 fix: mixed-precision same-minute timestamps order chronologically ---
out3="$(mktemp)"
bash "$SCRIPT" --run-dir "$FIX/mixed-precision/kiln" --out "$out3"
assert_eq "mixed-precision first_ts (minute-only, earlier)" "2026-07-13T14:48Z" \
  "$(jq -r '.first_ts' "$out3")"
assert_eq "mixed-precision last_ts (full-second, later)" "2026-07-13T14:48:45Z" \
  "$(jq -r '.last_ts' "$out3")"

# --- Task 3: cost join (fake ccusage) ---
chmod +x "$FIX/fake-ccusage.sh"
out2="$(mktemp)"
SMITH_CCUSAGE="bash $FIX/fake-ccusage.sh" bash "$SCRIPT" --run-dir "$FIX/clean-run/kiln" --out "$out2"
assert_eq "session_id" "sess-clean-123" "$(jq -r '.session_id' "$out2")"
assert_eq "cost_usd" "1.23" "$(jq -r '.cost_usd' "$out2")"

# --- Slice 1.5: cost joins via .completed marker on a COMPLETED run (no .active) ---
outc="$(mktemp)"
SMITH_CCUSAGE="bash $FIX/fake-ccusage.sh" bash "$SCRIPT" --run-dir "$FIX/completed-run/kiln" --out "$outc"
assert_eq "completed-run session_id from .completed" "sess-clean-123" "$(jq -r '.session_id' "$outc")"
assert_eq "completed-run cost_usd from .completed" "1.23" "$(jq -r '.cost_usd' "$outc")"

# degrade: no matching session → null cost, note set, still exits 0
missdir="$(mktemp -d)/kiln"; mkdir -p "$missdir"; printf 'sess-absent\n' > "$missdir/.active"
: > "$missdir/progress.md"
out3="$(mktemp)"
SMITH_CCUSAGE="bash $FIX/fake-ccusage.sh" bash "$SCRIPT" --run-dir "$missdir" --out "$out3"
assert_eq "missing-session cost null" "null" "$(jq -r '.cost_usd' "$out3")"
assert_eq "missing-session note set" "true" "$(jq -r '(.cost_note|length)>0' "$out3")"

# --- Task 3 fix: quoted session id in .active must not crash the write ---
qdir="$(mktemp -d)/kiln"; mkdir -p "$qdir"
printf 'sess"quote\n' > "$qdir/.active"
: > "$qdir/progress.md"
out4="$(mktemp)"
SMITH_CCUSAGE="bash $FIX/fake-ccusage.sh" bash "$SCRIPT" --run-dir "$qdir" --out "$out4"
quoted_exit=$?
assert_eq "quoted session id: exit 0" "0" "$quoted_exit"
assert_eq "quoted session id: valid JSON" "true" "$(jq -e . "$out4" >/dev/null 2>&1 && echo true || echo false)"
assert_eq "quoted session id: safely stringified" 'sess"quote' "$(jq -r '.session_id' "$out4")"

# --- Task 3 fix: non-numeric costUSD from ccusage must not crash the write ---
chmod +x "$FIX/fake-ccusage-badcost.sh"
out5="$(mktemp)"
SMITH_CCUSAGE="bash $FIX/fake-ccusage-badcost.sh" bash "$SCRIPT" --run-dir "$FIX/clean-run/kiln" --out "$out5"
badcost_exit=$?
assert_eq "malformed cost: exit 0" "0" "$badcost_exit"
assert_eq "malformed cost: cost_usd null" "null" "$(jq -r '.cost_usd' "$out5")"
assert_eq "malformed cost: note set" "true" "$(jq -r '(.cost_note|length)>0' "$out5")"

# --- Task 4 (carry-forward from Task 1 review): mixed verdict-naming
# conventions in one run dir must not double-count tasks ---
outmix="$(mktemp)"
bash "$SCRIPT" --run-dir "$FIX/mixed-convention/kiln" --out "$outmix"
assert_eq "mixed-convention task count" "3" "$(jq -r '.tasks | length' "$outmix")"
assert_eq "mixed-convention task numbers" "1 2 3" \
  "$(jq -r '[.tasks[].n] | sort | join(" ")' "$outmix")"

# --- Task 4 (optional): multi-digit task numbers parse correctly ---
outmulti="$(mktemp)"
bash "$SCRIPT" --run-dir "$FIX/multidigit-convention/kiln" --out "$outmulti"
assert_eq "multi-digit task n" "12" "$(jq -r '.tasks[0].n' "$outmulti")"

# --- Task 4: idempotency ---
r1="$(mktemp)"; r2="$(mktemp)"
SMITH_CCUSAGE="bash $FIX/fake-ccusage.sh" bash "$SCRIPT" --run-dir "$FIX/clean-run/kiln" --out "$r1"
SMITH_CCUSAGE="bash $FIX/fake-ccusage.sh" bash "$SCRIPT" --run-dir "$FIX/clean-run/kiln" --out "$r2"
assert_eq "idempotent digest" "$(cat "$r1")" "$(cat "$r2")"

# --- Task 4: multi-run driver mode ---
ws="$(mktemp -d)"
mkdir -p "$ws/projects/active/run-a/kiln" "$ws/projects/active/run-b/kiln"
: > "$ws/projects/active/run-a/kiln/progress.md"
: > "$ws/projects/active/run-b/kiln/progress.md"
# build filter (Slice 1.5): give each folder a sentinel so it still qualifies as a build.
: > "$ws/projects/active/run-a/kiln/.completed"
: > "$ws/projects/active/run-b/kiln/.completed"
# stagger mtimes so --last ordering is deterministic
touch -t 202607131700 "$ws/projects/active/run-a/kiln/progress.md"
touch -t 202607131701 "$ws/projects/active/run-b/kiln/progress.md"

driver_out="$(SMITH_CCUSAGE="bash $FIX/fake-ccusage.sh" bash "$SCRIPT" --workspace "$ws" --last 2)"
driver_exit=$?
assert_eq "driver: exit 0" "0" "$driver_exit"
assert_eq "driver: prints both retro.json paths" "true" \
  "$(printf '%s\n' "$driver_out" | grep -qF "run-a/kiln/retro.json" && printf '%s\n' "$driver_out" | grep -qF "run-b/kiln/retro.json" && echo true || echo false)"
assert_eq "driver: writes run-a retro.json" "true" "$([ -f "$ws/projects/active/run-a/kiln/retro.json" ] && echo true || echo false)"
assert_eq "driver: writes run-b retro.json" "true" "$([ -f "$ws/projects/active/run-b/kiln/retro.json" ] && echo true || echo false)"
assert_eq "driver: run-a retro.json is valid JSON" "true" \
  "$(jq -e . "$ws/projects/active/run-a/kiln/retro.json" >/dev/null 2>&1 && echo true || echo false)"

# --- Task 4 fix: --last must be a positive integer, else usage error + exit 2 ---
bash "$SCRIPT" --workspace "$ws" --last abc >/dev/null 2>&1
badlast_exit=$?
assert_eq "bad --last: exit non-zero" "true" "$([ "$badlast_exit" -ne 0 ] && echo true || echo false)"

# --- Fix: absent ccusage (not installed) gets its own wording, distinct from
# an installed-but-old ccusage. Build a PATH containing only the coreutils
# the harvester needs — no `ccusage` binary anywhere on it — so `command -v
# ccusage` genuinely fails rather than relying on this machine happening not
# to have ccusage installed.
noccusage_dir="$(mktemp -d)"
for t in bash jq grep sed awk sort head cut tr dirname basename mktemp tail; do
  tp="$(command -v "$t" 2>/dev/null)"
  [ -n "$tp" ] && ln -sf "$tp" "$noccusage_dir/$t"
done
outabsent="$(mktemp)"
env -i PATH="$noccusage_dir" HOME="$HOME" \
  bash "$SCRIPT" --run-dir "$FIX/clean-run/kiln" --out "$outabsent"
absent_exit=$?
assert_eq "absent ccusage: exit 0" "0" "$absent_exit"
assert_eq "absent ccusage: cost_usd null" "null" "$(jq -r '.cost_usd' "$outabsent")"
assert_eq "absent ccusage: note says not found" "true" \
  "$(jq -r '.cost_note | test("not found")' "$outabsent")"
assert_eq "absent ccusage: note does NOT say double-counts" "false" \
  "$(jq -r '.cost_note | test("double-counts")' "$outabsent")"

# --- Task 4 fix: --last N < total run count truncates to the N most-recent ---
ws3="$(mktemp -d)"
mkdir -p "$ws3/projects/active/run-x/kiln" "$ws3/projects/active/run-y/kiln" "$ws3/projects/active/run-z/kiln"
: > "$ws3/projects/active/run-x/kiln/progress.md"
: > "$ws3/projects/active/run-y/kiln/progress.md"
: > "$ws3/projects/active/run-z/kiln/progress.md"
# build filter (Slice 1.5): give each folder a sentinel so it still qualifies as a build.
: > "$ws3/projects/active/run-x/kiln/.completed"
: > "$ws3/projects/active/run-y/kiln/.completed"
: > "$ws3/projects/active/run-z/kiln/.completed"
touch -t 202607131700 "$ws3/projects/active/run-x/kiln/progress.md"
touch -t 202607131701 "$ws3/projects/active/run-y/kiln/progress.md"
touch -t 202607131702 "$ws3/projects/active/run-z/kiln/progress.md"  # most recent

trunc_out="$(SMITH_CCUSAGE="bash $FIX/fake-ccusage.sh" bash "$SCRIPT" --workspace "$ws3" --last 1)"
assert_eq "truncation: exactly one path printed" "1" "$(printf '%s\n' "$trunc_out" | grep -c 'retro.json')"
assert_eq "truncation: picks most-recent (run-z)" "true" \
  "$(printf '%s\n' "$trunc_out" | grep -qF "run-z/kiln/retro.json" && echo true || echo false)"
assert_eq "truncation: does not touch run-x" "true" "$([ ! -f "$ws3/projects/active/run-x/kiln/retro.json" ] && echo true || echo false)"
assert_eq "truncation: does not touch run-y" "true" "$([ ! -f "$ws3/projects/active/run-y/kiln/retro.json" ] && echo true || echo false)"

# --- Slice 1.5: build filter — sentinel-first, spine-fallback ---
wsf="$(mktemp -d)"
mkdir -p "$wsf/projects/active/note-only/kiln" \
         "$wsf/projects/active/spine-only/kiln" \
         "$wsf/projects/active/sentinel-only/kiln"
# note-only: no spine, no sentinel -> EXCLUDED
printf -- '- billing gap\n' > "$wsf/projects/active/note-only/kiln/progress.md"
# spine-only: tasklist+plan, no sentinel, no verdicts -> INCLUDED, tasks:[]
: > "$wsf/projects/active/spine-only/kiln/tasklist.md"
: > "$wsf/projects/active/spine-only/kiln/plan.md"
printf 'CODE-QUALITY-AUDIT: clean\n' > "$wsf/projects/active/spine-only/kiln/progress.md"
# sentinel-only: .completed, no spine -> INCLUDED
printf 'sess-x\n' > "$wsf/projects/active/sentinel-only/kiln/.completed"
: > "$wsf/projects/active/sentinel-only/kiln/progress.md"
# stagger mtimes so all three are within --last 10
touch -t 202607131700 "$wsf/projects/active/note-only/kiln/progress.md"
touch -t 202607131701 "$wsf/projects/active/spine-only/kiln/progress.md"
touch -t 202607131702 "$wsf/projects/active/sentinel-only/kiln/progress.md"

filt_out="$(SMITH_CCUSAGE="bash $FIX/fake-ccusage.sh" bash "$SCRIPT" --workspace "$wsf" --last 10)"
assert_eq "filter: note-only excluded (no path printed)" "false" \
  "$(printf '%s\n' "$filt_out" | grep -qF 'note-only/kiln/retro.json' && echo true || echo false)"
assert_eq "filter: note-only writes no retro.json" "true" \
  "$([ ! -f "$wsf/projects/active/note-only/kiln/retro.json" ] && echo true || echo false)"
assert_eq "filter: spine-only included" "true" \
  "$(printf '%s\n' "$filt_out" | grep -qF 'spine-only/kiln/retro.json' && echo true || echo false)"
assert_eq "filter: spine-only has empty tasks[]" "0" \
  "$(jq -r '.tasks | length' "$wsf/projects/active/spine-only/kiln/retro.json")"
assert_eq "filter: sentinel-only included" "true" \
  "$(printf '%s\n' "$filt_out" | grep -qF 'sentinel-only/kiln/retro.json' && echo true || echo false)"

# --- Slice 1.5: duration_note makes calendar-vs-work-time explicit ---
# clean-run has real timestamps -> calendar-span note
outd="$(mktemp)"
bash "$SCRIPT" --run-dir "$FIX/clean-run/kiln" --out "$outd"
assert_eq "duration_note: calendar-span when ts present" "true" \
  "$(jq -r '.duration_note | test("calendar span")' "$outd")"
# a run with no parseable timestamps -> unavailable note
ndir="$(mktemp -d)/kiln"; mkdir -p "$ndir"; printf 'no timestamps here\n' > "$ndir/progress.md"
printf 'sess-x\n' > "$ndir/.completed"
outn="$(mktemp)"
bash "$SCRIPT" --run-dir "$ndir" --out "$outn"
assert_eq "duration_note: unavailable when ts null" "true" \
  "$(jq -r '.duration_note | test("unavailable")' "$outn")"
assert_eq "first_ts still null when unparseable" "null" "$(jq -r '.first_ts' "$outn")"

# --- Slice 3a: cost_by_member spliced from the langfuse reader (injected) ---
fakereader="$(mktemp)"; cat > "$fakereader" <<'SH'
#!/usr/bin/env bash
# Fake langfuse reader: ignores the session arg, emits a fixed per-member object.
printf '%s\n' '{"members":[{"agent":"crafter","turns":2,"cost_usd":0.44}],"conductor_cost_usd":2.49,"note":""}'
SH
chmod +x "$fakereader"
outm="$(mktemp)"
SMITH_CCUSAGE="bash $FIX/fake-ccusage.sh" SMITH_LANGFUSE_COST="bash $fakereader" \
  bash "$SCRIPT" --run-dir "$FIX/clean-run/kiln" --out "$outm"
assert_eq "cost_by_member present" "true" "$(jq -e 'has("cost_by_member")' "$outm")"
assert_eq "cost_by_member member agent" "crafter" "$(jq -r '.cost_by_member.members[0].agent' "$outm")"
assert_eq "cost_by_member conductor cost" "2.49" "$(jq -r '.cost_by_member.conductor_cost_usd' "$outm")"
# coarse cost_usd still present and unchanged (additive, not a replacement)
assert_eq "coarse cost_usd untouched" "1.23" "$(jq -r '.cost_usd' "$outm")"

# --- Slice 3a: fail-open — reader can't reach the substrate → cost_by_member is the empty object, still valid ---
# Point the reader's substrate .env at a guaranteed-nonexistent path so it takes its
# "no substrate .env" fail-open branch on ANY host. Without this the test would
# silently exercise the LIVE-query branch on a machine where the substrate is up
# (e.g. the author's dev box) and pass by coincidence, not by testing fail-open.
outnm="$(mktemp)"
SMITH_CCUSAGE="bash $FIX/fake-ccusage.sh" \
SMITH_LANGFUSE_COST="bash $FIX/../../smith-langfuse-cost.sh" \
SMITH_LANGFUSE_ENV="/nonexistent/smith-langfuse-test-no-such.env" \
  bash "$SCRIPT" --run-dir "$FIX/clean-run/kiln" --out "$outnm"
assert_eq "fail-open cost_by_member is object" "object" "$(jq -r '.cost_by_member | type' "$outnm")"
assert_eq "fail-open members empty" "0" "$(jq -r '.cost_by_member.members | length' "$outnm")"

# --- Slice 3a: reader output with a non-array `members` is rejected to the fail-open default ---
# A reader that emits { "members": "oops" } satisfies has("members") but violates the
# documented array contract; the harvester must reject it, not splice a corrupt shape.
badreader="$(mktemp)"; cat > "$badreader" <<'SH'
#!/usr/bin/env bash
printf '%s\n' '{"members":"not-an-array","conductor_cost_usd":1.0,"note":""}'
SH
chmod +x "$badreader"
outbad="$(mktemp)"
SMITH_CCUSAGE="bash $FIX/fake-ccusage.sh" SMITH_LANGFUSE_COST="bash $badreader" \
  bash "$SCRIPT" --run-dir "$FIX/clean-run/kiln" --out "$outbad"
assert_eq "non-array members rejected → members is array" "array" "$(jq -r '.cost_by_member.members | type' "$outbad")"
assert_eq "non-array members rejected → empty" "0" "$(jq -r '.cost_by_member.members | length' "$outbad")"
assert_eq "non-array members rejected → note says unavailable" "true" \
  "$(jq -r '.cost_by_member.note | test("unavailable")' "$outbad")"

exit $fail
