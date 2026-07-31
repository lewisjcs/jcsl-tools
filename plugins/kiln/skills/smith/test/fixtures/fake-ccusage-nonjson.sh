#!/usr/bin/env bash
# Fake ccusage that prints a human-readable table instead of JSON — reproduces
# what a misconfigured SMITH_CCUSAGE override (missing `session --json`) or a
# genuinely broken ccusage install would emit. Used to regression-test that
# the harvester's cost-join degrades to a null cost note instead of crashing
# the whole harvest under `set -euo pipefail` when jq fails to parse it.
cat <<'TABLE'
  Session   Cost (USD)
  --------  ----------
  abc123    $1.23
TABLE
