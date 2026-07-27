# Smith Eval Gate — `/smith --validate <proposal>` operating procedure

Loaded on demand by `smith/SKILL.md` when Josh asks to validate a Kiln proposal. The gate is
**on-demand only** — the morning briefing never triggers it. It validates a proposal that touches
Kiln **routing/gate logic** (`SKILL.md`/`lanes.md`/`gates.md`/`scenarios.md`) by live-replaying the
19-scenario harness against the *proposed* prose, then labels it.

## Inputs
- `<proposal>`: a git branch or a unified-diff file in the source repo carrying the candidate edit.
- The proposed prose files (the branch's versions of the fire skill files).
- The gold fixtures `plugins/kiln/skills/fire/eval/expected/*.json` and `thresholds.yaml`.

## Step 0 — Anti-gaming pre-check (hard gate, before any replay)
Produce the proposal's unified diff and run:
`bash ${CLAUDE_PLUGIN_ROOT}/skills/smith/smith-eval-gate.sh anti-gaming <diff-file>`
Exit 3 → **STOP**: the proposal edits a fixture/scenario. Report REJECTED (anti-gaming) and do not replay.

## Step 1 — Per-scenario replay (19 scenarios)
For each `scenarios/NN-*.md`, run one of three modes (see the table). Capture the conductor's
`kiln-routing` marker (routing modes) or the observed behavior (execution/offline modes) to a file,
then diff:
`bash ${CLAUDE_PLUGIN_ROOT}/skills/smith/smith-eval-gate.sh diff <marker-file> <expected/NN-*.json>`
Record `NN-name PASS` / `NN-name FAIL` to a results file. Exit 2 (unparseable marker) is a **runner
error — FAIL the scenario loud**, never count it as pass.

### Mode table
| Scenarios | Mode | How |
|---|---|---|
| 01–08, 10–12, 19 | **routing-halt** | Dispatch a conductor-role agent loaded with the PROPOSED prose + the scenario `## Input`; instruct it to run through Verb 2, emit the `kiln-routing` marker, and HALT at the routing checkpoint (no member dispatch). Diff the marker. |
| 13–18 | **execution-observed** | Same dispatch, but drive until the fixture's asserted execution field is observable (`engine_behavior`, finalize verb, verify-fail-block, native-skip) — then halt. Default: "run until the asserted behavior is observable." These are the expensive minority. |
| 09 | **offline** | Do NOT live-replay. Run `bash plugins/kiln/hooks/test-kiln-guards.sh`; PASS iff it exits 0 (asserts conductor-denied + member-allowed). |

**Conductor-role dispatch contract (routing/execution modes):** the agent is told it is playing the
Kiln conductor for calibration; it receives the proposed prose file contents, the scenario `## Input`
(entry form, ticket signals, `compounds_classification`, `blast_radius`), and the instruction to emit
the marker and halt. It must NOT write source, open PRs, or touch the live workspace — it is a dry
replay. It reports the marker text back as its result.

The dispatch prompt MUST carry these three replay rules verbatim (the pilot failed without them —
they fix serialization drift, not routing judgment; the routing decision stays the agent's to derive
from the proposed prose):
1. **Marker grammar is the proposed `SKILL.md` Verb 2 spec** ("Serialization is fixed" block): lowercase
   closed member vocabulary `{crafter, planner, inspector, walker, designer, scout, curator}`; `drafter`
   never listed; `agents_skipped` = the lane's eligible roster minus dispatched, not every member;
   `gates_fired` enumerates every gate the run fires that is determinable at the checkpoint (a
   DESIGN/RESEARCH run lists `[SPEC-GATE, PLAN-GATE]` even while paused at SPEC-GATE), a non-blocking
   LOW TASK-GATE is not "fired". Emit the marker with exactly these keys and forms — the gate compares
   by exact string.
2. **The supplied `compounds_classification`/`blast_radius` stand in for Compounds' classify output** (the
   harness can't run Compounds). On a build lane (TRIVIAL/PLAN/EXECUTE) where tier/blast are deterministic
   at the routing checkpoint, consume them as that dependency's result and map through the proposed prose
   (a `TRIVIAL` classification routes the fast-path per the proposed `gates.md`; if the proposal broke that
   rule, the marker will mis-route and the scenario correctly FAILs). Do NOT invent a classification the
   `## Input` did not supply.
3. **On design-front lanes (DESIGN/RESEARCH), `tier`/`blast_radius`/`scenario_type` are `N/A` at the
   routing checkpoint regardless of any supplied `compounds_classification`/`blast_radius`** — the Designer
   has not synthesized targets and the Planner derives blast only after SPEC-GATE, so those hints are not
   yet knowable at routing (the `eval/README.md` deterministic-at-checkpoint rule). The supplied values are
   a distractor here, not the answer.

## Step 2 — Tally + label
`bash ${CLAUDE_PLUGIN_ROOT}/skills/smith/smith-eval-gate.sh tally <results-file> <thresholds.yaml>`
- `RECOMMENDED` (exit 0): all 19 met their bar.
- `OBSERVATION-ONLY` (exit 1): names each regressed scenario.

## Step 3 — Report (with self-accounting)
Emit:
```
## Smith eval gate — <proposal> vs Kiln <version/commit>
Verdict: <RECOMMENDED | OBSERVATION-ONLY>
- <NN-name>: PASS/FAIL[ — <field> expected=x got=y]   (one line per scenario)
Regressions: <none | list>
Gate cost: ≈ <tokens/$ for the 19 replays>   (self-accounting — guardrail #5)
Gated against: Kiln <version> @ <commit sha>   (staleness — guardrail #4)
```

## Guardrails (state they hold)
- **External anchor:** the label comes from the live replay, never self-graded reasoning.
- **Anti-gaming:** Step 0 rejects any fixture-touching proposal before replay.
- **Staleness:** the report records the Kiln version/commit gated against.
- **Cost-bounded:** on-demand only; the report self-accounts its token cost.
