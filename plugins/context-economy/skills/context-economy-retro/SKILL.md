---
name: context-economy-retro
description: Use for a context-economy retrospective — how have my recent sessions spent context, which plugin skills never fire, did handoff+clear save money, any rework. Read-only, proposes advisory suggestions only. Triggers include "context economy retro", "how's my context spend", "which context-economy skills are dormant", "did clearing save money", "context retro briefing".
---

# Context-Economy Retro (read-only)

Reads the telemetry spine (`~/.claude/hooks/state/ce-events-*.jsonl`) + transcripts for recent
spine-backed sessions and briefs on firing coverage, handoff+clear ROI (optimistic), and a
rework/accuracy watch. **Proposes only — never edits a SKILL.md, fixture, or opens a PR.**

## Steps

1. **Harvest** (default last 10 sessions; honor a user-given N):
   `bash ${CLAUDE_PLUGIN_ROOT}/hooks/retro-harvest.sh --last <N>`
   It writes one `ce-retro-<session>.json` per spine-backed session under `~/.claude/hooks/state/`
   and prints their paths. If it prints zero paths, there is no telemetry yet — say so and stop
   (the spine only fills as the plugin is used across sessions).
   Note: ROI pricing is cache-first but may trigger a one-time, 2s-timeout, fail-open network
   fetch on a cold cache (see `retro-roi.py`) — harvest still completes offline (ROI just reports
   its error object for that boundary).

2. **Read each digest.** Each holds `firing` (fired/never_fired/`denominator`/`expected_dormant`),
   `boundaries` (each with optimistic ROI: realized/counterfactual/savings_foregone), `rework`
   (within_session + marker-linked cross_clear), and `lenses_available`. The `denominator` is
   derived from the skills on disk (not hardcoded), and `expected_dormant` lists skills that are
   dormant BY DESIGN (e.g. `observer`, whose output is the statusline widget) — subtract those
   from the dormancy candidates below so they are never flagged as needing a fix.
   Each digest also holds `cost` (real Langfuse $: `session_cost_usd`,
   `conductor_cost_usd`, `delegation_cost_usd`, `members[]`) when the substrate was
   live — signaled by `"langfuse"` in `lenses_available`. All-null `cost` means the
   substrate was down for that session; report it as unavailable, never as $0.

3. **Synthesize the briefing** in this exact shape:

   ## Context-Economy Retro — <N> spine-backed sessions (<oldest> → <newest>)

   ### Firing coverage
   - Fired across corpus: <skills + how many sessions each>
   - NEVER fired: <dormant skills, EXCLUDING those in `expected_dormant`> ← dormancy candidates
   - Dormant by design (not flagged): <skills in `expected_dormant`, e.g. observer>
   - (denominator: <`denominator` from the digest> shipped skills)

   ### ROI — estimated savings foregone (OPTIMISTIC; ignores re-orientation cost)
   - Boundaries where a reset would have saved: <realized vs counterfactual $ per session>
   - Corpus total estimated savings foregone: <$X> — directional, NOT measured
   - Sessions with no boundary / no reset opportunity: <count>

   ### Real cost (Langfuse — penny-exact, sessions where the substrate was live)
   - Total session cost: <sum of `cost.session_cost_usd` across langfuse-lens sessions>
   - Delegation cost (work pushed to subagents): <sum of `cost.delegation_cost_usd`> —
     this is the concrete payoff of `delegating-to-subagents`; near-zero across a corpus
     where you dispatched agents is itself a dormancy signal for that skill.
   - Conductor (main-thread) cost: <sum of `cost.conductor_cost_usd`>
   - Sessions missing this lens (substrate down): <count> — reported as unavailable, not $0
   - Note: this is measured $ (reconciles 1.00× with ccusage per-model), UNLIKE the
     optimistic ROI above. Ground the "did clearing save money" judgment on the ratio of
     ROI `savings_foregone` to real `session_cost_usd`, not on the optimistic number alone.

   ### Accuracy watch (rework proxy — for your judgment; never auto-concludes "worth it")
   - Within-session: <correction turns, repeated reads> by session
   - Cross-clear (marker-linked pairs only): <post-resume re-reads>
   - ⚠ Flagged: <sessions that saved $ but showed rework — flagged, not celebrated>

   ### Suggestions (advisory — NOT applied, NOT eval-verified)
   - <each ties to a SPECIFIC signal, names the exact SKILL.md section a fix would touch,
     and states it is NOT eval-verified. e.g. "context-assembly never fired in 8/10 sessions —
     consider a trigger phrase in its description; unverified.">

   ### The retro's own cost
   - Read <N> sessions; harvest + synthesis ≈ <rough tokens/$ if known>

4. **Guardrails (state these hold):** every suggestion is advisory and unverified. ROI is optimistic
   and directional — never present `savings_foregone` as measured fact (its digest carries
   `"model":"optimistic"`; keep that framing). A session that saved money but shows rework is
   flagged, not celebrated — accuracy is primary. If the harvest was partial or a session lacked a
   lens (`lenses_available`), say so rather than silently reporting on fewer sessions/lenses.
   The Langfuse cost lens is measured (not optimistic) but only covers sessions where the
   local substrate was running; never extrapolate a corpus total from a partial-coverage
   lens — state the covered-session count alongside any cost sum.

## When NOT to use
Skip mid-task — this is an offline retro, not a live signal. For live cost/cache state use the
Observer statusline instead.
