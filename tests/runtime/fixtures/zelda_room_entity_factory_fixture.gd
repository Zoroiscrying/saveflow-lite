@tool
extends SaveFlowEntityFactory

const SaveFlowNodeSourceScript := preload("res://addons/saveflow_lite/runtime/sources/saveflow_node_source.gd")
const SaveFlowIdentityScript := preload("res://addons/saveflow_lite/runtime/entities/saveflow_identity.gd")
const RoomEntityFixtureScript := preload("res://tests/runtime/fixtures/zelda_room_entity_fixture.gd")

var entities: Dictionary = {}
var target_container: Node = null
var spawn_count := 0


func can_handle_type(type_key: String) -> bool:
	return type_key == "enemy" or type_key == "chest"


func find_existing_entity(persistent_id: String, _context: Dictionary = {}) -> Node:
	var entity: Variant = entities.get(persistent_id, null)
	if is_instance_valid(entity):
		return entity
	entities.erase(persistent_id)
	return null


func spawn_entity_from_save(descriptor: Dictionary, _context: Dictionary = {}) -> Node:
	var persistent_id: String = String(descriptor.get("persistent_id", ""))
	var type_key: String = String(descriptor.get("type_key", ""))
	var node: Node2D = Node2D.new()
	node.name = persistent_id
	node.set_script(RoomEntityFixtureScript)
	node.set("entity_type", type_key)

	var identity: Node = Node.new()
	identity.name = "Identity"
	identity.set_script(SaveFlowIdentityScript)
	identity.set("persistent_id", persistent_id)
	identity.set("type_key", type_key)
	node.add_child(identity)

	var state_source: Node = Node.new()
	state_source.name = "State"
	state_source.set_script(SaveFlowNodeSourceScript)
	state_source.set("save_key", "state")
	node.add_child(state_source)

	if is_instance_valid(target_container):
		target_container.add_child(node)

	entities[persistent_id] = node
	spawn_count += 1
	return node


func apply_saved_data(node: Node, payload: Variant, _context: Dictionary = {}) -> void:
	if payload is Dictionary:
		var payload_dict: Dictionary = payload
		for child in node.get_children():
			if not (child is SaveFlowSource):
				continue
			var source: SaveFlowSource = child
			var source_key: String = source.get_source_key()
			if payload_dict.has(source_key):
				source.apply_save_data(payload_dict[source_key], {})
	node.set_meta("payload", payload)


func prepare_restore(restore_policy: int, _target_container: Node, _context: Dictionary = {}) -> void:
	if restore_policy == SaveFlowEntityCollectionSource.RestorePolicy.CLEAR_AND_RESTORE:
		entities.clear()
		spawn_count = 0
