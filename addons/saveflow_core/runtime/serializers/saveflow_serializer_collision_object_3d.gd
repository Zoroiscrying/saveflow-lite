class_name SaveFlowSerializerCollisionObject3D
extends SaveFlowBuiltInSerializer


func get_serializer_id() -> String:
	return "collision_object_3d"


func get_display_name() -> String:
	return "CollisionObject3D Layers"


func supports_node(node: Node) -> bool:
	return node is CollisionObject3D


func gather_from_node(node: Node) -> Variant:
	var target := node as CollisionObject3D
	if target == null:
		return {}
	return {
		"collision_layer": target.collision_layer,
		"collision_mask": target.collision_mask,
	}


func apply_to_node(node: Node, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var target := node as CollisionObject3D
	if target == null:
		return
	var payload: Dictionary = data
	if payload.has("collision_layer"):
		target.collision_layer = int(payload["collision_layer"])
	if payload.has("collision_mask"):
		target.collision_mask = int(payload["collision_mask"])


func describe_fields(_node: Node) -> Array:
	return [
		{"id": "collision_layer", "display_name": "Collision Layer"},
		{"id": "collision_mask", "display_name": "Collision Mask"},
	]


func recommended_field_ids(_node: Node) -> PackedStringArray:
	return PackedStringArray(["collision_layer", "collision_mask"])
