# Scenario 06 — Wrong Repo (drift-check halt)

## Input
entry_form: /kiln AIS-38
ticket_signals:
  - EARS AC present
  - file paths specified
  - root cause explained
  - named packages: simple-git, fast-xml-parser, tar
compounds_classification: TRIVIAL
blast_radius: N/A

## Repo State
Simulated: current repo is `shopify-sync-app` (Remix frontend).
`simple-git` is absent from `package.json`.
`serverless.yml` does not exist.
`fast-xml-parser` is present but already at a safe version (5.2.5).

## Expected Routing
lane: HALT-AND-ASK
tier: N/A — halted before any Compounds call
scenario_type: N/A
gates_fired: []
walker_dispatched: false
planner_dispatched: false
inspector_dispatched: false

## Why this halts (v2 behavior)
The drift-check's local file verification (lanes.md) fails: the ticket's claimed artifacts
(`simple-git`, `serverless.yml`) do not exist in this repo, so the named work cannot be the
work in front of us. The conductor HALTS-AND-ASKS before dispatching any member rather than
mis-route into a repo the ticket was not written against. (In v1 this was an ARTIFACT-GATE
abort; v2 folds artifact verification into the drift-check.)
