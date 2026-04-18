# SaveFlow Ergonomics V2

Updated: 2026-04-06

## Purpose

This document tightens SaveFlow around the actual user problem:
not just writing save files, but reducing the number of concepts and manual steps required to build a trustworthy save/load workflow in a real game project.

## 1. What The User Is Right About

The previous direction was still too dependent on knowledge and convention.

Pain points that remained:
- runtime script naming was not aligned with the product name
- the sandbox still taught too much implementation detail
- saveable detection was still heavily method-name driven
- field persistence rules were still too implicit or too manual
- the product still leaned closer to a low-level helper than a direct save workflow

## 2. Naming Alignment

Decision:
- autoload name stays `SaveFlow`
- main runtime file becomes `save_flow.gd`

Reason:
- reduce naming drift between brand, autoload, docs, and source files
- improve codebase readability

## 3. Marker Design

### 3.1 Saveable object marker

Ideal mental model:
- a developer should be able to say "this object participates in save/load"
- not just accidentally qualify because it happens to implement certain method names

Godot reality:
- GDScript does not provide a C#-style interface keyword
- but Godot 4.5+ supports abstract classes and abstract methods

Design decision:
- support `SaveFlowSource` as the explicit contract
- keep `SaveFlowNodeSource` as the low-boilerplate scene-first contract
- do not rely on method-name detection

Resulting hierarchy:
- Scene-first users: attach `SaveFlowNodeSource`
- Code-first users: `extends SaveFlowSource` or `extends SaveFlowDataSource`

This gives SaveFlow explicit main paths instead of accidental ones.

### 3.2 Field marker design

User goal:
- only save what is intended
- avoid serializing everything blindly
- avoid hand-writing serialization glue for ordinary data holders

Desired syntax in spirit:
- `@SaveData`
- `@DoNotSave`

Constraint:
- GDScript annotations are built-in language annotations, not user-defined decorators in the C# sense

Inference from official docs:
- Godot documents a fixed annotation system and built-in annotations such as `@export`
- there is no general user-defined annotation mechanism for custom persistence markers

Practical SaveFlow equivalent:
- use `@export` / `@export_storage` as the primary field marker in Lite
- use component-level additional field lists only when needed
- support ignore lists for explicit opt-out
- provide transform defaults automatically
- later provide richer inspector tooling so the user does not have to type raw strings often

Current V2 component rules:
- business data is explicit through stored script fields (`@export` / `@export_storage`)
- transform-like data is auto-included by default for Node2D, Node3D, and Control
- extra non-exported properties can still be included through `additional_properties`
- any property can be opted out through `ignored_properties`

This matches the user mental model more closely:
- important transform data is persisted automatically
- business state is explicit
- opt-out exists when automatic persistence is undesirable

## 4. Current SaveFlow Main Paths

### Path A: Scene/component workflow

Best for most users.

Flow:
1. put gameplay state on normal nodes
2. attach `SaveFlowNodeSource` as child helper nodes
3. set `save_key`
4. mark intended business fields with `@export` or `@export_storage`
5. call `SaveFlow.save_scene(slot_id, root)` and `SaveFlow.load_scene(slot_id, root)`
6. use `SaveFlow.inspect_scene(root)` when you want to verify what will be collected

This should become the default onboarding path.

### Path B: Code-first serializable objects

Best for teams that prefer explicit code contracts.

Flow:
1. `extends SaveFlowSource` or `extends SaveFlowDataSource`
2. implement `gather_save_data()` or `gather_data()`
3. implement `apply_save_data(data)` or `apply_data(data)`
4. optionally override `get_save_key()`
5. call `SaveFlow.save_nodes(...)` and `SaveFlow.load_nodes(...)`

This is more explicit than free-form method detection and reads like a real save graph contract.

## 5. Transform Defaults

Design decision:
- transform data should be saved automatically unless the user opts out

Reason:
- position, rotation, scale, size, and related state are among the most common persistence expectations
- requiring users to remember to list basic transform fields creates avoidable errors

Current automatic behavior in `SaveFlowNodeSource`:
- Node2D: `position`, `rotation`, `scale`
- Node3D: `position`, `rotation`, `scale`
- Control: `position`, `size`, `scale`, `rotation`

Opt-out path:
- `ignored_properties`

Future improvement:
- expose transform presets more clearly in inspector UI
- offer one-click include/exclude presets per node type

## 6. What Still Needs To Improve

Even after V2, several ergonomics gaps remain.

### 6.1 Stringly-typed field selection

`additional_properties` is now a secondary escape hatch, not the main path.
That is an improvement, but it is still typo-prone when used.

Next step:
- inspector helper for property picking instead of raw text entry
- validation report for missing properties before save/load

### 6.2 Save graph visibility

Users still need better visibility into:
- what objects were collected
- what keys were saved
- what properties were skipped
- what failed to restore

Next step:
- save trace or save report object
- optional debug panel or inspector tool

### 6.3 Scene restoration semantics

Saving properties is only part of the problem.
Games often need to answer:
- should a scene be loaded first, then restored?
- should dynamic objects be respawned?
- how should deleted/spawned runtime entities be handled?

Next step:
- formalize scene restore policy
- distinguish persistent scene state from runtime entity reconstruction

## 7. Real Game Save/Load Scenarios To Optimize For

SaveFlow should optimize for these concrete situations.

### Scenario 1: Jam / prototype game

Needs:
- one global state root
- a few nodes for player/settings/progress
- one slot or a few slots

Ideal SaveFlow behavior:
- one root node
- a few `SaveFlowNodeSource` children
- immediate save/load with almost no custom code

### Scenario 2: Mid-size single-player game

Needs:
- multiple systems: player, settings, quests, unlocked content, current scene state
- evolving data model over time
- multiple slots

Ideal SaveFlow behavior:
- explicit scene or system roots
- stable save keys
- slot metadata and future migration support
- debug visibility when load output is wrong

### Scenario 3: Commercial long-lived project

Needs:
- migration
- validation
- debug tooling
- safer editing and recovery workflow

Ideal SaveFlow behavior:
- Pro layer on top of the Lite workflow
- not a different mental model

## 8. Product Principle Going Forward

The user should not need to remember hidden rules.

SaveFlow should prefer:
- explicit markers over accidental convention
- inspector configuration over stringly-typed code when possible
- automatic handling of common state like transforms
- opt-out for exceptions
- save/load flows that read like intent, not infrastructure

## 9. Immediate Implementation Priorities

1. keep `save_flow.gd` naming aligned everywhere
2. keep `SaveFlowNodeSource` as the default Lite path
3. make component property selection less typo-prone
4. expose clearer save reports and validation
5. formalize `SaveFlowSource` and `SaveFlowDataSource` as the code-first contracts
6. postpone C# until the GDScript-side workflow feels truly direct
