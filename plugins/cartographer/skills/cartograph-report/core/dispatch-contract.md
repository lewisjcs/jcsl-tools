# Dispatch contract — what a stage-5 verification dispatch must provide

Stage 5's two verification dispatches (accuracy, effectiveness) each
require a conforming dispatch: a way to run a fresh helper agent whose
whole world is the dispatch prompt. Any mechanism satisfying all five
of the following conforms; SKILL.md's Harness requirements section
names the mechanisms known to conform.

1. **Fresh context.** The helper starts with no memory of this
   conversation — it receives the dispatch prompt and nothing else.
   The drafting session's transcript, reasoning, and working files are
   not handed over.
2. **At most read-only access to the subject repository.** The
   dispatch prompt states each dispatch's permitted-input list (the
   accuracy dispatch reads the repository; the effectiveness dispatch
   reads only the artifact lines carried in its prompt). The mechanism
   must make repository writes impossible, or at minimum leave the
   detection rules of `core/claim-verification.md` § Isolation intact.
3. **The helper returns report content; it writes no files.** The main
   session receives the helper's records as returned content, writes
   `.cartographer/verification-report.md` itself, and runs the checker
   on it. A mechanism whose helper cannot write files satisfies this
   by construction; one whose helper could write must still route the
   report back as returned content only.
4. **Grammar-constrained report.** The returned content is the record
   grammar the dispatch prompt states (`core/claim-verification.md`
   RC-31, `core/effectiveness-verification.md` RC-35). The main
   session validates the written artifact with
   `check-verification-report.sh`; a mechanism that can additionally
   enforce a response schema on the helper's final message may layer
   that on top.
5. **Failure stops the run.** A dispatch that cannot be launched,
   returns nothing, or returns malformed content is a stage-5 failure
   handled by SKILL.md's stage-5 branches — never a silent skip, and
   never a fallback to running verification in the main context.

One property, noted but not required: a mechanism that can run the
helper on a different model family than the drafting session adds
cross-model independence to verification. Nothing in this pipeline
depends on it.
