# Output Shapes — report / decision-memo / context-handoff skeletons

Load at Synthesize (`method.md` Phase 4). Pick the shape per `SKILL.md` Step 1's
inference rule (report / memo / handoff), copy the matching skeleton below into
the destination file, and fill in each section per its one-line gloss. Every
shape closes with the shared `## Sources` block defined at the end of this file.

## report

Use for a "how / where / why" question — a synthesis of what exists and why,
with no explicit recommendation.

```markdown
# <question>

## Answer
<the direct answer, 1-3 sentences, before any supporting detail>

## Findings
<the verified, load-bearing claims and their detail, each carrying a source pointer>

## Sources
<shared Sources block — see below>
```

## decision-memo

Use for a "should we / which" question — a recommendation backed by the options
weighed and the evidence behind them.

```markdown
# Decision: <question>

## Recommendation
<the recommended choice, stated directly, 1-3 sentences>

## Options considered
<each option weighed, with its trade-offs, including the one recommended>

## Evidence
<the verified, load-bearing claims that support the recommendation, each carrying a source pointer>

## Sources
<shared Sources block — see below>
```

## context-handoff

Use when the research feeds other work (for example, a Kiln Designer or
Crafter picking up from here). This skeleton matches `kiln:scout`'s Output
Contract verbatim (`plugins/kiln/agents/scout.md`) — the four sections below
are identical to Scout's, section for section, so a prospector handoff and a
Scout `research.md` are interchangeable.

```markdown
## Findings
<what exists / what the work likely entails>

## Affected Systems
<files, services, patterns in scope>

## Open Gaps
<the questions that could not be resolved — these seed the next agent's first questions>

## Sources
<shared Sources block — see below>
```

## Shared Sources block

Every shape above closes with a `## Sources` section using this bullet format:

`- <path/URL/key> — <fidelity tag> [<staleness caveat if any>]`

The `<fidelity tag>` values are `sources.md`'s provenance tag strings, used
verbatim — do not restate the fidelity ladder here (see `sources.md`). One
example bullet per distinct tag family:

- `repos/user_interface/src/foo.ts` — local clone
- `contentful/extensibility-api#412` — GitHub API
- "App SDK migration notes" (Confluence) — Glean index (may lag)
- EXT-7293 — live Jira
- "Tundra sprint retro, 2026-06-10" (Slack) — Glean
- https://www.rfc-editor.org/rfc/rfc9110 — web, fetched 2026-07-14
