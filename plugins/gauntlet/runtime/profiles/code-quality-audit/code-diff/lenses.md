# Code-diff audit lenses

Applies when the artifact-family profile supplied for this run is
`jcsl:artifact-family:code-diff`. Four layers, worked in order: compliance,
staleness, gap analysis, test integrity. Each rule, signal, or check below is
this profile's anchor for a finding in that layer — cite it exactly as named.

## Layer 1 — Compliance

Compliance checks the diff against `references/code-quality-standards.md`'s
anti-defensive-code priorities. Anchor findings in this layer `compliance`/`R<N>`.

### R1: No Fallback-to-Old-Behavior Wrappers

When a change is asked for, commit fully. Don't wrap new behavior in
fallbacks to the old behavior — that produces working code where tests pass
via the fallback while the actual new code never runs.

**Check:** Does the diff add a guard that routes to old code when new code
would otherwise run? Does it add a feature flag or conditional that defaults
to the old path?

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

**Common violations:** Feature flags defaulting to false on new behavior,
`if (NEW_FLOW)` wrappers added in the same change that introduces the new
flow, three-layer fallbacks that ensure tests pass but bypass the actual
change.

### R2: No Defensive Guards on Typed Values

If the type system says a value can't be null, don't add a null check. If a
function's return type guarantees a shape, don't add defensive parsing.

**Check:** Does the diff add a guard against a state the type system already
excludes?

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

**Common violations:** `if (!x)` checks where `x: NonNullable<T>`, optional
chaining (`x?.field`) on values typed as required, `?? defaultValue` on
non-nullable returns.

### R3: No Defensive try/catch Around Framework Operations

Don't wrap framework operations in try/catch unless there's a specific
failure mode you're handling. Generic "just in case" catches swallow real
bugs.

**Check:** Does the diff add try/catch where the catch body has no specific
recovery — just logs and continues, or rethrows the same error?

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

**Common violations:** `try { await frameworkCall(); } catch { /* swallow */ }`,
catches that just log and rethrow, defensive try around an expression the
framework already validates.

### R4: No Backwards-Compat Shims for Unreleased Changes

If a change isn't released yet, there's no compat surface to maintain.
Renaming an unused variable to keep it around, keeping `// removed` comments,
or re-exporting deleted types are noise.

**Check:** Does the diff preserve a removed export "for compat" when no
consumer exists yet? Does it rename a removed field to an underscore-prefixed
version instead of deleting it?

```typescript
// ❌ violation: unreleased rename kept "for compat" with no consumer
export type OldWidgetOptions = WidgetOptions; // removed in v2 — kept for compat

// ✅ ok: delete the old name outright; nothing depends on it yet
export type WidgetOptions = { size: number; label: string };
```

**Common violations:** `// removed in v2 — kept for compat` comments on
unreleased code, re-export shims for types or functions with zero real
callers, underscore-prefixed unused fields instead of deletion.

### R5: No Silent Failures

Every `catch` block must either log with context, rethrow, or be explicitly
justified inline. A silent catch that returns a default hides bugs.

**Check:** Does the diff add a catch that returns a value without logging or
rethrowing?

```typescript
// ❌ violation: silent failure
try {
  return await fetchUser(id);
} catch {
  return null; // bug-masking
}

// ✅ ok: log with context, then rethrow
try {
  return await fetchUser(id);
} catch (err) {
  logger.error('fetchUser failed', { id, err });
  throw err;
}
```

**Common violations:** `catch { return null }`, `catch { return [] }`,
`.catch(() => {})` chains that swallow without logging, `catch (e) {}` empty
bodies.

### R6: Type-System Trust

Don't widen types unnecessarily. Don't use `any` to bypass a type error —
fix the root cause. Type assertions (`as X`) should be exceptional, not
routine.

**Check:** Does the diff introduce `: any` or `as any` where a more specific
type is derivable? Does it widen a return type to allow undefined when the
function doesn't actually return undefined?

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

**Common violations:** `: any` on function returns, `as any` casts, type
widening from `T` to `T | undefined` to satisfy a type checker without
changing behavior.

### R7: Pattern Matching

New code should match existing patterns in the same repo. Generic library
patterns are a smell when the codebase has specific conventions.

**Check:** For each new file or new code section, can you cite at least one
existing file using the same pattern? If not, the diff introduces a novel
pattern — flag it as a `warning` (not necessarily a violation, but worth
surfacing).

```typescript
// ❌ violation: introduces a generic logging call when the repo has its own logger
console.log('user created', userId);

// ✅ ok: matches the repo's existing logger convention
logger.info('user.created', { userId });
```

**Common violations:** Generic logging library used when the repo has its
own logger, ad-hoc error class instead of the project's established error
base, custom test setup instead of the repo's test framework conventions.

### R8: Concise — DRY, No Dead Code

Don't introduce unused variables, dead branches, or duplicate logic. Don't
introduce abstractions until the second consumer exists (YAGNI). Don't
narrate the diff in comments — comments explain the code to a maintainer,
not the change to a reviewer.

**Check:** Does the diff add code with no caller? Does it duplicate logic
that exists elsewhere? Does it introduce a helper for a single use site?
Does a comment explain the change instead of the code?

```typescript
// ❌ violation: dead branch, premature single-use helper, reviewer-narration comment
function formatLabel(value: string) {
  return value.trim();
}
// now we correctly trim the label before rendering
const label = formatLabel(rawLabel); // formatLabel has exactly one caller

if (false) {
  // unreachable — left over from the old flow
}

// ✅ ok: inline the single-use logic, drop the dead branch and the narration
const label = rawLabel.trim();
```

**Common violations:** Variables declared and never read, conditional
branches with no path that reaches them, helpers extracted prematurely
(single caller), comment blocks describing what the code does (vs why),
reviewer-narration comments ("now we correctly…", "this used to…"), comments
that only restate the next line, comments citing where code came from (a
ticket, a PR, an old file) instead of explaining the code itself.

### R9: Guard/Logic Consistency

When a change widens or narrows what counts as a valid value, every guard,
validator, or dispatch/routing check on that value has to be audited and
updated in the same change — a guard written against the old validity model
can silently reject (or wrongly accept) inputs the new logic handles
differently.

**Check:** Does the diff change what a function accepts or rejects for a
value? If so, does it also update every other guard/validator/dispatch check
on that same value elsewhere in the diff or the reviewed tree? Is there a
test at the path where both the guard and the changed logic run?

```typescript
// ❌ violation: logic widened to accept empty arrays; the guard was not updated
// logic.ts
function process(items: string[]) {
  return items.map(normalize); // now handles [] fine
}

// guard.ts — unchanged, still rejects the case logic.ts now handles
function isValidItems(items: string[]) {
  return items.length > 0; // stale: rejects the newly-valid empty case
}

// ✅ ok: guard updated in the same diff to match the widened validity model
function isValidItems(items: string[]) {
  return Array.isArray(items); // matches process()'s widened acceptance
}
```

**Common violations:** A validity-widening or -narrowing fix that changes one
function's accepted domain without a corresponding update to every other
guard/validator/dispatch check on the same value, a shared helper with no
test at the guard-and-logic intersection path.

### R10: No Reimplementation

New code should reuse an existing helper or util instead of re-implementing
its behavior under a different name.

**Check:** Does the diff add a new function or class that duplicates
behavior an existing helper, util, or base class already provides?

```typescript
// ❌ violation: hand-rolled retry loop duplicates src/lib/retry.ts's withRetry()
async function fetchWithRetries(url: string) {
  for (let i = 0; i < 3; i++) {
    try {
      return await fetch(url);
    } catch {
      // retry
    }
  }
}

// ✅ ok: reuse the existing helper
async function fetchWithRetries(url: string) {
  return withRetry(() => fetch(url), { attempts: 3 });
}
```

**Common violations:** A new function replicating an existing util's logic
under a different name, a new class re-implementing a shared base class's
method instead of extending it, logic copy-pasted from another file instead
of importing the shared implementation.

## Layer 2 — Staleness

Staleness cross-references the diff's patterns against deprecation signals
already present in the codebase. Anchor findings in this layer
`staleness`/`<signal-name>`.

### deprecated-modified

The diff modifies (not just calls) a function annotated `@deprecated`.

**Check:** Does the diff change the body of a function or method carrying an
`@deprecated` annotation, rather than its replacement?

```typescript
// ❌ violation: modified a deprecated function instead of its replacement
/** @deprecated use fetchUserV2 instead */
function fetchUser(id: string) {
  return db.users.findOne({ id, includeArchived: true }); // new behavior added here
}

// ✅ ok: extend the replacement instead
function fetchUserV2(id: string) {
  return db.users.findOne({ id, includeArchived: true });
}
```

**Common violations:** Adding a parameter or branch to a `@deprecated`
function, fixing a bug inside deprecated code instead of its replacement,
removing the `@deprecated` annotation without migrating callers.

### stale-todo

A `// TODO: remove` comment more than six months old (heuristic — tune when
calibration data exists, via `git blame` where available) that the diff
neither acts on nor refreshes.

**Check:** Does the diff touch a file carrying a stale removal TODO without
resolving or updating it?

```typescript
// ❌ violation: touches the function next to a stale removal TODO and leaves it
// TODO: remove after the migration ships (git blame: 8 months old)
const legacyFlag = readLegacyFlag();
function computeLimit() {
  return legacyFlag ? 10 : readLimit(); // new logic added alongside the stale TODO
}

// ✅ ok: the diff resolves the TODO — removes the code it names
function computeLimit() {
  return readLimit();
}
```

**Common violations:** Leaving a >6-month-old removal TODO untouched while
editing the surrounding function, adding new code next to a stale TODO
instead of resolving it.

### legacy-import

New code imports from a directory explicitly marked legacy.

**Check:** Does a new or changed import reference a `legacy/` or
`deprecated/` directory?

```typescript
// ❌ violation: new import from a directory marked legacy
import { parse } from '../legacy/parser';

// ✅ ok: import from the current location
import { parse } from '../parser';
```

**Common violations:** A new file importing from a `legacy/` or
`deprecated/` path, new code re-exporting a legacy module.

### migrated-api

The diff uses an older API when 80%+ of callers in the repo already use a
newer one (heuristic — tune when calibration data exists).

**Check:** If 80%+ of the repo's call sites use a newer API for this
operation, does the diff introduce a new call to the older one?

```typescript
// ❌ violation: new call site uses the pre-migration API most callers left behind
const rows = db.query(sql);

// ✅ ok: matches the migrated majority
const rows = db.queryTyped<Row>(sql);
```

**Common violations:** Copy-pasting an old call site instead of the current
pattern, new code matching a minority (pre-migration) pattern found via
search instead of the dominant one.

### stale-pattern-doc

The diff reintroduces a pattern the repo's own documentation (CLAUDE.md,
ARCHITECTURE.md, or similar) explicitly marks deprecated.

**Check:** Does repo documentation explicitly retire this pattern, and does
the diff use it anyway?

```typescript
// ❌ violation: ARCHITECTURE.md says "singletons are deprecated; use DI"
class ConfigSingleton {
  private static instance: ConfigSingleton;
  static get() {
    return (ConfigSingleton.instance ??= new ConfigSingleton());
  }
}

// ✅ ok: constructed through the documented DI mechanism
function buildConfig(container: Container) {
  return container.resolve(Config);
}
```

**Common violations:** New code copying an example the docs call out as an
anti-pattern, resurrecting a pattern a decision doc explicitly retired.

### deprecated-dep

New code imports from a package the manifest (`package.json`, `Cargo.toml`,
`requirements.txt`, or similar) marks deprecated.

**Check:** Does the diff add an import from a dependency the manifest flags
as deprecated?

```typescript
// ❌ violation: package.json marks "legacy-http-client" deprecated
import { request } from 'legacy-http-client';

// ✅ ok: uses the current dependency
import { request } from 'http-client';
```

**Common violations:** New import from a dependency flagged deprecated in
the manifest, a new call site added to an existing deprecated dependency
instead of migrating it.

## Layer 3 — Gap Analysis

Gap analysis checks for missing protections the rulebook expects but the
diff doesn't break outright. Anchor findings in this layer `gaps`/`gap-<N>`.

### gap-1: New public function without test

**Check:** Is a function or class newly exported in the diff missing a
corresponding test?

```typescript
// ❌ gap: exported with no test referencing it anywhere in the diff or repo
export function computeTotal(items: Item[]) {
  return items.reduce((sum, i) => sum + i.price, 0);
}

// ✅ ok: exported alongside a test that exercises it
test('computeTotal sums item prices', () => {
  expect(computeTotal([{ price: 3 }, { price: 4 }])).toBe(7);
});
```

**Common violations:** A new exported function with zero test references, a
new exported class whose public methods have no test coverage.

### gap-2: New export without explicit type

**Check:** Does a new or modified export leave its return type to inference
rather than annotating it?

```typescript
// ❌ gap: return type is whatever JSON.parse happens to infer
export function parseConfig(raw: string) {
  return JSON.parse(raw);
}

// ✅ ok: return type is an explicit, documented contract
export function parseConfig(raw: string): Config {
  return JSON.parse(raw) as Config;
}
```

**Common violations:** Exported function relying on an inferred return type,
exported const initialized from a call whose return type isn't pinned.

### gap-3: New throw without error context

**Check:** Does a new `throw` omit the detail an operator would need to
triage it?

```typescript
// ❌ gap: no detail — indistinguishable from any other failure
throw new Error('failed');

// ✅ ok: names the operation, the input, and the cause
throw new Error(`failed to copy role from ${env}: ${cause}`);
```

**Common violations:** Bare `throw new Error('failed')` with no operand
context, a rethrow that drops the original error's message.

### gap-4: New branch without test coverage

**Check:** Does a new `if`/`else`/`switch`/ternary on a typed value leave
one or more branches without a corresponding test case? (Heuristic only —
the auditor surfaces this, it doesn't mechanically verify coverage; a
reviewer judges adequacy.)

```typescript
// ❌ gap: only the "admin" branch has a test; the else branch is untested
function limitFor(role: Role) {
  return role === 'admin' ? Infinity : 10;
}

// ✅ ok: both branches have a test case
test('admin has no limit', () => expect(limitFor('admin')).toBe(Infinity));
test('non-admin is capped at 10', () => expect(limitFor('member')).toBe(10));
```

**Common violations:** A new conditional with only the happy-path branch
tested, a new `switch` statement missing a case's test.

### gap-5: New public API change without docstring/JSDoc

**Check:** Is a modified or added public function, method, or class missing
an accompanying JSDoc/docstring update?

```typescript
// ❌ gap: new parameter added, docstring left describing the old signature
/** Copies a role to the target environment. */
function copyToEnvironment(role: Role, target: Env, force: boolean) { /* ... */ }

// ✅ ok: docstring updated to document the new parameter
/**
 * Copies a role to the target environment.
 * @param force - when true, overwrites an existing role of the same name.
 */
function copyToEnvironment(role: Role, target: Env, force: boolean) { /* ... */ }
```

**Common violations:** Public signature changes with a stale docstring, a
new public class with no class-level doc comment.

### gap-6: New error class not extending the project base

**Check:** Does a new error class extend `Error` directly instead of the
project's own error-class module, so it bypasses the typed error responses
the project maps at its API boundaries?

```typescript
// ❌ gap: bypasses the project's error-class module
class InvalidInputError extends Error {}

// ✅ ok: routes through the project's error-class module
class InvalidInputError extends AppError {}
```

**Common violations:** A new error class skipping the project's base error
type, an error thrown as a plain `Error` where the codebase's convention is
a typed error response at the API boundary.

### gap-7: New env var without default in config

**Check:** Does a new `process.env.X` reference lack a corresponding entry
in `.env.example` or the config schema?

```typescript
// ❌ gap: read with no .env.example / config-schema entry
const timeoutMs = Number(process.env.FEATURE_TIMEOUT_MS);

// ✅ ok: documented in the config surface
// .env.example: FEATURE_TIMEOUT_MS=5000
const timeoutMs = Number(process.env.FEATURE_TIMEOUT_MS);
```

**Common violations:** New env var read with no `.env.example`/schema entry,
an env-var default hardcoded inline instead of documented in config.

### gap-8: New event emission without a consumer

**Check:** Where the codebase's convention is that state changes emit
domain events, does the diff add a new emission with no listener, handler,
or subscriber for it anywhere in the reviewed tree — and no note that the
consumer lives elsewhere?

```typescript
// ❌ gap: no subscriber anywhere in the reviewed tree, no note that one exists elsewhere
await emitDomainEvent('order.shipped', { orderId });

// ✅ ok: a handler in the reviewed tree subscribes to the event
onDomainEvent('order.shipped', notifyFulfillment);
```

**Common violations:** A new event emission with no matching subscriber in
the reviewed tree and no note that the consumer is external, a
state-changing code path that skips emitting the event the codebase's
convention expects.

### gap-9: Schema constraint looser than its data-layer consumer

**Check:** When a schema or type validates a value that's consumed
downstream by a narrower concrete type, does the schema match that
consumer's exact constraint — not just the parser's looser acceptance set?

```typescript
// ❌ gap: schema accepts any non-empty string; the consumer only accepts UUIDs
const schema = z.object({ id: z.string().min(1) });

function lookup(id: string) {
  return db.findByUuid(id as Uuid); // throws at runtime on any non-UUID id
}

// ✅ ok: schema matches lookup()'s actual constraint
const schema = z.object({ id: z.string().uuid() });
```

**Common violations:** A schema/type that matches the parser's acceptance
set but not a downstream transform's narrower requirement, a layered
validator (JSON schema plus a business guard, a GraphQL type plus a resolver
assertion) where the outer layer is looser than the inner one it feeds.

### gap-10: Prose/text-matcher heuristic with no invariant test

Tag findings under this heuristic `warning` — it flags an absent protection,
not a proven defect.

**Check:** Does the diff add or rely on a gate that decides an outcome by
matching prose — a phrase list, regex, or keyword denylist — without a
co-required invariant test on the actual runtime control it's meant to
protect? Any such gate is evadable by rewording, by construction.

```typescript
// ❌ gap (warning): only defense is a keyword match; no other check
function isRiskyChange(diffText: string) {
  return /delete|drop table/i.test(diffText);
}

// ✅ ok: prose match AND-composed with an invariant check on the real control
function isRiskyChange(diffText: string) {
  return /delete|drop table/i.test(diffText) || affectsProtectedTable(diffText);
}
```

**Common violations:** A safety/quality gate whose only defense is a keyword
or regex match, a classification step with no test asserting the underlying
runtime control (not just the prose scan) actually rejects the unsafe case.

## Layer 4 — Test Integrity

Test integrity runs on every diff that touches test files or deletes
symbols; skip it otherwise. Anchor findings in this layer
`test-integrity`/`<check-name>`.

### assertion-rewriting

An existing test assertion was modified in the same diff that changed
implementation behavior on the same logical path.

**Auditor question:** Was this assertion updated to verify the new behavior
is correct, or to make the test pass despite the new behavior being wrong?

```typescript
// ❌ violation: assertion rewritten to match a broken early-return
// implementation — early-return guard added in this diff
function computeDiscount(order: Order) {
  if (!order.items.length) return 0; // added in this diff
  return calculate(order);
}

// test — expected value changed to match the early-return's sentinel output
expect(computeDiscount(order)).toBe(0); // was 12.5 before this diff

// ✅ ok: assertion unchanged; still asserts the real computed value
expect(computeDiscount(order)).toBe(12.5);
```

**Common violations:** Expected value changed to `null`, `undefined`, `''`,
`[]`, `{}`, or `false` — the cheap sentinel outputs a broken function
returns when it fails early; the assertion and the implementation change are
in the same function on the same path; an assertion deleted without a
replacement covering the same behavior (only `toBeDefined()` remains).

### stale-test-reference

A diff deletes or renames a function, class, or export, but a test file
still references the old name.

**Auditor steps:** Collect every symbol removed or renamed in the diff, grep
test files in scope for those names, flag any reference that survived.

```typescript
// deleted in this diff: export function legacyFormat(x: string) { ... }

// ❌ violation: test still imports the deleted export
import { legacyFormat } from '../format';
expect(legacyFormat('x')).toBe('X');

// ✅ ok: test updated to the replacement, or removed with the deletion
import { format } from '../format';
expect(format('x')).toBe('X');
```

**Common violations:** Test imports a deleted named export, test calls a
function that was renamed without the test being updated, mock setup
references a deleted module path.

### defensive-absence-assertion

A test assertion with a `+` prefix in this diff asserts something does NOT
exist, is NOT called, or does NOT render — where the thing being asserted
absent was deleted in the same diff. This defends against a state the
codebase now makes impossible; it is vacuously true and verifies nothing.

```typescript
// DeletedComponent removed in this diff

// ❌ violation: new assertion that a deleted thing is absent — vacuously true
expect(screen.queryByTestId('deleted-component')).not.toBeInTheDocument();

// ✅ ok: asserts the replacement's real behavior instead
expect(screen.getByTestId('replacement-component')).toBeInTheDocument();
```

**Common violations:** `.not.toHaveBeenCalled()` on a function deleted in
the same diff, a `.not.` assertion whose target was removed in the same diff,
an absence assertion added as a substitute for asserting the replacement's
actual behavior. Not a violation: a `.not.` assertion targeting live code as
a negative control, or one that predates the diff (no `+` prefix).

### dispatch-layer-test

For a change behind a matcher, router, or dispatcher, does at least one test
read the real routing/dispatch configuration — not a piped-input shortcut
that bypasses it — and assert the route exists? For a guard fix, does a test
prove the guard has teeth: failing against the pre-fix code, passing against
the fix?

```typescript
// ❌ violation: feeds the handler directly, bypasses the router config,
// never proves 'foo' events are actually routed here
test('handles the event', () => {
  expect(handleEvent({ type: 'foo' })).toBe('ok');
});

// ✅ ok: asserts against the real routing config
test('router dispatches "foo" events to handleEvent', () => {
  const matcher = loadRouterConfig().matchers.find((m) => m.event === 'foo');
  expect(matcher?.handler).toBe('handleEvent');
});
```

**Common violations:** A handler test that pipes input straight to the
function under test without touching the router/matcher config, a "fixed"
guard with no test that fails against the pre-fix code (no red/green proof
the guard has teeth), a coupled-bug fix where the newly-reachable path ships
without its own guard test landing first.

## Output discipline

- One finding per rule/signal/check hit — do not bundle multiple hits under
  one finding.
- Set `layer` to the layer the finding came from (`compliance`, `staleness`,
  `gaps`, `test-integrity`) and `rule` to the specific anchor within that
  layer, e.g. `compliance`/`R2`, `staleness`/`stale-todo`,
  `test-integrity`/`assertion-rewriting`.
- `location` uses this family's location format: `file:line` — the post-diff
  path for changed files, or the repo-relative reviewed-tree path for
  cross-boundary findings.
- `level` follows the persona's guide (`violation`/`warning`/`gap`); when in
  doubt between `violation` and `warning`, choose `warning`.
- A layer that produces no findings is a clean pass for that layer, not an
  omission — never invent a finding to fill it.
