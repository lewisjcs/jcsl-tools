# Gauntlet — the postable comment template

Load this file **only when the operator asks for something to post** (step 8 of the run skill). Nothing before that step needs it: the runtime writes the report file itself, and this template is consumed once, at the moment a teammate-facing comment is actually wanted.

**Bright-line: the report file's own vocabulary never appears on a teammate-facing surface. This comment is the only postable text.** It is the canonical postable text for EVERY artifact type — code diff, plan, doc, skill, or agent-instruction file. For a non-pull-request artifact the operator pastes it into the ticket. When the operator later posts a comment or opens a pull request, that step reuses this comment verbatim. One voice pass, one source of truth.

---

````markdown
## Postable review comment

[This is the ONLY text safe to paste into a PR/ticket/Slack. It is the **Gauntlet's branded, dual-audience comment** — render it to the canonical template below.

**Voice (AI-attributed, NOT first-person as the operator).** Findings are attributed to the Gauntlet, never to a first-person "I". Aim for warmth, clear structure, and disciplined emoji use. Conversational warmth comes from word choice, not pronouns:
- ✅ "The Gauntlet flags one blocker before the live run." / "Worth confirming whether X is exempt."
- ❌ "One issue I'd want resolved." / "Curious whether X is exempt." (first-person as the operator — forbidden here)

**Content rules.**
- Findings + recommendations only. NO gauntlet-internal vocabulary ("pressure-tested", "grounding lean heavier than usual", "Validator disproof rate", lens taxonomy) and NO process narration ("I checked X and it was fine", "ran deeper than by hand").
- **Branding carve-out:** the header, AI subtitle + tagline, verdict badge, box score, severity labels, agent-channel block, and footer below are INTENTIONAL brand — they are exempt from the no-vocabulary/no-narration rules above. The forbidden list is internal *mechanics*, not the brand frame.
- NO competitive claims (never "caught what tool X missed") — the comment is about the code; brand bragging belongs elsewhere.
- Each AI/brand fact appears ONCE in its strongest position — no repetition (AI-attribution → subtitle; builder credit → footer).

**Severity tiers** (mapped from the runtime's already-adjudicated report — no new analysis): 🛑 **Blocker** = an entry in the report's Required Changes section; ⚠️ **Concern** = a reported High/Medium finding that is not a blocker; 💡 **Nit** = a reported Low finding. The word is the contract (agent enum + accessibility); the emoji is sugar — never emoji-only.

**Canonical template** (render exactly this shape; the example shows a code diff — the verdict, badge, `🧪 Lanes` row, and box-score tiers are generated from THIS run's reported counts and its actual roster, not hardcoded. The `🧪 Lanes` row names the lanes the runtime fielded for this run, plus any gap follow-up the operator chose to run):

## ⚔️ The Gauntlet — <verdict: 🛑 N Blocker(s) · M advisory | 🛡️ Clean>
<sub>🤖 AI-powered · *your code, through the lanes*</sub>

<!-- Header verdict is REVIEW-LANE ONLY (blockers/concerns/nits). The go-live SHIP/HOLD/NEEDS-INFO verdict does NOT appear here — it renders in its own `[!TIP]`/`[!CAUTION]`/`[!IMPORTANT]` callout below. A run can be review-Clean AND go-live HOLD simultaneously; the two verdict systems are kept visually distinct so neither masks the other. -->

![gauntlet verdict](https://img.shields.io/badge/gauntlet-<message>-<color>)

| | |
|---|---|
| 🛑 Blockers | **<n>** |
| ⚠️ Concerns | <n> |
| 💡 Nits | <n> |
| 🔒 Security | <clean ✓ / N findings / not run> |
| 🧪 Lanes | <the lanes this run actually fielded> |

> [!WARNING]
> **<Blocker title>** — `<file>:<line>`. <claim>. **Fix:** <recommendation>.

(one `> [!WARNING]` per blocker; omit the block entirely on a clean run. A blocker raised because a lane did not run has no `file:line` — render its callout as `> [!WARNING]` `**<Adversarial review | Code-quality audit> did not run** — <claim>. **Fix:** <recommendation>.` with the location clause dropped, not stubbed with a placeholder path.)

> [!TIP]
> **🚀 Go-Live: SHIP** · _as-of <YYYY-MM-DD>_
> <one-line reason from the verdict — what gate/precondition is satisfied, blast radius>
>
> **Before GA — not this merge:**
> 1. <forward item, if any>

(Go-Live callout — render ONLY if the go-live readiness lane ran as a follow-up. It is the condensed mirror of that lane's own verdict block: same verdict, callout shape. Rules:
- **Alert type tracks the verdict:** SHIP → `> [!TIP]` (green), HOLD → `> [!CAUTION]` (red), NEEDS-INFO → `> [!IMPORTANT]` (purple). The `🚀` + verdict word is the contract; the alert color is sugar.
- **Always carry the `as-of <YYYY-MM-DD>` stamp** — go-live reads drifting external state, so its verdict is point-in-time, unlike the digest-reproducible counts.
- **Forward items live INSIDE the block**, never scattered into prose. For SHIP, head them `**Before GA — not this merge:**`; for HOLD/NEEDS-INFO, head them `**Must resolve before shipping:**` as a numbered list lifted from the go-live verdict's resolution list. Omit the sub-list entirely if there are none.
- **Placement:** after the blocker `[!WARNING]`s, before `### Findings` — the two ship/no-ship signals (blockers + go-live) sit together above the advisory findings.
- **Separation invariant (load-bearing):** this block's verdict NEVER appears in the box score, the `🛑/⚠️/💡` counts, the verdict badge, or the `verdict:{}` JSON object. A HOLD here is an operator signal, NOT a gauntlet blocker — folding a drifting verdict into the reproducible counts corrupts the trust signal. It maps ONLY to the `go_live:{}` JSON sibling below. If the go-live lane did not run, omit this callout entirely.)

### Findings
| | Lens | Finding | Location |
|---|---|---|---|
| ⚠️ | <lens> | <one-line claim> | `<file>:<line>` |
| 💡 | <lens> | <one-line claim> | `<file>:<line>` |

(Render as a TABLE. Columns:
- **Col 1** — severity emoji (⚠️ Concern, 💡 Nit).
- **Lens** — the finding's `lens` value as the report gives it, **character-for-character identical to the `lens` field in the machine-readable JSON block below** (e.g. `adversarial-review / Failure Scenarios`, `code-quality-audit / Compliance`, `code-quality-standards / Gaps`, `security-gauntlet / Authorization`). Do NOT translate it to a friendlier synonym (`Failure scenario`, `Design / scoping`, `Type safety`, …) — a paraphrase mints a THIRD vocabulary that mismatches both the JSON and the 🧪 Lanes row, so a reader cross-referencing a row to the JSON sees two labels for one finding. One concept, one label, across both surfaces. The lane (the skill-prefix before ` / `) always equals a 🧪 Lanes entry; the sub-lens after ` / ` is the extra triage signal for the human. The lens taxonomy is allowed in this column (it's the carve-out, like the box score) — the no-internal-vocabulary rule still bars *process narration*, not the lens label itself.
- **Finding** — one-line claim.
- **Location** — `` `file:line` ``.
- **Status — RE-REVIEW ONLY.** Append a **Status** column ONLY when this comment reports a re-review of an advanced head. **Omit it entirely on a first review** — every cell would read `Open`, a dead column carrying no signal. On a re-review, Status is set BY THE GAUNTLET (never self-ticked) and reflects what the re-review VERIFIED against the code: `✅ Resolved` (fix confirmed in the diff), `➖ By design` / `➖ Author` (author dispositioned and the rationale holds), or `🔴 Still open` (claimed fixed but verification failed, OR not yet addressed). Never mark `✅ Resolved` on an author's say-so alone — confirm against the code.

**Row membership differs by review kind — the table is the stable spine across re-reviews:**
- **First review:** one row per reported Concern/Nit, ordered Concerns-before-Nits, then in the order the report lists them.
- **Re-review:** carry EVERY prior finding's row forward — including the ones now `✅ Resolved` and `➖ By design` — and append any new findings below them. A reader diffing the two comments must be able to track each finding's fate down a stable column; the Status cell IS that fate. **Do NOT drop resolved findings to a prose line** (e.g. "Resolved since last pass: …") — a finding that leaves the table loses its row continuity and the Status column has nothing to attach `✅ Resolved` to, defeating the column's whole purpose. Order: still-open Concerns → still-open Nits → resolved/by-design (prior order preserved) → new findings. The box-score counts still reflect only the OPEN tally (resolved findings are not counted as concerns/nits), but they keep their row with a terminal Status.

**Blockers are NOT in this table** — they stay in the `> [!WARNING]` callouts above.

Two rationales: (a) **Lens matches the JSON** — the human table and the agent JSON both name the lens, so they MUST agree; the report's `lens` value is the source of truth, so the human cell copies it rather than inventing prose. (b) **Status is re-review-only** — its value is the *verified* disposition a re-review produces; on a first review it is uniformly `Open` and adds nothing. That same "verified, not self-asserted" property is why a Gauntlet-set Status emoji beats a GitHub `- [ ]` task-list checkbox: clickable boxes only render in a list (not a table cell) and the author can mis-tick them, whereas the Gauntlet verifies disposition against the code. Omit the Findings section entirely if there are no Concerns/Nits; on a fully clean run replace the header verdict with 🛡️ Clean and emit one line: "Cleared all lanes — no findings.")

<details>
<summary>🤖 Machine-readable findings (for agents)</summary>

```json
{
  "tool": "gauntlet",
  "schema": "v1",
  "reviewed_ref": "<short sha or path@digest>",
  "verdict": { "blockers": 0, "concerns": 0, "nits": 0, "security": "clean" },
  "go_live": { "verdict": "SHIP|HOLD|NEEDS-INFO", "as_of": "<YYYY-MM-DD>" },
  "findings": [
    { "severity": "blocker|concern|nit", "location": "<file>:<line>", "lens": "<lens>", "confidence": 0, "claim": "<text>", "recommendation": "<text>" }
  ]
}
```
</details>

---
<sub>🎮 The Gauntlet · an AI review harness built by Josh C.S. Lewis · reviewed at `<short sha>`. Everything but the 🛑 is advisory.</sub>
<!-- gauntlet:v1 ref=<short sha> -->

**Verdict badge** (`shields.io`, static, rendered at post time from the report's counts): label `gauntlet`; message+color track state — ≥1 blocker → `<n>_blocker[s]`/`red`; 0 blockers + ≥1 advisory → `<n>_advisory`/`yellow`; 0 findings → `clean`/`brightgreen`. The badge is garnish (proxy-cached, breaks on host outage); the text box score is the source of truth — the badge never carries info absent from the text.

**Agent channel.** The `<details>` JSON is the machine contract: `severity` ∈ {blocker, concern, nit}; `location` is `file:line`, except a blocker raised because a lane did not run, whose `location` is the literal string `"N/A — lane failure"`; fields mirror the report's own finding shape. Keep the blank line after `</summary>` or the fenced block won't render. The `<!-- gauntlet:v1 ref=<sha> -->` marker is the comment's self-ID: on a re-review, grep existing comments for `gauntlet:v1` and UPDATE the prior comment rather than posting a duplicate — with the operator's fresh consent, which a prior post never carries forward. The `go_live` sibling key is present ONLY when the go-live lane ran; it carries `{verdict, as_of}` and is deliberately a SEPARATE top-level key from `verdict:{}` — agent consumers read the ship/hold decision from `go_live`, never by inflating the `verdict` counts. Omit the `go_live` key entirely when the go-live lane did not run (do not emit `null`).]
````
