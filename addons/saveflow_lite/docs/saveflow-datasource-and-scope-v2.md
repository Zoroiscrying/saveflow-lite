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
- `SaveFlowTypedData`
- `SaveFlowTypedDataSource`
- `SaveFlowDataSource`
- `SaveFlowScope v2` fields

## SaveFlowTypedDataSource

`SaveFlowTypedDataSource` is the low-boilerplate path for system-owned data
that can be represented by one typed payload-provider object.

The simplest business object is a typed resource:

```gdscript
class_name RoomSaveData
extends SaveFlowTypedData

@export var room_id := ""
@export var door_open := false
@export var collected_coins: PackedStringArray = []
```

Gameplay code edits normal fields:

```gdscript
room_data.door_open = true
room_data.collected_coins.append("coin_01")
```

The source converts those fields to a SaveFlow payload during save and applies
them back during load. The top-level save data is still Variant/Dictionary based,
but project code does not need to manage string keys for every child value.

After load, `SaveFlowTypedData` calls:

```gdscript
func on_saveflow_post_apply(payload: Dictionary) -> void
```

Override it when loaded fields require derived runtime refresh, such as
rebuilding UI labels, refreshing collision, spawning visuals, or recalculating
cached state. Keep ordinary field persistence in exported fields; use the hook
only for post-load effects.

`SaveFlowTypedData` is a convenience base, not a hard requirement. Any object can
be saved by `SaveFlowTypedDataSource` if it implements:

```gdscript
func to_saveflow_payload() -> Dictionary
func apply_saveflow_payload(payload: Dictionary) -> void
```

C# providers can use the same contract with PascalCase method names:

```csharp
public Dictionary ToSaveFlowPayload()
	=> SaveFlowTypedPayload.ToPayload(this);

public void ApplySaveFlowPayload(Dictionary payload)
	=> SaveFlowTypedPayload.ApplyPayload(this, payload);
```

That reflection helper is a convenience path for small or low-frequency state.
For performance-sensitive C# state, prefer the encoded payload contract:

```csharp
public Dictionary ToSaveFlowEncodedPayload()
	=> SaveFlowEncodedPayload.CreateJsonPayload(
		CaptureState(),
		MySaveJsonContext.Default.RoomSaveState,
		"my_game.room_state");

public void ApplySaveFlowEncodedPayload(Dictionary payload)
	=> SaveFlowEncodedPayload.ApplyJsonPayload(
		payload,
		MySaveJsonContext.Default.RoomSaveState,
		ApplyState);
```

With this shape, the C# side can use `System.Text.Json` source generation or a
project-owned encoder. SaveFlow stores the encoded result as one payload and
does not inspect every C# field.

For the common C# case where one DTO is the source of truth, inherit
`SaveFlowTypedStateSource` and place that node directly under the
`SaveFlowScope`/SaveGraph. It captures `SaveFlowState` during save, replaces
that state during load, and then calls `OnSaveFlowStateApplied(state)` for
post-load refresh. Use a tiny typed property around `GetSaveFlowState<T>()` /
`SetSaveFlowState(...)` when gameplay code wants a strongly typed `State`
member.
Call `InitializeSaveFlowState(initialState, MyJsonContext.Default.MyState)`
once in the source constructor to register the source-generated JSON metadata
without writing a separate `SaveFlowStateTypeInfo` override.

The default schema comes from the DTO type name in `JsonTypeInfo`, and the
default sections come from the serialized JSON property names. Override schema
when old saves must survive C# class/namespace renames; override sections only
when inspector diagnostics should show business groups instead of field names.

`SaveFlowTypedStateSource.PayloadEncoding` selects whether the source stores
the typed state as JSON text or JSON bytes. Users should not write separate JSON
and binary classes for the same business state. For advanced custom binary
encoders such as MessagePack, protobuf, MemoryPack, or `BinaryWriter`, implement
the explicit encoded-payload methods on a project-owned node or resource.

Keep the source's Godot script class non-generic:

```csharp
public partial class RoomStateSource : SaveFlowTypedStateSource
{
	private RoomSaveState State
	{
		get => GetSaveFlowState<RoomSaveState>();
		set => SetSaveFlowState(value);
	}

	public RoomStateSource()
	{
		InitializeSaveFlowState(
			new RoomSaveState(10, false, ""),
			RoomSaveJsonContext.Default.RoomSaveState);
	}
}
```

Scene shape:

```text
SaveGraph
|- RoomStateSource (C# script extends SaveFlowTypedStateSource)
```

Do not create `SaveFlowTypedStateSource<TState> : Node` or similar generic
`GodotObject` script bases. Generic DTOs, `JsonTypeInfo<T>`, and helper methods
are normal C# and are fine; generic Godot script bases can collide with Godot's
C# editor reload registration.

For authored C# data where convenience matters more than throughput, inherit
`SaveFlowTypedResource` and mark fields or properties with `[Export]`. Use
`[SaveFlowKey]` only when a stable payload key must differ from the member name,
and `[SaveFlowIgnore]` for exported editor state that should not enter the save
file.

Supported shapes:
- direct `Resource` assigned to `data`
- target `Node` that implements the two methods
- target property holding a `RefCounted`, C# object, or custom data object with the two methods
- C# target that implements `ToSaveFlowEncodedPayload` / `ApplySaveFlowEncodedPayload`

Use `SaveFlowTypedDataSource` when:
- the state is one coherent model
- exported fields or a typed object describe the data clearly
- custom gather/apply code would only copy fields into a dictionary

Do not use it when:
- the source must merge several services
- the payload needs custom validation or filtering
- restore must rebuild derived runtime state in a non-field way

## SaveFlowDataSource

`SaveFlowDataSource` is a specialized `SaveFlowSource` for non-node-field state.

It is meant for state that needs project-owned gather/apply logic, not just
field persistence.

Examples:
- quest manager progress maps
- inventory database state
- region mutation tables
- pending event queues
- unlocked codex entries

### Mental Model

Users should understand it as:

`SaveFlowNodeSource` is for "save this node object and its selected parts".

`SaveFlowTypedDataSource` is for "save this typed system-owned data model or payload provider".

`SaveFlowDataSource` is for "save this system-owned data model through custom
translation logic".

That means it is not a replacement for node sources.
It is the sibling path for manager-owned or table-owned state.

### Contract

If one typed object can provide the payload, prefer `SaveFlowTypedDataSource`.
This is the default path for new gameplay data because exported fields give the
project a visible, typed shape and avoid repeated dictionary key management.

Subclass `SaveFlowDataSource` only when custom translation is needed or the
source of truth already exists as a registry/table payload. Implement:
- `gather_data() -> Dictionary`
- `apply_data(data: Dictionary) -> void`

`SaveFlowDataSource` then adapts those into the normal graph contract:
- `gather_save_data()`
- `apply_save_data(data)`

This is still useful when the source itself should own the save logic.

### Example

```gdscript
extends SaveFlowDataSource

@export var registry: Node

func gather_data() -> Dictionary:
    if registry == null or not registry.has_method("export_save_payload"):
        return {}
    return registry.call("export_save_payload")

func apply_data(data: Dictionary) -> void:
    if registry == null or not registry.has_method("apply_save_payload"):
        return
    registry.call("apply_save_payload", data)
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
- the data already exists as dictionaries, arrays, tables, or registries
- typed exported fields would be awkward or misleading
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
