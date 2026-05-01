---
sidebar_position: 1
title: Roadmap
---

SaveFlow Lite is now on its stable 1.0 baseline.

## Lite Roadmap

- `0.7.x`: template/demo cleanup and documentation-site foundation.
- `0.8.x`: API freeze beta, now closed.
- `0.9.x`: release-candidate bug fixing, testing, and packaging validation, now closed.
- `1.0.x`: stable Lite baseline and compatibility-focused patch releases.

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

## Current 1.0 Focus

1.0.x is the stable Lite line.

The current focus is:

- preserve compatibility for the public `SaveFlow`, Source, and C# wrapper APIs
- keep runtime diagnostics, editor preview wording, and reference docs aligned
- validate install, upgrade, and release package shapes before each release
- fix bugs, cold-start regressions, and documentation mismatches found after the stable baseline
- avoid adding broad Lite-only orchestration features that belong to Pro

This work matters because 1.0.x should remain a confidence line, not a surprise
feature line. If a public API issue is found in 1.0.x, it should be fixed only
when the compatibility tradeoff is smaller than shipping the mistake.
