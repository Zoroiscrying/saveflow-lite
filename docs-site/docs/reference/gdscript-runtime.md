---
sidebar_position: 2
title: GDScript Runtime API
---

The `SaveFlow` autoload is the main GDScript runtime facade.

Use these calls from gameplay code, menu code, tests, or editor utilities.

## Configuration

```gdscript
SaveFlow.configure(settings: SaveSettings) -> SaveResult
SaveFlow.configure_with(
	save_root: String,
	slot_index_file: String,
	storage_format: int = 0,
	pretty_json_in_editor: bool = true,
	use_safe_write: bool = true,
	keep_last_backup: bool = true,
	auto_create_dirs: bool = true,
	include_meta_in_slot_file: bool = true,
	project_title: String = "",
	game_version: String = "",
	data_version: int = 1,
	save_schema: String = "main",
	enforce_save_schema_match: bool = true,
	enforce_data_version_match: bool = true,
	verify_scene_path_on_load: bool = true,
	file_extension_json: String = "json",
	file_extension_binary: String = "sav",
	log_level: int = 2
) -> SaveResult
SaveFlow.get_settings() -> SaveSettings
SaveFlow.set_storage_format(mode: int) -> SaveResult
SaveFlow.get_storage_format() -> int
```

Prefer `SaveFlow Settings` for project defaults.
Use `configure_with()` when a test scene or bootstrapper needs code-side setup.

## Save And Load Payloads

```gdscript
SaveFlow.save_slot(slot_id: String, data: Variant, meta_patch: Dictionary = {}) -> SaveResult
SaveFlow.save_data(slot_id: String, data: Variant, meta_patch: Dictionary = {}) -> SaveResult
SaveFlow.load_slot(slot_id: String) -> SaveResult
SaveFlow.load_slot_data(slot_id: String) -> SaveResult
SaveFlow.load_data(slot_id: String) -> SaveResult
SaveFlow.load_slot_or_default(slot_id: String, default_data: Variant) -> SaveResult
```

Use these when you already own the whole payload.
For scene-authored game state, prefer Scope or scene calls.

## Scene Graph Calls

```gdscript
SaveFlow.save_scene(slot_id: String, root: Node, meta_patch: Dictionary = {}, group_name: String = "saveflow") -> SaveResult
SaveFlow.load_scene(slot_id: String, root: Node, strict: bool = false, group_name: String = "saveflow") -> SaveResult
SaveFlow.save_nodes(slot_id: String, root: Node, meta_patch: Dictionary = {}, group_name: String = "saveflow") -> SaveResult
SaveFlow.load_nodes(slot_id: String, root: Node, strict: bool = false, group_name: String = "saveflow") -> SaveResult
SaveFlow.inspect_scene(root: Node, group_name: String = "saveflow") -> SaveResult
SaveFlow.apply_nodes(root: Node, saveables_data: Dictionary, strict: bool = false, group_name: String = "saveflow") -> SaveResult
```

Use scene calls when Sources are discovered from the scene tree/group.

`strict` controls whether missing payload/source situations should fail harder.
Keep it false while iterating; use strict only when the project expects an exact
graph shape.

## Scope Calls

```gdscript
SaveFlow.save_scope(slot_id: String, scope_root: SaveFlowScope, meta_patch: Dictionary = {}) -> SaveResult
SaveFlow.load_scope(slot_id: String, scope_root: SaveFlowScope, strict: bool = false) -> SaveResult
SaveFlow.gather_scope(scope_root: SaveFlowScope, pipeline_control: SaveFlowPipelineControl = null) -> SaveResult
SaveFlow.apply_scope(scope_root: SaveFlowScope, scope_payload: Dictionary, strict: bool = false, pipeline_control: SaveFlowPipelineControl = null) -> SaveResult
SaveFlow.inspect_scope(scope_root: SaveFlowScope) -> SaveResult
```

These are the recommended calls for domain-based gameplay saves.

Example:

```gdscript
var metadata := slot_workflow.build_active_slot_metadata(
	"Village Start",
	"manual",
	"Chapter 1",
	"Forest Gate",
	playtime_seconds
)
var result := SaveFlow.save_scope(slot_workflow.active_slot_id(), $RoomScope, metadata)
```

## Slot Management

```gdscript
SaveFlow.delete_slot(slot_id: String) -> SaveResult
SaveFlow.copy_slot(from_slot: String, to_slot: String, overwrite: bool = false) -> SaveResult
SaveFlow.rename_slot(old_id: String, new_id: String, overwrite: bool = false) -> SaveResult
SaveFlow.list_slots() -> SaveResult
SaveFlow.read_slot_summary(slot_id: String) -> SaveResult
SaveFlow.list_slot_summaries() -> SaveResult
SaveFlow.read_slot_metadata(slot_id: String, target_metadata: SaveFlowSlotMetadata = null) -> SaveResult
SaveFlow.read_meta(slot_id: String) -> SaveResult
SaveFlow.write_meta(slot_id: String, meta_patch: Dictionary) -> SaveResult
SaveFlow.inspect_slot_storage(slot_id: String) -> SaveResult
SaveFlow.inspect_slot_compatibility(slot_id: String) -> SaveResult
SaveFlow.validate_slot(slot_id: String) -> SaveResult
SaveFlow.get_slot_path(slot_id: String) -> SaveResult
SaveFlow.get_index_path() -> String
```

Use summary and metadata reads for save/load menus.
Avoid loading full gameplay payloads just to draw a save card.

## Metadata Builders

```gdscript
SaveFlow.build_slot_metadata_patch(...) -> Dictionary
SaveFlow.build_slot_metadata(...) -> SaveFlowSlotMetadata
SaveFlow.build_meta(slot_id: String, meta_patch: Dictionary = {}) -> Dictionary
```

For most game menus, `SaveFlowSlotWorkflow.build_active_slot_metadata()` is the
friendlier entry point.

## Current Data Helpers

```gdscript
SaveFlow.set_value(path: String, value: Variant) -> SaveResult
SaveFlow.get_value(path: String, default_value: Variant = null) -> SaveResult
SaveFlow.clear_current() -> SaveResult
SaveFlow.get_current_data() -> SaveResult
SaveFlow.save_current(slot_id: String, meta_patch: Dictionary = {}) -> SaveResult
SaveFlow.load_current(slot_id: String) -> SaveResult
```

These are lower-level helpers for projects that want a current in-memory data
store.
Most scene-authored workflows can ignore them.

## Runtime Entity Helpers

```gdscript
SaveFlow.register_entity_factory(factory: SaveFlowEntityFactory) -> SaveResult
SaveFlow.unregister_entity_factory(factory: SaveFlowEntityFactory) -> SaveResult
SaveFlow.clear_entity_factories() -> SaveResult
SaveFlow.restore_entities(descriptors: Array, context: Dictionary = {}, strict: bool = false, options: Dictionary = {}) -> SaveResult
```

`SaveFlowEntityCollectionSource` normally handles factory registration for the
standard scene-owned workflow.

Use these directly only when your project owns factory registration manually.

## Dev Save Helpers

```gdscript
SaveFlow.save_dev_named_entry(entry_name: String) -> SaveResult
SaveFlow.load_dev_named_entry(entry_name: String) -> SaveResult
```

These are for editor/development workflows.
Do not build shipped save menus around dev named entries.
