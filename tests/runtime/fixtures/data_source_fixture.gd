@tool
extends "res://addons/saveflow_lite/runtime/sources/saveflow_data_source.gd"

@export var target: Node


func gather_data() -> Dictionary:
	if target == null:
		return {}
	return Dictionary(target.get("system_state")).duplicate(true)


func apply_data(data: Dictionary) -> void:
	if target == null:
		return
	target.set("system_state", data.duplicate(true))
