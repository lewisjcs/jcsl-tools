# Voice and Structure Patterns

What good documentation looks like across doc types. Loaded by `doc-review` and other doc-relevant skills. For the list of doc types these patterns apply to, see doc-types.md §1–6.

---

## Headings as TL;DR

**The pattern:** A reader should get the gist of decisions, recommendations, and scope from headings alone. Each heading is a summary statement, not a topic label. "Solution," "Approach," and "Background" fail the skim test. "Token Exchange Replaces Direct CMA Access" and "Why We Rejected Centralized Storage" pass it.

**What good looks like:** RFC headings that encode the decision: "Coarse-Grained Permissions Gate Feature Access; Fine-Grained Permissions Gate Data" rather than "Permission Model."

**What bad looks like:** Topic buckets — "Context," "Design," "Next Steps" — that force the reader to read every paragraph to understand what was decided.

**Doc-review lens:** Lens 4 (Voice/writing-style alignment) — skim-test failure signals the author wrote to document a process rather than communicate a decision. Finder pattern: headings matching `^#{2,4} (Context|Background|Approach|Solution|Design|Implementation|Next Steps|Summary)\s*$` (single-word or generic topic-bucket headings) are candidates for flagging.

**Sources:** Larson, [Writing Engineering Strategy](https://staffeng.com/guides/engineering-strategy/); Nygard, [Documenting Architecture Decisions](https://www.cognitect.com/blog/2011/11/15/documenting-architecture-decisions)

---

## Paragraph Density

**The pattern:** Prose blocks rarely exceed 3–4 sentences before a break (heading, code block, table, or list). Dense paragraphs signal narrative padding. When a paragraph exceeds 4 sentences, ask: should this be a table (comparisons), code block (data structures), list (enumerable outcomes), or is it hedging filler?

**What good looks like:** RFC summary — two-sentence problem statement, then a numbered solution list. Delivery Risks section — a table, not prose paragraphs.

**What bad looks like:** A three-paragraph "Context" that restates the problem from multiple angles with no list or table. A "Detailed Solution" that describes a data model in prose when a TypeScript interface block would be unambiguous.

**Doc-review lens:** Lens 4 (Voice/writing-style alignment). See also §Structured-then-prose pattern.

**Sources:** Tundra RFC corpus voice patterns; Nygard, [Documenting Architecture Decisions](https://www.cognitect.com/blog/2011/11/15/documenting-architecture-decisions)

---

## Active Voice for Directives

**The pattern:** Decision sections use active voice — the subject acts. Nygard's canonical form: "We will…" in the ADR Decision section, never "It was decided that…" Applies to RFC Detailed Solution sections and AGENTS.md guardrails. Passive voice is acceptable only in Context sections, where recording forces without editorializing is the intent.

**What good looks like:**
- "We will extract infrastructure stacks from CF-Infra and manage them in the service repo."
- "Do not use legacy CMA clients or `spaceContext.space.getSpace()` in new code."

**What bad looks like:**
- "It was agreed that extraction from CF-Infra would be undertaken."
- "Legacy CMA clients are not recommended."

**Doc-review lens:** Lens 4 (Voice/writing-style alignment). Finder flags passive constructions in Decision, Recommendation, and Directive sections. Active voice in Context sections is not flagged.

**Sources:** Nygard, [Documenting Architecture Decisions](https://www.cognitect.com/blog/2011/11/15/documenting-architecture-decisions)

---

## No Hedging on Directives

**The pattern:** Directive sections state decisions, recommendations, rules, and guardrails without soft hedges. Hedging converts a directive into a suggestion, removing accountability. `might`, `could`, `perhaps`, `consider`, `you may want to`, `optionally`, and `it might be worth` are directive killers (per Larson's specificity principle — see §Larson's specificity principle). Reserve conditional language for genuinely optional extensions, explicitly framed as such.

**What good looks like:**
- "Apply the litmus test to every line before adding it."
- "AI-generated AGENTS.md files require a human review pass before merge."

**What bad looks like:**
- "You might want to consider applying the litmus test."
- "Optionally, you can add a human review pass for AI-generated files."

**Doc-review lens:** Lens 4. See failure-modes.md §Lens 4, "Hedge words in directive sections" for the grep pattern.

**Sources:** Larson, [Writing Engineering Strategy](https://staffeng.com/guides/engineering-strategy/); `skill-authoring-principles` Rule 7

---

## Evergreen Language

**The pattern:** Shipped docs describe current state. History — what was removed, what the situation was before a migration — belongs in ADRs, commit messages, or PR descriptions. In AGENTS.md and CLAUDE.md this is especially load-bearing: these files are loaded into every agent session, and stale history actively misleads agents.

**What good looks like:**
- AGENTS.md: "Import from `@contentful/forma-36-react-components` is prohibited; use `@contentful/f36-components`." (states the current rule only)
- ADR Status field: "Superseded by [2026-05-12-cloudflare-workers-for-everything.md](./2026-05-12-cloudflare-workers-for-everything.md)." (history in the explicitly historical field)

**What bad looks like:**
- "Post-EXT-7298, the agent registration flow was unified." (post-ticket reference in a design doc body)
- RFC data model table row: `agent_token | removed | scrapped in M1`

**Doc-review lens:** Lens 1 (Memory-encoded rules). See failure-modes.md §Lens 1, "Evergreen-ness violation" for grep patterns.

**Sources:** `feedback_evergreen_docs_no_history` memory; cross-org RFC anti-exemplar analysis (doc-research-notes.md §Cross-org Confluence exemplars, anti-exemplar #2)

---

## Citation Conventions

**The pattern:** Every URL uses `[text](url)` format — never bare URLs. Anchor text must be descriptive: `[RFC: CMA Access Delegation for Agent Apps](url)`, not `[here](url)`. For Jira ADF and Confluence-specific constraints (bare URLs do not auto-link, inline `code` inside link text is dropped, `- [ ]` checkboxes are escaped), see tundra-patterns.md §Citation conventions in Jira and Confluence markdown.

**What good looks like:** `See [Writing Engineering Strategy](https://staffeng.com/guides/engineering-strategy/) for the specificity principle.`

**What bad looks like:** `Reference Documentation: <bare URL>` (no descriptive anchor text — readers cannot tell what the link points to without clicking).

**Doc-review lens:** Lens 3 (Accuracy of references). Finder pattern: `https?://[^\s)]+(?<!\))` on a line without a preceding `](`.

**Sources:** `feedback_jira_markdown_adf_lossy` memory; tundra-patterns.md §Citation conventions in Jira and Confluence markdown (Jira-specific detail)

---

## Structured-then-Prose Pattern

**The pattern:** Enumerable, comparative, or actionable content is a table or list — not prose. Prose handles continuous reasoning that does not decompose into parallel items. Sections open with structure and add prose as follow-up explanation, not the other way around.

**What good looks like:**
- RFC Delivery Risks: table first, one-sentence caveat if needed — not two preamble paragraphs.
- AGENTS.md Guardrails: Do/Don't bullet list with no preamble paragraph.

**What bad looks like:**
- A "Delivery Risks" section that opens with paragraphs before the table.
- An RFC Context that buries the forcing function in paragraph three when a Force | Implication table would surface it in three lines.

**Doc-review lens:** Lens 4 (Voice/writing-style alignment). Cross-reference §Paragraph density.

**Sources:** contentful-update-agents-md conventions.md §4 (Do/Don't bullets, no prose paragraphs in AGENTS.md); Tundra RFC corpus structural patterns

---

## Larson's Specificity Principle

**The pattern:** Specific statements create alignment. Generic statements create the illusion of alignment. This is the governing *why* behind §No hedging on directives, §Headings as TL;DR, and the Tundra house style for decision sections. "We will use Braintrust as the eval framework for this feature's regression suite" creates accountability; "We should consider using an eval framework at some point" does not — every reader walks away with a different understanding of "some point."

**What good looks like:**
- Milestone: "M2: Evals suite passes on staging (target: 2026-06-15, Owner: Team Tundra)."
- AGENTS.md: "Never call `spaceContext.space.getSpace()` — use the injected `cmaClient` instead."

**What bad looks like:**
- Milestone: "Complete evals work." (no criteria, no date, no owner)
- AGENTS.md: "Prefer the injected client where possible."

**Doc-review lens:** Lens 4. Specificity failures are distinct from hedge-word failures — a statement can be active-voice and non-hedged yet still generic. The Finder flags milestones and directives without an owner, date, or concrete criteria; the Validator adjudicates whether the specificity gap is structural (a real failure) or intentional (e.g., a known TBD with explicit follow-up).

**Sources:** Larson, [Writing Engineering Strategy](https://staffeng.com/guides/engineering-strategy/): "Specific statements create alignment; generic statements create the illusion of alignment."
