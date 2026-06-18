# Scenario 06 — Wrong Repo Abort

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
mode: ORIENT
tier: N/A — aborted before Compounds call
gates_fired: [ARTIFACT-GATE]
refiner_dispatched: false
planner_dispatched: false
