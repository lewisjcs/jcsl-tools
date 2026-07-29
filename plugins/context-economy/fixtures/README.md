# Context Economy Party — Behavioral Fixtures

Manual operator-in-loop verification scenarios. Not automated test suites — these measure whether the Party skills fire and guide correct behavior in real sessions.

## How to verify

1. Enable the context-economy plugin and reload the session (`/reload-plugins`).
2. For each fixture, open a **fresh session** (so there is no prior plugin-invocation history).
3. Paste the contents of `prompt.md` as your first message.
4. Score against `expected.md` — mark each checkbox as pass or fail.
5. Record results in your journal or task notes.

**Target:** ≥3/5 fixtures pass before ship.

## Optional: Langfuse cost read-back

If running locally with `langfuse_hook.py`, record `cost_usd` per fixture ID in a JSONL file for before/after comparison. See `projects/active/token-optimization/langfuse-spike/` for setup. This is NOT required for plugin install or use.
