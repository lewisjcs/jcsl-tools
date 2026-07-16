# Doc Types Reference

Six document types used across Applied AI Solutions (AIS) and the broader Contentful engineering org. Loaded by `doc-review` and other doc-relevant skills.

---

## 1. RFC (Request for Comments)

**Purpose:** Define and gain alignment on a technical solution to a scoped problem before implementation begins.

**Audience:** Engineers, architects, and DevOps who will build or be affected by the solution; the Technical Lead owns authorship; RFC exists to surface misalignment before code starts, not document decisions already made.

**Structural template (three tiers — observed across the ECO/AIS/ProdDev corpus, not the flat template):**

*Near-universal (every deliverable RFC has these):*
1. Front-matter details table — status badge (RFC Status: DRAFT/UNDER REVIEW/APPROVED/ABANDONED) + Author + upstream link (Reference Documentation → PRD, optionally RAPID; Jira Deliverable). Canonical 6 fields: RFC Status, Author, Contributors, Reference Documentation, Jira Deliverable, Review Date.
2. Summary — what-it-does + (if no parent owns the problem) current-state problem; leads with the solution when a parent PRD/epic does own it (see Authoring guidance).
3. Audience table — Role (AGREE/INPUT/CONSULT) | Individual(s)/Team(s) | Detail. CONSULT is an AIS extension beyond the org AGREE/INPUT pair.
4. Effect — observable outcomes per actor role if adopted; separate from Summary.
5. Context — settled information only; flag anything still open so reviewers focus there.
6. Detailed Solution — prose + inline code blocks for all data structures; never prose-only for data shapes.
7. Delivery Approach & Milestones — t-shirt sizing + rationale; Milestone/Description/Target Date/Owner; Rollout; Testing Plan.
8. Delivery Risks & Mitigations — Risk | Mitigation | Owner (Owner column required per org template).

*Conditional (present when the change is a service/API — routinely empty otherwise; do NOT treat as required):*
- Technical Diagram, API Specification, Data Model, Dependencies.

*Maturity signals (the best-reviewed RFCs add these though the base template omits them):*
- Open Questions (numbered, inline recommendations, framed as future work not blockers); Scope / Non-Goals (explicit boundary — see Authoring guidance); Rollback Plan; dated Decisions / Revisions log.

**Authoring guidance (write-time rules — consumed by kiln-native doc authoring):**

- **Problem clarity is mandatory; problem length is not — ownership decides length.** If a parent PRD/epic/prior-RFC owns the problem, state it in 1–2 sentences, *link* the parent, and spend the body on solution + rationale (do NOT re-narrate the parent's problem). If the RFC itself owns the problem (net-new tool, a proposed standard, an org-process change with no upstream PRD), narrate the problem in depth. Rule of thumb: specificity over length — "specific statements create alignment; generic statements create the illusion of alignment" (Larson); "readers are brought up to speed but some previous knowledge can be assumed and detailed info can be linked to" (Design Docs at Google).
- **Rationale = inline rejected-alternatives or a pro/con table — never Q&A.** Put the rejected option next to the decision it lost to: `Rejected — X: because…`, or a pro/con options table with `(recommended)` marked. Alternatives-with-trade-offs are mandatory, not optional.
- **Scope boundary is an explicit surface, not silence.** Name what the RFC does not own — a Scope/Non-Goals section, inline "owned by X, not this RFC", or Open Questions. Non-goals are things that could reasonably be goals but are explicitly chosen not to be — not negated outcomes.
- **Be opinionated; show your work.** Stake a recommendation and defend it with cited reasoning. See voice-and-structure.md for the specificity and active-voice rules.
- **AI-feature RFCs carry a first-class eval/success-metrics plan.** See contentful-patterns.md §Evals discipline — state how the feature is measured and graduated, plus cost model and rollback criteria.

**Voice cues:**
- Declarative and opinionated: stake a recommendation and defend it — no hedge language
- Larson's rule applies directly: "Specific statements create alignment; generic statements create the illusion of alignment" (https://staffeng.com/guides/engineering-strategy/)
- Active voice throughout; short paragraphs (prose blocks rarely exceed 3–4 sentences before a break)
- Parenthetical scope constraints are acceptable and preferred over waffling prose: "(at the time of writing, only user identity)"
- Templates evolve from repeat reviewer questions (Orosz, https://blog.pragmaticengineer.com/scaling-engineering-teams-via-writing-things-down-rfcs/); the AIS audience table with AGREE/INPUT/CONSULT is the formalized answer to "who must approve this and in what capacity"
- **AI features require an evals plan.** Per Mike Kivisto's February 2026 All Hands directive (https://docs.google.com/presentation/d/1qb1NNCIjIakodLN8YGZrckM8ilMeiTCDlFucIqdkpHM): "If an LLM is part of the feature you are shipping you need to use AI Evals. Full stop." An RFC proposing an AI-powered feature that defers evals to a future sprint is directly contradicting this mandate. Regression evals are required whenever prompts change, models swap, or tools/agents are added.

**Doc-review lens emphasis:**
- **Lens 2 (Internal consistency)** is the most load-bearing lens for RFCs. The Alternatives/Rationale sections frequently drift from the chosen approach. The RFC Status badge and Architecture Review outcome must stay in sync. Milestone-table dates must align with the delivery-approach phases. **Also flag a Summary that re-narrates a linked parent PRD/epic's problem instead of linking it (the layering rule in Authoring guidance) — but only when a parent is actually linked.**
- **Lens 1 (Memory-encoded rules):** Evergreen rule applies — no "was removed" table rows in entity/field inventories; no `post-EXT-XXXX` history references in the body. CONSULT row absence is flaggable when the RFC has cross-boundary implications.

**Common failure modes:** See failure-modes.md §RFC — covers evergreen violations in data model tables, Risks & Mitigations missing Owner column, RFC Status badge out of sync with review outcome, evals omission in AI feature docs.

**Source:** ProdDev Hub org RFC template (internal Confluence, ProdDev space); Standard Artifacts artifact hierarchy (internal Confluence, ProdDev space); Orosz/Uber RFC practice (https://blog.pragmaticengineer.com/scaling-engineering-teams-via-writing-things-down-rfcs/); Larson engineering strategy guide (https://staffeng.com/guides/engineering-strategy/)

---

## 2. PRD (Product Requirements Document)

**Purpose:** Define what the product should do and the business value it delivers at the Deliverable level. The PRD is the upstream artifact an RFC depends on; the RFC's Reference Documentation field links to the parent PRD.

**Audience:** PM and EM are co-owners; Design, Research, Marketing, Finance, Security, and Staff Engineering have sign-off roles; engineers read PRDs to understand the "why" before the RFC explains the "how."

**Structural template (recommended sections in order):**
1. Executive Summary — standalone summary of the deliverable and its business value
2. Business Value Summary — quantified or qualified customer value; must be independently deliverable, not contingent on another PRD
3. Detailed Solution Description — product requirements only; the technical solution goes in the RFC, not here
4. Functional Requirements — what the product does
5. Non-Functional Requirements — performance, accessibility, security, compliance requirements
6. Key Milestones — milestones represent testable customer value, not engineering completion dates
7. Dependencies — Related PRD/BRDs; risks if a dependency slips; shared ownership; third-party services; Legal/Security/compliance
8. T-Shirt Sizing — size estimate at the Deliverable level
9. How will we measure success? — success metrics and instrumentation plan
10. Risks and Mitigations — product-level risks (technical risks go in the RFC)
11. GTM Approach — go-to-market plan and launch requirements
12. FAQ — anticipated questions from stakeholders
13. Change Log — tracks significant changes to the PRD over its lifecycle

**Voice cues:**
- PM-owned prose: describes user-facing outcomes and business value, not implementation choices
- Requirement verbs are `shall`, `must`, `should`, or `will`; intrusion of implementation verbs (`the service will return`, `we will implement`, `the API endpoint accepts`) signals content that belongs in the RFC, not the PRD
- Milestones describe what customers can do or experience, not what engineers ship
- Fractional PRD pattern is valid: split when a PRD spans too many systems, ownership is unclear, or the initiative is better executed in phases
- Do not duplicate the RFC's technical solution; cross-reference the RFC in a Reference Documentation pointer

**Doc-review lens emphasis:**
- **Lens 4 (Voice/writing-style alignment):** PRD prose should be requirements-oriented, not implementation-specifying; technical implementation language signals misplaced content (belongs in the RFC).
- **Lens 2 (Internal consistency):** Milestone section must reflect independent deliverable value; a PRD whose milestones are only meaningful in aggregate with another PRD is out of scope.

**Common failure modes:** See failure-modes.md §PRD — covers PRDs that duplicate RFC technical content, milestone tables that describe engineering completion rather than customer value, and PRDs missing the explicit RFC handoff pointer.

**Source:** ProdDev Hub PRD guide (internal Confluence, ProdDev space); Standard Artifacts artifact hierarchy (internal Confluence, ProdDev space)

---

## 3. RAPID (Decision-Allocation Framework)

**Purpose:** Allocate decision-making roles for a constrained choice — naming, build-vs-acquire, pricing, unclear cross-product ownership — before the RFC designs the solution. RAPID and RFC are orthogonal; RAPID decides upstream, RFC designs downstream.

**Audience:** The Decider (single named person), Recommenders, Agree stakeholders (veto power — must be as few as possible), Input contributors (provide data and facts), and Perform implementors. RAPID is not a broadcast document; audience is limited to active decision participants.

**Structural template (recommended sections in order):**
1. Decision Summary table — driver, approver, contributors, informed, due date
2. Background — why a decision was needed and what was at stake; trigger case for the RAPID
3. Options comparison table — Option 1 | Option 2 | … with Pros and Cons (or +/− columns); recommended option labeled "RECOMMENDED" or highlighted
4. Decision — chosen option and rationale; written in past tense once the decision is made; names the single Decider explicitly
5. RAPID Roles table — maps each role (Recommend/Agree/Perform/Input/Decide) to the named individual(s); Agree row must be as short as possible

**Voice cues:**
- Decision section is in past tense once decided; no hedging
- For a RAPID still in draft (Decider not yet named or due date in the future), present-tense or conditional phrasing in the Decision section is correct and should not be flagged as a voice violation — the past-tense rule applies only to RAPIDs whose decision has been made
- Options comparison is neutral in framing — pros and cons stated without editorializing before the Decision section
- The RAPID vocabulary (Recommend/Agree/Perform/Input/Decide) maps to the AIS RFC audience table: AGREE and INPUT roles in the RFC audience table borrow directly from RAPID; CONSULT is an AIS RFC extension not present in RAPID itself
- RAPID and RFC are explicitly not alternatives: RAPID resolves a constrained upstream choice; the RFC designs the solution to implement that choice. The RFC's Reference Documentation field can link to the preceding RAPID.
- The org's canonical RAPID definition (internal Confluence) is the normative reference for role definitions and trigger cases

**Doc-review lens emphasis:**
- **Lens 2 (Internal consistency):** Agree role must map to veto-power stakeholders, not broadcast participants — an Agree list longer than 3–4 people signals the role is being used as INPUT or INFORM. Decision section must match the recommended option in the options table.

**Common failure modes:** See failure-modes.md §RAPID — covers Agree role overloaded with non-veto participants, Decision section written before all Input contributors are named, RAPID used for decisions that should be an RFC (technical solution design) or a PRD change (scope negotiation).

**Source:** Org RAPID definition (internal Confluence); Standard Artifacts artifact hierarchy confirming RAPID as upstream of RFC (internal Confluence, ProdDev space)

---

## 4. ADR (Architecture Decision Record)

**Purpose:** Capture a single architecture decision — its context, the decision made, and all consequences (positive, negative, neutral) — as an immutable log entry stored in version control alongside the code it governs.

**Audience:** Future developers encountering the code governed by the decision; primary reader value is motivation and consequences, not the decision itself. ADRs are written after the decision is made (or while fleshing out a just-made decision), not to debate options.

**Structural template (recommended sections in order):**
1. Title — short noun phrase naming the decision
2. Status — proposed / accepted / deprecated / superseded (superseded entries include a bidirectional link to the replacement ADR; superseded ADRs are retained, not deleted)
3. Context — forces at play: technological, organizational, project-local; value-neutral; states facts, not opinions; no argumentation
4. Decision — response to the forces; full sentences, active voice: "We will…" — never passive, never hedged; argumentation lives here, not in Context
5. Consequences — all consequences, positive, negative, and neutral; not just the justification for the decision
6. (Optional, MADR 4.0 extension) Considered Options — explicit options comparison with Pros/Cons per option; maps to the options table patterns common in AIS RFCs

**Voice cues:**
- Active voice in Decision section is a hard rule (Nygard 2011, https://www.cognitect.com/blog/2011/11/15/documenting-architecture-decisions): "We will…" not "It was decided that…"
- Full sentences in Decision section; bullets are acceptable in Consequences and Considered Options but not as substitutes for the decision statement itself
- Context section does not argue; argumentation is reserved for Decision
- One decision per file; the whole document should be one to two pages
- **Filename convention is a hard rule WITH scope awareness:**
  - Tundra, ECO-space, and ExO repos: `YYYY-MM-DD-title.md` (date-based)
  - SDK team repos (e.g., ContentfulBundle, contentful.php): `0001-title.md` (Nygard sequential)
  - Neither is org-mandated; the conventions coexist. A date-based filename in an SDK repo or a sequential filename in a Tundra repo is a deviation from team convention — flag it.
  - MADR 4.0 (https://adr.github.io/madr/) uses sequential numbering by default; Tundra's date-based deviation is deliberate and known.
- When an ADR introduces a new invariant, reference it from ARCHITECTURE.md or AGENTS.md so agents and reviewers can discover the constraint
- Superseded ADRs include bidirectional links: the new ADR references what it supersedes; the old ADR is updated to point to its replacement

**Doc-review lens emphasis:**
- **Lens 1 (Memory-encoded rules), ADR filename sub-rule:** In Tundra/ECO/ExO repos, the correct pattern is `^\d{4}-\d{2}-\d{2}-` (date-based) — flag any ADR filename that does not match this pattern. The diagnostic for the wrong-convention case is `^\d{4}-[^0-9]` (four digits followed by a non-digit, indicating sequential). In SDK repos the correct pattern is the inverse — `^\d{4}-[^0-9]` is correct, `^\d{4}-\d{2}-\d{2}-` is the deviation. The lens requires repo-context to adjudicate.
- **Lens 2 (Internal consistency):** Status field must stay in sync with the supersession chain — a "superseded" ADR without a link to its replacement is incomplete.

**Common failure modes:** See failure-modes.md §ADR — covers wrong filename convention for the repo's team, passive voice in Decision section, superseded ADRs deleted rather than retained, and Context section containing argumentation that belongs in Decision.

**Source:** Nygard 2011 (https://www.cognitect.com/blog/2011/11/15/documenting-architecture-decisions) as origin; MADR 4.0 (https://adr.github.io/madr/) as modern adaptation with explicit options comparison and `decision-makers`/`consulted`/`informed` frontmatter; cross-org ADR filename convention finding (doc-research-notes.md §ADR Filename Convention)

---

## 5. README

**Purpose:** Project-level entry point that orients any reader — human or agent — to the repository: what it does, how to set it up, and where to find deeper documentation.

**Audience:** New contributors, external developers evaluating the project, agents beginning a session in the repo; readers make decisions about whether this repo is relevant to their task and how to get started.

**Structural template (recommended sections in order):**
1. Project name and one-line description — what this repo does, without jargon
2. Badges (CI status, npm version, license) — machine-readable health signals
3. Overview — 2–5 sentences of context: what problem it solves, who uses it, how it fits into the broader system
4. Prerequisites — runtime/Node version, required tooling, credentials or environment setup (`.env.example` reference)
5. Installation — exact commands; use the repo's prescribed package manager
6. Usage — representative example(s) showing the primary use case
7. Architecture — brief pointer to ARCHITECTURE.md or a diagram for deeper structure; do not duplicate ARCHITECTURE.md content inline
8. Contributing — link to CONTRIBUTING.md; include the commit convention and PR process if not in CONTRIBUTING.md
9. License

**Voice cues:**
- README is the entry point for humans; AGENTS.md is the entry point for agents — the two files are complementary and non-redundant. README may include setup commands; AGENTS.md must not (setup commands in AGENTS.md are `bloat` per the `contentful-update-agents-md` conventions)
- Distinguish project README from skill SKILL.md: README is project-level; SKILL.md is skill-level with required frontmatter (`name`, `description`, `triggers`)
- Describe current capabilities and current setup, not history; README is evergreen content
- Owner pointers go to teams or CODEOWNERS paths, not individual names

**Doc-review lens emphasis:**
- **Lens 3 (Accuracy of references)** is the primary lens for READMEs: links go stale. Installation commands, badge URLs, and architecture diagram links are the highest-risk staleness surfaces. Flag any URL pattern that warrants verification and any command that may have been superseded by a package manager or script change.
- **Lens 1 (Memory-encoded rules):** No individual names as owner pointers; no local/personal paths; no personal tooling skill references.

**Common failure modes:** See failure-modes.md §README — covers stale installation commands, badge URLs pointing to deleted CI workflows, architecture diagrams embedded inline rather than linked, and personal name as owner contact.

**Source:** Cross-org Confluence exemplars (doc-research-notes.md §Cross-org Confluence exemplars); contentful-update-agents-md conventions.md (README as the correct destination for setup commands that do not belong in AGENTS.md)

---

## 6. AGENTS.md (and CLAUDE.md by extension)

**Purpose:** Provide coding agents with only what they cannot discover from code, configuration, or tooling — non-discoverable constraints, sharp edges, invariants, and safety rules — in a compact, always-on routing table.

**Audience:** Any AI coding agent (GitHub Copilot, Cursor, Bito, Claude Code, etc.) beginning a session in the repo; also read by engineers onboarding to the codebase. AGENTS.md is the public/agnostic routing table. CLAUDE.md is the internal-only broader project instructions for Claude Code specifically (carries Slack channels, Jira keys, team workflow references that cannot ship publicly).

**Structural template (recommended sections in order — AGENTS.md):**
1. Brief intro (1–3 lines) — repo purpose, monorepo tool, package manager; nothing discoverable from package.json
2. Routing table — "What you need | Where to look"; points to which files and directories matter for which tasks
3. Guardrails — Do/Don't bullets or named Anti-Patterns and Invariants; non-discoverable constraints only
4. Commands — only if non-obvious (e.g., Docker required for tests, `.env.example` must be copied first)
5. Safety / Permissions — never-do and ask-before-doing rules; scope of high-risk changes

**Structural template (recommended sections in order — CLAUDE.md):**
1. Identity / Purpose — project name, repo purpose, team context (may include internal team names and Jira project keys)
2. Commands — build, test, lint, format with exact invocations
3. Architecture — pointer to ARCHITECTURE.md plus key patterns not visible there
4. Conventions — commit format, branch naming, code style not enforced by linters
5. Testing — test runner, coverage expectations, how to run specific suites
6. Sharp Edges — things that break silently; non-obvious coupling; invariants agents must respect
7. Reference to AGENTS.md — CLAUDE.md explicitly references `@AGENTS.md`; AGENTS.md is the routing table; CLAUDE.md is broader project instructions

**Voice cues:**
- Apply the litmus test to every line before adding it: "If removing this line would cause an agent to violate a repo constraint it has no other way to learn, the line belongs. Otherwise it does not." (contentful-update-agents-md conventions.md, Section 1)
- **Bloat rule (hard rule):** Do not include content discoverable elsewhere. `npm run` script enumerations, build commands already in package.json, file structure listings that duplicate the filesystem, setup commands (those belong in README), testing taxonomy, and file/module naming conventions enforced by linters are all `bloat`. Bloated context files reduce agent task success rates and increase inference cost (contentful-update-agents-md conventions.md, Section 1).
- **Misplaced rule (hard rule):** State management decision trees, multi-line code examples, dependency/build/lint tool preferences, and procedural instructions belong in skills and hooks — not AGENTS.md. Content in AGENTS.md that belongs elsewhere is tagged `misplaced` by the `contentful-update-agents-md` skill.
- **Size rule (hard rule):** Root AGENTS.md must stay under ~100 lines. Use nested AGENTS.md files in subdirectories for scope-specific guidance in large repos. The ~100-line target is a content discipline, not a soft guideline — it ensures the routing table remains scannable and does not degrade agent performance.
- **Deliberate divergence from community spec:** The community spec at https://agents.md/ lists setup/build commands as a "popular choice" to include. Contentful's doctrine **rejects** setup commands in AGENTS.md (they are `bloat` — discoverable from README and package.json). This is an intentional org-level restriction that narrows the community spec to the highest-signal content for codebases with established tooling.
- **Evergreen rule (hard rule):** Describe current state only. No "was removed," "post-EXT-XXXX," "as of [month year] update" language. History belongs in ADRs. Per `feedback_evergreen_docs_no_history`: this is especially load-bearing for AGENTS.md and CLAUDE.md because they are loaded into every agent session — stale history language actively misleads agents.
- AGENTS.md is agnostic (ships to public repos); CLAUDE.md is internal-only and must never be proposed for public repos. Public repos use AGENTS.md only.
- When an ADR introduces a new invariant, reference it from AGENTS.md so agents can discover the constraint without reading all ADRs.
- **AI-generated AGENTS.md files require a human review pass** before merge. Per Mike Kivisto's May 6 2026 directive (https://contentful.slack.com/archives/C07RKUD0W20/p1778092500679499): "What David did is probably a great jumpstart but from now until....someday(?)....we need to verify what is being output." Automated generation is a valid starting point; human verification before merge is non-optional and not a temporary bridging measure.

**Doc-review lens emphasis:**
- **Lens 1 (Memory-encoded rules), multiple sub-rules apply:**
  - Evergreen rule: flag any history language or temporal references in the body
  - Bloat sub-rule (NEW): flag content discoverable from package.json, tsconfig.json, lint configs, or directory structure
  - No personal tooling: flag skill references to tools not present in the repo's installed skill set
  - No local paths: flag `~/`, `/tmp/`, `.worktrees/`, personal Confluence space URLs (`atlassian.net/wiki/spaces/~\d+/`)
  - No individual names: owner pointers must use CODEOWNERS paths or team aliases

**Common failure modes:** See failure-modes.md §AGENTS.md — covers bloat (npm script enumeration, setup commands), misplaced content (decision trees, multi-line examples), evergreen violations (history language, post-migration notes), personal tooling references, and AI-generated files merged without human review.

**Source:** `contentful-update-agents-md` skill in `contentful/agents-kit` (canonical enforcement layer; conventions.md litmus test, bloat/misplaced/ok taxonomy, size rule, skeleton structure); community AGENTS.md spec at https://agents.md/ (community standard + Contentful's deliberate divergence on setup commands); cartographer knowledge files (`file-format-agents-md.md`, `file-format-claude-md.md`) in `contentful/agents-kit`; Mike Kivisto May 2026 directive on AI-generated artifact verification (https://contentful.slack.com/archives/C07RKUD0W20/p1778092500679499)
