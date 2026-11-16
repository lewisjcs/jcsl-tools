---
name: report
description: Use when the person types /tavern:report, to print the counts-only report block.
disable-model-invocation: true
---

Run `node ../../runtime/bin/cli.mjs report` from the session's working folder. Resolve the two `..` against this skill's own folder, so the path is the plugin's `runtime/bin/cli.mjs`. Show what it prints, exactly as printed. Put it inside one code block. Add nothing to it. If the command fails, show the error as printed and stop. An error that names `EPERM` or `EACCES` means this session's sandbox does not allow reads under `${XDG_STATE_HOME:-$HOME/.local/state}/tavern/`; say that.
