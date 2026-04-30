---
sidebar_position: 1
title: Roadmap
---

SaveFlow Lite is moving toward a stable 1.0 baseline.

## Lite Roadmap

- `0.7.x`: template/demo cleanup and documentation-site foundation.
- `0.8.x`: API freeze beta.
- `0.9.x`: release-candidate bug fixing, testing, and packaging validation.
- `1.0.0`: stable Lite release.

## Lite Boundary

Lite owns:

- baseline Save Graph model
- explicit source ownership
- slot metadata and active slot workflows
- editor diagnostics and authoring warnings
- baseline C# parity
- practical Godot templates and examples

Pro owns:

- staged restore orchestration
- migration/version tooling
- storage profiles
- cloud sync and conflict handling
- reference repair
- seamless/background save performance workflows

## Current 0.8 Focus

0.8.x is the API-freeze beta line.

The current focus is:

- make runtime entity authoring and restore diagnostics stable
- keep editor preview wording aligned with runtime restore issue codes
- preserve compatibility for the public `SaveFlow` and Source APIs
- finish small documentation and naming corrections before release candidates
- avoid adding broad Lite-only orchestration features that belong to Pro

This work matters because 0.9 should be mostly bug fixing, testing, and
packaging validation.
If a Lite workflow still needs a public name or a clearer diagnostic, it should
be handled in 0.8 before the release-candidate line begins.
