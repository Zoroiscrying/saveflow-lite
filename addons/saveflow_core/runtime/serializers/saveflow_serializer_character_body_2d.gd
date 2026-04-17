class_name SaveFlowSerializerCharacterBody2D
extends SaveFlowBuiltInSerializer


func get_serializer_id() -> String:
	return "character_body_2d"


func get_display_name() -> String:
	return "CharacterBody2D"


func supports_node(node: Node) -> bool:
	return node is CharacterBody2D


func gather_from_node(node: Node) -> Variant:
	var target := node as CharacterBody2D
	if target == null:
		return {}
	return {
		"velocity": target.velocity,
		"motion_mode": target.motion_mode,
		"up_direction": target.up_direction,
		"floor_snap_length": target.floor_snap_length,
	}


func apply_to_node(node: Node, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var target := node as CharacterBody2D
	if target == null:
		return
	var payload: Dictionary = data
	if payload.has("velocity"):
		target.velocity = payload["velocity"]
	if payload.has("motion_mode"):
		target.motion_mode = int(payload["motion_mode"]) as CharacterBody2D.MotionMode
	if payload.has("up_direction"):
		target.up_direction = payload["up_direction"]
	if payload.has("floor_snap_length"):
		target.floor_snap_length = max(0.0, float(payload["floor_snap_length"]))
