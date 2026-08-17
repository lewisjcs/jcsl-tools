# Contentful profile

This directory is intentionally code-free in Slice 1. It exists as a placeholder for
the Contentful-specific profile that later slices add on top of the plugin's core
pipeline (`plugins/cartographer/core/`).

Later slices add here:
- **Slice 2** — the profile's claim-source adapters and any Contentful-specific
  grounding rules layered on top of the core evidentiary conventions.
- **Slice 3** — profile-specific README section handling that the core pipeline
  delegates to.
- **Slice 4** — end-to-end wiring so the profile can be invoked against a real
  Contentful repository.
