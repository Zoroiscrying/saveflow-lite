---
sidebar_position: 3
title: Typed Data Sources
---

Use typed data when the user story is:

> Save this project-owned model, not this scene node.

Lite supports two first-class typed paths:

- `SaveFlowTypedDataSource` for GDScript payload providers
- `SaveFlowTypedStateSource` for direct C# typed state

## GDScript Typed Data

Use `SaveFlowTypedDataSource` when a Resource or manager object can provide a
typed payload contract.

The on-disk payload is still a Variant/Dictionary.
The gameplay code should not have to manually maintain string keys for every
field.

Common shapes:

```text
SaveGraph
|- SettingsStateSource
|- ProfileStateSource
|- RoomStateSource
```

The Source can use:

- a typed `Resource`
- a target node that implements the payload methods
- a property on a target node that contains the typed data object

Minimal typed Resource:

```gdscript
extends SaveFlowTypedData
class_name RoomSaveData

@export var coins := 0
@export var location_name := "Start"
@export var unlocked_doors: PackedStringArray = []

func on_saveflow_post_apply(_payload: Dictionary) -> void:
	print("Room data loaded: ", location_name)
```

Then assign this Resource to a `SaveFlowTypedDataSource.data` field.
The Source will gather and apply the exported fields.

## Payload Contract

SaveFlow looks for these methods:

```gdscript
func to_saveflow_payload() -> Dictionary
func apply_saveflow_payload(payload: Dictionary) -> void
func get_saveflow_property_names() -> PackedStringArray
```

PascalCase C# equivalents are also accepted when a target object is bridged
through Godot.

## C# Typed State

Use `SaveFlowTypedStateSource` when the C# side owns one typed DTO/state object.

That Source owns:

- the current state object
- source-generated `JsonTypeInfo`
- JSON text or JSON bytes payload encoding
- default state replacement on load
- optional post-apply behavior

Use this instead of creating separate JSON and binary Source classes.
The same business state should load into the same typed object regardless of
the selected payload encoding.

## When To Use SaveFlowDataSource

Use custom `SaveFlowDataSource` when the data is not naturally represented by
one typed object or when the gather/apply steps are project-specific.

Keep it focused.
One custom Source should still own one system boundary.

## Nested Typed Data

`SaveFlowTypedData` can contain another `SaveFlowTypedData` value.

Use this for small nested models, not for entire object graphs.
If the nested object starts to feel like a separate gameplay system, give it its
own Source and include it in a Scope.
