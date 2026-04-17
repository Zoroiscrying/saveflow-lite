class_name SaveFlowSerializerCamera2D
extends SaveFlowBuiltInSerializer


func get_serializer_id() -> String:
	return "camera_2d"


func get_display_name() -> String:
	return "Camera2D"


func supports_node(node: Node) -> bool:
	return node is Camera2D


func gather_from_node(node: Node) -> Variant:
	var target := node as Camera2D
	if target == null:
		return {}
	return {
		"zoom": target.zoom,
		"offset": target.offset,
		"enabled": target.enabled,
		"ignore_rotation": target.ignore_rotation,
	}


func apply_to_node(node: Node, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var target := node as Camera2D
	if target == null:
		return
	var payload: Dictionary = data
	if payload.has("zoom"):
		target.zoom = payload["zoom"]
	if payload.has("offset"):
		target.offset = payload["offset"]
	if payload.has("enabled"):
		target.enabled = bool(payload["enabled"])
	if payload.has("ignore_rotation"):
		target.ignore_rotation = bool(payload["ignore_rotation"])
