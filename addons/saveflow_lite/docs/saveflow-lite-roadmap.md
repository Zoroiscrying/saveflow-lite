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
- `SaveFlowTypedDataSource`
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

### Lite v0.5

Recommended focus:

- built-in final pass
- authoring warning polish
- scene validator consistency
- docs for fixing common source ownership and built-in selection mistakes

### Lite v0.6

Recommended focus:

- C# parity for baseline Lite workflows
- typed-data ergonomics and documentation polish
- C# active-slot and save-card workflow helpers
- regression tests for C# wrappers that project code is expected to call directly

## Current Roadmap Checkpoint

As of `0.1.10`, several roadmap lines have moved from "planned" into baseline
Lite behavior:

- project-level settings and compatibility policy are visible from `SaveFlow Settings`
- slot summary, business metadata, autosave, checkpoint, and active-slot
  patterns are documented and demonstrated in the recommended template
- `SaveFlowTypedDataSource` gives Godot users a lower-boilerplate path for typed
  system/model data, while `SaveFlowTypedStateSource` gives C# users a direct
  graph-source path for one typed state object
- `SaveFlowPipelineControl` and `SaveFlowPipelineSignals` let scenes react to
  local save/load lifecycle stages without subclassing every Source
- C# has baseline runtime entry wrappers and typed-data helpers
- `SaveFlowNodeSource` has stronger authoring diagnostics for missing included
  children, nested Source helpers, and ownership boundaries
- the recommended template is now a scene-authored project workflow instead of
  a set of disconnected UI-only cases
- common built-in coverage already includes the first focused batch of
  high-value object/runtime nodes

As of `0.2.0`, the release line is shifting from adding concepts to hardening
the runtime and release surface:

- the `SaveFlow` singleton has been reduced to a facade over focused runtime
  services for storage, slot lifecycle, metadata, graph execution, pipeline
  lifecycle, DevSaveManager access, and entity restore
- the public runtime API remains stable while internal responsibilities are
  easier to test and maintain
- the next release checkpoint is primarily reliability, packaging, and
  regression confidence, not another feature pillar

That does **not** mean these areas are complete forever.
It means the next Lite work should avoid adding new concepts unless they remove
a concrete adoption or reliability problem.

The largest remaining Lite gap for the next line is now:

- users can compose real scenes correctly, but stale built-in selections,
  incorrect field overrides, ownership mistakes, and incomplete authoring plans
  should become clearer before runtime save/load tests

## Previous 0.5 Working Plan

The next Lite release should be framed as:

- **Built-in final pass and authoring warnings**

The goal is not to add another save model.
The goal is to make the existing node-authored workflow safer:

- common Godot node state should be covered by focused built-ins
- built-in serializer and field selections should not fail silently
- ownership mistakes should remain visible from the node inspector and scene validator
- every new warning should point at a concrete fix

### Must Have

#### 1. Built-in coverage audit

Target problem:

- built-ins reduce boilerplate only when their restore semantics are obvious
- adding too many node types makes Lite harder to explain
- authors need to know when a built-in is enough and when a custom source is better

Lite should audit:

- every registered built-in serializer
- current test coverage for each high-value category
- candidate gaps with a clear "add", "defer", or "do not add" decision

Acceptance bar:

- every built-in has a clear reason to exist
- no new built-in ships without a focused runtime test
- unclear Godot node state is deferred instead of guessed

#### 2. Built-in selection warnings

Target problem:

- `SaveFlowNodeSource` can be edited after the target node type changes
- stale serializer ids and field ids may be filtered out safely at runtime
- safe filtering is still confusing when the author expects that state to save

Lite should warn when:

- `included_target_builtin_ids` contains unsupported serializer ids
- `target_builtin_field_overrides` references an unsupported serializer
- field overrides reference fields that the serializer does not expose

Acceptance bar:

- inspector warnings explain what is ignored and why
- scene validator surfaces those warnings
- save/load behavior remains backwards compatible

#### 3. Entity factory and collection warning pass

Target problem:

- runtime entity save/load is easy to misconfigure
- missing containers, missing factories, missing type keys, or stale prefab setup should be visible before pressing Play
- warnings should explain the node relationship, not just say "invalid"

Lite should tighten:

- prefab factory plan details
- collection source plan details
- double-collection diagnostics
- missing identity guidance

Acceptance bar:

- a user can fix the setup from the node tree and inspector
- custom factories still work without forcing prefab-factory assumptions
- warnings do not become runtime-only logs

#### 4. Scene validator consistency

Target problem:

- users often edit scenes without opening Save Graph tooling
- node warnings and the scene validator badge should agree about the same problems
- duplicate keys and invalid plans should remain easy to find

Lite should ensure:

- source/scope/factory/pipeline warnings flow into the validator
- duplicate source keys stay errors
- incomplete but safe authoring states stay warnings
- each issue includes node path and next-action guidance

#### 5. Documentation

Target problem:

- warnings help only when users understand the underlying ownership model
- built-ins are useful only when users know their boundary

Lite docs should explain:

- when `SaveFlowNodeSource` built-ins are enough
- when to add a child source directly instead of saving the child subtree
- when to use `SaveFlowEntityCollectionSource` for runtime containers
- how to fix stale built-in selections and field overrides

### Not In This Release

Keep these out of scope:

- migration frameworks
- cloud save
- cross-device conflict handling
- reference repair systems
- staged multi-scene restore orchestration
- multithreaded seamless save pipelines
- a full save-menu UI framework
- broad setup wizards
- C# parity expansion beyond bug fixes

### Release Readiness Check

Before shipping this release, verify:

1. every new built-in has a focused runtime test
2. every new warning appears in the relevant inspector warning path
3. scene validator shows source/scope/factory/pipeline warnings consistently
4. docs explain the fix, not only the error
5. runtime smoke tests still pass

### 0.5.x Progress Checkpoint

Current progress toward the **Built-in final pass and authoring warnings** release:

- `SaveFlowNodeSource` now reports unsupported target built-in ids and unknown
  target built-in field overrides instead of silently filtering them out.
- `SaveFlowEntityCollectionSource` now reports duplicate runtime
  `persistent_id` values, default `Identity` fallback ids, and entity
  `type_key` values that the configured factory cannot handle.
- scene validator regression tests now confirm both the NodeSource built-in
  warnings and EntityCollection identity/factory warnings surface from the
  validator issue list.
- `saveflow-common-authoring-mistakes.md` now includes concrete fixes for stale
  built-ins, invalid field overrides, duplicate entity ids, default identity ids,
  factory type mismatches, and double-collected runtime containers.
- `docs/workspace/saveflow-lite-0.5-builtins-authoring-audit.md` now tracks the
  0.5.x audit scope, current coverage, recommended work order, and release bar.

## Next Release Working Plan

The next Lite release should be framed as:

- **C# parity and typed-data polish**

The goal is not to create a second C#-only save model.
The goal is to make the existing Lite model equally reachable from C#:

- active-slot and save-card helpers should exist in C# as well as GDScript
- baseline slot, metadata, graph, entity, and validation calls should have thin C# wrappers
- typed metadata and typed data should remain the default C# path for new project code
- docs should show when to use typed helpers instead of raw dictionaries

### 0.6.x Progress Checkpoint

Current progress toward the **C# parity and typed-data polish** release:

- `SaveFlowClient` now exposes more baseline runtime wrappers for slot
  management, metadata reads/writes, validation, graph inspection/application,
  current-data helpers, and entity restore.
- C# now has `SaveFlowSlotWorkflow` and `SaveFlowSlotCard`, matching the
  recommended active-slot/save-list workflow introduced on the GDScript side.
- runtime regression coverage now includes a C# fixture for active-slot metadata,
  save-card summaries, and C# client slot operations.
- C# typed-state sources now own default `State` storage and optional payload
  sections, reducing the boilerplate for source-generated typed state.
- `saveflow-csharp-quickstart.md` now documents active slots, save cards, and
  the expanded C# wrapper surface.
- the recommended template now includes a small C# workflow demo that wires
  `SaveFlowTypedStateSource`, `SaveFlowSlotWorkflow`, `SaveFlowSlotCard`, and
  `SaveFlowClient.SaveScope()`
  in one scene-authored example.

## Previous 0.4 Working Plan

The 0.4 Lite release was framed as:

- **Business save-slot workflow polish**

Current completed scope:

- `SaveFlowSlotWorkflow` centralizes active slot index, slot-id templates,
  slot-id overrides, typed metadata construction, and save-card construction.
- `SaveFlowSlotCard` provides typed card data for in-game continue/load/save UI
  without loading full gameplay payloads.
- the recommended project workflow template uses the helper for main-scene and
  subscene slot cards while keeping save/load calls explicit.
- runtime tests cover active slot save/delete behavior, autosave/checkpoint
  writes to the active slot only, and recommended template card summaries.

## Previous 0.3 Working Plan

The 0.3 Lite release was framed as:

- **Preflight + reliability polish**

The goal is not to add Pro-style orchestration.
The goal is to make the existing Lite workflow harder to misconfigure and safer
to release.

### Must Have

#### 1. Setup Health / Preflight v2

Target problem:

- setup health currently checks installation and C# basics
- source previews catch local mistakes, but users still need one place to see
  whether the current scene has obvious SaveFlow authoring problems

This release should extend `SaveFlow Settings > Setup Health` with current-scene
preflight checks for:

- source count and scope count
- empty or duplicate source keys
- invalid `SaveFlowNodeSource`, `SaveFlowTypedDataSource`, `SaveFlowDataSource`,
  `SaveFlowEntityCollectionSource`, and entity-factory plans
- common ownership mistakes that already appear in source plans

Acceptance bar:

- a user can open the scene and immediately see whether the SaveFlow graph is
  obviously safe to test
- invalid scene authoring shows up in one project-level place, not only after
  selecting the exact broken node
- this remains diagnostics only; it must not auto-rewrite the user's save graph

#### 2. Release tooling hardening

Target problem:

- release automation should be boring
- a missing GitHub Release or remote branch race should not require manual
  intervention after assets are already generated

This release should:

- make `gh release view` failure fall through to release creation
- fetch/rebase the public sync worktree before syncing and before pushing
- keep release asset validation unchanged

Acceptance bar:

- running `publish_saveflow_lite.ps1 -PushChanges -CreateRelease` can create a
  new release when it does not already exist
- if the public repo moved forward before push, the script rebases or fails
  clearly before publishing the tag

#### 3. Focused built-in follow-up

Target problem:

- built-ins should continue to reduce handwritten object-state code
- coverage should not drift into arbitrary UI persistence or obscure node state

This release may add a small follow-up batch only if each node passes this bar:

- common in gameplay scenes
- has obvious restore value
- can be explained in one sentence
- has a focused runtime test

Candidate areas:

- collision shape enabled/disabled state
- collision layer/mask for authored interactables
- other common runtime toggles that users currently store by hand

#### 4. Slot UI polish without new architecture

Target problem:

- the slot-summary APIs and demo exist, but the recommended save-list workflow
  can still be easier to copy into real projects

This release may tighten:

- recommended slot metadata names
- in-game save-card examples
- docs explaining active slot index vs storage key vs display name

### Not In This Release

The next Lite release should **not** become a grab-bag of unrelated bigger
systems.

Keep these out of scope:

- migration frameworks
- cloud save
- reference repair systems
- staged multi-scene restore orchestration
- multithreaded seamless save pipelines
- heavy editor automation or wizard-style setup systems
- a large new panel just to explain features already covered by Quick Access,
  Setup Health, or existing previews

### Release Readiness Check

Before shipping this next Lite release, verify:

1. `Setup Health` reports both setup and current-scene authoring issues clearly
2. release automation can create or update a GitHub release without manual
   fallback
3. the recommended template still demonstrates the same core ownership models
4. smoke tests still pass for:
   - recommended cases
   - editor entry points
   - core runtime save/load behavior

### 0.3.x Progress Checkpoint

Current progress toward the **Preflight + reliability polish** release:

- `Setup Health / Preflight v2` now has a scene validator badge, current-scene
  source/scope/factory checks, pipeline signal checks, component breakdowns,
  and next-action guidance.
- `Release tooling hardening` now validates version consistency before sync,
  requires a clean public sync worktree, fetches/rebases before sync and push,
  and keeps release asset validation unchanged.
- the focused built-in follow-up extends common gameplay coverage with
  `RayCast2D` / `RayCast3D` sensor state so authored interactables, traps, and
  detection rays need less handwritten state code.
- slot workflow copy now clarifies active slot index, storage key, display name,
  and the rule that autosave/checkpoint events write the active slot rather than
  every visible save card.

Remaining 0.3.x work should now stay limited to release QA unless a regression
or packaging issue appears.

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
