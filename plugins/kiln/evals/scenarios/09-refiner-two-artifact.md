# Eval Scenario 09: Refiner Two-Artifact Design-Dialogue

## Scenario

The orchestrator is invoked with `/kiln "add webhook retry logic"` — a raw idea with fuzzy
acceptance criteria. REFINE routing fires and the `refiner` agent is dispatched.

The Refiner must:
1. Run Compounds-first exploration before asking any questions
2. Propose 2-3 named approach candidates with blast-radius notes
3. Ask at most 4 questions (one per turn) to clarify unknowns
4. Write `{{RUN_FOLDER}}/design.md` with 4 required sections
5. Write `{{RUN_FOLDER}}/spec-draft.md` with 5 required EARS sections
6. Run the self-review verifier and pass all 4 checks
7. Emit `REFINER_DONE: {{RUN_FOLDER}}/design.md + {{RUN_FOLDER}}/spec-draft.md written | run-id: <slug>`

## Expected Behavior

- Before asking the first question, the Refiner runs `compounds query` and `compounds impact`
- Approach candidates are presented to the user with blast-radius context from Compounds output
- Questions stay within the ≤4 budget; once the budget is exhausted the Refiner proceeds to writing
- `design.md` contains exactly 4 `##` section headers: Problem, Approaches Considered, Architecture Sketch, Risks/Out-of-scope
- `spec-draft.md` contains exactly 5 `##` section headers: Problem Statement, Acceptance Criteria, File Paths, Root Cause, Out of Scope
- `## Approaches Considered` is non-empty: at least one named approach with chosen rationale
- Neither artifact contains `TODO`, `TBD`, or `[[` placeholders
- Done signal matches: `REFINER_DONE: <run-folder>/design.md + <run-folder>/spec-draft.md written | run-id: <slug>`

## Pass Condition

- Both artifact files exist at `{{RUN_FOLDER}}/design.md` and `{{RUN_FOLDER}}/spec-draft.md`
- Section-count verifier passes for both files (4 and 5 respectively)
- `## Approaches Considered` contains ≥1 named approach with rationale
- No placeholder tokens remain in either artifact
- Done signal emitted with correct format

## Fail Condition

- Either artifact is missing
- Wrong number of `##` headers in either file
- `## Approaches Considered` is empty or contains only a placeholder
- Placeholders (`TODO`, `TBD`, `[[`) remain in either artifact
- Done signal references only `spec-draft.md` (old format)
- More than 4 questions asked before writing artifacts
- Compounds exploration skipped (no `compounds query` or `compounds impact` called)
