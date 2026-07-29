#!/usr/bin/env bash
# The Smith — per-member Langfuse cost reader. <session-id> -> per-member cost JSON.
# CONSUMES the promoted substrate at substrate/langfuse-observability/ (traces API);
# never re-instruments. Fail-open: always prints valid JSON and exits 0.
set -uo pipefail
SID="${1:-}"

# Fail-open emitter: members empty, conductor null, note explains why.
emit_empty() { jq -n --arg n "$1" '{members:[], conductor_cost_usd:null, note:$n}'; exit 0; }

[ -n "$SID" ] || emit_empty "no session id given"

# --- obtain a traces response: injected fixture (test) or live query ---
if [ -n "${SMITH_LANGFUSE_RESPONSE:-}" ]; then
  [ -f "$SMITH_LANGFUSE_RESPONSE" ] || emit_empty "response file not found"
  raw="$(cat "$SMITH_LANGFUSE_RESPONSE")"
else
  # Credentials from the substrate .env (CC-prefixed, per its README consume-contract).
  ENV_FILE="${SMITH_LANGFUSE_ENV:-$HOME/Development/jcslOS/substrate/langfuse-observability/.env}"
  [ -f "$ENV_FILE" ] || emit_empty "no substrate .env ($ENV_FILE)"
  # shellcheck disable=SC1090
  set -a; . "$ENV_FILE"; set +a
  PK="${CC_LANGFUSE_PUBLIC_KEY:-${LANGFUSE_PUBLIC_KEY:-}}"
  SK="${CC_LANGFUSE_SECRET_KEY:-${LANGFUSE_SECRET_KEY:-}}"
  BASE="${CC_LANGFUSE_BASE_URL:-${LANGFUSE_BASE_URL:-http://localhost:3000}}"
  [ -n "$PK" ] && [ -n "$SK" ] || emit_empty "incomplete substrate credentials"
  # Liveness: unreachable substrate → fail open (design §6 Langfuse-liveness).
  curl -sf -o /dev/null --max-time 5 "$BASE/api/public/health" \
    || emit_empty "langfuse unreachable (substrate down)"
  # limit is capped at 100 by the traces API (HTTP 400 above that). A Kiln run's
  # session never approaches 100 turns, so 100 is both the max and sufficient — no
  # pagination needed.
  raw="$(curl -sfG --max-time 15 -u "$PK:$SK" \
          --data-urlencode "sessionId=$SID" --data-urlencode "limit=100" \
          "$BASE/api/public/traces" || true)"
  [ -n "$raw" ] || emit_empty "empty response from traces API"
fi

# --- validate + reduce. Any jq failure on the raw input → fail open. ---
jq -e '.data' >/dev/null 2>&1 <<<"$raw" || emit_empty "unparseable traces response"

# Group by the agent-name prefix of each trace name:
#   "Claude Code - Turn N"  -> conductor (summed into conductor_cost_usd, NOT a member)
#   "<agent> · Turn N"      -> member "<agent>" (split on " · ", first field)
# A row whose name has no " · " and is not "Claude Code ..." is treated as conductor-ish
# (unknown main-thread label) and folded into the conductor bucket, never invented as a member.
result="$(jq -c '
  (.data // [])
  | map(. + {is_member: (.name | contains(" · "))})
  | {
      members: (
        map(select(.is_member))
        | group_by(.name | split(" · ")[0])
        | map({ agent: (.[0].name | split(" · ")[0]),
                turns: length,
                cost_usd: (map(.totalCost // 0) | add) })
        | sort_by(.agent)
      ),
      conductor_cost_usd: (
        (map(select(.is_member | not) | .totalCost // 0) | add) // 0
      ),
      note: ""
    }' <<<"$raw" 2>/dev/null || true)"

# Guard the reducer output itself (defense in depth — a shape we did not anticipate).
if [ -z "$result" ] || ! jq -e . >/dev/null 2>&1 <<<"$result"; then
  emit_empty "reducer produced no valid output"
fi

# Annotate the common real cases with an honest note (still exit 0, data is valid).
mcount="$(jq -r '.members | length' <<<"$result")"
ccost="$(jq -r '.conductor_cost_usd' <<<"$result")"
if [ "$mcount" -eq 0 ]; then
  if [ "$ccost" = "0" ] || [ "$ccost" = "null" ]; then
    result="$(jq '.note = "no traces for session '"$SID"'"' <<<"$result")"
  else
    result="$(jq '.note = "conductor-only: no member (subagent) traces for this session"' <<<"$result")"
  fi
fi

printf '%s\n' "$result"
