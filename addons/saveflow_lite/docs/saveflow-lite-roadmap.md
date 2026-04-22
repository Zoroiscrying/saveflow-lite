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

### 6. Business-Facing Save Workflow

Lite should keep improving the parts a real game team touches every day, even
when those needs are not "advanced orchestration".

Priority tracks:

- slot summary and in-game save list workflows
- autosave and checkpoint integration patterns
- slot metadata normalization for real game UI and QA usage

These belong in Lite when they stay within:

- one local save profile
- explicit slot metadata
- explicit save/load entry points
- no migration framework
- no cloud conflict system
- no staged multi-scene scheduler

#### 6.1 Slot summary and in-game save list

Target problem:

- game UI often needs to list saves without loading the full gameplay payload
- QA and designers need fast visibility into which slot is which
- slot rows usually need chapter, map, playtime, difficulty, save type, and similar summary fields

Lite should move toward:

- lightweight slot-summary reads
- a documented slot-summary schema
- a clear split between slot metadata and full save payload
- examples for building an in-game continue/load screen from slot metadata

Recommended Lite acceptance bar:

- a game can render a save list without loading full gameplay state
- slot summary reads are explicit and stable
- compatibility and slot safety can be surfaced in game UI, not only in editor tools

#### 6.2 Autosave and checkpoint integration

Target problem:

- real games save from gameplay events, not only from manual debug actions
- teams need a clean pattern for door transitions, checkpoints, settings changes, and return-to-menu saves
- save requests often need basic gating such as "scene is stable", "combat is not interrupting", or "restore target is valid"

Lite should move toward:

- recommended autosave trigger patterns
- a minimal checkpoint workflow
- guidance for "when a game should refuse to save right now"
- examples that keep autosave orchestration simple and local to gameplay code

Recommended Lite acceptance bar:

- users can wire autosave/checkpoint events without inventing a private save architecture first
- the docs explain when to call `save_scene()`, `save_scope()`, or `save_data()`
- the baseline pattern stays explicit and does not pretend to be a full background-save scheduler

#### 6.3 Slot metadata for business UI

Target problem:

- the slot file often needs business-facing fields beyond technical metadata
- players and QA need labels like chapter name, location name, playtime, save type, or thumbnail reference
- without a clear convention, every project invents incompatible ad-hoc metadata

Lite should move toward:

- a recommended metadata schema for business-facing slot info
- clear guidance for what belongs in slot metadata vs settings vs full gameplay payload
- examples for auto-save, manual save, and checkpoint labels

Recommended Lite acceptance bar:

- users can answer "what should go in slot metadata?" without guessing
- slot metadata is good enough to drive a production save list UI
- the schema stays simple enough that migration pressure does not get pushed down into every Source

### 7. Core Reliability

These always stay in Lite/Core:

- correctness fixes
- better defaults
- safer restore behavior
- clearer editor/runtime warnings
- consistency improvements
- explicit scene/scope restore contracts for currently loaded targets
- version compatibility reporting and baseline load blocking when schema/data versions do not match
- one-slot local backup safety with simple fallback recovery

These are not premium features.

### 8. Baseline C# Parity

Lite/Core should continue to treat C# as a first-class baseline entry path.

That means:

- runtime entrypoints should stay callable from C#
- compatibility inspection should not become GDScript-only
- baseline save/load workflows should remain documented for both languages

This is still part of the base product, not a Pro-only differentiator.

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
- clearer commercial-project boundary explanation for users

### Lite v0.4

Recommended focus:

- slot summary and in-game save list workflow
- slot metadata schema guidance
- autosave and checkpoint integration examples
- better business-facing save-slot ergonomics without adding Pro orchestration concepts

## What Lite Should Explicitly Avoid

Do not overload Lite with:

- advanced reference resolution
- migration frameworks
- multithreaded seamless save pipelines
- high-complexity orchestration systems
- premium delivery/security profiles beyond the baseline
- cloud sync transport and conflict workflows
- multi-scene restore schedulers or staged resource-loading coordinators

Those are better left to `Pro`.

## Relationship To Commercial Projects

Lite/Core should still be enough to build a real save system in a serious project.

That means Lite/Core must continue owning:

- Save Graph
- Restore Contract
- compatibility reporting
- baseline backup safety
- project-level diagnostics

But once the project problem changes from:

- "how do I save this object/system/runtime set?"

to:

- "how do I orchestrate multi-stage restore?"
- "how do I migrate old saves?"
- "how do I sync local and cloud state?"
- "how do I repair references after restore?"

the project has naturally crossed into `Pro` territory.
