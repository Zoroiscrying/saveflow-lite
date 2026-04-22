class_name SaveFlowSerializerTextEdit
extends SaveFlowBuiltInSerializer


func get_serializer_id() -> String:
	return "text_edit"


func get_display_name() -> String:
	return "TextEdit"


func supports_node(node: Node) -> bool:
	return node is TextEdit


func gather_from_node(node: Node) -> Variant:
	var target := node as TextEdit
	if target == null:
		return {}
	return {
		"text": target.text,
		"editable": target.editable,
	}


func apply_to_node(node: Node, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var target := node as TextEdit
	if target == null:
		return
	var payload: Dictionary = data
	if payload.has("text"):
		target.text = String(payload["text"])
	if payload.has("editable"):
		target.editable = bool(payload["editable"])


func describe_fields(_node: Node) -> Array:
	return [
		{"id": "text", "display_name": "Text"},
		{"id": "editable", "display_name": "Editable"},
	]


func recommended_field_ids(_node: Node) -> PackedStringArray:
	return PackedStringArray(["text"])
