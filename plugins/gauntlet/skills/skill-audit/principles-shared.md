# Skill Audit — Shared Principles

Loaded by every audit layer. Establishes philosophy and severity grading.

> **Kept in sync with `skill-authoring-principles`.** This skill (the auditor) and `skill-authoring-principles` (the standard) encode the SAME empirical rules — size budget, focus, verification, phantom-alternatives. When one changes, update the other in the same pass, or the auditor will enforce a rule the standard has dropped.

---

## Philosophy

Skills are compact, always-on reference guides. They tell agents what they cannot discover from code, config, or tooling — and nothing else. Bloated or inaccurate skills degrade agent performance.

| Principle | Source |
|-----------|--------|
| Focused skills with 2-3 modules outperform comprehensive docs by +16.2pp avg (but over-narrow fragments hurt too) | [SkillsBench](https://arxiv.org/pdf/2602.12670) (86 tasks, 11 domains) |
| 80% of skills yielded zero improvement; the 7 that worked were narrow and domain-specific | [SWE-Skills-Bench](https://arxiv.org/pdf/2603.15401) (49 skills, 565 tasks) |
| Version-mismatched guidance caused ~10% performance degradation | [SWE-Skills-Bench](https://arxiv.org/pdf/2603.15401) |
| Verification loops produce stronger outcomes than vague reminders (a check can be a command OR a structured comparison) | [mdskills.ai best practices](https://www.mdskills.ai/docs/skill-best-practices) |
| Performance degrades monotonically with instruction count; long context buries mid-context info | [When Instructions Multiply](https://arxiv.org/abs/2509.21051) · [Lost in the Middle](https://arxiv.org/abs/2307.03172) |

---

## Severity Guide

| Severity | Criteria | Action |
|----------|----------|--------|
| `violation` | Breaks a researched principle (Rules 1-7), skill will malfunction or degrade performance | Must fix |
| `warning` | Missing best practice, skill works but could be better | Should fix |
| `ok` | Passes the check | No action |

When in doubt, lean toward `warning` over `violation`. Only flag `violation` for clear principle breaches backed by the research above.
