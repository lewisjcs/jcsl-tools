#!/usr/bin/env bash
# Fake ccusage for tests. Emits a fixed session report; ignores args.
cat <<'JSON'
{"sessions":[{"sessionId":"sess-clean-123","costUSD":1.23},
             {"sessionId":"sess-other-999","costUSD":9.99}]}
JSON
