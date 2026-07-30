#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPT="$HERE/ce-langfuse-cost.sh"
fail=0
assert_eq() { if [ "$2" != "$3" ]; then echo "FAIL: $1 — expected [$2] got [$3]"; fail=1; else echo "ok: $1"; fi; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# Fixture: 2 conductor turns + 2 crafter turns + 1 inspector turn.
resp="$TMP/traces.json"
cat > "$resp" <<'JSON'
{"data":[
  {"name":"Claude Code - Turn 1","sessionId":"s","totalCost":1.0},
  {"name":"Claude Code - Turn 2","sessionId":"s","totalCost":0.5},
  {"name":"crafter · Turn 1","sessionId":"s","totalCost":0.30},
  {"name":"crafter · Turn 2","sessionId":"s","totalCost":0.14},
  {"name":"inspector · Turn 1","sessionId":"s","totalCost":0.06}
],"meta":{}}
JSON

out="$(CE_LANGFUSE_RESPONSE="$resp" bash "$SCRIPT" s)"; rc=$?
assert_eq "exit 0 on good response" "0" "$rc"
assert_eq "valid JSON out" "true" "$(jq -e . >/dev/null 2>&1 <<<"$out" && echo true || echo false)"
assert_eq "conductor cost summed" "1.5" "$(jq -r '.conductor_cost_usd' <<<"$out")"
assert_eq "delegation cost = crafter+inspector = 0.5" "0.5" "$(jq -r '.delegation_cost_usd' <<<"$out")"
assert_eq "session cost = conductor + delegation = 2.0" "2" "$(jq -r '.session_cost_usd' <<<"$out")"
assert_eq "two member rows" "2" "$(jq -r '.members|length' <<<"$out")"
assert_eq "member agents sorted" "crafter inspector" "$(jq -r '[.members[].agent]|sort|join(" ")' <<<"$out")"

# conductor-only session → delegation 0, members [], note set, exit 0
condonly="$TMP/cond.json"; printf '{"data":[{"name":"Claude Code - Turn 1","sessionId":"s","totalCost":1.5}],"meta":{}}' > "$condonly"
oc="$(CE_LANGFUSE_RESPONSE="$condonly" bash "$SCRIPT" s)"; ec=$?
assert_eq "conductor-only exit 0" "0" "$ec"
assert_eq "conductor-only delegation 0" "0" "$(jq -r '.delegation_cost_usd' <<<"$oc")"
assert_eq "conductor-only members []" "0" "$(jq -r '.members|length' <<<"$oc")"
assert_eq "conductor-only note set" "true" "$(jq -r '(.note|length)>0' <<<"$oc")"

# fail-open: malformed JSON → nulls, note, exit 0
bad="$TMP/bad.json"; printf 'not json{' > "$bad"
ob="$(CE_LANGFUSE_RESPONSE="$bad" bash "$SCRIPT" s)"; eb=$?
assert_eq "malformed exit 0" "0" "$eb"
assert_eq "malformed session cost null" "null" "$(jq -r '.session_cost_usd' <<<"$ob")"
assert_eq "malformed note set" "true" "$(jq -r '(.note|length)>0' <<<"$ob")"

# fail-open: no session id → nulls, note, exit 0
on="$(bash "$SCRIPT")"; en=$?
assert_eq "no session id exit 0" "0" "$en"
assert_eq "no session id note set" "true" "$(jq -r '(.note|length)>0' <<<"$on")"

# zero-egress: non-localhost base url → refuse, nulls, exit 0
# (env file must supply credentials so the script reaches the base-url guard
# rather than short-circuiting earlier on missing creds)
envfile="$TMP/none.env"
printf 'CC_LANGFUSE_PUBLIC_KEY=pk-test\nCC_LANGFUSE_SECRET_KEY=sk-test\n' > "$envfile"
oz="$(CE_LANGFUSE_ENV="$envfile" CC_LANGFUSE_BASE_URL="https://evil.example.com" bash "$SCRIPT" s)"; ez=$?
assert_eq "non-localhost exit 0" "0" "$ez"
assert_eq "non-localhost refused note" "true" "$(jq -r '(.note|test("localhost"))' <<<"$oz")"

# session id with double-quote must not break JSON contract (passed via jq --arg)
oq="$(CE_LANGFUSE_RESPONSE="$TMP/none.json" bash "$SCRIPT" 'sess-"inj')"; eqc=$?
printf '{"data":[]}' > "$TMP/none.json"
oq="$(CE_LANGFUSE_RESPONSE="$TMP/none.json" bash "$SCRIPT" 'sess-"inj')"
assert_eq "quoted session id → valid JSON" "true" "$(jq -e . >/dev/null 2>&1 <<<"$oq" && echo true || echo false)"

echo "PASS/FAIL summary:"; [ "$fail" -eq 0 ] && echo "ALL PASS" || echo "FAILURES"
exit "$fail"
