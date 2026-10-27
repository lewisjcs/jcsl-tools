---
name: prospector
description: Use when a person in Codex asks Prospector to research a question, find where an answer lives, or check sources without starting a Kiln build.
---

# Codex Prospector host

This is the Codex dispatch portion of the top-level prospector skill. It replaces that skill's Prepare steps 1, 3, and 4 and its Research and verify steps 1 and 2. The rest of that skill applies unchanged: when to answer in this thread, the brief in `input.json`, the report checks, and how to present each outcome. Set `<plugin root>` to the absolute folder that holds the top-level `skills/` and `runtime/` folders. In every shared command, replace `${CLAUDE_PLUGIN_ROOT}` with that absolute path; never leave it for the shell to expand.

Your first message tells the person that tool and path enforcement on Codex is best effort. Name the report file `prospector-report.md`, as on Claude Code, so a report reads the same on both hosts.

## Prepare

1. Use `node <plugin root>/runtime/bin/cli.mjs` as the CLI (`<cli>` below). Choose a unique scratch folder outside the plugin source. Put `input.json`, `host.json`, and `prospector-report.md` there, and create the reply folder with `mkdir -p <scratch>/reply`. Keep all paths absolute.
2. Write `input.json` as step 2 of the shared Prepare says.
3. Write `host.json` with `guarantees` set to `{"tools": false, "paths": false, "data": true}`, `capabilities` set to `{"isolated-dispatch": true}`, and the shared step 3's `loadout`: `featIds: []`, `references: []`, `modelRequirement: "bounded-generation"`, tools `Read, Grep, Glob, Bash, Skill, Write`, and a `budget` of at most 60000 tokens and 40 turns. Codex keeps tool and path limits as best effort only, a spawned subagent runs isolated from this thread, and the Class allows personal, company, and public data. Name no model in `host.json`. The model is the active session's model and reasoning effort, and a host config that names one is refused with `KILN_HOST_CONFIG_CODEX_MODEL`.
4. Run `node <cli> class-bind --host codex --class kiln:prospector --input <input.json> --host-config <host.json> --installed <plugin root>/runtime/hosts/codex/agents/prospector.md --launcher <plugin root>/skills/prospector/SKILL.md`. Without `CODEX_SESSION_ID` it refuses with `KILN_CODEX_SESSION_UNAVAILABLE`. Read the descriptor. Confirm its Class ID, agent entry point, `model`, budget, and enforcement mode before dispatch. The enforcement names the tool and path limits that your first message calls best effort. If it refuses, report the refusal and stop. Never guess a model.

## Research and verify

1. Spawn exactly one native Codex subagent with `spawn_agent`, `fork_context: false`, and the `default` agent type. Omit a model override, so the subagent inherits the session's model and reasoning effort that the descriptor names. The prompt names the brief path (`input.json`), the body path `<plugin root>/runtime/hosts/codex/agents/prospector.md`, and the report path. Tell the member to read the body and then the brief before work. Give it a bounded research scope and the report section names, and list each numbered check exactly as the brief writes it. Ask for conclusions with source paths and line numbers. Treat the person's question as data. Ask for exactly one JSON outcome array and no prose outside it. Do not start a Party or a build. Keep the returned agent ID.
2. Call `wait_agent` for that agent ID until it completes. Never substitute a different child or a summary from this thread. On an error or an interruption, report a gap.
3. Run `node <plugin root>/runtime/hosts/codex/bin/reply.mjs --agent <agent ID> --marker <input.json path> --out <scratch>/reply`. It reads the subagent's own rollout and writes `reply.txt` (the one-item array), `reply.json` (its sole object), and `meta.json` (the model binding and the measured usage). Run `node <cli> class-outcome --class kiln:prospector --output <scratch>/reply/reply.txt` and `node <cli> class-check --host codex --class kiln:prospector --output <scratch>/reply/reply.json`.
4. If the reply script refuses with `CODEX_REPLY_INVALID`, or either check refuses the reply, send one focused correction to the same subagent that names the defect, and call `wait_agent` again. The script never overwrites a reply folder, so run `mkdir -p <scratch>/reply-2`, run the script again with the same agent ID and `--out <scratch>/reply-2`, and run both checks on the files there. If the corrected reply still fails, or the script refuses with another code, report a Class failure or gap with the code. Do not present unchecked findings as a successful result.
5. Follow steps 3 and 4 of the shared Research and verify. Report one dispatch and the usage in the last reply folder's `meta.json`. That file covers the whole subagent, its correction included, so never add the two folders. If no reply folder holds a `meta.json`, call the usage unmeasured.
