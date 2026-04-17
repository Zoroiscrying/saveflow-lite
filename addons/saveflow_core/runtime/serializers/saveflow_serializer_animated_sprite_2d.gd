class_name SaveFlowSerializerAnimatedSprite2D
extends SaveFlowBuiltInSerializer


func get_serializer_id() -> String:
	return "animated_sprite_2d"


func get_display_name() -> String:
	return "AnimatedSprite2D"


func supports_node(node: Node) -> bool:
	return node is AnimatedSprite2D


func gather_from_node(node: Node) -> Variant:
	var target := node as AnimatedSprite2D
	if target == null:
		return {}
	return {
		"animation": String(target.animation),
		"frame": target.frame,
		"frame_progress": target.frame_progress,
		"speed_scale": target.speed_scale,
		"is_playing": target.is_playing(),
		"flip_h": target.flip_h,
		"flip_v": target.flip_v,
	}


func apply_to_node(node: Node, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var target := node as AnimatedSprite2D
	if target == null:
		return
	var payload: Dictionary = data
	var animation_name: String = String(payload.get("animation", ""))
	if not animation_name.is_empty():
		target.animation = animation_name
	if payload.has("frame"):
		target.frame = int(payload["frame"])
	if payload.has("frame_progress"):
		target.frame_progress = float(payload["frame_progress"])
	if payload.has("speed_scale"):
		target.speed_scale = float(payload["speed_scale"])
	if payload.has("flip_h"):
		target.flip_h = bool(payload["flip_h"])
	if payload.has("flip_v"):
		target.flip_v = bool(payload["flip_v"])
	if bool(payload.get("is_playing", false)):
		if animation_name.is_empty():
			target.play()
		else:
			target.play(animation_name)
	else:
		target.stop()
