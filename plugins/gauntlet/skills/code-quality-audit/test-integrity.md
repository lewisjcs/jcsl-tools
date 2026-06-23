# Code Quality Audit — Layer 4: Test Integrity

Read [principles-shared.md](principles-shared.md) first for philosophy and severity grading. Then run the three checks below on every diff that touches test files or modifies both implementation and test code in the same change.

Skip this layer entirely if the diff contains no test file changes and no deletion of symbols. Early-exit keeps the audit fast on pure implementation changes.

---

## Check 1: Assertion Rewriting

**What to look for:** An existing test assertion was modified in the same diff that changed implementation behavior on the same logical path.

**Auditor question:** "Was this assertion updated to verify the new behavior is correct, or to make the test pass despite the new behavior being wrong?"

**Red flags — tag `violation`:**
- Expected value changes to `null`, `undefined`, `''`, `[]`, `{}`, or `false` — these are the cheap sentinel outputs a broken function returns when it fails early
- The assertion change and the implementation change are in the same function: the test calls the changed function directly, and the implementation change added an early-return or guard that causes the function to return early with a cheap value
- `expect(fn()).toBe(newValue)` where `newValue` matches what a broken implementation would return rather than what the spec requires
- An assertion was deleted without a replacement covering the same behavior — the test now calls the subject but asserts nothing meaningful about it (e.g., only `expect(result).toBeDefined()` remains)

**Not a violation — tag `ok`:**
- Expected value updated to match an intentional behavior change clearly described by the diff (e.g., a renamed field, a deliberate new return shape)
- Assertion added alongside genuinely new behavior (new test, not modification of existing assertion)

**Ambiguous — tag `warning`:**
- Intent cannot be determined from the diff alone — the assertion value changed but the reason is not described by the diff

---

## Check 2a: Stale Test Reference

**What to look for:** A diff deletes or renames a function, class, or export, but a test file still references the old name.

**Auditor steps:**
1. Collect all symbols removed or renamed in the diff (deleted `export function X`, deleted `export class X`, deleted `export const X`, deleted `export type X`, deleted `export interface X`)
2. Grep test files in scope for those symbol names
3. Flag any reference that survived

**Red flags — tag `violation`:**
- Test imports a deleted named export
- Test calls a function that was renamed without the test being updated
- Mock setup references a deleted module path

**Not a violation — tag `ok`:**
- The symbol was replaced by a re-export shim that preserves the old name
- The test file was updated in the same diff to remove the reference

**Ambiguous — tag `warning`:**
- Symbol was renamed (may be re-exported); cannot confirm without reading the full module

---

## Check 2b: Defensive Absence Assertion

**Governing principle:** `code-quality-standards` Rule 1 (no fallback-to-old-behavior) and Rule 2 (no defensive guards on typed values) applied to the test layer. A test asserting that a deleted thing is absent defends against a state the codebase now makes impossible. It is vacuously true and verifies nothing.

**What to look for:** A test assertion line with a `+` prefix in this diff that asserts something does NOT exist, is NOT called, or does NOT render — where the thing being asserted absent was deleted in the same diff.

**Red flags — tag `violation`:**
- `expect(screen.queryByTestId('deleted-component')).not.toBeInTheDocument()` added after the component is removed in the same diff
- `expect(fn).not.toHaveBeenCalled()` where `fn` is a function deleted in the same diff
- `expect(wrapper.find('DeletedComponent').exists()).toBe(false)` added in the same diff that removes `DeletedComponent`
- Any `.not.` assertion whose target is a symbol removed in the same diff

**Not a violation — tag `ok`:**
- The `.not.` assertion targets live code as a negative control (verifying the *replacement* behavior doesn't accidentally trigger old behavior)
- The assertion predates the diff — the assertion line has no `+` prefix (it appears in diff context, not as a new or changed line)

---

## Output Shape

For each file containing test code, report under a `**Test Integrity:**` subsection (parallel to `**Compliance:**`, `**Staleness:**`, `**Gaps:**`):

| Field | Content |
|-------|---------|
| `check` | `Assertion Rewriting` / `Stale Reference` / `Defensive Absence` |
| `tag` | `violation` / `warning` / `ok` |
| `location` | `file:line` |
| `finding` | One sentence describing what was found |
| `proposed-fix` | For `violation`: concrete edit — what the test should assert instead, or that it should be deleted. For `warning` or `ok`: `—` |

If no test files are in scope, report: `**Test Integrity:** no test files in diff — skipped`
