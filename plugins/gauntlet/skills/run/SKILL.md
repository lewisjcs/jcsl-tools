---
name: gauntlet
description: Use when running the full review Party over one artifact — a pull request, a local diff, a plan, a doc, a skill, or an agent-instruction file. The canonical PR-review surface — "review this PR" routes here. Trigger phrases include "review this PR", "review PR <number>", "review the PR", "review this", "run the gauntlet", "do a full review", "fully review", or any natural-language variation requesting a full review of an artifact. When NOT to use: for a single-lane review invoke the corresponding sibling directly (threat-review, code-quality-audit, adversarial-review, plan-review, doc-review, skill-audit, directive-review).
argument-hint: "[<pr-url> | <path>] [--type <type>] [--full] [--go-live] [--no-go-live] [--force-lane <class>] [--skip-lane <class>]"
---

# Gauntlet

A thin host over the Party runtime. The runtime decides what this review is and who reviews it; this skill fetches the artifact, performs the dispatches the runtime asks for, and places the report the runtime wrote.

The runtime owns every decision that used to live here: what type of artifact this is, which review lanes to field (the roster — the set of lanes the runtime decided to run), where the artifact snapshot is frozen, how findings across lanes are adjudicated and de-duplicated, and what the report says. Do not re-derive any of it. When the runtime refuses something, surface the refusal — never work around it.

The skill's whole job is the eleven steps below, in order.

## Usage

```
/gauntlet https://github.com/<org>/<repo>/pull/<n>   — a pull request (code diff)
/gauntlet                                            — the local branch diff
/gauntlet <path-to-file.md>                          — a plan, doc, skill, or agent-instruction file
```

One artifact per run. The runtime reviews one file per party run and refuses a directory (`CLI_PARTY_DIRECTORY_INPUT`) — to review several files, run the skill once per file.

**When NOT to use:** a single-lane review (invoke `gauntlet:threat-review`, `gauntlet:plan-review`, `gauntlet:doc-review`, `gauntlet:adversarial-review`, `gauntlet:code-quality-audit`, or `gauntlet:skill-audit` directly). Designing an artifact rather than checking one — brainstorm first; the gauntlet is the quality pass on the result.

## 1. Preflight

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
gh repo view <owner>/<repo> --json visibility --jq .visibility
```

Write the `title` value to `"$STAGE/pr-title.md"` and the `body` value to `"$STAGE/pr-body.md"`. Set `AUTHOR=self` when `author.login` equals the `gh api user` login, else `AUTHOR=other`. When `gh repo view` succeeds, lower-case its result to set `VISIBILITY` (`PUBLIC` → `public`, any other value → `private`): the runtime holds security findings from the posted comment on a public repository, so this is a fielding input the operator never edits. When it fails, leave `VISIBILITY` unset and tell the operator in chat: the runtime treats an unrecorded visibility the same as a public one, so it will hold security findings from any comment on this artifact.

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

When `revision` is not null, the runtime linked this party to an earlier posted one. Add a line under the roster: `revision <number> of <priorPartyRunId> · narrow|full`, and when the mode is `full` without the operator asking for it, append the runtime's `fallbackReason`. In `narrow` mode the verifier lane reads a range-diff against the prior head and the other lanes read the pull-request diff scoped to the files the push touched (`revision.files`); do not re-derive or second-guess the mode.

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

## 6. Drive each fielded lane

Run the lanes **one at a time**, in the order `lanes` gives them. Each lane already has its own run directory with `bundle.json` staged by `party-form` — stage nothing yourself, and never create a run directory.

Some artifacts field no lanes at all: a skill file and an agent-instruction file have no admitted Class today, so their whole roster is gaps. When `lanes` is empty there is nothing to drive — go straight to step 7, and let step 9 offer the gaps.

```
node "${CLAUDE_PLUGIN_ROOT}/runtime/bin/cli.mjs" init --bundle <runDir>/bundle.json --family <family> --host claude-code --class <classKey> --out <runDir>/state.json
# stdout: {issues, next, hostBinding} — next is the pending action or {terminal: true}; hostBinding is {agent, model} or null once terminal
# loop while next.terminal is not true:
#   Agent tool: subagent_type = hostBinding.agent, prompt = next.promptBody verbatim
#   role key = next.kind with the leading "dispatch-" removed (finder, validator, auditor, verifier, …)
#   write <runDir>/<role>-output-<attempt>.json (raw) and <runDir>/<role>-host-meta-<attempt>.json = {"modelBinding": {"<role>": {"model": hostBinding.model}}, "usage": {"inputTokens", "cacheWriteTokens", "cacheReadTokens", "turns": <summed from the dispatch transcript, see below>, "latencySeconds": <wall seconds>}}
#   receipt --state <runDir>/state.json --action next.actionId --output <raw> --host-meta <meta>   → prints the same {issues, next, hostBinding} shape
node ... result --state <runDir>/state.json --out <runDir>/result.json --evidence <runDir>/evidence.json
```

**`--family` takes the prefixed form.** `init` wants the value `bundle.json` records as `artifactFamily` — `jcsl:artifact-family:code-diff`, not the bare `code-diff` that the lane's `family` field carries. Read it off `<runDir>/bundle.json`. Passing the bare id is a hard refusal, not a warning.

**Which agent for which action.** The runtime names it: every `init`, `next`, and `receipt` reply carries `hostBinding.agent`, the `subagent_type` to dispatch, and `hostBinding.model`, the model that agent is bound to. Dispatch to exactly that agent and pass `next.promptBody` verbatim; never paste artifact content into a prompt yourself — the prompt already tells the agent to read the artifact from the run directory — and never pick an agent from memory: a lane you have not seen before is just a lane whose binding you read off the reply.

**Host metadata on every receipt.** Always pass `--host-meta`. The role key is `next.kind` without its `dispatch-` prefix. Record `hostBinding.model` as the model — it is the same value the agent file pins, read from the bindings the runtime loaded; the Agent tool does not report which model ran, so the pinned value is the only measurable one. Where the dispatch also pins a reasoning effort, record it in the same object under `reasoningEffort`. Add a `usage` object (`inputTokens`, `cacheWriteTokens`, `cacheReadTokens`, `turns`, `latencySeconds`) — no `outputTokens`, see below. The Agent tool's own result reports one unsplit token total, which the pricer cannot use; the real split is in the dispatch's transcript. Each Agent call writes `<config-dir>/projects/<project-slug>/<session-id>/subagents/agent-<agentId>.jsonl`, where `agentId` is the id the Agent tool result names — read the split from there:

```
jq -s '[.[] | select(.type=="assistant")] | group_by(.message.id) | map(last)
  | {inputTokens: (map(.message.usage.input_tokens)|add), cacheWriteTokens: (map(.message.usage.cache_creation_input_tokens)|add), cacheReadTokens: (map(.message.usage.cache_read_input_tokens)|add), turns: length}' <transcript>
```

The `group_by(.message.id) | map(last)` step is load-bearing: a transcript records several `assistant` lines per message as the reply streams in, each carrying that message's usage so far, and summing every line over-counts the lane two to three times. Keep the last line per message id. Pass the three split fields exactly as the query prints them; the pricer reads them unchanged. **Never record `outputTokens`.** A subagent transcript carries only the stream-start placeholder for `output_tokens` (a single-digit count on a message thousands of characters long), and no other host source has the final figure — the Agent tool reports one unsplit total, and transcript-reading tools such as ccusage sum the same placeholder. Leave the field out: the pricer books zero for output and the report's cost block lists `outputTokens` as unavailable for that role — the honest figure. Only when the transcript cannot be found do you fall back to the Agent tool's total, recorded as `totalTokens` in the same `usage` object with the split fields left out — never guess a split. A metric you cannot measure is left out — the runtime records it as a named omission rather than a guess, and a run with no `modelBinding` receipt produces an unverifiable evidence record.

**Run `result` once `next` reports `terminal: true`**, at the exact paths above — `party-report` (step 7) reads a lane's findings from `<runDir>/result.json`, so a result written anywhere else leaves the lane unreadable and the party reports it as failed. A lane that ended in a gap is still terminal: run `result` anyway and move to the next lane. Do not retry it, do not substitute a lane, and do not stop the party — step 7's report renders a failed lane as a blocker on its own.

<HARD-GATE>
The host never reorders, collapses, or skips a stage; never decides whether a second Finder or Validator pass runs; and never invents, drops, or re-labels a candidate or verdict ID. One dispatch per Agent call — never the Finder and the Validator from a single call. Each dispatch is a fresh, isolated context with no shared history and no visibility into the other role's reasoning. Do not adjudicate, filter, re-rank, or re-severity anything: adjudication is the runtime's job, not the host's. Do not skip `receipt`, and do not infer a result before `next` reports `terminal: true`. An out-of-order, substituted, stale, or wrong-digest receipt is a typed refusal the runtime raises itself — surface it; never work around it or retry outside the runtime's own one-retry-per-stage rule.
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

**The postable comment.** When the operator asks for something to post, run `node "${CLAUDE_PLUGIN_ROOT}/runtime/bin/cli.mjs" party-report --party <partyRunId> --format pr-comment` and show the operator the `commentPath` it prints. The stdout also carries `held`; when `held.security` is above zero, list under a `Held from the comment` heading in chat every row of the report file's `## Findings — threat-review` section, verbatim (that lane's findings carry the security category, and its uncategorized rows are held too), say they were held because the repository is public or its visibility was not recorded, and offer `--include-security` as a separate, deliberate choice — never pass it without the operator saying so in that exchange. If the number of rows listed differs from `held.security`, say so and point the operator at the report file rather than guessing which other row was held; do not re-run `party-report` with `--include-security` to produce the listing — that overwrites `commentPath`. The runtime renders the whole comment — banner, box score, blocker callouts, findings table, machine-readable block, marker, footer — do not edit, re-word, or re-count it. For a non-pull-request artifact the operator pastes that file into the ticket.

**Posting to the pull request** is an outward-facing action. Ask the operator: `Post this comment to <repo>#<number>? [y/N]`, followed, only when `held.security` is above zero, by `Include the N held security findings? [y/N]`. On `y` to the first, run `node "${CLAUDE_PLUGIN_ROOT}/runtime/bin/cli.mjs" post --party <partyRunId>`, adding `--include-security` only when the second question also got a `y`; an `n` to the second runs `post` without it. Approval to include held findings on one post does not carry to the next — ask again every time `held.security` is above zero. The runtime files or updates one pull-request review whose body is the comment — `REQUEST_CHANGES` with blockers, `COMMENT` without, and always `COMMENT` on a pull request the operator authored — and writes receipts to `post.json`. On a revision the runtime updates the standing review in place when its event is unchanged. When the event must change — blockers cleared, or blockers appeared — it dismisses a standing `REQUEST_CHANGES` review (a `COMMENT` review has nothing to dismiss), replaces that review's body with a one-line superseded note, and files a new review with the new event. Before asking, say which of the two will happen: compare the prior party's last `post.json` receipt event with the verdict `party-report` just printed. Either way the receipt's `event` is the event the live review carries. A refusal (`CLI_POST_PENDING`, `CLI_POST_GH_FAILED`, `CLI_POST_ORIGIN_MISSING`, `CLI_POST_RECEIPTS_MALFORMED`) is surfaced verbatim, never retried. `post` is only ever run at the operator's say-so, each time.

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
- **Posting on a re-review is still an outward-facing action.** Approval to post the first comment does not authorize the next one. Run step 8's question again, saying first whether `post` will edit the standing review in place or refile it with a new event.
