---
name: handoff
description: Use when checkpointing a long task before /clear, writing a handoff file, saving session state to resume later, or when the reset-nudge fires. Triggers include "write a handoff", "checkpoint this", "save state before clear", "hand this off", "resume later".
---

# Handoff

Write a structured handoff so you can `/clear` and resume a long task lean — the cheap-prefix path the `context-economy` clear-vs-compact decision points at. Produces a durable file AND a copy-pasteable resume prompt.

*Chronicler Class in the Context Economy Party — checkpoint before reset.*

## Procedure

1. **Determine the target dir.** Write to a `.handoffs/` directory at the repository root (create it if absent). If the work is scoped to a sub-project that already has its own working directory, write there instead. Filename: `handoff-<YYYY-MM-DD>.md` (append `-N` if one exists today).

2. **Write the handoff file** with exactly these sections:

   ```markdown
   <!-- ce-session: PENDING -->
   # Handoff — <task> — <date>
   ## Goal           — what we're accomplishing (1–2 sentences)
   ## State          — what's done + what's in flight (verified truth, not assumed)
   ## Next steps     — ordered, concrete resume path
   ## Key paths      — files / artifacts / tickets the next session needs
   ## Open questions — unresolved decisions, things to verify
   ```

   Write the marker literally as `PENDING` — do not try to fill in a session id. A
   PostToolUse hook (`handoff-stamp.sh`) rewrites that line with the real `session_id`
   on write; that stamped marker is what the context-economy retro matches on to link
   this handoff to the session that produced it. Leave the `<!-- ce-session: ... -->`
   comment intact.

3. **Print the resume prompt** (do not write it to a file). Keep it short — its job is to seed a LEAN session. Reference the file by its ACTUAL written path:

   > Resuming `<task>`. Read `<actual/path/handoff-<date>.md>` for full state, then continue from Next Steps. Goal: `<one sentence>`.

4. **Confirm + point to the next action.** Echo the written file path, then:

   > Review the file, then `/clear`, then paste the resume prompt into the fresh session.

**Check:** before printing the resume prompt, confirm the file was written: `ls <actual-path>` returns it. If the write failed, report that — do not print a resume prompt for a missing file.

## When NOT to use

Skip for short sessions or throwaway tasks where no continuity is needed — the overhead of a handoff file isn't worth it if you won't be resuming.

## Discipline

- The handoff file is workspace-internal scratch. It lands in the project tree, never in a shipped artifact (PR body, ticket, wiki page). Add `.handoffs/` to `.gitignore` if the handoffs should not be committed.
