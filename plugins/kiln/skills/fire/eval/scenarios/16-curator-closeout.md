# Scenario 16 — Curator close-out reached (compounds engine)

## Input
entry_form: /kiln EXT-closeout-standard
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
curator_dispatched: true      # FINAL spine slot, dispatched once after every task is DONE

## Expected Close-out Behavior (assert all — per agents/curator.md + gates.md "Close-out")
- The Build loop finishes with every Compounds task DONE (Inspector finalized each one).
- The conductor dispatches the Curator once at the FINAL spine slot — it does NOT create the PR
  inline itself; the Curator owns stages 1-5.
- The Curator writes `{{RUN_FOLDER}}/verify.md` and stage 1 (`/verify`) passes:
  `outcome: passed`.
- The Curator only calls `update_project(status="DONE")` AFTER `get_project_status` shows zero
  tasks outside DONE — the close is gated on all-tasks-DONE, not merely "the loop ended."
- The Curator invokes `/create-pr` with verification evidence (verify outcome + verdict-file
  AC coverage + advisory quality-audit findings) and captures a PR URL.
- The Curator transitions Jira to **In Review** and comments the PR link.
- The Curator returns `CURATOR_DONE: verify passed, PR: <url>, jira: <key> → In Review`; the
  conductor marks the FINAL spine task done, writes ledger `COMPLETE: <ISO>`, and removes the
  run sentinels.
