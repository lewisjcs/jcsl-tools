# Kiln Lanes (P2.1)

Loaded on-demand at the classify verb. Implements EXECUTE / PLAN / TRIVIAL / RESUME / RESEARCH / DESIGN.
RESEARCH and DESIGN lanes (Scout, Designer, SPEC-GATE) are now live as of P2.1 — a sparse/partial ticket
routes into RESEARCH/DESIGN instead of halting.

## Entry detection (mechanical first, prefix-agnostic `[A-Z]+-\d+`)

| Entry | Detected as | Lane | Members |
|---|---|---|---|
| `<KEY> <path>.md` numbered tasks + file targets | impl-plan | EXECUTE | drift-check → Planner(register) → Build |
| `<KEY> <path>.md` EARS AC + paths, no tasks | spec | PLAN | Planner → Build |
| `<KEY>` ticket: EARS AC + paths + root cause | complete | PLAN | Planner → Build |
| `<KEY>` ticket: some AC, no paths | partial | **DESIGN** | Designer → SPEC-GATE → Planner → Build |
| `<KEY>` ticket: title-only / thin / epic-only | sparse | **RESEARCH** | Scout → Designer → SPEC-GATE → Planner → Build |
| Quoted string, no ticket | net-new | **DESIGN** | Designer → SPEC-GATE → Planner → Build (local kebab-slug run-id; NO Jira offer — P2.2) |
| File = design doc (`## Approaches`/`## Architecture`, no AC) | design-doc | **DESIGN (mid-flow)** | Designer enters with design.md pre-supplied → convert → SPEC-GATE → Planner → Build |
| re-invoke with active run folder + ledger | resume | RESUME | read ledger → Build from first incomplete |
| NL feedback phrasing referencing the PR ("got comments/feedback on the PR", "reviewer left notes", "address the review comments on the PR") | review-nl | **→ /process-review-feedback** | (delegated — fire is one caller) |
| A PR URL or `#<number>` (+ repo) | review-direct | **→ /process-review-feedback** | (delegated) |
| `<KEY>` ticket In Review + open PR with unresolved threads | review-pending | **→ /process-review-feedback** | (delegated) |
| `<KEY> --review` explicit flag | review-forced | **→ /process-review-feedback** | (delegated) |
| file shape none-of-the-above | — | HALT-AND-ASK | (don't guess) |

## Doc-shape detection (borrowed from the Gauntlet tiebreaker)

- `## Tasks`/`## Steps` + per-task file targets → impl-plan.
- `When … shall` EARS + file paths, no task list → spec.
- `## Approaches`/`## Architecture`, no AC → design doc → **DESIGN (mid-flow)** — Designer enters with
  design.md pre-supplied and converts it, no HALT.
- none-of-the-above → halt-and-ask.

**Lane vs. scenario are ORTHOGONAL dimensions.** A design-doc ENTRY is an *input to convert into a spec*
→ routes DESIGN (mid-flow); it is NOT the `doc` *scenario* (which is when the change's DELIVERABLE is
prose to author). The `.md` shape of the ENTRY never by itself triggers the `doc` scenario — the scenario
is derived from the SYNTHESIZED file targets after the Designer runs, and may resolve to `code`,
`tool-authoring`, or `doc` depending on what those targets actually are.

## Stale-plan drift-check (EXECUTE only — never blindly run a prior-session plan)

1. **Jira drift:** scope changed, work already started, new blockers on the ticket.
2. **Local file verification:** named files still exist, functions still match, no PR already merged part of it.
- **Material drift → STOP and recommend re-planning** (executing a stale plan compounds wrong work across N tasks).
- Cosmetic/no drift → proceed.
- Also detect: plan is already a Compounds project with tasks (→ resume from task order) vs. a fresh markdown plan (→ Planner registers it + generates tasks).

## Cross-repo detection (EXT-7497 category — out of P1/P2 scope)

If the change spans multiple repos, DO NOT silently mis-route. Announce:
"This spans N repos — the Kiln runs one repo per run. This is N single-repo runs." Then stop and let the user choose.

## REVIEW entry (delegated to /process-review-feedback)

Review-feedback reception is NOT an in-conductor lane — it lives in the standalone
`/process-review-feedback` skill (gauntlet-style; the conductor is one caller). When fire detects a
PR-feedback entry (NL phrasing referencing the PR, a PR URL/`#number`, a ticket already In Review with
unresolved threads, or `--review`), it announces the REVIEW path and INVOKES that skill with the
resolved entry, then relays the skill's outcome. Fire does not re-implement PR resolution, the Sifter,
SIFT-GATE, routing, or the Finisher — the skill owns all of it. The run-folder/ledger convention is
shared, so a fire-authored run resumes seamlessly under the skill.

**Disambiguation:** "address the feedback" delegates here ONLY when an open PR with unresolved threads
exists; otherwise it is design feedback (SPEC-GATE re-dispatch), not this path.

**Precedence:** the REVIEW rows take precedence over the shape-based lane rows above them. When a PR-feedback signal is present (a PR URL/`#number`, NL phrasing referencing the PR, `--review`, or a `<KEY>` whose ticket is In Review with an open PR carrying unresolved threads), route to `/process-review-feedback` even if the same `<KEY>` would otherwise match a `complete`/`partial`/`spec` row on its body shape — an In-Review ticket with an open PR under review is past the build lanes.
