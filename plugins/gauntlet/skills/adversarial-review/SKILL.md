---
name: adversarial-review
description: Runtime-driven adversarial review (Find, Validate, Adjudicate under a deterministic runtime). Use when pressure-testing a code change, plan, or doc for hidden assumptions, failure modes, and structural risks that standard review misses. Trigger phrases include "adversarial review", "pressure test this", "how could this break", "what am I missing", "stress test this code", "break this", "find the flaws". Requires Node >= 22.
---


# Adversarial Review

Set `GAUNTLET_PLUGIN_ROOT` to the absolute directory two levels above this `SKILL.md` file. Select the host from the current session. In Claude Code, verify that the real path matches `CLAUDE_PLUGIN_ROOT` and read `${GAUNTLET_PLUGIN_ROOT}/runtime/hosts/claude-code/skills/adversarial-review/SKILL.md`. In Codex, read `${GAUNTLET_PLUGIN_ROOT}/runtime/hosts/codex/skills/adversarial-review/SKILL.md`. Stop if this session is neither host or the selected file is absent. Shell tool calls start fresh; substitute the verified absolute plugin path for `${GAUNTLET_PLUGIN_ROOT}` in every command in the selected host skill.

Follow the selected host skill in full, including its preflight, dispatch, receipt, result, and reporting steps. The selected file is the generated Class instruction for this installed package. Check that its `name` is `adversarial-review` and its host mechanics match the selected host before beginning a run.
