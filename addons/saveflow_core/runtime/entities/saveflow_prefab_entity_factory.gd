## SaveFlowPrefabEntityFactory is the lowest-boilerplate runtime factory path.
## Use it when one entity `type_key` maps directly to one prefab scene and
## the default identity lookup + local save-graph restore behavior is enough.
@icon("res://addons/saveflow_lite/icons/components/saveflow_prefab_entity_factory_icon.svg")
@tool
class_name SaveFlowPrefabEntityFactory
extends SaveFlowEntityFactory

## The runtime container to write spawned prefab entities into. Leave empty only
## when `auto_create_container` is enabled and the factory should create one.
@export var target_container: Node:
	set(value):
		target_container = value
		_target_container_ref_path = _resolve_relative_node_path(value)
		_refresh_editor_state()
@export_storage var _target_container_ref_path: NodePath = NodePath()

## Enable this only when the container should be created by SaveFlow at runtime.
## The container will be created under the factory's parent using `container_name`.
@export var auto_create_container := false:
	set(value):
		var previous_value := auto_create_container
		auto_create_container = value
		_refresh_editor_state(previous_value != auto_create_container)
## Used only when `auto_create_container` is enabled.
@export var container_name := "RuntimeEntities":
	set(value):
		container_name = value if not String(value).strip_edges().is_empty() else "RuntimeEntities"
		_refresh_editor_state()

## The primary entity type this prefab factory owns. Leave empty to infer one
## from the prefab scene file name.
@export var type_key: String = "":
	set(value):
		type_key = value.strip_edges()
		_refresh_editor_state()
## The prefab scene instantiated for the configured `type_key`.
@export var entity_scene: PackedScene:
	set(value):
		entity_scene = value
		_refresh_editor_state()

var _entity_index: Dictionary = {}


func _ready() -> void:
	_hydrate_target_container_from_ref_path()
	_refresh_editor_state()


func can_handle_type(requested_type_key: String) -> bool:
	var normalized_requested_type_key := requested_type_key.strip_edges()
	if normalized_requested_type_key.is_empty():
		return false
	return normalized_requested_type_key == _effective_type_key()


func get_supported_entity_types() -> PackedStringArray:
	var effective_type_key := _effective_type_key()
	if effective_type_key.is_empty():
		return PackedStringArray()
	return PackedStringArray([effective_type_key])


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

	var entity_descriptor := resolve_entity_descriptor(descriptor)
	var requested_type_key := entity_descriptor.type_key
	if requested_type_key.is_empty():
		requested_type_key = _effective_type_key()
	if not can_handle_type(requested_type_key):
		return null

	var entity := _instantiate_entity_scene(descriptor, context)
	if entity == null:
		return null
	resolved_container.add_child(entity)

	_ensure_identity(entity, entity_descriptor.persistent_id, requested_type_key)
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
	var problems: PackedStringArray = PackedStringArray(plan.get("problems", PackedStringArray()))
	var effective_type_key := _effective_type_key()
	var inferred_type_key := _infer_type_key_from_scene()
	if effective_type_key.is_empty():
		problems.append("type_key is empty and no type could be inferred from entity_scene")
	if entity_scene == null:
		problems.append("entity_scene is not assigned")
	if resolved_container == null and not auto_create_container:
		problems.append("target_container is missing and auto_create_container is disabled")
	plan["valid"] = problems.is_empty()
	plan["reason"] = _resolve_prefab_plan_reason(problems)
	plan["problems"] = problems
	plan["factory_name"] = name
	plan["target_container_name"] = _describe_node_name(resolved_container)
	plan["target_container_path"] = _describe_node_path(resolved_container)
	plan["supported_entity_types"] = PackedStringArray([effective_type_key]) if not effective_type_key.is_empty() else PackedStringArray()
	plan["can_provide_target_container"] = resolved_container != null or auto_create_container
	plan["uses_prefab_scene"] = entity_scene != null
	plan["auto_create_container"] = auto_create_container
	plan["container_name"] = container_name
	plan["uses_inferred_type_key"] = type_key.is_empty() and not inferred_type_key.is_empty()
	plan["inferred_type_key"] = inferred_type_key
	plan["type_key_mode"] = _describe_type_key_mode(inferred_type_key)
	plan["routing_summary"] = _describe_routing_summary(effective_type_key)
	return plan


func _resolve_prefab_plan_reason(problems: PackedStringArray) -> String:
	if problems.is_empty():
		return ""
	if _effective_type_key().is_empty():
		return "MISSING_TYPE_KEY"
	if entity_scene == null:
		return "MISSING_ENTITY_SCENE"
	return "TARGET_CONTAINER_NOT_RESOLVED"


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


func _validate_property(property: Dictionary) -> void:
	if String(property.get("name", "")) == "target_container":
		property["usage"] = PROPERTY_USAGE_DEFAULT if not auto_create_container else PROPERTY_USAGE_NO_EDITOR
	elif String(property.get("name", "")) == "container_name":
		property["usage"] = PROPERTY_USAGE_DEFAULT if auto_create_container else PROPERTY_USAGE_NO_EDITOR


func _effective_type_key() -> String:
	if not type_key.is_empty():
		return type_key
	return _infer_type_key_from_scene()


func _infer_type_key_from_scene() -> String:
	if entity_scene == null:
		return ""
	var resource_path := String(entity_scene.resource_path).strip_edges()
	if resource_path.is_empty():
		return ""
	return resource_path.get_file().get_basename().to_snake_case()


func _refresh_editor_state(refresh_property_list: bool = false) -> void:
	if not Engine.is_editor_hint():
		return
	update_configuration_warnings()
	if refresh_property_list:
		notify_property_list_changed()


func _describe_type_key_mode(inferred_type_key: String) -> String:
	if not type_key.is_empty():
		return "Explicit single key"
	if not inferred_type_key.is_empty():
		return "Inferred single key"
	return "Unresolved"


func _describe_routing_summary(effective_type_key: String) -> String:
	if effective_type_key.is_empty():
		return "No type routing is configured yet."
	var container_summary := "the assigned target container"
	if auto_create_container:
		container_summary = "runtime container `%s`" % container_name
	elif target_container == null and _target_container_ref_path.is_empty():
		container_summary = "the resolved factory target container"
	return "Type `%s` spawns the configured prefab into %s." % [effective_type_key, container_summary]
