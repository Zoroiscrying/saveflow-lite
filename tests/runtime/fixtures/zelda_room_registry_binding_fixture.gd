extends "res://addons/saveflow_lite/runtime/sources/saveflow_data_source.gd"

@export_node_path("Node") var target_path: NodePath


func gather_data() -> Dictionary:
	var target := get_node_or_null(target_path)
	if target == null:
		return {}
	return Dictionary(target.get("system_state")).duplicate(true)


func apply_data(data: Dictionary) -> void:
	var target := get_node_or_null(target_path)
	if target == null:
		return
	target.set("system_state", data.duplicate(true))
