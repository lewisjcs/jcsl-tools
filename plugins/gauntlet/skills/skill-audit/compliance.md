# Skill Audit — Layer 1: Compliance Rules

Read [principles-shared.md](principles-shared.md) first for philosophy and severity grading. Then check every skill against each rule below.

---

## Rule 1: Description Field — Trigger Nouns/Verbs

The description is the only content read to decide whether to invoke a skill. It has a small effective token window.

**Check:** Does the description contain specific words a developer would type?

```yaml
# ❌ violation: Too abstract
description: Create an Architectural Decision Record (ADR).

# ✅ ok: Includes trigger phrases
description: Use when recording a decision, creating an ADR, documenting why we chose an approach, or "let's capture this decision".
```

**Common violations:** Generic one-liners, descriptions that name the output instead of the trigger.

---

## Rule 2: Description Field — No Workflow Summary

If the description summarizes the skill's process, agents follow the summary instead of reading the full skill body. This was observed directly: a description saying "code review between tasks" caused one review; removing the workflow summary caused correct two-stage behavior.

**Check:** Does the description describe HOW the skill works (steps, phases, sequence)?

```yaml
# ❌ violation: Summarizes workflow
description: Use when starting a task — dispatches parallel agents for Jira, Docs, and Codebase context then hands off to brainstorm

# ✅ ok: Triggers only
description: Use when starting a new task, beginning work on a ticket, kicking off a Jira story, or given an EXT- issue key
```

---

## Rule 3: Accuracy Over Comprehensiveness

Code examples that don't match the actual repo cause ~10% performance degradation.

**Check:** Are code examples pulled from real files with cited paths, OR explicitly labeled as simplified illustrations?

**Common violations:** Invented code examples presented as real, outdated examples from previous repo versions.

---

## Rule 4: Focus Beats Breadth (bidirectional)

A skill should do one thing. The failure mode is bidirectional: too broad dilutes, too narrow fragments.
- **Too broad:** covers more than 2-3 distinct modules → split it.
- **Too narrow:** scoped so tightly it owns only a fragment of a task, forcing several skills to co-load and creating ambiguous activation → consolidate into a coherent unit.

**Check:** How many distinct concerns does the skill address? And does it own a *complete* task or just a fragment?

**Threshold:** >3 distinct modules = `warning`. >5 = `violation`. A skill that cannot be invoked without 2+ siblings co-loading for one logical task = `warning` (over-fragmented).

---

## Rule 5: Verification Loops Over Vague Reminders

A concrete, checkable step produces stronger outcomes than a vague reminder. The check does NOT have to be a shell command — a structured comparison against a reference doc (e.g. read `STYLE_GUIDE.md` and compare) is a first-class verifier. What loses is the vague reminder, not prose itself.

**Check:** Does each agent instruction block end with an explicit check — a command OR a structured comparison?

| Instead of (violation) | Write (ok) |
|------------------------|------------|
| "Make sure you found all the PRs" | "List every PR found with number, repo, state. If none found, explicitly state this." |
| "Check that the ticket exists" | "Confirm ticket key resolves before reporting. If not found, stop and report immediately." |

**Don't flag over-strict verifiers as compliant-good either:** a check that rejects correct output over spurious differences (formatting, punctuation, valid alternative phrasing) is itself a smell — note it.

---

## Rule 6: Avoid Phantom Alternatives

Skill bodies are read by models with no comparative state. Phrasing that contrasts the chosen behavior with another *named* alternative the model wasn't going to do creates phantom-alternative inflation: token cost without direction.

**Check:** Does the skill use comparative phrasings (`rather than X`, `instead of Y`, `not a Z`, `do not <phantom default>`) where the contrast adds no direction?

**Three cases to distinguish:**

| Case | Example | Verdict |
|---|---|---|
| Bright-line prohibition (real model temptation) | `Never invent facts` / `Do not modify source code` | `ok` — keep |
| Default-behavior directive | `Read the prompt first` (vs. `Don't skip the prompt`) | `ok` — positive form preferred |
| Phantom-alternative comparison | `Do X rather than Y` / `This is a hard stop, not a degraded mode` | `violation` — drop |

**Common violations:** `rather than [thing the model wasn't going to do]`, justification clauses opening with `not a`, double-negation patterns where a positive directive already stands alone (`do X. Do not <phantom default>.`).

**Test:** Would removing the comparison weaken the directive? If no, it's phantom-alternative phrasing — drop it.

---

## Rule 7: Firm Directives Over Soft Hedges

Opus 4.7 follows directives more literally than 4.5/4.6. Soft hedges read as optional and get skipped — actions phrased as suggestions don't get taken.

**Check:** Does any load-bearing instruction use hedging phrases like `consider`, `you may want to`, `it might be worth`, `feel free to`, `optionally`?

```markdown
# ❌ violation: Hedged action that should always run
**Verify:** ... If counts mismatch, consider re-dispatching the agent.

# ✅ ok: Firm directive
**Verify:** ... If counts mismatch, re-dispatch the agent. Do not advance until verification passes.
```

**Common violations:** `consider X`, `you may want to X`, `it might be worth X-ing`, `optionally do X`. Each one gives 4.7 permission to skip the action.

**Distinction from Rule 6:** Rule 6 strips *unnecessary* directives (phantom alternatives). Rule 7 strengthens *too-weak* directives (soft hedges). They're complementary checks, not duplicates.

**Exception:** Genuinely optional behaviors stay hedged — `optionally include a graphviz diagram for branching workflows` is fine because it's truly optional. Only flag hedges where the action is load-bearing.
