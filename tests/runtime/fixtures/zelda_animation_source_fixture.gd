@tool
extends "res://addons/saveflow_lite/runtime/core/saveflow_source.gd"

@export_node_path("AnimationPlayer") var target_path: NodePath


func gather_save_data() -> Variant:
	var target := _resolve_target()
	if target == null:
		return {}
	return {
		"current_animation": String(target.current_animation),
		"assigned_animation": String(target.assigned_animation),
		"position": float(target.current_animation_position),
		"speed_scale": float(target.speed_scale),
		"is_playing": bool(target.is_playing()),
	}


func apply_save_data(data: Variant, _context: Dictionary = {}) -> SaveResult:
	if not (data is Dictionary):
		return ok_result()
	var payload: Dictionary = data
	var target := _resolve_target()
	if target == null:
		return ok_result()

	var animation_key: String = String(payload.get("assigned_animation", payload.get("current_animation", "")))
	target.speed_scale = float(payload.get("speed_scale", 1.0))
	if animation_key.is_empty() or not target.has_animation(animation_key):
		target.stop()
		return ok_result()

	target.play(animation_key)
	target.seek(float(payload.get("position", 0.0)), true)
	if not bool(payload.get("is_playing", true)):
		target.pause()
	return ok_result()


func describe_source() -> Dictionary:
	var description := super.describe_source()
	description["kind"] = "animation"
	description["target_path"] = str(target_path)
	return description


func _resolve_target() -> AnimationPlayer:
	if target_path.is_empty():
		return null
	return get_node_or_null(target_path) as AnimationPlayer
