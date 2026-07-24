#!/usr/bin/env bash
# Fake ccusage for tests. Emits a fixed session report; ignores args.
# Schema-pinned to real ccusage v20 (`npx ccusage@latest session --json`):
# top-level `.session[]` array, per-row `.period` (session UUID) and
# `.totalCost` — NOT `.sessions[].sessionId`/`.costUSD`. Re-verify against
# a real ccusage run if this ever needs to change.
cat <<'JSON'
{"session":[{"period":"sess-clean-123","totalCost":1.23},
            {"period":"sess-other-999","totalCost":9.99}],
 "totals":{}}
JSON
