<!-- Reference asset embedded into the threat-review Class. Host-neutral; the canon-purity sweep applies. -->

# Threat disproof playbook

One section per lens of the threat-review code-diff profile. Each section lists the checks that most often kill a false positive of that kind and the checks that most often confirm a true one. The Validator reads the section for a candidate's lens before ruling; the Finder may read it to avoid the commonest false positives but never to withhold a traced path.

Four causes account for most security false positives in tool-assisted review: an unreachable source, an unrecognised sanitiser, a disabled or absent context, and a missing privileged precondition. Every section below starts from those four.

## New input reaches a sink

Kills:

- The source is not untrusted: the value comes from a constant, a build-time file, the operator's own configuration, or a typed enum. Cite where it is set.
- A sanitiser or encoder sits on the path and is not visible from the diff: a parameterised query builder, an escaping template engine, a path normaliser followed by a prefix check, an allow-list. Cite it by line and confirm it covers the sink's grammar (an HTML encoder does not protect a shell).
- The "sink" is safe by construction: a JSON parser, a query builder that binds parameters, a filesystem call that takes a file descriptor not a path.
- The regex is anchored and bounded, or the input reaching it has a length cap on the path; a nested quantifier on bounded input is not catastrophic.

Confirms:

- The sanitiser is for the wrong grammar, is applied before a transformation that undoes it, or is bypassed by one branch.
- The sink is string-concatenated (`shell`, SQL, LDAP, a path join with `..` unchecked) and the Finder's cited entry point is a request field, file content, environment, or tool output.
- A test in the tree exercises the path with a hostile value and the guard is absent from what it exercises.

## Access decision changed or bypassed

Kills:

- The check the Finder says was removed still runs earlier on the path (middleware, a decorator, a router-level guard); cite it.
- The reordered action is idempotent and side-effect free before the check runs (a read of public data).
- The "caller-controlled host" is validated against an allow-list, or the client refuses redirects and private ranges; cite the guard.
- The framework guarantees the check (a route registered under an authenticated group, a typed principal that cannot be null).

Confirms:

- The check that used to run no longer runs on at least one path, or runs after a write, a send, or a fetch.
- A tenancy or ownership comparison was dropped, widened, or now uses a caller-supplied identifier without binding it to the session.
- The upstream guarantee offered as disproof lives in another system you cannot read from here; the finding survives with that named.

### Worked borderline case

A command-line tool takes a configuration path from its own argument and opens it. The Finder files a path-traversal finding that presupposes a caller who supplies a hostile path. Under `single-user-tool` the only caller is the operator, who can already open any file on that machine: kill it with `trust-model`, and name the context in `evidence`. Under `agent-tool`, ask where the argument comes from: if it is assembled from content the tool read (a fetched page, a pull-request thread, a tool result), the same path is in scope and the finding survives, because the less-trusted party is that content, not a second human. Under `multi-caller-service` it survives. The value this check keys on is the bundle's `trust-context` component, never the Finder's guess or yours about how the code is deployed.

## Secrets and sensitive data flow

Kills:

- The literal is a placeholder, a test fixture, a public key, or a documented example, and no runtime path reads it as a credential.
- The logger redacts by key name or the value is hashed or truncated before the write site; cite the redaction.
- The logged object is a typed structure that cannot carry the field the Finder names.
- The identifier is internal and non-sensitive (a row id, a build number).

Confirms:

- A credential-shaped literal is assigned and read on a runtime path.
- An error message or log line writes a whole request, response, token, or environment, and the redaction the author expects is by value not by key, or is applied downstream of the write.
- Personal data appears in a response or log where the previous state carried only an identifier.

## Cryptography and randomness

Kills:

- The randomness is not security-bearing (a jitter, a shuffle, a display id) and nothing derives a token, a key, or a nonce from it.
- The algorithm is used for integrity of data the same principal wrote and reads, not for authentication across a trust boundary.
- The verification the Finder says is optional is enforced by the library's default or by a type that cannot be constructed without it; cite it.

Confirms:

- A token, session id, reset code, or nonce derives from a non-cryptographic generator.
- A nonce or key is reused across messages or a key is derived from a low-entropy input without stretching.
- Signature or MAC verification can be skipped by a flag, a missing header, or an error path.

## Dependencies, pipeline, and executed code

Kills:

- The dependency change is a version bump of an existing pinned package with no new install script, no new resolution source, and no unpinned range; cite the manifest and lockfile lines.
- The workflow trigger is not privileged (`pull_request`, not a target-checkout trigger), or the job that checks out untrusted code has read-only permissions and no secrets; cite the permissions block.
- The container image is pinned by digest, or the "root" user is replaced before the entrypoint; cite the line.
- The dynamic import is over a fixed table of module names, not over data.

Confirms:

- A new package, an install-time script, a resolution that leaves the registry, or a range that lets the next install pick an unreviewed version.
- A workflow that checks out a fork's head under a privileged trigger, or a job with write-all permissions or secrets reachable from a fork run.
- A download piped to an interpreter, an unpinned image, a permissive cross-origin or content-security policy, a debug or admin surface enabled in a non-development configuration.

## Fail-open under exceptional conditions

Kills:

- The catch re-raises, returns a refusal, or sets a state that the caller treats as denied; cite the branch's effect.
- The guard the Finder says is stale was updated in the same change, or the widened domain is still rejected by a later typed check; cite both.
- The prose-matched decision is co-required with an invariant test in the tree; cite the test.

Confirms:

- An error path skips a check and continues to the action.
- A validity domain was widened (a new enum value, a new format, a new range) and a guard elsewhere still assumes the old domain, so a new value passes a check written for the old one.
- A safety decision keys on matching prose (a regex over a message, a keyword in a title) with no invariant test beside it, so rewording defeats it.

## Agent surface

Kills:

- No untrusted party can reach the instruction position: the prompt is assembled from operator-owned files only, the tool description is static, the memory is written only by the operator.
- The grant is exactly the role's task (a read grant over the reviewed tree for a reviewer) and the manifest enforces it.
- The fetched or artifact content is treated as data: it is fenced, never executed, and the role is told to treat instructions inside it as content to review.

Confirms:

- Content from a fetched page, a pull-request thread, a server's instruction block, a tool result, or a reviewed file reaches a prompt, a tool description, a memory file, or an inter-agent message without a fence and a rule.
- A role receives a write grant, a network grant, or a path grant wider than its task.
- State written from untrusted content is read back later as trusted (a memory, a cache, a summary file), or a server-supplied instruction is followed rather than reviewed.
