# Sources — Roster and Fidelity Ladder

## Table of contents
- [Round 1 — Locate (no cloning)](#round-1--locate-no-cloning)
- [Round 2 — Deepen (targeted)](#round-2--deepen-targeted)
- [Source Fidelity Ladder](#source-fidelity-ladder)
- [The rule](#the-rule)

Load this file before Round 1 of `method.md`'s Discover phase. It defines the exact tool
roster per round and the provenance tag strings the Sources section (and `output-shapes.md`)
must use verbatim.

## Round 1 — Locate (no cloning)

Cast the discovery net without cloning anything. Run these in parallel where possible:

- **Glean `search`** — the primary net. Broad, cross-system (Confluence, Slack, Docs, indexed
  code), but uncloned/lossy and may lag the live repo or ticket state.
- **GitHub MCP `search_code`** — org-wide `contentful/*` code search, no local clone required.
- **GitHub MCP `search_issues`** — org-wide `contentful/*` issue/PR search.
- **Jira MCP `searchJiraIssuesUsingJql`** — live Jira search by JQL.

## Round 2 — Deepen (targeted)

Once Round 1 has located candidate files/issues/docs, deepen on the specific hits:

- **Local `repos/<name>` grep** — if the repo is already cloned locally, grep it directly
  (highest fidelity, zero lag).
- **GitHub MCP `get_file_contents`** — if the repo is not cloned, read the exact file via the
  API instead of cloning.
- **Glean `read_document`** — full-content read of a Glean-indexed doc found in Round 1.
- **Jira `getJiraIssue`** — live, full-fidelity read of a specific issue found in Round 1.

## Source Fidelity Ladder

Four domains, each with a ground-truth rung, a fallback rung, and the exact tag string the
Sources section must record.

| Domain | Ground truth | Fallback | Sources-section tag |
|--------|-------------|----------|---------------------|
| Code | Local `repos/<name>` grep | GitHub MCP `search_code` / `get_file_contents` → Glean code index | `local clone` / `GitHub API` / `Glean index (may lag)` |
| Jira | Jira MCP JQL + issue read | Glean Jira index | `live Jira` / `Glean` |
| Docs-Slack | Glean `search` + `read_document` | — | `Glean` |
| Web | `WebFetch` / `WebSearch` | — | `web, fetched <date>` |

## The rule

Glean is the discovery net — breadth, uncloned, may lag. This applies when reading or
deepening on a specific hit (Round 2), not to Round 1 discovery, which runs org-wide
regardless of clone status. For Jira, the dedicated Jira MCP is the ground-truth rung. For
Code, prefer the local `repos/<name>` clone; use GitHub MCP `get_file_contents` only when the
repo is not cloned locally. Fall back to Glean only when the dedicated MCP can't reach the item.
