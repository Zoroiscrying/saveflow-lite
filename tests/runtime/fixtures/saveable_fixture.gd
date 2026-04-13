@tool
extends "res://addons/saveflow_lite/runtime/core/saveflow_source.gd"

var save_key := ""
var state: Dictionary = {}


func get_save_key() -> String:
	if save_key.is_empty():
		return name.to_snake_case()
	return save_key


func gather_save_data() -> Variant:
	return state.duplicate(true)


func apply_save_data(data: Variant, _context: Dictionary = {}) -> SaveResult:
	if data is Dictionary:
		state = data.duplicate(true)
	return ok_result()
