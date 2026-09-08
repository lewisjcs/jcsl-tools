# Archive: v1 security-gauntlet

Archived September 2026.

This directory holds the agent-orchestrated (v1) implementation of the `security-gauntlet` skill: `skill/SKILL.md`, its `agents/security-finder.md` / `agents/security-validator.md` pair, and the `security-principles/` reference skill it loaded. Security review is now the runtime-driven `threat-review` Class (bundle → init → dispatch → receipt → result), fielded by the gauntlet on a security signal and invocable directly as `gauntlet:threat-review`; these files are kept for historical reference only.

`_archive/` sits outside `skills/` and `agents/` plugin discovery, so nothing here loads, registers, or is dispatchable — it ships as inert bytes. The files are unmodified from their last live version; do not edit them here.
