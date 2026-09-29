# Kiln Engines (P2.1 — Compounds-as-Engine)

Loaded on-demand. An **engine** is a documented three-plus-one-verb contract that a
member fulfills by calling different tools depending on which engine the router bound for
this run. It is **prose convention, not a code module** (design D5) — members honor it; no
runtime layer enforces it. The router binds exactly one engine per run and writes the
`engine:` tag to the ledger; members never branch on scenario internally — they branch on
the bound engine, which the conductor passes into each dispatch.

## Why two engines

Compounds has no artifact type for Claude Code skills, agent-prompt markdown, or plugins —
the owner's most common work (verified in the v2 design §173). That gap is **named and
served by a second engine**, not patched around. `code` (and `mcp/agent-app` / `infra`, once
P2.2 activates them) run on the **Compounds engine**; `tool-authoring` and `doc` run on the
**native standards engine**.

## The verb contract

| Verb | Called by | Compounds engine | Native standards engine |
|---|---|---|---|
| **`register`** → project | Planner (once, before `generate_tasks`, STANDARD only) | `init_repo(git_remote_url)` → read `repositoryId` from `.compounds/repo-state.json` → `create_project(repository_id=...)` **after** the master-spec REVIEW gate | N/A — native engine has no Compounds project |
| **`enrich(task)` → brief-context** | Planner (per task, at brief-authoring time) | `get_design_patterns` + `get_testing_frameworks` + `get_reference_architecture` for the task, captured as text | `skill-authoring-principles` + `directive-review` lenses + `doc-patterns`, captured as the pattern source |
| **`implement`** | Crafter | **STANDARD:** calls `implement_task` at craft time so Compounds runs its own implementation+test loop (the enriched brief context is the guide; the Planner's register + generate_tasks created the project/task it needs — register runs init_repo → create_project first, see the register row). **TRIVIAL:** no project exists (no Planner ran) → the Compounds `start_trivial` terminal path — `plan_change(step="start")` → locate → edit → commit → `create_project(status="DONE")` as the terminal — NOT `implement_task` | Authors the artifact grounded in the injected standards; deterministic authoring, no Compounds call |
| **`verify(diff)` → verdict-inputs** | Crafter (self) + Inspector (independent) | Crafter: test suite green (+ optional E2E on frontend). Inspector: **static** review of diff vs AC for **test adequacy** | Crafter: deterministic self-checks (frontmatter valid, trigger phrases, no forbidden patterns, calibration fixtures green). Inspector: static adequacy of those checks |
| **`finalize(task)`** | Inspector (STANDARD) / Crafter (TRIVIAL) | STANDARD → **Inspector** calls `implement_task_finalize` with the verdict evidence. TRIVIAL → **Crafter**; the `start_trivial` terminal `create_project(status="DONE")` (from `implement`) IS the finalize — no `update_task` (no existing task), no `implement_task_finalize` (not granted to the Crafter) | STANDARD → **Inspector** calls `update_task(status="DONE")`. TRIVIAL → **Crafter**; native never touches Compounds, so there is no project/task to finalize — the task is done when the commit lands (no Compounds verb) |

On a STANDARD compounds run, `implement_task` is called **exactly once** — by the Crafter, at craft
time (a TRIVIAL compounds run never calls it; it runs the `start_trivial` terminal instead). The Planner's
`enrich` does NOT call `implement_task`; it captures the pattern/framework/architecture
context so the expensive-to-generate guidance is paid once at plan time, written into the
brief, and never re-generated on a Crafter retry.

**The prioritize kickoff (`implement_all_tasks`) is the Planner's, once, and prioritize-ONLY.**
`implement_task` has a hard prerequisite — `.compounds/<project_id>/task-order.json` — which is
written only by the `implement_all_tasks` *prioritize* step. Compounds' native shape is one
orchestrator agent that both prioritizes AND drives the whole loop; Kiln's shape is the
opposite (a fresh per-task Crafter + a separate Inspector). So Kiln **splits** that call: the
Planner runs `implement_all_tasks` once after `generate_tasks` completes, follows the returned
prioritize prompt to write `task-order.json`, then **STOPS** — it does NOT drive the loop. Each
per-task Crafter later reads `task-order.json` and calls `implement_task(project_id, task_id)`.
The Planner must ignore the prioritize prompt's instruction to "drive the implementation loop"
— that instruction assumes Compounds' single-agent topology, not Kiln's.

## Grants vs. use (the capability-gate rule)

A member holding a Compounds tool in its frontmatter `tools:` list does NOT mean it calls
that tool on every run. Frontmatter grants are static — they cannot be scoped per engine — so
**this prose is the gate.** Each tool sorts into one of three engine-sensitivity tiers, and a
member fires a tool only on the engine its tier permits:

| Tier | Tools | On a `native`-bound run |
|---|---|---|
| **T1 — engine-agnostic reads** | `get_project`, `get_all_projects`, `get_project_tasks`, `get_project_status` (+ CLI `query`/`search`/`impact`) | **Callable.** A skill/doc task still lives in a real indexed repo; reading its structure is engine-independent. |
| **T2 — Compounds catalog** | `pattern_detection`, `get_pattern_context`, `get_pattern_examples`, `get_design_patterns`, `get_reference_architecture`, `get_reference_architecture_context`, `get_testing_frameworks` | **Held, NOT called.** The native `enrich` column names the correct source (`skill-authoring-principles` + `directive-review` lenses + `doc-patterns`). The Compounds catalog is bound to Compounds' tech stacks (python-fastapi, typescript-react, fastmcp, playwright) and has nothing for skill/agent-prompt markdown. |
| **T3 — Compounds-artifact-bound** | `implement_task`, `implement_task_finalize`, `implement_all_tasks`, `get_task`, `get_task_with_context`, `get_prompt` | **Cannot be called — no artifact exists.** A native run never creates a Compounds project/task. |

This preserves the measurement symmetry: the only variable between a `compounds` run and a
`native` run is the bound engine, because a native-bound member simply does not fire its
T2/T3 grants.

## Enrichment is carried by the brief (the core fix)

`enrich` is called by the **Planner** and its output is written into the task's entry in
`{{RUN_FOLDER}}/tasklist.md` (durable file state, pattern B2). The conductor merges that
entry into `brief-N.md` during the Build loop. This is the direct fix for the founding
defect — enriched context was generated by the Planner then discarded because only the task
*breakdown* was retained. Now the *enrichment* rides the brief to the Crafter.

## Two structural properties this buys

1. **Symmetry = clean measurement.** The Crafter has ONE flow — "consume enriched brief →
   `implement` per the bound engine → engine `verify` self-check → `finalize` (Crafter only on
   TRIVIAL; on STANDARD the Inspector finalizes — see the verb-contract table)" — with no
   `if code / if tool-authoring` fork. The only variable between a Compounds run and a
   native run is which engine is bound, so the `engine:`-tagged ledger comparison is a
   controlled experiment on one executor, not two drifting code paths.
2. **Generator/critic separation is engine-independent.** Whichever engine is bound,
   `verify`'s Inspector half receives only the output artifact + diff, never the reasoning
   trace. The AIS Harness Standard property holds identically on both paths.

## Router → engine binding

The router (in `SKILL.md`'s classify verb) is a lookup table, not judgment:

| Scenario | Engine | Ledger tag | Active this pass? |
|---|---|---|---|
| `code` | compounds | `engine: compounds` | **active** |
| `tool-authoring` | native | `engine: native` | **active** |
| `doc` | native | `engine: native` | **active** |
| `mcp/agent-app` | compounds | `engine: compounds` | dormant this pass (P2.1) — still HALTs; activates in P2.2 |
| `infra` | compounds | `engine: compounds` | dormant this pass (P2.1) — still HALTs; activates in P2.2 |

Only `code` / `tool-authoring` / `doc` route this pass (P2.1). The Compounds bindings for
`mcp/agent-app` and `infra` are designed-but-dormant — those scenarios still HALT-AND-ASK
in this pass (P2.1). Their rows exist so the contract is complete when P2.2 activates them.

## The compounds standard path (connective tissue)

On `engine: compounds` + `tier: STANDARD`, the Planner walks the full Compounds standard path —
not just its endpoints. The order, with the tool at each stage:

1. `plan_change` (start→locate→impact→classify→route) → `gen_spec(tier="standard", composite_score)`
2. `gen_master_spec` → write the master spec → `validate_master_spec` → **REVIEW gate** (user approves)
3. `register`: `init_repo` → read `repositoryId` → `get_all_projects` (reuse-or-create) → `create_project` (post-REVIEW only)
4. upload the tech spec to the project via the `compounds` CLI (`compounds upload <project_id> <file> --type technical-spec`), then `validate_spec`
5. `generate_tasks` → **poll `get_project_status` every 60s** (max 5 attempts) until `breakdown_status == COMPLETED` and `task_count > 0`
6. `implement_all_tasks` (prioritize-only → `task-order.json`) → STOP

When the master spec exceeds 70,000 chars, step 2 auto-branches to the multi-project sub-mode:
`gen_project_spec` per scope → `validate_project_specs` before `create_project`. `generate_tasks`
is async and requires an uploaded tech spec with content — steps 4–5 are not optional.
