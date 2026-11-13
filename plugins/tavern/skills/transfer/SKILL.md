---
name: transfer
description: Use when the person types /tavern:transfer, or asks to take over the work of an earlier session.
argument-hint: [<ticket id>]
---

Run `node ../../runtime/bin/cli.mjs transfer` from the session's working folder, with the ticket id after it when the person gave one. Resolve the two `..` against this skill's own folder, so the path is the plugin's `runtime/bin/cli.mjs`. Show what it prints, exactly as printed. Work the ticket, and use the write commands it lists as you go. If it says it took a ticket the last close released, carry on with that ticket. If the command fails, show the error as printed and stop. An error that names `EPERM` or `EACCES` means this session's sandbox does not allow writes under `${XDG_STATE_HOME:-$HOME/.local/state}/tavern/`; say that. If it prints a line that starts `Ask the person`, ask that one question and wait. Add `--confirmed` only after the person says yes.
