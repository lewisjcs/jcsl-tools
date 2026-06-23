# Gauntlet Reference — lens mapping & schema-promotion rules

Load this file **only in Phase 3 substep 1** (Concatenate/promote), when adversarial-review's 5-field findings are being promoted to the canonical 10-field shape and relabeled. The orchestrator does not need this content to run Phases 0–2 or 4.

Authoritative source: master spec `projects/active/gauntlet/2026-05-22-design.md` §4.1 / §4.1.1. This file is the operational extract; if the two ever disagree, the master spec wins.

---

## Cross-skill canonical-lens mapping table

When `adversarial-review` is dispatched against `plan-text` or `doc-text` (Phase 1), its three sub-lenses preserve as distinct labels under a parent lens family. For `code-diff`, native vocabulary is kept unchanged.

| Dispatch type | adversarial-finder lens | Canonical relabeled lens |
|---|---|---|
| `plan-text` | `Hidden Assumptions` | `plan-review / Architectural risk - Hidden Assumptions` |
| `plan-text` | `Failure Scenarios` | `plan-review / Architectural risk - Failure Scenarios` |
| `plan-text` | `Blast Radius` | `plan-review / Architectural risk - Blast Radius` |
| `doc-text` | `Hidden Assumptions` | `doc-review / Hidden assumptions - Hidden Assumptions` |
| `doc-text` | `Failure Scenarios` | `doc-review / Hidden assumptions - Failure Scenarios` |
| `doc-text` | `Blast Radius` | `doc-review / Hidden assumptions - Blast Radius` |
| `code-diff` | `Hidden Assumptions` | `adversarial-review / Hidden Assumptions` (no relabel) |
| `code-diff` | `Failure Scenarios` | `adversarial-review / Failure Scenarios` (no relabel) |
| `code-diff` | `Blast Radius` | `adversarial-review / Blast Radius` (no relabel) |

**Why preserve all three sub-lenses (don't collapse to one):** Phase 8 Task 5+6 soft-validation showed that collapsing the 3 sub-lenses to 1 canonical lens caused Phase 3 substep 4 dedup to drop HIGH-confidence critical findings (severity=High AND confidence≥85 AND category=correctness). Two fixtures lost Required-Changes findings to the lens-collapse blind spot (plan/02 dropped F5-AR at conf 87; doc/01 dropped F6-AR at conf 85). The hyphenated-suffix vocabulary keeps each sub-lens distinct for dedup while preserving the parent family for report grouping. Dedup (substep 4) treats two findings as duplicates only when the original sub-lens AND the location both match.

**Separator disambiguation:** the lens vocabulary uses TWO separators that consumers MUST handle differently:
- ` - ` (space-hyphen-space, U+002D) is the parent-vs-sub-lens delimiter — e.g. `plan-review / Architectural risk - Hidden Assumptions`.
- ` — ` (space-em-dash-space, U+2014) is part of the lens-label text itself — e.g. `doc-review / Memory rules — evergreen-ness`. It is NOT a sub-lens delimiter.

To group by parent lens family, split on ` - ` (space-hyphen-space) ONLY — never on bare `-` (that would wrongly split `evergreen-ness`), and treat ` — ` as part of the label.

---

## Phase 3 substep 1 — 5-field → 10-field promotion

Promote each adversarial-review finding (`lens`, `location`, `claim`, `evidence`, `severity` + Validator's `verdict` + `confidence`) to the canonical 10-field shape:

- **`skill`** → `adversarial-review`.
- **`lens`** → apply the mapping table above (9 rows = 3 sub-lenses × 3 dispatch types).
- **`category`** → single deterministic rule: `plan-text` → `correctness`; `doc-text` → `correctness`; `code-diff` → `correctness`. Adversarial findings always represent correctness concerns (hidden assumptions break intended behavior). The Phase 6 doc-review multi-category mapping does NOT apply here.
- **`recommendation`** → if the `claim` already carries a `Recommendation:`/`Fix:` suffix, use it; otherwise derive a one-sentence action from the claim (e.g. "Step 3 has a hidden dependency on the cache being warm" → "Add an explicit cache-warm step or guard Step 3 on cache miss").
- Apply the master spec §4.3 skill-audit transformation table for any skill-audit findings.

---

## Location & lens emission contract (§4.1.1 extract)

Sub-skills emit these two fields in exact formats (the calibration scorer does exact-string match):

**`location`:**
| Artifact | Format | Example |
|---|---|---|
| Code (file diff) | `<repo-relative path>:<post-diff source line>` | `src/handlers/admin.ts:8` |
| Plan / Doc / Skill / Directive | bare narrative section reference (case- and quote-sensitive) | `Step 3 ("Update the auth flow")`, `Architecture section, paragraph 2`, `Frontmatter (lines 1-4)`, `EXECUTE Step 4 ("Checkpoint")` |

Code line numbers reference the **post-diff source file** (the patched file's numbering, as GitHub PR comments and IDE goto-line use), NOT diff-text positions. Multiple defects of the same lens at adjacent paragraphs emit as **N findings with single-paragraph locations**, never one finding with a paragraph-range location.

**`lens`:** `<skill-name> / <lens-label>`, where `<skill-name>` ∈ {`security-gauntlet`, `plan-review`, `doc-review`, `skill-audit`, `adversarial-review`, `directive-review`, `code-quality-standards`}, ` / ` is a literal space-slash-space, and `<lens-label>` is the lens name as defined in master spec §3.
