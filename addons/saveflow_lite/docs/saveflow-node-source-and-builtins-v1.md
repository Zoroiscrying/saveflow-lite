# SaveFlow Node-Centric Model v1

## Goal

SaveFlow should stop feeling like "a pile of sources that happen to save data" and start feeling like "a tool for saving a Godot object and the parts attached to it".

The user mental model should be:

1. Pick a target node.
2. SaveFlow understands the target's built-in Godot state from its type.
3. The user chooses which child components or attached systems also participate.
4. SaveFlow produces one structured payload for that target.


## Current Problem

Current SaveFlow is still too source-centric:

- the old field-only helper model is property-centric.
- system-state sources should remain source-centric, not adapter-centric.
- `SaveFlowEntityCollectionSource` is collection-centric.

These are valid internal building blocks, but they are not the most natural user-facing model.

This causes a few UX problems:

- Users have to think in terms of many small source nodes instead of "save this object".
- Built-in Godot node state is not modeled as a first-class concept.
- Child-node composition is not modeled as a first-class concept.
- Demo wrappers can become empty shells with no obvious value.
- Users still have to infer when they need pre-load preparation or special restore steps.


## Design Principle

SaveFlow should distinguish four different things:

1. `Scope`
   Domain, order, restore policy.
2. `Node Source`
   Save one target node and selected attached parts.
3. `Data Source`
   Save a non-node system model such as a registry, table, queue, or manager.
4. `Entity Collection`
Save a set of runtime entities and coordinate restore through an entity factory.

The missing piece is item 2.


## New User-Facing Concept

## `SaveFlowNodeSource`

`SaveFlowNodeSource` should become the main user-facing way to save a Godot object.

It binds to one target node and does three jobs:

1. It detects built-in serializer candidates from the target node's inheritance chain.
2. It lets the user choose which built-in serializers are enabled.
3. It lets the user include selected child save participants under the same target.

This means the user no longer starts from:

"Which source classes do I need to add?"

They start from:

"I want to save this Player node."


## Mental Model

For a typical `Player`:

```text
Player
|- AnimationPlayer
|- AbilitySystem
|- InventoryModel
|- RendererTarget
```

The user should be able to configure one `SaveFlowNodeSource` on `Player` and get:

- built-in `Node2D` transform state from `Player`
- built-in animation state from `AnimationPlayer`
- custom system state from `AbilitySystem`
- custom bound data from `InventoryModel`
- optional inclusion/exclusion of each child participant


## Built-In Serializer Registry

`SaveFlowNodeSource` should not hardcode every Godot type internally.
Instead, SaveFlow should introduce a built-in serializer registry.

Each serializer declares:

- which node types it supports
- which state it gathers
- which state it applies
- how it should appear in inspector UI

Example first-wave serializers:

- `Node2DSerializer`
  - `position`
  - `rotation`
  - `scale`
- `Node3DSerializer`
  - `position`
  - `rotation`
  - `scale`
- `ControlLayoutSerializer`
  - `position`
  - `size`
  - `rotation`
  - `scale`
- `AnimationPlayerSerializer`
  - current animation
  - assigned animation
  - playback position
  - speed scale
  - playing/paused state

This gives SaveFlow a stable core model:

- user-facing object: `SaveFlowNodeSource`
- internal extension point: built-in serializer registry

This is preferable to a long-term design based on many thin classes like:

- `SaveFlowAnimationSource`
- `SaveFlowNode2DSource`
- `SaveFlowNode3DSource`

Those may still exist as presets later, but they should not be the core architecture.


## Inheritance Chain Recognition

SaveFlow should explicitly recognize that a node's serializable built-in state depends on its inheritance chain.

Example:

- `CharacterBody2D` implies `Node2D` transform support.
- `RigidBody2D` also implies `Node2D` transform support.
- `Control` implies layout support.
- `AnimationPlayer` implies playback state support.

This must be type-driven, not manual-source-driven.

The user should not have to think:

"Do I need to add a Node2D source for this?"

SaveFlow should know that from the target type.


## Child Participation Model

Inheritance alone is not enough.
The other half is composition.

The user also needs to decide which attached child nodes participate in the save graph for the same target.

`SaveFlowNodeSource` should support three inclusion modes:

1. `Self Only`
   Only the target node's built-in and local custom state.
2. `Selected Children`
   Only explicitly selected child participants.
3. `Selected Descendants`
   Explicitly selected descendants, not just direct children.

Within that model, a child participant may be one of:

- built-in serializer target
- `SaveFlowSource`
- custom `SaveFlowDataSource`
- nested `SaveFlowNodeSource`

Recommended rule:

- default should be explicit selection, not broad discovery
- discovery should help authoring, not define the runtime contract


## Payload Shape

`SaveFlowNodeSource` should output structured payload, not a flat dictionary blob.

Recommended shape:

```gdscript
{
    "target_kind": "node_source",
    "target_path": "Player",
    "built_ins": {
        "node2d_transform": {
            "position": Vector2(...),
            "rotation": 0.0,
            "scale": Vector2(...)
        },
        "animation_player": {
            "current_animation": "attack",
            "assigned_animation": "attack",
            "position": 0.32,
            "speed_scale": 1.0,
            "is_playing": true
        }
    },
    "children": {
        "ability_system": {...},
        "inventory_model": {...}
    }
}
```

This gives SaveFlow clearer diagnostics and better future migration support than a single freeform dictionary.


## Relationship To Existing Runtime Pieces

### `SaveFlowScope`

Still needed.
It remains the orchestration layer:

- order
- restore policy
- partial save/load
- domain partitioning

`SaveFlowNodeSource` becomes a leaf under a scope.

### Custom `SaveFlowDataSource`

Still needed.
Use it when the state is not meaningfully "owned" by a single node object.

Examples:

- world registry
- room state table
- event queue
- quest database

### `SaveFlowEntityCollectionSource`

Still needed.
Use it when the problem is:

"Which runtime instances exist, and how do I restore that set?"

But each entity in that collection should be allowed to contain its own `SaveFlowNodeSource` or local scope graph.


## What This Changes In Current Demo Patterns

### Animation

The current Zelda-like animation source proves the concept but is not the right long-term user-facing path.

Long-term preferred path:

- `SaveFlowNodeSource` sees an included `AnimationPlayer`
- built-in `AnimationPlayerSerializer` handles it automatically

`SaveDataBuilder` can still exist for custom extensions, but it should not be the primary answer for common built-in Godot types.

### Empty Wrapper Scripts

Files like these are currently weak:

- demo-specific bound data source subclasses with no extra behavior
- demo-specific bound entity provider subclasses with no extra behavior

If they add no defaults, no custom inspector help, and no behavior, they should not exist.

Good wrapper rule:

A user-facing subclass should only exist if it adds at least one of:

- a clearer default configuration
- custom inspector UI
- behavior
- diagnostics

Otherwise the demo should just use the base SaveFlow class directly.

### Runtime Pre-Load Preparation

Current scope hooks like `before_load()` are useful, but they are too implicit for common restore preparation.

SaveFlow should formalize this as restore policy rather than rely on custom knowledge.

For collection restore, explicit preparation strategies should exist:

- `KEEP_EXISTING`
- `CLEAR_TARGET_BEFORE_RESTORE`
- `DELEGATE_TO_FACTORY_BINDING`

That should be discoverable in the inspector instead of hidden inside a custom scope script.


## Where `SaveDataBuilder` Fits

`SaveDataBuilder` is still worth adding, but as an extension ergonomics tool.

It should help authors of custom sources write:

```gdscript
return SaveFlowDataBuilder.begin() \
    .field("current_animation", animation_player.current_animation) \
    .field("position", animation_player.current_animation_position) \
    .field("is_playing", animation_player.is_playing()) \
    .to_dict()
```

This reduces dictionary boilerplate.

But it should be treated as a secondary ergonomics feature, not the core answer to built-in Godot state handling.


## Recommended Implementation Order

### Phase 1

- Design and add `SaveFlowNodeSource`
- Design and add built-in serializer registry
- Implement first-wave serializers:
  - `Node2D`
  - `Node3D`
  - `Control`
  - `AnimationPlayer`

### Phase 2

- Add child participant selection model
- Add inspector UI for included built-ins and included children
- Add structured payload diagnostics

### Phase 3

- Replace Zelda-like custom animation source with node-centric built-in handling
- Remove empty demo wrapper scripts that no longer provide value
- Promote collection pre-restore strategy into formal policy

### Phase 4

- Add `SaveDataBuilder` for custom source authors
- Add more built-in serializers as needed:
  - `AudioStreamPlayer`
  - `Timer`
  - `PathFollow2D/3D`


## Recommendation

SaveFlow should officially move from:

"Users compose many low-level sources"

to:

"Users save a target node, choose which built-in and attached parts participate, and let SaveFlow organize the result."

That is the model most aligned with:

- Godot's node-tree mental model
- real project authoring workflow
- lower user error rate
- lower debug cost
- clearer plugin differentiation
