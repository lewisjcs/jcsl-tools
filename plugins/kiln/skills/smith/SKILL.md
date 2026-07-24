---
name: smith
description: The Smith — reads recent Kiln runs and briefs you on how they went (accuracy, friction, speed, cost) with advisory suggestions for improving the tool. Use for "how have my Kiln runs been going", "kiln retro", "smith briefing", "review my last N kiln runs", or a morning tool-health check. Read-only — proposes, never edits.
---

# The Smith — Kiln Run Retrospective (read-only)

The Smith is a Kiln Party member whose job is to reforge the tools between firings. It reads the
run trail Kiln already leaves and reports how the runs went. It **proposes only — it never edits
Kiln, never re-invokes a member, never touches a fixture.**

## Steps

1. **Harvest.** Run the bundled harvester over the workspace (default last 10 runs; honor a user-given N):
   `bash ${CLAUDE_PLUGIN_ROOT}/skills/smith/smith-harvest.sh --workspace "<WORKSPACE>" --last <N>`
   where `<WORKSPACE>` is the OS root the session launched from (the dir containing `projects/active/`),
   NOT a git root. The harvester writes one `retro.json` per run and prints their paths.

   The driver runs under `set -euo pipefail`: if one run's harvest fails, it exits non-zero having
   only printed paths for the runs processed before the failure. If the harvester exits non-zero or
   prints fewer paths than the requested N, do not hard-fail the briefing — proceed with whatever
   `retro.json` files were written and note in the briefing that the harvest was partial, naming which
   runs are missing.

2. **Read the digests.** Read each printed `retro.json`. Each holds: `run_id`, `tasks` (array of
   `{n, spec, quality, criteria_met, criteria_total, critical_findings}` per task), `friction`
   (verbatim ledger lines), `first_ts`/`last_ts`, `fix_loops`, and best-effort `session_id`/`cost_usd`/
   `cost_note`.

3. **Synthesize the briefing** in this exact shape:

   ```
   ## The Smith — briefing over <N> runs (<oldest date> → <newest date>)

   ### How the runs went
   - Accuracy: <M/N runs clean on first pass; total fix-loops; any HARD STOP/escalation>
   - Friction: <the 2–4 most repeated friction patterns across runs, quoted, with run ids>
   - Speed: <median wall-clock per run from first_ts→last_ts; slowest run + why if friction explains it>
   - Cost: <median/total cost_usd across runs where available; note runs with cost_note (unavailable)>

   ### Suggestions (advisory — not applied)
   - <each suggestion ties to a SPECIFIC repeated signal, names the file it would touch
     (SKILL.md / gates.md / a prompt), and states it is NOT yet eval-verified>

   ### The Smith's own cost
   - This briefing read <N> runs; harvester + synthesis ≈ <rough token/$ if known>.
   ```

4. **Guardrails (state these hold):** every suggestion is advisory and unverified — Slice 1 has no eval
   gate yet (that is Slice 2). Never propose editing a fixture. Flag any suggestion whose evidence comes
   from a run on an older Kiln version as possibly stale (compare the run's ENGINE/version ledger line).
   If the harvest was partial (Step 1), say so up front in the briefing rather than silently reporting
   on fewer runs than requested.

## What The Smith does NOT do (Slice 1)
- Does not edit Kiln source, gates, or prompts.
- Does not re-invoke Kiln members or replay runs.
- Does not run the eval harness (Slice 2).
