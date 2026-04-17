class_name SaveFlowSerializerPathFollow2D
extends SaveFlowBuiltInSerializer


func get_serializer_id() -> String:
	return "path_follow_2d"


func get_display_name() -> String:
	return "PathFollow2D"


func supports_node(node: Node) -> bool:
	return node is PathFollow2D


func gather_from_node(node: Node) -> Variant:
	var target := node as PathFollow2D
	if target == null:
		return {}
	return {
		"progress": target.progress,
		"progress_ratio": target.progress_ratio,
		"h_offset": target.h_offset,
		"v_offset": target.v_offset,
		"rotates": target.rotates,
		"cubic_interp": target.cubic_interp,
		"loop": target.loop,
	}


func apply_to_node(node: Node, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var target := node as PathFollow2D
	if target == null:
		return
	var payload: Dictionary = data
	if payload.has("loop"):
		target.loop = bool(payload["loop"])
	if payload.has("cubic_interp"):
		target.cubic_interp = bool(payload["cubic_interp"])
	if payload.has("h_offset"):
		target.h_offset = float(payload["h_offset"])
	if payload.has("v_offset"):
		target.v_offset = float(payload["v_offset"])
	if payload.has("rotates"):
		target.rotates = bool(payload["rotates"])
	if payload.has("progress"):
		target.progress = float(payload["progress"])
	if payload.has("progress_ratio"):
		var owner_path := target.get_parent() as Path2D
		if owner_path != null and owner_path.curve != null and owner_path.curve.get_point_count() > 0:
			target.progress_ratio = float(payload["progress_ratio"])
