class_name SaveFlowSerializerCanvasItem
extends SaveFlowBuiltInSerializer


func get_serializer_id() -> String:
	return "canvas_item_visibility"


func get_display_name() -> String:
	return "CanvasItem Visibility"


func supports_node(node: Node) -> bool:
	return node is CanvasItem


func gather_from_node(node: Node) -> Variant:
	var target := node as CanvasItem
	if target == null:
		return {}
	return {
		"visible": target.visible,
	}


func apply_to_node(node: Node, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var target := node as CanvasItem
	if target == null:
		return
	var payload: Dictionary = data
	if payload.has("visible"):
		target.visible = bool(payload["visible"])


func describe_fields(_node: Node) -> Array:
	return [
		{"id": "visible", "display_name": "Visible"},
	]


func recommended_field_ids(_node: Node) -> PackedStringArray:
	return PackedStringArray(["visible"])
