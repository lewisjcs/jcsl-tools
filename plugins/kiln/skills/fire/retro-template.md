# Kiln Retro Template

Load-on-demand template for the retro generation block (BE-008).
Choose **TERSE STUB** when the run was clean; choose **FULL PROSE** when friction was detected.

---

<!-- TERSE STUB -->
## Terse Stub Skeleton

*Use when: no fix loops, no corrections, no escalations, no routing mismatch.*

## Run Summary

Entry: `{entry_form}` | Routing: `{routing}` | Tier: `{tier}` | Tasks: `{task_count}`

## Routing

`{routing}` → tier `{tier}` · blast radius `{blast_radius}`

## Outcome

`{status}` · PR: `{pr_url}`

<!-- FULL PROSE -->

---

## Full Prose Skeleton

*Use when: fix loops detected (`fix_loop_count > 0`), corrections present, escalations hit, or routing mismatch observed.*

## What Went Smoothly

<!-- Fill with what ran without friction: clean task sequencing, accurate routing, fast plan-gate approval, etc. -->

## What Was Harder

<!-- Fill with friction points: fix loop triggers, ambiguous specs, tool failures, slow approvals, etc. -->

## Workflow Observations

<!-- Fill with systemic notes: patterns across tasks, recurring correction types, model-routing accuracy, blast-radius calibration. -->

## Corrections Scorecard

| # | Description | Phase | Resolved |
|---|-------------|-------|----------|
| 1 | {description} | {phase} | {yes/no} |

---

## Auto-Seed Field List

Fields the orchestrator extracts before filling either skeleton.

### From `progress.md`

| Field | Source key | Values |
|-------|-----------|--------|
| entry_form | `entry_form` | `TICKET` / `RAW_IDEA` / `TICKET_WITH_PLAN` |
| routing | `routing` | `ORIENT` / `REFINE` |
| tier | `tier` | `TRIVIAL` / `STANDARD` |
| blast_radius | `blast_radius` | `LOW` / `HIGH` / `N/A` |
| plan_gate_approved_at | `plan_gate_approved_at` | ISO timestamp |
| task_count | `task_count` | integer |
| fix_loop_count | `fix_loop_count` | integer |
| escalation_count | `escalation_count` | integer |
| user_correction_count | `user_correction_count` | integer (count of `USER-CORRECTION:` ledger entries) |
| pr_url | `pr_url` | from `COMPLETE:` ledger entry |

### From `verdict-N.md` files (aggregated across all tasks)

| Field | Aggregation |
|-------|-------------|
| critical_findings_total | sum of `critical` counts across all verdict files |
| important_findings_total | sum of `important` counts |
| minor_findings_total | sum of `minor` counts |
