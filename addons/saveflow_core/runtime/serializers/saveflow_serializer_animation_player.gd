class_name SaveFlowSerializerAnimationPlayer
extends SaveFlowBuiltInSerializer


func get_serializer_id() -> String:
	return "animation_player"


func get_display_name() -> String:
	return "Animation Player"


func supports_node(node: Node) -> bool:
	return node is AnimationPlayer


func gather_from_node(node: Node) -> Variant:
	var target := node as AnimationPlayer
	if target == null:
		return {}
	return {
		"current_animation": String(target.current_animation),
		"assigned_animation": String(target.assigned_animation),
		"position": float(target.current_animation_position),
		"speed_scale": float(target.speed_scale),
		"is_playing": bool(target.is_playing()),
	}


func apply_to_node(node: Node, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var target := node as AnimationPlayer
	if target == null:
		return
	var payload: Dictionary = data
	var animation_key: String = String(payload.get("assigned_animation", payload.get("current_animation", "")))
	target.speed_scale = float(payload.get("speed_scale", 1.0))
	if animation_key.is_empty() or not target.has_animation(animation_key):
		target.stop()
		return

	target.play(animation_key)
	target.seek(float(payload.get("position", 0.0)), true)
	if not bool(payload.get("is_playing", true)):
		target.pause()
