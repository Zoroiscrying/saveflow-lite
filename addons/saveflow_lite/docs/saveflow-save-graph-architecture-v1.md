# SaveFlow Save Graph Architecture v1

Updated: 2026-04-07

## Goal

SaveFlow should stop being only a flat collection of component sources.
For medium-size projects, it needs an explicit save graph that matches how game systems are actually organized.

This architecture adds four roles:
- `SaveFlow` as the top-level save manager
- `SaveFlowScope` as a logical save domain
- `SaveFlowSource` as a leaf data source
- a factory-backed runtime restore seam for entity reconstruction

This is the first version of that model.
It is meant to solve authored multi-system saves now, while leaving room for more complete world reconstruction later.

## Why This Exists

The old Lite path was good at:
- saving a plain `Dictionary`
- saving a flat scene through node-owned save helpers
- restoring data onto nodes that already exist

It was weak at:
- organizing one gameplay domain across several nodes
- controlling restore order
- integrating with user-owned factories such as `EntityFactory.LoadEntityFromSave(save_data)`
- expressing nested save structure without one huge flat key namespace

The save graph addresses those problems directly.

## Roles

### 1. SaveFlow

`SaveFlow` remains the singleton runtime entry.

It now acts as the save manager and exposes:
- `save_scope(slot_id, scope_root, meta, pipeline_control)`
- `load_scope(slot_id, scope_root, strict, pipeline_control)`
- `gather_scope(scope_root, pipeline_control)`
- `apply_scope(scope_root, scope_payload, strict, pipeline_control)`
- `inspect_scope(scope_root)`
- `restore_entities(descriptors, context, strict)`

Responsibility:
- save/load slot IO
- graph traversal
- lifecycle ordering
- diagnostics
- runtime restore orchestration

## 2. SaveFlowScope

`SaveFlowScope` is a composite node.

It represents a logical domain such as:
- `player`
- `world`
- `settings`
- `party`
- `spawned_enemies`

It can contain:
- child `SaveFlowScope` nodes
- child `SaveFlowSource` nodes

Scope lifecycle:
- `before_save(context)`
- `before_load(payload, context)`
- `after_load(payload, context)`

Current traversal is ordered by `phase` first, then tree order.
That is deliberate for v1. It gives explicit and predictable restore ordering
without adding a full dependency solver yet.

## 3. SaveFlowSource

`SaveFlowSource` is the leaf abstraction.

It is a focused adapter that gathers and applies one slice of state.

Required methods:
- `gather_save_data()`
- `apply_save_data(data)`

Optional lifecycle:
- `before_save(context)`
- `before_load(payload, context)`
- `after_load(payload, context)`

Optional metadata:
- `get_source_key()`
- `describe_source()`

`SaveFlowNodeSource` now fits here as the main node/object leaf.
That means exported-field persistence remains the fast path, but it is no longer the only architectural model.

## 4. Runtime Restore Seam

The runtime seam exists so SaveFlow does not fight the game's own runtime systems.

SaveFlow should not directly replace:
- entity factories
- object pools
- dependency injection
- combat registration
- AI setup

Instead, SaveFlow delegates runtime entity work to a factory-backed restore seam.

Current lower-level contract:
- `can_handle(type_key)`
- `find_existing(persistent_id, context)`
- `spawn_from_save(descriptor, context)`
- `apply_saved_data(node, payload, context)`
- optional `remove_extra(node, context)`

This lets projects route restoration through systems such as:

```gdscript
EntityFactory.load_entity_from_save(save_data)
```

The factory remains the source of truth for how the entity is created.
SaveFlow only coordinates when restoration should happen.

In the current user-facing model, this lower-level seam is usually reached through:
- `SaveFlowEntityCollectionSource`
- `SaveFlowEntityFactory`

## Payload Shape

The save graph payload is currently:

```gdscript
{
    "scope_key": "root",
    "entries": [
        {
            "kind": "scope",
            "key": "player",
            "data": {
                "scope_key": "player",
                "entries": [...]
            }
        },
        {
            "kind": "source",
            "key": "core",
            "data": {
                "hp": 100,
                "coins": 9
            }
        }
    ]
}
```

This shape is intentionally readable and stable enough for inspection.

## Lifecycle Semantics

Current v1 ordering:

1. `scope.before_save(context)`
2. gather child scopes/sources by `phase`, then tree order
3. `scope.before_load(payload, context)`
4. apply child scopes/sources by `phase`, then tree order
5. `scope.after_load(payload, context)`

This is not yet a full dependency graph.
It is a deterministic restore pipeline with enough structure for authored systems.

`SaveFlowPipelineControl` is the user-facing control object for this local
pipeline. It exposes typed callback events while keeping `context.values` as the
plain dictionary passed to existing scope/source hooks:

```gdscript
var control := SaveFlowPipelineControl.new()
control.before_load = func(event: SaveFlowPipelineEvent) -> void:
    print("Loading slot: ", event.slot_id)

control.before_apply_source = func(event: SaveFlowPipelineEvent) -> void:
    if event.key == "inventory" and not inventory_ready:
        event.cancel("Inventory source is not ready.")

control.after_load = func(_event: SaveFlowPipelineEvent) -> void:
    refresh_hud_after_restore()

var result := SaveFlow.load_scope("slot_1", $SaveGraphRoot, true, control)
```

For scene-authored integration, `SaveFlowPipelineSignals` can be added under a
`SaveFlowScope` or `SaveFlowSource` and connected through Godot's Node > Signals
panel. It emits the same local lifecycle events, including source gather/apply
and scope save/load stages. It is a non-serialized pipeline helper; NodeSource
does not treat it as a child participant or a gameplay child node.

`SaveFlowPipelineContext` is the diagnostic and shared-data support object
inside the control. SaveFlow records an ordered trace on the context and returns
it in result metadata:

```gdscript
var control := SaveFlowPipelineControl.new()
control.context.values["events"] = []

var result := SaveFlow.load_scope("slot_1", $SaveGraphRoot, true, control)
print(result.meta["pipeline_trace"])
```

Trace stages include:
- `before_load`
- `before_save_scope`
- `after_save_scope`
- `before_load_scope`
- `after_load_scope`
- `before_gather_source`
- `after_gather_source`
- `before_apply_source`
- `after_apply_source`
- `scope.before_save`
- `source.before_save`
- `source.gathered`
- `scope.before_load`
- `source.before_load`
- `source.apply`
- `source.after_load`
- `scope.after_load`

This is Lite-level lifecycle visibility. It is not a multi-scene scheduler,
resource-ready gate, migration pipeline, or late-reference resolver.

## Diagnostics

`inspect_scope(scope_root)` returns a graph diagnostic tree.

It reports:
- scope validity
- duplicate keys
- source descriptions
- component save plans where available

In v1, graph sources are also validated before gather/apply.
If a `SaveFlowNodeSource` target disappears, strict `load_scope()` now fails instead of silently succeeding.

That is important because a missing runtime target is not a successful restore.

## Example Hierarchy

```text
SaveGraphRoot
|- PlayerScope
|  |- PlayerCoreSource
|  |- PartyScope
|     |- AriaSource
|     |- BramSource
|- WorldScope
|  |- WorldStateSource
|  |- QuestStateSource
|  |- EnemyScope
|     |- WolfAlphaSource
|     |- SlimeBetaSource
|- SettingsScope
   |- SettingsStateSource
```

This is the shape used by the complex sandbox.

## Lite Boundaries

What v1 solves well:
- authored multi-system saves
- explicit save hierarchy
- better restore ordering
- clearer diagnostics
- entity-factory-based runtime integration seams

What v1 does not solve yet:
- exact runtime entity sync policies
- automatic removal of extra runtime entities
- built-in persistent ID generation
- reference repair across objects
- schema migration
- async save/load

Those should remain part of later Lite iterations or Pro features.

## Recommended Usage

Use `save_scene()` when:
- the project is small
- one scene root is a good mental model
- a flat key space is still manageable

Use `save_scope()` when:
- one system spans multiple nodes
- restore order matters
- nested save domains are easier to reason about
- you expect runtime entity reconstruction later

Use the runtime restore seam when:
- entities are created through a factory
- spawn logic has game-specific side effects
- pooled or registered objects must be restored through existing systems

## Bottom Line

SaveFlow v1 should no longer be framed only as a serializer with nicer node helpers.

It is now becoming a save orchestration layer:
- node sources for the easy path
- scopes for the real project path
- entity collections and entity factories for runtime world reconstruction

That is the architectural direction that can differentiate SaveFlow from smaller minimal save libraries.
