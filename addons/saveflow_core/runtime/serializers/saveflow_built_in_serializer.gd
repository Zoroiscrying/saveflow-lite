@abstract
class_name SaveFlowBuiltInSerializer
extends RefCounted


@abstract
func get_serializer_id() -> String


func get_display_name() -> String:
	return get_serializer_id()


@abstract
func supports_node(_node: Node) -> bool


@abstract
func gather_from_node(_node: Node) -> Variant


@abstract
func apply_to_node(_node: Node, _data: Variant) -> void


func describe_fields(_node: Node) -> Array:
	return []


func recommended_field_ids(_node: Node) -> PackedStringArray:
	return PackedStringArray()
