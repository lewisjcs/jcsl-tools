# Archive: v1 adversarial-review

This directory holds the agent-orchestrated (v1) implementation of the
`adversarial-review` skill: `skill/SKILL.md` and its `agents/adversarial-finder.md`
/ `agents/adversarial-validator.md` pair. `adversarial-review` is now the
runtime-driven Class (bundle → init → dispatch → receipt → result), and these
files are kept for historical reference only.

`_archive/` sits outside `skills/` and `agents/` plugin discovery, so nothing
here loads, registers, or is dispatchable — it ships as inert bytes. The
files are unmodified from their last live version; do not edit them here.
