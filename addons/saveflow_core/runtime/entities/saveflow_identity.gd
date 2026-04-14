class_name SaveFlowIdentity
extends Node

@export var persistent_id: String = ""
@export var type_key: String = ""


func get_persistent_id() -> String:
	if not persistent_id.is_empty():
		return persistent_id
	return name.to_snake_case()


func get_type_key() -> String:
	if not type_key.is_empty():
		return type_key
	return get_parent().name.to_snake_case() if get_parent() != null else ""


func describe_identity() -> Dictionary:
	return {
		"persistent_id": get_persistent_id(),
		"type_key": get_type_key(),
	}
