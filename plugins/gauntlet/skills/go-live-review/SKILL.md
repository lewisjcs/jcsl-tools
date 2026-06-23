---
name: go-live-review
description: Use when deciding whether a change is safe to merge and turn on for real users — a feature flag/gate removal, an enforce-flip, a kill-switch, a GA, or any user-visible/contract-breaking production change. Trigger phrases include "is this safe to ship", "ready to go live", "ok to merge this for", "go-live review", "prod readiness", "should we ship this", "merge on their behalf", or when the gauntlet routes a go-live-signal PR here.
---

# Go-Live Review

A go-live carries risk that does **not** live in the diff: whether the rollback path survives, whether a production precondition is actually provisioned, who owns the change after merge. This skill is a readiness review that **reaches outside the repo** to answer "should we *actually* ship this?" — separate from "is the code correct?" (that is `/gauntlet`).

## Core principle

**A go-live review that only reads the diff is worthless.** The deciding facts live in the linked ticket's acceptance criteria, the rollout doc, the entitlement/flag state, and the team — not in the code. Read those, or you will rubber-stamp a breaking change. (Calibration finding: reviews that skipped the ticket fetch ran materially shallower and one approved an unsanctioned breaking change; reviews that fetched the ticket and checked the diff against its acceptance criteria caught it.)

## When to use

- A PR/change removes a feature flag, gate, kill-switch, or fallback; flips shadow→enforce; GAs a feature; or breaks a contract (status code, response shape, auth scope).
- The gauntlet's go-live pre-filter matched and you opted into this lane.
- Someone asks "is this safe to merge / turn on", especially merging on an absent author's behalf.

**When NOT to use:** routine code review (`/gauntlet`), security-only review (`/security-gauntlet`), or dark/flag-gated feature *construction* that ships nothing live (that is normal review — introducing a flag is not a go-live).

## The review — six steps, each ends in a check

Work read-only. Do every step; the value is in the steps a diff-only review skips.

### 1. Establish what is going live (and confirm it IS a go-live)
Read the diff + PR body. State in one line what turns on / what safety mechanism is removed.
**Check:** if nothing actually goes live (a flag is *introduced*, feature stays dark), STOP and say so — this is not a go-live, route to `/gauntlet`.

### 2. Fetch the linked ticket and rollout doc — verify the diff against them
Extract the ticket key from the PR/branch. Fetch it (Jira MCP) and read its **acceptance criteria** and **rollout preconditions**. Search Glean (Confluence/Slack) for a rollout plan or deployment runbook covering this change.
**Check:** list each AC and rollout precondition, and mark whether the diff satisfies it or diverges. A divergence from an AC (e.g. ticket says "no new gate on path X", diff adds one) is a **HOLD**. If no ticket/rollout doc exists, record that as a NEEDS-INFO gap — do not assume.

### 2b. Confirm staging/prod verification actually happened — not just that it was planned
A checked test-plan box or a green CI run proves the code works in CI, not that the change was verified in the target environment. Look for **evidence** the staged rollout occurred: a deploy record, a "verified in staging" thread, a rollout-monitoring note, or release-pipeline confirmation.
**Check:** cite the evidence that verification happened, or mark NEEDS-INFO. "Test plan checkbox is checked" / "CI is green" is NOT verification evidence — say so and treat the dimension as unconfirmed.

### 3. Confirm the production precondition is real — against external state, not the diff
The change usually depends on something being true in prod: an entitlement provisioned, a flag targeted, a sibling service deployed. Identify that precondition and verify it against Glean/Jira/config — **never assert it from memory or from the PR body's say-so.**
**Check:** state the precondition and the source that confirms (or fails to confirm) it. Unconfirmable precondition → NEEDS-INFO, not SHIP. (This is the dimension diff-only reviews miss most.)

### 4. Rollback path
With the flag/gate removed, what is the revert path? Is there a kill switch left, or is redeploy-the-previous-build the only option?
**Check:** name the concrete rollback mechanism. "Revert the PR" is not a rollback plan for a change that altered production data or removed the only gate — say so.

### 5. Ownership after merge + coordination
Who owns this once merged and handles an incident — especially if the author is out? Must this land atomically with sibling PRs/services, or does merging it alone half-ship the feature?
**Check:** name the post-merge owner (or flag its absence), and list any sibling PR/service that must land together (or confirm none).

### 6. Blast radius + contract-break comms
Who is affected — internal-developer orgs only, or external customers? For a behavioral/contract break (e.g. 404→403, token-scope narrowing), are downstream consumers identified and warned?
**Check:** state the audience and, for any contract break, whether consumers are notified.

## Verdict

Emit exactly one, in the fenced block below:

- **SHIP** — every step's check passes; precondition confirmed; rollback + owner known.
- **HOLD** — a check found a real problem (AC divergence, removed gate with no rollback, unwarned contract break).
- **NEEDS-INFO** — a load-bearing fact could not be confirmed (precondition unverifiable, no owner, no rollout record). Default here over SHIP when unsure: an unconfirmed go-live is not a go SHIP.

## Output — fenced, point-in-time zone

A go-live review reads external state that **drifts**, so its verdict is point-in-time, not reproducible like a code review. Render it in its own fenced block and **never fold it into a gauntlet `blocker/concern/nit` count or its `reviewed-at-SHA` machine block** — keep the calibrated code-review signal clean.

```
## 🚀 Go-Live Readiness — <SHIP | HOLD | NEEDS-INFO> (as-of <UTC timestamp>)

**Going live:** <one line: what turns on / what gate is removed>

| Step | Finding | Status |
|---|---|---|
| Ticket/AC match | <diff vs each AC> | ✅/⚠️/❓ |
| Prod precondition | <precondition + confirming source> | ✅/⚠️/❓ |
| Rollback path | <concrete mechanism> | ✅/⚠️/❓ |
| Ownership / coordination | <post-merge owner; sibling PRs> | ✅/⚠️/❓ |
| Blast radius / comms | <audience; consumer notification> | ✅/⚠️/❓ |

**Verdict: <SHIP | HOLD | NEEDS-INFO>** — <one-line reason>
<if HOLD/NEEDS-INFO: numbered list of exactly what must be resolved before shipping>
```

## Red flags — you are about to ship a shallow review

- You wrote a verdict without fetching the linked ticket. → Do step 2.
- You accepted a production precondition because the PR body or a test stub asserted it. → Do step 3 against external state.
- You marked SHIP with any ❓ in the table. → A ❓ is NEEDS-INFO, never SHIP.
- The change removes a gate and you did not name the rollback path. → Do step 4.
- The author is out and you did not name who owns it after merge. → Do step 5.

## Trigger (gauntlet-dispatched mode)

The gauntlet routes a PR here when its calibrated pre-filter matches (any of: status/contract change, auth/entitlement change, breaking change, flag removal, terminal rollout language, SDK major release). The prompt is an opt-in nudge, not an auto-run — see `projects/active/gauntlet/2026-06-08-golive-review-design.md` §4.2 and the calibration in `test-dataset/golive/`. `flag_introduction` is deliberately NOT a trigger (it marks dark prep, not a go-live).
