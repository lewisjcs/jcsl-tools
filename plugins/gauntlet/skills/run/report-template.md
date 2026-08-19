# Gauntlet Report Templates — Zone 1 (report file) & Zone 2 (postable comment)

Load this file **only when Phase 4b begins** (writing the report file). The orchestrator does not need this content to run Phases 0–3, Phase 4a, or Phase 4c–4d — it is the report-rendering template, consumed once per run at report-write time.

Authoritative source: the gauntlet master spec §4.1 (report shape) / §4.4 (critical classification) / the Zone-1/Zone-2 bright-line. This file is the operational extract; if the two ever disagree, the master spec wins.

---

Write the file with TWO zones. **Bright-line: Zone 1 vocabulary never appears in a teammate-facing surface; only Zone 2 is postable.**

````markdown
# Gauntlet Report

**Artifact:** <path or PR URL>
**Type:** <code-pr | code-local | plan | doc | skill | multi>
**Reviewed ref:** <from Phase 4a — base ← head@sha, or path@blob>
**Reviewed at:** <ISO 8601 timestamp>

[OPTIONAL header callout if Phase 2 failed: ⚠️ Security pass failed — manually run /security-gauntlet or escalate to AppSec.]
[OPTIONAL trust-signal footer line from Phase 3's disproof-rate check (at most one: HIGH or LOW band).]

## Required Changes

[Only present if critical[] non-empty. Each entry: location, claim, severity, confidence, recommendation. NO truncation — the user is making a ship/no-ship call. **Adversarial-lane-failure blocker (`code-pr`/`code-local` only, per run/SKILL.md Phase 3 substep 6):** when adversarial-review's Phase 1 status is `⚠ failed`, its synthetic blocker entry renders FIRST, with `location: N/A — lane failure` in place of a `file:line` — everything else about the entry (claim, severity, recommendation) renders like any other Required Changes row.]

## Findings (ranked, by severity × confidence)

[All surviving findings not in Required Changes. Each entry: location, claim, severity, confidence (integer), recommendation. Group by skill if helpful.]

[**Clean-run case (master spec §5.2 row 8):** if both `critical[]` and `findings[]` are empty, replace BOTH sections with: `✅ Clean — no surviving findings across N reviews.` (N = sub-skills with status ✓).]

## Reviewed by

| Skill | Status | Findings |
|---|---|---|
| code-quality-audit | <status> | <count> |
| security-gauntlet | <status> | <count> |
| adversarial-review | <status> | <count> |
| plan-review | <status> | <count> |
| doc-review | <status> | <count> |
| doc-review (PR body) | <status> | <count> |
| skill-audit | <status> | <count> |
| directive-review | <status> | <count> |
| directive-review (body prose) | <status> | <count> |
| go-live-review | <status> | <verdict> |

[Status: `✓` ran; `⚠ failed` errored; `n/a` not applicable; `declined` operator skipped the prompt;
`skipped (gated)` security gate skipped a confidently-non-security code diff (fail-open did not trip);
`skipped (cross-author)` doc-on-body skipped because the PR was teammate-authored. A `skipped (gated)`
security row is a POSITIVE signal (the calibrated gate considered the diff and it was clean-surface), not a
degradation — distinct from `⚠ failed`. `code-quality-standards` is a Validator reference skill, not a
dispatch target — it does not appear here. **The two directive-review rows are distinct dispatches on a
`skill` artifact:** `directive-review` is the sibling-sweep over prose siblings (`reference.md`, `modes.md`,
etc.) and shows `n/a` for a single SKILL.md with no siblings; `directive-review (body prose)` is the SKILL.md
body-prose pass and runs for both a single SKILL.md and a directory. Keeping them on separate rows means a
reader can tell which dispatch ran or failed — mirroring the `doc-review` / `doc-review (PR body)` split.
**go-live-review's column shows its VERDICT (SHIP/HOLD/NEEDS-INFO), not a finding count.**]

## Stage coverage

[Emit ONE line by artifact type:
- **`plan`:** `Stage coverage: plan-time only. Code-time coverage: <found | not yet>.` "found" iff `gh pr list --search "<ticket>" --state all --json number --jq length` ≥ 1.
- **`code-pr`/`code-local`:** `Stage coverage: code-time (full lane set — not reduced by plan coverage).
  Plan-time coverage: <found | not found>.` "found" iff `ls projects/active/<ticket>/plans/*.md 2>/dev/null`
  ≥ 1 file. The parenthetical states the §1 guard explicitly so a reader never assumes prior plan coverage
  thinned this run.
- **`doc`/`skill`/`multi`:** omit the line.
If ticket-key extraction or detection errors out, omit silently.]

[**Go-Live Readiness zone (Phase 2.5 output) — present ONLY if Phase 2.5 ran.** Render the fenced `🚀 Go-Live Readiness — <SHIP|HOLD|NEEDS-INFO> (as-of <timestamp>)` block returned by go-live-review, verbatim, here. It is a SEPARATE section — its verdict does NOT appear in the box score, the `🛑/⚠️/💡` counts, the verdict badge, or the machine-readable JSON. If Phase 2.5 was skipped or declined, omit this zone entirely (the footer records the status). A HOLD/NEEDS-INFO here is an operator signal, not a gauntlet "blocker" — keep the two verdict systems distinct.]

<details>
<summary>N findings disproved (click to expand)</summary>

[Each disproved finding: skill, lens, location, claim, Validator's evidence-of-disproof. Transparency only; do not action.]

</details>

---

## Postable review comment

[This is the ONLY zone safe to paste into a PR/ticket/Slack. It is the **Gauntlet's branded, dual-audience comment** — render it to the canonical template below.

**Voice (AI-attributed, NOT first-person-as-Josh).** Findings are attributed to the Gauntlet, never to a first-person "I". Aim for warmth, clear structure, and disciplined emoji use. Conversational warmth comes from word choice, not pronouns:
- ✅ "The Gauntlet flags one blocker before the live run." / "Worth confirming whether X is exempt."
- ❌ "One issue I'd want resolved." / "Curious whether X is exempt." (first-person-as-Josh — forbidden here)

**Content rules.**
- Findings + recommendations only. NO gauntlet-internal vocabulary ("pressure-tested", "grounding lean heavier than usual", "Validator disproof rate", "three-filter rule", lens taxonomy) and NO process narration ("I checked X and it was fine", "ran deeper than by hand").
- **Branding carve-out:** the header, AI subtitle + tagline, verdict badge, box score, severity labels, agent-channel block, and footer below are INTENTIONAL brand — they are exempt from the no-vocabulary/no-narration rules above. The forbidden list is internal *mechanics*, not the brand frame.
- NO competitive claims (never "caught what Bito/Copilot missed") — the comment is about the code; brand bragging belongs in Slack/demos.
- Each AI/brand fact appears ONCE in its strongest position — no repetition across zones (AI-attribution → subtitle; builder credit → footer).

**Severity tiers** (mapped from already-adjudicated data — no new analysis): 🛑 **Blocker** = `critical[]`; ⚠️ **Concern** = surviving High/Medium not classified critical; 💡 **Nit** = surviving Low. The word is the contract (agent enum + accessibility); the emoji is sugar — never emoji-only.

**Canonical Zone 2 template** (render exactly this shape; the example shows a `code-pr` — the verdict, badge, `🧪 Lanes` row, and box-score tiers are generated from THIS run's adjudicated counts and dispatch set, not hardcoded. A `plan` renders `plan-review · adversarial · security`; `doc` renders `doc-review · adversarial · security`; `skill` renders `skill-audit · directive-review · security` (directive-review runs the body prose pass for both single-file and directory; a skill DIRECTORY additionally fans directive-review out to prose siblings); `directive` renders `directive-review · adversarial · security`):

## ⚔️ The Gauntlet — <verdict: 🛑 N Blocker(s) · M advisory | 🛡️ Clean>
<sub>🤖 AI-powered · *your code, through the lanes*</sub>

<!-- Header verdict is CODE-LANE ONLY (blockers/concerns/nits). The go-live SHIP/HOLD/NEEDS-INFO verdict does NOT appear here — it renders in its own `[!TIP]`/`[!CAUTION]`/`[!IMPORTANT]` callout below. A run can be code-Clean AND go-live HOLD simultaneously; the two verdict systems are kept visually distinct so neither masks the other. -->

![gauntlet verdict](https://img.shields.io/badge/gauntlet-<message>-<color>)

| | |
|---|---|
| 🛑 Blockers | **<n>** |
| ⚠️ Concerns | <n> |
| 💡 Nits | <n> |
| 🔒 Security | <clean ✓ | N findings> |
| 🧪 Lanes | <actual dispatch set for this artifact type> |

> [!WARNING]
> **<Blocker title>** — `<file>:<line>`. <claim>. **Fix:** <recommendation>.

(one `> [!WARNING]` per blocker; omit the block entirely on a clean run. The adversarial-lane-failure blocker
has no `file:line` — render its callout as `> [!WARNING]` `**Adversarial review did not run** — <claim>.
**Fix:** <recommendation>.` with the location clause dropped, not stubbed with a placeholder path.)

> [!TIP]
> **🚀 Go-Live: SHIP** · _as-of <YYYY-MM-DD>_
> <one-line reason from the verdict — what gate/precondition is satisfied, blast radius>
>
> **Before GA — not this merge:**
> 1. <forward item, if any>

(Go-Live callout — render ONLY if Phase 2.5 ran. This is the Zone 2 mirror of the Zone 1 `🚀 Go-Live Readiness` block: same verdict, condensed to a callout. Rules:
- **Alert type tracks the verdict:** SHIP → `> [!TIP]` (green), HOLD → `> [!CAUTION]` (red), NEEDS-INFO → `> [!IMPORTANT]` (purple). The `🚀` + verdict word is the contract; the alert color is sugar.
- **Always carry the `as-of <YYYY-MM-DD>` stamp** — go-live reads drifting external state, so its verdict is point-in-time, unlike the SHA-reproducible counts.
- **Forward items live INSIDE the block**, never scattered into prose. For SHIP, head them `**Before GA — not this merge:**`; for HOLD/NEEDS-INFO, head them `**Must resolve before shipping:**` as a numbered list lifted from the go-live verdict's resolution list. Omit the sub-list entirely if there are none.
- **Placement:** after the blocker `[!WARNING]`s, before `### Findings` — the two ship/no-ship signals (blockers + go-live) sit together above the advisory findings.
- **Separation invariant (load-bearing):** this block's verdict NEVER appears in the box score, the `🛑/⚠️/💡` counts, the verdict badge, or the `verdict:{}` JSON object. A HOLD here is an operator signal, NOT a gauntlet blocker — folding a drifting verdict into the reproducible counts corrupts the calibration trust signal. It maps ONLY to the `go_live:{}` JSON sibling below. If Phase 2.5 did not run, omit this callout entirely; the footer records the status.)

### Findings
| | Lens | Finding | Location |
|---|---|---|---|
| ⚠️ | <canonical lens> | <one-line claim> | `<file>:<line>` |
| 💡 | <canonical lens> | <one-line claim> | `<file>:<line>` |

(Render as a TABLE. Columns:
- **Col 1** — severity emoji (⚠️ Concern, 💡 Nit).
- **Lens** — the finding's canonical `lens` value, **character-for-character identical to the `lens` field in the machine-readable JSON block below** (e.g. `adversarial-review / Failure Scenarios`, `code-quality-standards / Gaps`, `security-gauntlet / Authorization`). Do NOT translate it to a friendlier synonym (`Failure scenario`, `Design / scoping`, `Type safety`, …) — a paraphrase mints a THIRD vocabulary that mismatches both the JSON and the 🧪 Lanes row, so a reader cross-referencing a row to the JSON sees two labels for one finding. One concept, one label, across both surfaces. The lane (the skill-prefix before ` / `) always equals a 🧪 Lanes entry; the sub-lens after ` / ` is the extra triage signal for the human. The lens taxonomy is allowed in this column (it's the carve-out, like the box score) — the no-internal-vocabulary rule still bars *process narration*, not the lens label itself.
- **Finding** — one-line claim.
- **Location** — `` `file:line` ``.
- **Status — RE-REVIEW ONLY.** Append a **Status** column ONLY on a Phase 4d re-review. **Omit it entirely on an initial review** — every cell would read `Open`, a dead column carrying no signal. On a re-review, Status is set BY THE GAUNTLET (never self-ticked) and reflects what the re-review VERIFIED against the code: `✅ Resolved` (fix confirmed in the diff), `➖ By design` / `➖ Author` (author dispositioned and the rationale holds), or `🔴 Still open` (claimed fixed but verification failed, OR not yet addressed). Never mark `✅ Resolved` on an author's say-so alone — confirm against the code per Phase 4d.

**Row membership differs by review kind — the table is the stable spine across re-reviews:**
- **Initial review:** one row per surviving Concern/Nit, ordered Concerns-before-Nits then by the Phase 3 rank.
- **Re-review (Phase 4d):** carry EVERY prior finding's row forward — including the ones now `✅ Resolved` and `➖ By design` — and append any new findings below them. A reader diffing the two comments must be able to track each finding's fate down a stable column; the Status cell IS that fate. **Do NOT drop resolved findings to a prose line** (e.g. "Resolved since last pass: …") — a finding that leaves the table loses its row continuity and the Status column has nothing to attach `✅ Resolved` to, defeating the column's whole purpose. Order: still-open Concerns → still-open Nits → resolved/by-design (prior rank preserved) → new findings (Phase 3 rank). The box-score counts still reflect only the OPEN tally (resolved findings are not counted as concerns/nits), but they keep their row with a terminal Status.

**Blockers are NOT in this table** — they stay in the `> [!WARNING]` callouts above.

Two rationales: (a) **Lens matches the JSON** — the human table and the agent JSON both name the lens, so they MUST agree; the JSON `lens` is the calibrated source of truth, so the human cell copies it rather than inventing prose. (b) **Status is re-review-only** — its value is the *verified* disposition a re-review produces; on an initial review it is uniformly `Open` and adds nothing. That same "verified, not self-asserted" property is why a Gauntlet-set Status emoji beats a GitHub `- [ ]` task-list checkbox: clickable boxes only render in a list (not a table cell) and the author can mis-tick them, whereas the Gauntlet verifies disposition against the code. Omit the Findings section entirely if there are no Concerns/Nits; on a fully clean run replace the header verdict with 🛡️ Clean and emit one line: "Cleared all lanes — no findings.")

<details>
<summary>🤖 Machine-readable findings (for agents)</summary>

```json
{
  "tool": "gauntlet",
  "schema": "v1",
  "reviewed_ref": "<short sha or path@blob>",
  "verdict": { "blockers": 0, "concerns": 0, "nits": 0, "security": "clean" },
  "go_live": { "verdict": "SHIP|HOLD|NEEDS-INFO", "as_of": "<YYYY-MM-DD>" },
  "findings": [
    { "severity": "blocker|concern|nit", "location": "<file>:<line>", "lens": "<canonical lens>", "confidence": 0, "claim": "<text>", "recommendation": "<text>" }
  ]
}
```
</details>

---
<sub>🎮 The Gauntlet · an AI review harness built by Josh C.S. Lewis · reviewed at `<short sha>`. Everything but the 🛑 is advisory.</sub>
<!-- gauntlet:v1 ref=<short sha> -->

**Verdict badge** (`shields.io`, static, rendered at post time from adjudicated counts): label `gauntlet`; message+color track state — ≥1 blocker → `<n>_blocker[s]`/`red`; 0 blockers + ≥1 advisory → `<n>_advisory`/`yellow`; 0 findings → `clean`/`brightgreen`. The badge is garnish (Camo-cached, breaks on host outage); the text box score is the source of truth — the badge never carries info absent from the text.

**Agent channel.** The `<details>` JSON is the machine contract: `severity` ∈ {blocker, concern, nit}; `location` is `file:line`, except the adversarial-lane-failure blocker (`code-pr`/`code-local` only), whose `location` is the literal string `"N/A — lane failure"`; fields mirror the canonical schema subset. Keep the blank line after `</summary>` or the fenced block won't render. The `<!-- gauntlet:v1 ref=<sha> -->` marker is the comment's self-ID: on a re-run, grep existing PR comments for `gauntlet:v1` and UPDATE the prior comment (Phase 4d delta) rather than posting a duplicate. The `go_live` sibling key is present ONLY when Phase 2.5 ran; it carries `{verdict, as_of}` and is deliberately a SEPARATE top-level key from `verdict:{}` — agent consumers read the ship/hold decision from `go_live`, never by inflating the `verdict` counts. Omit the `go_live` key entirely when Phase 2.5 did not run (do not emit `null`).

**Zone 2 is the canonical postable text** for EVERY artifact type (code-pr, code-local, plan, doc, skill — for non-PR artifacts the operator pastes it into the ticket). When the operator later posts a PR comment or runs `/create-pr`, that step reuses Zone 2 verbatim. One voice pass, one source of truth.]
````
