# Smith Eval Gate — `/smith --validate <proposal>` operating procedure

Loaded on demand by `smith/SKILL.md` when Josh asks to validate a Kiln proposal. The gate is
**on-demand only** — the morning briefing never triggers it. It validates a proposal that touches
Kiln **routing/gate logic** (`SKILL.md`/`lanes.md`/`gates.md`/`scenarios.md`) by live-replaying the
21-scenario harness against the *proposed* prose, then labels it.

## Inputs
- `<proposal>`: a git branch or a unified-diff file in the source repo carrying the candidate edit.
- The proposed prose files (the branch's versions of the fire skill files) and the current
  (baseline) prose files — the gate replays both sides under the same scenario input.
- `K`: the per-side replay count (majority sample size); see `smith-eval-gate.sh majority`.
- The gold fixtures `plugins/kiln/skills/fire/eval/expected/*.json` and `thresholds.yaml` — consulted
  by the periodic calibration anchor and by the one free-rider capture inside Step 1.1 (which reuses
  the anchor's `diff`-vs-gold on markers it already replayed). The per-proposal *routing verdict*
  (Steps 0–3) never reads gold; the free-ride is drift telemetry riding alongside it, not part of the
  verdict.

## Scope selection (cost lever — opt-out to `--full`)
The gate's cost is `in-scope scenarios × 2 sides × K`, so the executor picks the in-scope set before
replaying. This is an **executor judgment, not a mechanized step** — routing is holistic, so a
mechanical scoper would over-include to the full set in almost every real case (routing prose changes
rarely leave a routing scenario provably untouchable), buying no narrowing for real code and
maintenance cost. Apply this rule instead:

- **Scope to every scenario whose fixture or mode plausibly involves the edited section**, and **when
  unsure, include it.** The heuristic must over-include — a false `SAME` from an omitted scenario is a
  missed regression, the one failure this gate exists to prevent.
- A proposal that touches a routing section of `lanes.md`/`gates.md`/`SKILL.md`/`scenarios.md` scopes
  to **all routing scenarios** unless a specific scenario can be *shown* untouchable by the edit.
- A proposal that touches **no routing prose at all** scopes to empty — there is nothing to
  differentially test (and Step 0 anti-gaming still runs).
- `--full` **forces the entire non-sentinel set**, ignoring any narrowing — use it whenever the
  proposal's blast is uncertain or the edit spans multiple routing sections.

Whichever set you pick, **name the excluded scenarios in the report** (Step 3) — a scenario left out of
scope is a scenario not tested, and silent omission reads as coverage it did not have. Excluding a
scenario for cost is distinct from the coverage the gate structurally cannot provide at all (see
`## Scope — what a routing-marker diff can and cannot see`).

## Step -1 — Classify & route (before anything else)
Produce the proposal's unified diff and run:
`bash ${CLAUDE_PLUGIN_ROOT}/skills/smith/smith-eval-gate.sh classify <diff-file>`
The output is the dream-class set. Route to EVERY matching control (a diff often hits more than one):

| Class | Control | On finding |
|---|---|---|
| `routing-output` | the differential gate (Steps 0–3 below) | `CHANGED` outside the intended set → Observation-only |
| `guard-hook-code` | `bash plugins/kiln/hooks/test-kiln-guards.sh` (exit 0 = held) | non-zero → Observation-only: guard hook regressed |
| `guard-relaxation` | BOTH `bash …/smith-eval-gate.sh guard-relax <diff-file>` (exit 5 = flagged) AND `bash plugins/kiln/hooks/test-kiln-guards.sh` (exit 0 = held) | guard-relax exit 5 OR guard-hook non-zero → Observation-only: authorizes/enables a guard-forbidden action |
| `detection-perf` | NONE the marker can see — measure out-of-band (§ Two-part label) | never Recommended on the gate alone |
| `unsure` | none | annotate gate-blind; do NOT stamp Recommended |

**`guard-relaxation` pairs two controls, not one.** The `guard-relax` prose scan is a best-effort heuristic — it catches the phrasings it knows, but prose can always be reworded past a text matcher. So a `guard-relaxation` class routes to the guard's own regression test (`test-kiln-guards.sh`) *in addition to* the prose scan: the test asserts the runtime guard still denies inline conductor edits and allows member edits, which no rewording of the proposal's prose can evade. A `guard-relaxation` proposal is therefore never Recommended on a `guard-relax` exit 0 alone — the guard-hook test must also pass, and a genuine relaxation of the guard's own logic fails it. (This is the enforcement of the pairing the § Scope section describes for Verb-4 execution changes.)

**Conservative rule:** if the set contains `unsure`, or a class whose only control is out-of-band, the proposal is NEVER stamped Recommended on gate evidence alone — it is labeled gate-blind and handed to Josh with whatever out-of-band evidence exists. The routing gate stays a *routing* gate; this step is what stops a routing `SAME` from silently clearing a change the marker cannot see.

## Step 0 — Anti-gaming pre-check (hard gate, before any replay)
Produce the proposal's unified diff and run:
`bash ${CLAUDE_PLUGIN_ROOT}/skills/smith/smith-eval-gate.sh anti-gaming <diff-file>`
Exit 3 → **STOP**: the proposal edits a fixture/scenario. Report REJECTED (anti-gaming) and do not replay.

## Step 1 — Per-scenario replay (21 scenarios)
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
   **Free-rider calibration:** having resolved the baseline majority for this scenario, also record a gold-diff for it — identify the representative raw marker (the one whose `canon` equals the majority) and run `smith-eval-gate.sh diff <representative> <expected/NN-*.json>`, appending `NN: PASS|FAIL(<fields>)` to a `calibration-freeride.txt` for this run. This is the partial-coverage anchor (only in-scope scenarios); it is NOT a gate on the proposal — it is drift telemetry captured for free from replays already done. At the end of the `--validate` run, if no `full-21` record in `.last-calibration` already covers HEAD's routing prose, write the free-ride summary to the ledger as `<HEAD-sha> partial-freeride <YYYY-MM-DD> <reproduced>/<in-scope-count>` so the release-preflight floor can see this validation satisfied the covered routing sections (see the ledger's own header for the write contract).
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
| 01–08, 10–12, 19, 20–21 | **routing-halt** | Dispatch a conductor-role agent loaded with the PROPOSED prose + the scenario `## Input`; instruct it to run through Verb 2, emit the `kiln-routing` marker, and HALT at the routing checkpoint (no member dispatch). Diff the marker. 20–21 are the REVIEW lane: fire's first Verb-2 branch delegates to `/process-review-feedback` and emits its `lane: REVIEW` routing-halt marker (empty dispatch/skip lists, delegation `halt_reason`) — the same halt-at-Verb-2 shape as 06's HALT-AND-ASK, differing only in the lane value and an empty roster. |
| 13–18 | **execution-observed** | Same dispatch, but drive until the fixture's asserted execution field is observable (`engine_behavior`, finalize verb, verify-fail-block, native-skip) — then halt. Default: "run until the asserted behavior is observable." These are the expensive minority. |
| 09 | **offline** | Do NOT live-replay. Run `bash plugins/kiln/hooks/test-kiln-guards.sh`; PASS iff it exits 0 (asserts conductor-denied + member-allowed). |

Note: the REVIEW routing-halt (20–21) diffs only fire's OWN routing decision. The
`/process-review-feedback` internal flow (Sifter → SIFT-GATE → Finisher) it hands off to is NOT
marker-instrumented — no fixture asserts those agents/gates, and this harness cannot see them. That is
a known coverage gap, not a passing signal (see `## Scope — what a routing-marker diff can and cannot see`).

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
intended-change set — **not** from the `tally` subcommand, which compares against gold and is not
used by this per-proposal gate (see `## Calibration anchor` below, which reuses the gold `diff`
subcommand for periodic drift detection):
- **RECOMMENDED** iff every in-scope, non-sentinel scenario is `SAME`, OR every `CHANGED` scenario
  is in the intended-change set.
- **OBSERVATION-ONLY** if any scenario outside the intended-change set is `CHANGED` (an unintended
  change), or any scenario is a finding-grade `UNSTABLE` per Step 1 point 3's side rule (a proposal
  side is always a finding; a baseline side is a finding only when Task 6 did not already classify
  that scenario's baseline as unstable). Name the scenario, the changed fields, or the unstable side
  in the report.

**Aggregate across controls.** The verdict is the AND of every routed control: RECOMMENDED iff the routing-gate verdict is RECOMMENDED (per the rule above) AND every other routed control passed AND no class was left gate-blind-unproven. "Every other routed control passed" means: guard-hook `test-kiln-guards.sh` exit 0 wherever `guard-hook-code` OR `guard-relaxation` was routed (both classes require it), and `guard-relax` exit 0 wherever `guard-relaxation` was routed. Any single control's finding → OBSERVATION-ONLY, naming the control and the finding. A `detection-perf` or `unsure` class present with no confirming out-of-band evidence → gate-blind → not Recommended.

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

### Two-part label (when the proposal's value is not gate-visible)
When a class is `detection-perf` (the routing gate reports `SAME` but the intended win is invisible to the marker — see `## Scope`), the label MUST split what the gate proved from what it did not:
```
Proposal <id> — <intent>
  Safety:   [routing gate] SAME across in-scope scenarios — no routing regression
            [guard-relax]  clean — no guard-forbidden authorization added
  Efficacy: [out-of-band]  <metric> <before> → <after> on <real run id>  (a SAMPLE, not a benchmark)
  Class:    <classes>  (detection/perf is marker-blind — efficacy NOT gate-provable by design)
  Version:  gated against Kiln <commit>/<version>
  Label:    RECOMMENDED (safety proven by gate+guard-relax; efficacy measured out-of-band)
```
The efficacy line is a MEASUREMENT, never a pass/fail gate — state that verbatim so no reader mistakes it for a threshold. Record the Kiln version/commit gated against (staleness).

## Guardrails (state they hold)
- **External anchor:** the label comes from the live replay, never self-graded reasoning.
- **Anti-gaming:** Step 0 rejects any fixture-touching proposal before replay.
- **Staleness:** the report records the Kiln version/commit gated against.
- **Cost-bounded:** on-demand only; the report self-accounts its token cost.

## Scope — what a routing-marker diff can and cannot see
The gate diffs the `kiln-routing` marker, which the conductor emits at the **Verb 2 routing
checkpoint**. It therefore discriminates changes to **routing outputs** — lane, tier, blast_radius,
scenario_type, gates_fired, and the dispatch/skip roster. A `SAME` verdict means "routing output
unchanged," not "behavior unchanged." Two proposal classes are outside its reach — route them through
the matching control below rather than reading a routing `SAME` as a full clearance:

- **Verb-4 (Build-loop) execution-behavior changes.** How the conductor behaves *after* the routing
  checkpoint — e.g. whether it dispatches a member or applies an edit inline — is decided in the Build
  loop, after the marker is emitted, so the marker records the dispatch *plan*, not the runtime
  behavior. A proposal that relaxes the conductor guard in prose can gate `RECOMMENDED` while still
  changing execution. Pair such a proposal with `hooks/test-kiln-guards.sh` (the guard's own test) and
  a go-live-review; a routing `SAME` is not evidence the guard held.
- **Non-output detection/perf changes.** A change to *how fast* or *by what path* a routing decision is
  reached, with no change to the decision itself, yields a byte-identical marker → `SAME`. The gate
  correctly reports no regression but cannot confirm the intended speedup — that needs a separate
  measure (e.g. a wall-clock or step-count comparison), not this differential.

## Calibration anchor (periodic — NOT per-proposal)

This mode checks whether current Kiln prose still reproduces the gold fixtures
(`plugins/kiln/skills/fire/eval/expected/*.json`). It is a **drift detector**, run on a cadence,
never on a per-proposal basis — the differential gate's *verdict* (Steps 1–3 above) never reads gold.
Gold is consulted in exactly two places, and both are drift telemetry, never the routing verdict:
this calibration anchor, and the Step 1.1 free-rider (which reuses this section's `diff`-vs-gold on
baseline markers the gate already replayed). The free-ride is the partial-coverage version of what
this anchor does over the full 21.

**Trigger:** on-demand via `/smith --calibrate`. The version-bump case is governed entirely by the release-preflight floor below — it is NOT a blanket "run before every bump" rule.

**Release-preflight floor (the only mandatory trigger):** before a Kiln version bump, read the last-calibration commit from the ledger file `${CLAUDE_PLUGIN_ROOT}/skills/smith/.last-calibration` (the active record line's first field — see that file's header for the format), then check `git diff <that-commit>..HEAD -- plugins/kiln/skills/fire/{SKILL,lanes,gates,scenarios}.md`. If routing prose changed AND the ledger record does not cover it (a `full-21` record covers unconditionally; a `partial-freeride` record covers only the routing sections its in-scope scenarios exercised), the bump is BLOCKED until a full-21 `--calibrate` runs — which rewrites `.last-calibration` with the new HEAD, `full-21`, and the drift ratio (also recorded in the PR). This makes the anchor fire exactly when drift risk is introduced, and never on idle weeks — an unrun anchor is strictly worse than none. The ledger is the single source of truth for "since when": if `.last-calibration` is absent or unreadable, treat it as never-calibrated and require a full-21 run before the bump.

**Procedure**, per `scenarios/NN-*.md`:
1. Dispatch `K` conductor-role replays against the **current** Kiln prose — same dispatch contract
   and mode table as Step 1 above (reference them; do not restate). Unlike the differential gate,
   there is only one side here: current prose only.
2. Run `majority <marker-file>...` on the `K` raw marker files to find the winning canonical line.
   If `majority` reports `UNSTABLE` (exit 4), record the scenario as `UNSTABLE` — a drift/stability
   signal in its own right — and do not force a gold comparison for it.
3. Otherwise, identify the **representative raw marker file** among the `K` — the one whose `canon`
   output equals the majority's canonical line — and run
   `bash ${CLAUDE_PLUGIN_ROOT}/skills/smith/smith-eval-gate.sh diff <representative-marker> <expected/NN-*.json>`.
   `diff` parses a fenced `kiln-routing` marker file, so the representative *raw marker*, never the
   majority's canonical line, is what gets diffed — piping `majority`'s output straight into `diff`
   would find no fenced block and fail loud on every scenario. PASS iff `diff` exits 0.

**Report** a drift ratio, not a pass/fail gate — e.g. "17/21 scenarios reproduce gold on their
K-sample majority" — plus:
- a named list of any scenario whose majority no longer matches gold, with the `diff` field deltas
  (`FAIL: <field> expected=x got=y`), and
- a named list of any scenario that came back `UNSTABLE`.

The anchor's job is to **detect drift**, never to gate or block a proposal — a soft ratio is the
honest signal here, precisely because a hard 21/21 bar is too brittle against replay stochasticity —
the anchor exists to report drift, not to gate. Do not report this as a pass/fail verdict.

**Record the calibration in the ledger.** After a full-21 `--calibrate` run, overwrite the active
record line in `${CLAUDE_PLUGIN_ROOT}/skills/smith/.last-calibration` with
`<HEAD-sha> full-21 <YYYY-MM-DD> <reproduced>/<total>` (the same drift ratio just reported). This is
what the release-preflight floor reads to know "since when." A `--validate` free-ride writes the same
line with coverage `partial-freeride` **only if** no `full-21` record already covers HEAD's routing
prose — a partial ride must never overwrite a stronger full anchor.
