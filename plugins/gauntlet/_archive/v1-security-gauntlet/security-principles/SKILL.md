---
name: security-principles
description: Use when reviewing code, plans, or artifacts for security concerns; threat-modeling a feature; deciding whether a defensive check is justified; or asked "is this safe", "what's the threat model", "is this a security issue".
---

# Security Principles

Reference content for security-relevant work in the Tundra stack. Load when assessing security risk, applying threat models, or deciding whether a control is justified.

## When NOT to use

- **General code review** — use `/gauntlet` for multi-skill review or `/code-quality-audit` for convention-only audit
- **Style, lint, or defensive-code patterns** — use `code-quality-standards`
- **No security question on the table** — use `code-quality-standards`; load this skill only when a security concern is load-bearing

## Reference files (load on demand)

| File | Purpose |
|---|---|
| [threat-categories.md](threat-categories.md) | Seven threat categories (AuthN, AuthZ, input validation, secrets, data exposure, supply chain, blast radius) with detection signals and mitigations. |
| [owasp-mapping.md](owasp-mapping.md) | OWASP Top 10 (2025) and API Security Top 10 (2023) mapped to Tundra stack code patterns. |
| [contentful-patterns.md](contentful-patterns.md) | Tundra-specific vulnerability shapes: tenant isolation, APS authorization, CMA token scoping, and multi-region data exposure. |
| [ai-tool-security.md](ai-tool-security.md) | Prompt injection, tool-to-AI injection, and MCP server attack surfaces for agentic workflows. |

## Lens index

When applying security review, the seven lenses (in the order security-finder applies them) map to reference-file sections as follows:

| # | Lens | Primary file | Secondary references |
|---|---|---|---|
| 1 | Authentication | threat-categories.md §1 | owasp-mapping.md (A07, API02), contentful-patterns.md |
| 2 | Authorization | threat-categories.md §2 | owasp-mapping.md (A01, API01, API05), contentful-patterns.md |
| 3 | Input validation | threat-categories.md §3 | owasp-mapping.md (A05), ai-tool-security.md (prompt injection) |
| 4 | Secrets & credentials | threat-categories.md §4 | owasp-mapping.md (A04), ai-tool-security.md (secrets in prompts), contentful-patterns.md (CMA token scoping) |
| 5 | Data exposure | threat-categories.md §5 | owasp-mapping.md (A02, API03, API08), contentful-patterns.md (multi-region) |
| 6 | Supply chain | threat-categories.md §6 | owasp-mapping.md (A03, API09) |
| 7 | Blast radius | threat-categories.md §7 | contentful-patterns.md (tenant isolation, multi-region) |

## Sibling Skills

- `security-gauntlet` — Finder/Validator pattern; loads this skill at Validator invocation time.
- `code-quality-standards` — pattern alignment and defensive-code anti-patterns. Different domain.
- `adversarial-review` — pressure-tests hidden assumptions. Different domain; not security-specific.

## Maintenance

Source verification dates are in `projects/active/gauntlet/research/security-sources.md`. Re-verify quarterly.
