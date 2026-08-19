# Archive: v1 code-quality-audit

Archived August 2026.

This directory holds the inline (v1) implementation of the code-quality-audit
lane — a 3-layer prose audit (Compliance / Staleness / Gaps, plus
test-integrity) run in the main context. `code-quality-audit` is now the
runtime-driven Class (bundle → init → dispatch → receipt → result), and these
files are kept for historical reference only.

`_archive/` sits outside `skills/` and `agents/` plugin discovery, so nothing
here loads, registers, or is dispatchable — it ships as inert bytes. The files
are unmodified from their last live version; do not edit them here.
