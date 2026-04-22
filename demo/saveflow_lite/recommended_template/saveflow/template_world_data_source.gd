## Minimal template data source showing the recommended custom-source path for
## non-object system state.
@tool
extends "res://addons/saveflow_core/runtime/sources/saveflow_data_source.gd"

## Points at the node that owns the template's `system_state` dictionary.
@export var target: Node
@export_storage var _target_ref_path: NodePath = NodePath()


func _ready() -> void:
	_hydrate_target_from_ref_path()


func gather_data() -> Dictionary:
	var resolved_target := _resolve_target_node()
	if resolved_target == null:
		return {}
	return _as_dictionary(resolved_target.get("system_state")).duplicate(true)


func apply_data(data: Dictionary) -> void:
	var resolved_target := _resolve_target_node()
	if resolved_target == null:
		return
	resolved_target.set("system_state", data.duplicate(true))


func describe_data_plan() -> Dictionary:
	var resolved_target := _resolve_target_node()
	var system_state: Dictionary = {}
	var target_name := "<none>"
	if resolved_target != null:
		system_state = _as_dictionary(resolved_target.get("system_state")).duplicate(true)
		target_name = resolved_target.name
	return {
		"valid": resolved_target != null,
		"reason": "" if resolved_target != null else "TARGET_NOT_FOUND",
		"source_key": get_source_key(),
		"data_version": data_version,
		"phase": get_phase(),
		"enabled": is_source_enabled(),
		"save_enabled": can_save_source(),
		"load_enabled": can_load_source(),
		"summary": "Template world state",
		"sections": PackedStringArray(system_state.keys()),
		"details": {
			"target": target_name,
			"target_path": str(_target_ref_path),
		},
	}


func _resolve_target_node() -> Node:
	if is_instance_valid(target):
		if _target_ref_path.is_empty():
			_target_ref_path = _resolve_relative_node_path(target)
		return target
	if _target_ref_path.is_empty():
		return null
	var resolved := get_node_or_null(_target_ref_path)
	if is_instance_valid(resolved):
		return resolved
	return null


func _hydrate_target_from_ref_path() -> void:
	var resolved := _resolve_target_node()
	if is_instance_valid(resolved) and target == null:
		target = resolved


func _resolve_relative_node_path(node: Node) -> NodePath:
	if node == null:
		return NodePath()
	if not is_inside_tree() or not node.is_inside_tree():
		return NodePath()
	return get_path_to(node)


func _as_dictionary(value: Variant) -> Dictionary:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return {}
