# Capture: `kiln/design.md` § "Research basis"

Captured 2026-08-17. Verbatim copy of the source document's "Research basis: not every README section is worth its cost by default" section, preserved here because the Slice 1 run folder (`kiln/`) does not ship with the released plugin and `core/references/` entries citing it need a repo-relative path that actually resolves in the shipped tree.

### Research basis: not every README section is worth its cost by default

Gloaguen, Mündler, Müller, Raychev, and Vechev, "Evaluating AGENTS.md: Are
Repository-Level Context Files Helpful for Coding Agents?" (arXiv:2602.11988),
found that repository-level context files as a class do not reliably improve
coding-agent task success while increasing inference cost by over 20% on
average, and that this null result held across models, agents, and both
LLM-generated and developer-committed files. The same study found concrete,
actionable instructions in context files are well followed by coding agents,
while generic repository overviews are not helpful despite being popular and
recommended by model providers; context files are best suited to documenting
non-standard practices, not general repo description.

This is direct supporting evidence for keeping always-loaded, generated
context small and evidence-justified rather than uniformly complete. Slice 1
therefore cannot treat every Content Contract section (purpose/scope,
repository at a glance, quick start, runtime/tooling, architecture overview,
development workflow, known constraints, documentation map, for AI agents)
as equally worth generating by default: sections that are
generic-overview-shaped (repository at a glance, architecture overview)
carry the paper's unhelpful-but-costly profile, while sections that are
concrete-instruction-shaped (quick start, known constraints, for AI agents)
carry its effective profile. Any claim that a generated section improves
outcomes should be treated as unproven until evaluated, not assumed from the
section existing. `spec-draft.md`'s README enrichment and local validation
acceptance criteria encode this distinction as testable behavior rather than
citing it as an unverified aside.
