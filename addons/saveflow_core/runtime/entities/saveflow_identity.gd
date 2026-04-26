@icon("res://addons/saveflow_lite/icons/components/saveflow_identity_icon.svg")
class_name SaveFlowIdentity
extends Node

@export var persistent_id: String = ""
@export var type_key: String = ""
## Optional spawn/routing data copied into the entity descriptor.
## Keep gameplay state in the entity payload; use this only for small data the
## factory needs before the entity payload can be applied.
@export var descriptor_extra: Dictionary = {}


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
		"descriptor_extra_keys": PackedStringArray(_dictionary_key_names(descriptor_extra)),
	}


func get_saveflow_entity_extra() -> Dictionary:
	return descriptor_extra.duplicate(true)


func get_saveflow_entity_descriptor_extra() -> Dictionary:
	return get_saveflow_entity_extra()


func _dictionary_key_names(data: Dictionary) -> Array:
	var names: Array = []
	for key in data.keys():
		names.append(String(key))
	names.sort()
	return names
