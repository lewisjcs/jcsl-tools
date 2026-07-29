# Self-Improvement Loop (plugin maintenance)

Pattern from [Zach Lloyd](https://www.linkedin.com/pulse/how-build-self-improvement-loop-your-skills-zach-lloyd-aandc) for evolving this plugin's skills from real usage.

## Inner loop (every session)

1. Agent runs a context-economy plugin skill (clear decision, assembly, delegation, handoff).
2. Interaction is recorded in transcript + optional human correction (label change, "don't load that", rewritten dispatch).

## Outer loop (scheduled or post-incident)

1. Pull sessions where context-economy skills fired OR where hygiene clearly failed (marathon session, broad read into main thread, under-specified subagent rework).
2. For each failure: name the skill section that should have fired, the human correction, and the missing trigger or check.
3. Propose a minimal diff to the relevant `SKILL.md` — one lever per diff.

## What to optimize for

| Signal | Skill to patch |
|---|---|
| Session >100 turns without handoff/clear | `context-economy` clear-vs-compact; hook threshold |
| Large file/log dump on main thread | `context-assembly` |
| Subagent rework / "feels dumb" | `delegating-to-subagents` dispatch gate |
| Skill never invokes (0 attribution) | Description triggers + add a `<HARD-GATE>` at the decision point |

## Check

After an outer-loop pass, list: sessions reviewed, diffs proposed, and which concrete trigger phrase was added or which check was hardened.
