---
name: add
description: Use when the person types /tavern:add, or when something turns up along the way that should become a ticket instead of being chased now.
argument-hint: <title> <source pointer>
---

Run `node ../../runtime/bin/cli.mjs add --title ... --source ...` from the session's working folder. Resolve the two `..` against this skill's own folder, so the path is the plugin's `runtime/bin/cli.mjs`. Show what it prints, exactly as printed. Then do what its last line says. Do not pick up a ticket until the person says which one. If the command fails, show the error as printed and stop. An error that names `EPERM` or `EACCES` means this session's sandbox does not allow writes under `${XDG_STATE_HOME:-$HOME/.local/state}/tavern/`; say that. Use this for something found along the way, in place of chasing it. Pass `--on-their-word` only when the person asked for this ticket in their own words in this conversation.
