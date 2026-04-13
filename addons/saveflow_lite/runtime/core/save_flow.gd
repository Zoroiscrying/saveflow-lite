## SaveFlow is the runtime singleton that owns slot IO, save graph execution,
## and runtime-entity restore orchestration.
extends Node

const FORMAT_AUTO := 0
const FORMAT_JSON := 1
const FORMAT_BINARY := 2
const INDEX_VERSION := 1
const INDEX_SLOTS_KEY := "slots"
const TEMP_FILE_SUFFIX := ".tmp"

var _settings: SaveSettings = SaveSettings.new()
var _current_data: Dictionary = {}
var _entity_factories: Array = []


func configure(settings: SaveSettings) -> SaveResult:
	if settings == null:
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"settings cannot be null"
		)
	_settings = settings
	return _ok_result(_settings)


func configure_with(options: Dictionary = {}) -> SaveResult:
	var settings := SaveSettings.new()
	var merge_result: SaveResult = _apply_settings_options(settings, options)
	if not merge_result.ok:
		return merge_result
	return configure(settings)


func get_settings() -> SaveSettings:
	return _settings


func set_storage_format(mode: int) -> SaveResult:
	if not _is_valid_format(mode):
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"storage format is invalid",
			{"mode": mode}
		)
	_settings.storage_format = mode
	return _ok_result({"storage_format": mode})


func get_storage_format() -> int:
	return _settings.storage_format


func resolve_storage_format() -> int:
	if _settings.storage_format != FORMAT_AUTO:
		return _settings.storage_format
	if Engine.is_editor_hint():
		return FORMAT_JSON
	return FORMAT_BINARY


func save_slot(slot_id: String, data: Variant, meta: Dictionary = {}) -> SaveResult:
	if slot_id.is_empty():
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"slot_id cannot be empty"
		)

	var payload: Dictionary = {
		"meta": build_meta(slot_id, meta),
		"data": data,
	}
	return _save_payload(slot_id, payload, resolve_storage_format())


func save_data(slot_id: String, data: Variant, meta: Dictionary = {}) -> SaveResult:
	return save_slot(slot_id, data, meta)


func save_scene(slot_id: String, root: Node, meta: Dictionary = {}, group_name := "saveflow") -> SaveResult:
	return save_nodes(slot_id, root, meta, group_name)


func save_scope(slot_id: String, scope_root: SaveFlowScope, meta: Dictionary = {}, context: Dictionary = {}) -> SaveResult:
	var gather_result: SaveResult = gather_scope(scope_root, context)
	if not gather_result.ok:
		return gather_result

	var final_meta: Dictionary = meta.duplicate(true)
	if not final_meta.has("scene_path") and is_instance_valid(scope_root):
		final_meta["scene_path"] = scope_root.scene_file_path
	return save_slot(slot_id, {"graph": gather_result.data}, final_meta)


func load_slot(slot_id: String) -> SaveResult:
	var locate_result: SaveResult = _locate_slot(slot_id)
	if not locate_result.ok:
		return locate_result

	var path: String = String(locate_result.data["path"])
	var format: int = int(locate_result.data["format"])
	var read_result: SaveResult = _read_payload_file(path, format)
	if not read_result.ok:
		return read_result

	var payload: Dictionary = read_result.data
	if not _is_valid_payload(payload):
		return _error_result(
			SaveError.INVALID_FORMAT,
			"INVALID_FORMAT",
			"save payload must contain meta and data",
			{"slot_id": slot_id, "path": path}
		)

	return _ok_result(payload, {"slot_id": slot_id, "path": path, "format": format})


func load_slot_data(slot_id: String) -> SaveResult:
	var result: SaveResult = load_slot(slot_id)
	if not result.ok:
		return result
	return _ok_result(result.data["data"], result.meta)


func load_data(slot_id: String) -> SaveResult:
	return load_slot_data(slot_id)


func load_scene(slot_id: String, root: Node, strict := false, group_name := "saveflow") -> SaveResult:
	return load_nodes(slot_id, root, strict, group_name)


func load_scope(slot_id: String, scope_root: SaveFlowScope, strict := false, context: Dictionary = {}) -> SaveResult:
	var load_result: SaveResult = load_slot_data(slot_id)
	if not load_result.ok:
		return load_result
	if not (load_result.data is Dictionary):
		return _error_result(
			SaveError.INVALID_FORMAT,
			"INVALID_FORMAT",
			"slot data must be a dictionary to load a save graph",
			{"slot_id": slot_id}
		)

	var payload: Dictionary = load_result.data
	if not payload.has("graph") or not (payload["graph"] is Dictionary):
		return _error_result(
			SaveError.INVALID_FORMAT,
			"INVALID_FORMAT",
			"slot data must contain a graph dictionary",
			{"slot_id": slot_id}
		)
	return apply_scope(scope_root, payload["graph"], strict, context)


func load_slot_or_default(slot_id: String, default_data: Variant) -> SaveResult:
	var result: SaveResult = load_slot(slot_id)
	if result.ok:
		return result
	return _ok_result(default_data, {"slot_id": slot_id, "used_default": true})


func gather_scope(scope_root: SaveFlowScope, context: Dictionary = {}) -> SaveResult:
	if not is_instance_valid(scope_root):
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"scope_root cannot be null"
		)
	if not scope_root.can_save_scope():
		return _error_result(
			SaveError.INVALID_SAVEABLE,
			"INVALID_SAVEABLE",
			"scope_root is not enabled for save",
			{"scope_key": scope_root.get_scope_key()}
		)
	return _gather_scope_payload(scope_root, context)


## Scope apply is the graph-level restore entry point. Individual sources keep
## their own gather/apply contracts, while SaveFlow handles traversal order and
## strict-mode result propagation.
func apply_scope(scope_root: SaveFlowScope, scope_payload: Dictionary, strict := false, context: Dictionary = {}) -> SaveResult:
	if not is_instance_valid(scope_root):
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"scope_root cannot be null"
		)
	if not scope_root.can_load_scope():
		return _error_result(
			SaveError.INVALID_SAVEABLE,
			"INVALID_SAVEABLE",
			"scope_root is not enabled for load",
			{"scope_key": scope_root.get_scope_key()}
		)
	return _apply_scope_payload(scope_root, scope_payload, strict, context)


func inspect_scope(scope_root: SaveFlowScope) -> SaveResult:
	if not is_instance_valid(scope_root):
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"scope_root cannot be null"
		)
	return _inspect_scope_payload(scope_root)


func register_entity_factory(factory: SaveFlowEntityFactory) -> SaveResult:
	if factory == null:
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"entity factory cannot be null"
		)
	if _entity_factories.has(factory):
		return _ok_result({"factory_count": _entity_factories.size()}, {"already_registered": true})
	_entity_factories.append(factory)
	return _ok_result({"factory_count": _entity_factories.size()})


func unregister_entity_factory(factory: SaveFlowEntityFactory) -> SaveResult:
	if factory == null:
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"entity factory cannot be null"
		)
	_entity_factories.erase(factory)
	return _ok_result({"factory_count": _entity_factories.size()})


func clear_entity_factories() -> SaveResult:
	_entity_factories.clear()
	return _ok_result()


## Runtime entity restore is split on purpose:
## - collection sources decide which descriptors belong to a runtime set
## - factories decide how entities are found, spawned, and hydrated
## SaveFlow only coordinates the descriptor loop and aggregate result.
func restore_entities(descriptors: Array, context: Dictionary = {}, strict := false, options: Dictionary = {}) -> SaveResult:
	var restored_count := 0
	var spawned_count := 0
	var missing_types: PackedStringArray = []
	var failed_ids: PackedStringArray = []
	var allow_create_missing := bool(options.get("allow_create_missing", true))

	for descriptor_variant in descriptors:
		if not (descriptor_variant is Dictionary):
			return _error_result(
				SaveError.INVALID_ARGUMENT,
				"INVALID_ARGUMENT",
				"entity descriptor must be a dictionary"
			)
		var descriptor: Dictionary = descriptor_variant
		var type_key: String = String(descriptor.get("type_key", ""))
		if type_key.is_empty():
			return _error_result(
				SaveError.INVALID_ARGUMENT,
				"INVALID_ARGUMENT",
				"entity descriptor must contain type_key",
				{"descriptor": descriptor}
			)

		var persistent_id: String = String(descriptor.get("persistent_id", ""))
		var factory: SaveFlowEntityFactory = _find_entity_factory(type_key)
		var node: Node = null
		if factory == null:
			_append_unique_string(missing_types, type_key)
			continue
		node = factory.find_existing_entity(persistent_id, context)
		if node == null and allow_create_missing:
			node = factory.spawn_entity_from_save(descriptor, context)
			if node != null:
				spawned_count += 1
		if node == null:
			_append_unique_string(failed_ids, persistent_id if not persistent_id.is_empty() else type_key)
			continue

		var payload: Variant = descriptor.get("payload", {})
		var entity_graph_result: Dictionary = _try_apply_entity_graph_payload(node, payload, strict, context)
		if bool(entity_graph_result.get("handled", false)):
			if not bool(entity_graph_result.get("ok", false)):
				_append_unique_string(failed_ids, persistent_id if not persistent_id.is_empty() else type_key)
				continue
		else:
			factory.apply_saved_data(node, payload, context)
		restored_count += 1

	if strict and (not missing_types.is_empty() or not failed_ids.is_empty()):
		return _error_result(
			SaveError.INVALID_SAVEABLE,
			"INVALID_SAVEABLE",
			"failed to restore one or more entity descriptors",
			{
				"missing_types": missing_types,
				"failed_ids": failed_ids,
				"restored_count": restored_count,
				"spawned_count": spawned_count,
			}
		)

	return _ok_result(
		{
			"restored_count": restored_count,
			"spawned_count": spawned_count,
			"missing_types": missing_types,
			"failed_ids": failed_ids,
		}
	)


func _try_apply_entity_graph_payload(node: Node, payload: Variant, strict := false, context: Dictionary = {}) -> Dictionary:
	if not (payload is Dictionary):
		return {"handled": false, "ok": false}

	var payload_dict: Dictionary = payload
	var mode: String = String(payload_dict.get("mode", ""))
	if mode != "scope_graph":
		return {"handled": false, "ok": false}

	var scope_payload: Variant = payload_dict.get("graph", null)
	if not (scope_payload is Dictionary):
		return {"handled": true, "ok": false}

	var entity_scope: SaveFlowScope = _resolve_entity_scope_from_payload(node, payload_dict)
	if entity_scope == null:
		return {"handled": true, "ok": false}

	var apply_result: SaveResult = apply_scope(entity_scope, scope_payload, strict, context)
	return {
		"handled": true,
		"ok": apply_result.ok,
		"result": apply_result,
	}


func _resolve_entity_scope_from_payload(node: Node, payload: Dictionary) -> SaveFlowScope:
	if not is_instance_valid(node):
		return null

	var scope_path: String = String(payload.get("scope_path", ""))
	if scope_path == "." and node is SaveFlowScope:
		return node
	if not scope_path.is_empty() and scope_path != ".":
		return node.get_node_or_null(NodePath(scope_path)) as SaveFlowScope

	for child in node.get_children():
		if child is SaveFlowScope:
			return child
	return null


func save_nodes(slot_id: String, root: Node, meta: Dictionary = {}, group_name := "saveflow") -> SaveResult:
	var collect_result: SaveResult = collect_nodes(root, group_name)
	if not collect_result.ok:
		return collect_result

	var payload: Dictionary = {
		"saveables": collect_result.data,
	}
	var final_meta: Dictionary = meta.duplicate(true)
	if not final_meta.has("scene_path") and is_instance_valid(root):
		final_meta["scene_path"] = root.scene_file_path
	return save_slot(slot_id, payload, final_meta)


func load_nodes(slot_id: String, root: Node, strict := false, group_name := "saveflow") -> SaveResult:
	var load_result: SaveResult = load_slot_data(slot_id)
	if not load_result.ok:
		return load_result
	if not (load_result.data is Dictionary):
		return _error_result(
			SaveError.INVALID_FORMAT,
			"INVALID_FORMAT",
			"slot data must be a dictionary to load saveable nodes",
			{"slot_id": slot_id}
		)

	var payload: Dictionary = load_result.data
	if not payload.has("saveables") or not (payload["saveables"] is Dictionary):
		return _error_result(
			SaveError.INVALID_FORMAT,
			"INVALID_FORMAT",
			"slot data must contain a saveables dictionary",
			{"slot_id": slot_id}
		)
	return apply_nodes(root, payload["saveables"], strict, group_name)


func inspect_scene(root: Node, group_name := "saveflow") -> SaveResult:
	if not is_instance_valid(root):
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"root cannot be null"
		)

	var entries: Array = []
	var seen_keys: Dictionary = {}
	var duplicate_keys: PackedStringArray = []
	for node in _collect_saveable_nodes(root, group_name):
		var describe_result: SaveResult = _describe_saveable_node(root, node)
		if not describe_result.ok:
			return describe_result
		var entry: Dictionary = describe_result.data
		var key: String = String(entry.get("save_key", ""))
		if key.is_empty():
			entry["valid"] = false
			entry["issues"] = PackedStringArray(["EMPTY_SAVE_KEY"])
		elif seen_keys.has(key):
			_append_unique_string(duplicate_keys, key)
			var issues: PackedStringArray = PackedStringArray(entry.get("issues", PackedStringArray()))
			_append_unique_string(issues, "DUPLICATE_SAVE_KEY")
			entry["issues"] = issues
			entry["valid"] = false
		else:
			seen_keys[key] = true
		entries.append(entry)

	var valid := duplicate_keys.is_empty()
	for entry in entries:
		if not bool(entry.get("valid", true)):
			valid = false
			break

	return _ok_result(
		{
			"valid": valid,
			"entries": entries,
			"duplicate_keys": duplicate_keys,
		},
		{
			"root_path": _describe_root(root),
			"group_name": group_name,
			"saveable_count": entries.size(),
		}
	)


func collect_nodes(root: Node, group_name := "saveflow") -> SaveResult:
	if not is_instance_valid(root):
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"root cannot be null"
		)

	var saveables: Dictionary = {}
	var visited_count := 0
	for node in _collect_saveable_nodes(root, group_name):
		visited_count += 1
		var entry_result: SaveResult = _collect_saveable_entry(root, node)
		if not entry_result.ok:
			return entry_result
		var entry: Dictionary = entry_result.data
		var key: String = String(entry["save_key"])
		var data: Variant = entry["data"]
		if saveables.has(key):
			return _error_result(
				SaveError.DUPLICATE_SAVE_KEY,
				"DUPLICATE_SAVE_KEY",
				"multiple saveables resolved to the same save key",
				{
					"root_path": _describe_root(root),
					"save_key": key,
				}
			)
		saveables[key] = data

	return _ok_result(
		saveables,
		{
			"root_path": _describe_root(root),
			"group_name": group_name,
			"saveable_count": saveables.size(),
			"visited_count": visited_count,
		}
	)


func apply_nodes(root: Node, saveables_data: Dictionary, strict := false, group_name := "saveflow") -> SaveResult:
	if not is_instance_valid(root):
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"root cannot be null"
		)

	var lookup_result: SaveResult = _build_saveable_lookup(root, group_name)
	if not lookup_result.ok:
		return lookup_result
	var node_lookup: Dictionary = lookup_result.data

	var applied_count := 0
	var missing_keys: Array = []
	for key in saveables_data.keys():
		var key_string: String = str(key)
		if not node_lookup.has(key_string):
			missing_keys.append(key_string)
			continue

		var target: Node = node_lookup[key_string]
		if not target.has_method("apply_save_data"):
			missing_keys.append(key_string)
			continue

		target.call("apply_save_data", saveables_data[key])
		applied_count += 1

	if strict and not missing_keys.is_empty():
		return _error_result(
			SaveError.INVALID_FORMAT,
			"INVALID_FORMAT",
			"failed to apply some saveable entries",
			{
				"root_path": _describe_root(root),
				"missing_keys": missing_keys,
				"applied_count": applied_count,
			}
		)

	return _ok_result(
		{
			"applied_count": applied_count,
			"missing_keys": missing_keys,
		},
		{
			"root_path": _describe_root(root),
			"group_name": group_name,
		}
	)


func delete_slot(slot_id: String) -> SaveResult:
	var locate_result: SaveResult = _locate_slot(slot_id)
	if not locate_result.ok:
		return locate_result

	var path: String = String(locate_result.data["path"])
	var remove_error: int = DirAccess.remove_absolute(path)
	if remove_error != OK:
		return _error_result(
			SaveError.DELETE_FAILED,
			"DELETE_FAILED",
			"failed to delete slot file",
			{"slot_id": slot_id, "path": path, "dir_error": remove_error}
		)

	var index_result: SaveResult = _remove_index_entry(slot_id)
	if not index_result.ok:
		return index_result

	return _ok_result({"slot_id": slot_id, "path": path})


func copy_slot(from_slot: String, to_slot: String, overwrite := false) -> SaveResult:
	if from_slot.is_empty() or to_slot.is_empty():
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"from_slot and to_slot cannot be empty"
		)
	if from_slot == to_slot:
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"from_slot and to_slot must be different"
		)

	if slot_exists(to_slot) and not overwrite:
		return _error_result(
			SaveError.SLOT_ALREADY_EXISTS,
			"SLOT_ALREADY_EXISTS",
			"target slot already exists",
			{"slot_id": to_slot}
		)

	var source_result: SaveResult = load_slot(from_slot)
	if not source_result.ok:
		return source_result

	var payload: Dictionary = source_result.data.duplicate(true)
	var meta: Dictionary = payload["meta"]
	meta["slot_id"] = to_slot
	meta["saved_at_unix"] = Time.get_unix_time_from_system()
	if String(meta.get("display_name", "")).is_empty() or String(meta.get("display_name", "")) == from_slot:
		meta["display_name"] = to_slot
	payload["meta"] = meta

	var source_format: int = int(source_result.meta.get("format", resolve_storage_format()))
	return _save_payload(to_slot, payload, source_format)


func rename_slot(old_id: String, new_id: String, overwrite := false) -> SaveResult:
	if old_id.is_empty() or new_id.is_empty():
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"old_id and new_id cannot be empty"
		)
	if old_id == new_id:
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"old_id and new_id must be different"
		)

	if slot_exists(new_id) and not overwrite:
		return _error_result(
			SaveError.SLOT_ALREADY_EXISTS,
			"SLOT_ALREADY_EXISTS",
			"target slot already exists",
			{"slot_id": new_id}
		)

	var source_result: SaveResult = load_slot(old_id)
	if not source_result.ok:
		return source_result

	var payload: Dictionary = source_result.data.duplicate(true)
	var meta: Dictionary = payload["meta"]
	meta["slot_id"] = new_id
	if String(meta.get("display_name", "")) == old_id:
		meta["display_name"] = new_id
	payload["meta"] = meta

	var source_format: int = int(source_result.meta.get("format", resolve_storage_format()))
	var save_result: SaveResult = _save_payload(new_id, payload, source_format)
	if not save_result.ok:
		return save_result

	var delete_result: SaveResult = delete_slot(old_id)
	if not delete_result.ok:
		return delete_result

	return save_result


func slot_exists(slot_id: String) -> bool:
	var locate_result: SaveResult = _locate_slot(slot_id)
	return locate_result.ok


func list_slots() -> SaveResult:
	var index_result: SaveResult = _read_index_data()
	if not index_result.ok:
		return index_result

	var slots_map: Dictionary = index_result.data[INDEX_SLOTS_KEY]
	var slot_infos: Array = []
	for slot_id in slots_map.keys():
		var entry: Dictionary = slots_map[slot_id]
		if entry.has("meta"):
			slot_infos.append(entry["meta"].duplicate(true))
	return _ok_result(slot_infos)


func read_meta(slot_id: String) -> SaveResult:
	var load_result: SaveResult = load_slot(slot_id)
	if not load_result.ok:
		return load_result
	return _ok_result(load_result.data["meta"].duplicate(true), load_result.meta)


func write_meta(slot_id: String, meta_patch: Dictionary) -> SaveResult:
	var load_result: SaveResult = load_slot(slot_id)
	if not load_result.ok:
		return load_result

	var payload: Dictionary = load_result.data.duplicate(true)
	var meta: Dictionary = payload["meta"]
	for key in meta_patch.keys():
		meta[key] = meta_patch[key]
	payload["meta"] = meta

	var format: int = int(load_result.meta.get("format", resolve_storage_format()))
	return _save_payload(slot_id, payload, format)


func _apply_settings_options(settings: SaveSettings, options: Dictionary) -> SaveResult:
	for key in options.keys():
		var property_name: String = str(key)
		if not _has_object_property(settings, property_name):
			return _error_result(
				SaveError.INVALID_ARGUMENT,
				"INVALID_ARGUMENT",
				"unknown save setting",
				{"setting": property_name}
			)
		settings.set(property_name, options[key])
	return _ok_result(settings)


func build_meta(slot_id: String, meta_patch: Dictionary = {}) -> Dictionary:
	var base_meta: Dictionary = {
		"slot_id": slot_id,
		"display_name": slot_id,
		"saved_at_unix": Time.get_unix_time_from_system(),
		"scene_path": "",
		"playtime_seconds": 0,
		"game_version": "",
		"data_version": 1,
	}
	for key in meta_patch.keys():
		base_meta[key] = meta_patch[key]
	return base_meta


func set_value(path: String, value: Variant) -> SaveResult:
	if path.is_empty():
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"path cannot be empty"
		)
	_current_data[path] = value
	return _ok_result(value, {"path": path})


func get_value(path: String, default_value: Variant = null) -> SaveResult:
	if _current_data.has(path):
		return _ok_result(_current_data[path], {"path": path})
	return _ok_result(default_value, {"path": path, "used_default": true})


func clear_current() -> SaveResult:
	_current_data.clear()
	return _ok_result()


func get_current_data() -> SaveResult:
	return _ok_result(_current_data.duplicate(true))


func save_current(slot_id: String, meta: Dictionary = {}) -> SaveResult:
	return save_slot(slot_id, _current_data.duplicate(true), meta)


func load_current(slot_id: String) -> SaveResult:
	var result: SaveResult = load_slot(slot_id)
	if result.ok and result.data is Dictionary and result.data.has("data") and result.data["data"] is Dictionary:
		_current_data = result.data["data"].duplicate(true)
	return result


func validate_slot(slot_id: String) -> SaveResult:
	var load_result: SaveResult = load_slot(slot_id)
	if not load_result.ok:
		return load_result
	return _ok_result(
		{
			"slot_id": slot_id,
			"valid": true,
			"format": load_result.meta.get("format", resolve_storage_format()),
			"path": load_result.meta.get("path", "")
		},
		load_result.meta
	)


func get_slot_path(slot_id: String) -> SaveResult:
	if slot_id.is_empty():
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"slot_id cannot be empty"
		)

	var locate_result: SaveResult = _locate_slot(slot_id)
	if locate_result.ok:
		return _ok_result(String(locate_result.data["path"]), locate_result.meta)

	var path: String = _build_slot_path(slot_id, resolve_storage_format())
	return _ok_result(path, {"slot_id": slot_id, "resolved": false})


func get_index_path() -> String:
	return _settings.slot_index_file


func _save_payload(slot_id: String, payload: Dictionary, format: int) -> SaveResult:
	if not _is_valid_payload(payload):
		return _error_result(
			SaveError.INVALID_FORMAT,
			"INVALID_FORMAT",
			"payload must contain meta and data",
			{"slot_id": slot_id}
		)

	var path: String = _build_slot_path(slot_id, format)
	var ensure_result: SaveResult = _ensure_parent_dir(path)
	if not ensure_result.ok:
		return ensure_result

	var previous_result: SaveResult = _locate_slot(slot_id, false)
	var previous_path: String = ""
	if previous_result.ok:
		previous_path = String(previous_result.data["path"])

	var write_result: SaveResult = _write_payload_file(path, payload, format)
	if not write_result.ok:
		return write_result

	if previous_path != "" and previous_path != path and FileAccess.file_exists(previous_path):
		DirAccess.remove_absolute(previous_path)

	var index_result: SaveResult = _upsert_index_entry(slot_id, path, format, payload["meta"])
	if not index_result.ok:
		return index_result

	return _ok_result(payload, {"slot_id": slot_id, "path": path, "format": format})


func _collect_saveable_nodes(root: Node, group_name: String) -> Array:
	var results: Array = []
	_collect_saveable_nodes_recursive(root, root, results, group_name)
	return results


func _collect_saveable_nodes_recursive(root: Node, current: Node, results: Array, group_name: String) -> void:
	if current != root and _is_saveable_node(current, group_name):
		results.append(current)

	for child in current.get_children():
		if child is Node:
			_collect_saveable_nodes_recursive(root, child, results, group_name)


func _is_saveable_node(node: Node, _group_name: String) -> bool:
	if not is_instance_valid(node):
		return false
	if node is SaveFlowSource:
		return node.is_source_enabled()
	return false


func _build_saveable_lookup(root: Node, group_name: String) -> SaveResult:
	var node_lookup: Dictionary = {}
	for node in _collect_saveable_nodes(root, group_name):
		var key: String = _resolve_saveable_key(root, node)
		if key.is_empty():
			return _error_result(
				SaveError.INVALID_SAVEABLE,
				"INVALID_SAVEABLE",
				"saveable resolved to an empty save key",
				{"root_path": _describe_root(root), "node_path": _describe_node_path(node)}
			)
		if node_lookup.has(key):
			return _error_result(
				SaveError.DUPLICATE_SAVE_KEY,
				"DUPLICATE_SAVE_KEY",
				"multiple saveables resolved to the same save key",
				{"root_path": _describe_root(root), "save_key": key}
			)
		node_lookup[key] = node
	return _ok_result(node_lookup)


func _collect_saveable_entry(root: Node, node: Node) -> SaveResult:
	var describe_result: SaveResult = _describe_saveable_node(root, node)
	if not describe_result.ok:
		return describe_result
	var report: Dictionary = describe_result.data
	if not bool(report.get("valid", true)):
		return _error_result(
			SaveError.INVALID_SAVEABLE,
			"INVALID_SAVEABLE",
			"saveable is not ready to be collected",
			{
				"root_path": _describe_root(root),
				"node_path": String(report.get("node_path", "")),
				"save_key": String(report.get("save_key", "")),
				"issues": report.get("issues", PackedStringArray()),
			}
		)

	var key: String = String(report.get("save_key", ""))
	if key.is_empty():
		return _error_result(
			SaveError.INVALID_SAVEABLE,
			"INVALID_SAVEABLE",
			"saveable resolved to an empty save key",
			{"root_path": _describe_root(root), "node_path": String(report.get("node_path", ""))}
		)

	var data: Variant = _gather_source_payload(node)
	return _ok_result(
		{
			"save_key": key,
			"data": data,
			"report": report,
		}
	)


func _describe_saveable_node(root: Node, node: Node) -> SaveResult:
	var save_key: String = _resolve_saveable_key(root, node)
	var issues: PackedStringArray = []
	var entry: Dictionary = {
		"node_path": _describe_node_path(node),
		"save_key": save_key,
		"kind": _describe_saveable_kind(node),
		"valid": true,
		"issues": issues,
	}

	if save_key.is_empty():
		entry["valid"] = false
		issues.append("EMPTY_SAVE_KEY")

	if node is SaveFlowSource:
		var source := node as SaveFlowSource
		var description: Dictionary = source.describe_source()
		if description.has("plan") and description["plan"] is Dictionary:
			var plan: Dictionary = description["plan"]
			entry["plan"] = plan
			entry["properties"] = plan.get("properties", PackedStringArray())
			entry["missing_properties"] = plan.get("missing_properties", PackedStringArray())
			if not bool(plan.get("valid", true)):
				entry["valid"] = false
				_append_unique_string(issues, String(plan.get("reason", "INVALID_SAVE_PLAN")))

	return _ok_result(entry)


func _describe_saveable_kind(node: Node) -> String:
	if node is SaveFlowDataSource:
		return "data_source"
	if node is SaveFlowSource:
		return "source"
	return "source"


func _gather_scope_payload(scope_root: SaveFlowScope, context: Dictionary = {}) -> SaveResult:
	if not scope_root.can_save_scope():
		return _ok_result(
			{
				"scope_key": scope_root.get_scope_key(),
				"entries": [],
			}
		)

	scope_root.before_save(context)
	var entries: Array = []
	var seen_keys: PackedStringArray = []
	for child in _get_ordered_graph_children(scope_root):
		if child is SaveFlowScope:
			var child_scope: SaveFlowScope = child
			if not child_scope.can_save_scope():
				continue
			var child_scope_key: String = child_scope.get_scope_key()
			if seen_keys.has("scope:%s" % child_scope_key):
				return _error_result(
					SaveError.DUPLICATE_SAVE_KEY,
					"DUPLICATE_SAVE_KEY",
					"duplicate child scope key inside save graph",
					{"scope_key": scope_root.get_scope_key(), "child_scope_key": child_scope_key}
				)
			seen_keys.append("scope:%s" % child_scope_key)
			var child_result: SaveResult = _gather_scope_payload(child_scope, context)
			if not child_result.ok:
				return child_result
			entries.append(
				{
					"kind": "scope",
					"key": child_scope_key,
					"data": child_result.data,
				}
			)
		elif _is_graph_source_node(child):
			if not _can_gather_graph_source(child):
				continue
			var source_key: String = _resolve_graph_source_key(child)
			if source_key.is_empty():
				return _error_result(
					SaveError.INVALID_SAVEABLE,
					"INVALID_SAVEABLE",
					"graph source resolved to an empty source key",
					{"scope_key": scope_root.get_scope_key(), "node_path": _describe_node_path(child)}
				)
			if seen_keys.has("source:%s" % source_key):
				return _error_result(
					SaveError.DUPLICATE_SAVE_KEY,
					"DUPLICATE_SAVE_KEY",
					"duplicate source key inside save graph",
					{"scope_key": scope_root.get_scope_key(), "source_key": source_key}
				)
			seen_keys.append("source:%s" % source_key)
			var validate_result: SaveResult = _validate_graph_source(child)
			if not validate_result.ok:
				return validate_result
			var source_data: Variant = _gather_source_payload(child, context)
			entries.append(
				{
					"kind": "source",
					"key": source_key,
					"data": source_data,
				}
			)

	return _ok_result(
		{
			"scope_key": scope_root.get_scope_key(),
			"entries": entries,
		}
	)


func _apply_scope_payload(scope_root: SaveFlowScope, scope_payload: Dictionary, strict := false, context: Dictionary = {}) -> SaveResult:
	scope_root.before_load(scope_payload, context)
	var local_strict: bool = _resolve_scope_strict(scope_root, strict)
	var payload_entries: Array = Array(scope_payload.get("entries", []))
	var source_payloads: Dictionary = {}
	var scope_payloads: Dictionary = {}
	for entry_variant in payload_entries:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var kind: String = String(entry.get("kind", ""))
		var key: String = String(entry.get("key", ""))
		if kind == "scope":
			scope_payloads[key] = entry.get("data", {})
		elif kind == "source":
			source_payloads[key] = entry.get("data", null)

	var applied_count := 0
	var missing_keys: PackedStringArray = []
	var consumed_scope_keys: PackedStringArray = []
	var consumed_source_keys: PackedStringArray = []
	for child in _get_ordered_graph_children(scope_root):
		if child is SaveFlowScope:
			var child_scope: SaveFlowScope = child
			if not child_scope.can_load_scope():
				continue
			var child_scope_key: String = child_scope.get_scope_key()
			if not scope_payloads.has(child_scope_key):
				continue
			consumed_scope_keys.append(child_scope_key)
			var child_result: SaveResult = _apply_scope_payload(child_scope, scope_payloads[child_scope_key], local_strict, context)
			if not child_result.ok:
				return child_result
			applied_count += int(child_result.data.get("applied_count", 0))
			for missing in PackedStringArray(child_result.data.get("missing_keys", PackedStringArray())):
				_append_unique_string(missing_keys, missing)
		elif _is_graph_source_node(child):
			if not _can_apply_graph_source(child):
				continue
			var source_key: String = _resolve_graph_source_key(child)
			if not source_payloads.has(source_key):
				continue
			consumed_source_keys.append(source_key)
			var validate_result: SaveResult = _validate_graph_source(child)
			if not validate_result.ok:
				_append_unique_string(missing_keys, "source:%s" % source_key)
				continue
			var apply_result: SaveResult = _apply_source_payload(child, source_payloads[source_key], context)
			if not apply_result.ok:
				return apply_result
			applied_count += 1

	for scope_key in scope_payloads.keys():
		if not consumed_scope_keys.has(String(scope_key)):
			_append_unique_string(missing_keys, "scope:%s" % String(scope_key))
	for source_key in source_payloads.keys():
		if not consumed_source_keys.has(String(source_key)):
			_append_unique_string(missing_keys, "source:%s" % String(source_key))

	scope_root.after_load(scope_payload, context)
	if local_strict and not missing_keys.is_empty():
		return _error_result(
			SaveError.INVALID_SAVEABLE,
			"INVALID_SAVEABLE",
			"failed to apply one or more graph entries",
			{
				"scope_key": scope_root.get_scope_key(),
				"missing_keys": missing_keys,
				"applied_count": applied_count,
			}
		)

	return _ok_result(
		{
			"applied_count": applied_count,
			"missing_keys": missing_keys,
		}
	)


func _inspect_scope_payload(scope_root: SaveFlowScope) -> SaveResult:
	var entries: Array = []
	var duplicate_keys: PackedStringArray = []
	var seen_keys: PackedStringArray = []
	for child in _get_ordered_graph_children(scope_root):
		if child is SaveFlowScope:
			var child_scope: SaveFlowScope = child
			if not child_scope.is_scope_enabled():
				continue
			var child_key: String = child_scope.get_scope_key()
			if seen_keys.has("scope:%s" % child_key):
				_append_unique_string(duplicate_keys, "scope:%s" % child_key)
			else:
				seen_keys.append("scope:%s" % child_key)
			var nested_result: SaveResult = _inspect_scope_payload(child_scope)
			if not nested_result.ok:
				return nested_result
			entries.append(
				{
					"kind": "scope",
					"key": child_key,
					"valid": bool(nested_result.data.get("valid", true)),
					"scope": child_scope.describe_scope(),
					"data": nested_result.data,
				}
			)
		elif _is_graph_source_node(child):
			var source_key: String = _resolve_graph_source_key(child)
			if seen_keys.has("source:%s" % source_key):
				_append_unique_string(duplicate_keys, "source:%s" % source_key)
			else:
				seen_keys.append("source:%s" % source_key)
			var entry: Dictionary = {
				"kind": "source",
				"key": source_key,
				"node_path": _describe_node_path(child),
				"valid": true,
			}
			var source := child as SaveFlowSource
			entry["source"] = source.describe_source()
			if entry["source"] is Dictionary:
				var source_description: Dictionary = entry["source"]
				if source_description.has("plan") and source_description["plan"] is Dictionary:
					var plan: Dictionary = source_description["plan"]
					entry["plan"] = plan
					if not bool(plan.get("valid", true)):
						entry["valid"] = false
			entries.append(entry)

	var valid := duplicate_keys.is_empty()
	for entry in entries:
		if not bool(entry.get("valid", true)):
			valid = false
			break
	return _ok_result(
		{
			"scope_key": scope_root.get_scope_key(),
			"valid": valid,
			"entries": entries,
			"duplicate_keys": duplicate_keys,
		}
	)


func _is_graph_source_node(node: Node) -> bool:
	if not is_instance_valid(node):
		return false
	if node is SaveFlowSource:
		return node.is_source_enabled()
	return false


func _resolve_graph_source_key(node: Node) -> String:
	if node is SaveFlowSource:
		return (node as SaveFlowSource).get_source_key()
	return node.name.to_snake_case()


func _gather_source_payload(node: Node, context: Dictionary = {}) -> Variant:
	var source := node as SaveFlowSource
	source.before_save(context)
	return source.gather_save_data()


func _apply_source_payload(node: Node, payload: Variant, context: Dictionary = {}) -> SaveResult:
	var source := node as SaveFlowSource
	source.before_load(payload, context)
	var apply_result_variant: Variant = source.apply_save_data(payload, context)
	if apply_result_variant is SaveResult:
		var apply_result: SaveResult = apply_result_variant
		if not apply_result.ok:
			return apply_result
	source.after_load(payload, context)
	return _ok_result()


func _validate_graph_source(node: Node) -> SaveResult:
	if not is_instance_valid(node):
		return _error_result(
			SaveError.INVALID_SAVEABLE,
			"INVALID_SAVEABLE",
			"graph source is not valid",
			{"node_path": "<null>"}
		)

	if node.has_method("describe_source"):
		var description: Variant = node.call("describe_source")
		if description is Dictionary:
			var source_description: Dictionary = description
			if source_description.has("plan") and source_description["plan"] is Dictionary:
				var plan: Dictionary = source_description["plan"]
				if not bool(plan.get("valid", true)):
					return _error_result(
						SaveError.INVALID_SAVEABLE,
						"INVALID_SAVEABLE",
						"graph source has an invalid save plan",
						{
							"node_path": _describe_node_path(node),
							"source_key": _resolve_graph_source_key(node),
							"reason": String(plan.get("reason", "INVALID_SAVE_PLAN")),
							"missing_properties": plan.get("missing_properties", PackedStringArray()),
						}
					)
			elif source_description.has("valid") and not bool(source_description.get("valid", true)):
				return _error_result(
					SaveError.INVALID_SAVEABLE,
					"INVALID_SAVEABLE",
					"graph source reported itself as invalid",
					{
						"node_path": _describe_node_path(node),
						"source_key": _resolve_graph_source_key(node),
					}
				)

	return _ok_result()


func _can_gather_graph_source(node: Node) -> bool:
	if not is_instance_valid(node):
		return false
	if node is SaveFlowSource:
		return node.can_save_source()
	return true


func _can_apply_graph_source(node: Node) -> bool:
	if not is_instance_valid(node):
		return false
	if node is SaveFlowSource:
		return node.can_load_source()
	return true


func _get_ordered_graph_children(scope_root: SaveFlowScope) -> Array:
	var ordered_entries: Array = []
	var index := 0
	for child in scope_root.get_children():
		ordered_entries.append(
			{
				"child": child,
				"phase": _resolve_graph_node_phase(child),
				"index": index,
			}
		)
		index += 1

	ordered_entries.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var phase_a: int = int(a.get("phase", 0))
			var phase_b: int = int(b.get("phase", 0))
			if phase_a == phase_b:
				return int(a.get("index", 0)) < int(b.get("index", 0))
			return phase_a < phase_b
	)

	var ordered_children: Array = []
	for entry in ordered_entries:
		ordered_children.append(entry["child"])
	return ordered_children


func _resolve_graph_node_phase(node: Node) -> int:
	if not is_instance_valid(node):
		return 0
	if node.has_method("get_phase"):
		return int(node.call("get_phase"))
	return 0


func _resolve_scope_strict(scope_root: SaveFlowScope, inherited_strict: bool) -> bool:
	match scope_root.get_restore_policy():
		SaveFlowScope.RestorePolicy.BEST_EFFORT:
			return false
		SaveFlowScope.RestorePolicy.STRICT:
			return true
		_:
			return inherited_strict


func _find_entity_factory(type_key: String) -> SaveFlowEntityFactory:
	for factory_variant in _entity_factories:
		var factory: SaveFlowEntityFactory = factory_variant
		if factory == null:
			continue
		if factory.can_handle_type(type_key):
			return factory
	return null


func _has_object_property(target: Object, property_name: String) -> bool:
	for property_info in target.get_property_list():
		if String(property_info.get("name", "")) == property_name:
			return true
	return false


func _resolve_saveable_key(root: Node, node: Node) -> String:
	if node is SaveFlowSource:
		return (node as SaveFlowSource).get_save_key()
	return str(root.get_path_to(node))


func _describe_root(root: Node) -> String:
	if not is_instance_valid(root):
		return "<null>"
	if root.is_inside_tree():
		return str(root.get_path())
	if not root.name.is_empty():
		return root.name
	return "<detached>"


func _describe_node_path(node: Node) -> String:
	if not is_instance_valid(node):
		return "<null>"
	if node.is_inside_tree():
		return str(node.get_path())
	return node.name


func _locate_slot(slot_id: String, use_fallback := true) -> SaveResult:
	if slot_id.is_empty():
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"slot_id cannot be empty"
		)

	var index_result: SaveResult = _read_index_data()
	if index_result.ok:
		var slots_map: Dictionary = index_result.data[INDEX_SLOTS_KEY]
		if slots_map.has(slot_id):
			var entry: Dictionary = slots_map[slot_id]
			var indexed_path: String = String(entry.get("path", ""))
			if indexed_path != "" and FileAccess.file_exists(indexed_path):
				return _ok_result(
					{
						"path": indexed_path,
						"format": int(entry.get("format", resolve_storage_format())),
						"entry": entry,
					},
					{"slot_id": slot_id, "source": "index"}
				)

	if use_fallback:
		var candidates: Array = _build_candidate_paths(slot_id)
		for candidate in candidates:
			var candidate_path: String = String(candidate["path"])
			if FileAccess.file_exists(candidate_path):
				return _ok_result(
					{
						"path": candidate_path,
						"format": int(candidate["format"]),
						"entry": {},
					},
					{"slot_id": slot_id, "source": "fallback"}
				)

	return _error_result(
		SaveError.SLOT_NOT_FOUND,
		"SLOT_NOT_FOUND",
		"slot was not found",
		{"slot_id": slot_id}
	)


func _build_candidate_paths(slot_id: String) -> Array:
	var resolved_format: int = resolve_storage_format()
	var formats: Array = [resolved_format]
	if resolved_format != FORMAT_JSON:
		formats.append(FORMAT_JSON)
	if resolved_format != FORMAT_BINARY:
		formats.append(FORMAT_BINARY)

	var candidates: Array = []
	for format in formats:
		candidates.append({"path": _build_slot_path(slot_id, int(format)), "format": int(format)})
	return candidates


func _build_slot_path(slot_id: String, format: int) -> String:
	var extension: String = _settings.file_extension_json
	if format == FORMAT_BINARY:
		extension = _settings.file_extension_binary
	return "%s/%s.%s" % [_settings.save_root, _sanitize_slot_id(slot_id), extension]


func _sanitize_slot_id(slot_id: String) -> String:
	var sanitized: String = slot_id.strip_edges()
	sanitized = sanitized.replace("/", "_")
	sanitized = sanitized.replace("\\", "_")
	sanitized = sanitized.replace(":", "_")
	sanitized = sanitized.replace("*", "_")
	sanitized = sanitized.replace("?", "_")
	sanitized = sanitized.replace("\"", "_")
	sanitized = sanitized.replace("<", "_")
	sanitized = sanitized.replace(">", "_")
	sanitized = sanitized.replace("|", "_")
	if sanitized.is_empty():
		sanitized = "slot"
	return sanitized


func _read_payload_file(path: String, format: int) -> SaveResult:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _error_result(
			SaveError.READ_FAILED,
			"READ_FAILED",
			"failed to open save file for reading",
			{"path": path, "open_error": FileAccess.get_open_error()}
		)

	if format == FORMAT_JSON:
		var text: String = file.get_as_text()
		var json := JSON.new()
		var parse_error: int = json.parse(text)
		if parse_error != OK:
			return _error_result(
				SaveError.INVALID_FORMAT,
				"INVALID_FORMAT",
				"failed to parse json save file",
				{"path": path, "json_error": parse_error}
			)
		var native_payload: Variant = JSON.to_native(json.data, true)
		return _ok_result(native_payload, {"path": path, "format": format})

	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	var payload: Variant = bytes_to_var(bytes)
	return _ok_result(payload, {"path": path, "format": format})


func _write_payload_file(path: String, payload: Dictionary, format: int) -> SaveResult:
	if _settings.use_safe_write:
		return _write_payload_file_safe(path, payload, format)
	return _write_payload_file_direct(path, payload, format)


func _write_payload_file_safe(path: String, payload: Dictionary, format: int) -> SaveResult:
	var temp_path: String = "%s%s" % [path, TEMP_FILE_SUFFIX]
	if FileAccess.file_exists(temp_path):
		DirAccess.remove_absolute(temp_path)

	var write_result: SaveResult = _write_payload_file_direct(temp_path, payload, format)
	if not write_result.ok:
		return write_result

	if FileAccess.file_exists(path):
		var remove_error: int = DirAccess.remove_absolute(path)
		if remove_error != OK:
			return _error_result(
				SaveError.WRITE_FAILED,
				"WRITE_FAILED",
				"failed to replace existing slot file",
				{"path": path, "dir_error": remove_error}
			)

	var rename_error: int = DirAccess.rename_absolute(temp_path, path)
	if rename_error != OK:
		return _error_result(
			SaveError.WRITE_FAILED,
			"WRITE_FAILED",
			"failed to move temp file into final location",
			{"path": path, "temp_path": temp_path, "dir_error": rename_error}
		)

	return _ok_result({"path": path, "format": format})


func _write_payload_file_direct(path: String, payload: Dictionary, format: int) -> SaveResult:
	var ensure_result: SaveResult = _ensure_parent_dir(path)
	if not ensure_result.ok:
		return ensure_result

	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _error_result(
			SaveError.WRITE_FAILED,
			"WRITE_FAILED",
			"failed to open save file for writing",
			{"path": path, "open_error": FileAccess.get_open_error()}
		)

	if format == FORMAT_JSON:
		var indent: String = ""
		if _settings.pretty_json_in_editor and Engine.is_editor_hint():
			indent = "\t"
		var json_payload: Variant = JSON.from_native(payload, true)
		var text: String = JSON.stringify(json_payload, indent)
		file.store_string(text)
		file = null
		return _ok_result({"path": path, "format": format})

	var bytes: PackedByteArray = var_to_bytes(payload)
	file.store_buffer(bytes)
	file = null
	return _ok_result({"path": path, "format": format})


func _read_index_data() -> SaveResult:
	var path: String = get_index_path()
	if not FileAccess.file_exists(path):
		return _ok_result(_default_index_data(), {"path": path, "created_default": true})

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _error_result(
			SaveError.INDEX_READ_FAILED,
			"INDEX_READ_FAILED",
			"failed to open slot index",
			{"path": path, "open_error": FileAccess.get_open_error()}
		)

	var text: String = file.get_as_text()
	var json := JSON.new()
	var parse_error: int = json.parse(text)
	if parse_error != OK or not (json.data is Dictionary):
		return _error_result(
			SaveError.INDEX_READ_FAILED,
			"INDEX_READ_FAILED",
			"failed to parse slot index",
			{"path": path, "json_error": parse_error}
		)

	var index_data: Dictionary = json.data
	if not index_data.has(INDEX_SLOTS_KEY) or not (index_data[INDEX_SLOTS_KEY] is Dictionary):
		index_data[INDEX_SLOTS_KEY] = {}
	if not index_data.has("version"):
		index_data["version"] = INDEX_VERSION
	return _ok_result(index_data, {"path": path})


func _write_index_data(index_data: Dictionary) -> SaveResult:
	var path: String = get_index_path()
	var ensure_result: SaveResult = _ensure_parent_dir(path)
	if not ensure_result.ok:
		return ensure_result

	index_data["version"] = INDEX_VERSION
	if not index_data.has(INDEX_SLOTS_KEY) or not (index_data[INDEX_SLOTS_KEY] is Dictionary):
		index_data[INDEX_SLOTS_KEY] = {}

	var text: String = JSON.stringify(index_data, "\t")
	if _settings.use_safe_write:
		var temp_path: String = "%s%s" % [path, TEMP_FILE_SUFFIX]
		if FileAccess.file_exists(temp_path):
			DirAccess.remove_absolute(temp_path)
		var temp_file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
		if temp_file == null:
			return _error_result(
				SaveError.INDEX_WRITE_FAILED,
				"INDEX_WRITE_FAILED",
				"failed to open temp index file",
				{"path": temp_path, "open_error": FileAccess.get_open_error()}
			)
		temp_file.store_string(text)
		temp_file = null
		if FileAccess.file_exists(path):
			var remove_error: int = DirAccess.remove_absolute(path)
			if remove_error != OK:
				return _error_result(
					SaveError.INDEX_WRITE_FAILED,
					"INDEX_WRITE_FAILED",
					"failed to replace existing index file",
					{"path": path, "dir_error": remove_error}
				)
		var rename_error: int = DirAccess.rename_absolute(temp_path, path)
		if rename_error != OK:
			return _error_result(
				SaveError.INDEX_WRITE_FAILED,
				"INDEX_WRITE_FAILED",
				"failed to move temp index file into final location",
				{"path": path, "temp_path": temp_path, "dir_error": rename_error}
			)
		return _ok_result(index_data, {"path": path})

	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _error_result(
			SaveError.INDEX_WRITE_FAILED,
			"INDEX_WRITE_FAILED",
			"failed to open index file for writing",
			{"path": path, "open_error": FileAccess.get_open_error()}
		)
	file.store_string(text)
	file = null
	return _ok_result(index_data, {"path": path})


func _upsert_index_entry(slot_id: String, path: String, format: int, meta: Dictionary) -> SaveResult:
	var index_result: SaveResult = _read_index_data()
	if not index_result.ok:
		return index_result

	var index_data: Dictionary = index_result.data
	var slots_map: Dictionary = index_data[INDEX_SLOTS_KEY]
	slots_map[slot_id] = {
		"slot_id": slot_id,
		"path": path,
		"format": format,
		"meta": meta.duplicate(true),
	}
	index_data[INDEX_SLOTS_KEY] = slots_map
	return _write_index_data(index_data)


func _remove_index_entry(slot_id: String) -> SaveResult:
	var index_result: SaveResult = _read_index_data()
	if not index_result.ok:
		return index_result

	var index_data: Dictionary = index_result.data
	var slots_map: Dictionary = index_data[INDEX_SLOTS_KEY]
	if slots_map.has(slot_id):
		slots_map.erase(slot_id)
	index_data[INDEX_SLOTS_KEY] = slots_map
	return _write_index_data(index_data)


func _ensure_parent_dir(path: String) -> SaveResult:
	if not _settings.auto_create_dirs:
		return _ok_result(path)

	var base_dir: String = path.get_base_dir()
	var make_error: int = DirAccess.make_dir_recursive_absolute(base_dir)
	if make_error != OK:
		return _error_result(
			SaveError.DIR_CREATE_FAILED,
			"DIR_CREATE_FAILED",
			"failed to create parent directory",
			{"path": path, "base_dir": base_dir, "dir_error": make_error}
		)
	return _ok_result(base_dir)


func _default_index_data() -> Dictionary:
	return {
		"version": INDEX_VERSION,
		INDEX_SLOTS_KEY: {},
	}


func _is_valid_payload(payload: Variant) -> bool:
	return payload is Dictionary and payload.has("meta") and payload.has("data") and payload["meta"] is Dictionary


func _is_valid_format(mode: int) -> bool:
	return mode == FORMAT_AUTO or mode == FORMAT_JSON or mode == FORMAT_BINARY


func _append_unique_string(values: PackedStringArray, value: String) -> void:
	if value.is_empty():
		return
	if values.has(value):
		return
	values.append(value)


func _ok_result(data: Variant = null, meta: Dictionary = {}) -> SaveResult:
	var result := SaveResult.new()
	result.ok = true
	result.error_code = SaveError.OK
	result.error_key = "OK"
	result.data = data
	result.meta = meta
	return result


func _error_result(error_code: int, error_key: String, error_message: String, meta: Dictionary = {}) -> SaveResult:
	var result := SaveResult.new()
	result.ok = false
	result.error_code = error_code
	result.error_key = error_key
	result.error_message = error_message
	result.meta = meta
	return result



