---
name: next
description: Use when the person types /tavern:next, or asks to move on to the next ticket.
argument-hint: [<ticket id>]
---

Run `node ../../runtime/bin/cli.mjs next` from the session's working folder, with the ticket id after it when the person gave one. Resolve the two `..` against this skill's own folder, so the path is the plugin's `runtime/bin/cli.mjs`. Show what it prints, exactly as printed. Work the ticket, and use the write commands it lists as you go. If the command fails, show the error as printed and stop. An error that names `EPERM` or `EACCES` means this session's sandbox does not allow writes under `${XDG_STATE_HOME:-$HOME/.local/state}/tavern/`; say that. If it refuses because this session holds a ticket, show the three choices and wait.
