# EARS Authoring Reference (Kiln Designer)

Distilled from the owner's EARS canon — EXT-7293 (canonical), EXT-7059 (heavyweight NFR),
AIS-17 (cross-project). This is an authoring reference, not EARS theory. Author `spec-draft.md` to it.

## The Five Patterns
| Pattern | Template | Use |
|---|---|---|
| Ubiquitous | `The <system> shall <response>` | always-true constraint |
| Event-driven | `When <trigger>, the <system> shall <response>` | happy-path triggered behavior |
| State-driven | `While <state>, the <system> shall <response>` | precondition / duration (often NFRs) |
| Unwanted behavior | `If <condition>, then the <system> shall <response>` | ERROR / fault paths ONLY |
| Optional feature | `Where <feature included>, the <system> shall <response>` | flag-gated / optional |

Load-bearing Mavin semantics: `If…then` is RESERVED for unwanted behavior (errors, invalid input,
limits exceeded); `When` is happy-path. Complex ordering is `While … when …` — state before trigger,
never reversed.

## Two Scale-Selected Templates
Pick by scope (a complexity-proportionate decision):
- **Grouped skeleton** (multi-subsystem; EXT-7293, EXT-7059): `## Context` + `### References` →
  `## Functional Requirements` under subsystem `###` heads → `## Non-functional Requirements`
  (Performance / Security / Compatibility / Reliability) → `## Excluded Scope` → optional `## Open Questions`.
- **Flat AC list** (single-handler; EXT-7340): `## Description` → `## Acceptance Criteria` as `* AC N:` bullets.

## Anti-Pattern Checklist (Designer self-review greps these)
- vague response ("appropriately" / "correctly")
- compound requirement (multiple independent `shall`, or >1 system named → split)
- non-trigger ("when needed")
- untestable `shall` (no observable assertion)
- passive voice (no system subject)
- solution-in-requirement (prescribes mechanism, not behavior)
- wrong keyword for error path (`When` used for a fault → should be `If…then`)
- out-of-order Complex (`when … while …` reversed)
- duplication
- wordiness

## Few-Shot Exemplars
- **EXT-7293** — canonical, exercises all five patterns; grouped skeleton.
- **EXT-7059** — heavyweight, full NFR block.
- **AIS-17** — cross-project; `TODO at build kickoff:` is an ACCEPTED deferral, NOT staleness — never flag it.

## Composing EARS into a host ticket skeleton

EARS is a *sentence-level* requirement style (Mavin, RE'09), not a document skeleton. When a team
has a house ticket format, EARS fills the **acceptance-criteria / behavioral** section; the other
sections stay prose. Precedent: Amazon Kiro nests EARS acceptance criteria under user stories.

**Section mapping (host skeleton → content style):**
- `Context` / `Background` / `Problem` / `References` → prose (fold the original ticket text here).
- `Acceptance Criteria` / `Functional Requirements` / behavioral sub-headings → EARS bullets.
- `Non-functional Requirements` → EARS state-driven (`While <load>, the system shall … within <p95>`).
- `Excluded Scope` / `Out of Scope` → prose list.

**Fold-in rule (no invented scope).** When absorbing an existing thin description, move its intent
into the prose sections and derive testable AC — but do NOT manufacture requirements the source
does not support. Mark any AC not directly grounded in the source as `⟨proposed — confirm⟩` so it
is caught at review before it lands. If the source is too thin to ground any AC, that is a design-
dialogue signal (route to the Designer), not a licence to invent.

**Worked example (thin → composed).**
Source ticket body: *"webhook retries are flaky, make them better."*
Composed (AIS house skeleton):
```
## Context
Webhook delivery retries currently <fold original>. <references>

## Acceptance Criteria
- When a webhook delivery fails, the system shall retry after an exponential backoff interval.
- If the retry attempt count exceeds the configured maximum, then the system shall stop retrying
  and record a delivery-failed event.
- ⟨proposed — confirm⟩ While the endpoint is returning 5xx, the system shall apply jitter to
  successive retry intervals.

## Excluded Scope
- Changes to the webhook payload schema.
```
