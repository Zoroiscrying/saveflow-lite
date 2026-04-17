class_name SaveFlowSerializerPathFollow3D
extends SaveFlowBuiltInSerializer


func get_serializer_id() -> String:
	return "path_follow_3d"


func get_display_name() -> String:
	return "PathFollow3D"


func supports_node(node: Node) -> bool:
	return node is PathFollow3D


func gather_from_node(node: Node) -> Variant:
	var target := node as PathFollow3D
	if target == null:
		return {}
	return {
		"progress": target.progress,
		"progress_ratio": target.progress_ratio,
		"h_offset": target.h_offset,
		"v_offset": target.v_offset,
		"rotation_mode": target.rotation_mode,
		"cubic_interp": target.cubic_interp,
		"loop": target.loop,
		"tilt_enabled": target.tilt_enabled,
		"use_model_front": target.use_model_front,
	}


func apply_to_node(node: Node, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var target := node as PathFollow3D
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
	if payload.has("rotation_mode"):
		target.rotation_mode = int(payload["rotation_mode"]) as PathFollow3D.RotationMode
	if payload.has("tilt_enabled"):
		target.tilt_enabled = bool(payload["tilt_enabled"])
	if payload.has("use_model_front"):
		target.use_model_front = bool(payload["use_model_front"])
	if payload.has("progress"):
		target.progress = float(payload["progress"])
	if payload.has("progress_ratio"):
		target.progress_ratio = float(payload["progress_ratio"])
