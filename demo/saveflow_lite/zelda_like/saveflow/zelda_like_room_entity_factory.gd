@tool
extends "res://addons/saveflow_lite/runtime/entities/saveflow_entity_factory.gd"

const EntityPrefabScene := preload("res://demo/saveflow_lite/zelda_like/scenes/prefabs/zelda_like_entity_prefab.tscn")
const RoomEntityStateScript := preload("res://demo/saveflow_lite/zelda_like/gameplay/zelda_like_room_entity_state.gd")

@export var target_container: Node
@export_storage var _target_container_ref_path: NodePath = NodePath()

var entities: Dictionary = {}
var spawn_count := 0


func _ready() -> void:
	_hydrate_target_container_from_ref_path()


func can_handle_type(type_key: String) -> bool:
	return type_key == "enemy" or type_key == "chest"


func get_supported_entity_types() -> PackedStringArray:
	return PackedStringArray(["enemy", "chest"])


func get_target_container() -> Node:
	return _resolve_target_container()


func find_existing_entity(persistent_id: String, _context: Dictionary = {}) -> Node:
	var entity: Variant = entities.get(persistent_id, null)
	if is_instance_valid(entity):
		return entity
	entities.erase(persistent_id)
	return null


func spawn_entity_from_save(descriptor: Dictionary, _context: Dictionary = {}) -> Node:
	var persistent_id: String = String(descriptor.get("persistent_id", ""))
	var type_key: String = String(descriptor.get("type_key", "enemy"))
	var entity := create_entity_shell(persistent_id, type_key)
	var resolved_target_container := _resolve_target_container()
	if is_instance_valid(resolved_target_container):
		resolved_target_container.add_child(entity)
	entities[persistent_id] = entity
	spawn_count += 1
	return entity


func apply_saved_data(node: Node, payload: Variant, _context: Dictionary = {}) -> void:
	node.set_meta("payload", payload)


func prepare_restore(restore_policy: int, _target_container: Node, _context: Dictionary = {}) -> void:
	if restore_policy == SaveFlowEntityCollectionSource.RestorePolicy.CLEAR_AND_RESTORE:
		clear_registry()


func create_entity_from_template(template: Dictionary, room_id: String) -> Area2D:
	var persistent_id: String = String(template.get("persistent_id", ""))
	var type_key: String = String(template.get("type_key", "enemy"))
	var entity := create_entity_shell(persistent_id, type_key)
	var core_state := {
		"entity_type": type_key,
		"room_id": room_id,
		"hp": int(template.get("hp", 0)),
		"is_open": bool(template.get("is_open", false)),
		"loot_table": Array(template.get("loot_table", [])).duplicate(true),
		"tags_set": Dictionary(template.get("tags_set", {})).duplicate(true),
		"patrol_route": PackedStringArray(template.get("patrol_route", PackedStringArray())),
		"touch_damage": int(template.get("touch_damage", 1)),
		"rupee_value": int(template.get("rupee_value", 0)),
		"position": Vector2(template.get("position", Vector2.ZERO)),
	}
	var visual_state := {
		"pose": String(template.get("pose", "idle")),
		"mood": String(template.get("mood", "calm")),
		"facing": String(template.get("facing", "left")),
		"accent": String(template.get("accent", "moss")),
		"ornament_flags": Dictionary(template.get("ornament_flags", {})).duplicate(true),
	}
	entity.call("reset_state", core_state, visual_state)
	return entity


func register_entity(persistent_id: String, entity: Node) -> void:
	if persistent_id.is_empty() or entity == null:
		return
	entities[persistent_id] = entity


func unregister_entity(persistent_id: String) -> void:
	entities.erase(persistent_id)


func clear_registry() -> void:
	entities.clear()
	spawn_count = 0


func create_entity_shell(persistent_id: String, type_key: String) -> Area2D:
	var entity := EntityPrefabScene.instantiate() as Area2D
	entity.name = persistent_id.capitalize()
	if entity == null:
		entity = Area2D.new()
		entity.set_script(RoomEntityStateScript)
	var identity := entity.get_node_or_null("Identity")
	if identity != null:
		identity.set("persistent_id", persistent_id)
		identity.set("type_key", type_key)
	return entity


func _resolve_target_container() -> Node:
	if is_instance_valid(target_container):
		if _target_container_ref_path.is_empty():
			_target_container_ref_path = _resolve_relative_node_path(target_container)
		return target_container
	if _target_container_ref_path.is_empty():
		return null
	var resolved := get_node_or_null(_target_container_ref_path)
	if is_instance_valid(resolved):
		return resolved
	return null


func _hydrate_target_container_from_ref_path() -> void:
	var resolved := _resolve_target_container()
	if is_instance_valid(resolved) and target_container == null:
		target_container = resolved


func _resolve_relative_node_path(node: Node) -> NodePath:
	if node == null:
		return NodePath()
	if not is_inside_tree() or not node.is_inside_tree():
		return NodePath()
	return get_path_to(node)
