#!/usr/bin/env bash
# Context-Economy — per-session Langfuse cost reader. <session-id> -> cost JSON.
# CONSUMES the promoted substrate at substrate/langfuse-observability/ (traces API);
# never re-instruments. Fail-open: always prints valid JSON and exits 0.
# NOTE: Langfuse attributes cost per agent/turn, NOT per skill — per-skill cost is
# impossible here (died with OTEL, see reference_langfuse_spike_exists). This lens
# grounds the ROI number (real session cost) + delegation cost, not skill cost.
set -uo pipefail
SID="${1:-}"

emit_empty() {  # $1 = note. All numerics null; members []; exit 0.
  jq -n --arg n "$1" \
    '{session_cost_usd:null, conductor_cost_usd:null, delegation_cost_usd:null, members:[], note:$n}'
  exit 0
}

[ -n "$SID" ] || emit_empty "no session id given"

if [ -n "${CE_LANGFUSE_RESPONSE:-}" ]; then
  [ -f "$CE_LANGFUSE_RESPONSE" ] || emit_empty "response file not found"
  raw="$(cat "$CE_LANGFUSE_RESPONSE")"
else
  [ "${CE_LANGFUSE_DOWN:-}" = "1" ] && emit_empty "langfuse unreachable (substrate down, batch-cached)"
  ENV_FILE="${CE_LANGFUSE_ENV:-$HOME/Development/jcslOS/substrate/langfuse-observability/.env}"
  [ -f "$ENV_FILE" ] || emit_empty "no substrate .env ($ENV_FILE)"
  # shellcheck disable=SC1090
  set -a; . "$ENV_FILE"; set +a
  PK="${CC_LANGFUSE_PUBLIC_KEY:-${LANGFUSE_PUBLIC_KEY:-}}"
  SK="${CC_LANGFUSE_SECRET_KEY:-${LANGFUSE_SECRET_KEY:-}}"
  BASE="${CC_LANGFUSE_BASE_URL:-${LANGFUSE_BASE_URL:-http://localhost:3000}}"
  [ -n "$PK" ] && [ -n "$SK" ] || emit_empty "incomplete substrate credentials"
  case "$BASE" in
    http://localhost:*|http://127.0.0.1:*) : ;;
    *) emit_empty "refusing non-localhost base url (zero-egress guard)" ;;
  esac
  curl -sf -o /dev/null --max-time 5 "$BASE/api/public/health" \
    || emit_empty "langfuse unreachable (substrate down)"
  raw="$(curl -sfG --max-time 15 -u "$PK:$SK" \
          --data-urlencode "sessionId=$SID" --data-urlencode "limit=100" \
          "$BASE/api/public/traces" || true)"
  [ -n "$raw" ] || emit_empty "empty response from traces API"
fi

jq -e '.data' >/dev/null 2>&1 <<<"$raw" || emit_empty "unparseable traces response"

# Reducer: split member (" · "-named) vs conductor (everything else) trace costs.
result="$(jq -c '
  (.data // [])
  | map(. + {is_member: (.name | contains(" · "))})
  | ( map(select(.is_member))
      | group_by(.name | split(" · ")[0])
      | map({ agent: (.[0].name | split(" · ")[0]),
              turns: length,
              cost_usd: (map(.totalCost // 0) | add) })
      | sort_by(.agent) ) as $members
  | ((map(select(.is_member) | .totalCost // 0) | add) // 0) as $deleg
  | ((map(select(.is_member | not) | .totalCost // 0) | add) // 0) as $cond
  | { session_cost_usd: ($cond + $deleg),
      conductor_cost_usd: $cond,
      delegation_cost_usd: $deleg,
      members: $members,
      note: "" }' <<<"$raw" 2>/dev/null || true)"

if [ -z "$result" ] || ! jq -e . >/dev/null 2>&1 <<<"$result"; then
  emit_empty "reducer produced no valid output"
fi

# Honest note on the no-data / conductor-only cases (still exit 0).
# A zero-trace session (substrate up, no traces yet) must look like substrate-down
# to callers — all numerics null — so retro-harvest never counts a phantom $0 into
# lenses_available or the cost corpus. A genuine conductor-only session always has
# conductor cost > 0, so that case keeps its numerics and still fires the lens.
mcount="$(jq -r '.members | length' <<<"$result")"
if [ "$mcount" -eq 0 ]; then
  ccost="$(jq -r '.conductor_cost_usd' <<<"$result")"
  if [ "$ccost" = "0" ] || [ "$ccost" = "null" ]; then
    result="$(jq --arg sid "$SID" \
      '.session_cost_usd=null | .conductor_cost_usd=null | .delegation_cost_usd=null | .note=("no traces for session " + $sid)' \
      <<<"$result")"
  else
    result="$(jq --arg sid "$SID" '.note = "conductor-only (no subagent traces) for session " + $sid' <<<"$result")"
  fi
fi

printf '%s\n' "$result"
