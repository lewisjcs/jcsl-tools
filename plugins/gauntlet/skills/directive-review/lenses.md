# directive-review — Lens Definitions

These lenses evaluate **agent-instruction prose** (prompts, knowledge/reference files) at the *prompt level* (per Tian et al., arXiv:2509.14404): the instruction artifact is judged on its own terms — clarity, internal consistency, gate enforceability, completeness — NOT against external code (that is cartographer-refresh's job) and NOT for human-doc voice (that is doc-review's job).

The reader you are protecting is a **literal LLM executor**: it follows instructions exactly as written, treats hedges as optional, and picks one branch when the text is ambiguous. A defect is anything that makes that literal executor do the wrong thing.

## Lens 1 — Under-specification (apply first)

**Evidence: STRONG.** Controlled study (CMU "What Prompts Don't Say," arXiv:2505.13360): omitting an essential requirement drops the model's chance of satisfying it by 22.6% on average (up to 93.1%); models self-resolve omissions only 41.1% of the time.

A directive is under-specified when it states a goal or happy path but omits a requirement, success criterion, or branch condition the executor must have to act correctly — leaving multiple valid-but-inconsistent behaviors open.

- **Fires when:** a step says what to do but not when it does NOT apply; a rule references a condition ("if the gate fails…") without saying what the executor does in the other branch; a success criterion is named but not defined ("ensure it's clean" with no definition of clean).
- **Does NOT fire for:** details discoverable elsewhere the artifact legitimately points to (e.g., "see lenses.md for the criteria"); the artifact deferring a genuinely implementer-judgment call. Missing-but-pointed-to is not under-specification.
- **Do NOT claim** conditional/edge-case omissions are the *hardest* or *worst* defect class — that specific claim was empirically refuted (research-brief §2). Rank them by impact like any other finding.

## Lens 2 — Internal contradiction

**Evidence: taxonomy (arXiv:2509.14404 "Conflicting instructions") + observed in our own builds** (the split citation-downgrade rule: one section said "all unresolvable citations → MISLEADING," another carved out an exception — two verdicts for the same scenario).

Two sections of the same artifact give mutually incompatible directives, and the executor cannot satisfy both.

- **Fires when:** section A says "always X" and section B says "X is exempt when Y" without a reconciling rule; a verdict/threshold/format defined one way in one place and differently in another; an ordering constraint that conflicts with another stated ordering.
- **Does NOT fire for:** a general rule followed by an explicitly-scoped exception that names its condition (that is correct specification, not contradiction); two statements that read as conflicting but operate on different inputs the text distinguishes.
- **Disproof boundary:** an apparent contradiction resolved by a reconciling clause elsewhere *in the same artifact under this lens* is disproved. Do NOT use the artifact "reading well overall" to disprove — point to the specific reconciling text.

## Lens 3 — Unenforceable gate

**Evidence: observed in our own builds** (the gauntlet's own "HARD-GATE not self-enforcing" failure — a `<HARD-GATE>` stated as a rule but framed so the executor advanced past it; held only by user push). No controlled harm study; label as practice-grounded.

A gate, stop condition, or verification step **structurally exists** but lacks a blocking consequence — it names a check but never says "do not proceed until," so a literal executor satisfies the letter (it "verified") and advances anyway. The defect is **structural (a missing consequence/failure-branch)**, not the wording of the verb.

- **Fires when:** a HARD-GATE/STOP/verify step names a condition but no consequence ("ensure all lenses ran" with no "do not proceed until"); a verification step has no defined failure action ("confirm the counts match" with nothing about what to do on mismatch). The step is *present and firmly worded* but toothless.
- **Does NOT fire for:** a gate with a firm directive AND a concrete consequence ("STOP — do not adjudicate until security ran; if it didn't, dispatch it now"); a non-blocking recommendation correctly framed as optional.
- **Distinguish from Under-specification:** under-specification is a missing requirement; unenforceable-gate is a *present but toothless* requirement. If the gate's condition is missing → lens 1; if the gate exists but can't bite → lens 3.
- **Distinguish from Ambiguity (lens 4) — the deciding rule:** if the step fails *because of a hedge word* ("consider", "you may want to", "you should ideally", "try to") on the action, that is **lens 4**, not lens 3 — the register is the defect. Lens 3 is reserved for steps that are *firmly worded* ("Confirm X", "Verify Y") yet still lack a consequence/failure-branch. One defect, one lens: a hedged gate is a lens-4 finding; a firm-but-toothless gate is a lens-3 finding. Never emit both for the same step.

## Lens 4 — Ambiguity / literal-readability

**Evidence: proxy.** Prompt-phrasing sensitivity is well-established (FormatSpread, ICLR 2024: ≤76-point accuracy swing from meaning-preserving rephrasings; IFEval++ reliable@10 drops 18–62%). No study isolates soft-vs-firm directive register specifically, so this is proxy-grounded.

A load-bearing directive is phrased so a literal executor can interpret it ≥2 ways, or hedges an action that is meant to be mandatory.

- **Fires when:** a hedge ("consider", "you may want to", "you should ideally", "try to", "it might be worth") sits on a load-bearing action the executor must take — **this includes hedged gate/verification steps** (a hedge on a blocking step is a lens-4 defect, per the deciding rule in lens 3); a pronoun/referent is ambiguous ("run it" — run what?); a term is used in two senses without disambiguation.
- **Does NOT fire for:** hedging on a genuinely optional step (correct); domain jargon used consistently; a single clear interpretation that only *feels* terse.
- **Owns hedge-word defects (the deciding rule):** any hedge word on a mandatory action is lens 4, even when the action is a gate or verification. Lens 3 fires only when a *firmly-worded* gate lacks a consequence. This keeps the two lenses mutually exclusive — emit exactly one finding for a hedged gate, under lens 4.
- **Verbosity-bias guard (CRITICAL):** do NOT flag a directive as ambiguous merely because the artifact is long. Length is not a defect. A 600-line prompt that is clear is clean; a 20-line prompt with one hedged load-bearing action has a finding. Score the specific phrasing, never the file size.

## Deferred lens (do NOT emit in v1)

- **Context-dependent-truth** — an instruction true in one context applied literally elsewhere. Real pattern, but zero empirical harm data and high false-positive risk on legitimately-conditional instructions. Add when evidence or fixtures accumulate.

## Category mapping

For the `category` field of emitted findings: Under-specification → `correctness`; Internal contradiction → `correctness`; Unenforceable gate → `correctness`; Ambiguity/literal-readability → `maintainability`. (Enum: security/correctness/data-loss/maintainability/style/accuracy/other.)
