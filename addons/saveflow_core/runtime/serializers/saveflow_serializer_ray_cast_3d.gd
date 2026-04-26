class_name SaveFlowSerializerRayCast3D
extends SaveFlowBuiltInSerializer


func get_serializer_id() -> String:
	return "ray_cast_3d"


func get_display_name() -> String:
	return "RayCast3D"


func supports_node(node: Node) -> bool:
	return node is RayCast3D


func gather_from_node(node: Node) -> Variant:
	var target := node as RayCast3D
	if target == null:
		return {}
	return {
		"enabled": target.enabled,
		"target_position": target.target_position,
		"collision_mask": target.collision_mask,
		"exclude_parent": target.exclude_parent,
		"collide_with_areas": target.collide_with_areas,
		"collide_with_bodies": target.collide_with_bodies,
		"hit_from_inside": target.hit_from_inside,
		"hit_back_faces": target.hit_back_faces,
	}


func apply_to_node(node: Node, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var target := node as RayCast3D
	if target == null:
		return
	var payload: Dictionary = data
	if payload.has("enabled"):
		target.enabled = bool(payload["enabled"])
	if payload.has("target_position"):
		target.target_position = payload["target_position"]
	if payload.has("collision_mask"):
		target.collision_mask = int(payload["collision_mask"])
	if payload.has("exclude_parent"):
		target.exclude_parent = bool(payload["exclude_parent"])
	if payload.has("collide_with_areas"):
		target.collide_with_areas = bool(payload["collide_with_areas"])
	if payload.has("collide_with_bodies"):
		target.collide_with_bodies = bool(payload["collide_with_bodies"])
	if payload.has("hit_from_inside"):
		target.hit_from_inside = bool(payload["hit_from_inside"])
	if payload.has("hit_back_faces"):
		target.hit_back_faces = bool(payload["hit_back_faces"])


func describe_fields(_node: Node) -> Array:
	return [
		{"id": "enabled", "display_name": "Enabled"},
		{"id": "target_position", "display_name": "Target Position"},
		{"id": "collision_mask", "display_name": "Collision Mask"},
		{"id": "exclude_parent", "display_name": "Exclude Parent"},
		{"id": "collide_with_areas", "display_name": "Collide With Areas"},
		{"id": "collide_with_bodies", "display_name": "Collide With Bodies"},
		{"id": "hit_from_inside", "display_name": "Hit From Inside"},
		{"id": "hit_back_faces", "display_name": "Hit Back Faces"},
	]


func recommended_field_ids(_node: Node) -> PackedStringArray:
	return PackedStringArray(
		[
			"enabled",
			"target_position",
			"collision_mask",
			"exclude_parent",
			"collide_with_areas",
			"collide_with_bodies",
		]
	)
