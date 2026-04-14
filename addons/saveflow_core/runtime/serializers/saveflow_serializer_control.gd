class_name SaveFlowSerializerControl
extends SaveFlowBuiltInSerializer


func get_serializer_id() -> String:
	return "control_layout"


func get_display_name() -> String:
	return "Control Layout"


func supports_node(node: Node) -> bool:
	return node is Control


func gather_from_node(node: Node) -> Variant:
	var target := node as Control
	if target == null:
		return {}
	return {
		"position": target.position,
		"size": target.size,
		"rotation": target.rotation,
		"scale": target.scale,
	}


func apply_to_node(node: Node, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var target := node as Control
	if target == null:
		return
	var payload: Dictionary = data
	if payload.has("position"):
		target.position = payload["position"]
	if payload.has("size"):
		target.size = payload["size"]
	if payload.has("rotation"):
		target.rotation = float(payload["rotation"])
	if payload.has("scale"):
		target.scale = payload["scale"]
