# Doc Failure Modes

Common failure patterns mapped to `doc-review` lenses (master spec §3.5). Each Lens 1 and Lens 4 entry has a concrete grep-able tell. Lenses 2 and 3 are partially supported — the Validator role is more load-bearing there. For lens definitions see the master spec §3.5. For doc type context see doc-types.md §1–6. For voice rules behind these patterns see voice-and-structure.md and contentful-patterns.md.

---

## Lens 1: Memory-Encoded Rules

Highest-confidence findings — violations of explicit, stored rules. Finder pattern-matches; Validator confirms context (e.g., is this in an ADR where history is appropriate?).

---

### Evergreen-ness Violation

**Concrete tell (grep-able):**
- `\b(was removed|were removed|has been removed|scrapped|deprecated and removed)\b` in a doc body outside an ADR Consequences or Status section
- `\b(post|after|since|pre)-(EXT|DX|MAPS|INTEG|CAP|PROD)-\d+\b` — post-ticket history references in RFC/AGENTS.md/ARCHITECTURE.md bodies
- `\b(January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{4}\s+update:` — body timestamp outside front-matter Review Date field
- `\(\d{4}-\d{2}-\d{2}\s+update\)` — inline date-stamp in body text
- `^\|\s*(removed|scrapped|deprecated)\s*\|` — table cell value in an entity/field inventory (a "removed" status row retained instead of deleted)

**Why it's wrong:** Shipped docs describe current state. History belongs in ADRs, commit messages, or PR descriptions. In AGENTS.md and CLAUDE.md, stale history actively misleads agents loaded in every session.

**The fix:** Delete the history reference. If the descope needs recording, create an ADR or add a Non-Goals / Out of Scope section describing current scope — not a before/after comparison. Living RFC scope updates should state what IS implemented, not what WAS planned.

---

### No Personal Tooling in Shipped Docs

**Concrete tell (grep-able):**
- `/cartograph\b` or `/create-pr\b` — personal-only OS skills
- `\$contentful-[a-z-]+` — `$`-prefixed skill invocation in AGENTS.md without verifying the skill is in the repo's `.agents/skills/` or `.claude/skills/` inventory
- `sca-angel\b` or other internal automation aliases not present in the target repo

**Why it's wrong:** Skills cited in shipped docs must be available to all readers. Personal OS skills are not installed in the reader's environment — the reference is silently non-executable.

**The fix:** Replace with vendor-neutral process descriptions, or reference only `contentful-*` skills from `contentful/agents-kit` that are org-public artifacts.

---

### No Local Paths in Shipped Docs

**Concrete tell (grep-able):**
- `~/` or `/tmp/` or `\.worktrees/` or `projects/active/` — local filesystem paths
- `atlassian\.net/wiki/spaces/~\d+/` — personal Confluence tilde-space URL
- `/Users/[a-z.]+/` — absolute local path

**Why it's wrong:** Local paths are not navigable by any other reader.

**The fix:** Replace with relative repo paths, CODEOWNERS paths, or team aliases. Replace personal Confluence space URLs with the canonical team space URL, or remove entirely.

---

### No Individual Names as Owner Pointers

**Concrete tell (grep-able):**
- `(Reach out to|Contact|Owner:|Maintainer:|Point of contact:)\s+[A-Z][a-z]+\s+[A-Z][a-z]+` — personal name following an ownership signal phrase
- `@[a-z]+\.[a-z]+` — `@firstname.lastname` patterns in owner fields

**Why it's wrong:** Individual names go stale and commit people to roles they did not agree to.

**The fix:** Replace with team aliases (e.g. `Applied AI Solutions`), Slack channels, or CODEOWNERS paths. Internal scratch docs are exempt.

**Exception:** Mike Kivisto is named in contentful-patterns.md §Evals discipline — the only individual-name exception in doc-patterns content (master spec §3.2 spec-named exception).

---

### ADR Filename Convention (Scope-Aware)

**Concrete tell (grep-able):**
- Tundra/ECO/ExO repo: `^\d{4}-[^0-9]` (sequential) — correct Tundra pattern is `^\d{4}-\d{2}-\d{2}-` (date-based)
- SDK team repo: `^\d{4}-\d{2}-\d{2}-` (date-based) — correct SDK pattern is `^\d{4}-[^0-9]` (sequential)

**Why it's wrong:** Same pattern is correct in one team's repos and flagged in another's — Validator needs repo context.

**The fix:** Rename to match team convention; update any index. Do not delete old entries. Cross-reference: doc-types.md §4.

---

### Bloat / Non-Discoverable Content in AGENTS.md

**Concrete tell (grep-able):**
- `npm run [a-z\-]+` — npm script enumeration (discoverable from `package.json`)
- `npx|yarn run|pnpm run` — package manager commands
- `git clone|git checkout|npm install|yarn install|pnpm install` — setup commands (belong in README)
- `## Getting Started` or `## Setup` heading in AGENTS.md
- ` ```[a-z]*\n(?:[^\n]*\n){2,}``` ` — code block of 2+ content lines in an AGENTS.md body (multi-line code examples belong in skill files or README, not AGENTS.md)

**The fix:** Apply the litmus test (contentful-patterns.md §AGENTS.md). Remove `bloat`; move `misplaced`: setup → README; decision trees/examples → skill files. The `contentful-update-agents-md` skill in `contentful/agents-kit` automates this classification.

Three-tag vocabulary: `ok` (non-discoverable, keep), `bloat` (discoverable/procedural, remove), `misplaced` (belongs elsewhere, move).

---

## Lens 2: Internal Consistency

Validator-heavy. Lens 2 findings require reading the full document and comparing sections against each other. The Finder produces broader, lower-confidence findings; the Validator adjudicates. Static pattern matching has limited coverage.

**Structural signals the Finder checks (all require Validator confirmation):**
- **RFC Status vs. Architecture Review outcome:** Status field (DRAFT/UNDER REVIEW/APPROVED/ABANDONED) must match the outcome of any linked Architecture Review.
- **Milestone dates vs. delivery phases:** Milestone target dates falling before phase-start dates indicate the table was not updated when the delivery approach changed.
- **Rationale Q&A vs. Detailed Solution:** An option listed as "rejected" in the Q&A but still described in the Detailed Solution is an inconsistency.
- **RAPID Decision vs. options table:** The Decision section must name an option present in the options comparison table.
- **Superseded ADR chain:** A "superseded" ADR without a link to its replacement, or vice versa, breaks the bidirectional chain.

The Validator decides whether an inconsistency is a genuine error or an intentional informed deviation (e.g., "No architecture review needed" with explicit rationale is a valid deviation, not a missing field).

### Rationale as Q&A Instead of Inline Rejected-Alternatives

**Concrete tell (grep-able):** A "Rationale Q&A" / "Q&A" heading, or a run of `**Q:** … **A:** …` pairs standing in for design rationale.

**Why it's wrong:** Observed practice across the corpus never uses Q&A for rationale; it reads as post-hoc FAQ rather than decisions. Rationale belongs next to the decision it justifies, as an inline `Rejected — X: because…` callout or a pro/con options table.

**The fix:** Convert each Q&A pair into an inline rejected-alternative at the relevant Detailed Solution sub-section, or a pro/con options table with `(recommended)` marked. Cross-reference: doc-types.md §1 Authoring guidance.

### Summary Re-Narrates the Parent PRD/Epic Problem (Layering Violation)

**Concrete tell:** The RFC links a parent PRD/epic (front-matter Reference Documentation or Jira Deliverable is populated) AND the Summary/Context spends multiple paragraphs restating that parent's problem/motivation rather than linking it and pivoting to the solution.

**Why it's wrong:** Problem ownership lives upstream. Re-narration duplicates the PRD (drifts over time) and buries the decision the RFC exists to make. "Specific statements create alignment; generic statements create the illusion of alignment" (Larson).

**The fix:** Compress the problem to 1–2 sentences + a link to the parent; spend the body on solution + rationale. Cross-reference: doc-types.md §1 Authoring guidance.

**Guardrail — do NOT flag when:** no parent PRD/epic is linked (the RFC legitimately owns the problem — e.g. a net-new tool, a proposed standard, an org-process RFC). Problem narration is correct there.

### Guardrails — RFC status-aware (what NOT to flag)

- **DRAFT-status RFC with placeholder litter or empty *conditional* sections is not defective.** Only flag missing *near-universal* sections (doc-types.md §1 tier 1). RFCs are gated at Architecture Review; drafts are legitimately incomplete (timely-over-polished).
- **Do not demand full defended rationale from a DRAFT.** Open questions are acceptable pre-review; rationale-completeness checks apply at UNDER REVIEW / APPROVED.
- **Flag a *stale* status badge** — e.g. APPROVED with unresolved blocking comments, or a badge out of sync with the Architecture Review outcome.

---

## Lens 3: Accuracy of References

Partial support — URL resolution requires fetching, not static analysis. The Finder flags patterns that warrant verification; the Validator confirms.

**Static checks the Finder can perform:**
- **Bare URLs:** `https?://[^\s)\]]+(?<![\)\]])` on a line without a preceding `](` — use `[text](url)` instead. (See voice-and-structure.md §Citation conventions.)
- **Personal Confluence space URLs:** `atlassian\.net/wiki/spaces/~\d+/` — personal spaces may not be accessible to all readers.
- **Skill references:** `\$contentful-[a-z-]+` in AGENTS.md without verified installed-skill inventory. (See §Lens 1, No personal tooling.)
- **Local paths:** `~/|/tmp/|\.worktrees/|/Users/[a-z.]+/` — not navigable by other readers. (See §Lens 1, No local paths.)

**What the Finder cannot check statically:** Whether a Confluence URL resolves, whether a GitHub file path exists, whether a linked Architecture Review is the correct session. For high-stakes references (upstream RAPID links, ADR supersession links), the Validator fetches and confirms.

---

## Lens 4: Voice / Writing-Style Alignment

### Hedge Words in Directive Sections

**Concrete tell (grep-able):**
`\b(might|could|perhaps|consider|you may want to|optionally|it might be worth|potentially|ideally)\b` in lines under headings matching `## Decision`, `## Recommendation`, `## Guardrails`, `## Anti-Patterns`, `## Invariants`, or in agent system prompts and AGENTS.md rule sections.

**Fix:** Replace hedges with declarative statements. Genuinely optional content belongs in a separate Optional or Open Questions section. See voice-and-structure.md §No hedging on directives and §Larson's specificity principle.

---

### Passive Voice in Decision Sections

**Concrete tell (grep-able):**
`\b(it was decided|it has been agreed|a decision was made|has been selected|was chosen)\b` in ADR Decision sections or RFC Settled Decisions tables.

**Fix:** "We will X" for ADRs. Present-tense declarative for RFC Settled Decisions: "Token exchange is the delegation mechanism" not "Token exchange was selected." See voice-and-structure.md §Active voice for directives.

---

### Bullet-Only Sections Without Prose Context

**Concrete tell (grep-able):** Heading immediately followed by a list with no prose introduction. Mechanical Finder pattern: `^#{2,4} .+\n+[-*] ` (heading line, then a bullet on the first non-blank line that follows).

**Validator confirmation:** the Finder match is necessary but not sufficient. The Validator confirms whether the bullets are fragment-level (3+ words, no complete sentence) versus complete-sentence bullets that stand on their own. Complete-sentence bullets without a preamble are acceptable; fragment bullets without a preamble are the violation.

**Why it's wrong:** Nygard: "Bullets are acceptable only for visual style, not as an excuse for writing sentence fragments. Bullets kill people, even PowerPoint bullets." Fragment bullets in context sections fail to communicate causality — the reader infers the connective tissue.

**The fix:** Add one framing sentence before the list. The bullets enumerate; the prose provides the interpretive frame.

---

### Paragraph Density Violation (Prose Wall)

**Concrete tell (grep-able):**
Five or more consecutive non-blank lines without a list marker (`- `, `* `, `1.`), heading (`#`), code block (` ``` `), or table (`|`).

**Why it's wrong:** Dense prose signals narrative padding. Cross-reference voice-and-structure.md §Paragraph density.

**The fix:** Determine whether the content is parallel items (→ list or table), data structure (→ code block), or continuous reasoning (→ legitimate prose). If genuinely continuous reasoning and over 4 sentences, compress: cut to decision and rationale, remove restatements.

---

### RFC Audience Table Missing Detail Column

**Concrete tell (grep-able):** Audience table rows matching `\|\s*(AGREE|INPUT|CONSULT)\s*\|[^|]+\|\s*$` — three pipes total instead of four (Role | Individual/Team | Detail | end-of-row). The Detail column is required per Contentful house style; its absence collapses reviewer scope.

**Why it's wrong:** The Detail column communicates what each reviewer is being asked to validate. Without it, an AGREE reviewer cannot tell if their veto applies to the whole RFC or only to a specific sub-decision.

**The fix:** Add the Detail column. Each row gets a one-phrase scope: "API surface", "auth model", "delivery sequencing", etc. Cross-reference: contentful-patterns.md §AGREE / INPUT / CONSULT audience-table convention.

---

## Lens 5: Hidden Assumptions (Delegated to adversarial-review)

Delegates to the `adversarial-review` skill. No lens-specific failure modes captured here. Doc-review passes the document text to `adversarial-review` for pressure-testing of hidden assumptions and structural risks that static pattern matching misses.
