#!/usr/bin/env bash
# Fake ccusage returning a non-numeric totalCost (malformed/unexpected value).
# Used to regression-test the guard: --argjson cost_usd must never receive
# non-numeric input, since that would crash the final jq -n write.
# Schema-pinned to real ccusage v20: `.session[].period` / `.totalCost`.
cat <<'JSON'
{"session":[{"period":"sess-clean-123","totalCost":"N/A"}],
 "totals":{}}
JSON
