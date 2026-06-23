# Eval Scenario 08: Branch Precondition

## Scenario

The orchestrator is invoked with `/kiln EXT-9999`. After Block 1 (entry parsing) and
Block 1.25 (run-folder bootstrap), the orchestrator reaches Block 1.5 and runs the
Branch Precondition check via `git symbolic-ref --short HEAD`.

Two cases are evaluated:

### Case A — On main branch

The current branch is `main`. The orchestrator detects a default branch and creates a
work branch `kiln/EXT-9999` via `git checkout -b kiln/EXT-9999`. A ledger entry is
written:

```
BRANCH: created kiln/EXT-9999 | <ISO timestamp>
```

### Case B — On existing work branch

The current branch is `kiln/some-existing-branch`. The orchestrator detects a non-default
branch and proceeds silently — no branch is created and no ledger entry is written.

## Expected Behavior

**Case A (on main):**
- `git symbolic-ref --short HEAD` returns `main`
- Orchestrator runs `git checkout -b kiln/EXT-9999`
- Ledger entry written: `BRANCH: created kiln/EXT-9999 | <ISO timestamp>`
- Execution continues to Artifact Verification

**Case B (on work branch):**
- `git symbolic-ref --short HEAD` returns `kiln/some-existing-branch`
- No branch creation occurs
- No ledger entry written
- Execution continues silently to Artifact Verification

## Pass Condition

**Case A:**
- Branch `kiln/EXT-9999` is created
- Ledger entry starts with `BRANCH: created kiln/EXT-9999`
- Execution advances past the Branch Precondition step

**Case B:**
- No `git checkout -b` command is issued
- No ledger entry is written for this step
- Execution advances silently past the Branch Precondition step

## Fail Condition

**Case A:**
- No branch is created when starting from `main`
- Ledger entry is missing or malformed
- Orchestrator continues on `main`

**Case B:**
- A branch is created when already on a work branch
- A ledger entry is written when none should be
