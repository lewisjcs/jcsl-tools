# Architecture reference

The Designer's architecture and AI engineering lenses. Questions per phase. A checklist to draw from, not a form to fill.

## Frame

- What is the unit of change: a module, a service, a contract, a runtime, a prompt?
- Which boundaries does it cross: process, repository, team, trust, network?
- What must not change: a public contract, a stored format, a pinned dependency, a cost cap?
- What does "wrong" look like here, and who feels it first?

## Diverge

- Where else could this responsibility live? Name the option that moves it up a layer and the one that moves it down.
- What if the change were data instead of code, or code instead of data?
- What if the runtime decided instead of a model, or a model instead of the runtime?
- What is the smallest version that proves the shape, and the version that removes a piece instead of adding one?

## Provoke

- **Data flow.** Trace one request end to end. Where does data enter, where is it trusted, where is it acted on? Which hop has no check?
- **Failure modes.** What happens on a partial write, a stale read, a retry, a duplicate, a missing input, a slow dependency? Which failure is silent?
- **Blast radius.** If this ships wrong, how many callers, users, repos, or teams feel it? Is a revert enough, or does state have to be repaired?
- **Coupling.** What must move together when this moves? What breaks two hops away?
- **Cost.** Per call, per run, per month. Fixed against variable. What the cap is and who watches it.
- **Model in the loop.** What is the model trusted to decide? What checks its output before anything acts on it? What evidence proves it worked? What is the deterministic floor when it is wrong?
- **Replay.** Can the decision be replayed on the same input later and give the same answer? If not, what records why it answered as it did?

## Converge

- One sentence per ruling in the person's words. Each ruling names what it forecloses.
- The interfaces between parts: names, shapes, and who owns each.
- The verification policy: which checks, run by whom, before what.
- The migration: what exists today, what changes, what stays compatible, what is deleted.

## Capture

- Ships and does not ship, against the map that set the scope.
- Every requirement as an EARS line. Every design section cites the ruling it serves.
- Build-time items: the facts a builder must settle first, named as facts, not tasks.
