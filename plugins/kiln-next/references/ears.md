# EARS authoring reference

Every requirement and acceptance line the Designer or the Planner writes uses one of these five sentence patterns. This is an authoring reference, not a theory of requirements.

## The five patterns

| Pattern | Template | Use |
|---|---|---|
| Ubiquitous | `The <system> shall <response>` | an always-true constraint |
| Event-driven | `When <trigger>, the <system> shall <response>` | happy-path triggered behavior |
| State-driven | `While <state>, the <system> shall <response>` | a precondition or a duration; most non-functional lines |
| Unwanted behavior | `If <condition>, then the <system> shall <response>` | error and fault paths only |
| Optional feature | `Where <feature included>, the <system> shall <response>` | flag-gated or optional behavior |

`If … then` is reserved for unwanted behavior (errors, invalid input, limits exceeded); `When` is the happy path. A line that needs both a state and a trigger reads `While <state>, when <trigger>, the <system> shall <response>`: state before trigger, never reversed.

## Where the lines go

EARS is a sentence style, not a document skeleton. In a decision file the requirements section is EARS bullets; the context, the excluded scope, and the open questions are prose. In a ticket plan every task's `goal` is one EARS line and every `covers` entry quotes one requirement line from the decision file verbatim.

## No invented scope

When absorbing a thin ticket, move its intent into the prose sections and derive testable lines from it, but never manufacture a requirement the source does not support. Mark any line not directly grounded in the source as `(proposed — confirm)` so it is caught at the design gate. If the source is too thin to ground any line, that is a design question for the person, not a licence to invent. Quote the ticket's own goal verbatim in the first section so no later step works from a paraphrase.

## Self-review before writing the file

Refuse your own line when it has any of these:

- a vague response ("appropriately", "correctly", "as needed")
- more than one independent `shall`, or more than one system named: split it
- a non-trigger ("when needed")
- no observable assertion a reader could test
- passive voice with no system as the subject
- a mechanism where a behavior belongs (the line says how, not what)
- `When` on a fault path (use `If … then`)
- `when … while …` reversed
- a duplicate of another line
- more words than the template needs
