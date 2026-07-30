#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/../smith-langfuse-cost.sh"
FIX="$HERE/fixtures"
fail=0
assert_eq() { if [ "$2" != "$3" ]; then echo "FAIL: $1 — expected [$2] got [$3]"; fail=1; else echo "ok: $1"; fi; }

# --- happy path: fixture groups into per-member cost, conductor split out ---
out="$(SMITH_LANGFUSE_RESPONSE="$FIX/langfuse-traces-response.json" bash "$SCRIPT" sess-fixture)"
assert_eq "exit 0 on good response" "0" "$?"
assert_eq "valid JSON out" "true" "$(jq -e . >/dev/null 2>&1 <<<"$out" && echo true || echo false)"
assert_eq "has members array" "true" "$(jq -e 'has("members")' <<<"$out")"
# two distinct members (crafter, inspector); conductor is NOT a member row
assert_eq "member count" "2" "$(jq -r '.members | length' <<<"$out")"
assert_eq "members are the two agents" "crafter inspector" \
  "$(jq -r '[.members[].agent] | sort | join(" ")' <<<"$out")"
# crafter cost = 0.086963999996 + 0.357749699998 = 0.444713699994
assert_eq "crafter cost summed across turns" "0.444713699994" \
  "$(jq -r '.members[] | select(.agent=="crafter") | .cost_usd' <<<"$out")"
assert_eq "crafter turn count" "2" \
  "$(jq -r '.members[] | select(.agent=="crafter") | .turns' <<<"$out")"
# conductor cost = 1.135467249999 + 1.356344749998 = 2.491811999997, split OUT of members
assert_eq "conductor cost summed, excluded from members" "2.491811999997" \
  "$(jq -r '.conductor_cost_usd' <<<"$out")"

# --- conductor-only session (the COMMON real case today): members:[], note set, exit 0 ---
condonly="$(mktemp)"
printf '{"data":[{"name":"Claude Code - Turn 1","sessionId":"s","totalCost":1.5}],"meta":{}}' > "$condonly"
outc="$(SMITH_LANGFUSE_RESPONSE="$condonly" bash "$SCRIPT" s)"; ec=$?
assert_eq "conductor-only exit 0" "0" "$ec"
assert_eq "conductor-only → members:[]" "0" "$(jq -r '.members|length' <<<"$outc")"
assert_eq "conductor-only → conductor cost present" "1.5" "$(jq -r '.conductor_cost_usd' <<<"$outc")"
assert_eq "conductor-only → note set" "true" "$(jq -r '(.note|length)>0' <<<"$outc")"

# --- fail-open: empty data → members:[], note set, exit 0 ---
empty="$(mktemp)"; printf '{"data":[],"meta":{}}' > "$empty"
oute="$(SMITH_LANGFUSE_RESPONSE="$empty" bash "$SCRIPT" sess-none)"; ee=$?
assert_eq "empty response exit 0" "0" "$ee"
assert_eq "empty → members:[]" "0" "$(jq -r '.members|length' <<<"$oute")"
assert_eq "empty → note set" "true" "$(jq -r '(.note|length)>0' <<<"$oute")"

# --- fail-open: malformed JSON → members:[], note set, exit 0 (never crash the caller) ---
bad="$(mktemp)"; printf 'not json{' > "$bad"
outb="$(SMITH_LANGFUSE_RESPONSE="$bad" bash "$SCRIPT" sess-bad)"; eb=$?
assert_eq "malformed response exit 0" "0" "$eb"
assert_eq "malformed → members:[]" "0" "$(jq -r '.members|length' <<<"$outb")"
assert_eq "malformed → note set" "true" "$(jq -r '(.note|length)>0' <<<"$outb")"

# --- fail-open: no session id given → members:[], note, exit 0 ---
outn="$(bash "$SCRIPT")"; en=$?
assert_eq "no session id exit 0" "0" "$en"
assert_eq "no session id → note set" "true" "$(jq -r '(.note|length)>0' <<<"$outn")"

# --- regression: a session id with a double-quote must NOT break the JSON contract ---
# The empty-data path interpolates the session id into the note; the id is passed via
# jq --arg (not spliced into the program text), so a `"` stays data and the output
# remains valid JSON. Pre-fix this closed the jq string literal early and crashed.
qsid='sess-"injection'
outq="$(SMITH_LANGFUSE_RESPONSE="$empty" bash "$SCRIPT" "$qsid")"; eq=$?
assert_eq "quoted session id exit 0" "0" "$eq"
assert_eq "quoted session id → valid JSON out" "true" \
  "$(jq -e . >/dev/null 2>&1 <<<"$outq" && echo true || echo false)"
assert_eq "quoted session id → note carries the id verbatim" "true" \
  "$(jq -r --arg s "$qsid" '.note | contains($s)' <<<"$outq")"

exit $fail
