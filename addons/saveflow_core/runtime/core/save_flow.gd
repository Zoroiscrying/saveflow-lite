## SaveFlow is the runtime singleton that owns slot IO, save graph execution,
## and runtime-entity restore orchestration.
extends Node

const FORMAT_AUTO := 0
const FORMAT_JSON := 1
const FORMAT_BINARY := 2
const INDEX_VERSION := 1
const INDEX_SLOTS_KEY := "slots"
const TEMP_FILE_SUFFIX := ".tmp"
const BACKUP_FILE_SUFFIX := ".bak"
const SaveFlowProjectSettingsScript := preload("res://addons/saveflow_core/runtime/core/saveflow_project_settings.gd")
const SaveFlowSaveManagerBusScript := preload("res://addons/saveflow_core/runtime/core/saveflow_save_manager_bus.gd")

var _settings: SaveSettings = SaveSettings.new()
var _current_data: Dictionary = {}
var _entity_factories: Array = []
var _save_manager_bridge: Node
var _save_manager_status_timer := 0.0


func _ready() -> void:
	_settings = SaveFlowProjectSettingsScript.load_settings()
	set_process(true)


func _process(delta: float) -> void:
	_save_manager_status_timer += delta
	if _save_manager_status_timer < 0.5:
		return
	_save_manager_status_timer = 0.0
	_write_save_manager_status()
	_process_save_manager_requests()


func configure(settings: SaveSettings) -> SaveResult:
	if settings == null:
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"settings cannot be null"
		)
	_settings = settings
	return _ok_result(_settings)


func configure_with(
	options_or_save_root: Variant = {},
	slot_index_file: String = "",
	storage_format: int = FORMAT_AUTO,
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
) -> SaveResult:
	if options_or_save_root is SaveSettings:
		return configure(options_or_save_root)

	if options_or_save_root is Dictionary:
		var settings_from_options := SaveSettings.new()
		var merge_result: SaveResult = _apply_settings_options(settings_from_options, options_or_save_root)
		if not merge_result.ok:
			return merge_result
		return configure(settings_from_options)

	var settings := SaveSettings.new()
	if options_or_save_root != null:
		var resolved_save_root := String(options_or_save_root).strip_edges()
		if not resolved_save_root.is_empty():
			settings.save_root = resolved_save_root
	if not slot_index_file.strip_edges().is_empty():
		settings.slot_index_file = slot_index_file.strip_edges()
	settings.storage_format = storage_format
	settings.pretty_json_in_editor = pretty_json_in_editor
	settings.use_safe_write = use_safe_write
	settings.keep_last_backup = keep_last_backup
	settings.auto_create_dirs = auto_create_dirs
	settings.include_meta_in_slot_file = include_meta_in_slot_file
	settings.project_title = project_title
	settings.game_version = game_version
	settings.data_version = data_version
	settings.save_schema = save_schema
	settings.enforce_save_schema_match = enforce_save_schema_match
	settings.enforce_data_version_match = enforce_data_version_match
	settings.verify_scene_path_on_load = verify_scene_path_on_load
	settings.file_extension_json = file_extension_json
	settings.file_extension_binary = file_extension_binary
	settings.log_level = log_level
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


func save_slot(
	slot_id: String,
	data: Variant,
	meta_or_display_name: Variant = {},
	save_type: String = "manual",
	chapter_name: String = "",
	location_name: String = "",
	playtime_seconds: int = 0,
	difficulty: String = "",
	thumbnail_path: String = "",
	extra_meta: Dictionary = {}
) -> SaveResult:
	if slot_id.is_empty():
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"slot_id cannot be empty"
		)

	var meta_patch := _resolve_slot_meta_patch(
		meta_or_display_name,
		save_type,
		chapter_name,
		location_name,
		playtime_seconds,
		difficulty,
		thumbnail_path,
		extra_meta
	)
	var payload: Dictionary = {
		"meta": build_meta(slot_id, meta_patch),
		"data": data,
	}
	return _save_payload(slot_id, payload, resolve_storage_format())


func save_data(
	slot_id: String,
	data: Variant,
	meta_or_display_name: Variant = {},
	save_type: String = "manual",
	chapter_name: String = "",
	location_name: String = "",
	playtime_seconds: int = 0,
	difficulty: String = "",
	thumbnail_path: String = "",
	extra_meta: Dictionary = {}
) -> SaveResult:
	return save_slot(
		slot_id,
		data,
		meta_or_display_name,
		save_type,
		chapter_name,
		location_name,
		playtime_seconds,
		difficulty,
		thumbnail_path,
		extra_meta
	)


func save_scene(
	slot_id: String,
	root: Node,
	meta_or_display_name: Variant = {},
	group_name := "saveflow",
	save_type: String = "manual",
	chapter_name: String = "",
	location_name: String = "",
	playtime_seconds: int = 0,
	difficulty: String = "",
	thumbnail_path: String = "",
	extra_meta: Dictionary = {}
) -> SaveResult:
	return save_nodes(
		slot_id,
		root,
		meta_or_display_name,
		group_name,
		save_type,
		chapter_name,
		location_name,
		playtime_seconds,
		difficulty,
		thumbnail_path,
		extra_meta
	)


func save_scope(
	slot_id: String,
	scope_root: SaveFlowScope,
	meta_or_display_name: Variant = {},
	context: Dictionary = {},
	save_type: String = "manual",
	chapter_name: String = "",
	location_name: String = "",
	playtime_seconds: int = 0,
	difficulty: String = "",
	thumbnail_path: String = "",
	extra_meta: Dictionary = {}
) -> SaveResult:
	var gather_result: SaveResult = gather_scope(scope_root, context)
	if not gather_result.ok:
		return gather_result

	var final_meta := _resolve_slot_meta_patch(
		meta_or_display_name,
		save_type,
		chapter_name,
		location_name,
		playtime_seconds,
		difficulty,
		thumbnail_path,
		extra_meta
	)
	if not final_meta.has("scene_path") and is_instance_valid(scope_root):
		final_meta["scene_path"] = _resolve_scene_path_for_node(scope_root)
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
		var backup_result := _try_read_slot_backup(path, format)
		if backup_result.ok:
			payload = backup_result.data
		if not _is_valid_payload(payload):
			return _error_result(
			SaveError.INVALID_FORMAT,
			"INVALID_FORMAT",
			"save payload must contain meta and data",
			{"slot_id": slot_id, "path": path}
		)

	var slot_meta := Dictionary(payload.get("meta", {}))
	var compatibility_report := _build_slot_compatibility_report(slot_meta)
	if not bool(compatibility_report.get("compatible", true)):
		return _error_result(
			SaveError.MIGRATION_REQUIRED,
			"MIGRATION_REQUIRED",
			_build_compatibility_error_message(compatibility_report),
			{
				"slot_id": slot_id,
				"path": path,
				"format": format,
				"compatibility_report": compatibility_report,
			}
		)

	return _ok_result(
		payload,
		{
			"slot_id": slot_id,
			"path": path,
			"format": format,
			"compatibility_report": compatibility_report,
		}
	)


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
	var load_result: SaveResult = load_slot(slot_id)
	if not load_result.ok:
		return load_result
	if not (load_result.data is Dictionary):
		return _error_result(
			SaveError.INVALID_FORMAT,
			"INVALID_FORMAT",
			"slot data must be a dictionary to load a save graph",
			{"slot_id": slot_id}
		)

	var slot_payload: Dictionary = load_result.data
	var scene_check := _validate_scene_restore_target(Dictionary(slot_payload.get("meta", {})), scope_root, "scope")
	if not scene_check.ok:
		return scene_check

	var payload: Variant = slot_payload.get("data", {})
	if not (payload is Dictionary):
		return _error_result(
			SaveError.INVALID_FORMAT,
			"INVALID_FORMAT",
			"slot data must be a dictionary to load a save graph",
			{"slot_id": slot_id}
		)
	var payload_dict: Dictionary = payload
	if not payload_dict.has("graph") or not (payload_dict["graph"] is Dictionary):
		return _error_result(
			SaveError.INVALID_FORMAT,
			"INVALID_FORMAT",
			"slot data must contain a graph dictionary",
			{"slot_id": slot_id}
		)
	return apply_scope(scope_root, payload_dict["graph"], strict, context)


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


func register_save_manager_bridge(bridge: Node) -> SaveResult:
	if bridge == null:
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"save manager bridge cannot be null"
		)
	if not bridge.has_method("save_named_entry") or not bridge.has_method("load_named_entry"):
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"save manager bridge must implement save_named_entry() and load_named_entry()"
		)
	_save_manager_bridge = bridge
	_write_save_manager_status()
	return _ok_result({"bridge_name": _get_save_manager_bridge_name()})


func unregister_save_manager_bridge(bridge: Node) -> SaveResult:
	if bridge == null:
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"save manager bridge cannot be null"
		)
	if _save_manager_bridge == bridge:
		_save_manager_bridge = null
	_write_save_manager_status()
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


func save_nodes(
	slot_id: String,
	root: Node,
	meta_or_display_name: Variant = {},
	group_name := "saveflow",
	save_type: String = "manual",
	chapter_name: String = "",
	location_name: String = "",
	playtime_seconds: int = 0,
	difficulty: String = "",
	thumbnail_path: String = "",
	extra_meta: Dictionary = {}
) -> SaveResult:
	var collect_result: SaveResult = collect_nodes(root, group_name)
	if not collect_result.ok:
		return collect_result

	var payload: Dictionary = {
		"saveables": collect_result.data,
	}
	var final_meta := _resolve_slot_meta_patch(
		meta_or_display_name,
		save_type,
		chapter_name,
		location_name,
		playtime_seconds,
		difficulty,
		thumbnail_path,
		extra_meta
	)
	if not final_meta.has("scene_path") and is_instance_valid(root):
		final_meta["scene_path"] = _resolve_scene_path_for_node(root)
	return save_slot(slot_id, payload, final_meta)


func load_nodes(slot_id: String, root: Node, strict := false, group_name := "saveflow") -> SaveResult:
	var load_result: SaveResult = load_slot(slot_id)
	if not load_result.ok:
		return load_result
	if not (load_result.data is Dictionary):
		return _error_result(
			SaveError.INVALID_FORMAT,
			"INVALID_FORMAT",
			"slot data must be a dictionary to load saveable nodes",
			{"slot_id": slot_id}
		)

	var slot_payload: Dictionary = load_result.data
	var scene_check := _validate_scene_restore_target(Dictionary(slot_payload.get("meta", {})), root, "scene")
	if not scene_check.ok:
		return scene_check

	var payload: Variant = slot_payload.get("data", {})
	if not (payload is Dictionary):
		return _error_result(
			SaveError.INVALID_FORMAT,
			"INVALID_FORMAT",
			"slot data must be a dictionary to load saveable nodes",
			{"slot_id": slot_id}
		)
	var payload_dict: Dictionary = payload
	if not payload_dict.has("saveables") or not (payload_dict["saveables"] is Dictionary):
		return _error_result(
			SaveError.INVALID_FORMAT,
			"INVALID_FORMAT",
			"slot data must contain a saveables dictionary",
			{"slot_id": slot_id}
		)
	return apply_nodes(root, payload_dict["saveables"], strict, group_name)


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
	var backup_path := _build_backup_path(path)
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

	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)

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


func read_slot_summary(slot_id: String) -> SaveResult:
	if slot_id.is_empty():
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"slot_id cannot be empty"
		)

	var meta_result: SaveResult = _read_slot_meta_for_summary(slot_id)
	if not meta_result.ok:
		return meta_result

	return _ok_result(
		_build_slot_summary(slot_id, meta_result.data),
		meta_result.meta
	)


func list_slot_summaries() -> SaveResult:
	var index_result: SaveResult = _read_index_data()
	if not index_result.ok:
		return index_result

	var slots_map: Dictionary = index_result.data[INDEX_SLOTS_KEY]
	var summaries: Array = []
	for slot_id_variant in slots_map.keys():
		var slot_id := String(slot_id_variant)
		var entry := Dictionary(slots_map.get(slot_id_variant, {}))
		var meta := Dictionary(entry.get("meta", {}))
		if meta.is_empty():
			var meta_result: SaveResult = _read_slot_meta_for_summary(slot_id)
			if not meta_result.ok:
				continue
			meta = meta_result.data
		summaries.append(_build_slot_summary(slot_id, meta))

	summaries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("saved_at_unix", 0)) > int(b.get("saved_at_unix", 0))
	)

	return _ok_result(
		summaries,
		{
			"slot_count": summaries.size(),
		}
	)


func read_meta(slot_id: String) -> SaveResult:
	var load_result: SaveResult = load_slot(slot_id)
	if not load_result.ok:
		return load_result
	return _ok_result(load_result.data["meta"].duplicate(true), load_result.meta)


func inspect_slot_storage(slot_id: String) -> SaveResult:
	if slot_id.is_empty():
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"slot_id cannot be empty"
		)

	var locate_result: SaveResult = _locate_slot(slot_id, false)
	var path := ""
	var format := resolve_storage_format()
	if locate_result.ok:
		path = String(locate_result.data["path"])
		format = int(locate_result.data["format"])
	else:
		path = _build_slot_path(slot_id, format)

	var backup_path := _build_backup_path(path)
	var primary_probe := _probe_payload_file(path, format)
	var backup_probe := _probe_payload_file(backup_path, format)
	return _ok_result(
		{
			"slot_path": path,
			"backup_path": backup_path,
			"primary_exists": bool(primary_probe.get("exists", false)),
			"primary_valid_payload": bool(primary_probe.get("valid_payload", false)),
			"primary_probe_error": String(primary_probe.get("error_key", "")),
			"backup_exists": bool(backup_probe.get("exists", false)),
			"backup_valid_payload": bool(backup_probe.get("valid_payload", false)),
			"backup_probe_error": String(backup_probe.get("error_key", "")),
			"recovery_possible": not bool(primary_probe.get("valid_payload", false)) and bool(backup_probe.get("valid_payload", false)),
		},
		{
			"slot_id": slot_id,
			"path": path,
			"format": format,
		}
	)


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


func build_slot_metadata_patch(
	meta_patch_or_display_name: Variant = {},
	save_type: String = "manual",
	chapter_name: String = "",
	location_name: String = "",
	playtime_seconds: int = 0,
	difficulty: String = "",
	thumbnail_path: String = "",
	extra: Dictionary = {}
) -> Dictionary:
	var business_meta: Dictionary = {
		"display_name": "",
		"save_type": "manual",
		"chapter_name": "",
		"location_name": "",
		"playtime_seconds": 0,
		"difficulty": "",
		"thumbnail_path": "",
	}
	if meta_patch_or_display_name is Dictionary:
		for key in meta_patch_or_display_name.keys():
			business_meta[key] = meta_patch_or_display_name[key]
		return business_meta

	business_meta["display_name"] = String(meta_patch_or_display_name)
	business_meta["save_type"] = save_type
	business_meta["chapter_name"] = chapter_name
	business_meta["location_name"] = location_name
	business_meta["playtime_seconds"] = playtime_seconds
	business_meta["difficulty"] = difficulty
	business_meta["thumbnail_path"] = thumbnail_path
	for key in extra.keys():
		business_meta[key] = extra[key]
	return business_meta


func build_slot_metadata(
	display_name: String = "",
	save_type: String = "manual",
	chapter_name: String = "",
	location_name: String = "",
	playtime_seconds: int = 0,
	difficulty: String = "",
	thumbnail_path: String = "",
	extra: Dictionary = {}
) -> Dictionary:
	return build_slot_metadata_patch(
		display_name,
		save_type,
		chapter_name,
		location_name,
		playtime_seconds,
		difficulty,
		thumbnail_path,
		extra
	)


func _resolve_slot_meta_patch(
	meta_or_display_name: Variant = {},
	save_type: String = "manual",
	chapter_name: String = "",
	location_name: String = "",
	playtime_seconds: int = 0,
	difficulty: String = "",
	thumbnail_path: String = "",
	extra_meta: Dictionary = {}
) -> Dictionary:
	var meta_patch := build_slot_metadata_patch(
		meta_or_display_name,
		save_type,
		chapter_name,
		location_name,
		playtime_seconds,
		difficulty,
		thumbnail_path,
		extra_meta
	)
	return meta_patch.duplicate(true)


func build_meta(slot_id: String, meta_patch: Dictionary = {}) -> Dictionary:
	var base_meta: Dictionary = build_slot_metadata_patch(meta_patch)
	base_meta.merge(
		{
		"slot_id": slot_id,
		"created_at_unix": Time.get_unix_time_from_system(),
		"created_at_iso": Time.get_datetime_string_from_system(true, true),
		"saved_at_unix": Time.get_unix_time_from_system(),
		"saved_at_iso": Time.get_datetime_string_from_system(true, true),
		"scene_path": "",
		"playtime_seconds": 0,
		"project_title": _settings.project_title,
		"game_version": _settings.game_version,
		"data_version": _settings.data_version,
		"save_schema": _settings.save_schema,
		},
		false
	)
	if String(base_meta.get("display_name", "")).is_empty():
		base_meta["display_name"] = slot_id
	return base_meta


func _read_slot_meta_for_summary(slot_id: String) -> SaveResult:
	var index_result: SaveResult = _read_index_data()
	if index_result.ok:
		var slots_map: Dictionary = index_result.data[INDEX_SLOTS_KEY]
		if slots_map.has(slot_id):
			var entry := Dictionary(slots_map[slot_id])
			var indexed_meta := Dictionary(entry.get("meta", {}))
			if not indexed_meta.is_empty():
				return _ok_result(
					indexed_meta.duplicate(true),
					{
						"slot_id": slot_id,
						"from_index": true,
					}
				)

	var locate_result: SaveResult = _locate_slot(slot_id)
	if not locate_result.ok:
		return locate_result

	var path: String = String(locate_result.data["path"])
	var format: int = int(locate_result.data["format"])
	var read_result: SaveResult = _read_payload_file(path, format)
	if not read_result.ok:
		return read_result
	if not _is_valid_payload(read_result.data):
		return _error_result(
			SaveError.INVALID_FORMAT,
			"INVALID_FORMAT",
			"save payload must contain meta and data",
			{"slot_id": slot_id, "path": path}
		)

	return _ok_result(
		Dictionary(read_result.data.get("meta", {})).duplicate(true),
		{
			"slot_id": slot_id,
			"path": path,
			"format": format,
			"from_index": false,
		}
	)


func _build_slot_summary(slot_id: String, slot_meta: Dictionary) -> Dictionary:
	var custom_metadata := slot_meta.duplicate(true)
	for key in [
		"slot_id",
		"display_name",
		"save_type",
		"chapter_name",
		"location_name",
		"playtime_seconds",
		"difficulty",
		"thumbnail_path",
		"created_at_unix",
		"created_at_iso",
		"saved_at_unix",
		"saved_at_iso",
		"scene_path",
		"project_title",
		"game_version",
		"data_version",
		"save_schema",
	]:
		custom_metadata.erase(key)

	return {
		"slot_id": String(slot_meta.get("slot_id", slot_id)),
		"display_name": String(slot_meta.get("display_name", slot_id)),
		"save_type": String(slot_meta.get("save_type", "manual")),
		"chapter_name": String(slot_meta.get("chapter_name", "")),
		"location_name": String(slot_meta.get("location_name", "")),
		"playtime_seconds": int(slot_meta.get("playtime_seconds", 0)),
		"difficulty": String(slot_meta.get("difficulty", "")),
		"thumbnail_path": String(slot_meta.get("thumbnail_path", "")),
		"created_at_unix": int(slot_meta.get("created_at_unix", 0)),
		"created_at_iso": String(slot_meta.get("created_at_iso", "")),
		"saved_at_unix": int(slot_meta.get("saved_at_unix", 0)),
		"saved_at_iso": String(slot_meta.get("saved_at_iso", "")),
		"scene_path": String(slot_meta.get("scene_path", "")),
		"project_title": String(slot_meta.get("project_title", "")),
		"game_version": String(slot_meta.get("game_version", "")),
		"data_version": int(slot_meta.get("data_version", 0)),
		"save_schema": String(slot_meta.get("save_schema", "")),
		"compatibility_report": _build_slot_compatibility_report(slot_meta),
		"custom_metadata": custom_metadata,
	}


func inspect_slot_compatibility(slot_id: String) -> SaveResult:
	var locate_result: SaveResult = _locate_slot(slot_id)
	if not locate_result.ok:
		return locate_result

	var path: String = String(locate_result.data["path"])
	var format: int = int(locate_result.data["format"])
	var read_result: SaveResult = _read_payload_file(path, format)
	if not read_result.ok:
		return read_result
	if not _is_valid_payload(read_result.data):
		return _error_result(
			SaveError.INVALID_FORMAT,
			"INVALID_FORMAT",
			"save payload must contain meta and data",
			{"slot_id": slot_id, "path": path}
		)

	var payload: Dictionary = read_result.data
	var compatibility_report := _build_slot_compatibility_report(Dictionary(payload.get("meta", {})))
	return _ok_result(
		compatibility_report,
		{
			"slot_id": slot_id,
			"path": path,
			"format": format,
		}
	)


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


func save_current(
	slot_id: String,
	meta_or_display_name: Variant = {},
	save_type: String = "manual",
	chapter_name: String = "",
	location_name: String = "",
	playtime_seconds: int = 0,
	difficulty: String = "",
	thumbnail_path: String = "",
	extra_meta: Dictionary = {}
) -> SaveResult:
	return save_slot(
		slot_id,
		_current_data.duplicate(true),
		meta_or_display_name,
		save_type,
		chapter_name,
		location_name,
		playtime_seconds,
		difficulty,
		thumbnail_path,
		extra_meta
	)


func load_current(slot_id: String) -> SaveResult:
	var result: SaveResult = load_slot(slot_id)
	if result.ok and result.data is Dictionary and result.data.has("data") and result.data["data"] is Dictionary:
		_current_data = result.data["data"].duplicate(true)
	return result


## Save one named dev entry for editor-driven runtime testing.
## This uses a derived dev-save settings profile and prefers scope-root
## restoration when a SaveFlowScope is present in the active scene.
func save_dev_named_entry(entry_name: String) -> SaveResult:
	return _run_named_entry_with_dev_settings("save", entry_name)


## Load one named dev entry for editor-driven runtime testing.
func load_dev_named_entry(entry_name: String) -> SaveResult:
	return _run_named_entry_with_dev_settings("load", entry_name)


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
		var previous_entry: Dictionary = Dictionary(previous_result.data.get("entry", {}))
		if previous_entry.has("meta") and previous_entry["meta"] is Dictionary:
			var previous_meta: Dictionary = previous_entry["meta"]
			if previous_meta.has("created_at_unix") and not payload["meta"].has("created_at_unix"):
				payload["meta"]["created_at_unix"] = previous_meta["created_at_unix"]
			if previous_meta.has("created_at_iso") and not payload["meta"].has("created_at_iso"):
				payload["meta"]["created_at_iso"] = previous_meta["created_at_iso"]

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


func _write_save_manager_status() -> void:
	var bridge_active := _is_save_manager_bridge_available()
	var builtin_active := _is_builtin_save_manager_fallback_available()
	var runtime_available := bridge_active or builtin_active
	var dev_settings: Dictionary = {}
	var current_scene_path := ""
	var tree := get_tree()
	if tree != null and is_instance_valid(tree.current_scene):
		current_scene_path = _resolve_scene_path_for_node(tree.current_scene)
	if bridge_active and _save_manager_bridge.has_method("get_dev_save_settings"):
		var bridge_dev_settings: Variant = _save_manager_bridge.call("get_dev_save_settings")
		if bridge_dev_settings is Dictionary:
			dev_settings = Dictionary(bridge_dev_settings).duplicate(true)
	elif builtin_active:
		dev_settings = _settings_to_status_dict(_build_builtin_dev_settings())
	SaveFlowSaveManagerBusScript.write_status(
		{
			"runtime_available": runtime_available,
			"bridge_name": _get_save_manager_bridge_name() if bridge_active else ("SaveFlow (Built-in)" if builtin_active else ""),
			"current_scene_path": current_scene_path,
			"settings": _settings_to_status_dict(_settings),
			"dev_settings": dev_settings,
		}
	)


func _process_save_manager_requests() -> void:
	var bridge_active := _is_save_manager_bridge_available()
	var builtin_active := _is_builtin_save_manager_fallback_available()
	if not bridge_active and not builtin_active:
		return

	for request in SaveFlowSaveManagerBusScript.list_pending_requests():
		var request_id: String = String(request.get("id", ""))
		var action: String = String(request.get("action", ""))
		var entry_name: String = String(request.get("name", ""))
		var result: SaveResult = _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"unsupported save manager action",
			{"action": action}
		)

		if bridge_active:
			if action == "save":
				result = _save_manager_bridge.call("save_named_entry", entry_name)
			elif action == "load":
				result = _save_manager_bridge.call("load_named_entry", entry_name)
		else:
			if action == "save":
				result = save_dev_named_entry(entry_name)
			elif action == "load":
				result = load_dev_named_entry(entry_name)

		if result.ok:
			SaveFlowSaveManagerBusScript.complete_request(request_id, true, "Completed %s '%s'." % [action, entry_name])
		else:
			SaveFlowSaveManagerBusScript.complete_request(
				request_id,
				false,
				result.error_message if not result.error_message.is_empty() else "Save manager request failed."
			)


func _is_save_manager_bridge_available() -> bool:
	if _save_manager_bridge == null or not is_instance_valid(_save_manager_bridge):
		return false
	if _save_manager_bridge.has_method("is_bridge_enabled"):
		return bool(_save_manager_bridge.call("is_bridge_enabled"))
	return true


func _is_builtin_save_manager_fallback_available() -> bool:
	return _resolve_runtime_scene_root() != null


func _get_save_manager_bridge_name() -> String:
	if _save_manager_bridge == null or not is_instance_valid(_save_manager_bridge):
		return ""
	if _save_manager_bridge.has_method("get_bridge_name"):
		return String(_save_manager_bridge.call("get_bridge_name"))
	return _save_manager_bridge.name


func _build_slot_compatibility_report(slot_meta: Dictionary) -> Dictionary:
	var report := {
		"slot_game_version": String(slot_meta.get("game_version", "")),
		"project_game_version": _settings.game_version,
		"slot_data_version": int(slot_meta.get("data_version", 0)),
		"project_data_version": _settings.data_version,
		"slot_save_schema": String(slot_meta.get("save_schema", "")),
		"project_save_schema": _settings.save_schema,
		"schema_matches": true,
		"data_version_matches": true,
		"game_version_matches": true,
		"compatible": true,
		"reasons": PackedStringArray(),
	}

	var reasons: PackedStringArray = report["reasons"]
	var slot_schema := String(report["slot_save_schema"])
	var project_schema := String(report["project_save_schema"])
	var schema_mismatch := not slot_schema.is_empty() and not project_schema.is_empty() and slot_schema != project_schema
	report["schema_matches"] = not schema_mismatch
	if schema_mismatch and _settings.enforce_save_schema_match:
		report["schema_matches"] = false
		report["compatible"] = false
		reasons.append("SAVE_SCHEMA_MISMATCH")

	var slot_data_version := int(report["slot_data_version"])
	var project_data_version := int(report["project_data_version"])
	var data_version_mismatch := slot_data_version > 0 and project_data_version > 0 and slot_data_version != project_data_version
	report["data_version_matches"] = not data_version_mismatch
	if data_version_mismatch and _settings.enforce_data_version_match:
		report["data_version_matches"] = false
		report["compatible"] = false
		reasons.append("DATA_VERSION_MISMATCH")

	var slot_game_version := String(report["slot_game_version"])
	var project_game_version := String(report["project_game_version"])
	if not slot_game_version.is_empty() and not project_game_version.is_empty() and slot_game_version != project_game_version:
		report["game_version_matches"] = false
		reasons.append("GAME_VERSION_DIFFERS")

	report["reasons"] = reasons
	return report


func _build_compatibility_error_message(report: Dictionary) -> String:
	var reasons := PackedStringArray(report.get("reasons", PackedStringArray()))
	if reasons.has("SAVE_SCHEMA_MISMATCH"):
		return "slot save_schema does not match the current project schema; migration is required before load"
	if reasons.has("DATA_VERSION_MISMATCH"):
		return "slot data_version does not match the current project data version; migration is required before load"
	return "slot metadata is not compatible with the current SaveFlow project settings"


func _validate_scene_restore_target(slot_meta: Dictionary, target: Node, target_kind: String) -> SaveResult:
	if not _settings.verify_scene_path_on_load:
		return _ok_result()

	var expected_scene_path := String(slot_meta.get("scene_path", ""))
	if expected_scene_path.is_empty():
		return _ok_result()

	var current_scene_path := _resolve_scene_path_for_node(target)
	if current_scene_path == expected_scene_path:
		return _ok_result(
			{
				"expected_scene_path": expected_scene_path,
				"current_scene_path": current_scene_path,
			}
		)

	var current_description := current_scene_path if not current_scene_path.is_empty() else "<no loaded scene path>"
	return _error_result(
		SaveError.INVALID_SAVEABLE,
		"SCENE_PATH_MISMATCH",
		"restore contract mismatch: saved %s expects scene `%s`, but the current restore target resolves to `%s`; load the expected scene first and retry the restore" % [
			target_kind,
			expected_scene_path,
			current_description,
		],
		{
			"expected_scene_path": expected_scene_path,
			"current_scene_path": current_scene_path,
			"target_kind": target_kind,
		}
	)


func _resolve_scene_path_for_node(node: Node) -> String:
	if node == null or not is_instance_valid(node):
		return ""
	if not node.scene_file_path.is_empty():
		return node.scene_file_path
	var tree := node.get_tree()
	if tree != null and tree.current_scene != null and (node == tree.current_scene or tree.current_scene.is_ancestor_of(node)):
		return tree.current_scene.scene_file_path
	return ""


func _build_backup_path(path: String) -> String:
	return "%s%s" % [path, BACKUP_FILE_SUFFIX]


func _write_slot_backup(path: String) -> SaveResult:
	if not _settings.keep_last_backup or not FileAccess.file_exists(path):
		return _ok_result()

	var backup_path := _build_backup_path(path)
	var ensure_result: SaveResult = _ensure_parent_dir(backup_path)
	if not ensure_result.ok:
		return ensure_result

	var source := FileAccess.open(path, FileAccess.READ)
	if source == null:
		return _error_result(
			SaveError.BACKUP_RESTORE_FAILED,
			"BACKUP_READ_FAILED",
			"failed to open slot file while creating backup",
			{"path": path, "backup_path": backup_path, "open_error": FileAccess.get_open_error()}
		)
	var bytes := source.get_buffer(source.get_length())
	source = null

	var backup := FileAccess.open(backup_path, FileAccess.WRITE)
	if backup == null:
		return _error_result(
			SaveError.BACKUP_RESTORE_FAILED,
			"BACKUP_WRITE_FAILED",
			"failed to write slot backup file",
			{"path": path, "backup_path": backup_path, "open_error": FileAccess.get_open_error()}
		)
	backup.store_buffer(bytes)
	backup = null
	return _ok_result({"backup_path": backup_path})


func _try_read_slot_backup(path: String, format: int) -> SaveResult:
	var backup_path := _build_backup_path(path)
	if not FileAccess.file_exists(backup_path):
		return _error_result(
			SaveError.BACKUP_RESTORE_FAILED,
			"BACKUP_NOT_FOUND",
			"no slot backup file is available",
			{"path": path, "backup_path": backup_path}
		)

	var read_result := _read_payload_file(backup_path, format)
	if not read_result.ok:
		return read_result
	if not _is_valid_payload(read_result.data):
		return _error_result(
			SaveError.BACKUP_RESTORE_FAILED,
			"BACKUP_INVALID_FORMAT",
			"slot backup exists but does not contain a valid save payload",
			{"path": path, "backup_path": backup_path}
		)
	return _ok_result(read_result.data, {"backup_path": backup_path, "used_backup": true})


func _run_named_entry_with_dev_settings(action: String, entry_name: String) -> SaveResult:
	var slot_id := entry_name.strip_edges()
	if slot_id.is_empty():
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"entry_name cannot be empty"
		)

	var previous_settings := _settings
	var dev_settings := _build_builtin_dev_settings()
	_settings = dev_settings
	var result := _execute_named_entry_action(action, slot_id)
	_settings = previous_settings
	return result


func _execute_named_entry_action(action: String, slot_id: String) -> SaveResult:
	var scene_root := _resolve_runtime_scene_root()
	if scene_root == null:
		return _error_result(
			SaveError.INVALID_SAVEABLE,
			"INVALID_SAVEABLE",
			"no runtime scene is available for SaveFlow dev save/load"
		)

	var scope_root := _find_first_scope_in_tree(scene_root)
	if scope_root != null:
		if action == "save":
			return save_scope(slot_id, scope_root, {"display_name": slot_id})
		if action == "load":
			return load_scope(slot_id, scope_root, false)

	if action == "save":
		return save_scene(slot_id, scene_root, {"display_name": slot_id}, "saveflow")
	if action == "load":
		return load_scene(slot_id, scene_root, false, "saveflow")

	return _error_result(
		SaveError.INVALID_ARGUMENT,
		"INVALID_ARGUMENT",
		"unsupported save manager action",
		{"action": action}
	)


func _resolve_runtime_scene_root() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	if tree.current_scene != null:
		return tree.current_scene
	return null


func _find_first_scope_in_tree(node: Node) -> SaveFlowScope:
	if node == null:
		return null
	if node is SaveFlowScope:
		return node as SaveFlowScope
	for child in node.get_children():
		if not (child is Node):
			continue
		var found := _find_first_scope_in_tree(child)
		if found != null:
			return found
	return null


func _build_builtin_dev_settings() -> SaveSettings:
	var settings := _settings.duplicate(true) as SaveSettings
	if settings == null:
		settings = SaveSettings.new()

	var formal_root := settings.save_root
	if formal_root.is_empty():
		formal_root = "user://saves"

	var formal_root_clean := formal_root.trim_suffix("/")
	formal_root_clean = formal_root_clean.trim_suffix("\\")
	var formal_leaf := formal_root_clean.get_file().to_lower()
	var parent := formal_root_clean.get_base_dir()
	if formal_leaf == "saves":
		settings.save_root = parent.path_join("devSaves")
	else:
		settings.save_root = formal_root_clean.path_join("devSaves")

	var slot_index := settings.slot_index_file
	if slot_index.is_empty():
		settings.slot_index_file = settings.save_root.path_join("dev-slots.index")
	else:
		settings.slot_index_file = slot_index.get_base_dir().path_join("dev-slots.index")
	return settings


func _settings_to_status_dict(settings: SaveSettings) -> Dictionary:
	return {
		"save_root": settings.save_root,
		"slot_index_file": settings.slot_index_file,
		"storage_format": settings.storage_format,
		"pretty_json_in_editor": settings.pretty_json_in_editor,
		"use_safe_write": settings.use_safe_write,
		"keep_last_backup": settings.keep_last_backup,
		"file_extension_json": settings.file_extension_json,
		"file_extension_binary": settings.file_extension_binary,
		"log_level": settings.log_level,
		"include_meta_in_slot_file": settings.include_meta_in_slot_file,
		"auto_create_dirs": settings.auto_create_dirs,
		"project_title": settings.project_title,
		"game_version": settings.game_version,
		"data_version": settings.data_version,
		"save_schema": settings.save_schema,
		"enforce_save_schema_match": settings.enforce_save_schema_match,
		"enforce_data_version_match": settings.enforce_data_version_match,
		"verify_scene_path_on_load": settings.verify_scene_path_on_load,
	}


func _read_payload_file(path: String, format: int) -> SaveResult:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		var open_error_result := _error_result(
			SaveError.READ_FAILED,
			"READ_FAILED",
			"failed to open save file for reading",
			{"path": path, "open_error": FileAccess.get_open_error()}
		)
		var backup_open_result := _try_read_slot_backup(path, format)
		if backup_open_result.ok:
			return _ok_result(backup_open_result.data, backup_open_result.meta)
		return open_error_result

	if format == FORMAT_JSON:
		var text: String = file.get_as_text()
		var json := JSON.new()
		var parse_error: int = json.parse(text)
		if parse_error != OK:
			var parse_error_result := _error_result(
				SaveError.INVALID_FORMAT,
				"INVALID_FORMAT",
				"failed to parse json save file",
				{"path": path, "json_error": parse_error}
			)
			var backup_parse_result := _try_read_slot_backup(path, format)
			if backup_parse_result.ok:
				return _ok_result(backup_parse_result.data, backup_parse_result.meta)
			return parse_error_result
		var native_payload: Variant = JSON.to_native(json.data, true)
		return _ok_result(native_payload, {"path": path, "format": format})

	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	var payload: Variant = bytes_to_var(bytes)
	return _ok_result(payload, {"path": path, "format": format})


func _probe_payload_file(path: String, format: int) -> Dictionary:
	var report := {
		"path": path,
		"format": format,
		"exists": FileAccess.file_exists(path),
		"valid_payload": false,
		"error_key": "",
	}
	if not bool(report["exists"]):
		report["error_key"] = "FILE_NOT_FOUND"
		return report

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		report["error_key"] = "READ_FAILED"
		return report

	var payload: Variant = null
	if format == FORMAT_JSON:
		var text: String = file.get_as_text()
		var json := JSON.new()
		var parse_error: int = json.parse(text)
		if parse_error != OK:
			report["error_key"] = "INVALID_FORMAT"
			return report
		payload = json.data
	else:
		var bytes: PackedByteArray = file.get_buffer(file.get_length())
		payload = bytes_to_var(bytes)

	if not (payload is Dictionary) or not _is_valid_payload(payload):
		report["error_key"] = "INVALID_PAYLOAD"
		return report

	report["valid_payload"] = true
	return report


func _write_payload_file(path: String, payload: Dictionary, format: int) -> SaveResult:
	if _settings.use_safe_write:
		return _write_payload_file_safe(path, payload, format)
	return _write_payload_file_direct(path, payload, format)


func _write_payload_file_safe(path: String, payload: Dictionary, format: int) -> SaveResult:
	var temp_path: String = "%s%s" % [path, TEMP_FILE_SUFFIX]
	if FileAccess.file_exists(temp_path):
		DirAccess.remove_absolute(temp_path)

	var write_result: SaveResult = _write_payload_file_direct(temp_path, payload, format, false)
	if not write_result.ok:
		return write_result

	if FileAccess.file_exists(path):
		var backup_result: SaveResult = _write_slot_backup(path)
		if not backup_result.ok:
			DirAccess.remove_absolute(temp_path)
			return backup_result
		var remove_error: int = DirAccess.remove_absolute(path)
		if remove_error != OK:
			DirAccess.remove_absolute(temp_path)
			return _error_result(
				SaveError.WRITE_FAILED,
				"WRITE_FAILED",
				"failed to replace existing slot file",
				{"path": path, "dir_error": remove_error}
			)

	var rename_error: int = DirAccess.rename_absolute(temp_path, path)
	if rename_error != OK:
		DirAccess.remove_absolute(temp_path)
		return _error_result(
			SaveError.WRITE_FAILED,
			"WRITE_FAILED",
			"failed to move temp file into final location",
			{"path": path, "temp_path": temp_path, "dir_error": rename_error}
		)

	return _ok_result({"path": path, "format": format})


func _write_payload_file_direct(path: String, payload: Dictionary, format: int, create_backup := true) -> SaveResult:
	var ensure_result: SaveResult = _ensure_parent_dir(path)
	if not ensure_result.ok:
		return ensure_result
	if create_backup:
		var backup_result: SaveResult = _write_slot_backup(path)
		if not backup_result.ok:
			return backup_result

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
