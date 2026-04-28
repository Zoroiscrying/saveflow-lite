---
sidebar_position: 3
title: Source Contracts
---

All Sources participate in the same graph contract.

## SaveFlowSource

Base exported properties:

| Property | Type | Purpose |
| --- | --- | --- |
| `enabled` | `bool` | Disables the Source completely when false. |
| `save_enabled` | `bool` | Allows the Source to gather data. |
| `load_enabled` | `bool` | Allows the Source to apply data. |
| `phase` | `int` | Orders Sources inside graph operations. |

Common methods:

```gdscript
get_save_key() -> String
get_source_key() -> String
get_phase() -> int
get_saveflow_authoring_warnings() -> PackedStringArray
gather_save_data() -> Variant
apply_save_data(data: Variant, context: Dictionary = {}) -> SaveResult
```

Most users should not subclass `SaveFlowSource` directly.
Use one of the focused Sources below.

## SaveFlowDataSource

Use custom `SaveFlowDataSource` when project-specific gather/apply logic is
actually needed.

Exported properties:

| Property | Type | Purpose |
| --- | --- | --- |
| `data_version` | `int` | Local data version for this Source payload. |

Override these in your script:

```gdscript
func gather_data() -> Dictionary:
	return {}

func apply_data(data: Dictionary) -> void:
	pass
```

`SaveFlowDataSource` wraps these methods in the normal Source contract.

## SaveFlowTypedDataSource

Use when a Resource, node, or node property provides a payload contract.

Exported properties:

| Property | Type | Purpose |
| --- | --- | --- |
| `data` | `Resource` | Direct typed data object. |
| `target` | `Node` | Node that provides or owns the typed data. |
| `data_property` | `String` | Property name on `target` that contains the typed data object. |

Accepted payload methods:

```gdscript
to_saveflow_payload() -> Dictionary
apply_saveflow_payload(payload: Dictionary) -> void
get_saveflow_property_names() -> PackedStringArray
get_saveflow_payload_info() -> Dictionary
```

PascalCase equivalents are accepted for C# objects:

```csharp
ToSaveFlowPayload()
ApplySaveFlowPayload(...)
GetSaveFlowPropertyNames()
GetSaveFlowPayloadInfo()
```

## SaveFlowTypedData

`SaveFlowTypedData` is the low-boilerplate GDScript Resource base.

Override when needed:

```gdscript
func on_saveflow_post_apply(payload: Dictionary) -> void:
	pass
```

It automatically gathers exported script variables that use storage.

## SaveFlowNodeSource

Use when one Godot object owns the saved data.

Key exported properties:

| Property | Type | Purpose |
| --- | --- | --- |
| `save_key` | `String` | Optional stable key override. |
| `target` | `Node` | Optional target override. |
| `property_selection_mode` | `int` | Exported fields, additional properties, or both. |
| `additional_properties` | `PackedStringArray` | Non-exported properties that should be saved. |
| `ignored_properties` | `PackedStringArray` | Exported properties that should not be saved. |
| `include_target_built_ins` | `bool` | Enables built-in Godot node state capture. |
| `included_target_builtin_ids` | `PackedStringArray` | Explicit built-in serializer IDs. |
| `target_builtin_field_overrides` | `Dictionary` | Field whitelist per built-in serializer. |
| `included_paths` | `PackedStringArray` | Child participants included in this object payload. |
| `excluded_paths` | `PackedStringArray` | Child participants excluded from this object payload. |
| `participant_discovery_mode` | `int` | Direct children only or recursive. |

Useful helper methods:

```gdscript
clear_target_builtin_field_overrides() -> void
set_target_builtin_field_selection(serializer_id: String, field_ids: PackedStringArray) -> void
```

## SaveFlowEntityCollectionSource

Use when one runtime container owns a changing set of entities.

Key exported properties:

| Property | Type | Purpose |
| --- | --- | --- |
| `target_container` | `Node` | Runtime entity container override. |
| `failure_policy` | `int` | Report only or fail on invalid entities. |
| `restore_policy` | `int` | Apply existing, create missing, or clear and restore. |
| `include_direct_children_only` | `bool` | Controls entity discovery depth. |
| `entity_factory` | `SaveFlowEntityFactory` | Factory that restores descriptors. |
| `auto_register_factory` | `bool` | Registers factory automatically in runtime scenes. |

Policies:

```gdscript
RestorePolicy.APPLY_EXISTING
RestorePolicy.CREATE_MISSING
RestorePolicy.CLEAR_AND_RESTORE

FailurePolicy.REPORT_ONLY
FailurePolicy.FAIL_ON_MISSING_OR_INVALID
```

## SaveFlowPrefabEntityFactory

Use when one prefab maps cleanly to one entity type.

Exported properties:

| Property | Type | Purpose |
| --- | --- | --- |
| `target_container` | `Node` | Container to add restored entities to. |
| `auto_create_container` | `bool` | Create target container if missing. |
| `container_name` | `String` | Name used when auto-creating a container. |
| `type_key` | `String` | Entity type this factory handles. |
| `entity_scene` | `PackedScene` | Prefab to instantiate. |

Common methods:

```gdscript
get_supported_entity_types() -> PackedStringArray
get_target_container() -> Node
apply_saved_data(node: Node, payload: Variant, context: Dictionary = {}) -> void
```
