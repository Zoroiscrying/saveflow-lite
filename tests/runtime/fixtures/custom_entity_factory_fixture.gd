@tool
extends "res://addons/saveflow_lite/runtime/entities/saveflow_entity_factory.gd"

var entities: Dictionary = {}
var spawn_count := 0


func can_handle_type(type_key: String) -> bool:
	return type_key == "enemy"


func find_existing_entity(persistent_id: String, _context: Dictionary = {}) -> Node:
	return entities.get(persistent_id, null)


func spawn_entity_from_save(descriptor: Dictionary, _context: Dictionary = {}) -> Node:
	var persistent_id: String = String(descriptor.get("persistent_id", ""))
	var node := Node.new()
	node.name = persistent_id
	if get_parent() != null:
		get_parent().add_child(node)
	entities[persistent_id] = node
	spawn_count += 1
	return node


func apply_saved_data(node: Node, payload: Variant, _context: Dictionary = {}) -> void:
	node.set_meta("payload", payload)


func prepare_restore(restore_policy: int, _target_container: Node, _context: Dictionary = {}) -> void:
	if restore_policy == SaveFlowEntityCollectionSource.RestorePolicy.CLEAR_AND_RESTORE:
		entities.clear()
		spawn_count = 0
