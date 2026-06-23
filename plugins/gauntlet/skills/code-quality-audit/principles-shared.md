# Code Quality Audit — Shared Principles

Loaded by every audit layer. Establishes philosophy and severity grading.

---

## Philosophy

Working code is the minimum bar, not the goal. Code should be correct for *this system, in this codebase*, without unnecessary fallbacks. Defensive code that masks bugs or hedges against impossible scenarios is a quality regression, not a quality improvement.

This skill audits AGAINST `code-quality-standards/SKILL.md` rules. The rules are anti-defensive by design — recommending a guard the rules forbid is a self-contradiction. Findings should surface code that violates the rules, not invent guards the rules disallow.

---

## Severity Guide

| Severity | Criteria | Action |
|----------|----------|--------|
| `violation` | Breaks a code-quality-standards rule (Rules 1-8). Defensive code masking a bug, fallback hiding a regression, type widening that obscures a contract. | Must fix |
| `warning` | Borderline — works but could be clearer or more idiomatic. A pattern that's defensible but inconsistent with the rest of the repo. | Should fix |
| `ok` | Passes the check | No action |

When in doubt, lean toward `warning` over `violation`. Only flag `violation` for clear rule breaches with concrete evidence in the diff.
