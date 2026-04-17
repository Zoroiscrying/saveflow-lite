# SaveFlow Pro Feature Plan

This document defines the intended `SaveFlow Pro` feature set.

It is based on the product direction already discussed in the workspace:

- `Lite` stays focused on the clean baseline SaveFlow model
- `Pro` sells higher-level workflows and lower integration cost for advanced teams
- `Pro` must consider both GDScript and C# usage from the start

## Product Goal

`SaveFlow Lite` should remain:

- enough to build a real save system
- clean in user model
- strong in the base graph and runtime model

`SaveFlow Pro` should add:

- higher-level authoring workflows
- lower boilerplate for complex save logic
- stronger restore orchestration
- better ergonomics for larger projects
- C#-friendly high-level APIs

That means `Pro` should not become:

- a paywall for baseline correctness
- a dumping ground for normal bug fixes
- a way to make `Lite` feel intentionally crippled

## The Actual Pro Direction

The strongest `Pro` direction discussed so far is not "enterprise checklists".
It is:

- better save authoring
- better restore authoring
- better orchestration
- better advanced integration ergonomics

That gives `Pro` a clearer identity:

`Lite` gives you the model.
`Pro` gives you the workflow power.

## Pro Feature Pillars

### 1. SaveDataBuilder

This is one of the most explicit Pro candidates already discussed.

Target problem:

- complex `SaveFlowDataSource` implementations still require a lot of handwritten payload assembly
- developers repeat the same nested dictionary construction and field-shaping logic

`SaveDataBuilder` should provide:

- fluent payload construction
- nested sections
- list/object composition helpers
- consistent field writing
- optional omission helpers for empty/default values
- clearer gather code than raw dictionary assembly

Example intent:

- instead of hand-building nested dictionaries
- build payloads through a clearer API surface

This belongs in `Pro` because:

- it reduces boilerplate
- it improves authoring ergonomics
- it is not required for the base SaveFlow model to be valid

### 2. Fluent Restore / Data Restorer

This should be treated as the paired half of `SaveDataBuilder`.

Target problem:

- `apply_data()` often becomes a custom parser plus defensive restore code
- the write path and read path become inconsistent

`Pro` should provide:

- structured restore helpers
- fluent read/apply API
- required vs optional field helpers
- typed/defaulted reads
- nested section traversal helpers
- clearer restore intent than manual dictionary unpacking

This is not just "read helpers".
It is the restore-side authoring workflow.

### 3. Restore Orchestration and Preprocessing

This was already repeatedly identified as a place where bigger projects need more than the Lite baseline.

Target problem:

- some restores need preparation before apply
- some runtime containers need clearing, staging, or phased rebuild
- some systems cannot be restored in one immediate pass

`Pro` should eventually offer:

- pre-restore hooks
- staged restore helpers
- better orchestration primitives
- clearer preprocessing workflow
- stronger restore policies for complex environments

This should build on top of `SaveFlowScope`, not replace it.

`Lite` should keep the simple and understandable restore model.
`Pro` should help when restore order and preparation become a real engineering problem.

### 4. Higher-Level Runtime Entity Authoring

Lite already supports runtime entity collections.
Pro should reduce the remaining glue for larger entity-driven games.

Target problem:

- teams still end up writing repeated custom entity restore glue
- more advanced projects want better workflows around entity rebuild and re-attachment

Potential Pro direction:

- richer entity collection helpers
- higher-level entity restore authoring
- better prefab/entity graph integration helpers
- more advanced runtime collection tooling

This should not replace the current `EntityCollectionSource + EntityFactory` baseline.
It should accelerate advanced use cases.

### 5. Save Storage Profiles

This is one of the clearest "Pro-feeling" capabilities and should be treated as a first-class product pillar.

Target problem:

- teams shipping real games often need more than plain save serialization
- save files may need to be:
  - compressed
  - encrypted
  - protected against simple tampering
  - stored with recovery/backup strategy
  - packaged differently across platforms or build targets

`Pro` should eventually provide:

- explicit save storage profiles
- compression options
- encryption options
- optional integrity / tamper-detection hooks
- backup / recovery save profile helpers
- export/import profile configuration per product or platform

This is a strong Pro feature because:

- it is immediately legible to buyers
- it has obvious production value
- it is not required for the Lite baseline save model

This should be framed as part of delivery and shipping readiness, not just serialization internals.

### 6. Performance and Seamless Saving

This is another strong Pro pillar for commercial-scale projects.

Target problem:

- some teams need saving that does not visibly stall gameplay
- large save graphs and runtime entity sets can create frame spikes
- projects want background save pipelines instead of synchronous "freeze and write"

`Pro` should eventually provide:

- snapshot-oriented save capture
- asynchronous write pipeline
- multithreaded serialization or save preparation where safe
- staged "capture now, write later" workflow
- diagnostics around snapshot size, capture time, and write time

The most important product outcome is:

- seamless or near-seamless save behavior for larger projects

This belongs in `Pro` because:

- it solves a real production pain point
- it requires more engineering than the Lite baseline should carry
- it fits commercial expectations much better than a synchronous-only workflow

### 7. Reference Resolution

This is still a strong Pro candidate, but it should be framed as an advanced integration feature, not the sole product identity.

Target problem:

- larger save payloads often need stable references to other saved objects, authored nodes, or runtime entities

Potential Pro features:

- reference descriptors
- authored object resolving
- runtime entity reference resolving
- post-load link pass
- unresolved reference diagnostics

This fits Pro well, but it should sit under the broader "advanced project ergonomics" umbrella.

### 8. Migration / Version Tooling

This also remains a good Pro candidate.

Target problem:

- save files evolve
- field names change
- payload structures move
- runtime descriptors change over time

Potential Pro features:

- migration steps
- migration registry
- source/schema version helpers
- payload upgrade reporting

This is especially valuable for long-lived or commercial projects.

## C# Must Be A First-Class Design Input

This is not optional.

`Pro` is exactly the part of the product where C# matters more, not less.

Why:

- builder APIs are more valuable in C#
- fluent restore APIs are more natural in C#
- migration and reference APIs benefit from typed models
- C# users expect stronger editor and IDE guidance

So for any serious Pro API, the design process must answer:

- what does the GDScript shape look like?
- what does the C# shape look like?

This does **not** mean every feature must ship with full C# support on day one.
It does mean the API cannot be designed as if C# will be bolted on later.

## C# Design Rules

For Pro-level APIs, use these rules:

### Rule 1. Avoid API shapes that only feel natural in GDScript

If an API only makes sense as:

- weak dictionaries everywhere
- dynamic string-only access
- implicit runtime duck typing

then it is probably too GDScript-specific.

### Rule 2. Builders should be chainable and typed where possible

`SaveDataBuilder` and fluent restore should be designed so C# can expose:

- fluent chaining
- overloads
- typed reads
- reusable extension methods

### Rule 3. Descriptors should be stable data objects

Reference descriptors, migration descriptors, and orchestration descriptors should be shaped as stable models, not ad-hoc loose dictionaries where avoidable.

### Rule 4. C# should not require a second-class wrapper experience forever

It is acceptable if the first implementation lands in GDScript.
It is not acceptable if the API shape guarantees a bad C# surface.

## Recommended Release Order

### Pro v0.1

The first Pro release should establish the product shell and one real workflow advantage.

Recommended scope:

- `saveflow_pro/plugin.cfg`
- `saveflow_pro/plugin.gd`
- initial Pro branding and docs
- `SaveDataBuilder` foundation
- restore-side fluent reader/restorer foundation
- C# surface notes for those APIs

Why:

- this is the clearest match to the product direction already discussed
- it gives Pro a visible workflow improvement immediately

### Pro v0.2

Recommended scope:

- restore orchestration / preprocessing helpers
- higher-level entity authoring helpers
- initial save storage profiles
- snapshot capture design and async save pipeline groundwork

### Pro v0.3

Recommended scope:

- performance-oriented snapshot saving
- multithreaded seamless save implementation
- reference resolution
- migration/version tooling
- stronger encryption / compression / integrity profile options

This order is deliberate:

- first ship workflow wins
- then ship advanced system power

## What Should Stay In Lite/Core

These should remain outside Pro:

- base node save support
- base data source support
- base entity collection support
- base prefab entity factory support
- basic scope/domain ordering
- baseline diagnostics
- core correctness and reliability fixes

If one of these is missing, `Lite` is incomplete.

## First Technical Slice

The first real `Pro` implementation should create:

- `addons/saveflow_pro/plugin.cfg`
- `addons/saveflow_pro/plugin.gd`
- `addons/saveflow_pro/runtime/builders/`
- `addons/saveflow_pro/runtime/restorers/`

Suggested first classes:

- `SaveFlowDataBuilder`
- `SaveFlowRestoreReader`
- `SaveFlowDataRestorer`

And every one of them should be evaluated for:

- GDScript ergonomics
- C# shape
- long-term stable naming

## Decision Checklist

Before adding a feature to `Pro`, check:

1. does this reduce advanced save-integration cost?
2. does this improve real production delivery or shipping readiness?
3. is this mainly a workflow accelerator or advanced integration capability rather than a baseline capability?
4. does it still make sense in both GDScript and C# where applicable?
5. would this help a team avoid writing custom glue code repeatedly?

If the answer to 3 is no, the feature likely belongs in `core` or `lite`.

