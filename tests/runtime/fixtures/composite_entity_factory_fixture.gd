@tool
extends SaveFlowEntityFactory

const SaveFlowNodeSourceScript := preload("res://addons/saveflow_lite/runtime/sources/saveflow_node_source.gd")
const SaveFlowIdentityScript := preload("res://addons/saveflow_lite/runtime/entities/saveflow_identity.gd")
const SaveFlowScopeFixtureScript := preload("res://tests/runtime/fixtures/saveflow_scope_fixture.gd")
const PlayerStateFixtureScript := preload("res://tests/runtime/fixtures/player_state_fixture.gd")
const AbilityStateFixtureScript := preload("res://tests/runtime/fixtures/ability_state_fixture.gd")

var entities: Dictionary = {}
var target_container: Node = null
var spawn_count := 0


func can_handle_type(type_key: String) -> bool:
	return type_key == "enemy_composite"


func find_existing_entity(persistent_id: String, _context: Dictionary = {}) -> Node:
	var entity: Variant = entities.get(persistent_id, null)
	if is_instance_valid(entity):
		return entity
	entities.erase(persistent_id)
	return null


func spawn_entity_from_save(descriptor: Dictionary, _context: Dictionary = {}) -> Node:
	var persistent_id: String = String(descriptor.get("persistent_id", ""))
	var entity: Node = _build_entity(persistent_id)
	if is_instance_valid(target_container):
		target_container.add_child(entity)
	entities[persistent_id] = entity
	spawn_count += 1
	return entity


func apply_saved_data(node: Node, payload: Variant, _context: Dictionary = {}) -> void:
	node.set_meta("payload", payload)


func prepare_restore(restore_policy: int, _target_container: Node, _context: Dictionary = {}) -> void:
	if restore_policy == SaveFlowEntityCollectionSource.RestorePolicy.CLEAR_AND_RESTORE:
		entities.clear()
		spawn_count = 0


func _build_entity(persistent_id: String) -> Node:
	var entity := Node.new()
	entity.name = persistent_id.capitalize()

	var identity := Node.new()
	identity.name = "Identity"
	identity.set_script(SaveFlowIdentityScript)
	identity.set("persistent_id", persistent_id)
	identity.set("type_key", "enemy_composite")
	entity.add_child(identity)

	var core := Node.new()
	core.name = "CoreState"
	core.set_script(PlayerStateFixtureScript)
	core.set("hp", 0)
	core.set("coins", 0)
	entity.add_child(core)

	var abilities := Node.new()
	abilities.name = "AbilityState"
	abilities.set_script(AbilityStateFixtureScript)
	abilities.set("cooldown_slot", 0)
	abilities.set("active_tags", PackedStringArray())
	entity.add_child(abilities)

	var scope := Node.new()
	scope.name = "EntityScope"
	scope.set_script(SaveFlowScopeFixtureScript)
	scope.set("scope_key", "entity")
	scope.set("scope_label", persistent_id)
	entity.add_child(scope)

	var core_source := Node.new()
	core_source.name = "CoreSource"
	core_source.set_script(SaveFlowNodeSourceScript)
	core_source.set("save_key", "core")
	core_source.set("target", core)
	scope.add_child(core_source)

	var abilities_source := Node.new()
	abilities_source.name = "AbilitiesSource"
	abilities_source.set_script(SaveFlowNodeSourceScript)
	abilities_source.set("save_key", "abilities")
	abilities_source.set("target", abilities)
	scope.add_child(abilities_source)

	return entity
