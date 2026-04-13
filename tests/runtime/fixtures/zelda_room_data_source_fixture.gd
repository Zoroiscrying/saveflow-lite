@tool
extends "res://addons/saveflow_lite/runtime/sources/saveflow_data_source.gd"

@export var registry: Node


func gather_data() -> Dictionary:
	if registry == null:
		return {}
	return Dictionary(registry.get("system_state")).duplicate(true)


func apply_data(data: Dictionary) -> void:
	if registry == null:
		return
	registry.set("system_state", data.duplicate(true))
