# doc-text profile

Applies when the artifact-family profile supplied for this run is
`jcsl:artifact-family:doc-text`. Read this alongside the family-neutral
personas and grounding contract — it refines what counts as a finding under
each lens and how the Validator disproves one, for a doc specifically.

## Finder application

### Lens applications

- **Hidden Assumptions** — invariants the doc states without proof or
  qualification (e.g., "the service guarantees X" without naming the failure
  mode that breaks X); consequences the doc doesn't acknowledge (e.g., a
  stated TTL without noting what breaks under replication lag); scope claims
  the doc doesn't bound (e.g., "all webhooks are validated" without
  specifying which signature schemes count as "validated").
- **Failure Scenarios** — a reader who follows the doc as written and
  reaches a broken state.
- **Blast Radius** — readers who act on the incorrect claim, downstream docs
  that repeat this claim.

### Location format

`<Section> section, paragraph N`. Match the doc's actual heading text;
case-sensitive.

## Validator disproof strategies

1. Does the surrounding doc context already explain the apparent gap under
   the same lens?
2. Is the missing detail discoverable elsewhere in the repo (a config file,
   an environment-variable example, a command's help output) and not
   load-bearing for the doc's stated purpose?
3. **Doc-as-living-artifact rule.** A finding that demands the doc *add* a
   detail already discoverable elsewhere is a false positive — docs evolve,
   and missing-but-discoverable details are not defects. Only surviving
   findings are those where the missing detail would actively mislead a
   reader or cause an incorrect implementation or operations decision.
4. Read adjacent files or sibling docs to verify whether the doc's claim is
   accurate in the surrounding repo context, per the grounding contract's
   tool-discipline rule.
