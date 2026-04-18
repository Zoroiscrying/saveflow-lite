# SaveFlow Lite Roadmap

This document defines what should continue to improve in `SaveFlow Lite`.

The goal is not feature flood.
The goal is:

- cleaner first-time adoption
- fewer integration mistakes
- stronger baseline reliability
- clearer project-level save configuration

## Lite Product Rule

`Lite` should own:

- the base save graph model
- the main user-facing entry points
- the cleanest possible default workflows
- the baseline reliability users need to trust the product

`Lite` should not try to compete with `Pro` by piling on advanced commercial features.
It should get better by becoming:

- clearer
- safer
- easier to configure
- easier to debug

## Main Lite Update Lines

### 1. Entry Path Polish

Continue refining:

- `SaveFlowNodeSource`
- `SaveFlowDataSource`
- `SaveFlowEntityCollectionSource`
- `SaveFlowScope`

Goals:

- fewer misconfigurations
- less hidden behavior
- better inspector guidance
- clearer defaults

### 2. Unified Save Settings Panel

This is now a key Lite roadmap item.

Target problem:

- project-level save settings are currently spread across code, autoload behavior, and per-source decisions
- users need one obvious place to manage global save defaults

Lite should add a unified settings surface for things like:

- save format
- default slot behavior
- version metadata
- save-file metadata
- backup policy at the project level
- editor-facing project save settings

The panel should make it easier to answer:

- what format does this project save with?
- what version is the current save schema?
- what metadata is stored with save files?
- what global save defaults are active?

This belongs in Lite because:

- it improves baseline product clarity
- it reduces configuration sprawl
- users expect a save plugin to expose these basics in one place

### 3. Inspector and Diagnostics

Continue improving editor-facing guidance:

- better source previews
- stronger configuration warnings
- clearer failure messages
- runtime diagnostics when practical

This should help users understand:

- what will be saved
- what failed to resolve
- what restore policy is active
- what global settings apply

### 4. Common Built-In Support

Continue adding carefully selected built-ins for common Godot nodes.

Priority should stay on:

- high-frequency nodes
- obvious state value
- meaningful reduction in handwritten source code

### 5. Documentation and Template Quality

Keep improving:

- shorter integration paths
- clearer examples
- smaller templates
- better decision maps

Lite should continue to be the easiest way to understand the SaveFlow model.

### 6. Core Reliability

These always stay in Lite/Core:

- correctness fixes
- better defaults
- safer restore behavior
- clearer editor/runtime warnings
- consistency improvements

These are not premium features.

## Suggested Lite Release Direction

### Lite v0.2

Recommended focus:

- unified save settings panel
- inspector polish
- more diagnostics
- a few high-value built-ins

### Lite v0.3

Recommended focus:

- stronger project-level save configuration UX
- better preflight checks
- more polished templates and examples

## What Lite Should Explicitly Avoid

Do not overload Lite with:

- advanced reference resolution
- migration frameworks
- multithreaded seamless save pipelines
- high-complexity orchestration systems
- premium delivery/security profiles beyond the baseline

Those are better left to `Pro`.
