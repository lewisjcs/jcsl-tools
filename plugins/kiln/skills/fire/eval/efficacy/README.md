# Kiln Efficacy Calibration (§6d) — Maintainer-Private

Reads engine-tagged `progress.md` ledgers and reports cost + accuracy split by engine, so the
maintainer can answer the founding question: **does leaning on Compounds cut cost while holding
accuracy?**

## What it reads
- `projects/active/*/kiln/progress.md` — the `ENGINE: <compounds|native>` header and per-task
  `DONE: task N | engine: <e> | <ISO>` lines the conductor writes.

## What it reports
- Run and task counts split by engine (from the ledger — deterministic).
- Cost (tokens/turns): a **manual input** — the ledger does not hold token counts; pull them from
  the session transcript or LangFuse and attribute by the run's `ENGINE` header.
- Accuracy: Inspector pass-rate is derivable from retained `verdict-N.md` files; post-merge defect
  signal is a manual input.

## Why it is NOT a ship gate
Per design D6, this is captured as candidate input to statblock's deferred Increment E (make
`rigor` checkable) — a private maintainer regression, not enforcement machinery. The script exits
0 unconditionally; it never blocks a run or a merge. Building an enforcement gate here would be
"cruft that lies about reality" before the data justifies it.

## Run
`bash synthesize-efficacy.sh <workspace-root>`
