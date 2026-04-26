## SaveFlow is the runtime singleton facade for slot IO, save graph execution,
## and runtime-entity restore orchestration.
extends Node

const FORMAT_AUTO := 0
const FORMAT_JSON := 1
const FORMAT_BINARY := 2
const SaveFlowProjectSettingsScript := preload("res://addons/saveflow_core/runtime/core/saveflow_project_settings.gd")
const SaveFlowStorageServiceScript := preload("res://addons/saveflow_core/runtime/core/saveflow_storage_service.gd")
const SaveFlowSlotMetadataServiceScript := preload("res://addons/saveflow_core/runtime/core/saveflow_slot_metadata_service.gd")
const SaveFlowPipelineServiceScript := preload("res://addons/saveflow_core/runtime/core/saveflow_pipeline_service.gd")
const SaveFlowScopeGraphRunnerScript := preload("res://addons/saveflow_core/runtime/core/saveflow_scope_graph_runner.gd")
const SaveFlowNodeGraphRunnerScript := preload("res://addons/saveflow_core/runtime/core/saveflow_node_graph_runner.gd")
const SaveFlowDevSaveManagerServiceScript := preload("res://addons/saveflow_core/runtime/core/saveflow_dev_save_manager_service.gd")
const SaveFlowEntityRestoreRunnerScript := preload("res://addons/saveflow_core/runtime/core/saveflow_entity_restore_runner.gd")
const SaveFlowSlotServiceScript := preload("res://addons/saveflow_core/runtime/core/saveflow_slot_service.gd")

var _settings: SaveSettings = SaveSettings.new()
var _current_data: Dictionary = {}
var _save_manager_bridge: Node
var _save_manager_status_timer := 0.0
var _storage_service := SaveFlowStorageServiceScript.new()
var _slot_metadata_service := SaveFlowSlotMetadataServiceScript.new()
var _pipeline_service := SaveFlowPipelineServiceScript.new()
var _scope_graph_runner := SaveFlowScopeGraphRunnerScript.new()
var _node_graph_runner := SaveFlowNodeGraphRunnerScript.new()
var _dev_save_manager_service := SaveFlowDevSaveManagerServiceScript.new()
var _entity_restore_runner := SaveFlowEntityRestoreRunnerScript.new()
var _slot_service := SaveFlowSlotServiceScript.new()


func _init() -> void:
	_sync_runtime_services()


func _ready() -> void:
	_settings = SaveFlowProjectSettingsScript.load_settings()
	_sync_runtime_services()
	set_process(true)


func _process(delta: float) -> void:
	_save_manager_status_timer += delta
	if _save_manager_status_timer < 0.5:
		return
	_save_manager_status_timer = 0.0
	_dev_save_manager_service.write_status(self, _save_manager_bridge)
	_dev_save_manager_service.process_requests(self, _save_manager_bridge)


func configure(settings: SaveSettings) -> SaveResult:
	if settings == null:
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"settings cannot be null"
	)
	_settings = settings
	_sync_runtime_services()
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
	return _storage_service.resolve_storage_format()


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
	return _slot_service.save_slot(
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
	pipeline_control: SaveFlowPipelineControl = null,
	save_type: String = "manual",
	chapter_name: String = "",
	location_name: String = "",
	playtime_seconds: int = 0,
	difficulty: String = "",
	thumbnail_path: String = "",
	extra_meta: Dictionary = {}
) -> SaveResult:
	pipeline_control = _resolve_pipeline_control(pipeline_control)
	_register_pipeline_signal_bridges(pipeline_control, scope_root)
	var before_save_result := _notify_pipeline_stage(
		pipeline_control,
		"before_save",
		{
			"slot_id": slot_id,
			"scope": scope_root,
			"key": _resolve_scope_key_or_empty(scope_root),
			"kind": "scope",
		}
	)
	if not before_save_result.ok:
		return _attach_pipeline_trace(before_save_result, pipeline_control.context)

	var gather_result: SaveResult = _gather_scope_with_control(scope_root, pipeline_control)
	if not gather_result.ok:
		return gather_result
	var after_gather_result := _notify_pipeline_stage(
		pipeline_control,
		"after_gather",
		{
			"slot_id": slot_id,
			"scope": scope_root,
			"key": _resolve_scope_key_or_empty(scope_root),
			"kind": "scope",
			"payload": gather_result.data,
			"result": gather_result,
		}
	)
	if not after_gather_result.ok:
		return _attach_pipeline_trace(after_gather_result, pipeline_control.context)

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
	var before_write_result := _notify_pipeline_stage(
		pipeline_control,
		"before_write",
		{
			"slot_id": slot_id,
			"scope": scope_root,
			"key": _resolve_scope_key_or_empty(scope_root),
			"kind": "slot",
			"payload": {"graph": gather_result.data, "meta": final_meta},
		}
	)
	if not before_write_result.ok:
		return _attach_pipeline_trace(before_write_result, pipeline_control.context)

	var save_result := save_slot(slot_id, {"graph": gather_result.data}, final_meta)
	if gather_result.meta.has("pipeline_trace"):
		save_result.meta["pipeline_trace"] = gather_result.meta["pipeline_trace"]
	if not save_result.ok:
		return _finish_pipeline_error(
			pipeline_control,
			save_result,
			{
				"slot_id": slot_id,
				"scope": scope_root,
				"key": _resolve_scope_key_or_empty(scope_root),
				"kind": "slot",
			}
		)

	var after_write_result := _notify_pipeline_stage(
		pipeline_control,
		"after_write",
		{
			"slot_id": slot_id,
			"scope": scope_root,
			"key": _resolve_scope_key_or_empty(scope_root),
			"kind": "slot",
			"result": save_result,
		}
	)
	if not after_write_result.ok:
		return _attach_pipeline_trace(after_write_result, pipeline_control.context)
	save_result.meta["pipeline_trace"] = pipeline_control.context.to_trace_array()
	return save_result


func load_slot(slot_id: String) -> SaveResult:
	return _slot_service.load_slot(slot_id)


func load_slot_data(slot_id: String) -> SaveResult:
	return _slot_service.load_slot_data(slot_id)


func load_data(slot_id: String) -> SaveResult:
	return _slot_service.load_slot_data(slot_id)


func load_scene(slot_id: String, root: Node, strict := false, group_name := "saveflow") -> SaveResult:
	return load_nodes(slot_id, root, strict, group_name)


func load_scope(
	slot_id: String,
	scope_root: SaveFlowScope,
	strict := false,
	pipeline_control: SaveFlowPipelineControl = null
) -> SaveResult:
	pipeline_control = _resolve_pipeline_control(pipeline_control)
	_register_pipeline_signal_bridges(pipeline_control, scope_root)
	var before_load_result := _notify_pipeline_stage(
		pipeline_control,
		"before_load",
		{
			"slot_id": slot_id,
			"scope": scope_root,
			"key": _resolve_scope_key_or_empty(scope_root),
			"kind": "scope",
		}
	)
	if not before_load_result.ok:
		return _attach_pipeline_trace(before_load_result, pipeline_control.context)

	var load_result: SaveResult = load_slot(slot_id)
	if not load_result.ok:
		return _finish_pipeline_error(
			pipeline_control,
			load_result,
			{
				"slot_id": slot_id,
				"scope": scope_root,
				"key": _resolve_scope_key_or_empty(scope_root),
				"kind": "slot",
			}
		)
	var after_read_result := _notify_pipeline_stage(
		pipeline_control,
		"after_read",
		{
			"slot_id": slot_id,
			"scope": scope_root,
			"key": _resolve_scope_key_or_empty(scope_root),
			"kind": "slot",
			"payload": load_result.data,
			"result": load_result,
		}
	)
	if not after_read_result.ok:
		return _attach_pipeline_trace(after_read_result, pipeline_control.context)
	if not (load_result.data is Dictionary):
		return _finish_pipeline_error(pipeline_control, _error_result(
			SaveError.INVALID_FORMAT,
			"INVALID_FORMAT",
			"slot data must be a dictionary to load a save graph",
			{"slot_id": slot_id}
		), {"slot_id": slot_id, "scope": scope_root, "kind": "slot"})

	var slot_payload: Dictionary = load_result.data
	var scene_check := _validate_scene_restore_target(Dictionary(slot_payload.get("meta", {})), scope_root, "scope")
	if not scene_check.ok:
		return _finish_pipeline_error(
			pipeline_control,
			scene_check,
			{
				"slot_id": slot_id,
				"scope": scope_root,
				"key": _resolve_scope_key_or_empty(scope_root),
				"kind": "scope",
			}
		)

	var payload: Variant = slot_payload.get("data", {})
	if not (payload is Dictionary):
		return _finish_pipeline_error(pipeline_control, _error_result(
			SaveError.INVALID_FORMAT,
			"INVALID_FORMAT",
			"slot data must be a dictionary to load a save graph",
			{"slot_id": slot_id}
		), {"slot_id": slot_id, "scope": scope_root, "kind": "slot"})
	var payload_dict: Dictionary = payload
	if not payload_dict.has("graph") or not (payload_dict["graph"] is Dictionary):
		return _finish_pipeline_error(pipeline_control, _error_result(
			SaveError.INVALID_FORMAT,
			"INVALID_FORMAT",
			"slot data must contain a graph dictionary",
			{"slot_id": slot_id}
		), {"slot_id": slot_id, "scope": scope_root, "kind": "slot"})

	var before_apply_result := _notify_pipeline_stage(
		pipeline_control,
		"before_apply",
		{
			"slot_id": slot_id,
			"scope": scope_root,
			"key": _resolve_scope_key_or_empty(scope_root),
			"kind": "scope",
			"payload": payload_dict["graph"],
		}
	)
	if not before_apply_result.ok:
		return _attach_pipeline_trace(before_apply_result, pipeline_control.context)
	var apply_result: SaveResult = _apply_scope_with_control(scope_root, payload_dict["graph"], strict, pipeline_control)
	if not apply_result.ok:
		return apply_result
	var after_load_result := _notify_pipeline_stage(
		pipeline_control,
		"after_load",
		{
			"slot_id": slot_id,
			"scope": scope_root,
			"key": _resolve_scope_key_or_empty(scope_root),
			"kind": "scope",
			"payload": payload_dict["graph"],
			"result": apply_result,
		}
	)
	if not after_load_result.ok:
		return _attach_pipeline_trace(after_load_result, pipeline_control.context)
	apply_result.meta["pipeline_trace"] = pipeline_control.context.to_trace_array()
	return apply_result


func load_slot_or_default(slot_id: String, default_data: Variant) -> SaveResult:
	return _slot_service.load_slot_or_default(slot_id, default_data)


func gather_scope(scope_root: SaveFlowScope, pipeline_control: SaveFlowPipelineControl = null) -> SaveResult:
	pipeline_control = _resolve_pipeline_control(pipeline_control)
	_register_pipeline_signal_bridges(pipeline_control, scope_root)
	var before_save_result := _notify_pipeline_stage(
		pipeline_control,
		"before_save",
		{
			"scope": scope_root,
			"key": _resolve_scope_key_or_empty(scope_root),
			"kind": "scope",
		}
	)
	if not before_save_result.ok:
		return _attach_pipeline_trace(before_save_result, pipeline_control.context)
	var gather_result: SaveResult = _gather_scope_with_control(scope_root, pipeline_control)
	if not gather_result.ok:
		return gather_result
	var after_gather_result := _notify_pipeline_stage(
		pipeline_control,
		"after_gather",
		{
			"scope": scope_root,
			"key": _resolve_scope_key_or_empty(scope_root),
			"kind": "scope",
			"payload": gather_result.data,
			"result": gather_result,
		}
	)
	if not after_gather_result.ok:
		return _attach_pipeline_trace(after_gather_result, pipeline_control.context)
	gather_result.meta["pipeline_trace"] = pipeline_control.context.to_trace_array()
	return gather_result


func _gather_scope_with_control(scope_root: SaveFlowScope, pipeline_control: SaveFlowPipelineControl) -> SaveResult:
	pipeline_control = _resolve_pipeline_control(pipeline_control)
	var pipeline_context: SaveFlowPipelineContext = pipeline_control.context
	if not is_instance_valid(scope_root):
		return _finish_pipeline_error(pipeline_control, _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"scope_root cannot be null"
		), {"kind": "scope"})
	if not scope_root.can_save_scope():
		return _finish_pipeline_error(pipeline_control, _error_result(
			SaveError.INVALID_SAVEABLE,
			"INVALID_SAVEABLE",
			"scope_root is not enabled for save",
			{"scope_key": scope_root.get_scope_key()}
		), {"scope": scope_root, "key": scope_root.get_scope_key(), "kind": "scope"})
	var gather_result: SaveResult = _gather_scope_payload(scope_root, pipeline_control)
	if not gather_result.ok:
		return _finish_pipeline_error(
			pipeline_control,
			gather_result,
			{"scope": scope_root, "key": scope_root.get_scope_key(), "kind": "scope"}
		)
	return _attach_pipeline_trace(gather_result, pipeline_context)


## Scope apply is the graph-level restore entry point. Individual sources keep
## their own gather/apply contracts, while SaveFlow handles traversal order and
## strict-mode result propagation.
func apply_scope(
	scope_root: SaveFlowScope,
	scope_payload: Dictionary,
	strict := false,
	pipeline_control: SaveFlowPipelineControl = null
) -> SaveResult:
	pipeline_control = _resolve_pipeline_control(pipeline_control)
	_register_pipeline_signal_bridges(pipeline_control, scope_root)
	var before_apply_result := _notify_pipeline_stage(
		pipeline_control,
		"before_apply",
		{
			"scope": scope_root,
			"key": _resolve_scope_key_or_empty(scope_root),
			"kind": "scope",
			"payload": scope_payload,
		}
	)
	if not before_apply_result.ok:
		return _attach_pipeline_trace(before_apply_result, pipeline_control.context)
	var apply_result: SaveResult = _apply_scope_with_control(scope_root, scope_payload, strict, pipeline_control)
	if not apply_result.ok:
		return apply_result
	var after_load_result := _notify_pipeline_stage(
		pipeline_control,
		"after_load",
		{
			"scope": scope_root,
			"key": _resolve_scope_key_or_empty(scope_root),
			"kind": "scope",
			"payload": scope_payload,
			"result": apply_result,
		}
	)
	if not after_load_result.ok:
		return _attach_pipeline_trace(after_load_result, pipeline_control.context)
	apply_result.meta["pipeline_trace"] = pipeline_control.context.to_trace_array()
	return apply_result


func _apply_scope_with_control(
	scope_root: SaveFlowScope,
	scope_payload: Dictionary,
	strict := false,
	pipeline_control: SaveFlowPipelineControl = null
) -> SaveResult:
	pipeline_control = _resolve_pipeline_control(pipeline_control)
	var pipeline_context: SaveFlowPipelineContext = pipeline_control.context
	if not is_instance_valid(scope_root):
		return _finish_pipeline_error(pipeline_control, _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"scope_root cannot be null"
		), {"kind": "scope"})
	if not scope_root.can_load_scope():
		return _finish_pipeline_error(pipeline_control, _error_result(
			SaveError.INVALID_SAVEABLE,
			"INVALID_SAVEABLE",
			"scope_root is not enabled for load",
			{"scope_key": scope_root.get_scope_key()}
		), {"scope": scope_root, "key": scope_root.get_scope_key(), "kind": "scope"})
	var apply_result: SaveResult = _apply_scope_payload(scope_root, scope_payload, strict, pipeline_control)
	if not apply_result.ok:
		return _finish_pipeline_error(
			pipeline_control,
			apply_result,
			{"scope": scope_root, "key": scope_root.get_scope_key(), "kind": "scope"}
		)
	return _attach_pipeline_trace(apply_result, pipeline_context)


func inspect_scope(scope_root: SaveFlowScope) -> SaveResult:
	if not is_instance_valid(scope_root):
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"scope_root cannot be null"
		)
	return _inspect_scope_payload(scope_root)


func register_entity_factory(factory: SaveFlowEntityFactory) -> SaveResult:
	return _entity_restore_runner.register_entity_factory(factory)


func unregister_entity_factory(factory: SaveFlowEntityFactory) -> SaveResult:
	return _entity_restore_runner.unregister_entity_factory(factory)


func clear_entity_factories() -> SaveResult:
	return _entity_restore_runner.clear_entity_factories()


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
	_dev_save_manager_service.write_status(self, _save_manager_bridge)
	return _ok_result({"bridge_name": _dev_save_manager_service.get_bridge_name(_save_manager_bridge)})


func unregister_save_manager_bridge(bridge: Node) -> SaveResult:
	if bridge == null:
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"save manager bridge cannot be null"
		)
	if _save_manager_bridge == bridge:
		_save_manager_bridge = null
	_dev_save_manager_service.write_status(self, _save_manager_bridge)
	return _ok_result()


func restore_entities(descriptors: Array, context: Dictionary = {}, strict := false, options: Dictionary = {}) -> SaveResult:
	return _entity_restore_runner.restore_entities(self, descriptors, context, strict, options)


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
	return _node_graph_runner.inspect_scene(root, group_name)


func collect_nodes(root: Node, group_name := "saveflow") -> SaveResult:
	return _node_graph_runner.collect_nodes(root, group_name)


func apply_nodes(root: Node, saveables_data: Dictionary, strict := false, group_name := "saveflow") -> SaveResult:
	return _node_graph_runner.apply_nodes(root, saveables_data, strict, group_name)


func delete_slot(slot_id: String) -> SaveResult:
	return _slot_service.delete_slot(slot_id)


func copy_slot(from_slot: String, to_slot: String, overwrite := false) -> SaveResult:
	return _slot_service.copy_slot(from_slot, to_slot, overwrite)


func rename_slot(old_id: String, new_id: String, overwrite := false) -> SaveResult:
	return _slot_service.rename_slot(old_id, new_id, overwrite)


func slot_exists(slot_id: String) -> bool:
	return _slot_service.slot_exists(slot_id)


func list_slots() -> SaveResult:
	return _slot_service.list_slots()


func read_slot_summary(slot_id: String) -> SaveResult:
	return _slot_service.read_slot_summary(slot_id)


func read_slot_metadata(slot_id: String, target_metadata: SaveFlowSlotMetadata = null) -> SaveResult:
	return _slot_service.read_slot_metadata(slot_id, target_metadata)


func list_slot_summaries() -> SaveResult:
	return _slot_service.list_slot_summaries()


func read_meta(slot_id: String) -> SaveResult:
	return _slot_service.read_meta(slot_id)


func inspect_slot_storage(slot_id: String) -> SaveResult:
	return _slot_service.inspect_slot_storage(slot_id)


func write_meta(slot_id: String, meta_patch: Dictionary) -> SaveResult:
	return _slot_service.write_meta(slot_id, meta_patch)


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
	return _slot_metadata_service.build_slot_metadata_patch(
		meta_patch_or_display_name,
		save_type,
		chapter_name,
		location_name,
		playtime_seconds,
		difficulty,
		thumbnail_path,
		extra
	)


func build_slot_metadata(
	display_name: String = "",
	save_type: String = "manual",
	chapter_name: String = "",
	location_name: String = "",
	playtime_seconds: int = 0,
	difficulty: String = "",
	thumbnail_path: String = "",
	extra: Dictionary = {}
) -> SaveFlowSlotMetadata:
	return _slot_metadata_service.build_slot_metadata(
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
	return _slot_metadata_service.resolve_slot_meta_patch(
		meta_or_display_name,
		save_type,
		chapter_name,
		location_name,
		playtime_seconds,
		difficulty,
		thumbnail_path,
		extra_meta
	)


func build_meta(slot_id: String, meta_patch: Dictionary = {}) -> Dictionary:
	return _slot_metadata_service.build_meta(slot_id, meta_patch)


func inspect_slot_compatibility(slot_id: String) -> SaveResult:
	return _slot_service.inspect_slot_compatibility(slot_id)


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
	return _dev_save_manager_service.run_named_entry_with_dev_settings(self, "save", entry_name)


## Load one named dev entry for editor-driven runtime testing.
func load_dev_named_entry(entry_name: String) -> SaveResult:
	return _dev_save_manager_service.run_named_entry_with_dev_settings(self, "load", entry_name)


func validate_slot(slot_id: String) -> SaveResult:
	return _slot_service.validate_slot(slot_id)


func get_slot_path(slot_id: String) -> SaveResult:
	return _slot_service.get_slot_path(slot_id)


func get_index_path() -> String:
	return _slot_service.get_index_path()


func _gather_scope_payload(scope_root: SaveFlowScope, pipeline_control: SaveFlowPipelineControl) -> SaveResult:
	return _scope_graph_runner.gather_scope_payload(scope_root, pipeline_control)


func _apply_scope_payload(
	scope_root: SaveFlowScope,
	scope_payload: Dictionary,
	strict := false,
	pipeline_control: SaveFlowPipelineControl = null
) -> SaveResult:
	return _scope_graph_runner.apply_scope_payload(scope_root, scope_payload, strict, pipeline_control)


func _inspect_scope_payload(scope_root: SaveFlowScope) -> SaveResult:
	return _scope_graph_runner.inspect_scope_payload(scope_root)


func _has_object_property(target: Object, property_name: String) -> bool:
	for property_info in target.get_property_list():
		if String(property_info.get("name", "")) == property_name:
			return true
	return false


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


func _is_valid_format(mode: int) -> bool:
	return _storage_service.is_valid_format(mode)


func _notify_pipeline_stage(
	pipeline_control: SaveFlowPipelineControl,
	stage: String,
	options: Dictionary = {}
) -> SaveResult:
	return _pipeline_service.notify_stage(pipeline_control, stage, options)


func _finish_pipeline_error(
	pipeline_control: SaveFlowPipelineControl,
	result: SaveResult,
	options: Dictionary = {}
) -> SaveResult:
	return _pipeline_service.finish_error(pipeline_control, result, options)


func _resolve_pipeline_control(pipeline_control: SaveFlowPipelineControl = null) -> SaveFlowPipelineControl:
	return _pipeline_service.resolve_pipeline_control(pipeline_control)


func _register_pipeline_signal_bridges(pipeline_control: SaveFlowPipelineControl, root: Node) -> void:
	_pipeline_service.register_signal_bridges(pipeline_control, root)


func _resolve_scope_key_or_empty(scope_root: SaveFlowScope) -> String:
	if not is_instance_valid(scope_root):
		return ""
	return scope_root.get_scope_key()


func _sync_runtime_services() -> void:
	_storage_service.configure(_settings)
	_slot_metadata_service.configure(_settings)
	_dev_save_manager_service.configure(_settings)
	_slot_service.configure(_storage_service, _slot_metadata_service)


func _ok_result(data: Variant = null, meta: Dictionary = {}) -> SaveResult:
	var result := SaveResult.new()
	result.ok = true
	result.error_code = SaveError.OK
	result.error_key = "OK"
	result.data = data
	result.meta = meta
	return result


func _attach_pipeline_trace(result: SaveResult, pipeline_context: SaveFlowPipelineContext) -> SaveResult:
	return _pipeline_service.attach_trace(result, pipeline_context)


func _error_result(error_code: int, error_key: String, error_message: String, meta: Dictionary = {}) -> SaveResult:
	var result := SaveResult.new()
	result.ok = false
	result.error_code = error_code
	result.error_key = error_key
	result.error_message = error_message
	result.meta = meta
	return result
