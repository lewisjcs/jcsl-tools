---
name: kiln
description: Complexity-proportionate implementation Party. Thin conductor — routes, gates, dispatches members; never implements inline. Entry: /kiln EXT-NNNN | /kiln "raw idea" | /kiln EXT-NNNN path/to/plan.md
---

# The Kiln — Conductor

A complexity-proportionate implementation Party. This conductor is **thin by capability**: while a run
is active it cannot edit source via the file-editing tools (Edit/Write/MultiEdit/NotebookEdit) or call
Compounds mutation tools — a plugin PreToolUse hook denies those in the main thread (see `hooks/`). This
is a behavioral guardrail, not a sandbox: the conductor still holds Bash (it needs git), so the guarantee
is "won't edit source through the editing tools," not "physically can't touch source." It routes, makes
the lane visible, builds a progress spine, dispatches members, and adjudicates gates from their typed
returns. It does not implement, plan, or design inline. Members hold the working tools.

**Progressive disclosure — load on demand:**
- `lanes.md` — at the classify verb (entry→lane matrix, doc-shape + drift-check).
- `scenarios.md` — at the classify verb (scenario detection → verifier + patterns source).
- `gates.md` — at the first gate (gate conditions, tier×blast behavior, flow-styles).
- `dispatch-contracts.md` — once per member dispatch (four-part templates).

**Ledger:** `{{RUN_FOLDER}}/progress.md`, written before every gate transition (task state + `NUDGE-SEEN`/`YIELD` flags). On a context-preservation yield the conductor also writes `handoff.md` (narrative). On resume after `/clear`, read both and continue from the first incomplete task.

**Scope (P2.1):** EXECUTE / PLAN / TRIVIAL / RESUME / **DESIGN / RESEARCH** lanes; `code` + `tool-authoring` + `doc` scenarios. SPEC-GATE, Scout, and the Designer are live. Still P2.2: the `mcp/agent-app` / `infra` scenarios (they HALT). Jira ticket write-back — the Drafter
renders the agreed spec into the team-format+EARS description and reconciles subtasks at the initial
(post-SPEC-GATE) and completion checkpoints, always diff-gated. The Curator's close-out transition
(ticket → In Review + PR-link comment) is in scope. An out-of-scope scenario or ambiguous doc shape → HALT-AND-ASK. Every run binds one engine (`code`→compounds, `tool-authoring`/`doc`→native) and is ledger-tagged `engine:`.

---

## Verb 1 — Read

Parse the entry argument. Prefix-agnostic key match `[A-Z]+-\d+`. Read the ticket (if any) via Jira-read.
Set `{{RUN_FOLDER}} = <WORKSPACE>/projects/active/<run-id>/kiln/`, where:
- `<WORKSPACE>` is the OS workspace root — the directory the session runs from (this OS launches from a
  non-git workspace that wraps many repos; do NOT use `git rev-parse --show-toplevel`, which would resolve
  into whichever nested repo the cwd sits in and scatter run folders across repos). Run folders always live
  in the workspace, never inside a repo.
- `<run-id>` is the Jira key if the entry has one (`[A-Z]+-\d+`); otherwise a kebab-slug derived from the
  entry (a raw-idea string or a keyless plan filename) — e.g. `/kiln "add dark mode"` → `add-dark-mode`.

**Ordering matters here.** A ticketed entry (run-id = Jira key) needs no confirmation — proceed straight
to `mkdir -p {{RUN_FOLDER}}`. A net-new entry's slug is a guess: CONFIRM it with the user via
`AskUserQuestion` (see Verb 4) BEFORE `mkdir -p {{RUN_FOLDER}}` and before any sentinel write — a
rejected slug must not orphan a folder or sentinels under the wrong name.
If the entry includes a spec-shaped file (a PLAN-from-spec run — see `lanes.md`), stash it at
`{{RUN_FOLDER}}/spec-draft.md` (`cp` — a project-space write, guard-exempt: the conductor guard
exempts the whole `<WORKSPACE>/projects/active/` tree — run folders, ticket-root docs, and
`.handoffs/` — as working space; only source under `<WORKSPACE>/repos/` is denied inline). That copy
is the sole P1 producer of `spec-draft.md`; the Planner and Walker read it there. No spec file at entry → no stash, and
those consumers fall through to the ticket body (they already read `spec-draft.md` only "if present").

## Verb 2 — Classify & announce (LOUDLY)

Load `lanes.md` and `scenarios.md`. Determine lane + scenario now (from the entry + ticket). Tier + blast are NOT known yet — the Planner derives them from Compounds' classify step and returns them in its done-line; update the announcement with them after the Planner runs. **Exception — TRIVIAL fast-detect** (per `lanes.md`, including its mechanical re-verification gate): if the entry carries a resolved `compounds_classification: TRIVIAL` signal AND the change's diff/targets pass the trivial check in `lanes.md` (comments/docs/whitespace or a single behavioral line, no routing/gate logic), tier is known now (`TRIVIAL`) without waiting on the Planner — the Build loop still dispatches the lone Crafter exactly as the TRIVIAL row specifies. If the signal says `TRIVIAL` but the change fails that check, fall through to the full classify apparatus (the signal is stale).

- **PR-feedback entry (checked FIRST, before engine-bind / sentinel / branch)** (a PR URL/`#number`, NL feedback phrasing referencing the PR, a ticket In Review with an open PR carrying unresolved threads, or `--review`) → announce `**[Kiln] This is a review-feedback run — delegating to /process-review-feedback.**` and INVOKE the `process-review-feedback` skill with the resolved entry. Fire is one caller; it does not orchestrate the flow itself. Do NOT bind the engine, write the active-run sentinel, or create a work branch for this entry, and do NOT enter the build lanes.
  **Emit the routing marker for this halt BEFORE stopping** (fire short-circuits here, ahead of the general marker-emit step below, so the REVIEW branch emits its own minimal marker). This is a routing-halt: fire decides the lane and hands off — it never binds an engine, classifies a `scenario_type`, or dispatches a Kiln member, so every value except `lane` and `halt_reason` is `N/A`/empty. The Sifter, Finisher, and SIFT-GATE belong to `/process-review-feedback`'s internal flow, NOT to fire's routing vocabulary — they are never named here (see the marker-grammar `REVIEW` rule below). Emit exactly:
  ```kiln-routing
  lane: REVIEW
  tier: N/A
  blast_radius: N/A
  scenario_type: N/A
  gates_fired: []
  agents_dispatched: []
  agents_skipped: []
  halt_reason: review-feedback entry — delegating to /process-review-feedback; fire routes and hands off, orchestrating no members itself
  ```
  Then relay the skill's final report and STOP Verb 2 here.

**Bind the engine (router — a lookup, not judgment).** Load `engines.md`. Map the resolved scenario → engine per its router table: `code` → compounds; `tool-authoring`/`doc` → native; `mcp/agent-app`/`infra` → compounds but DORMANT (still HALT — do not route this pass). Write the ledger header `ENGINE: <compounds|native> | <ISO>` and **narrate the binding** (why-narration, always on regardless of flow-style):
`[Kiln] <scenario> scenario → <engine> engine bound. <impl driver>; Inspector enforces <verify focus>. engine: <engine>.`
Example: `[Kiln] code scenario → compounds engine bound. implement_task drives impl; Inspector enforces test adequacy. engine: compounds.`

**Announce before any work**, task-kickoff style:
`**[Kiln] This is a <LANE> run, <SCENARIO> scenario — <one-line why>. Starting that path.**`
Sparse → RESEARCH; partial / net-new / design-doc → DESIGN (per `lanes.md`). Only a P2.2 scenario (`mcp/agent-app`/`infra`) or an ambiguous doc shape → **HALT-AND-ASK** (do not guess, do not fall through to code).

**Emit the machine-parseable routing marker (for the eval gate).** Immediately after the prose
announcement, emit a fenced ` ```kiln-routing ` block echoing the decision in this exact key set —
one value per line, lists in `[a, b]` form:
`lane`, `tier`, `blast_radius`, `scenario_type`, `gates_fired`, `agents_dispatched`, `agents_skipped`,
`halt_reason`. **Assert every value that is deterministic at this checkpoint; emit `N/A` only for a value
that genuinely cannot be derived yet.** Concretely:
- On a **build lane** (TRIVIAL/PLAN/EXECUTE) the complexity classification is an *input* to routing, so
  `tier` and `blast_radius` are concrete here — emit them (e.g. `tier: STANDARD`, `blast_radius: LOW`),
  never `N/A`. (Verb 2's "the Planner derives tier + blast" note describes who *authors* them in a live
  run; when the classification is already resolved, the marker records the resolved values.)
- Emit `N/A` for `tier`/`blast_radius` only on a **design-front lane** (DESIGN/RESEARCH), where the
  Designer synthesizes targets and the Planner derives blast only after SPEC-GATE.
- Emit `N/A` for `scenario_type` only when the signal it classifies on is not present — e.g. the change's
  file-path shape (`src/` vs `**/skills/**`, per `scenarios.md`) is not determinable from what routing was
  given. Do not guess a `scenario_type` the inputs do not support.

Re-emit the marker with concrete tier/blast after the Planner's done-line on any design-front lane where
they become known. The keys map 1:1 to `eval/expected/*.json`; this marker is additive telemetry — it
changes nothing about routing behavior (the `eval/README.md` deterministic-at-checkpoint rule).

**Serialization is fixed — the marker records the routing you already decided, it does not re-decide.**
The comparison is exact-string, so the *grammar* below is mandatory even though the *values* remain your
live routing judgment (from `lanes.md`/`gates.md`, never from this list):
- **Member tokens are lowercase and drawn from this closed vocabulary:** `crafter`, `planner`,
  `inspector`, `walker`, `designer`, `scout`, `curator`. Write them lowercase in both `agents_dispatched`
  and `agents_skipped` (`crafter`, never `Crafter`). The Drafter is a real member but is **never** named
  in either list — it is Jira write-back, out of the marker's routing vocabulary.
- **`agents_skipped` is the lane's eligible roster minus what you dispatched — not every member.** A build
  lane (TRIVIAL/PLAN/EXECUTE) draws its roster from `{planner, walker, crafter, inspector}` (plus
  `curator` only once a run reaches close-out); a design-front lane (DESIGN/RESEARCH) draws from
  `{scout, designer, planner}`. Members outside the lane's roster appear in **neither** list — e.g. a
  PLAN/LOW run skips `[walker]` only, not `scout`/`designer`/`curator`. `curator` is listed in
  `agents_dispatched` only on a run you drive through close-out; on a routing-halt it is neither
  dispatched nor skipped.
- **`REVIEW` is a routing-halt lane — a valid `lane` value that dispatches and skips NO members.** A
  PR-feedback entry (Verb 2's first branch) hands off to `/process-review-feedback` before fire binds an
  engine or enters a build lane, so fire runs none of its own members: BOTH `agents_dispatched` and
  `agents_skipped` are `[]`, and `halt_reason` carries the delegation reason (same shape as the
  `HALT-AND-ASK` routing-halt, differing only in that HALT-AND-ASK's roster is the build set it declined
  while REVIEW's roster is empty — fire never owned any member for this entry). The Sifter, Finisher, and
  Diagnostician are `/process-review-feedback`'s agents and SIFT-GATE is its gate; none is a fire member,
  so none is ever named in `agents_dispatched`, `agents_skipped`, or `gates_fired`. (Fire's routing marker
  records only fire's decision; the skill's internal flow is not marker-instrumented — a known follow-up.)
- **`gates_fired` enumerates every gate this run fires that is determinable at this checkpoint — not just
  the gate you are paused at.** Which gates fire is the `gates.md` logic (do not restate it here); the
  serialization rule is completeness: a DESIGN/RESEARCH run lists `[SPEC-GATE, PLAN-GATE]` at the routing
  checkpoint (both are lane-determined and knowable now) even though you have only reached SPEC-GATE. A
  gate that does not block (a LOW-blast TASK-GATE) is **not** "fired." Omit any gate whose firing depends
  on a value still `N/A` at this checkpoint (e.g. a design-front TASK-GATE, blast-dependent, blast unknown).

Worked example — grammar only, values chosen to match no fixture (a HIGH-blast tool-authoring run;
copying it onto any gold scenario mismatches `scenario_type` and fails, so it teaches serialization
without supplying an answer):
```kiln-routing
lane: PLAN
tier: STANDARD
blast_radius: HIGH
scenario_type: tool-authoring
gates_fired: [PLAN-GATE, TASK-GATE]
agents_dispatched: [planner, walker, crafter, inspector]
agents_skipped: []
halt_reason: N/A
```

**Write the active-run sentinel now, stamped with this session's id:**
`printf '%s\n' "$CLAUDE_CODE_SESSION_ID" > {{RUN_FOLDER}}/.active`. (This is what arms the guard hooks.
The stamped session id is what scopes the guards to THIS run: Claude Code runs one Kiln run per
session/window, so a concurrent run in another window — with a different session id — will not bind this
window's guards, and vice-versa. An empty stamp still works but is treated as legacy/unowned. Remove it
in Verb 5.)
**Branch precondition:** the session runs from the non-git workspace, so operate on the TARGET REPO by
path with `git -C <repo>` (`<repo>` = the repo the change targets, e.g. `repos/<name>`, derived from the
plan's file targets or the entry). Run `git -C <repo> symbolic-ref --short HEAD`; if `main`/`master`,
create a work branch. **The `contentful-git-create-branch` skill is the single source of truth for the
name** — its convention is `<type>/<TICKET-KEY>-<short-description>` (NOT the old `kiln/<run-id>`, which
matched no Contentful repo convention). Derive the parts without `cd`-ing into the repo (OS runs from the
workspace root):
- `<type>` from the bound scenario — `doc`→`docs`, `tool-authoring`→`chore`, `code`→`feat` (or `fix` if the
  ticket is a bug). Use the ticket's own type when the Jira issue type makes it unambiguous.
- `<TICKET-KEY>` = the run's Jira key, uppercased (e.g. `EXT-7366`). Keyless net-new run → use the kebab
  run-id slug in the `<short-description>` position and pick `<type>` from the scenario, no key segment.
- `<short-description>` = kebab-case slug from the ticket summary.
Then `git -C <repo> checkout -b <type>/<TICKET-KEY>-<short-description>` (if it already exists, `checkout`
it instead — never overwrite; per the skill's safety rules) and write ledger
`BRANCH: created <branch> (repo: <name>) | <ISO>`. The skill's own `git checkout -b` runs from cwd; here
we substitute `git -C <repo>` for the same effect since the conductor must not `cd`.

**Why-narration (always on, flow-style-independent — spec §5b, pattern E3).** At each routing/engine/gate decision, emit a one-line rationale to the user AND the ledger. Target decision points only — not verbose everything-narration. This is constant regardless of flow-style (the flow-style dials whether a gate *pauses*, not whether the reasoning is *shown*). Examples:
- `[Kiln] STANDARD+LOW blast → Inspector runs lightweight (verify-model relayed), TASK-GATE non-blocking. Advancing on findings-recorded.`
- `[Kiln] STANDARD+MEDIUM blast → Inspector runs full rigor, TASK-GATE blocks, NO Walker. Non-passing verdict → fix loop (cap 2).`
- `[Kiln] STANDARD+HIGH blast → Walker at PLAN-GATE, TASK-GATE blocks. Non-passing verdict → fix loop (cap 2).`

## Verb 3 — Build the spine

Create the `TaskCreate` progress spine — one task per phase this lane will run (e.g. Drafter (initial write, DESIGN/RESEARCH lanes) → PLAN-GATE → Walker (if HIGH) → per-task Crafter/Inspector → Drafter (completion sync) → Curator (FINAL)). This is the conductor's visible state; it is the fix for "no todo list, wall of text."
**Immediately after the spine exists:** `touch {{RUN_FOLDER}}/.spine`. (The spine guard denies any dispatch before this file exists.)

## Verb 4 — Dispatch

Load `dispatch-contracts.md`. Dispatch the right member with the four-part contract, passing `{{SCENARIO}}` into Crafter/Inspector/Walker dispatches. Sequence by lane (per `lanes.md`):
- **RESEARCH:** Scout → Designer (dialogue loop, below) → SPEC-GATE → Planner → PLAN-GATE → Build loop.
- **DESIGN:** Designer (dialogue loop) → SPEC-GATE → Planner → PLAN-GATE → Build loop. Net-new: propose a
  kebab-slug run-id and confirm via `AskUserQuestion` (a conductor step, not a member relay — permitted;
  see Verb 1) — if the user proposes a different slug, use theirs; do NOT offer a Jira ticket (P2.2).
  Design-doc mid-flow: pass the incoming design.md into dispatch #1 for confirm-and-convert.
- **Designer dialogue loop (Approach A):** repeat until the Designer returns `DESIGNER_DONE` — dispatch #N →
  if the done-line is `DESIGNER_NEEDS_INPUT`, render its `## Questions` block via `AskUserQuestion`
  (main thread; ≤4) and re-dispatch with the answers pasted into Part 3; if it is `DESIGNER_DONE`, stop.
  The Designer self-caps at ≤2 question batches (so at most 3 dispatches). This is the ONLY MEMBER
  interaction where the conductor calls AskUserQuestion; it relays each batch verbatim and authors no
  design content. (The Verb 1 slug confirm above is a separate conductor housekeeping step, not a
  member relay.)
- **EXECUTE:** drift-check → Planner(register existing plan) → Build loop. The drift-check is NOT a member dispatch (there is no drift-check contract) — the conductor runs it inline: read-only Jira read + local file-existence checks per `lanes.md`. Material drift → STOP and recommend re-planning.
- **PLAN:** Planner → PLAN-GATE → (Walker if HIGH blast) → Build loop.
- **Build loop (per task):** write `brief-N.md` (merge the task's entry from the Planner-produced `{{RUN_FOLDER}}/tasklist.md` — INCLUDING its `### Enriched context` subsection — + prior-task interfaces + `scenario:` + the bound `engine:`). Derive `{{SLUG}}` for this task NOW, from its `tasklist.md` title (kebab-case, ~5 words) — see `dispatch-contracts.md`'s filename note — and reuse the SAME slug in both this task's Crafter and Inspector dispatch (the report/verdict filenames must match between them). Dispatch Crafter, then Inspector (per `gates.md` tier×blast rules). The conductor reads `tasklist.md`; it never calls Compounds itself (the guard denies it). **Model relay (two values):** read the task's `- **Impl model:**` and `- **Verify model:**` bullets from `tasklist.md`. Pass the Impl-model as the `Agent` `model` param for the Crafter; pass the Verify-model as the `model` param for the Inspector. **Walker model (run-level, not per-task):** the Walker runs once at PLAN-GATE over the whole plan (it has no bound task), so relay the **highest Impl-model across all tasks in `tasklist.md`** (rank `opus` > `sonnet` > `haiku`) — it reviews the whole plan and should match the most-capable task's rigor. If a bullet is malformed (not one of `haiku`/`sonnet`/`opus`), omit that member's `model` param — it runs on its frontmatter floor. Also pass `engine: <compounds|native>` (bound in Verb 2) into the Crafter and Inspector dispatches, and pass `tier: <TRIVIAL|STANDARD>` (from the Planner's done-line; on TRIVIAL it is fixed) into the Crafter dispatch — the Crafter reads it to select its finalize step (TRIVIAL → Crafter self-finalizes: compounds via the `start_trivial` terminal `create_project(status="DONE")`, native via the commit only; STANDARD → Inspector finalizes). Pass `blast: <LOW|MEDIUM|HIGH>` (from the Planner's done-line) into the Inspector dispatch — the Inspector reads it to select its finalize condition (LOW → finalize regardless of verdict, findings advisory; MEDIUM/HIGH → finalize only on a passing verdict). Dispatch the Walker ONLY on HIGH blast (MEDIUM does not run the Walker). **TRIVIAL lane:** no Planner runs, so no bullets to relay — dispatch the lone Crafter on `model: haiku` (the rubric's TRIVIAL row, a fixed constant) with `tier: TRIVIAL`. The conductor never exercises per-task model *judgment*: it relays the Planner's typed recommendations, and where no Planner runs it applies the lane's fixed default.

## Verb 5 — Adjudicate & advance

Read each member's done-line + return artifact. Update the spine (`TaskUpdate`). Evaluate gates mechanically from typed fields (load `gates.md`):
- **SPEC-GATE** (after Designer, DESIGN/RESEARCH lanes): present `spec-draft.md`; per flow-style, pause for
  explicit approval.
  On rejection or a change request at THIS pause: do NOT write `approved` and do NOT dispatch the
  Drafter or the Planner; re-dispatch the Designer with the feedback and re-present at SPEC-GATE.
  On explicit approval, write ledger `SPEC-GATE: approved | <ISO>`. If `{{FORMAT_CACHE_PATH}}` is
  `none` or **stale** — absent, no `skeleton_version:` line, or a `skeleton_version` other than `1`
  (the Drafter's own staleness rule, `agents/drafter.md` § Format resolution) — fetch 3–5 recent
  ticket keys from {{JIRA_KEY}}'s project (`mcp__jira__searchJiraIssuesUsingJql`) to pass as
  `{{SIBLING_KEYS}}` (else pass `none` — the Drafter holds no search tool). Then dispatch the **Drafter**
  (initial write — load the Drafter Dispatch Template; pass spec-draft.md, target `update {{JIRA_KEY}}`,
  tasklist.md if it exists yet else "none", the current Jira children, the sibling keys, and the
  ledger; NO approval fields — this is Phase 1). It returns `DRAFTER_AWAITING_APPROVAL: <bundle>`; present `<bundle>/diff.md`
  for approval (R1; this approval is unconditional — it holds under every flow-style, including
  `hands_free`).
  On rejection or a change request AT THE DRAFTER'S DIFF: do NOT write `approved` and do NOT dispatch
  the Planner; re-dispatch the Drafter (Phase 1, NOT Phase 2) with the feedback and re-present the new
  bundle's `diff.md` at this same pause. Repeat until approved (see `gates.md` § DRAFTER-APPROVAL).
  ONLY on explicit approval of the diff, re-invoke the Drafter (Phase 2) with `APPROVAL=granted`,
  `APPROVED_BUNDLE=<bundle>`, and the same target. On `DRAFTER_DONE`/`DRAFTER_NOOP`, write ledger
  `DRAFTER: initial write {{JIRA_KEY}} | <ISO>`. On `DRAFTER_BLOCKED`, surface and HARD STOP (a
  keyless/personal run with no Jira target skips the Drafter — record `DRAFTER: skipped (keyless)`).
  Then dispatch the Planner.
- **PLAN-GATE:** present `plan.md` (+ `walkthrough.md` if HIGH); per flow-style, pause for explicit approval. Write ledger `PLAN-GATE: approved | <ISO>`.
  On rejection or a change request: do NOT write `approved` and do NOT start the Build loop; re-dispatch
  the Planner with the feedback and re-present at PLAN-GATE.
- **TASK-GATE** (the MEMBER always finalizes — the conductor never calls a Compounds mutation verb inline; the guard denies it. On STANDARD the **Inspector** finalizes: compounds → `implement_task_finalize` with verdict evidence, native → `update_task`. On TRIVIAL the **Crafter** already marked it done. The conductor's own action is the `TaskUpdate` on the spine plus writing the per-task ledger line `DONE: task N | engine: <compounds|native> | <ISO>`.):
  - **MEDIUM or HIGH blast (gate blocks):** conductor reads the verdict — `spec: ✅` AND `quality: approved` → the Inspector finalizes and the run advances. Else fix loop (cap 2) → escalate (revert task commits, HARD STOP, leave sentinels for resume).
  - **LOW blast (gate does NOT block):** the Inspector finalizes regardless of verdict (findings are advisory); the run always advances. No fix loop at LOW.
- **Context-preservation yield (all gates, every flow-style — see `gates.md`).** When the workspace
  reset-nudge appears in your context (the "invoke the context-economy skill lever router" message),
  record `NUDGE-SEEN: <ISO>` in `progress.md` once. Thereafter, at the NEXT gate boundary (SPEC/PLAN/
  TASK), before advancing: invoke `context-economy:handoff` to write `{{RUN_FOLDER}}/handoff.md`
  (narrative; it points to `progress.md` for task state), write ledger `YIELD: context-preservation at
  <gate>, task <N/total> | <ISO>`, then END YOUR TURN with a status line: the checkpoint phase/task
  and "Context is high — checkpointed. Run `/clear`, then `/kiln <run-id>` to resume in a fresh
  session." Do NOT auto-`/clear`. If the run reaches `COMPLETE` before the next gate, finish normally.

**On completion:** if this run did an initial Drafter write (a `DRAFTER: initial write` ledger entry
exists; DESIGN/RESEARCH keyed lanes), dispatch the **Drafter** once more for a completion sync;
otherwise skip the completion sync and go to the Curator dispatch (below). Completion sync — same
template, `{{CHECKPOINT}}` = completion, NO approval fields (re-fetch and pass the current Jira
children); it reconciles the final plan against the ledger. If it returns `DRAFTER_NOOP`, nothing
changed since the initial write — record and move on. If it returns `DRAFTER_AWAITING_APPROVAL: <bundle>`,
present `<bundle>/diff.md` for approval (R1; this approval is unconditional — it holds under every
flow-style, including `hands_free`).
On rejection or a change request: re-dispatch the Drafter (Phase 1) once more with the feedback and
re-present the new bundle's `diff.md`. If rejected or cancelled a SECOND time, do NOT hard-stop — the
build is already complete — record ledger `DRAFTER: completion sync skipped (rejected) | <ISO>` and
proceed to the Curator (same as the `DRAFTER_BLOCKED` handling below; see `gates.md` §
DRAFTER-APPROVAL).
ONLY on approval re-invoke the Drafter (Phase 2) with
`APPROVAL=granted`, `APPROVED_BUNDLE=<bundle>`, same target. Write ledger `DRAFTER: completion sync |
<ISO>`. If it returns `DRAFTER_BLOCKED`, do NOT hard-stop — the build is already complete, so surface the
reason, record ledger `DRAFTER: completion sync skipped (blocked: <reason>) | <ISO>`, and proceed to the
Curator. A keyless run skips this. THEN dispatch the Curator (below): load the Curator
Dispatch Template from `dispatch-contracts.md` and dispatch the Curator once, filling `{{TARGET_REPO}}`
(the repo the run targeted), `{{COMPOUNDS_PROJECT}}` (the project id from the Planner's run, or "none"
on native), `{{JIRA_KEY}}`, `{{ENGINE}}`, and `{{COMMIT_RANGE}}`. The Curator holds the Compounds-close
and Jira-write grants the conductor cannot call. Branch on its typed return:
- `CURATOR_DONE` → `TaskUpdate` the FINAL spine task to done; write the terse ledger `COMPLETE: <ISO>`
  entry (P3 expands the retro); **retire the sentinels, preserving cost attribution:** first carry the session id forward —
  `mv {{RUN_FOLDER}}/.active {{RUN_FOLDER}}/.completed` (if `.active` is absent because a prior
  session already retired it, leave any existing `.completed` untouched) — then `rm -f
  {{RUN_FOLDER}}/.spine`. The `.completed` marker retains the session id so The Smith can still join
  cost after the run ends; it does NOT arm the guard hooks (those key on `.active` only), so a
  completed run is correctly un-guarded.
- `CURATOR_BLOCKED` → surface the `{{RUN_FOLDER}}/verify.md` evidence to the user, leave the FINAL spine
  task `in_progress`, HARD STOP, and **leave the sentinels in place** for resume. The Curator stopped at
  the first failing stage; side-effects BEFORE that stage may already have completed (verify.md records
  the actual state — e.g. Compounds may be closed, or a PR may already exist). Do not assume a clean
  slate — resume reads verify.md and continues from the failed stage.

## Resume

On re-invoke with `{{RUN_FOLDER}}/.active` present: read `progress.md` (task state — source of truth) and `handoff.md` if present (narrative context from a context-preservation yield), find the first task without a `DONE`, re-create the spine (Verb 3), and continue the Build loop from there. A `YIELD:` ledger entry with no later `DONE` marks exactly where the previous session stopped.

A `CURATOR_BLOCKED` ledger entry with no later `COMPLETE:` means the run stopped in close-out — resume
by re-dispatching the Curator (re-verify), NOT the Build loop; all tasks are already DONE. Likewise a
run whose every task has a `DONE` line but no `COMPLETE:` resumes at the Curator.

**Re-stamp ownership first:** `/clear` mints a NEW session id, so a resumed run's sentinel still carries
the *previous* session's id (or is empty/legacy) and the guards would treat this window as non-owning.
Immediately re-stamp with the current session: `printf '%s\n' "$CLAUDE_CODE_SESSION_ID" > {{RUN_FOLDER}}/.active`.
(A lone unowned run is claimable this way by design — the resolver binds a single unowned run so resume
is never orphaned; re-stamping makes ownership explicit and keeps a concurrent second run isolated.)
