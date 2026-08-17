# README Section Necessity

TL;DR: a drafted README section earns its place only if removing it would
leave the agent with no other way to learn something it needs. Concrete
sections default to inclusion; generic overview sections must justify
themselves before Cartographer drafts them.

## The litmus test

A drafted section stays only if removing it would cause an agent to
violate a repo constraint it has no other way to learn; otherwise it does
not. <!-- see: references/readme-scope.md#the-agentsmd-inclusion-litmus-test -->
Apply the test to every candidate section before drafting it, not after
drafting has produced prose worth defending.

## Concrete sections default to inclusion; generic sections must earn it

Concrete, actionable content is well followed by coding agents and passes
the litmus test by default. Generic repository overviews are popular and
often recommended, but must justify their inclusion explicitly rather than
riding in on a conventional section name. <!-- see: references/readme-scope.md#concrete-instructions-succeed-generic-overviews-do-not -->

## Inclusion has a real cost

Every included section raises inference cost without reliably raising
task success. Never include a section on the strength of "the section
name is conventional" alone. <!-- see: references/readme-scope.md#repository-context-files-null-result-on-task-success-positive-cost -->

## Bloat and misplacement are hard failures, not style choices

Content discoverable elsewhere — script enumerations, build commands
already in a manifest, file-structure listings, setup steps already in
CONTRIBUTING — must never appear in a drafted section. <!-- see: references/readme-scope.md#bloat-and-misplaced-content-are-hard-failure-classes-not-style-choices -->

## Verification check

Before drafting any section, answer in writing: does removing this
section deprive the agent of something it has no other way to learn?
Record the specific constraint for a "yes," or drop the section and log
the gap. A section with no recorded "yes" does not ship.
