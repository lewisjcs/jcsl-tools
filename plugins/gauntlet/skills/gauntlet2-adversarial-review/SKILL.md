---
name: gauntlet2-adversarial-review
description: Gauntlet v2 pilot — runtime-driven adversarial review (Find, Validate, Adjudicate under a deterministic runtime). Use ONLY when explicitly asked for gauntlet2-adversarial-review, the v2 pilot, or the runtime-driven adversarial review. Not a trigger-phrase surface: the incumbent gauntlet:adversarial-review remains the default lane during the pilot.
---
<!-- generated from canon; do not edit -->

## Claude Code host mechanics

Preflight: run `node --version` — if it fails or prints a major version below 22, stop and report that as the blocker (the runtime requires Node >=22).

Create the run directory once, before anything else, and reuse that one path for the whole run: `RUN_DIR=$(mktemp -d)`. Every file this run reads or writes — the artifact file, `bundle.json`, `state.json`, raw-output and host-meta files, `result.json`, `evidence.json` — goes under `$RUN_DIR`. Never write any of them inside the plugin cache, and never into the repository being reviewed. Wherever the handshake below writes `<bundle.json>`, `<state.json>`, and the rest, pass the `$RUN_DIR` path.

First, materialize the artifact as a single file, because `--primary` takes a path on disk — never a description of what to review, a PR number, or a branch name. For a code-diff, write the diff out first: `git diff <base>..<head> > "$RUN_DIR/artifact.diff"`, where `<base>` and `<head>` are the two commits the review spans (for a pull request, its base and head). For plan-text or doc-text, the artifact is already a file — the markdown file itself — so use its existing path and copy nothing. The resulting path is what `--primary` takes in the next step.

To author the bundle for a reviewable artifact, use the `bundle` subcommand: `node "${CLAUDE_PLUGIN_ROOT}/runtime/bin/cli.mjs" bundle --family <code-diff|plan-text|doc-text> --primary "$RUN_DIR/artifact.diff" [--path <logical-path>] --out "$RUN_DIR/bundle.json"`. `--path` records the artifact's logical path inside the repository under review, which is what reported finding locations are anchored to; it is optional, but pass it for a code-diff. The command writes the bundle to `--out` and prints a compact summary — `artifactId`, `artifactFamily`, `artifactSha256`, and `out` — rather than the bundle itself, so read `"$RUN_DIR/bundle.json"` if the full bundle is ever needed.

The two subcommands take the family in different forms, and mixing them up is a hard refusal: `bundle --family` takes the bare id (`code-diff`), while `init --family` takes the prefixed id the bundle records in `artifactFamily` (`jcsl:artifact-family:code-diff`). Pass the `artifactFamily` value from the `bundle` summary (or read it off `"$RUN_DIR/bundle.json"`) to `init`.

Perform `dispatch-finder` actions with the Agent tool using `subagent_type: gauntlet:gauntlet2-adversarial-finder`, and `dispatch-validator` actions with `subagent_type: gauntlet:gauntlet2-adversarial-validator`. Pass the dispatch prompt from the pending action verbatim; each dispatch is a fresh agent with no shared history. Record the model the agent actually ran on in that receipt's host-meta file.

Class `jcsl:gauntlet:adversarial-review@2.0.0` — adversarial code/plan/doc review. Two opposed roles (`jcsl:gauntlet:adversarial-finder`, `jcsl:gauntlet:adversarial-validator`) run in fresh, isolated dispatches under a deterministic runtime.

## Driving the runtime

This skill's job is narrow: drive the `gauntlet-runtime` CLI through its full handshake and perform exactly the dispatch each pending action requests. The runtime — not this skill — decides what happens next; a host only performs the dispatch a runtime action requests and returns what it observed.

1. **`init`** admits the run and prints the first pending action: `node "${CLAUDE_PLUGIN_ROOT}/runtime/bin/cli.mjs" init --bundle <bundle.json> --family <artifactFamily> --host <claude-code|codex> --out <state.json>`.
2. **`next`** reports the current pending action, or `{"terminal": true}` once the run has reached `adjudicating` or `gap`: `node "${CLAUDE_PLUGIN_ROOT}/runtime/bin/cli.mjs" next --state <state.json>`.
3. Perform the dispatch the pending action requests — in a fresh, isolated context carrying only the artifact view and profile the action specifies — and capture the raw output.
4. **`receipt`** reports what was observed; repeat from step 2 until `next` reports `terminal: true`: `node "${CLAUDE_PLUGIN_ROOT}/runtime/bin/cli.mjs" receipt --state <state.json> --action <actionId> --output <raw-output-file> --host-meta <host-meta.json>`. Always pass `--host-meta` on every dispatch receipt: write a JSON file recording the model the dispatch actually ran on, keyed by role — `{"modelBinding": {"finder": {"model": "<model-id>"}}}` for a dispatch-finder receipt, `{"modelBinding": {"validator": {"model": "<model-id>"}}}` for a dispatch-validator receipt. The runtime merges these into `evidence.modelBinding`; a run with no modelBinding receipts produces an unverifiable evidence record. When measured, numeric keys `tokens`, `cost` (USD), `turns`, and `latency` (seconds) may be added as top-level keys alongside `modelBinding` — e.g. `{"modelBinding": {...}, "tokens": 1234}` — and are summed into `evidence.measurements`.
5. **`result`** produces the typed review result and evidence record once the run is terminal: `node "${CLAUDE_PLUGIN_ROOT}/runtime/bin/cli.mjs" result --state <state.json> --out <result.json> --evidence <evidence.json>`.

<HARD-GATE>
A host never reorders, collapses, or skips a stage; never decides whether a second Finder or Validator pass runs; and never invents, drops, or re-labels a candidate or verdict ID. Do NOT dispatch the Finder and Validator from a single call. Do NOT adjudicate findings yourself — adjudication is the runtime's job, not the host's. Do NOT skip `receipt` or infer a result before `next` reports `terminal: true`. Each dispatch runs in a fresh, isolated context: no shared conversation history, no visibility into the other role's reasoning. An out-of-order, substituted, stale, or wrong-digest receipt is a typed refusal the runtime reports on its own — surface it; never work around it or silently retry outside the runtime's own one-retry-per-stage rule.
</HARD-GATE>

## Runtime protocol (canon, verbatim)

# Runtime protocol

The Adversarial Review Class runs as a sequence of stages driven by a
deterministic runtime — an executable reducer and validator, not a model. The
runtime, not any host, decides what happens next; a host only performs the
dispatch a runtime action requests and returns what it observed.

## Stage flow

1. **Admit and snapshot.** The runtime validates the invocation, resolves the
   artifact bundle, computes and freezes its digests, and selects the
   artifact-family profile for this run.
2. **Dispatch Finder.** The runtime emits a dispatch-finder action carrying
   the Finder persona's identity and instruction-source hash, the artifact
   digest, the selected profile, the model requirement, and the expected
   output contract. A host performs the dispatch — in a fresh, isolated
   context carrying only the artifact view and profile the action specifies
   — and returns a stage receipt with the raw output.
3. **Validate the Finder receipt.** The runtime parses and validates the
   candidate list against its contract, assigns each candidate a
   deterministic ID (`F-001`, `F-002`, ...), and retries the dispatch once,
   and only once, on malformed output. If the retried dispatch is also
   malformed, the runtime records a typed gap for the Finder stage rather
   than retrying further.
4. **Handle an empty candidate set.** Zero candidates is a valid Finder
   result. When the candidate list is empty, the runtime skips the Validator
   dispatch entirely — there is nothing to adjudicate — and proceeds directly
   to typed-result construction.
5. **Dispatch Validator.** When there is at least one candidate, the runtime
   emits a dispatch-validator action carrying the Validator persona's
   identity, the identical artifact digest, and the Finder's candidates
   verbatim with their assigned IDs. A host performs the dispatch in a fresh,
   isolated context and returns a stage receipt.
6. **Validate the Validator receipt.** The runtime requires exactly one
   verdict per candidate, referenced by `findingId`. A cardinality mismatch,
   a duplicate ID, an invented ID, or an omitted ID is a receipt-validation
   failure, not a warning. The runtime retries the dispatch once, and only
   once, on malformed output. If the retried dispatch is also malformed, the
   runtime records a typed gap for the Validator stage rather than retrying
   further.
7. **Adjudicate.** The runtime joins candidates and verdicts by ID and
   applies the versioned adjudication policy mechanically: drop `disproved`
   and below-floor results, deduplicate, rank, and apply the High-severity
   grounding check. Adjudication is entirely deterministic — no model call is
   involved.
8. **Emit the typed result and evidence record.** The runtime produces the
   typed review result and the accompanying evidence record: identity,
   artifact and component digests, surviving and disproved findings,
   coverage and calibration status, stage attempts, and enough detail to
   reproduce what was reviewed.

## Host obligations

A host adapter's job is narrow: perform the dispatch a runtime action
requests, in the isolation the action specifies, and return a receipt
carrying the raw output plus host execution metadata. A host never reorders,
collapses, or skips a stage; never decides whether a second Finder or
Validator pass runs; and never invents, drops, or re-labels a candidate or
verdict ID. Retries, cardinality checks, deduplication, ranking, and every
other deterministic mechanic belong to the runtime, not the host.

An out-of-order, substituted, stale, or wrong-digest receipt is a typed
refusal, never a warning silently absorbed.

## Isolation

Both dispatches — Finder and Validator — require a fresh, isolated context:
no shared conversation history, no visibility into the other role's
reasoning, only the artifact view and inputs the dispatch action specifies.
This isolation is what keeps the two opposed personas from converging into
one agreeable pass; a host that cannot provide it cannot honor this Class.

## Escalation

A second Validator pass is off by default. It may run only under an
explicitly admitted policy trigger, and even then it only re-examines
existing candidates for precision — it cannot recover a defect the Finder
never raised. A malformed response is a retry, never grounds for a second
opinion.

## Overlays and output schemas

The Finder and Validator personas are family-neutral: the lenses, severity
rubric, and disproof strategies apply to every artifact family this Class
supports. What counts as a finding under a lens, the `location` format, and
family-specific disproof refinements come from the artifact-family profile
the runtime selects during admission — never from the persona files
themselves. Output structure for each stage is the contract the dispatch
action names; the runtime validates raw output against that contract, not
against any host-specific transport shape.

