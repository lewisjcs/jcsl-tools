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
   (verbatim ledger lines), `first_ts`/`last_ts`, `duration_note`, `fix_loops`, and best-effort
   `session_id`/`cost_usd`/`cost_note`. `friction` is a coarse keyword net (it can match clean/summary
   lines like "0 gaps" or "no deviations found") — read each captured line yourself and judge whether
   it actually indicates friction before counting it; never report friction volume from the array
   length alone.

   Each digest also carries `cost_by_member` (Slice 3a): `{members:[{agent, turns, cost_usd}],
   conductor_cost_usd, note}` — per-Kiln-member cost joined from the local Langfuse substrate by
   session id. It is best-effort and fail-open: an empty `members` array with a `note` is the normal
   case for runs that predate member-trace wiring or when the substrate is down — never treat empty
   members as an error, and read the `note` to see why.

3. **Synthesize the briefing** in this exact shape:

   ```
   ## The Smith — briefing over <N> runs (<oldest date> → <newest date>)

   ### How the runs went
   - Accuracy: <M/N runs clean on first pass; total fix-loops; any HARD STOP/escalation>
   - Friction: <the 2–4 most repeated friction patterns across runs, quoted, with run ids>
   - Speed: <median calendar span per run (first_ts→last_ts) — NOTE: this is wall-clock incl. human-gated idle, not compute time; honor each run's duration_note; say "not comparable" for runs whose duration_note is "unavailable"; slowest run + why if friction explains it>
   - Cost: <median/total cost_usd across runs where available; note runs with cost_note (unavailable)>
     <when cost_by_member has members: the per-member split (Crafter/Inspector/Curator/conductor),
     stated as DIRECTIONAL — read patterns across runs, not point values. Single-run per-member $
     carries LLM non-determinism (a same-config control moved +26.8% at n=1); precise deltas need
     n≥3–5 repeats. Never present a one-run per-member number as precise.>

   ### Suggestions (advisory — not applied)
   - <each suggestion ties to a SPECIFIC repeated signal, names the file it would touch
     (SKILL.md / gates.md / a prompt), and states it is NOT yet eval-verified>

   ### The Smith's own cost
   - This briefing read <N> runs; harvester + synthesis ≈ <rough token/$ if known>.
   ```

4. **Guardrails (state these hold):** every suggestion is advisory and unverified — the morning briefing
   does NOT run the eval gate, so a briefing suggestion stays advisory until it is validated via
   `/smith --validate` (see that mode above). Never propose editing a fixture. If the harvest was
   partial (Step 1), say so up front in the briefing rather than silently reporting on fewer runs than
   requested.

   **Engine-mix check.** `retro.json` carries no engine field. To note whether a suggestion's evidence
   spans different engines, read that run's `progress.md` (it sits next to its `retro.json`) for the
   `ENGINE: <compounds|native> | <ISO>` line — this is read-only, consistent with the tool's stance.
   That line tells you which engine was bound, not a Kiln version; do not frame it as version-staleness.
   If a run has no `ENGINE:` line, state in the briefing that the engine mix could not be checked for
   that run — never imply the check ran when it didn't.

## Mode: `--validate <proposal>` (eval gate — on-demand, opt-in)

When invoked as `/smith --validate <proposal>` (a branch or diff touching Kiln routing/gate logic),
run the eval gate instead of the briefing: load `${CLAUDE_PLUGIN_ROOT}/skills/smith/references/eval-gate.md` and follow it exactly (**Step -1 classify & route** → anti-gaming pre-check → per-class controls: two-sided K-sample routing replay, guard-hook test, guard-relax check → aggregated two-part labeled report with self-accounted cost). A routing `SAME` never clears a class the marker cannot see — the classifier routes those to their own control or labels them gate-blind. The gate is the ONLY expensive
Smith operation in this mode; the morning briefing (above) stays read-only and never triggers it.

## Mode: `--calibrate` (periodic gold anchor)

When invoked as `/smith --calibrate`, load `${CLAUDE_PLUGIN_ROOT}/skills/smith/references/eval-gate.md`
and run its "Calibration anchor" procedure: K replays per scenario against current Kiln → `majority`
→ `diff` the representative marker vs gold → report a drift ratio. This mode runs on-demand via
`/smith --calibrate` — never per-proposal — and it is the only Smith mode that consults gold
(`expected/*.json`). The version-bump case is conditional, not a blanket pre-release step: it is
mandatory only when routing prose changed since the last recorded calibration without an
intervening `--validate` free-ride (the release-preflight floor — see the free-rider note below).

**Free-rider (A′):** a `--validate` run already replays the current prose per in-scope scenario (its baseline side). That run records a partial-coverage gold-diff from those same markers at no extra replay cost — so a validated PR needs no separate `--calibrate`. The dedicated full-21 `--calibrate` is the *floor*: it fires (a) on-demand, and (b) as a release-preflight when routing prose changed since the last recorded calibration WITHOUT an intervening `--validate`. Both modes persist their result to the ledger file `${CLAUDE_PLUGIN_ROOT}/skills/smith/.last-calibration` (one active record: `<sha> <coverage> <date> <ratio>`), which is what the release-preflight floor reads to know "since when" — a recorded calibration always states its coverage (`partial-freeride` vs `full-21`) so a partial ride is never mistaken for a full anchor. See `references/eval-gate.md` → Calibration anchor for the read/write contract.

## What The Smith does NOT do
- Does not edit Kiln source, gates, or prompts — it proposes and validates; Josh approves the PR.
- Does not autonomously adopt a proposal — a Recommended label plus Josh's approval ships it.
- Does not touch a fixture or scenario (anti-gaming — the gate rejects such proposals).
- In `--validate`, the conductor-role replays are dry (no source writes, no PRs, no live-workspace mutation).
