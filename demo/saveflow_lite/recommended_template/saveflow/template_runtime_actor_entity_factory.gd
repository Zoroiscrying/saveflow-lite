## Minimal demo factory for the recommended runtime-entity path.
## This file intentionally shows the smallest contract most projects need:
## advertise type ownership, spawn a prefab, and apply descriptor payload.
@tool
extends "res://addons/saveflow_lite/runtime/entities/saveflow_entity_factory.gd"

const ActorPrefabScene := preload("res://demo/saveflow_lite/recommended_template/scenes/prefabs/template_runtime_actor.tscn")

## The runtime container this demo factory writes spawned actors into.
@export var target_container: Node
@export_storage var _target_container_ref_path: NodePath = NodePath()

var entities: Dictionary = {}


func _ready() -> void:
	_hydrate_target_container_from_ref_path()


func can_handle_type(type_key: String) -> bool:
	return type_key == "slime" or type_key == "bat"


func get_supported_entity_types() -> PackedStringArray:
	return PackedStringArray(["slime", "bat"])


func get_target_container() -> Node:
	return _resolve_target_container()


func find_existing_entity(persistent_id: String, _context: Dictionary = {}) -> Node:
	var entity: Variant = entities.get(persistent_id, null)
	if is_instance_valid(entity):
		return entity
	entities.erase(persistent_id)
	return null


func spawn_entity_from_save(descriptor: Dictionary, _context: Dictionary = {}) -> Node:
	var persistent_id: String = String(descriptor.get("persistent_id", "runtime_actor"))
	var type_key: String = String(descriptor.get("type_key", "slime"))
	var actor := _instantiate_actor(persistent_id, type_key)
	var resolved_target_container := _resolve_target_container()
	if resolved_target_container != null:
		resolved_target_container.add_child(actor)
		entities[persistent_id] = actor
	return actor


func apply_saved_data(node: Node, payload: Variant, _context: Dictionary = {}) -> void:
	node.set_meta("fallback_payload", payload)


func prepare_restore(restore_policy: int, _target_container: Node, _context: Dictionary = {}) -> void:
	if restore_policy == SaveFlowEntityCollectionSource.RestorePolicy.CLEAR_AND_RESTORE:
		entities.clear()


func spawn_template_actor(persistent_id: String, type_key: String, position: Vector2, hp: int, tags: PackedStringArray, loot_table: Array) -> Node2D:
	var actor := _instantiate_actor(persistent_id, type_key)
	var resolved_target_container := _resolve_target_container()
	if resolved_target_container != null:
		resolved_target_container.add_child(actor)
		entities[persistent_id] = actor
	var actor_state := actor as Node2D
	if actor_state != null and actor_state.has_method("reset_state"):
		actor_state.call(
			"reset_state",
			{
				"actor_type": type_key,
				"hp": hp,
				"tags": tags,
				"loot_table": loot_table,
				"position": position,
				"is_alerted": false,
			}
		)
	return actor_state


func unregister_actor(persistent_id: String) -> void:
	entities.erase(persistent_id)


func clear_runtime() -> void:
	for entity_variant in entities.values():
		var entity := entity_variant as Node
		if is_instance_valid(entity):
			entity.queue_free()
	entities.clear()


func _instantiate_actor(persistent_id: String, type_key: String) -> Node2D:
	var actor := ActorPrefabScene.instantiate() as Node2D
	actor.name = persistent_id
	var identity := actor.get_node_or_null("Identity")
	if identity != null:
		identity.set("persistent_id", persistent_id)
		identity.set("type_key", type_key)
	return actor


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
