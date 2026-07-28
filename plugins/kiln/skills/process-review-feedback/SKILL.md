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
resume interchangeably.
- **Resume** — a `{{RUN_FOLDER}}` already exists for this key: reuse its `plan.md`, `task-*-verdict.md`,
  and `engine:` binding; append `sift.md`; reuse the sentinel/ledger. A `SIFT-GATE: approved` ledger
  line with no later `FINISHER_DONE` means resume at per-comment routing / Finisher, not the Sifter.
- **Bootstrap** — no run folder (external/hand-authored PR): create the folder, re-derive `engine:`
  from the PR diff paths via `skills/fire/scenarios.md` (no ticket needed), skip planning (work is
  comment-driven). Write ledger `LANE: REVIEW (bootstrap)`.

## Step 1 — Dispatch the Sifter (read-only intake)
Dispatch the `sifter` agent (Agent tool, `subagent_type: sifter`) with the resolved PR
(`owner`/`repo`/`pullNumber`), `{{RUN_FOLDER}}`, and — on resume — the prior `plan.md`/`verdict` paths.
The Sifter writes `{{RUN_FOLDER}}/sift.md` and returns `SIFTER_DONE: ... | accept, push-back, clarify, diagnose`.
Read `sift.md` directly.

## Step 2 — SIFT-GATE (human veto/approve)
Render the `sift.md` disposition batch via `AskUserQuestion`. The human may:
- **veto** an `accept` (drop it — no fix runs),
- **override** a `push-back` (force it to `accept` — routes as a fix),
- **answer** a `needs-clarification` inline (re-routes it to accept/push-back per the answer),
- **approve or defer** each `needs-diagnosis` (in this release approved needs-diagnosis still
  DEFERS-WITH-A-NOTE — the Diagnostician arrives in Plan B; record the approved `reply_draft`).
Per flow-style: `guided` (default) pauses for approval; `hands_free` auto-approves the Sifter's
disposition. On reject, re-dispatch the Sifter with the feedback and re-present. Write ledger
`SIFT-GATE: approved | <ISO>` on approval.

**Reply discipline enforced HERE:** an accepted-fix acknowledgment is a 👍 reaction ONLY (no text); a
push-back reply is the Sifter's `reply_draft`, and posting it requires explicit approval at THIS gate
(per-action outward consent). The Finisher posts nothing not approved here.

## Step 3 — Per-comment routing (after SIFT-GATE approval)
Driven by `sift.md` `verdict` + `weight`, reusing the existing Crafter→Inspector build loop:

| Verdict + weight | Route | Outcome |
|---|---|---|
| `accept` + `trivial` | Crafter `tier: TRIVIAL` (fixup commit), no Inspector | 👍 reaction (Finisher) |
| `accept` + `standard` | Crafter → Inspector, `blast: MEDIUM` | 👍 reaction (Finisher) |
| `accept` + `substantial` | Crafter → Inspector, `blast: HIGH` (Inspector rigor + block + fix-loop; NO Walker) | 👍 reaction (Finisher) |
| `push-back` | no code | approved reply (Finisher) |
| `needs-clarification` (resolved at gate) | re-route per answer | as above |
| `needs-clarification` (deferred) | no code | reply draft surfaced, not auto-posted |
| `needs-diagnosis` (approved at gate) | no code — deferred with a note (this release) | approved reply (Finisher) |
| `needs-diagnosis` (deferred at gate) | no code | reply draft surfaced, not auto-posted |

Relay `blast:` into each fix's Inspector dispatch exactly as the build loop does (`dispatch-contracts.md`
Crafter/Inspector templates). **This flow NEVER dispatches the Walker** regardless of mapped blast —
there is no plan / no PLAN-GATE. Record `DONE: comment <id>` in the ledger as each lands.

## Step 4 — Dispatch the Finisher (gated outward writes)
After all routed fixes land, dispatch the `finisher` agent (`subagent_type: finisher`) with the PR, the
approved `sift.md` dispositions, and the per-comment landed-commit map. On `FINISHER_DONE` write ledger
`COMPLETE:` and remove sentinels; on `FINISHER_BLOCKED` HARD STOP with sentinels preserved for resume.

## Step 5 — Report
Relay the Sifter counts, what was fixed, what was pushed back, and the Finisher's outcome. Do NOT
transition Jira and do NOT close Compounds — the PR already exists (that was the Curator's job on the
forward pass).

## Notes
- Sifter is read-only; only the Finisher posts, and only what SIFT-GATE approved.
- `needs-diagnosis` defers-with-a-note in this release; Plan B adds the Diagnostician member.
- Never write "Kiln"/member names into PR comment content (neutral technical wording only).
