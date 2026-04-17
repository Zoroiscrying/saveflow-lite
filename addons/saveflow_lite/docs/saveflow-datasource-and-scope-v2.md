# SaveFlow DataSource And Scope v2 Notes

Updated: 2026-04-08

## Why This Exists

Commercial projects do not only save scene-node fields.

They also save:
- manager state
- tables and registries
- event queues
- profile data
- per-system runtime models

At the same time, save domains need more than a tree shape.
They also need basic save/load policy.

This note introduces:
- `SaveFlowDataSource`
- `SaveFlowScope v2` fields

## SaveFlowDataSource

`SaveFlowDataSource` is a specialized `SaveFlowSource` for non-node-field state.

It is meant for state that is already modeled as data, not as a group of exported properties on one gameplay node.

Examples:
- quest manager progress maps
- inventory database state
- region mutation tables
- pending event queues
- unlocked codex entries

### Mental Model

Users should understand it as:

`SaveFlowNodeSource` is for "save this node object and its selected parts".

`SaveFlowDataSource` is for "save this system-owned data model".

That means it is not a replacement for node sources.
It is the sibling path for manager-owned or table-owned state.

### Contract

Subclass `SaveFlowDataSource` and implement:
- `gather_data() -> Dictionary`
- `apply_data(data: Dictionary) -> void`

`SaveFlowDataSource` then adapts those into the normal graph contract:
- `gather_save_data()`
- `apply_save_data(data)`

This is still useful when the source itself should own the save logic.

### Example

```gdscript
extends SaveFlowDataSource

@export_node_path("Node") var target_path: NodePath

func gather_data() -> Dictionary:
    var manager := get_node_or_null(target_path)
    if manager == null:
        return {}
    return Dictionary(manager.system_state).duplicate(true)

func apply_data(data: Dictionary) -> void:
    var manager := get_node_or_null(target_path)
    if manager == null:
        return
    manager.system_state = data.duplicate(true)
```

Then wire it into a graph:

```text
SaveGraphRoot
|- WorldScope
   |- WorldStateDataSource
```

### When To Use It

Use `SaveFlowDataSource` when:
- the source of truth is a manager or service
- the data already exists as dictionaries, arrays, or tables
- exported fields would be awkward or misleading
- the state may affect loaded and unloaded content alike

Do not use it when a simple node source on a gameplay object is enough.

## SaveFlowScope v2

`SaveFlowScope` now carries minimal policy, not just grouping.

Fields:
- `scope_key`
- `enabled`
- `save_enabled`
- `load_enabled`
- `key_namespace`
- `phase`
- `restore_policy`

### What These Mean

`save_enabled`
- this scope is skipped during gather when false

`load_enabled`
- this scope is skipped during apply when false

`phase`
- lower phases run first
- phases are currently used to order child scopes and child sources inside a scope

`restore_policy`
- `Inherit`
- `Best Effort`
- `Strict`

`Strict` means this scope will fail if expected graph entries cannot be applied.
`Best Effort` means the scope will gather missing-key diagnostics but will not turn them into a hard failure by itself.

### Why This Matters

This is the first step toward turning scopes into true save domains.

It helps express:
- core state before dependent state
- optional domains that should not load right now
- strict gameplay domains versus best-effort cosmetic domains

## Current Boundaries

This is still not the final commercial architecture.

Still missing:
- persistent ID registry
- reference resolver
- entity collection sync policies
- migration hooks
- richer inspector and load tracing

But this step closes two important gaps:
- non-node system state is now a first-class path
- scopes now carry actual save/load policy
