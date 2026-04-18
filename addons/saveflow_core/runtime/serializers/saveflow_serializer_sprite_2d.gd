class_name SaveFlowSerializerSprite2D
extends SaveFlowBuiltInSerializer


func get_serializer_id() -> String:
	return "sprite_2d"


func get_display_name() -> String:
	return "Sprite2D"


func supports_node(node: Node) -> bool:
	return node is Sprite2D


func gather_from_node(node: Node) -> Variant:
	var target := node as Sprite2D
	if target == null:
		return {}
	return {
		"frame": target.frame,
		"frame_coords": target.frame_coords,
		"flip_h": target.flip_h,
		"flip_v": target.flip_v,
		"self_modulate": target.self_modulate,
	}


func apply_to_node(node: Node, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var target := node as Sprite2D
	if target == null:
		return
	var payload: Dictionary = data
	if payload.has("frame"):
		target.frame = int(payload["frame"])
	if payload.has("frame_coords"):
		target.frame_coords = payload["frame_coords"]
	if payload.has("flip_h"):
		target.flip_h = bool(payload["flip_h"])
	if payload.has("flip_v"):
		target.flip_v = bool(payload["flip_v"])
	if payload.has("self_modulate"):
		target.self_modulate = payload["self_modulate"]
