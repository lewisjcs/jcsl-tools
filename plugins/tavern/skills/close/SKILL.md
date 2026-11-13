---
name: close
description: Use when the person types /tavern:close, or asks to close the shift or end the day's work.
---

Run `node ../../runtime/bin/cli.mjs close` from the session's working folder. Resolve the two `..` against this skill's own folder, so the path is the plugin's `runtime/bin/cli.mjs`. Show what it prints, exactly as printed. Then do what its last line says. Do not pick up a ticket until the person says which one. If the command fails, show the error as printed and stop. An error that names `EPERM` or `EACCES` means this session's sandbox does not allow writes under `${XDG_STATE_HOME:-$HOME/.local/state}/tavern/`; say that. Show the sidework list exactly as printed and wait for the person's numbers. Never choose numbers. Then run `close --sidework` with exactly what they said, or `none`.
