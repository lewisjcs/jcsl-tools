---
name: gauntlet
description: Use when running a full multi-skill review across an artifact (PR, local diff, plan, doc, or skill). The canonical PR-review surface — "review this PR" routes here. Trigger phrases include "review this PR", "review PR <number>", "review the PR", "review this", "run the gauntlet", "do a full review", "fully review", "review my plan and security", or any natural-language variation requesting a multi-domain review of an artifact. When NOT to use: for single-aspect review use the corresponding sibling (security-gauntlet, code-quality-audit, adversarial-review). For author-side approval ritual use /ownership-check standalone.
argument-hint: "[<pr-url> | <path> | <directory>] [--go-live] [--security] [--doc-body] [--type <type>]"
---

# Gauntlet

The orchestrator for the gauntlet skill family. Routes an artifact to its domain-specific review skill, always runs a security pass, adjudicates findings across the canonical schema, and emits a unified report.

This skill consumes pre-built sibling skills as black boxes: `security-gauntlet` (Phase 2), `plan-review`, and `doc-review` (Phase 1). For code paths it dispatches `code-quality-audit` and `adversarial-review` (Phase 1). For skill markdown it invokes `skill-audit`. See [[gauntlet-namespace-shadow]] before dispatching — preflight `ls ${CLAUDE_PLUGIN_ROOT}/skills/` to check for sibling name collisions; all sibling dispatches use the `gauntlet:` prefix (e.g. `Skill: gauntlet:adversarial-review`) to avoid plugin namespace collisions. See [[gauntlet-is-pr-review-tool]] for the routing convention: "review this PR" routes here, single-aspect reviews route to siblings, author-side approval ritual is `/ownership-check` standalone. The schema each sibling emits is normalized to the canonical 10-field shape (master spec §4.1) before adjudication.

## Usage

```
/gauntlet https://github.com/contentful/<repo>/pull/<n>   — PR mode (code diff)
/gauntlet                                                  — Local mode (git diff main..HEAD)
/gauntlet <path-to-plan.md>                                — Plan mode
/gauntlet <path-to-doc.md>                                 — Doc mode
/gauntlet <path-to-SKILL.md>                               — Skill audit mode
/gauntlet <directory>                                      — Multi-artifact mode (review every reviewable file)
```

**When NOT to use:** Single-domain review (use `/security-gauntlet`, `/plan-review`, `/doc-review`, `/adversarial-review`, or `/skill-audit` directly). Brainstorming or designing an artifact (use `superpowers:brainstorming` first; gauntlet is the QA pass on the result). Generic security pass on git changes without orchestration (use Claude Code's built-in `/security-review`).

## Phase 0 — Detect

Determine the artifact type from the input. The detection rule:

| Input pattern | Artifact type | Routing |
|---|---|---|
| `https://github.com/<org>/<repo>/pull/<n>` | `code-pr` | Phase 1 dispatches: code-quality-audit + adversarial-review (family=code-diff). **Conditionally also dispatches doc-review against the PR body** when ALL of: `wc -w` of the PR body ≥ 200 AND the PR is **own-authored** (`gh pr view <n> --json author --jq .author.login` equals the current `gh api user --jq .login`). For teammate-authored PRs the body lane is skipped by default (record `doc-review (PR body): skipped — cross-author (advisory lane)` in the footer); `--doc-body` forces it on. Its findings are **capped at Nit** in Phase 3 (advisory only — never a blocker or concern), because in the 36-run corpus this lane produced 0 blockers and only PR-description-accuracy items. Phase 2 dispatches: security-gauntlet against the PR diff. `code-quality-audit` is the gauntlet-callable skill that audits AGAINST the `code-quality-standards` rules (parallel to skill-audit ↔ skill-authoring-principles). |
| (no args) | `code-local` | Phase 1 dispatches: code-quality-audit + adversarial-review (family=code-diff). Both work on local diffs — code-quality-audit operates on diff content, not GitHub metadata. Phase 2 dispatches: security-gauntlet against `git diff main..HEAD` (fall back to `master` only if `main` does not exist). |
| Path ending in `.plan.md` OR file under `projects/active/<feature>/plans/` | `plan` | Phase 1 dispatches: plan-review. Phase 2 dispatches: security-gauntlet against the plan text. |
| Path to `.md` file with prose-paragraph structure (RFC, ADR, README, design doc, AGENTS.md) — NOT a SKILL.md, NOT a plan | `doc` | Phase 1 dispatches: doc-review. Phase 2 dispatches: security-gauntlet against the doc text. **Plan-vs-doc tiebreaker (when path-based plan rules don't fire):** if the `.md` file contains a `## Goal` heading OR a `## Steps` heading OR EARS-style requirements (`When ... the system shall ...`) in its body, prefer `plan` over `doc` regardless of file location. If after this tiebreaker the artifact is still ambiguous, halt and ask per Phase 0 verify. |
| Path to `SKILL.md` OR `.md` file with YAML frontmatter `name:` + `description:` skill-fields | `skill` | Phase 1 dispatches: skill-audit + directive-review (body prose — post-frontmatter). Phase 2 dispatches: security-gauntlet against the skill content. (skill-audit emits in 3-layer shape; gauntlet performs the §4.3 transformation to canonical 10-field findings.) |
| Path to a non-frontmatter `.md` under an instruction-prose dir (`prompts/`, `knowledge/`, `references/`, `reference/`, `rules/`) AND the content reads as agent operating prose (imperative directives), NOT a human-facing RFC/README | `directive` | Phase 1 dispatches: directive-review + adversarial-review (no directive-text family exists; family=doc-text as the closest fit, footer-noted). Phase 2 dispatches: security-gauntlet against the artifact text. |
| Path to a directory | `multi` | Recurse: detect each contained file's type, run gauntlet against each. Aggregate per-file findings into a single report. |

**`directive` detection rule (hybrid path-allowlist + halt-and-ask).** A file routes to `directive` when BOTH gates pass: (1) **path gate** — a `.md` without `name:`+`description:` skill frontmatter, living in a directive-prose dir: `knowledge/`, `prompts/`, `references/`, `reference/`, `rules/`; AND (2) **content gate** — it reads as agent operating prose (imperative/directive register), not a data table or sample artifact. Excluded dirs: `scripts/`, `bin/` (code), `fixtures/` (test data). `examples/` and any prose `.md` outside these trees → **halt-and-ask** ("I detected this as possibly `doc` or `directive` — which lens?"). `SKILL.md`/`agent.md` with frontmatter → `skill` (skill-audit), never `directive`. Operator override: `/gauntlet --type directive <path>` forces routing. Rationale: location is mechanical (reliable); content-only detection is the fuzzy mis-route this type exists to fix. The allowlist is tuned to current `.claude/` conventions — an instruction file elsewhere falls to halt-and-ask (safe), never a silent mis-route.

**Go-live pre-filter (code-pr / code-local only).** After detecting a `code-pr` or `code-local` artifact, compute the calibrated 6-signal go-live pre-filter over the diff + PR body (see `projects/active/gauntlet/test-dataset/golive/` for calibration; recall 0.92 / FPR 0.28). The pre-filter matches if ANY of: a status-code/response-contract change, an auth/entitlement-gate change, a `BREAKING CHANGE` declaration, a feature-flag/gate/kill-switch **removal** (not introduction — that is dark prep), terminal rollout language (`go-live`, `GA`, `enable for all`, `source of truth`, `removes the legacy gates`), or an SDK major-version bump. If it matches, Phase 2.5 will prompt the operator to run the go-live readiness lane. This is detection only — it sets a flag consumed in Phase 2.5; it does NOT dispatch here and never auto-runs. `--go-live` forces the lane regardless of pre-filter; `--no-go-live` suppresses the prompt.

**Security-relevance pre-filter (code-pr / code-local only) — fail-open.** After detecting a `code-pr` or
`code-local` artifact, compute a `security_relevant` flag over the diff + changed-file paths. The flag is
TRUE if ANY of: (1) a change under an auth/identity/permission path (`**/auth/**`, `**/permission*/**`,
`*entitlement*`, `*grant*`, `*policy*`, `*acl*`, `*rbac*`); (2) a credential/secret touch (`*secret*`,
`*token*`, `*credential*`, `*.env*`, `*key*` in a non-keyboard sense, or added strings matching a high-entropy
secret shape); (3) a data-mutation surface (SQL/ORM writes, `delete`/`drop`/`truncate`, file/object deletion,
destructive migration); (4) an agent/tool-grant change (a `tools:`/`allow:` frontmatter edit, an MCP grant,
a shell-exec capability); (5) network/SSRF-adjacent I/O (new outbound fetch to a non-constant URL, redirect
handling); OR (6) **no plan-stage security pass is on record** for this ticket
(`ls projects/active/<ticket>/reviews/*-gauntlet-plan.md 2>/dev/null` returns nothing). **Fail-open
invariant:** if diff-class detection is ambiguous or errors (cannot read the diff, unknown file types,
mixed signals), set `security_relevant = TRUE`. The flag only ever SKIPS security on a diff confidently
classified as none-of-the-above. Like the go-live pre-filter, this is detection only — it sets a flag
consumed in Phase 2; it never dispatches here. `--security` forces the lane regardless of the flag;
`--no-security` is NOT offered (there is no operator path to suppress security on a security-relevant diff).

**Phase 0 verify (per master spec §5.5):** `artifact_type ∈ {code-pr, code-local, skill, plan, doc, directive, multi}`. If detection produces multiple matches OR no matches, halt and ask the user: "I detected the artifact as both X and Y" (multi-match) or "I couldn't detect the artifact type from `<input>`" (no-match). Don't guess.

**Phase 0 diff-content re-routing (code-pr only).** When the initial detection yields `code-pr`, fetch the changed file paths via `gh pr diff <n> --name-only` and classify each path:
- A path is a **skill file** if it contains `.claude/skills/` OR matches `plugins/*/skills/`.
- A path is a **directive file** if it contains `.claude/agents/*/knowledge/`, `.claude/agents/*/prompts/`, `.claude/agents/*/references/`, or matches `plugins/*/agents/*/knowledge`, `plugins/*/agents/*/prompts`, or `plugins/*/agents/*/references` — AND its extension is `.md`.

Apply the following routing rule:
- **All changed files are skill/directive:** re-route from `code-pr` to `skill` (if all are skill files), `directive` (if all are directive files), or `multi` (if mixed skill+directive). Record in chat: `"All changed files are skill/directive — re-routing from code-pr to <type>."`
- **Mixed diff (some skill/directive files alongside non-skill/directive files):** keep `code-pr` routing. Add supplemental `skill-audit` and/or `directive-review` sub-tasks in Phase 1 for the skill/directive files. Record in chat: `"Mixed diff — code lanes + supplemental skill/directive lenses for N file(s)."`

**Phase 0 emits to the top-level task list (via `TaskCreate`):** the artifact type, the routing decision (which sub-skills will be dispatched in Phase 1), and the dispatch count.

**Phase 0 also checks for a prior report (P9 delta hook):** for ticketed artifacts, `ls projects/active/<ticket>/reviews/*-gauntlet-*.md 2>/dev/null`. If a prior report exists, read its **Reviewed ref** header; if the current head SHA has advanced past it, flag the run as a delta re-review so Phase 4d appends rather than writes fresh. If no prior report or the ref is unchanged, proceed as a normal run.

## Checklist (top-level — created at Phase 0 entry)

Create a task list with these 5 tasks (one `TaskCreate` call each). Mark each `completed` with `TaskUpdate` as the corresponding phase finishes, and set the next to `in_progress` before starting it. Do not start a phase while the previous one is incomplete.

1. **Phase 0** — Detect artifact type, announce routing (+ compute go-live pre-filter for code artifacts)
2. **Phase 1** — Domain-specific review (sub-tasks created on entry)
3. **Phase 2** — Security review (always for non-code; gated for code diffs per HARD-GATE invariant 2)
4. **Phase 3** — Adjudicate (sub-tasks created on entry)
5. **Phase 4** — Write report file + post lean chat summary (sub-steps 4a–4d on entry)

Add a **6th task when the Phase 0 go-live pre-filter matched OR `--go-live` was passed** (code-pr/code-local): **Phase 2.5** — Go-Live Readiness (conditional verdict lane), sequenced after Phase 2 and before Phase 3. Omit the task entirely when neither condition holds — it is not part of the default 5-phase flow.

**HARD-GATE — no pausing between phases.** Proceed directly from each completed phase to the next without pausing for user input or displaying intermediate sub-skill output to chat. The only deliberate pause points in the entire run are: (a) Phase 0 halt-and-ask when artifact type is ambiguous, and (b) Phase 2.5 go-live prompt when the pre-filter matched and `--go-live` was not passed. Every other phase transition is silent and automatic. Do not post intermediate findings, progress summaries, or "Phase 1 complete — proceeding to security…" narration between phases — Phase 3 must adjudicate all findings before any results surface to the user.

**Continue-signal protocol (structural enforcement of the no-pause rule).** Every `Skill:` sibling dispatch carries an implicit continue-signal: when the sibling returns its findings JSON, the orchestrator is in CONTINUE state for that phase. The dispatch loop advances as follows — this is the ONLY permitted sequence at a phase boundary:

```
CONTINUE state transition (every phase except the two legitimate pause points):
  1. tool: TaskUpdate(current-phase → completed)         ← marks phase done
  2. tool: TaskUpdate(next-phase → in_progress)          ← advances the state machine
  3. tool: [first dispatch call of next phase]           ← begins next phase immediately
     (TaskCreate for sub-tasks, Skill: dispatch, or first read for Phase 4a)
```

Rule: steps 1–3 are a single action sequence. **No assistant text output appears between steps 1 and 3.** Narrating phase progress is permitted ONLY inside step 3's sub-task work or after Phase 4 begins writing the report — never as a standalone chat turn between steps 1 and 2, or between steps 2 and 3. Receiving a sibling's return IS the continue-signal; it binds the next action to step 1 above with zero intervening output. The orchestrator's state upon receiving any non-pause-point sibling return is deterministically "advance the phase machine immediately."

The two legitimate turn boundaries remain intact and are explicitly excluded from this protocol:
- **Phase 0 halt-and-ask** (ambiguous artifact type): the orchestrator asks the user and waits — it is NOT in CONTINUE state.
- **Phase 2.5 go-live prompt** (pre-filter matched, no `--go-live` flag): the orchestrator asks the operator once — it is NOT in CONTINUE state until the operator responds.

<HARD-GATE>
Six invariants enforced by this skill:

1. **Phase 0 must complete before any sub-skill is dispatched.** Detection failures halt the run; do not partial-dispatch.
2. **Phase 2 (security-gauntlet) always runs — except on code diffs confidently classified
   non-security-relevant.** For `plan`, `doc`, `skill`, and `directive` artifacts, security ALWAYS runs,
   no exceptions. For `code-pr`/`code-local`, security runs whenever the Phase-0 `security_relevant` flag is
   TRUE — which includes the fail-open default (ambiguous/unreadable diff → flag TRUE → security runs) and
   the "no plan-stage security on record" trigger. Security may be skipped ONLY when the flag is FALSE: a
   diff confidently classified as none of {auth, secrets, mutation, tool-grant, network} AND a plan-stage
   security pass already covered this ticket. A skip is never silent — Phase 2 records
   `security-gauntlet: skipped — non-security diff (flag=false; plan-security on record)` in the trust-signal
   footer. The pass is never skipped because the artifact merely "doesn't look security-relevant" to the
   operator — only the calibrated, fail-open flag may gate it.
3. **Phase 3 must adjudicate before Phase 4 emits.** No streaming of raw sub-skill findings to the user. Every finding the user sees has been through dedup + classify + rank.
4. **Critical-finding classification uses the three-filter rule** (severity=High AND confidence≥85 AND category∈{security, data-loss, correctness}) per master spec §4.4. NEVER promote a finding to Required Changes based on Finder's "High severity" claim alone.
5. **Phase 4 writes the report to a file.** The file is the deliverable; the chat summary is only a pointer to it. Confirm the written file exists (`ls`/`wc`) before telling the user where it is. Never end a gauntlet run with the report living only in chat scrollback.
6. **A prior plan gauntlet never shrinks the code-stage gauntlet.** The existence of a plan-stage report for
   a ticket does NOT skip, trivialize, or down-select the code-stage lanes (it only feeds the Phase-0
   `security_relevant` flag's "no plan-security on record" trigger). The code stage runs its full lane set
   per the §2 gates regardless of plan coverage. Evidence: across paired plan↔code runs, the code stage still
   surfaced a plan-invisible blocker (implementation-only defect) — see the diet design §1.
</HARD-GATE>

---

## Phase 1 — Domain-specific review

On entry to the Phase 1 task, create the Phase 1 sub-tasks (a `TaskCreate` call per sub-task). The set of sub-tasks varies by artifact type:

- `code-pr`: code-quality-audit (audit/inline), adversarial-review (family=code-diff).
**Conditionally also dispatch doc-review (typed) against the PR body text** only when the body is ≥ 200 words
AND the PR is own-authored (per the Phase 0 `code-pr` rule). Pass the body content as the doc artifact. Record
the outcome in the trust-signal footer either way — `doc-review (PR body): ran (Nit-capped)`,
`… skipped — body too short`, or `… skipped — cross-author (advisory lane)`. The lane must never silently
disappear: always run the `wc -w` + author check and record the result. Findings from this lane are capped at
Nit in Phase 3 substep 6.
- `code-local`: code-quality-audit, adversarial-review (family=code-diff). Same dispatch pair as `code-pr`; both lanes operate on diff content rather than GitHub metadata. No PR body dispatch (no PR exists for `code-local`).
- `plan`: plan-review, adversarial-review (family=plan-text — wires up plan-review's Architectural-risk lens per Phase 7 §9 resolution)
- `doc`: doc-review, adversarial-review (family=doc-text — wires up doc-review's Hidden-assumptions lens per Phase 7 §9 resolution)
- `directive`: directive-review (typed; `Skill:` black-box dispatch) + adversarial-review (the runtime has no `directive-text` family; pass family=doc-text as the closest fit and note the substitution in the trust-signal footer). No PR body dispatch. **For multi-file directive runs:** before dispatching any directive-review sub-tasks, count the files to be reviewed and emit a single line to chat: `"Dispatching directive-review for N file(s): [list]. This will spawn N×2 agent passes."` Then proceed without gating.
- `skill`: skill-audit. **When the artifact is a skill DIRECTORY, also dispatch directive-review (typed; `Skill:` black-box dispatch) once per non-frontmatter prose sibling** (`modes.md`, `references/*.md`, `reference.md`, and any other `.md` without `name:`+`description:` skill frontmatter). A skill is reviewed as a unit: skill-audit owns the SKILL.md, directive-review owns the operating-prose siblings it points to. Enumerate the siblings with `ls`/`find` and create one directive-review sub-task per file. **Before dispatching directive-review sub-tasks for multiple siblings, emit a single line to chat: `"Dispatching directive-review for N file(s): [list]. This will spawn N×2 agent passes."` Then proceed without gating.** If the artifact is a single SKILL.md file (not a directory), skip the sibling sweep — there are no siblings to review. **Additionally, for BOTH a single SKILL.md and a skill directory, dispatch directive-review (typed; `Skill: gauntlet:directive-review`) against the SKILL.md body prose** — defined as everything after the closing `---` of the YAML frontmatter block (frontmatter = the leading `---` … `---` block; body prose = the rest). skill-audit retains ownership of the frontmatter and structural checks; directive-review receives the body prose only. This body pass is distinct from the sibling sweep above and applies even when the artifact is a single SKILL.md (no directory — no siblings); the sibling-sweep skip clause applies only to the sibling sweep, not to this body pass. **Create a dedicated `TaskCreate` sub-task for this body pass** (labelled `directive-review (body prose)`), separate from any sibling-sweep sub-tasks, so the Phase 1 completion gate tracks it and can detect it going missing.
- `multi`: per-file dispatch sets (recurse into Phase 1 for each contained artifact)

Mark each sub-task complete as its sub-skill returns its findings array.

### Canonical dispatch contract

Each sibling falls into one of two dispatch shapes. **Use exactly these — do not improvise a third.**

| Lens | Owns typed agents? | Dispatch shape |
|---|---|---|
| `security-gauntlet`, `plan-review`, `doc-review`, `directive-review` | Yes (`*-finder` + `*-validator`) | **`Skill:` dispatch.** Invoke the sibling skill (`Skill: gauntlet:security-gauntlet`). The skill runs its OWN internal Find→Validate→Adjudicate against its calibrated agents and returns survivors-only JSON (verdict=survives, confidence≥70). Treat it as a black box. |
| `adversarial-review` | Yes (runtime-driven `adversarial-finder` + `adversarial-validator`) | **`Skill:` dispatch of `gauntlet:adversarial-review`.** The skill drives the deterministic runtime handshake (bundle → init → dispatch → receipt → result) inline; consume `<runDir>/result.json` `findings` as the lane's survivors — they arrive pre-adjudicated (severity-stratified gate) with `disposition: "survives"`. If the skill's own preflight fails (`node --version` absent or major < 22), it stops and reports that as its blocker before staging anything — treat this as a lane failure per Phase 1 verify below (no fallback dispatch). |
| `code-quality-audit`, `skill-audit` | No (workflow skills) | **Inline skill.** Invoke via `Skill:`; these read files and emit 3-layer prose in the main context (no typed finder/validator agents exist for them). gauntlet applies the §4.3 transformation to their prose. |

Why black-box the typed lenses: each sibling is a *calibrated unit* — it owns the finder→validator handoff, the empty-finder short-circuit, schema-retry, count-match verification, and its own per-lens adjudication. The calibration harness scores the **skill**, not the raw agents. Reaching past the skill to dispatch its agents directly would duplicate that coordination in the orchestrator AND diverge the production path from the calibration path.

**adversarial-review under orchestration:** when `adversarial-review` runs inside a gauntlet, defer its "Presenting the result" and disposition/triage prompt — the Phase 4 report IS the presentation. After the final report, ask dispositions for the adversarial-lane findings once (single batch) and submit them via the runtime's `triage` subcommand against the run's `runId`. Do not merge `result.json`'s below-the-line findings into Phase 3 — record their count and the `runDir` in the trust-signal footer instead. The runtime handshake itself (stages, receipts, retries) is untouched by orchestration: the sibling skill's HARD-GATE applies verbatim.

<HARD-GATE>
**Never wrap a sibling skill in a `general-purpose` (or any non-typed) subagent.** Dispatching `Agent(subagent_type: general-purpose, "run the adversarial review…")` collapses the sibling's Find→Validate→Adjudicate into a single Find pass — the Validator stage silently vanishes and false positives ship as fact. This is an observed failure (it required user correction in two prior runs). Typed lenses → `Skill:` dispatch; audit lenses → inline `Skill:`. There is no general-purpose path.
</HARD-GATE>

**Parallelism — why these run sequentially.** Phase 1's lenses are logically independent (security, adversarial, doc-on-body share no state and only meet at Phase 3 adjudication), so in principle they could run concurrently. They do NOT, by design: typed lenses are invoked via the `Skill:` tool, which executes **inline in the main conversation and has no background/concurrent mode** (verified — the Skill tool exposes no `run_in_background`). The only concurrency primitive in this harness is the `Agent` tool, and reaching past a sibling's `Skill:` boundary to batch its internal `*-finder`/`*-validator` agents directly is forbidden (the HARD-GATE above: it collapses Find→Validate and diverges the production path from the calibrated path). So independent lenses run one after another; this is an accepted latency cost of the black-box calibration boundary, not an oversight. Do not attempt to "background" `Skill:` dispatches or `Agent`-wrap siblings to parallelize them.

The sibling's "Called from gauntlet orchestrator" Invocation Context Detection row activates on `Skill:` dispatch; it returns a JSON findings array per its declared output contract.

**For plan and doc artifact types, dispatch the adversarial lane with the family named:**

```
Skill: gauntlet:adversarial-review

Family: <plan-text | doc-text>
Artifact path: <repo-relative path>
```

The skill stages the artifact file itself (`bundle --family <family> --primary <path>`). Its Finder emits the same native 3-lens vocabulary (`Hidden Assumptions` | `Failure Scenarios` | `Blast Radius`); Phase 3 substep 1 relabels ALL THREE to canonical lenses (the sub-lenses must NOT collapse to one — that drops HIGH-confidence critical findings in dedup). The full 9-row cross-skill lens-mapping table, the collapse-rationale, and the ` - ` vs ` — ` separator rule live in [reference.md](reference.md) — load it in Phase 3 substep 1.

**Phase 1 verify (per master spec §5.5):** for each domain skill dispatched, parse the output as JSON and confirm:
1. The output is an array (possibly empty).
2. Each entry has one of three shapes:
   - **Black-box sub-skill output (plan-review, doc-review, security-gauntlet, directive-review):** the 10 canonical fields per §4.1, pre-filtered to verdict=`survives` AND confidence≥70.
   - **Adversarial-review output:** read `<runDir>/result.json`. `findings` is the survivors array; each item already carries `lens`, `location`, `claim`, `evidence`, `severity`, `category`, `confidence`, `recommendation`, `disposition: "survives"`. Promotion to the canonical 10-field shape (Phase 3 substep 1) only adds `skill: adversarial-review` and `verdict: "survives"` and applies the lens relabel — never re-gate these findings (the runtime's severity-stratified adjudication already did). If `executionStatus` is `failed`/`incomplete`, the run recorded a stage gap, or the skill's own preflight failed (Node < 22, reported as its own blocker before any staging), mark the lane `review failed` in the trust-signal footer and continue (existing failed-domain rule) — there is no fallback dispatch.
   - **Prose-emitting sub-skill output (skill-audit, code-quality-audit):** these skills emit 3-layer prose (Compliance / Staleness / Gap) rather than canonical 10-field JSON. Apply the master spec §4.3 transformation to convert the prose into the canonical schema before adjudication.
3. The `lens` value matches the sub-skill's declared lens vocabulary.
4. `verdict ∈ {survives, disproved}`.
5. `confidence ∈ [0, 100]`.

If any sub-skill returns malformed JSON, re-dispatch once with the schema spelled out (per §5.2 row 3). If the second attempt also fails, mark the domain as "review failed" in the trust-signal footer and continue to Phase 2 — DO NOT halt the gauntlet on a single sub-skill failure.

If a sub-skill returns an empty array, mark the domain as "clean — no findings" in the trust-signal footer and continue. Empty is valid (per §5.2 row 4).

**Phase 1 sub-task completion gate:** the top-level Phase 1 task only marks `completed` after all sub-tasks complete (success or "review failed"). Do not advance to Phase 2 with a sub-task `in_progress`.

---

## Phase 2 — Security review

**Runs by the §5.3 invariant-2 gate** (see the HARD-GATE block above): unconditionally for `plan`/`doc`/
`skill`/`directive`; for `code-pr`/`code-local`, iff the Phase-0 `security_relevant` flag is TRUE (fail-open:
ambiguous → TRUE). When the flag is FALSE, skip the dispatch, record
`security-gauntlet: skipped — non-security diff (flag=false; plan-security on record)` in the trust-signal
footer, set the "Reviewed by" status to `skipped (gated)`, and proceed to Phase 3 — the Phase 3 entry gate
(below) treats a gated skip as a satisfied security requirement, NOT a missing lens. A `--security` flag
forces the dispatch even when the flag is FALSE.

Dispatch security-gauntlet via `Skill: gauntlet:security-gauntlet` against the same artifact:

- For `code-pr` and `code-local`: dispatch with the diff (PR diff for `code-pr`, `git diff main..HEAD` for `code-local`).
- For `plan`, `doc`, `skill`: dispatch with the artifact content. security-gauntlet's existing prompt accepts non-code artifacts per master spec §3.3 ("Apply the 7 security-principles lenses to an artifact (code diff, plan text, doc text, or skill content per master spec §3.3)").

**security-gauntlet output contract.** security-gauntlet returns a JSON findings array per the canonical 10-field schema when called from gauntlet (symmetric with plan-review and doc-review's `Returns surviving findings JSON for orchestrator aggregation` contract). Phase 2 verify parses that JSON; the standalone-prose path is a separate output mode invoked only when `Skill: gauntlet:security-gauntlet` runs without the gauntlet caller-context.

**Phase 2 verify (per master spec §5.5):** parse output as JSON. If security-gauntlet returns a valid findings array (possibly empty), continue to Phase 3. If security-gauntlet errors or returns malformed JSON, mark Phase 2 as failed in the trust-signal footer and add a `⚠️ Security pass failed — manually run `/security-gauntlet` or escalate to AppSec.` callout to the report header (per §5.2 row 6). Critical-classification proceeds without the security signal.

If security-gauntlet returns 0 findings, mark "Security pass: clean" in the trust-signal footer and continue (per §5.2 row 7).

---

## Phase 2.5 — Go-Live Readiness (conditional, code-pr / code-local only)

Runs ONLY when the Phase 0 go-live pre-filter matched OR `--go-live` was passed. Skip this phase silently and record `go-live-review: n/a` in the trust-signal footer for: every non-code artifact type, and code artifacts where the pre-filter did not match AND `--go-live` was not passed.

**This lane is structurally distinct from every other gauntlet lens and MUST be kept so:**
- It emits a **SHIP / HOLD / NEEDS-INFO verdict in a fenced zone**, NOT canonical 10-field findings. It does NOT enter Phase 3 (dedup/classify/rank), and its verdict is NEVER counted as a blocker/concern/nit or added to the `gauntlet:v1` machine-readable JSON. Folding a drifting, externally-grounded verdict into the SHA-reproducible finding counts corrupts the calibration trust signal (per the go-live design §4.4).
- It reads **external state that drifts** (Jira ACs, rollout docs, entitlement/flag provisioning), so its verdict is point-in-time (`as-of <timestamp>`), unlike the reproducible code lanes.

**Run condition (two paths into dispatch).**
- **`--go-live` passed:** dispatch unconditionally, skipping the prompt — the operator already opted in explicitly. This path fires even when the pre-filter did NOT match (the override's whole purpose: review a go-live the signals missed).
- **Pre-filter matched, no flag:** ask the operator once — "This change <matched signals — e.g. removes a feature flag and alters a response contract> — it may be a go-live. Run the go-live readiness lane? [y/N]". On `y`, dispatch; on `N` (or `--no-go-live`), skip and record `go-live-review: declined` in the footer. The FPR is ~0.28 by calibration, so a wrong prompt costs one keystroke; never escalate a bare pre-filter match to an auto-run.

**Dispatch.** Invoke `Skill: gauntlet:go-live-review` against the PR/diff. It runs its own six-step readiness review (ticket-fetch, external-state confirmation, rollback, ownership, blast-radius) and returns its fenced verdict block. Treat it as a black box like the typed lenses — do not re-implement its steps in the orchestrator.

**Phase 2.5 verify.** Confirm the lane returned a fenced `🚀 Go-Live Readiness` block with one of SHIP / HOLD / NEEDS-INFO. If it errored, record `go-live-review: ⚠ failed` in the footer and continue — a go-live-lane failure never blocks the rest of the gauntlet. Carry the verdict block verbatim to Phase 4b for rendering in its own zone.

---

## Phase 3 — Adjudicate

### Phase 3 entry gate — review-completeness check (P3)

Before creating the substep list or touching any finding, prove the review is complete. Build the dispatch ledger and confirm BOTH conditions; if either fails, **STOP — do not adjudicate, do not emit.** Resume by dispatching the missing lens.

1. **Security ran or was gate-skipped.** Phase 2 returned a result (findings array OR an explicit
   `⚠ failed`), OR Phase 2 was skipped because the Phase-0 `security_relevant` flag was FALSE (a deliberate,
   footer-recorded gated skip — NOT a missing lens). If Phase 2 neither ran nor was gate-skipped (i.e. it was
   silently dropped with no flag decision), it is not optional — dispatch it now (HARD-GATE invariant 2).
2. **Every dispatched lens completed.** For the artifact type's routing set (per Phase 0), each lens shows status `✓` (returned findings/empty) or `⚠ failed` (errored after one retry) — never `in_progress`, never absent. A lens that was dispatched as a typed `Skill:` must have run its full Find→Validate→Adjudicate (survivors-only JSON returned), not just a Finder pass.

Concretely, list each lens in the routing set with its status before proceeding:

```
Phase 3 entry gate:
  security-gauntlet : ✓ (N findings)        ← invariant 1
  <lens-2>          : ✓ (M findings)
  <lens-3>          : ⚠ failed (after retry)
  → all lenses terminal AND security ran? YES → adjudicate / NO → STOP, dispatch missing
```

This gate exists because two prior runs advanced toward a report with an incomplete review — one ran a single lens then stopped (caught only by the user asking "why stop?"), one ran Finders with no Validators. The completeness proof must be explicit, not assumed.

**go-live-review is NOT in this ledger.** It is a Phase 2.5 verdict lane, not a finding lens — it has its own Phase 2.5 verify and emits no findings to adjudicate. Do not list it here, do not block Phase 3 on it, and do not treat its absence as an incomplete review. (If Phase 2.5 ran, it already completed before Phase 3 by sequencing.)

### Adjudication substeps

Create the Phase 3 sub-tasks with these 7 substeps (a `TaskCreate` call per substep). Each substep is mechanically distinct; skipping any one degrades report quality.

1. **Concatenate** — Combine all findings from Phase 1 (per-domain) and Phase 2 (security) into a single array. Promote adversarial-review's result items to the 10-field canonical shape (add `skill`/`verdict` and relabel the lens), and apply the §4.3 skill-audit transformation to any skill-audit findings. **Load [reference.md](reference.md) now** — it holds the field-by-field promotion rules (`skill`, `lens` via the 9-row mapping table, `category`, `recommendation`) and the lens-mapping needed for this substep.

2. **Normalize verdicts (NEW — runs before drop-disproved).** Validators occasionally drift to non-canonical verdict strings under load. Before any drop, case-fold each `verdict` and apply this deterministic synonym map — known synonyms have unambiguous intent and MUST be mapped, not kept:

   | Drifted verdict (case-insensitive) | Canonical |
   |---|---|
   | `disproved`, `refuted`, `false_positive`, `false-positive`, `invalid`, `rejected`, `not a finding`, `n/a` | `disproved` |
   | `survives`, `confirmed`, `valid`, `upheld`, `stands`, `real` | `survives` |

   Mapping `refuted`/`false_positive` → `disproved` is load-bearing: these mean the validator KILLED the finding, so the old "keep on non-canonical" fallback would have done the opposite of the validator's intent (leaking a killed finding). After mapping, record in the trust-signal footer only if any mapping was applied: "Normalized N non-canonical verdict(s)." A verdict that matches NEITHER column (genuinely unrecognized) falls through to substep 3's residual rule.

3. **Drop disproved** — Remove findings where the (now-normalized) `verdict = "disproved"` exactly. For any verdict that substep 2's map did NOT recognize (truly unknown string), do NOT drop it — treat it as `survives`, keep it, and surface in the trust-signal footer as "Validator emitted unrecognized verdict `<value>`; finding kept for safety." This residual fallback now applies only to strings outside the synonym map, not to known synonyms.

4. **Drop low-confidence** — Remove findings where `verdict = "survives"` but `confidence < 70`. NOTE: sub-skills called via "Called from gauntlet orchestrator" path already pre-filter to confidence≥70; this substep is a no-op for those (preserved for safety). adversarial-review arrives pre-adjudicated (deterministic severity-stratified gate) — this substep is a no-op for it too, preserved for safety.

5. **Deduplicate** — Two findings are duplicates if they have **same `location` AND same `lens`**. Adjacent paragraphs / lines with the same lens are NOT duplicates and MUST both survive (per §4.1.1's multi-defect-same-section emission contract added Phase 6). When duplicates exist, keep the higher-confidence version; tie-break by severity (High > Medium > Low), then by skill-name alphabetical.

**Order is load-bearing:** normalize (substep 2) runs first so the drop rules see canonical verdicts; drop-disproved (substep 3) and drop-low-confidence (substep 4) run BEFORE dedup so that dedup never has to choose between a valid and a disproved/low-confidence version of the same finding. Reordering for "efficiency" (e.g., dedup first to reduce the working set) would break this invariant — disproved or low-confidence findings could survive by being chosen as the dedup keeper before the drop-rules apply.

6. **Classify critical** — Apply the §4.4 three-filter rule. A finding is critical IFF: severity == "High" AND confidence ≥ 85 AND category ∈ {"security", "data-loss", "correctness"}. NEVER promote based on Finder's "High severity" claim alone (per HARD-GATE invariant 4). Findings that fail any of the three filters remain in the regular ranked list, NOT in Required Changes.

   **Source cap (doc-on-body):** any finding whose `lens` is `doc-review / *` AND whose origin is the PR-body
   lane (not a standalone `doc` artifact) is capped at severity Low (Nit) before this filter runs — it can never
   be classified critical or surface as a Concern. This encodes the corpus result (0 blockers in 36 runs) and
   keeps PR-description nits advisory.

   **6b. Ground-truth check on critical findings (P7).** Before a finding stays in Required Changes, verify any load-bearing factual/environmental claim it rests on against ground truth — do NOT promote on a Finder's (or Validator's) assertion alone. The claim types that have shipped wrong: "this regex/type allows X", "this slips past CI", "this symbol is already published in version N", "the other service guarantees Y before this runs". For each critical finding, identify its load-bearing claim and verify by the cheapest sufficient means:
   - **In-repo claim** (regex, type, guard, test config) → read the actual file/line. First do the cheapest check: if the cited line number exceeds the file's length (`wc -l`), the citation is out of bounds — mark the finding **unverifiable** (it points at a line that does not exist) and do not promote it. Only when the line is in-bounds, read it to verify the claim.
   - **Build/CI claim** ("passes/fails the gate") → run the gate, or read the CI config that defines it.
   - **Published-artifact claim** ("X is exported in 4.x") → check the package version the artifact actually resolves to, not memory. When the diff itself bumps a dependency, resolve the claim against the DECLARED post-change version in the manifest/lockfile post-image (the `+` side of `package.json` / `package-lock.json` / equivalent) — NOT the installed `node_modules` tree, which may still hold the pre-bump version if the sandbox wasn't reinstalled. When the diff does not touch the dependency, the installed package or registry is ground truth.
   - **Cross-service/cross-repo claim** the gauntlet can't reach → it is **unverifiable from here**. Do not promote it to Required Changes on confidence alone; downgrade to a regular Finding and tag it `⚠ unverified cross-system claim` in the report. Symmetrically, a *disproof* that rests on an unverifiable cross-system claim does NOT count as grounded — keep the finding rather than dropping it on an unprovable disproof (the ede1b2b6 failure: 3 High findings dropped on a lifecycle claim the Validator admitted it couldn't confirm).

   If verification contradicts the finding, drop it (note in the disproved `<details>`). If it confirms, keep it. If it can't be resolved, downgrade + tag. This step is the orchestrator's job precisely because the Finder→Validator loop runs in subagents that may assert environmental facts the orchestrator must confirm at ground level.

7. **Rank** — Sort surviving findings by (severity_weight × confidence) descending. Severity weight: High=3, Medium=2, Low=1. Stable sort; preserve relative order on ties.

**Phase 3 verify (per master spec §5.5):** filtering count ≥ 0; critical-classification rule applied; dedup ran. If the disproved + low-confidence filters dropped zero findings AND the Phase 1+2 dispatches produced findings, the re-dispatch path depends on which sub-skill is most permissive. Sub-skills are NOT uniformly addressable — gauntlet dispatches them via `Skill:` tool (black box), so internal Validators are not directly invokable. The re-dispatch logic:
- **For adversarial-review:** re-dispatch is NOT available — adjudication is deterministic inside the runtime and the lane returns pre-gated survivors; treat it like the black-box sub-skills below.
- **For black-box sub-skills (plan-review, doc-review, security-gauntlet):** re-dispatch is NOT available — those skills pre-filter to confidence≥70 internally and return only surviving findings. If they returned findings that gauntlet's drop-disproved + drop-confidence-low produced zero drops on, that's a SUB-SKILL output that already passed the sub-skill's own re-dispatch path. Do not re-invoke; accept the surviving set.

If the re-dispatch path is unavailable (all in-Phase-1 sub-skills are black-box) AND zero findings were dropped, accept survivors and emit a `<details>` note in the report (per §5.2 row 9): "no false-positive filter triggered at gauntlet level — sub-skills already pre-filtered." Do not loop further.

**Disproof-rate signal (single bidirectional check — replaces the two prior ≥90% banners).** Compute once: `disproof_rate = count(verdict="disproved") / total_raised` over the normalized Phase 1+2 findings (substep 3 input, after substep 2 normalization). The two failure modes this guards against are opposite ends of ONE axis, so define them with explicit polarity and never collapse or invert them:

- **HIGH disproof (validators may be over-dropping):** `disproof_rate ≥ HIGH_BAND`. Footer: `ℹ️ High disproof rate (X/Y disproved). Artifact may be clean, OR Validators may be leaning on 'out of scope' / 'established convention' disproofs without context-checking — including unverifiable cross-system disproofs (substep 6b). Review the disproof reasons in the collapsed Findings before treating this as confirmation.`
- **LOW disproof (validators may be over-firing / rubber-stamping):** `disproof_rate ≤ LOW_BAND` AND `total_raised ≥ 8` AND **not lens convergence** (suppress the banner — emit nothing — if the surviving findings share **a converging `location`** — for `file:line` locations, the same file no more than 5 lines apart (`same file AND |lineA − lineB| ≤ 5`); for narrative/section-reference locations (no line number, e.g. a heading like `## AC-4.1`), the same section/heading string — across 2 or more distinct `lens` prefixes; if a `location` is neither `file:line` nor a clear section reference, treat it as not converging (banner fires as normal); that cluster means multiple lenses legitimately converged on one root defect, so low disproof is the correct outcome, not evidence of over-firing). Footer: `⚠️ Low disproof rate (X/Y disproved); validators dropped little — review may have over-fired false positives.`

**Threshold the bands on the CALIBRATED baseline, not a fixed 90%.** A fixed 90% fired on nearly every real run because ~90% disproof IS the steady-state for well-authored artifacts — flagging normal as suspicious (banner-blindness). Instead, read the validators' baseline disproof rate from the most recent calibration run (`run-calibration.sh` agreement block: a calibrated validator's disproof rate is `1 − (TP+FP confirmed)/total`; the φ−κ drift sign says whether it over- or under-confirms vs gold). Set `HIGH_BAND = baseline + 0.10` and `LOW_BAND = baseline − 0.20`, so the banner fires on **deviation from calibrated behavior**, not on the baseline itself. If no calibration baseline is available, fall back to `HIGH_BAND = 0.95`, `LOW_BAND = 0.50` (deliberately wider than the old 0.90 so it stops firing every run). Emit at most ONE of the two lines; if `disproof_rate` is between the bands, emit nothing. Neither line blocks the report.

**Phase 3 sub-task completion gate:** the top-level Phase 3 task only marks `completed` after all 7 substeps complete. Do not advance to Phase 4 with a substep `in_progress`.

---

## Phase 4 — Write report file + post summary

The report is **written to a file** (the durable artifact); a **lean summary is posted to chat** (the pointer to it). Sub-steps 4a–4c run on every run; 4d runs only for delta re-reviews.

### Phase 4a — Resolve report path and reviewed ref

**Report path.** Extract the ticket key (first `[A-Z]+-\d+` match) from the PR title (`code-pr`), the plan/doc path or its parent dir (`plan`/`doc`), or the branch name (`code-local`). Then:

- **Ticket found:** check for an existing ticket dir case-insensitively — `ls -d projects/active/* 2>/dev/null | grep -i "/<ticket>$"`. Reuse it if found; otherwise create `projects/active/<ticket>/` using the key as-extracted. Report path: `projects/active/<ticket>/reviews/<YYYY-MM-DD>-gauntlet-<artifact-type>.md` (`mkdir -p` the `reviews/` subdir; date from `date +%Y-%m-%d`).
- **No ticket** (ad-hoc doc, unticketed local diff): `scratch/gauntlet-<YYYYMMDD-HHMMSS>/report.md` (`date +%Y%m%d-%H%M%S`).
- **Collision:** if the dated path already exists (a re-run the same day that is NOT a delta re-review — see Phase 4d), append `-2`, `-3`, … Delta re-reviews append a section to the existing file instead (Phase 4d).

**Reviewed ref (P4 — record what was actually reviewed).** Capture the exact ref so findings are never re-grounded against the wrong branch:
- `code-pr`: `gh pr view <n> --json baseRefName,headRefName,headRefOid` → record `base ← head@<headRefOid short>`.
- `code-local`: `git rev-parse --abbrev-ref HEAD` + `git rev-parse --short HEAD` + merge-base against `main`/`master` → record `<base>..<branch>@<sha>`.
- `plan`/`doc`/`skill`: record the artifact path + `git rev-parse --short HEAD:<path> 2>/dev/null` (file blob SHA) if tracked, else `untracked file`.

### Phase 4b — Write the report file

**Load `report-template.md` now** — it holds the full Zone 1 (report file) + Zone 2 (postable comment) templates. The orchestrator does not need it before Phase 4b; it is consumed once per run at report-write time. Render the report to those two templates.

**Bright-line (carried from the template):** Zone 1 vocabulary never appears in a teammate-facing surface; only Zone 2 is postable. The Zone 2 comment is the canonical postable text for EVERY artifact type — when the operator later posts a PR comment or runs `/create-pr`, that step reuses Zone 2 verbatim.

### Phase 4c — Post lean chat summary + verify

To **chat** (not the full report), post only:
1. Verdict line — `✅ Clean`, `⚠️ N findings (M required)`, or `🛑 Required Changes — do not ship yet`.
2. The **Required Changes** block verbatim if `critical[]` non-empty (the ship/no-ship call shouldn't require opening a file).
3. The report file path, and a one-line note that full findings + the postable comment are in the file.

**Phase 4 verify (per master spec §5.5):** after writing, confirm the file exists and is non-empty — `wc -l <path>` returns ≥ 1 and `ls <path>` succeeds. State the path in chat only after this check passes (evidence before assertion — do not claim "report written" without the `ls`/`wc` confirmation). In-file checks: required sections present and ordered; if `critical[]` non-empty, Required Changes appears first; if Phase 2 failed, the header callout is present; if `findings[]` > ~30, surface top 10 critical/High and collapse Medium/Low into a `<details>` count summary (§5.2 row 10).

**Output length discipline:** Zone 1 is for a human ship/no-ship decision, not an exhaustive audit log — trim verbose evidence to the lines that demonstrate each issue. Keep the trust-signal footer (Reviewed by) always visible. Chat stays lean; the file holds the detail.

### Phase 4d — Delta re-review (re-run against an advanced head)

If Phase 4a finds an existing dated report for this ticket AND the head SHA has advanced since that report's **Reviewed ref**, this is a re-review, not a fresh run:
- **Read the PR thread FIRST, before diffing or judging.** Pull issue comments (`gh api .../issues/<n>/comments`), inline review comments (`.../pulls/<n>/comments`), and reviews (`.../pulls/<n>/reviews`) — the author often replies disposing each finding (Fixed / Intentional / Skip) and may give rationale that moots a finding (e.g. "this 404 is intentional anti-enumeration"). Re-reviewing without those replies re-litigates settled points.
- **Verify every author "Fixed" / "resolved" claim against the code — claims can be wrong.** Read the actual test/handler the claim rests on; confirm the new test exercises the path it says (not a sibling), and that the tested handler even calls the changed function. (Observed failure: an author marked a finding "Fixed — covered by the handler tests" when the only tested handler didn't call the function at all.) Reconcile any commit SHA the author cites against the current head — a rebase re-IDs the same commit, so a matching commit *subject* under a different SHA is the same content, not new work. Trust the thread for *intent*, the diff for *reality*.
- Re-verify each prior **surviving** finding against the new ref (fixed / still-open / now-moot) and scan only the new commits (`git diff <prior-headRefOid>..<new-head>`) for new findings. **Isolate the author's actual changes from rebase artifacts:** diff the prior tip → new tip on the artifact's own paths only; unrelated files pulled in by a rebase onto a newer base are NOT this PR's work and do not enter the verdict.
- **Append** a dated section to the existing file: `## Re-review <YYYY-MM-DD> (<prior-sha> → <new-sha>)` with a verdict-transition table (finding → was → now) and any new findings run through the normal Phase 1–3 pipeline.
- **Updating the posted comment is an outward-facing action — re-confirm before doing it.** Prior approval to post the *initial* comment does NOT authorize editing it on a re-run. Ask before PATCHing the existing `gauntlet:v1` comment (or posting a new one). Iterate freely in the report file (Zone 1/2); the PR comment is the gated surface.
- Chat summary states the transition (e.g., `2 of 3 prior findings resolved; 1 new Low`).
This gives re-reviews a defined path instead of an improvised ad-hoc rerun.

## Sibling Skills

Dispatch shape per the canonical contract in Phase 1: **typed** lenses own `*-finder`/`*-validator` agents and are `Skill:`-dispatched as black boxes; **audit** lenses own no agents and run inline.

- `security-gauntlet` — typed. Phase 2 dispatch target. **Always runs for `plan`/`doc`/`skill`/`directive`;
  for code artifacts it is gated by the Phase-0 `security_relevant` fail-open flag** (skipped only on a
  confidently-non-security diff with plan-stage security already on record). Never skipped silently — a gated
  skip is footer-recorded and shows `skipped (gated)` in "Reviewed by".
- `plan-review` — typed. Phase 1 dispatch target for `plan` artifacts.
- `doc-review` — typed. Phase 1 dispatch target for `doc` artifacts (and the PR body of `code-pr` when ≥200 words).
- `adversarial-review` — runtime-driven Class, dispatched via `gauntlet:adversarial-review`. Phase 1 dispatch target for code (`code-pr`, `code-local`) AND for plan/doc (family-named dispatch). Owns `adversarial-finder`/`adversarial-validator`, running inside the runtime handshake (not directly dispatchable).
- `directive-review` — typed. Phase 1 dispatch target for `directive` artifacts, AND for the SKILL.md body prose (post-frontmatter) of ANY `skill` artifact (single-file or directory), AND for the non-frontmatter prose siblings (`modes.md`, `references/*`) of a `skill`-directory run. Owns `directive-finder`/`directive-validator`; returns survivors-only canonical JSON like the other typed lenses.
- `skill-audit` — audit (inline). Phase 1 dispatch target for `skill` artifacts. gauntlet performs the §4.3 transformation; skill-audit's output contract is unchanged.
- `code-quality-audit` — audit (inline). Phase 1 dispatch target for `code-pr` and `code-local` artifacts. 3-layer audit (Compliance / Staleness / Gap) against `code-quality-standards` rules. Returns prose; gauntlet transforms to canonical 10-field shape via master spec §4.3.
- `go-live-review` — **verdict lane (Phase 2.5), not a finding lens.** Conditionally dispatched for `code-pr`/`code-local` when the go-live pre-filter matches and the operator opts in. `Skill:`-dispatched as a black box; returns a fenced SHIP/HOLD/NEEDS-INFO readiness verdict that renders in its own Phase 4b zone and never enters Phase 3 adjudication or the blocker/concern/nit counts. Calibration + gold corpus: `projects/active/gauntlet/test-dataset/golive/`.
- `code-quality-standards` — reference skill loaded by Validators (security-validator, adversarial-validator, plan-validator, doc-validator) for false-positive rules. Not a dispatch target; emits no findings. The `code-quality-standards / *` lens prefix appears in the canonical lens vocabulary for routing-by-lens, not skill-attribution — actual emissions against those lenses come from sibling Finder agents (e.g., security-finder).

## Trust-signal footer notes

When the report's "Reviewed by" footer shows `⚠ failed` for any skill, the gauntlet operator should manually re-run that skill in standalone mode and append findings to the report. The `n/a` status is a positive signal ("we considered this skill and it didn't apply"), not a degradation.

A `skipped (gated)` (security) or `skipped (cross-author)` (doc-on-body) status is the diet's intended
behavior, not a gap: the lane was *considered* and deliberately not dispatched per a calibrated, fail-open
rule. Treat it like `n/a` — a positive "we evaluated this and it didn't apply" signal. Only `⚠ failed`
warrants a manual standalone re-run.
