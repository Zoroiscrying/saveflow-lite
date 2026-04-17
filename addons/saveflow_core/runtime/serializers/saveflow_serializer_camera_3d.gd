class_name SaveFlowSerializerCamera3D
extends SaveFlowBuiltInSerializer


func get_serializer_id() -> String:
	return "camera_3d"


func get_display_name() -> String:
	return "Camera3D"


func supports_node(node: Node) -> bool:
	return node is Camera3D


func gather_from_node(node: Node) -> Variant:
	var target := node as Camera3D
	if target == null:
		return {}
	return {
		"projection": target.projection,
		"keep_aspect": target.keep_aspect,
		"fov": target.fov,
		"size": target.size,
		"near": target.near,
		"far": target.far,
		"current": target.current,
	}


func apply_to_node(node: Node, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var target := node as Camera3D
	if target == null:
		return
	var payload: Dictionary = data
	if payload.has("projection"):
		target.projection = int(payload["projection"]) as Camera3D.ProjectionType
	if payload.has("keep_aspect"):
		target.keep_aspect = int(payload["keep_aspect"]) as Camera3D.KeepAspect
	if payload.has("fov"):
		target.fov = float(payload["fov"])
	if payload.has("size"):
		target.size = float(payload["size"])
	if payload.has("near"):
		target.near = float(payload["near"])
	if payload.has("far"):
		target.far = float(payload["far"])
	if payload.has("current"):
		target.current = bool(payload["current"])
