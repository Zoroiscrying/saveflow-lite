class_name SaveFlowSerializerOptionButton
extends SaveFlowBuiltInSerializer


func get_serializer_id() -> String:
	return "option_button"


func get_display_name() -> String:
	return "OptionButton"


func supports_node(node: Node) -> bool:
	return node is OptionButton


func gather_from_node(node: Node) -> Variant:
	var target := node as OptionButton
	if target == null:
		return {}
	return {
		"selected": target.selected,
		"disabled": target.disabled,
	}


func apply_to_node(node: Node, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var target := node as OptionButton
	if target == null:
		return
	var payload: Dictionary = data
	if payload.has("disabled"):
		target.disabled = bool(payload["disabled"])
	if payload.has("selected"):
		var selected_index: int = int(payload["selected"])
		if selected_index >= 0 and selected_index < target.item_count:
			target.select(selected_index)


func describe_fields(_node: Node) -> Array:
	return [
		{"id": "selected", "display_name": "Selected Item"},
		{"id": "disabled", "display_name": "Disabled"},
	]


func recommended_field_ids(_node: Node) -> PackedStringArray:
	return PackedStringArray(["selected"])
