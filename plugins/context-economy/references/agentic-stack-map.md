# Agentic Stack → Context-Economy Plugin Map

Maps the Starburst/Glean enterprise context stack to this plugin's skills. Use when deciding which skill owns a context decision.

```
Consumer          →  You (orchestrator agent on Opus main thread)
Context serving   →  Scoped return payloads from subagents; handoff resume prompts
Context assembly  →  context-assembly skill (what to load, when, how much)
Enterprise layer  →  Skills, memories, CLAUDE.md — governed static prefix
Context harvest   →  Subagent explore/search; MCP on demand — not bulk pre-load
Substrate         →  Repos, Jira, Confluence, Glean — live federated sources
Data              →  Raw files, logs, warehouses — never dump wholesale into main thread
```

| Stack layer | Plugin skill / artifact | Lever |
|---|---|---|
| **Serving** | `delegating-to-subagents` return contract | Parent receives summary + paths, not raw tool dumps |
| **Assembly** | `context-assembly` | Narrow reads; grep-before-read; file-then-grep for logs |
| **Enterprise** | Other skills (gauntlet, jira, …) | Progressive disclosure — metadata at discovery, body on activation |
| **Harvesting** | `delegating-to-subagents` + explore subagents | Noisy search runs off-thread |
| **Session reset** | `context-economy` + `handoff` + reset-nudge hook | `/clear` at boundaries; checkpoint mid-task |
| **Enforced behavior** | reset-nudge Stop hook | Turn-count reminder when hygiene slips |

**Design implication:** the main thread is the expensive consumer. Every layer above "data" should reduce what reaches it — assembly before serving, harvesting before assembly, reset before unbounded growth.
