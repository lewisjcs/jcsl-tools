---
name: process-review-feedback
description: Use when acting on the review feedback left ON A PULL REQUEST — "process the review feedback on the PR", "the reviewer left comments on the PR", "address the review comments on PR #123", a PR URL, or `/kiln:fire <KEY> --review`. Resolves the PR, sifts each unresolved review thread against the codebase, gates the disposition with you, routes accepted fixes through the build loop, and responds on the PR. This is the ORCHESTRATED pipeline for a concrete PR — NOT the general receiving-code-review discipline (that skill teaches how to evaluate any feedback), and NOT general PR review authoring.
argument-hint: <PR-URL | #number --repo <owner/repo> | TICKET-KEY [--review]>
---

# process-review-feedback — act on a PR's review threads

Intakes the unresolved review threads on a pull request, judges each against the codebase, gates the
disposition with you, routes accepted fixes through the Kiln build loop, and responds on the PR. This
skill is a thin mini-conductor; the Sifter and Finisher agents do the work. Structurally a sibling of
`/spec-ticket`.

## Step 0 — Resolve the PR (never guess)
Determine the target PR, in this order:
1. If a PR URL or `#<number>` (+ `--repo`) was given, that is the PR.
2. Else if an active `{{RUN_FOLDER}}` exists for the referenced key, use its recorded PR.
3. Else if a ticket key was given, `gh pr list --search "<KEY>" --state open` for its branch.
4. Else `AskUserQuestion` for the PR.
If no open PR is found, OR the PR has no unresolved review threads → **HALT-AND-ASK** (announce
"No open PR with unresolved review threads — nothing to process." and stop). Never guess a PR.

**Disambiguation:** "address the feedback" is THIS skill only when an open PR with unresolved threads
exists; otherwise it is not (design feedback → brainstorming/spec, not here).

## Step 0b — Resume vs. bootstrap (run-folder convention shared with /kiln:fire)
Use fire's run-folder path scheme and ledger format so a fire-authored run and a standalone run
resume interchangeably. `{{RUN_FOLDER}} = <WORKSPACE>/projects/active/<run-id>/kiln/` (fire's scheme).
Also resolve `{{TARGET_REPO}}` NOW (the absolute path the fixes commit into and the Finisher pushes) —
derive it from the resolved PR's head repo/branch (`gh pr view --json headRepository,headRefName`),
matching the Curator's `git -C {{TARGET_REPO}}` convention; the conductor never `cd`s. Then ensure the
PR's head branch is checked out in `{{TARGET_REPO}}` before any fix commits (`git -C {{TARGET_REPO}}
checkout <headRefName>`); the REVIEW flow reworks an EXISTING branch, so it never creates a new one.
If `{{TARGET_REPO}}` is not a local clone (a truly external PR you cannot push to) → **HALT-AND-ASK**.
- **Resume** — a `{{RUN_FOLDER}}` already exists for this key: reuse its `plan.md`, `task-*-verdict.md`,
  and `engine:` binding; append `sift.md`; reuse the ledger. A `SIFT-GATE: approved` ledger line with no
  later `FINISHER_DONE` means resume at per-comment routing / Finisher, not the Sifter — BUT first
  re-fetch the PR's unresolved threads and compare against `sift.md`: if any unresolved thread is absent
  from `sift.md` (a comment posted after the prior gate), re-dispatch the Sifter for the new threads and
  re-run SIFT-GATE before routing. Never skip the Sifter on stale disposition data.
- **Bootstrap** — no run folder (external/hand-authored PR): create the folder, re-derive `engine:`
  from the PR diff paths via `skills/fire/scenarios.md` (no ticket needed), skip planning (work is
  comment-driven). Write ledger `LANE: REVIEW (bootstrap)`.

**Arm the guard before Step 1 (both paths).** Reusing fire's build loop means reusing its guard: the
main-thread guards (`kiln-guard-conductor.sh`, `kiln-guard-spine.sh`) arm ONLY when a session-owned
`{{RUN_FOLDER}}/.active` sentinel exists, and the spine guard then denies every dispatch until
`{{RUN_FOLDER}}/.spine` exists. So, in this exact order, before dispatching the Sifter:
1. **Stamp `.active` with this session:** `printf '%s\n' "$CLAUDE_CODE_SESSION_ID" > {{RUN_FOLDER}}/.active`.
   On **resume**, `/clear` mints a new session id, so re-stamp unconditionally (the sentinel may carry a
   prior session's id or be empty/legacy) — mirrors fire's resume re-stamp convention.
2. **Create the progress spine** (`TaskCreate`: Sifter → SIFT-GATE → routed fixes → Finisher), then
   **`touch {{RUN_FOLDER}}/.spine`**. Without the sentinel the guard fails open (the conductor could edit
   shipped source inline instead of routing through the Crafter); without the spine-after-sentinel order
   the spine guard would deny the Sifter dispatch itself. Retire the sentinels at COMPLETE (Step 4):
   `mv {{RUN_FOLDER}}/.active {{RUN_FOLDER}}/.completed`.

## Step 1 — Dispatch the Sifter (read-only intake)
Dispatch the `sifter` agent (Agent tool, `subagent_type: sifter`) with the resolved PR
(`owner`/`repo`/`pullNumber`), `{{RUN_FOLDER}}`, and — on resume — the prior `plan.md`/`verdict` paths.
The Sifter writes `{{RUN_FOLDER}}/sift.md` and returns `SIFTER_DONE: ... | accept, push-back, clarify, diagnose`.
Read `sift.md` directly.

## Step 2 — SIFT-GATE (human veto/approve)
Render the `sift.md` disposition batch via `AskUserQuestion`. For an `accept` + `trivial` (which Step 3
routes past the Inspector), surface the RAW comment text and cited `file:line` diff at the gate — not
only the Sifter's paraphrased `reason` — so the human approves the actual change, not a summary of it.
The human may:
- **veto** an `accept` (drop it — no fix runs),
- **override** a `push-back` (force it to `accept` — routes as a fix; the human supplies the `weight`,
  defaulting to `standard` if unspecified),
- **answer** a `needs-clarification` inline (re-routes it to accept/push-back per the answer; a
  re-routed accept takes the human-supplied `weight`, default `standard`),
- **approve or defer** each `needs-diagnosis` (in this release approved needs-diagnosis still
  DEFERS-WITH-A-NOTE — the Diagnostician arrives in Plan B; record the approved `reply_draft`).

**Persist every gate decision back into `sift.md` before Step 3 (the routing table and the Finisher
both read `sift.md` as the source of truth — an un-amended entry routes on the pre-gate proposal).**
After the human responds, rewrite each affected entry so the file reflects the DECIDED state:
- vetoed accept → `verdict: vetoed` (Step 3 routes it nowhere; no fix, no reply),
- overridden push-back → `verdict: accept` with the decided `weight`,
- resolved needs-clarification → `verdict: accept` (+`weight`) or `verdict: push-back` per the answer,
- approved reply (push-back / deferred needs-clarification / needs-diagnosis) → add `reply_approved: true`
  so the Finisher posts ONLY entries carrying that flag.
Append ledger `SIFT-GATE: approved | <ISO>` on approval.

Per flow-style: `guided` (default) pauses for approval. `hands_free` auto-approves the Sifter's
CODE dispositions (which fixes run) — but SIFT-GATE's OUTWARD writes are NEVER auto-approved: every
`reply_draft` (push-back and needs-clarification/diagnosis replies) still requires an explicit human
approve, even under `hands_free` (per-action outward consent — `feedback_outward_facing_edit_consent_scope`).
Under `hands_free` with no human present, unapproved replies stay `reply_approved: false` and the
Finisher surfaces them as deferred rather than posting. On reject, re-dispatch the Sifter with the
feedback and re-present.

**Reply discipline enforced HERE:** an accepted-fix acknowledgment is a 👍 reaction ONLY (no text); a
push-back reply is the Sifter's `reply_draft`, and posting it requires explicit approval at THIS gate
(per-action outward consent). The Finisher posts nothing not carrying `reply_approved: true`.

## Step 3 — Per-comment routing (after SIFT-GATE approval)
Driven by the AMENDED `sift.md` `verdict` + `weight`, reusing the existing Crafter→Inspector build loop:

| Verdict + weight | Route | Outcome |
|---|---|---|
| `vetoed` | no code, no reply | dropped at gate |
| `accept` + `trivial` | Crafter `tier: TRIVIAL` (fixup commit), no Inspector | 👍 reaction (Finisher) |
| `accept` + `standard` | Crafter → Inspector, `blast: MEDIUM` | 👍 reaction (Finisher) |
| `accept` + `substantial` | Crafter → Inspector, `blast: HIGH` (Inspector rigor + block + fix-loop; NO Walker) | 👍 reaction (Finisher) |
| `push-back` | no code | approved reply (Finisher) |
| `needs-clarification` (resolved at gate) | re-route per answer | as above |
| `needs-clarification` (deferred) | no code | reply draft surfaced, not auto-posted |
| `needs-diagnosis` (approved at gate) | no code — deferred with a note (this release) | approved reply (Finisher) |
| `needs-diagnosis` (deferred at gate) | no code | reply draft surfaced, not auto-posted |

**Per-fix brief (Inspector precondition).** A `standard`/`substantial` accept routes through the
Inspector, whose contract reads `{{RUN_FOLDER}}/brief-N.md` — but this flow runs no Planner, so no brief
exists. Before dispatching the Crafter for such a fix, the conductor writes a minimal
`{{RUN_FOLDER}}/brief-<commentId>.md`: the raw comment text, its `file:line`, the Sifter's `reason` as
the single acceptance criterion, and `engine:`/`scenario:`. Pass that path (and the SAME `{{SLUG}}`) to
both the Crafter and the Inspector, exactly as the build loop pairs them. A `trivial` accept skips the
Inspector, so it needs no brief. Pass `{{TARGET_REPO}}` into every Crafter fix dispatch (the fix commits
into that repo — `git -C {{TARGET_REPO}}`).

Relay `blast:` into each fix's Inspector dispatch exactly as the build loop does (`dispatch-contracts.md`
Crafter/Inspector templates). **This flow NEVER dispatches the Walker** regardless of mapped blast —
there is no plan / no PLAN-GATE. Record `DONE: comment <id>` in the ledger as each lands.

## Step 4 — Dispatch the Finisher (gated outward writes)
After all routed fixes land, dispatch the `finisher` agent (`subagent_type: finisher`) with the PR,
`{{TARGET_REPO}}` (the repo it pushes — resolved in Step 0b), the amended `sift.md` dispositions, and the
per-comment landed-commit map. On `FINISHER_DONE` write ledger `COMPLETE:` and retire the sentinels
(`mv {{RUN_FOLDER}}/.active {{RUN_FOLDER}}/.completed`); on `FINISHER_BLOCKED` HARD STOP with `.active`
preserved for resume.

## Step 5 — Report
Relay the Sifter counts, what was fixed, what was pushed back, and the Finisher's outcome. Do NOT
transition Jira and do NOT close Compounds — the PR already exists (that was the Curator's job on the
forward pass).

## Notes
- Sifter is read-only; only the Finisher posts, and only what SIFT-GATE approved.
- `needs-diagnosis` defers-with-a-note in this release; Plan B adds the Diagnostician member.
- Never write "Kiln"/member names into PR comment content (neutral technical wording only).
