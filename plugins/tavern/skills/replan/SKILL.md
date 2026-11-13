---
name: replan
description: Use when the person types /tavern:replan, to reorder the rail, set the objective, drop a ticket, record who took one, or pivot.
argument-hint: order|objective|drop|taken|pivot ...
disable-model-invocation: true
---

Run `node ../../runtime/bin/cli.mjs replan` from the session's working folder, followed by the person's words, quoted as they gave them. Resolve the two `..` against this skill's own folder, so the path is the plugin's `runtime/bin/cli.mjs`. Show what it prints, exactly as printed. Then do what its last line says. Do not pick up a ticket until the person says which one. If the command fails, show the error as printed and stop. An error that names `EPERM` or `EACCES` means this session's sandbox does not allow writes under `${XDG_STATE_HOME:-$HOME/.local/state}/tavern/`; say that. Only the person starts this. A pivot needs their reason in their words; pass it as `--why` unchanged.
