class_name SaveFlowSerializerCollisionShape3D
extends SaveFlowBuiltInSerializer


func get_serializer_id() -> String:
	return "collision_shape_3d"


func get_display_name() -> String:
	return "CollisionShape3D"


func supports_node(node: Node) -> bool:
	return node is CollisionShape3D


func gather_from_node(node: Node) -> Variant:
	var target := node as CollisionShape3D
	if target == null:
		return {}
	return {
		"disabled": target.disabled,
	}


func apply_to_node(node: Node, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var target := node as CollisionShape3D
	if target == null:
		return
	var payload: Dictionary = data
	if payload.has("disabled"):
		target.disabled = bool(payload["disabled"])


func describe_fields(_node: Node) -> Array:
	return [
		{"id": "disabled", "display_name": "Disabled"},
	]


func recommended_field_ids(_node: Node) -> PackedStringArray:
	return PackedStringArray(["disabled"])
