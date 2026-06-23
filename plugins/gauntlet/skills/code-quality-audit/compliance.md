# Code Quality Audit — Layer 1: Compliance Rules

Read [principles-shared.md](principles-shared.md) first for philosophy and severity grading. Then check every changed file against each rule below.

The rule source is `~/.claude/skills/code-quality-standards/SKILL.md` (user-global). These rules are paraphrased detection signals; cite the source skill when reporting `violation` findings.

---

## Rule 1: No Fallback-to-Old-Behavior Wrappers

When a change is asked for, commit fully. Don't wrap new behavior in fallbacks to the old behavior — that produces working code where tests pass via the fallback while the actual new code never runs.

**Check:** Does the diff add a guard that routes to old code when new code would otherwise run? Does it add a feature flag or conditional that defaults to the old path?

```typescript
// ❌ violation: new behavior wrapped in fallback to old
function copyToEnvironment(role, target, subject) {
  if (USE_NEW_COPY_FLOW) {
    return newCopyImplementation(role, target, subject);
  }
  return legacyCopyImplementation(role, target, subject); // old path still default
}

// ✅ ok: commit to the change
function copyToEnvironment(role, target, subject) {
  return newCopyImplementation(role, target, subject);
}
```

**Common violations:** Feature flags defaulting to false on new behavior, `if (NEW_FLOW)` wrappers added in the same PR that introduces the new flow, three-layer fallbacks that ensure tests pass but bypass the actual change.

---

## Rule 2: No Defensive Guards on Typed Values

If the type system says a value can't be null, don't add a null check. If a function's return type guarantees a shape, don't add defensive parsing.

**Check:** Does the diff add a guard against a state the type system already excludes?

```typescript
// ❌ violation: type says role is non-null
function process(role: AppInstallationRole) {
  if (!role) return; // type system excludes this
  // ...
}

// ✅ ok: trust the type
function process(role: AppInstallationRole) {
  // ...
}
```

**Common violations:** `if (!x)` checks where `x: NonNullable<T>`, optional chaining (`x?.field`) on values typed as required, `?? defaultValue` on non-nullable returns.

---

## Rule 3: No Defensive try/catch Around Framework Operations

Don't wrap framework operations in try/catch unless there's a specific failure mode you're handling. Generic "just in case" catches swallow real bugs.

**Check:** Does the diff add try/catch where the catch body has no specific recovery — just logs and continues, or rethrows the same error?

```typescript
// ❌ violation: catch with no specific recovery
try {
  await db.users.findById(id);
} catch (err) {
  console.error('Error', err); // not handled — masks the real failure
}

// ✅ ok: let it throw, framework handles it
await db.users.findById(id);
```

**Common violations:** `try { await frameworkCall(); } catch { /* swallow */ }`, catches that just `console.log` and rethrow, defensive try around an expression the framework already validates.

---

## Rule 4: No Backwards-Compat Shims for Unreleased Changes

If a change isn't released yet, there's no compat surface to maintain. Renaming an unused `_var`, keeping `// removed` comments, or re-exporting deleted types are noise.

**Check:** Does the diff preserve a removed export "for compat" when no consumer exists yet? Does it rename `removed_field` to `_removed_field` instead of deleting?

**Common violations:** `// removed in v2 — kept for compat` (when v2 isn't released), `export type OldName = NewName` re-exports, underscore-prefixed unused vars instead of deletion.

---

## Rule 5: No Silent Failures

Every `catch` block must either log with context, rethrow, or be explicitly justified inline. A silent catch that returns a default hides bugs.

**Check:** Does the diff add a catch that returns a value without logging or rethrowing?

```typescript
// ❌ violation: silent failure
try {
  return await fetchUser(id);
} catch {
  return null; // bug-masking
}

// ✅ ok: log and rethrow OR log with context
try {
  return await fetchUser(id);
} catch (err) {
  request.log(['error', traceId], `fetchUser ${id} failed: ${err}`);
  throw err;
}
```

**Common violations:** `catch { return null }`, `catch { return [] }`, `.catch(() => {})` chains that swallow without logging, `catch (e) {}` empty bodies.

---

## Rule 6: Type-System Trust

Don't widen types unnecessarily. Don't use `any` to bypass a type error — fix the root cause. Type assertions (`as X`) should be exceptional, not routine.

**Check:** Does the diff introduce `: any` or `as any` where a more specific type is derivable? Does it widen a return type to allow undefined when the function doesn't actually return undefined?

```typescript
// ❌ violation: any leak
function parse(input: string): any { // why any?
  return JSON.parse(input);
}

// ✅ ok: specific type
function parse<T>(input: string): T {
  return JSON.parse(input) as T;
}
```

**Common violations:** `: any` on function returns, `as any` casts, type widening from `T` to `T | undefined` to satisfy a type checker without changing behavior.

---

## Rule 7: Pattern Matching

New code should match existing patterns in the same repo. Generic library patterns are a smell when the codebase has specific conventions.

**Check:** For each new file or new code section, can you cite at least one existing file using the same pattern? If not, the diff introduces a novel pattern — flag it as a `warning` for review (not necessarily a violation, but worth surfacing).

**Common violations:** Generic logging library used when the repo has its own logger, ad-hoc error class instead of the project-standard `BadRequestError`/`NotFoundError`/etc, custom test setup instead of the repo's test framework conventions.

---

## Rule 8: Concise — DRY, No Dead Code

Don't introduce unused variables, dead branches, or duplicate logic. Don't introduce abstractions until the second consumer exists (YAGNI).

**Check:** Does the diff add code with no caller? Does it duplicate logic that exists elsewhere? Does it introduce a helper for a single use site?

**Common violations:** Variables declared and never read, conditional branches with no path that reaches them, helpers extracted prematurely (single caller), comment blocks describing what the code does (vs why).
