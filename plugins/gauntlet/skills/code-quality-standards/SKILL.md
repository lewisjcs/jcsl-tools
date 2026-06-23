---
name: code-quality-standards
description: Use before writing or committing code, when reviewing an implementation for correctness, or when code adds defensive null checks on typed values, wraps new behavior in old-behavior fallbacks, or hedges a requested breaking change. Trigger phrases include "is this production-ready", "does this match our patterns", "is this correct", "too defensive", "unnecessary guards", "unnecessary fallback".
---

# Code Quality Standards

## When NOT to use

- **Skill files (SKILL.md)** — use `skill-audit` for evaluating skills
- **Pressure-testing for hidden assumptions and failure modes** — use `adversarial-review` for hostile review
- **Style-only nits with no behavioral concerns** — use the language's linter directly (eslint, prettier, ruff, gofmt, etc.)

## Overview

Five prioritized principles for evaluating code. Working code is the minimum bar, not the goal. Code should be correct for this system, match existing patterns, and be bold about making the change that was asked for.

## Priorities (in order)

### 1. Correct over Working

Working code that technically solves the problem but hedges with unnecessary defensive checks is NOT correct. Correct code solves the problem for *this situation, in this system*, without unnecessary fallbacks.

**Be Bold:**

- Check return types and callers before adding guards -- if the type system or architecture guarantees a condition, trust it
- If asked for a breaking change or refactor, commit fully to that change -- don't wrap new behavior in fallbacks to old behavior
- Working code with three layers of fallbacks that ensure tests pass but the actual new code never runs is a failure
- Don't be afraid to make the change that was asked for

**Red flags:**

- Defensive checks for situations the system architecture makes impossible
- Fallback-to-old-behavior wrappers around new implementations
- Tests passing because fallbacks kick in, not because new code works

### 2. Concise and Clean

Follow DRY and Single Responsibility. Avoid unnecessary defensive code. If a guard clause doesn't protect against a real scenario in this system, remove it.

### 3. Pattern Matching

Use existing codebase patterns, not generic solutions. Before writing code, look at how similar things are done in this repo. Match the conventions, naming, structure, and error handling patterns already established.

### 4. Security Conscious

Flag security concerns directly. Don't silently add security-related code without explaining the threat model. If there's a real security concern, call it out.

### 5. Type Safety

Respect the type system. If types say a value can't be null, don't add null checks. If a function's return type guarantees a shape, don't add defensive parsing. The type system is documentation -- trust it.

## Common AI Anti-Patterns

- Adding try/catch around operations that can't fail in this system
- Null-checking values the type system guarantees are present
- Wrapping new behavior in fallback-to-old-behavior guards
- Adding three layers of fallbacks that ensure tests pass but bypass the actual change
- Using generic patterns when the codebase has specific conventions
- Over-commenting with obvious narration instead of letting clean code speak

## When Reviewing Code

- Does it solve the actual problem, or does it just "work"?
- Are defensive checks justified by the system's actual constraints?
- Does it match existing patterns in this codebase?
- Is the change bold enough, or hedged with unnecessary safety nets?

## Verification

Before claiming a change is correct:

1. **Enumerate every guard, fallback, or try/catch you added or kept.** For each, name the specific system constraint (type contract, framework guarantee, prior validation) that proves the guarded condition can or cannot occur. If you cannot name one, the guard is defensive — remove it or justify it inline as a comment with the threat scenario.
2. **For removed guards or fallbacks:** identify at least one call site that exercises the previously-guarded path. Confirm the path still behaves correctly without the guard. If no caller exercises the path, the guard was dead code.
3. **Run the language's static type checker, compile check, or linter** that the repo uses (e.g. `tsc --noEmit`, `mypy`, `cargo clippy`, `go vet`, `ruff check`). Confirm zero new errors.
4. **Run the affected tests.** Confirm tests pass *because the new code runs*, not because a fallback kicks in. If a test still passes when the new code is commented out, the test isn't covering the change.
5. **For pattern-matching claims:** cite at least one existing file in the repo using the same pattern. If you cannot find one, the change is introducing a new pattern — flag it explicitly.

If any verification step cannot be completed, state which one and why before claiming the change is correct.

## Sibling Skills

- `adversarial-review` — pressure-test changes for hidden assumptions, failure modes, blast radius. Use for non-trivial PRs after this skill's checks pass.
- `skill-audit` — evaluates SKILL.md files (not code). Different domain; use when reviewing skills.
