class_name SaveFlowSerializerNode3D
extends SaveFlowBuiltInSerializer


func get_serializer_id() -> String:
	return "node3d_transform"


func get_display_name() -> String:
	return "Node3D Transform"


func supports_node(node: Node) -> bool:
	return node is Node3D


func gather_from_node(node: Node) -> Variant:
	var target := node as Node3D
	if target == null:
		return {}
	return {
		"position": target.position,
		"rotation": target.rotation,
		"scale": target.scale,
	}


func apply_to_node(node: Node, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var target := node as Node3D
	if target == null:
		return
	var payload: Dictionary = data
	if payload.has("position"):
		target.position = payload["position"]
	if payload.has("rotation"):
		target.rotation = payload["rotation"]
	if payload.has("scale"):
		target.scale = payload["scale"]
