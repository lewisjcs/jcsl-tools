---
name: run
description: Use when running the full review Party over one artifact — a pull request, a local diff, a plan, a doc, a skill, or an agent-instruction file. The canonical PR-review surface — "review this PR" routes here. Trigger phrases include "review this PR", "review PR <number>", "review the PR", "review this", "run the gauntlet", "do a full review", "fully review", or any natural-language variation requesting a full review of an artifact. When NOT to use: for a single-lane review invoke the corresponding sibling directly (threat-review, code-quality-audit, adversarial-review, plan-review, doc-review, skill-audit, directive-review).
argument-hint: "[<pr-url> | <path>] [--type <type>] [--full] [--go-live] [--no-go-live] [--force-lane <class>] [--skip-lane <class>]"
---

# Gauntlet

A thin host over the Party runtime. The runtime decides what this review is and who reviews it; this skill fetches the artifact, performs the dispatches the runtime asks for, and places the report the runtime wrote.

The runtime owns every decision that used to live here: what type of artifact this is, which review lanes to field (the roster — the set of lanes the runtime decided to run), where the artifact snapshot is frozen, how findings across lanes are adjudicated and de-duplicated, and what the report says. Do not re-derive any of it. When the runtime refuses something, surface the refusal — never work around it.

The skill's whole job is the eleven steps below, in order.

## Usage

```
/gauntlet:run https://github.com/<org>/<repo>/pull/<n>   — a pull request (code diff)
/gauntlet:run                                            — the local branch diff
/gauntlet:run <path-to-file.md>                          — a plan, doc, skill, or agent-instruction file
```

One artifact per run. The runtime reviews one file per party run and refuses a directory (`CLI_PARTY_DIRECTORY_INPUT`) — to review several files, run the skill once per file.

**When NOT to use:** a single-lane review (invoke `gauntlet:threat-review`, `gauntlet:plan-review`, `gauntlet:doc-review`, `gauntlet:adversarial-review`, `gauntlet:code-quality-audit`, `gauntlet:skill-audit`, or `gauntlet:directive-review` directly). Designing an artifact rather than checking one — brainstorm first; the gauntlet is the quality pass on the result.

## 1. Preflight

**Host.** The Party runs under Claude Code. Step 6 uses the packaged Claude dispatch wrapper with the `claude-code` host binding. If this session is not Claude Code, stop here and name the supported single-lane sibling skills. Before forming a party, check that `${CLAUDE_PLUGIN_ROOT}/runtime/bin/dispatch.mjs` exists. A missing wrapper means this installed plugin cannot enforce the turn limit.

**Sibling-name check.** Run `ls ${CLAUDE_PLUGIN_ROOT}/skills/` and note the sibling skill names. Another plugin, or a local skill of the same bare name, can shadow one of them. Every sibling dispatch in this skill therefore uses the plugin-qualified form — `Skill: gauntlet:<name>` — never the bare name.

**Node.** Run `node --version`. If it fails or the major version is below 22, stop and report that as the blocker: the runtime requires Node 22 or newer.

**The command.** Every runtime call below is `node "${CLAUDE_PLUGIN_ROOT}/runtime/bin/cli.mjs" <subcommand> …`. Never write run files into the plugin directory or into the repository under review — the runtime owns where a run is recorded. The report copy that step 8 places under a repository's `reviews/` directory is not a run file: it is the deliverable, and putting it there is deliberate.

## 2. Normalize the input

The runtime's `--primary` takes a path to one file on disk — never a pull-request number, a branch name, or a description of what to review. Stage the artifact first: `STAGE=$(mktemp -d)`.

**A pull-request URL or number.** Write the diff and the body out, and find the local clone:

```
gh pr diff <n> > "$STAGE/pr.diff"
gh pr view <n> --json title,body,headRefOid,baseRefName,baseRefOid,url,author
gh api user --jq .login
gh repo view --json visibility --jq .visibility
```

Write the `title` value to `"$STAGE/pr-title.md"` and the `body` value to `"$STAGE/pr-body.md"`. Set `AUTHOR=self` when `author.login` equals the `gh api user` login, else `AUTHOR=other`. When `gh repo view` succeeds, map its result to set `VISIBILITY` (`PUBLIC` → `public`, any other value → `private`). The runtime records it on the origin and does not act on it; this skill reads it in step 8 to decide whether to ask before posting. When it fails, leave `VISIBILITY` unset and tell the operator in chat: an unrecorded visibility is treated as public, so step 8 will ask.

Then fetch the thread — every issue comment, inline review comment, and review on the pull request:

```
gh api --paginate repos/<owner>/<repo>/issues/<n>/comments
gh api --paginate repos/<owner>/<repo>/pulls/<n>/comments
gh api --paginate repos/<owner>/<repo>/pulls/<n>/reviews
```

Write the three results as one JSON object `{issueComments, reviewComments, reviews}` to `"$STAGE/thread.json"` and pass `--thread "$STAGE/thread.json"` beside the origin flags. An empty thread is still written and passed. Pass `--full` only when the operator asked for a full re-review. The runtime decides whether this party revises an earlier posted one; never pre-judge it.

**Resolve the repository root explicitly.** `--repo-root` and `--reviewed-commit` are both hard requirements for `--type code-pr` — without them the runtime refuses with `CLI_REVIEWED_COMMIT_REQUIRED` — and it pins its review worktree from that root. `gh pr diff` and `gh pr view` resolve against the current directory, so start there: `git rev-parse --show-toplevel`. For a pull-request URL, confirm that root is actually the right clone — check that one of its remotes matches the URL's `<org>/<repo>` (`git -C <repo-root> remote -v`). If none matches, stop and ask the operator for the path to the clone. That question is a refusal in all but name; it is a legitimate pause, listed with the others below.

The head commit must also exist locally, since the runtime pins the review to it in its own git worktree: check with `git -C <repo-root> cat-file -e <headRefOid>^{commit}` and, if it is absent, fetch it (`git -C <repo-root> fetch origin <headRefOid>`). Then form the party with `--primary "$STAGE/pr.diff" --type code-pr --repo-root <repo-root> --reviewed-commit <headRefOid> --title "$STAGE/pr-title.md" --body "$STAGE/pr-body.md" --origin-url <url> --base-ref <baseRefName> --base-sha <baseRefOid> --author $AUTHOR --thread "$STAGE/thread.json"`, adding `--visibility $VISIBILITY` before `--thread` only when the lookup above succeeded.

**No argument.** Review the current branch against the trunk:

```
git diff main..HEAD > "$STAGE/local.diff"
```

Fall back to `master` only if `main` does not exist. Then form the party with `--primary "$STAGE/local.diff" --type code-local`. A working tree cannot be pinned, so the runtime records its content digest instead.

**A path.** Pass the file as `--primary <path>` and let the runtime detect the type. Do not pass `--type`: the operator can, and the runtime records it as an override, but this skill never guesses one.

If detection cannot settle, the runtime refuses with `CLI_PARTY_TYPE_AMBIGUOUS` or `CLI_PARTY_TYPE_REQUIRED` and names the candidate types in the refusal message. Ask the operator which one, using the refusal's own candidate list, and re-invoke with their answer as `--type`. **Only three pauses are legitimate before the report: this one, the missing-clone question above, and the go-live question in step 5.** Every other refusal stops the run and is surfaced as-is.

For a **single-file** code diff also pass `--path <logical-path>` — the artifact's path inside the repository under review, which is what reported finding locations anchor to. Omit `--path` for a multi-file diff: there is no one logical path to name, and the runtime falls back to the `--primary` file name.

## 3. Extract the go-live signals

For a `code-pr` or `code-local` artifact only, compute the calibrated 6-signal go-live pre-filter over the diff and the pull-request body (recall 0.92 / FPR 0.28 against its calibration set). The pre-filter matches if ANY of: a status-code/response-contract change, an auth/entitlement-gate change, a `BREAKING CHANGE` declaration, a feature-flag/gate/kill-switch **removal** (not introduction — that is dark prep), terminal rollout language (`go-live`, `GA`, `enable for all`, `source of truth`, `removes the legacy gates`), or an SDK major-version bump.

Pass each signal that matched to `party-form` as a repeated `--golive-signal <id>` flag, using these ids:

| Signal | Flag value |
|---|---|
| status-code / response-contract change | `status_or_contract_change` |
| auth / entitlement-gate change | `auth_or_entitlement_change` |
| `BREAKING CHANGE` declaration | `breaking_change` |
| feature-flag / gate / kill-switch removal | `flag_removal` |
| terminal rollout language | `terminal_rollout_language` |
| SDK major-version bump | `sdk_major_release` |

This step reports signals; it decides nothing. Whether the signals lead to a go-live question is the runtime's call, read off its answer in step 5. One consequence belongs to this skill rather than the runtime: `--go-live` **is** the operator's answer to step 5's question, already given, which is why step 5 does not ask it again.

## 4. Form the party

Compose one call. Detection, the roster, and the artifact snapshot are all the runtime's decisions:

```
node "${CLAUDE_PLUGIN_ROOT}/runtime/bin/cli.mjs" party-form --primary <artifact-file> [--path <logical-path>] [--type <code-pr|code-local|plan|doc|skill|directive>] [--body <pr-body-file>] [--title <pr-title-file>] [--trust-context <single-user-tool|agent-tool|multi-caller-service>] [--repo-root <dir> --reviewed-commit <sha>] [--origin-url <url> --base-ref <ref> --base-sha <sha> --author <self|other> --visibility <public|private>] [--thread <thread-file>] [--full] [--golive-signal <id>]... [--go-live|--no-go-live] [--force-lane <class>]... [--skip-lane <class>]...
# stdout: {partyRunId, partyDir, profile, roster:{fielded, skipped, gaps, overrides}, goLivePrompt, lanes:[{classKey, runId, runDir, family}], origin, worktree, revision, events}
```

For a pull request, pass the title and body files step 2 wrote as `--title` and `--body`. They are fielding inputs only: the runtime matches them against its signal set and never delivers them to a role. Pass `--trust-context` only when the operator or the repository's configuration states one; otherwise leave it to the runtime's default.

Forward the operator's lane overrides untouched: `--force-lane <class>` and `--skip-lane <class>` are both repeatable, and the runtime validates each against its roster pool — forcing a Class onto a family it does not support is a typed refusal. Never add an override the operator did not ask for. Pass `--go-live` or `--no-go-live` straight through when the operator gave one, and never re-derive what they do to the roster — this applies to every artifact type, not just `code-pr` and `code-local`.

Parse the stdout JSON. Keep `partyRunId` (step 7 needs it) and `lanes` (step 6 needs each lane's `classKey`, `runId`, and `runDir`).

Then print the roster as **one line** to chat, so the operator sees what this run covers before it starts:

```
Roster (<roster.rowId>): fielded <classKey>… · skipped <classKey> (<reason>)… · gaps <lane> (<reason>)…
```

Name every fielded lane, every skipped lane with the runtime's reason, and every gap with its reason. Write `none` for an empty group. Do not editorialize, re-order, or drop a group — the skipped and gap entries are what tell the operator which coverage this run does *not* have.

When `revision` is not null, the runtime linked this party to an earlier posted one. Add a line under the roster: `revision <number> of <priorPartyRunId> · narrow|full`, and when the mode is `full` without the operator asking for it, append the runtime's `fallbackReason`. In `narrow` mode the verifier reads a range-diff and the other lanes read only the patch added since the prior reviewed head (`revision.files`). A changed base or rewritten history selects `full` with an explicit reason.

## 5. The go-live question

**When the operator passed `--go-live`, do not ask.** The flag is the answer, already given: run `Skill: gauntlet:go-live-review` against the same artifact after the report is placed (step 8), exactly as a `y` would.

**Otherwise, ask only when the runtime returned `goLivePrompt: true`.** Never re-derive that condition from the signals, the other flags, or the diff. (`--no-go-live` suppresses it at the runtime, so no question arises.)

Ask once, and take the operator's first answer:

```
This change matched the go-live signals (<trigger>). Run the go-live readiness lane after the report? [y/N]
```

Fill `<trigger>` from the `go-live-review` entry in `roster.gaps[]` — its `trigger` value, which names the signals that fired.

On `y`, run `Skill: gauntlet:go-live-review` against the same artifact **after** the report is placed (step 8), never before. Anything else declines: say `go-live-review: declined` and move on. A wrong question costs one keystroke; never escalate a signal match into an automatic run.

The go-live lane's SHIP / HOLD / NEEDS-INFO verdict is a separate verdict system that stays in its own zone. It never becomes a finding, never counts toward blockers, and never mixes into the report the runtime wrote — folding a drifting, externally-grounded verdict into reproducible counts corrupts the trust signal.

## 6. Drive the fielded lanes

Each lane has its own staged `bundle.json` and run directory. Start fielded lanes in parallel, then advance each lane only when its current dispatch and receipt finish. A lane's pending action supplies `hostBinding.agent`, `hostBinding.model`, and `hostBinding.maxTurns`. The agent name selects `${CLAUDE_PLUGIN_ROOT}/agents/<name without gauntlet: prefix>.md`. Save `next.promptBody` verbatim to `<runDir>/<actionId>-prompt.md`.

Initialize each lane before its first dispatch. Read the prefixed `artifactFamily` from its `bundle.json` and run `node "${CLAUDE_PLUGIN_ROOT}/runtime/bin/cli.mjs" init --bundle <runDir>/bundle.json --family <artifactFamily> --host claude-code --class <classKey> --out <runDir>/state.json`. Use the returned `next` and `hostBinding`. For later actions, use the `next` and `hostBinding` returned by `receipt`, or run `next --state <runDir>/state.json` after an interruption.

Run one process for each pending action:

```
node "${CLAUDE_PLUGIN_ROOT}/runtime/bin/dispatch.mjs" \
  --agent-file "${CLAUDE_PLUGIN_ROOT}/agents/<agent-name>.md" \
  --prompt-file <runDir>/<actionId>-prompt.md \
  --bundle <runDir>/bundle.json \
  --model <hostBinding.model> \
  --role <next.kind without dispatch- prefix> \
  --max-turns <hostBinding.maxTurns> \
  --output <runDir>/<role>-output-<attempt>.json \
  --meta <runDir>/<role>-host-meta-<attempt>.json
```

The wrapper runs a fresh Claude SDK query with the role's model and a host-enforced turn cap. For a pinned pull request, it starts in the reviewed worktree and refuses a mismatched commit. Its stdout lists read targets. Inspect unusually broad targets before launching another lane. It writes the raw member reply and host metadata, including actual turns, usage, and tool calls. The SDK result `error_max_turns` becomes raw host-failure output; never interpret it as a clean finding set.

Pass those files to the runtime unchanged:

```
node "${CLAUDE_PLUGIN_ROOT}/runtime/bin/cli.mjs" receipt \
  --state <runDir>/state.json --action <actionId> \
  --output <runDir>/<role>-output-<attempt>.json \
  --host-meta <runDir>/<role>-host-meta-<attempt>.json
```

Follow the returned `next` action for that lane, including the runtime's single retry. If the wrapper process fails before writing output, report the process error and stop that lane. When `next` reports `terminal: true`, run `result --state <runDir>/state.json --out <runDir>/result.json --evidence <runDir>/evidence.json` once. A lane that ended in a gap is still terminal; run `result` and let the Party report that gap. If no lanes were fielded, continue to step 7.

<HARD-GATE>
Never reorder or skip a stage. Never place two roles in one dispatch. Never change the member's output, invent a finding, or adjudicate a lane yourself. Each wrapper process gets only its own role, prompt, and staged artifact. Run `receipt` for every completed dispatch before acting on the next one.
</HARD-GATE>

## 7. Close the party

Once every fielded lane is terminal and has run `result`:

```
node "${CLAUDE_PLUGIN_ROOT}/runtime/bin/cli.mjs" party-report --party <partyRunId> [--keep-worktree]
# stdout: {partyRunId, reportPath, recordPath, blockers, gaps, lanes, cost:{bookedUsd, fullFlowUsd, omissions}}
```

The runtime has now written the report and the digested record: it verified that each lane's frozen bytes still match the snapshot, collected the usage envelopes, priced the run, and removed the pinned worktree. Pass `--keep-worktree` only when the operator wants to inspect it. A lane that failed comes back reported as a blocker with exit code 0; treat that as the run's result.

**Reporting happens once.** A second `party-report` on the same party is refused with `CLI_PARTY_ALREADY_REPORTED`; the command never rewrites recorded evidence. If more review is needed, that is a new party run (step 10).

Do not re-adjudicate, re-count, or re-word what the report says. It is the deliverable.

## 8. Place the report and summarize

**Copy the report from `reportPath` to where the operator will look for it.** Extract the ticket key (first `[A-Z]+-\d+` match) from the pull-request title (`code-pr`), the artifact path or its parent dir (`plan`/`doc`), or the branch name (`code-local`). Then:

- **Ticket found:** check for an existing ticket dir case-insensitively — `ls -d projects/active/* 2>/dev/null | grep -i "/<ticket>$"`. Reuse it if found; otherwise create `projects/active/<ticket>/` using the key as-extracted. Report path: `projects/active/<ticket>/reviews/<YYYY-MM-DD>-gauntlet-<artifact-type>.md` (`mkdir -p` the `reviews/` subdir; date from `date +%Y-%m-%d`).
- **No ticket** (ad-hoc doc, unticketed local diff): `scratch/gauntlet-<YYYYMMDD-HHMMSS>/report.md` (`date +%Y%m%d-%H%M%S`).
- **Collision:** if the dated path already exists, append `-2`, `-3`, … A re-review against an advanced head is its own party run with its own report — see step 10.

The runtime already recorded what was reviewed: the artifact type is in the report header, and the snapshot digest and the pinned commit for a `code-pr` are in the party record at `recordPath`. Do not re-derive the reviewed ref.

Confirm the copy landed — `wc -l <path>` returns at least 1 — before naming the path in chat. Evidence before assertion: never say "report written" without the check.

**Post a lean summary to chat**, not the report:

1. The verdict line: the blocker count from `party-report`, or `no blockers`.
2. Every blocker verbatim if there are any — a ship / do-not-ship call should not need the operator to open a file.
3. The report path, the cost line (`bookedUsd`, `fullFlowUsd`, and any `omissions`), and a one-line note that the full findings are in the file.
4. On a revision, the transition, read off `party-report`'s `revision.statuses` — for example `2 of 3 prior findings resolved · 1 persisting · 1 new`. The counts in the verdict line cover open rows only (`persisting`, `new`, `unverified`); resolved and withdrawn rows stay in the report, closed.

**The postable comment.** When the operator asks for something to post, run `node "${CLAUDE_PLUGIN_ROOT}/runtime/bin/cli.mjs" party-report --party <partyRunId> --format pr-comment` and show the operator the `commentPath` it prints. Security findings post like every other finding — claim, location, and fix — on every origin: a pull request is unreleased code, and its author is the one who can fix it. The stdout also carries `securityFindings`, every security-class row the comment holds (lane, id, tier, claim, file, line, location — the location fields only where the row has them), and `held`, which is `{security: 0, blockers: 0}` on this render. The runtime renders the whole comment — banner, box score, blocker callouts, findings table, machine-readable block, marker, footer — do not edit, re-word, or re-count it. For a non-pull-request artifact the operator pastes that file into the ticket.

**Posting to the pull request** is an outward-facing action. On a revision, before asking, say which of the two will happen: compare the prior party's last `post.json` receipt event with the verdict `party-report` just printed — on a revision the runtime updates the standing review in place when its event is unchanged, and when the event must change (blockers cleared, or blockers appeared) it dismisses a standing `REQUEST_CHANGES` review (a `COMMENT` review has nothing to dismiss), replaces that review's body with a one-line superseded note, and files a new review with the new event. Then, **only when `VISIBILITY` is `public` or was left unset in step 2, and `securityFindings` is not empty**, list those rows in chat, one line each as `<lane>/<id> · <tier> · <claim> · <location>`, and ask once: when `VISIBILITY` is `public`, `This repository is public. Hold these N security findings from the post? [y/N]`; when it was left unset, `This repository's visibility was not recorded, so it is treated as public. Hold these N security findings from the post? [y/N]`. Default is no: anything but `y` posts them. On `y`, add `--hold-security` to the `post` call below; the review event and the box score still come from the full set, so a held blocker still requests changes, and the comment carries a lock line naming the held count and pointing at the report file. A private origin never asks. Then ask: `Post the comment (held as answered above) to <repo>#<number>? [y/N]`. On `y`, run `node "${CLAUDE_PLUGIN_ROOT}/runtime/bin/cli.mjs" post --party <partyRunId>`, with `--hold-security` only when the hold question got a `y` in this exchange. Neither answer carries to the next post — ask both again every time. The runtime files or updates one pull-request review whose body is the comment — `REQUEST_CHANGES` with blockers, `COMMENT` without, and always `COMMENT` on a pull request the operator authored — and writes receipts to `post.json`; the receipt's `event` is the event the live review carries. A refusal (`CLI_POST_PENDING`, `CLI_POST_GH_FAILED`, `CLI_POST_ORIGIN_MISSING`, `CLI_POST_RECEIPTS_MALFORMED`) is surfaced verbatim, never retried. `post` is only ever run at the operator's say-so, each time.

## 9. Offer the gaps

A gap is a review lane that applies to this artifact but that the runtime does not yet run. `party-report` returns them as `gaps`; each carries a `lane` and the runtime's `reason`.

List every gap verbatim — lane and reason, no paraphrase — then offer each as a follow-up the operator can choose to run against the same artifact: the follow-up for a gap lane `<lane>` is `Skill: gauntlet:<lane>`. Skip the `go-live-review` offer when step 5 already settled it — the operator answered the question there, or passed `--go-live` / `--no-go-live`; still list the gap, do not offer it twice. If `Skill: gauntlet:<lane>` does not exist as a sibling skill (the sibling-name check in step 1 lists them), say so beside the gap instead of inventing a follow-up.

**Never dispatch a gap automatically.** Offer it and wait for the operator. A gap the operator declines is a known, recorded limit on this run's coverage: do not describe the run as complete coverage, and do not fold a follow-up's findings back into the runtime's report — that report is closed.

## 10. Re-reviewing an advanced head

A party run is frozen to the artifact it snapshotted, and its report is written once. When the head has moved since the last review, that is **a new party run** — start again at step 2 and form it exactly as there, with the same origin flags plus `--thread`. There is no append-to-the-old-report path.

The runtime does the linking: it finds the party it last posted for this pull request, fields the `revision-review` lane to rule on the fate of every open prior finding (`resolved`, `persisting`, `withdrawn`, or `unverified` — the verifier reads the thread, the range-diff, and the tree), folds duplicates into persisting rows by its dedup policy, and reviews only the delta unless `--full` was passed. A head the prior party already reviewed is refused (`CLI_REVISION_SAME_SHA`); surface it. Do not verify the author's "fixed" claims by hand and do not separate rebase artifacts yourself — the verifier lane and narrow mode do that, and the report says what they found.

What carries over is the discipline around the previous review:

- **Trust the thread for *intent*, the diff for *reality*** when reading the report. A `withdrawn` row names the reply it rests on; a `persisting` row names where the finding still lives.
- **State the transition in the chat summary** — step 8's `revision.statuses` line.
- **Posting on a re-review is still an outward-facing action.** Approval to post the first comment does not authorize the next one. Run step 8's questions again, saying first whether `post` will edit the standing review in place or refile it with a new event.

## 11. Recording a missed defect

When the operator says a reported party missed a defect — a reviewer, a later bug, or the operator's own reading found something the report did not — record it with `node "${CLAUDE_PLUGIN_ROOT}/runtime/bin/cli.mjs" escape --party <partyRunId> --lane <lane> --category <category> --note <text> [--ref <ref>]`: `--lane` is the Class that should have caught it, a Class key the runtime recognizes; `--category` is one of the runtime's finding categories; `--note` is one sentence saying what was missed; `--ref` is an optional pointer (a file:line, a commit, or a comment URL). The runtime appends the record to the party's `escapes.json` sidecar and prints the stamped record; it is only valid after `party-report` has run — `CLI_PARTY_NOT_REPORTED` is the refusal before that, and `CLI_INVALID_CLASS`, `ESCAPE_LANE_INVALID`, `ESCAPE_CATEGORY_INVALID`, `ESCAPE_NOTE_INVALID`, `ESCAPE_REF_INVALID`, `ESCAPE_SIDECAR_MALFORMED` are surfaced verbatim, never retried. Nothing in the runtime reads the sidecar back yet; it is evidence for a later measurement of which lane missed what. The skill never runs `escape` on its own, only when the operator names a miss.
