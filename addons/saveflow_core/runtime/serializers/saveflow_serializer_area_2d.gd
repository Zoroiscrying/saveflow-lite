class_name SaveFlowSerializerArea2D
extends SaveFlowBuiltInSerializer


func get_serializer_id() -> String:
	return "area_2d"


func get_display_name() -> String:
	return "Area2D"


func supports_node(node: Node) -> bool:
	return node is Area2D


func gather_from_node(node: Node) -> Variant:
	var target := node as Area2D
	if target == null:
		return {}
	return {
		"monitoring": target.monitoring,
		"monitorable": target.monitorable,
		"priority": target.priority,
		"gravity_space_override": target.gravity_space_override,
		"gravity": target.gravity,
		"gravity_direction": target.gravity_direction,
		"gravity_is_point": target.gravity_point,
		"gravity_point_unit_distance": target.gravity_point_unit_distance,
		"linear_damp_space_override": target.linear_damp_space_override,
		"linear_damp": target.linear_damp,
		"angular_damp_space_override": target.angular_damp_space_override,
		"angular_damp": target.angular_damp,
	}


func apply_to_node(node: Node, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var target := node as Area2D
	if target == null:
		return
	var payload: Dictionary = data
	if payload.has("monitoring"):
		target.monitoring = bool(payload["monitoring"])
	if payload.has("monitorable"):
		target.monitorable = bool(payload["monitorable"])
	if payload.has("priority"):
		target.priority = int(payload["priority"])
	if payload.has("gravity_space_override"):
		target.gravity_space_override = int(payload["gravity_space_override"]) as Area2D.SpaceOverride
	if payload.has("gravity"):
		target.gravity = float(payload["gravity"])
	if payload.has("gravity_direction"):
		target.gravity_direction = payload["gravity_direction"]
	if payload.has("gravity_is_point"):
		target.gravity_point = bool(payload["gravity_is_point"])
	if payload.has("gravity_point_unit_distance"):
		target.gravity_point_unit_distance = float(payload["gravity_point_unit_distance"])
	if payload.has("linear_damp_space_override"):
		target.linear_damp_space_override = int(payload["linear_damp_space_override"]) as Area2D.SpaceOverride
	if payload.has("linear_damp"):
		target.linear_damp = float(payload["linear_damp"])
	if payload.has("angular_damp_space_override"):
		target.angular_damp_space_override = int(payload["angular_damp_space_override"]) as Area2D.SpaceOverride
	if payload.has("angular_damp"):
		target.angular_damp = float(payload["angular_damp"])


func describe_fields(_node: Node) -> Array:
	return [
		{"id": "monitoring", "display_name": "Monitoring"},
		{"id": "monitorable", "display_name": "Monitorable"},
		{"id": "priority", "display_name": "Priority"},
		{"id": "gravity_space_override", "display_name": "Gravity Override"},
		{"id": "gravity", "display_name": "Gravity"},
		{"id": "gravity_direction", "display_name": "Gravity Direction"},
		{"id": "gravity_is_point", "display_name": "Gravity Is Point"},
		{"id": "gravity_point_unit_distance", "display_name": "Gravity Point Unit Distance"},
		{"id": "linear_damp_space_override", "display_name": "Linear Damp Override"},
		{"id": "linear_damp", "display_name": "Linear Damp"},
		{"id": "angular_damp_space_override", "display_name": "Angular Damp Override"},
		{"id": "angular_damp", "display_name": "Angular Damp"},
	]


func recommended_field_ids(_node: Node) -> PackedStringArray:
	return PackedStringArray(["monitoring", "monitorable"])
