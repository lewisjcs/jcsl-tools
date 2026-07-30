# `/smith --emit-suggestions` — durable suggestion emission (on-demand; read + local write only)

Loaded by `SKILL.md` when Josh runs `/smith --emit-suggestions`. This mode HARVESTS and WRITES a
durable suggestions file — it does NOT run the eval gate, draft a PR, or make any outward write. It
is the read-only briefing (Steps 1–3 of SKILL.md) plus a filtered local file write. The gate and PR
draft happen only later, attended, via `implement <id>` (below).

## Procedure

1. **Harvest** exactly as the briefing does: run
   `bash ${CLAUDE_PLUGIN_ROOT}/skills/smith/smith-harvest.sh --workspace "<WS>" --last <N>` and read
   each `retro.json` it prints. `<WS>` is the OS root the session launched from (the dir containing
   `projects/active/`), NOT a git root. Honor the partial-harvest fail-open (SKILL.md Step 1): if the
   harvester exits non-zero or prints fewer paths than the requested `N`, do not hard-fail — proceed
   with whatever `retro.json` files were written and note in the returned briefing text that the
   harvest was partial, naming which runs are missing. A partial harvest still emits; it never blocks.

2. **Determine the emit target file:** `<WS>/projects/active/kiln-smith/smith-suggestions/<today>.md`
   where `<today>` = the newest run's date, or, if that is not derivable, the system date — state
   which of the two you used in the file's first line. Create the `smith-suggestions/` dir if absent.
   If no harvested run is newer than the most recent existing `smith-suggestions/*.md` file, write a
   single line `nothing new since <date>` to `<today>.md` and STOP (the skip-when-nothing-new rule;
   it matters only under Plan B's unattended cadence and is harmless when attended).

3. **Build the suppress-list:**
   `bash ${CLAUDE_PLUGIN_ROOT}/skills/smith/smith-suggestions.sh list-dismissed <dir>` where `<dir>`
   is the `smith-suggestions/` directory. It emits one `<target>\t<change>` line per `status:
   dismissed` record across every dated file. Hold these `(target, change)` pairs — a candidate that
   matches one is DEAD: never surfaced in the file and never surfaced as an observation. (`emit-record`
   also enforces this deterministically — `is-duplicate` treats dismissed records as duplicates — but
   check the suppress-list yourself first so a dead candidate never even reaches the triangle.)

4. **For each candidate improvement you spot, apply the EVIDENCE TRIANGLE (design §4). ALL THREE
   required or the candidate is NOT written:**
   - **Empirical signal:** a repeated, quoted pattern across ≥2 real runs, WITH their run-ids. Apply
     the coarse-net skepticism (SKILL.md Step 2 — `friction` is a keyword net that matches clean/
     summary lines like "0 gaps" or "no deviations found"; read each captured line yourself and judge
     whether it actually indicates friction before counting it, never from array length alone). A
     one-off is not a signal — a pattern seen in exactly one run fails this leg and the candidate is
     suppressed.
   - **Principle anchor:** name the specific principle/memory/research finding that makes the change
     right by our standards — e.g. `code-quality-standards`, a named `feedback_*` memory such as
     `feedback_pair_prose_heuristic_with_invariant_test`, `reference_anthropic_harness_design`, or the
     mission ranking (accuracy-primary, cost-co-equal). A candidate that cannot cite a specific,
     real anchor is a preference, not an improvement — suppress it.
   - **Eval-provability:** the change must name a `target ∈ {SKILL.md, gates.md, lanes.md,
     scenarios.md, a named fire prompt}` and you must run
     `bash ${CLAUDE_PLUGIN_ROOT}/skills/smith/smith-eval-gate.sh classify <predicted-diff-file>` to
     record its class, where `<predicted-diff-file>` is a unified diff of the edit you would make. The
     classifier's vocabulary is `routing-output | guard-hook-code | guard-relaxation | detection-perf
     | unsure` (a diff can match more than one; record all it emits). A candidate whose class set is
     `detection-perf` and/or `unsure` (i.e. carries no class the gate can adjudicate) is still
     WRITTEN, but you MUST flag it gate-blind in the `<change>` line (append `[gate-blind: <class>]`)
     so the reader knows upfront the gate cannot bless it. A candidate that names no target in the
     allowed set fails this leg and is suppressed.

5. **Suppression is the teeth:** a candidate that cannot complete all three legs is NOT written to
   the file. You MAY mention it in the returned briefing text as a low-confidence observation, but it
   never becomes a `proposed` record. Better an empty suggestions file than a noisy one.

6. **Write each surviving candidate** with
   `bash ${CLAUDE_PLUGIN_ROOT}/skills/smith/smith-suggestions.sh emit-record <file> <id> <target>
   <change> <class> <signal> <principle> <cost_evidence>` — pass the arguments in exactly that order.
   `emit-record` writes a record with `status: proposed` and leaves `eval_verdict` and `pr` empty
   (they are filled later by `implement <id>`); you supply the other seven values. It dedups against
   the whole `smith-suggestions/` dir on `(target, change)` in ANY status (Task 3), so a re-run is
   idempotent — a `(target, change)` already `proposed`, `drafted`, or `dismissed` is silently not
   re-written (the command prints `duplicate … — not written` and exits 1; that is expected, not an
   error).
   - `<id>`: stable id in the format `<today>-NN`, `NN` zero-padded per file (`2026-07-30-01`,
     `2026-07-30-02`, …).
   - `<signal>`: the empirical-signal leg — the repeated pattern, quoted, WITH its run-ids.
   - `<target>`: the exact file the edit would touch (from the eval-provability leg).
   - `<change>`: one line describing the proposed edit; append `[gate-blind: <class>]` when the class
     set is `detection-perf`/`unsure`.
   - `<class>`: the class set that `classify` emitted.
   - `<principle>`: the principle-anchor leg — the specific real anchor named in step 4.
   - `<cost_evidence>`: the per-member figure from this run's `retro.json` `cost_by_member`
     (`members[].cost_usd` for a member, or `conductor_cost_usd` for the conductor) IF the suggestion
     is cost-motivated; otherwise the literal `n/a`. `cost_by_member` is best-effort and fail-open —
     an empty `members` array with a `note` is normal for runs predating member-trace wiring; when it
     is empty you have no per-member figure, so a cost-motivated candidate must fall back to `n/a` and
     lean on its other two legs. **Carry the n≥3 caveat** (`feedback_single_trial_model_comparison`):
     single-run cost is directional, not a point value — never justify a suggestion on one run's cost
     delta alone; a cost signal needs the same ≥2-run repetition the empirical leg demands.

7. **Auditability:** every `signal` quotes its run-ids and every `principle` names a real anchor, so
   each record is falsifiable — a reader can check whether the signal is really in those runs and
   whether the principle really says that. Do not fabricate a citation
   (`feedback_ai_reviewer_citation_fabrication` — AI reviewers and subagents fabricate; verify the
   raw source). If you cannot point to the actual runs or the actual principle, the candidate fails
   the triangle and is suppressed.

## `implement <id>` — gate-then-draft (attended; the first and only outward write)

Runs when Josh says `implement <id>` (or `/smith implement <id>`). Per-suggestion consent only —
never batch multiple ids on one approval (`feedback_outward_facing_edit_consent_scope`).

1. **Load the record.** `smith-suggestions.sh get-field <file> <id> <target|change|class>`. The
   record is the contract — do NOT re-harvest or re-derive the signal.

2. **Construct the intended diff** against a fresh worktree off `origin/main` of the source repo
   (`feedback_always_use_worktrees`). This is the candidate edit `change` describes on `target`.

3. **Anti-gaming pre-check (hard gate, FIRST).** `smith-eval-gate.sh anti-gaming <diff>`. Exit 3 →
   STOP, refuse, never draft. Report REJECTED (anti-gaming).

4. **Gate.** Follow `references/eval-gate.md` exactly (Step -1 classify & route → per-class controls →
   two-part label). Write the verdict: `smith-suggestions.sh set-status <file> <id> eval_verdict
   "<verdict line>"`.

5. **Branch on verdict:**
   - **RECOMMENDED** → `set-status <file> <id> status validated-recommended`, proceed to draft.
   - **OBSERVATION-ONLY / gate-blind** → `set-status <file> <id> status validated-observation`; report
     the failing control BY NAME; do NOT draft. Josh hand-fixes those. STOP.
   - By construction (`eval-gate.md` Step -1) a `guard-relaxation` class is forced OBSERVATION-ONLY —
     it can never reach step 6.

6. **Draft the PR (only on RECOMMENDED):**
   - Apply the diff on the worktree branch `smith/<id>`.
   - Use the `/create-pr` skill — never hand-roll (CLAUDE.md). Conventional-Commit title.
   - PR body carries: the evidence triangle (signal + run-ids, principle, cost_evidence), the full
     eval report, AND a one-line rollback note: `Rollback: revert commit <sha> on branch smith/<id>;
     touches only <target>, no migration, no release.`
   - Open as a GitHub DRAFT PR (not ready-for-review) — the machine-drafted signal.
   - `set-status <file> <id> pr <url>` and `set-status <file> <id> status drafted`.

7. **Josh reviews and merges.** The loop NEVER merges. The merge is the human gate.

### The four stacked guards (state they hold)
1. Evidence triangle at emit time (§4). 2. Anti-gaming refuses fixture edits (step 3).
3. Gate must return RECOMMENDED (step 5). 4. PR opens as draft for explicit human merge (step 6).

## Guardrails (state they hold)
- Emit is a FILTER, not a brainstormer — no record without the full evidence triangle.
- This mode makes NO outward write and NEVER runs the gate — it is read + local file write only.
- Dismissed suggestions stay suppressed (`list-dismissed` feeds both your pre-check and `emit-record`'s dedup).
