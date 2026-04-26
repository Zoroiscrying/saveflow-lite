extends RefCounted

const SaveFlowSaveManagerBusScript := preload("res://addons/saveflow_core/runtime/core/saveflow_save_manager_bus.gd")

var _settings: SaveSettings = SaveSettings.new()


func configure(settings: SaveSettings) -> void:
	_settings = settings if settings != null else SaveSettings.new()


func write_status(runtime: Node, bridge: Node) -> void:
	var bridge_active := is_bridge_available(bridge)
	var builtin_active := is_builtin_fallback_available(runtime)
	var runtime_available := bridge_active or builtin_active
	var dev_settings: Dictionary = {}
	var current_scene_path := ""
	var scene_root := resolve_runtime_scene_root(runtime)
	if scene_root != null:
		current_scene_path = resolve_scene_path_for_node(scene_root)
	if bridge_active and bridge.has_method("get_dev_save_settings"):
		var bridge_dev_settings: Variant = bridge.call("get_dev_save_settings")
		if bridge_dev_settings is Dictionary:
			dev_settings = Dictionary(bridge_dev_settings).duplicate(true)
	elif builtin_active:
		dev_settings = settings_to_status_dict(build_builtin_dev_settings(_settings))
	SaveFlowSaveManagerBusScript.write_status(
		{
			"runtime_available": runtime_available,
			"bridge_name": get_bridge_name(bridge) if bridge_active else ("SaveFlow (Built-in)" if builtin_active else ""),
			"current_scene_path": current_scene_path,
			"settings": settings_to_status_dict(_settings),
			"dev_settings": dev_settings,
		}
	)


func process_requests(runtime: Node, bridge: Node) -> void:
	var bridge_active := is_bridge_available(bridge)
	var builtin_active := is_builtin_fallback_available(runtime)
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
				result = bridge.call("save_named_entry", entry_name)
			elif action == "load":
				result = bridge.call("load_named_entry", entry_name)
		else:
			result = run_named_entry_with_dev_settings(runtime, action, entry_name)

		if result.ok:
			SaveFlowSaveManagerBusScript.complete_request(request_id, true, "Completed %s '%s'." % [action, entry_name])
		else:
			SaveFlowSaveManagerBusScript.complete_request(
				request_id,
				false,
				result.error_message if not result.error_message.is_empty() else "Save manager request failed."
			)


func run_named_entry_with_dev_settings(runtime: Node, action: String, entry_name: String) -> SaveResult:
	var slot_id := entry_name.strip_edges()
	if slot_id.is_empty():
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"entry_name cannot be empty"
		)
	if runtime == null or not runtime.has_method("get_settings") or not runtime.has_method("configure"):
		return _error_result(
			SaveError.INVALID_SAVEABLE,
			"INVALID_SAVEABLE",
			"SaveFlow runtime is not available for dev save/load"
		)

	var previous_settings: SaveSettings = runtime.call("get_settings")
	var dev_settings := build_builtin_dev_settings(previous_settings)
	runtime.call("configure", dev_settings)
	var result := execute_named_entry_action(runtime, action, slot_id)
	runtime.call("configure", previous_settings)
	return result


func execute_named_entry_action(runtime: Node, action: String, slot_id: String) -> SaveResult:
	var scene_root := resolve_runtime_scene_root(runtime)
	if scene_root == null:
		return _error_result(
			SaveError.INVALID_SAVEABLE,
			"INVALID_SAVEABLE",
			"no runtime scene is available for SaveFlow dev save/load"
		)

	var scope_root := find_first_scope_in_tree(scene_root)
	if scope_root != null:
		if action == "save":
			return _call_saveflow_result(runtime, "save_scope", [slot_id, scope_root, {"display_name": slot_id}])
		if action == "load":
			return _call_saveflow_result(runtime, "load_scope", [slot_id, scope_root, false])

	if action == "save":
		return _call_saveflow_result(runtime, "save_scene", [slot_id, scene_root, {"display_name": slot_id}, "saveflow"])
	if action == "load":
		return _call_saveflow_result(runtime, "load_scene", [slot_id, scene_root, false, "saveflow"])

	return _error_result(
		SaveError.INVALID_ARGUMENT,
		"INVALID_ARGUMENT",
		"unsupported save manager action",
		{"action": action}
	)


func is_bridge_available(bridge: Node) -> bool:
	if bridge == null or not is_instance_valid(bridge):
		return false
	if bridge.has_method("is_bridge_enabled"):
		return bool(bridge.call("is_bridge_enabled"))
	return true


func is_builtin_fallback_available(runtime: Node) -> bool:
	return resolve_runtime_scene_root(runtime) != null


func get_bridge_name(bridge: Node) -> String:
	if bridge == null or not is_instance_valid(bridge):
		return ""
	if bridge.has_method("get_bridge_name"):
		return String(bridge.call("get_bridge_name"))
	return bridge.name


func resolve_runtime_scene_root(runtime: Node) -> Node:
	if runtime == null or not is_instance_valid(runtime):
		return null
	var tree := runtime.get_tree()
	if tree == null:
		return null
	if tree.current_scene != null:
		return tree.current_scene
	return null


func find_first_scope_in_tree(node: Node) -> SaveFlowScope:
	if node == null:
		return null
	if node is SaveFlowScope:
		return node as SaveFlowScope
	for child in node.get_children():
		if not (child is Node):
			continue
		var found := find_first_scope_in_tree(child)
		if found != null:
			return found
	return null


func build_builtin_dev_settings(settings_source: SaveSettings = null) -> SaveSettings:
	var source := settings_source if settings_source != null else _settings
	var settings := source.duplicate(true) as SaveSettings
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


func settings_to_status_dict(settings: SaveSettings) -> Dictionary:
	if settings == null:
		settings = SaveSettings.new()
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


func resolve_scene_path_for_node(node: Node) -> String:
	if node == null or not is_instance_valid(node):
		return ""
	if not node.scene_file_path.is_empty():
		return node.scene_file_path
	var tree := node.get_tree()
	if tree != null and tree.current_scene != null and (node == tree.current_scene or tree.current_scene.is_ancestor_of(node)):
		return tree.current_scene.scene_file_path
	return ""


func _call_saveflow_result(runtime: Node, method_name: String, arguments: Array) -> SaveResult:
	if runtime == null or not runtime.has_method(method_name):
		return _error_result(
			SaveError.INVALID_SAVEABLE,
			"INVALID_SAVEABLE",
			"SaveFlow runtime does not implement %s" % method_name
		)
	var result := runtime.callv(method_name, arguments) as SaveResult
	if result == null:
		return _error_result(
			SaveError.UNKNOWN,
			"UNKNOWN",
			"SaveFlow runtime method %s did not return a SaveResult" % method_name
		)
	return result


func _error_result(error_code: int, error_key: String, error_message: String, meta: Dictionary = {}) -> SaveResult:
	var result := SaveResult.new()
	result.ok = false
	result.error_code = error_code
	result.error_key = error_key
	result.error_message = error_message
	result.meta = meta
	return result
