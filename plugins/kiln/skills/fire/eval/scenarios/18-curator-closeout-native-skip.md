# Scenario 18 — Curator close-out, native engine Compounds-close skip

## Input
entry_form: /kiln EXT-closeout-native path/to/spec.md
ticket_signals:
  - EARS AC present, file paths specified
  - file targets are under plugins/**/skills/ (a SKILL.md)
compounds_classification: STANDARD
blast_radius: LOW

## Expected Routing
lane: PLAN
tier: STANDARD
scenario_type: tool-authoring
engine: native
gates_fired: [PLAN-GATE]
walker_dispatched: false
planner_dispatched: true
inspector_dispatched: true
curator_dispatched: true

## Expected Close-out Behavior (assert all — per agents/curator.md stage 3 native branch)
- `{{ENGINE}}` == native and `{{COMPOUNDS_PROJECT}}` == none for this dispatch (native runs
  finalize via commit only — there is no Compounds project to close).
- The Curator does NOT call `get_project_status` or `update_project` — stage 3 is skipped
  entirely; it records `engine: native — no Compounds project` in `verify.md`'s `## Compounds`
  section (`closed: n/a`) and goes straight to stage 4.
- Stage 4 (`/create-pr`) and stage 5 (Jira transition to In Review) run identically to the
  compounds-engine case (scenario 16) — the native skip is scoped ONLY to the Compounds-close
  stage, not to PR/Jira.
- The Curator returns `CURATOR_DONE: verify passed, PR: <url>, jira: <key> → In Review`.
