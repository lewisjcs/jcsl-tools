---
name: context-economy-retro
description: Use for a context-economy retrospective — how have my recent sessions spent context, which plugin skills never fire, did handoff+clear save money, any rework. Read-only, proposes advisory suggestions only. Triggers include "context economy retro", "how's my context spend", "which context-economy skills are dormant", "did clearing save money", "context retro briefing".
---

# Context-Economy Retro (read-only)

Reads the Phase 1 telemetry spine + transcripts for recent spine-backed sessions and briefs on
firing coverage, handoff+clear ROI (optimistic), and a rework/accuracy watch. **Proposes only —
never edits a SKILL.md, fixture, or opens a PR.** That is Phase 4.

## Steps

1. **Harvest** (default last 10 sessions; honor a user-given N):
   `bash ${CLAUDE_PLUGIN_ROOT}/hooks/retro-harvest.sh --last <N>`
   It writes one `ce-retro-<session>.json` per spine-backed session under `~/.claude/hooks/state/`
   and prints their paths. If it prints zero paths, there is no telemetry yet — say so and stop
   (the spine only fills as the plugin is used across sessions).

2. **Read each digest.** Each holds `firing` (fired/never_fired/denominator=5), `boundaries` (each
   with optimistic ROI: realized/counterfactual/savings_foregone), `rework`
   (within_session + marker-linked cross_clear), and `lenses_available`.

3. **Synthesize the briefing** in this exact shape:

   ## Context-Economy Retro — <N> spine-backed sessions (<oldest> → <newest>)

   ### Firing coverage
   - Fired across corpus: <skills + how many sessions each>
   - NEVER fired: <dormant skills> ← dormancy candidates
   - (denominator: 5 shipped skills)

   ### ROI — estimated savings foregone (OPTIMISTIC; ignores re-orientation cost)
   - Boundaries where a reset would have saved: <realized vs counterfactual $ per session>
   - Corpus total estimated savings foregone: <$X> — directional, NOT measured
   - Sessions with no boundary / no reset opportunity: <count>

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

## When NOT to use
Skip mid-task — this is an offline retro, not a live signal. For live cost/cache state use the
Observer statusline instead.
