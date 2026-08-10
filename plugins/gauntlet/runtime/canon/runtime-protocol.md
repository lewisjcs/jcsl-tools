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
