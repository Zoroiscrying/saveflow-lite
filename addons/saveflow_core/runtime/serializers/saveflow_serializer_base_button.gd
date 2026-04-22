class_name SaveFlowSerializerBaseButton
extends SaveFlowBuiltInSerializer


func get_serializer_id() -> String:
	return "base_button"


func get_display_name() -> String:
	return "Button State"


func supports_node(node: Node) -> bool:
	return node is BaseButton


func gather_from_node(node: Node) -> Variant:
	var target := node as BaseButton
	if target == null:
		return {}
	return {
		"disabled": target.disabled,
		"button_pressed": target.button_pressed,
	}


func apply_to_node(node: Node, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var target := node as BaseButton
	if target == null:
		return
	var payload: Dictionary = data
	if payload.has("disabled"):
		target.disabled = bool(payload["disabled"])
	if payload.has("button_pressed"):
		target.button_pressed = bool(payload["button_pressed"])


func describe_fields(_node: Node) -> Array:
	return [
		{"id": "disabled", "display_name": "Disabled"},
		{"id": "button_pressed", "display_name": "Pressed"},
	]


func recommended_field_ids(_node: Node) -> PackedStringArray:
	return PackedStringArray(["button_pressed"])
