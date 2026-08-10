# plan-text profile

Applies when the artifact-family profile supplied for this run is
`jcsl:artifact-family:plan-text`. Read this alongside the family-neutral
personas and grounding contract — it refines what counts as a finding under
each lens and how the Validator disproves one, for a plan specifically.

## Finder application

### Lens applications

- **Hidden Assumptions** — dependencies the plan assumes but doesn't name
  (e.g., a step reads from a cache without specifying whether the cache
  exists or how it's invalidated); sequencing constraints the plan doesn't
  enforce (a later step verifies behavior an earlier step introduces, but an
  intervening step modifies the same thing in a way that verification
  doesn't catch); success criteria that don't actually verify the goal
  (e.g., "tests pass" when the new code path isn't exercised by any test).
- **Failure Scenarios** — a step that fails mid-execution, a dependency that
  isn't ready when a later step needs it, a sequencing constraint the plan
  ignores.
- **Blast Radius** — later steps that depend on this one, consumers of the
  shipped feature.

### Location format

`Step N (...)`, `Goal section (...)`, `Test strategy section (paragraph M)`.
Cite the section by its heading; case-sensitive.

## Validator disproof strategies

1. Does the surrounding plan context (Goal, Steps, Test strategy,
   Files-to-modify) already address the concern under the same lens?
2. Is the missing detail an implementation detail the implementer would
   derive from stated intent — not load-bearing for verification?
3. **Plan-as-scaffolding rule.** A finding that demands
   implementation-detail specification (cache key composition, error message
   wording, retry counts) the implementer would derive from stated intent is
   a false positive — plans are scaffolding, not exhaustive specs. Only
   surviving findings are those where the missing detail is load-bearing for
   verification: without it, the Test strategy section cannot assert
   success, or two steps are ambiguous in a way that would produce divergent
   implementations.
4. Read source files referenced by the plan to verify whether the assumed
   dependency or structure exists, per the grounding contract's
   tool-discipline rule.
