class_name SaveFlowSerializerLineEdit
extends SaveFlowBuiltInSerializer


func get_serializer_id() -> String:
	return "line_edit"


func get_display_name() -> String:
	return "LineEdit"


func supports_node(node: Node) -> bool:
	return node is LineEdit


func gather_from_node(node: Node) -> Variant:
	var target := node as LineEdit
	if target == null:
		return {}
	return {
		"text": target.text,
		"editable": target.editable,
		"secret": target.secret,
	}


func apply_to_node(node: Node, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var target := node as LineEdit
	if target == null:
		return
	var payload: Dictionary = data
	if payload.has("text"):
		target.text = String(payload["text"])
	if payload.has("editable"):
		target.editable = bool(payload["editable"])
	if payload.has("secret"):
		target.secret = bool(payload["secret"])


func describe_fields(_node: Node) -> Array:
	return [
		{"id": "text", "display_name": "Text"},
		{"id": "editable", "display_name": "Editable"},
		{"id": "secret", "display_name": "Secret"},
	]


func recommended_field_ids(_node: Node) -> PackedStringArray:
	return PackedStringArray(["text"])
