## SaveFlowPrefabEntityFactory is the lowest-boilerplate runtime factory path.
## Use it when one or more entity `type_key`s map directly to prefab scenes and
## the default identity lookup + local save-graph restore behavior is enough.
@tool
class_name SaveFlowPrefabEntityFactory
extends SaveFlowEntityFactory

## The runtime container to write spawned prefab entities into. Leave empty only
## when `auto_create_container` is enabled and the factory should create one.
@export var target_container: Node:
	set(value):
		target_container = value
		_target_container_ref_path = _resolve_relative_node_path(value)
@export_storage var _target_container_ref_path: NodePath = NodePath()

## Enable this only when the container should be created by SaveFlow at runtime.
## The container will be created under the factory's parent using `container_name`.
@export var auto_create_container := false
## Used only when `auto_create_container` is enabled.
@export var container_name := "RuntimeEntities"

## The primary entity type this prefab factory owns.
@export var type_key: String = ""
## The prefab scene instantiated for the configured `type_key`.
@export var entity_scene: PackedScene

var _entity_index: Dictionary = {}


func _ready() -> void:
	_hydrate_target_container_from_ref_path()


func can_handle_type(requested_type_key: String) -> bool:
	return not type_key.is_empty() and requested_type_key == type_key


func get_supported_entity_types() -> PackedStringArray:
	if type_key.is_empty():
		return PackedStringArray()
	return PackedStringArray([type_key])


func get_target_container() -> Node:
	return _ensure_target_container(false)


func find_existing_entity(persistent_id: String, _context: Dictionary = {}) -> Node:
	_refresh_entity_index()
	var entity: Variant = _entity_index.get(persistent_id, null)
	if is_instance_valid(entity):
		return entity
	_entity_index.erase(persistent_id)
	return null


func spawn_entity_from_save(descriptor: Dictionary, context: Dictionary = {}) -> Node:
	var resolved_container := _ensure_target_container(true)
	if resolved_container == null:
		return null
	if entity_scene == null:
		return null

	var requested_type_key: String = String(descriptor.get("type_key", type_key))
	if not can_handle_type(requested_type_key):
		return null

	var entity := _instantiate_entity_scene(descriptor, context)
	if entity == null:
		return null
	resolved_container.add_child(entity)

	var persistent_id: String = String(descriptor.get("persistent_id", ""))
	_ensure_identity(entity, persistent_id, requested_type_key)
	_index_entity(entity)
	return entity


func apply_saved_data(node: Node, payload: Variant, context: Dictionary = {}) -> void:
	if not (payload is Dictionary):
		return
	var payload_dict: Dictionary = payload
	for source_variant in _get_ordered_entity_sources(node):
		var source: SaveFlowSource = source_variant
		if not source.can_load_source():
			continue
		var source_key: String = source.get_source_key()
		if not payload_dict.has(source_key):
			continue
		var source_payload: Variant = payload_dict[source_key]
		source.before_load(source_payload, context)
		var apply_result_variant: Variant = source.apply_save_data(source_payload, context)
		if apply_result_variant is SaveResult:
			var apply_result := apply_result_variant as SaveResult
			if not apply_result.ok:
				continue
		source.after_load(source_payload, context)


func prepare_restore(restore_policy: int, _target_container: Node, _context: Dictionary = {}) -> void:
	if restore_policy == SaveFlowEntityCollectionSource.RestorePolicy.CLEAR_AND_RESTORE:
		_entity_index.clear()
	else:
		_refresh_entity_index()


func describe_entity_factory_plan() -> Dictionary:
	var plan: Dictionary = super.describe_entity_factory_plan()
	var resolved_container := _ensure_target_container(false)
	plan["valid"] = not type_key.is_empty() and entity_scene != null and (resolved_container != null or auto_create_container)
	plan["factory_name"] = name
	plan["target_container_name"] = _describe_node_name(resolved_container)
	plan["target_container_path"] = _describe_node_path(resolved_container)
	plan["supported_entity_types"] = get_supported_entity_types()
	plan["can_provide_target_container"] = resolved_container != null or auto_create_container
	plan["uses_prefab_scene"] = entity_scene != null
	return plan


func _instantiate_entity_scene(_descriptor: Dictionary, _context: Dictionary = {}) -> Node:
	return entity_scene.instantiate() if entity_scene != null else null


func _ensure_target_container(allow_create: bool) -> Node:
	if is_instance_valid(target_container):
		if _target_container_ref_path.is_empty():
			_target_container_ref_path = _resolve_relative_node_path(target_container)
		return target_container
	if not _target_container_ref_path.is_empty():
		var resolved := get_node_or_null(_target_container_ref_path)
		if is_instance_valid(resolved):
			target_container = resolved
			return resolved
	if not allow_create or Engine.is_editor_hint() or not auto_create_container:
		return null

	var anchor := get_parent()
	if anchor == null:
		return null
	var existing := anchor.get_node_or_null(NodePath(container_name))
	if existing != null:
		target_container = existing
		_target_container_ref_path = _resolve_relative_node_path(existing)
		return existing

	var created := Node.new()
	created.name = container_name
	anchor.add_child(created)
	target_container = created
	_target_container_ref_path = _resolve_relative_node_path(created)
	return created


func _hydrate_target_container_from_ref_path() -> void:
	var resolved := _ensure_target_container(false)
	if is_instance_valid(resolved) and target_container == null:
		target_container = resolved


func _refresh_entity_index() -> void:
	_entity_index.clear()
	var resolved_container := _ensure_target_container(false)
	if resolved_container == null:
		return
	for child in resolved_container.get_children():
		var entity := child as Node
		if entity == null:
			continue
		_index_entity(entity)


func _index_entity(entity: Node) -> void:
	var identity := _find_identity(entity)
	if identity == null:
		return
	var persistent_id: String = identity.get_persistent_id()
	if persistent_id.is_empty():
		return
	_entity_index[persistent_id] = entity


func _ensure_identity(entity: Node, persistent_id: String, resolved_type_key: String) -> SaveFlowIdentity:
	var identity := _find_identity(entity)
	if identity == null:
		identity = SaveFlowIdentity.new()
		identity.name = "Identity"
		entity.add_child(identity)
	identity.persistent_id = persistent_id
	identity.type_key = resolved_type_key
	return identity


func _find_identity(entity: Node) -> SaveFlowIdentity:
	for child in entity.get_children():
		if child is SaveFlowIdentity:
			return child as SaveFlowIdentity
	return null


func _get_ordered_entity_sources(entity: Node) -> Array:
	var ordered_entries: Array = []
	var index := 0
	for child in entity.get_children():
		if child is SaveFlowSource:
			var source := child as SaveFlowSource
			ordered_entries.append(
				{
					"phase": source.get_phase(),
					"index": index,
					"source": source,
				}
			)
		index += 1
	ordered_entries.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var phase_a := int(a.get("phase", 0))
			var phase_b := int(b.get("phase", 0))
			if phase_a == phase_b:
				return int(a.get("index", 0)) < int(b.get("index", 0))
			return phase_a < phase_b
	)
	var ordered_sources: Array = []
	for entry_variant in ordered_entries:
		ordered_sources.append(entry_variant["source"])
	return ordered_sources


func _resolve_relative_node_path(node: Node) -> NodePath:
	if node == null:
		return NodePath()
	if not is_inside_tree() or not node.is_inside_tree():
		return NodePath()
	return get_path_to(node)
