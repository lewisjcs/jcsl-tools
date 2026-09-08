# threat-review lenses — code-diff

Applies when the artifact-family profile supplied for this run is `jcsl:artifact-family:code-diff`. Read this alongside the two personas and the grounding contract. The lenses are organised by where the diff creates new trust, not by vulnerability taxonomy; the methodology is the path requirement in the Finder persona, and this list is coverage. Each lens says what to trace, what counts as evidence, and what is out.

## Finder application

### Post-image anchoring

Before emitting a finding, confirm its evidence appears on the `+` (post-image) side of a hunk, or on an unchanged line the change newly exposes. A finding whose only supporting evidence is on the `-` (pre-image) side describes code the change removes; do not emit it.

### New input reaches a sink

Trace untrusted data (request fields, file contents, environment, tool output, artifact content) newly flowing to a command, a query, a filesystem path, a template, a deserialiser, an `eval`-class call, or a regex with backtracking on unbounded input. Evidence: the call chain with lines from the entry point to the sink. Out: validation gaps with no sink named.

### Access decision changed or bypassed

Trace authentication, authorization, session, or tenancy checks that were added, moved, removed, reordered, or made skippable, and server-side requests to caller-controlled hosts. Evidence: the check that used to run and no longer does, or the order that lets the action precede the check, cited by line. Out: hardening suggestions where no decision changed.

### Secrets and sensitive data flow

Trace secrets in source, secrets or full payloads written to logs or error messages, and personal data broadened in a response or a log line. Evidence: the write site and what reaches it. Out: internal identifiers with no sensitivity.

### Cryptography and randomness

Trace weak or misused algorithms, reused nonces or keys, non-cryptographic randomness used for a token or a secret, and verification that is skipped or made optional. Evidence: the call and the use that makes it security-bearing. Out: algorithm preferences where the use is not security-bearing.

### Dependencies, pipeline, and executed code

Trace new or changed dependencies, lockfile drift the manifest does not explain, install-time scripts, download-and-execute, unpinned versions, and dynamic module loading from data. Trace the configuration that decides what runs with what authority: a workflow that checks out a fork's head under a privileged trigger, write-all permissions or secrets reachable from fork runs, a container running as root or pulling an unpinned image, a permissive cross-origin or content-security policy, a debug mode or admin endpoint left on. Evidence: the manifest, lockfile, workflow, or container lines and where the code runs. Out: a version bump of an existing pinned dependency with no script or resolution change.

### Fail-open under exceptional conditions

Trace error paths that skip a check, catch-and-continue around a control, a validity domain widened while an older guard still gates the value, and a safety decision made by matching prose with no invariant test beside it. Evidence: the branch and the check it bypasses. Out: error handling with no control in the path.

### Agent surface

Trace untrusted content reaching an instruction position (a prompt, a tool description, memory, an inter-agent message), a tool or path grant wider than the role's task, artifact or fetched content that gets executed, state written from untrusted data and read back as trusted, and a server-supplied instruction that is followed. Evidence: the file that grants or the line that reads. Out: agent design preferences where no untrusted party can reach the position.

### Deliberately outside a diff review

Insecure design and missing audit logging on an access decision both need the whole system in front of the reviewer, not the change. Do not emit them.

### Location format

`file:line`, a repo-relative path in the reviewed tree plus a line number.

- Findings in changed files: the post-diff source file path and line. Cite the `+` side of the hunk, or the surviving `+` lines when a hunk both removes and adds. Get the path from the component's own header; each component is introduced by a `--- component: <id> (role: ..., mediaType: ..., path: <path>) ---` line, and when the header states a `path`, use it verbatim.
- Cross-boundary findings (evidence in files the diff does not change): the file's repo-relative path in the reviewed tree, exactly as you read it. Cite only files you actually opened; never infer or invent a path.
- Only when a component's header carries no `path`, fall back to `(<component id>):line` instead of inventing one.

## Validator disproof strategies

Apply the four ordered checks in the Validator persona (reachability, the control the Finder missed, the empirical check, the trust model) to every candidate. The disproof playbook embedded with this Class lists, per lens, the checks that most often kill a false positive of that kind and the checks that most often confirm a true one; consult its section for the candidate's lens before ruling.

### Grounding-quality adjudication

Self-consistency is not evidence. When a candidate's reasoning is internally coherent but its grounding points at the wrong artifact state (the `-` side of a hunk, an installed-not-declared dependency version, or a file or line absent from the post-change artifact) that mis-grounding is itself a disproof basis: mark the candidate `disproved` with `killedBy: grounding` and name the wrong-state grounding in `evidence`.

### False-positive rules

Findings that recommend any of the following against typed values are false positives by team convention (see the code-quality standards embedded with this Class): adding null or undefined guards where the type system already excludes them, wrapping framework operations in defensive try/catch, backwards-compatibility shims for unreleased breaking changes, or validation at internal boundaries. Mark them `disproved` with `killedBy: convention`. A security finding is not exempt from these rules; a guard the type system makes unreachable protects nothing.
