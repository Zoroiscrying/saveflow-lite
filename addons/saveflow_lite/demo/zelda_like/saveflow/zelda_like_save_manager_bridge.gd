extends "res://addons/saveflow_core/runtime/core/saveflow_save_manager_bridge.gd"

@export var sandbox: Node
@export_storage var _sandbox_ref_path: NodePath = NodePath()


func _ready() -> void:
	_hydrate_sandbox_from_ref_path()
	if Engine.is_editor_hint():
		return
	SaveFlow.register_save_manager_bridge(self)


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	SaveFlow.unregister_save_manager_bridge(self)


func get_bridge_name() -> String:
	var resolved_sandbox := _resolve_sandbox()
	if resolved_sandbox == null:
		return "Zelda Demo (Unbound)"
	return "Zelda Demo"


func get_dev_save_settings() -> Dictionary:
	var resolved_sandbox := _resolve_sandbox()
	if resolved_sandbox == null or not resolved_sandbox.has_method("build_dev_save_settings"):
		return {}
	var settings_variant: Variant = resolved_sandbox.call("build_dev_save_settings")
	if settings_variant is Dictionary:
		return Dictionary(settings_variant).duplicate(true)
	return {}


func save_named_entry(entry_name: String) -> SaveResult:
	var resolved_sandbox := _resolve_sandbox()
	if resolved_sandbox == null or not resolved_sandbox.has_method("save_dev_named_entry"):
		return _error("Save manager bridge could not find the Zelda sandbox save entry point.")
	return resolved_sandbox.call("save_dev_named_entry", entry_name)


func load_named_entry(entry_name: String) -> SaveResult:
	var resolved_sandbox := _resolve_sandbox()
	if resolved_sandbox == null or not resolved_sandbox.has_method("load_dev_named_entry"):
		return _error("Save manager bridge could not find the Zelda sandbox load entry point.")
	return resolved_sandbox.call("load_dev_named_entry", entry_name)


func _resolve_sandbox() -> Node:
	if is_instance_valid(sandbox):
		if _sandbox_ref_path.is_empty():
			_sandbox_ref_path = _resolve_relative_node_path(sandbox)
		return sandbox
	if _sandbox_ref_path.is_empty():
		return null
	var resolved := get_node_or_null(_sandbox_ref_path)
	if is_instance_valid(resolved):
		return resolved
	return null


func _hydrate_sandbox_from_ref_path() -> void:
	var resolved := _resolve_sandbox()
	if is_instance_valid(resolved) and sandbox == null:
		sandbox = resolved


func _resolve_relative_node_path(node: Node) -> NodePath:
	if node == null:
		return NodePath()
	if not is_inside_tree() or not node.is_inside_tree():
		return NodePath()
	return get_path_to(node)


func _error(message: String) -> SaveResult:
	var result := SaveResult.new()
	result.ok = false
	result.error_code = SaveError.INVALID_SAVEABLE
	result.error_key = "SAVE_MANAGER_BRIDGE_ERROR"
	result.error_message = message
	return result
