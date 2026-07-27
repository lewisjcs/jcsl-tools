# Smith Eval Gate — `/smith --validate <proposal>` operating procedure

Loaded on demand by `smith/SKILL.md` when Josh asks to validate a Kiln proposal. The gate is
**on-demand only** — the morning briefing never triggers it. It validates a proposal that touches
Kiln **routing/gate logic** (`SKILL.md`/`lanes.md`/`gates.md`/`scenarios.md`) by live-replaying the
19-scenario harness against the *proposed* prose, then labels it.

## Inputs
- `<proposal>`: a git branch or a unified-diff file in the source repo carrying the candidate edit.
- The proposed prose files (the branch's versions of the fire skill files) and the current
  (baseline) prose files — the gate replays both sides under the same scenario input.
- `K`: the per-side replay count (majority sample size); see `smith-eval-gate.sh majority`.
- The gold fixtures `plugins/kiln/skills/fire/eval/expected/*.json` and `thresholds.yaml` — consulted
  only by the periodic calibration anchor, not by this per-proposal gate.

## Step 0 — Anti-gaming pre-check (hard gate, before any replay)
Produce the proposal's unified diff and run:
`bash ${CLAUDE_PLUGIN_ROOT}/skills/smith/smith-eval-gate.sh anti-gaming <diff-file>`
Exit 3 → **STOP**: the proposal edits a fixture/scenario. Report REJECTED (anti-gaming) and do not replay.

## Step 1 — Per-scenario replay (19 scenarios)
For each `scenarios/NN-*.md`, run the two-sided differential procedure below. Each side's replay is
produced by the mode-table dispatch (the table's "PROPOSED prose" language names whichever prose is
loaded for the side currently being replayed — the current prose for the baseline side, the proposed
prose for the proposal side):

1. **Resolve the baseline majority.** Compute
   `bash ${CLAUDE_PLUGIN_ROOT}/skills/smith/smith-eval-gate.sh cache-key <scenario> <K> <current-prose-files>`,
   then `cache-path <cache-dir> <key>`. If that path already exists, read it as the baseline
   majority. Otherwise dispatch `K` conductor-role replays against the **current** prose per the
   mode table, then run `majority <marker-file>...` on the `K` raw marker files directly (`majority`
   canonicalizes each marker internally — do not pre-run `canon` on them). Its output is the
   canonical majority line; write it to the cache path (a one-byte prose change yields a different
   key, so a Kiln HEAD bump auto-invalidates the cache).
2. **Produce the proposal majority.** Dispatch `K` conductor-role replays against the **proposed**
   prose (same `## Input`, same mode, same dispatch contract), then run `majority` on those `K` raw
   marker files directly to get the proposal's canonical majority line. The proposal side is never
   cached.
3. **Compare the two majorities.**
   `bash ${CLAUDE_PLUGIN_ROOT}/skills/smith/smith-eval-gate.sh diff-pair <baseline-majority-file> <proposal-majority-file>`:
   - `SAME` (exit 0) → the scenario is unchanged; no regression.
   - `CHANGED: <field>=<base>→<prop>[; …]` (exit 1) → record the named fields; the scenario changed.
   - `UNSTABLE-side: <baseline|proposal>` (exit 4) → the `K`-majority did not resolve on that side;
     record `UNSTABLE(<baseline|proposal>)`, carrying the side. This is a runner/stability signal,
     distinct from a regression, and its meaning depends on which side went unstable:
     - `UNSTABLE-side: proposal` is **always** a finding — the proposed prose failed to resolve a
       majority under the same input the baseline resolved.
     - `UNSTABLE-side: baseline` is a finding **only if** Task 6 did not already classify that
       scenario's baseline as unstable. A scenario Task 6 already knew was non-discriminating at the
       baseline is a sentinel and is handled by point 4 below (skip), not flagged here — a cached
       baseline majority that is chronically unstable must not re-flag every future proposal as a
       "new" instability.
4. **Skip sentinel scenarios.** Any scenario Task 6 classified as a non-discriminating sentinel
   (one whose canonical outcome cannot move under any prose change) is excluded from the
   differential verdict — list it excluded-by-name with its reason rather than replaying it.

Exit 2 (unparseable marker — `majority`'s internal per-marker canonicalization fails loud) is a
**runner error — FAIL the scenario loud**, never count it as `SAME` or absorb it into a majority.

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

## Step 2 — Differential labeling
Before replay, the executor states the proposal's **intended-change set** — the scenario(s) the
proposal means to change and how (e.g. "proposal B intends to change scenario 01's dispatch path").
A `CHANGED` result there is the point, not a regression.

The verdict is computed directly from the per-scenario `diff-pair` outcomes (Step 1) plus the
intended-change set — **not** from the `tally` subcommand, which compares against gold and is the
periodic calibration-anchor path, not this per-proposal gate:
- **RECOMMENDED** iff every in-scope, non-sentinel scenario is `SAME`, OR every `CHANGED` scenario
  is in the intended-change set.
- **OBSERVATION-ONLY** if any scenario outside the intended-change set is `CHANGED` (an unintended
  change), or any scenario is a finding-grade `UNSTABLE` per Step 1 point 3's side rule (a proposal
  side is always a finding; a baseline side is a finding only when Task 6 did not already classify
  that scenario's baseline as unstable). Name the scenario, the changed fields, or the unstable side
  in the report.

State the intended-change set explicitly in the report so "the proposal changed the thing it meant
to" is never confused with "the proposal broke something."

## Step 3 — Report (with self-accounting)
Emit:
```
## Smith eval gate — <proposal> vs Kiln <version/commit>
Verdict: <RECOMMENDED | OBSERVATION-ONLY>
- <NN-name>: SAME | CHANGED(<field>=<base>→<prop>[; …]) | UNSTABLE(<baseline|proposal>) | SENTINEL-excluded (<reason>)
  (one line per scenario)
Baseline: <cache hit | K replays> @ <prose sha>
Intended changes: <set>
Unintended regressions: <none | list>
Gate cost: ≈ <in-scope scenarios> × 2 sides × K, minus baseline cache hits   (self-accounting — guardrail #5)
Gated against: Kiln <version> @ <commit sha>   (staleness — guardrail #4)
```

## Guardrails (state they hold)
- **External anchor:** the label comes from the live replay, never self-graded reasoning.
- **Anti-gaming:** Step 0 rejects any fixture-touching proposal before replay.
- **Staleness:** the report records the Kiln version/commit gated against.
- **Cost-bounded:** on-demand only; the report self-accounts its token cost.
