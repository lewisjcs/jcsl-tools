# Profile contract — org content at the `profile/` seam

The core runs with or without org content. A distribution may place a
`profile/` directory beside `SKILL.md` (at the skill root). This file is
the whole contract for what that directory may contain and what the core
does with it. There is no manifest and no profile versioning: presence
of an entry file is activation; absence is skip.

## The four entry files

The core consults exactly four fixed filenames. Each is read at the
stage named for it and at no other point.

| Entry file | Consulted at | Feeds |
|---|---|---|
| `profile/evidence-sources.md` | Stage 1 | Additional evidence sources beyond the repository — where to query, and how to cite what comes back. |
| `profile/drafting-conventions.md` | Stage 3 | Org section formats and drafting conventions; may point into supporting files it ships (e.g. `profile/knowledge/`). |
| `profile/redaction.md` | Stages 3 and 6 | Visibility and redaction policy for what a draft or report may state. |
| `profile/document-selection.md` | Run scope (Step 0) | Which files beyond the README the run manages. |

A profile may ship any supporting files beside these (`profile/knowledge/`,
extra references). Anything not reachable from an entry file is inert —
the core never scans `profile/` beyond the four names. The seam is
extensible work-side without a core change; a **fifth entry point**, if
one is ever needed, is a core change and a re-promotion.

Two loading branches, stated so they are not improvised. **Several entry
files present:** each is loaded independently at the stage assigned to
it; there is no load order between them, because no entry file may
reference another. **A supporting file reachable from no entry file:**
it is inert — the core does not read it, and its presence changes
nothing about the run.

"Reachable from an entry file" means the entry file names the supporting
file by path. The core follows those paths from an entry file it loaded,
at the stage that entry file is loaded, and nowhere else.

## Sovereignty rule

Org content **adds; it never overrides**. It cannot disable a checker,
relax a blocking gate, alter the claim model, or exempt any evidence
class from verification. If an entry file's instruction contradicts a
core rule, the core rule wins and the run reports the conflict.

The consequence, spelled out: apply the core rule, discard the
conflicting instruction for the rest of the run, complete the stage, and
record the conflict in the report as `profile-conflict: <entry file> —
<core rule that won>`. A conflict is not a run failure and does not halt
the pipeline; an unreported conflict is a defect.

This rule is **review-enforced, not machinery-enforced**: it is prose,
and a literal executor reading a profile file that contradicts it might
comply with the profile file. The core limits the blast radius — each
entry file is consulted only at its stage, and the run report discloses
what was loaded — but the boundary holds through review of profile
content before it ships, not through a mechanism here.

## External-source honesty rule

A claim grounded only in an external source (a system named by
`profile/evidence-sources.md` that the isolated fact-checker cannot
re-query) is never marked `confirmed` by local verification. It keeps
its source citation and sits in a distinct class in the ledger and the
report. This extends the scoped verification statement in SKILL.md's
"Verification coverage" section; it never widens "verified".

## Run-report disclosure

Stage 6's report records, in a line near its top:

- `profile: none` — when no entry file was present, or
- `profile: <comma-separated list of the entry files present>` — when any was,

plus a provenance line: the `commit:` value from a `PROVENANCE.md`
beside `SKILL.md` when that file exists, else `source: plugin install`.
A run with org content and a core-only run must be distinguishable from
the report alone.

Both lines are written on every run. A run that loaded some entry files
lists exactly those, by their entry filenames, in the fixed table order
above; a run that loaded none writes `profile: none`, and so does a run
that found no `profile/` directory at all — the report does not
distinguish those two cases. Each conflict the sovereignty rule resolved
adds its own `profile-conflict:` line beneath the disclosure line.

## What promotion never touches

Re-promotion of the core replaces `SKILL.md`, `core/`, and `scripts/`
and never touches `profile/` — work-side edits are legitimate there and
only there. The parity check covers `SKILL.md` + `core/` + `scripts/`
exactly; `profile/`, `package.json`, `PROVENANCE.md`, and any
distribution extras sit outside it by design.
