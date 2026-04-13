## Demo data source for Zelda-like world and room state. It keeps the example on
## the main `SaveFlowDataSource` path instead of introducing extra binding types.
@tool
extends "res://addons/saveflow_lite/runtime/sources/saveflow_data_source.gd"

## Expected to point at the room registry node that exposes import/export state.
@export var registry: Node
@export_storage var _registry_ref_path: NodePath = NodePath()


func _ready() -> void:
	_hydrate_registry_from_ref_path()


func gather_data() -> Dictionary:
	var resolved_registry := _resolve_registry()
	if resolved_registry == null:
		return {}
	if resolved_registry.has_method("export_save_data"):
		return Dictionary(resolved_registry.call("export_save_data")).duplicate(true)
	return {}


func apply_data(data: Dictionary) -> void:
	var resolved_registry := _resolve_registry()
	if resolved_registry == null:
		return
	if resolved_registry.has_method("import_save_data"):
		resolved_registry.call("import_save_data", data.duplicate(true))


func describe_data_plan() -> Dictionary:
	var resolved_registry := _resolve_registry()
	return {
		"valid": resolved_registry != null,
		"reason": "" if resolved_registry != null else "REGISTRY_NOT_FOUND",
		"source_key": get_source_key(),
		"data_version": data_version,
		"phase": get_phase(),
		"enabled": is_source_enabled(),
		"save_enabled": can_save_source(),
		"load_enabled": can_load_source(),
		"summary": "Zelda-like world and room state",
		"sections": PackedStringArray(["world_state", "room_states"]),
		"details": {
			"registry": resolved_registry.name if resolved_registry != null else "<none>",
			"registry_path": str(_registry_ref_path),
		},
	}


func _resolve_registry() -> Node:
	if is_instance_valid(registry):
		if _registry_ref_path.is_empty():
			_registry_ref_path = _resolve_relative_node_path(registry)
		return registry
	if _registry_ref_path.is_empty():
		return null
	var resolved := get_node_or_null(_registry_ref_path)
	if is_instance_valid(resolved):
		return resolved
	return null


func _hydrate_registry_from_ref_path() -> void:
	var resolved := _resolve_registry()
	if is_instance_valid(resolved) and registry == null:
		registry = resolved


func _resolve_relative_node_path(node: Node) -> NodePath:
	if node == null:
		return NodePath()
	if not is_inside_tree() or not node.is_inside_tree():
		return NodePath()
	return get_path_to(node)
