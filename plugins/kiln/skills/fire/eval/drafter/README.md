# Kiln Drafter eval

Executable ship-gate for the Drafter's deterministic core (EARS-lint, reconcile, ledger).
Unlike the routing efficacy harness (human-run, never fails), this runner **exits non-zero on
any mismatch** — run it before every commit touching `scripts/drafter/`.

Run: `bash kiln-drafter-eval.sh`

Scenarios calibrate against `expected/drafter-*.json` (gold-first; never retrofit expected to
match a regression — see the calibration ship-gate discipline).
