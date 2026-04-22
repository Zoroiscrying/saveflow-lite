class_name SaveFlowSerializerRange
extends SaveFlowBuiltInSerializer


func get_serializer_id() -> String:
	return "range_value"


func get_display_name() -> String:
	return "Range Value"


func supports_node(node: Node) -> bool:
	return node is Range


func gather_from_node(node: Node) -> Variant:
	var target := node as Range
	if target == null:
		return {}
	return {
		"value": target.value,
	}


func apply_to_node(node: Node, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var target := node as Range
	if target == null:
		return
	var payload: Dictionary = data
	if payload.has("value"):
		target.value = float(payload["value"])


func describe_fields(_node: Node) -> Array:
	return [
		{"id": "value", "display_name": "Value"},
	]


func recommended_field_ids(_node: Node) -> PackedStringArray:
	return PackedStringArray(["value"])
