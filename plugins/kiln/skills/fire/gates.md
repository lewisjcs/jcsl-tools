# Kiln Gates (P2.1)

Loaded on-demand. Each gate is evaluated by the CONDUCTOR reading a member's typed return field —
never the worker grading itself. SPEC-GATE (P2.1) pairs with the Designer and fires on the DESIGN/RESEARCH
lanes; PLAN and TASK gates are unchanged.

## Gate table

| Gate | Fires when | Reads | Pass condition |
|---|---|---|---|
| **SPEC-GATE** | after Designer, before Planner — on ANY DESIGN/RESEARCH run under a pausing flow-style | `spec-draft.md` summary | user types explicit approval |
| **PLAN-GATE** | after Planner, before first Crafter — all STANDARD | `plan.md` (+ `walkthrough.md` on HIGH blast) | user types explicit approval |
| **TASK-GATE** | after each Inspector — blocks on MEDIUM or HIGH blast | `verdict-N.md` typed fields | `spec: ✅` AND `quality: approved` |

On reject: SPEC-GATE re-dispatches the Designer with the feedback and re-presents at SPEC-GATE;
PLAN-GATE re-dispatches the Planner with the feedback and re-presents at PLAN-GATE. Neither writes
`approved` nor advances until the re-presented artifact is explicitly approved.

**SPEC-GATE fires on lane, not blast.** Blast radius is Planner-derived (Compounds classify), which
runs AFTER SPEC-GATE — so blast is unknown at SPEC-GATE time. SPEC-GATE therefore fires whenever a
Designer synthesized a spec (any DESIGN/RESEARCH run) under a pausing flow-style: a ticket sparse
enough to need the Designer is high-uncertainty by definition. The Designer's `compounds impact`
grounding note is advisory only — the authoritative blast signal is still the Planner's.

## Tier × blast behavior (Inspector-runs vs gate-blocks are SEPARATE decisions)

- **TRIVIAL** (Compounds score 6–9): no gates, NO Inspector. Single Crafter dispatch; the **Crafter** self-finalizes (the conductor cannot call a Compounds verb — the guard forbids it; the Crafter holds the grant). By engine: **compounds** → the `start_trivial` terminal `create_project(status="DONE")` IS the finalize (no project/task exists yet, so `implement_task`/`update_task` do not apply); **native** → no Compounds project exists, so the commit is the finalize (no Compounds verb).

For STANDARD, blast selects gate behavior on a three-tier scale. **Walker and blocking are independent dials:** LOW→MEDIUM adds *blocking*; MEDIUM→HIGH adds *the Walker*.

| Blast | Walker @ PLAN-GATE | Inspector | TASK-GATE | Fix loop |
|---|---|---|---|---|
| **LOW** | no | lightweight adequacy (static, relayed verify-model) | non-blocking — Inspector finalizes regardless of verdict, findings advisory | none |
| **MEDIUM** | no | full adequacy rigor | blocks: `spec: ✅` AND `quality: approved` | cap 2 → escalate (revert task commits, HARD STOP) |
| **HIGH** | yes | full adequacy rigor | blocks: `spec: ✅` AND `quality: approved` | cap 2 → escalate (revert task commits, HARD STOP) |

- **LOW blast** never blocks under any flow-style; the Inspector finalizes every task (compounds → `implement_task_finalize`; native → `update_task`) so a LOW task is never left un-finalized (no rot-to-TODO).
- **MEDIUM blast** is the middle rung: the Inspector runs full rigor and TASK-GATE blocks exactly as HIGH does, but the Walker does NOT run — there is no whole-plan walkthrough. This is the defined home for a Planner "mid" classification that previously fell through the binary table.
- **HIGH blast** adds the Walker at PLAN-GATE on top of MEDIUM's blocking discipline.

**Test-adequacy is the relocated guardrail (design D3):** with red-green dropped, the Inspector's `verify` asserts the tests cover each AC, are not trivially-passing, and exercise the changed path. An empty or tautological test set is a Critical finding.

## Flow-styles (configurable gate pausing)

| Flow-style | SPEC-GATE | PLAN-GATE | TASK-GATE |
|---|---|---|---|
| `guided` (default) | pause for explicit approval | pause for explicit approval | block on findings (MEDIUM or HIGH blast) |
| `planning_gate` | pause | pause | auto-advance on clean verdict |
| `implementation_gate` | auto-proceed | auto-proceed | block on findings (MEDIUM or HIGH blast) |
| `hands_free` | auto-proceed | auto-proceed | auto-advance; escalate only on 2× fix-loop failure |

**Precedence — tier×blast is authoritative over flow-style.** The tier×blast rules above decide
*whether TASK-GATE fires and blocks at all*: a LOW-blast TASK-GATE is non-blocking under EVERY
flow-style, while MEDIUM and HIGH block under every flow-style. The flow-style column only dials
whether a gate that already fires *pauses* for human input — it never makes a LOW-blast TASK-GATE
block, and never stops a MEDIUM/HIGH TASK-GATE from blocking. So the `guided`/`implementation_gate`
"block on findings" cells mean "block on findings **on MEDIUM or HIGH blast**" (annotated above); on
LOW blast they resolve to auto-advance regardless of flow-style.

Default `guided`. Owner sets per-run (`/kiln <KEY> --flow hands_free`). Never pass `flow_style` to Compounds unless the owner explicitly set one.

## Context-preservation yield (separate axis from flow-style)

This is orthogonal to the tier×blast precedence above: tier×blast decides *whether a gate blocks*;
this decides *whether the conductor pauses to hand off before its own context grows unsafe*. It fires
under EVERY flow-style, including `hands_free`.

**Trigger.** The workspace reset-nudge Stop hook fires once (~100 assistant turns) and injects a
"invoke the context-economy skill lever router" message into the conductor's context. On seeing that
message, the conductor records `NUDGE-SEEN: <ISO>` in `progress.md` (once per run).

**Action.** While `NUDGE-SEEN` is unset, flow-style governs gates normally. Once it is set, at the
**next gate boundary** (SPEC-GATE / PLAN-GATE / a task's TASK-GATE) the conductor performs a **forced
yield regardless of flow-style**: it invokes `context-economy:handoff` to write
`{{RUN_FOLDER}}/handoff.md` (narrative reasoning; it references `progress.md` for task state rather
than duplicating it), then ends its turn with a status line naming the checkpoint phase/task and
instructing the user to `/clear` and re-invoke `/kiln <run-id>`. It does NOT auto-`/clear`.

**Why the next gate, not immediately:** gate boundaries are clean resume points; a mid-task yield
resumes worse. **Edge case:** if the run reaches `COMPLETE` before the next gate after the nudge, it
finishes normally — there is nothing to preserve once the run is done.

## Generator-Critic separation (AIS RFC mandate)

Inspector and Walker receive ONLY the output artifact (brief/report/diff, or plan/spec) — never the
Crafter's or author's reasoning trace. The conductor branches mechanically on their typed return field.

## Close-out (the Curator, FINAL slot)

After the Build loop, the conductor dispatches the **Curator** once (it is not a gate that blocks
mid-run — it is the terminal phase). The Curator runs `/verify` on the final diff, asserts all
Compounds tasks are DONE, closes the project (`update_project(status="DONE")`; skipped on the native
engine), creates the PR with verification evidence, and transitions Jira to In Review. The conductor
branches on its typed return:
- `CURATOR_DONE` → finalize the run (spine FINAL done, ledger `COMPLETE:`, remove sentinels).
- `CURATOR_BLOCKED` → HARD STOP, sentinels preserved for resume (mirrors MEDIUM/HIGH-blast TASK-GATE
  escalation). The Curator halts at the first failing stage; stages before it may have completed
  (verify.md is the source of truth for what was done — e.g. a stage-4/5 failure means Compounds is
  already closed and possibly a PR exists). Resume continues from the failed stage.

Fail-closed ordering: verify → close → PR → Jira. No side-effect runs on an unverified piece.
