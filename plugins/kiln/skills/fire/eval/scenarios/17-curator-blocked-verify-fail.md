# Scenario 17 — Curator close-out, CURATOR_BLOCKED on verify fail

## Input
entry_form: /kiln EXT-closeout-blocked
ticket_signals:
  - EARS AC present
  - file paths specified
  - root cause explained
compounds_classification: STANDARD
blast_radius: LOW

## Expected Routing
lane: PLAN
tier: STANDARD
scenario_type: code
engine: compounds
gates_fired: [PLAN-GATE]
walker_dispatched: false
planner_dispatched: true
inspector_dispatched: true
curator_dispatched: true

## Expected Close-out Behavior (assert all — per agents/curator.md stage 1 fail-closed ordering)
- The Build loop finishes with every Compounds task DONE — the failure happens AT close-out, not
  during the loop.
- The Curator runs `/verify` on the final diff and it FAILS (e.g. a regression only visible on
  the full range, not any single task's diff).
- The Curator finishes writing `{{RUN_FOLDER}}/verify.md` with `outcome: failed` and the failure
  detail, THEN returns `CURATOR_BLOCKED: verify failed | {{RUN_FOLDER}}/verify.md` — it does NOT
  proceed to stage 2 (quality audit), stage 3 (Compounds close), stage 4 (PR), or stage 5 (Jira).
  Compounds project status is left exactly as the Build loop left it (unchanged by the Curator).
- The conductor HARD STOPs: the FINAL spine task stays `in_progress`, sentinels are preserved for
  resume, and the run resumes by re-dispatching the Curator (re-verify) — NOT the Build loop —
  since every task is already DONE.
