class_name SaveFlowSerializerRigidBody2D
extends SaveFlowBuiltInSerializer


func get_serializer_id() -> String:
	return "rigid_body_2d"


func get_display_name() -> String:
	return "RigidBody2D"


func supports_node(node: Node) -> bool:
	return node is RigidBody2D


func gather_from_node(node: Node) -> Variant:
	var target := node as RigidBody2D
	if target == null:
		return {}
	return {
		"linear_velocity": target.linear_velocity,
		"angular_velocity": target.angular_velocity,
		"sleeping": target.sleeping,
		"freeze": target.freeze,
		"freeze_mode": target.freeze_mode,
		"gravity_scale": target.gravity_scale,
		"linear_damp": target.linear_damp,
		"angular_damp": target.angular_damp,
		"lock_rotation": target.lock_rotation,
	}


func apply_to_node(node: Node, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var target := node as RigidBody2D
	if target == null:
		return
	var payload: Dictionary = data
	if payload.has("linear_velocity"):
		target.linear_velocity = payload["linear_velocity"]
	if payload.has("angular_velocity"):
		target.angular_velocity = float(payload["angular_velocity"])
	if payload.has("sleeping"):
		target.sleeping = bool(payload["sleeping"])
	if payload.has("freeze"):
		target.freeze = bool(payload["freeze"])
	if payload.has("freeze_mode"):
		target.freeze_mode = int(payload["freeze_mode"]) as RigidBody2D.FreezeMode
	if payload.has("gravity_scale"):
		target.gravity_scale = float(payload["gravity_scale"])
	if payload.has("linear_damp"):
		target.linear_damp = float(payload["linear_damp"])
	if payload.has("angular_damp"):
		target.angular_damp = float(payload["angular_damp"])
	if payload.has("lock_rotation"):
		target.lock_rotation = bool(payload["lock_rotation"])
