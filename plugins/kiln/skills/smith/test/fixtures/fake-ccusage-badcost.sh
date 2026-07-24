#!/usr/bin/env bash
# Fake ccusage returning a non-numeric costUSD (malformed/unexpected schema).
# Used to regression-test the guard: --argjson cost_usd must never receive
# non-numeric input, since that would crash the final jq -n write.
cat <<'JSON'
{"sessions":[{"sessionId":"sess-clean-123","costUSD":"N/A"}]}
JSON
