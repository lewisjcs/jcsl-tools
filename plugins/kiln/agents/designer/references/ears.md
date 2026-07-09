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
