## SaveFlowEntityCollectionSource owns one changing set of runtime entities.
## It gathers entity descriptors from a container and delegates restore to
## SaveFlow + the configured entity factory.
@tool
class_name SaveFlowEntityCollectionSource
extends SaveFlowSource

enum RestorePolicy {
	APPLY_EXISTING,
	CREATE_MISSING,
	CLEAR_AND_RESTORE,
}

enum FailurePolicy {
	REPORT_ONLY,
	FAIL_ON_MISSING_OR_INVALID,
}

## Optional override for the container that owns this runtime set. Leave empty
## for the common case where the collection source sits directly under the container.
@export var target_container: Node:
	set(value):
		target_container = value
		_has_explicit_target_container = value != null
		_target_container_ref_path = _resolve_relative_node_path(value)
		_refresh_editor_preview()
@export_storage var _target_container_ref_path: NodePath = NodePath()
## Failure policy is separate from restore policy:
## - restore policy decides how the set is rebuilt
## - failure policy decides whether missing/invalid entities should fail the load
## Use Report Only while iterating or when partial recovery is acceptable.
## Use Fail On Missing Or Invalid when the collection must be consistent after load.
@export_enum("Report Only", "Fail On Missing Or Invalid")
var failure_policy: int = FailurePolicy.FAIL_ON_MISSING_OR_INVALID:
	set(value):
		failure_policy = _sanitize_failure_policy(value)
		_refresh_editor_preview()
## Pick restore policy before touching factory code:
## - Apply Existing: never spawn; good for pre-owned sets
## - Create Missing: default for most runtime collections
## - Clear And Restore: use when stale runtime entities must never survive load
@export_enum("Apply Existing", "Create Missing", "Clear And Restore")
var restore_policy: int = RestorePolicy.CREATE_MISSING:
	set(value):
		restore_policy = _sanitize_restore_policy(value)
		_refresh_editor_preview()
## Keep this enabled for most authored runtime containers. Turn it off only when
## real entities live deeper in the container tree and you explicitly want recursive discovery.
@export var include_direct_children_only: bool = true:
	set(value):
		include_direct_children_only = value
		_refresh_editor_preview()
## The factory owns runtime find, spawn, and apply logic for this collection's
## entities. The collection source owns only descriptor gathering and restore flow.
@export var entity_factory: SaveFlowEntityFactory:
	set(value):
		entity_factory = value
		_entity_factory_ref_path = _resolve_relative_node_path(value)
		_refresh_editor_preview()
## Leave auto-registration on for the standard scene-owned workflow. Disable it
## only when registration is handled manually outside this collection source.
@export var auto_register_factory := true:
	set(value):
		auto_register_factory = value
		_refresh_editor_preview()
@export_storage var _entity_factory_ref_path: NodePath = NodePath()

var _current_context: Dictionary = {}
var _last_report: Dictionary = {}
var _has_explicit_target_container := false


func before_save(context: Dictionary = {}) -> void:
	_current_context = context


func before_load(_payload: Variant, context: Dictionary = {}) -> void:
	_current_context = context


func _ready() -> void:
	_hydrate_target_container_from_ref_path()
	_hydrate_entity_factory_from_ref_path()
	if Engine.is_editor_hint():
		return
	_ensure_entity_factory_registration()


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	_unregister_entity_factory()


func describe_source() -> Dictionary:
	var description := super.describe_source()
	description["kind"] = "entity_collection"
	description["target_path"] = _describe_target_path(_resolve_target())
	description["failure_policy"] = failure_policy
	description["restore_policy"] = restore_policy
	description["last_report"] = _last_report.duplicate(true)
	description["entity_factory_path"] = _describe_node_path(entity_factory)
	description["auto_register_factory"] = auto_register_factory
	description["plan"] = describe_entity_collection_plan()
	return description


func gather_save_data() -> Variant:
	var descriptors: Array = []
	var missing_identity_nodes: PackedStringArray = []
	for entity in _collect_entities():
		var identity: Node = _find_identity(entity)
		if identity == null:
			_append_unique_string(missing_identity_nodes, _describe_node_path(entity))
			continue

		var payload: Dictionary = _collect_entity_payload(entity)
		descriptors.append(
			{
				"persistent_id": identity.get_persistent_id(),
				"type_key": identity.get_type_key(),
				"payload": payload,
			}
		)

	_last_report = {
		"descriptor_count": descriptors.size(),
		"missing_identity_nodes": missing_identity_nodes,
	}
	return {
		"descriptors": descriptors,
		"missing_identity_nodes": missing_identity_nodes,
	}


## Runtime collections restore in two stages:
## 1. prepare the target set according to restore policy
## 2. hand descriptors to SaveFlow so factories can find/spawn/apply entities
func apply_save_data(data: Variant, context: Dictionary = {}) -> SaveResult:
	if not (data is Dictionary):
		return error_result(
			SaveError.INVALID_FORMAT,
			"INVALID_FORMAT",
			"entity collection payload must be a dictionary",
			{"source_key": get_source_key()}
		)

	var payload: Dictionary = data
	var descriptors: Array = Array(payload.get("descriptors", []))
	if SaveFlow == null:
		return error_result(
			SaveError.INVALID_SAVEABLE,
			"INVALID_SAVEABLE",
			"entity collection source could not access SaveFlow runtime",
			{"source_key": get_source_key()}
		)

	_prepare_restore(context)
	var restore_result: SaveResult = SaveFlow.restore_entities(
		descriptors,
		context,
		_should_fail_on_restore_error(),
		{
			"allow_create_missing": restore_policy != RestorePolicy.APPLY_EXISTING,
		}
	)
	if restore_result.ok:
		_last_report = restore_result.data.duplicate(true)
	else:
		_last_report = restore_result.meta.duplicate(true)
	return restore_result


func describe_entity_collection_plan() -> Dictionary:
	var target := _resolve_target()
	var factory := _get_entity_factory()
	var saveflow_autoload_available := _is_saveflow_autoload_available_for_plan()
	var entity_candidates: Array = discover_entity_candidates()
	var missing_identity_nodes: PackedStringArray = []

	for candidate_variant in entity_candidates:
		var candidate: Dictionary = candidate_variant
		if not bool(candidate.get("has_identity", false)):
			missing_identity_nodes.append(String(candidate.get("path", "")))

	return {
		"valid": target != null and _is_entity_collection_plan_factory_valid(factory, saveflow_autoload_available),
		"reason": _resolve_plan_reason(target, factory, saveflow_autoload_available),
		"source_key": get_source_key(),
		"target_name": _describe_node_name(target),
		"target_path": _describe_node_path(target),
		"entity_factory_name": _describe_node_name(factory),
		"entity_factory_path": _describe_node_path(factory),
		"saveflow_autoload_available": saveflow_autoload_available,
		"failure_policy": failure_policy,
		"failure_policy_name": _describe_failure_policy(failure_policy),
		"restore_policy": restore_policy,
		"restore_policy_name": _describe_restore_policy(restore_policy),
		"include_direct_children_only": include_direct_children_only,
		"auto_register_factory": auto_register_factory,
		"entity_count": entity_candidates.size(),
		"missing_identity_nodes": missing_identity_nodes,
		"entity_candidates": entity_candidates,
	}


func discover_entity_candidates() -> Array:
	var target := _resolve_target()
	if target == null:
		return []

	var entities: Array = []
	for entity_variant in _collect_entities():
		var entity := entity_variant as Node
		if entity == null:
			continue
		var identity := _find_identity(entity)
		var entity_scope := _resolve_entity_scope(entity)
		entities.append(
			{
				"name": entity.name,
				"path": _relative_path_from_target(target, entity),
				"has_identity": identity != null,
				"persistent_id": identity.get_persistent_id() if identity != null else "",
				"type_key": identity.get_type_key() if identity != null else "",
				"has_local_scope": entity_scope != null,
			}
		)
	return entities


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	var plan := describe_entity_collection_plan()
	if not bool(plan.get("valid", false)):
		warnings.append("SaveFlowEntityCollectionSource plan is invalid: %s" % String(plan.get("reason", "INVALID_ENTITY_COLLECTION")))
	for path_text in PackedStringArray(plan.get("missing_identity_nodes", PackedStringArray())):
		warnings.append("Runtime entity is missing SaveFlowIdentity: %s" % path_text)
	return warnings


func can_handle_entity_type(type_key: String) -> bool:
	var factory := _get_entity_factory()
	if factory == null:
		return false
	return factory.can_handle_type(type_key)


func find_existing_entity(persistent_id: String, context: Dictionary = {}) -> Node:
	var factory := _get_entity_factory()
	if factory == null:
		return null
	return factory.find_existing_entity(persistent_id, context)


func spawn_entity_from_save(descriptor: Dictionary, context: Dictionary = {}) -> Node:
	var factory := _get_entity_factory()
	if factory == null:
		return null
	return factory.spawn_entity_from_save(descriptor, context)


func apply_saved_entity_data(node: Node, payload: Variant, context: Dictionary = {}) -> void:
	var factory := _get_entity_factory()
	if factory == null:
		return
	factory.apply_saved_data(node, payload, context)


func _collect_entities() -> Array:
	var target := _resolve_target()
	if target == null:
		return []
	if include_direct_children_only:
		return target.get_children()

	var entities: Array = []
	_collect_entity_nodes_recursive(target, entities)
	return entities


func _collect_entity_nodes_recursive(current: Node, entities: Array) -> void:
	for child in current.get_children():
		if not (child is Node):
			continue
		entities.append(child)
		_collect_entity_nodes_recursive(child, entities)


func _resolve_target() -> Node:
	if is_instance_valid(target_container):
		return target_container
	if not _target_container_ref_path.is_empty():
		var resolved := get_node_or_null(_target_container_ref_path)
		if is_instance_valid(resolved):
			return resolved
		return null
	var factory := _get_entity_factory()
	if factory != null:
		var factory_target: Node = factory.get_target_container()
		if is_instance_valid(factory_target):
			return factory_target
	if _has_explicit_target_container:
		return null
	return get_parent()


func _find_identity(entity: Node) -> Node:
	for child in entity.get_children():
		if child is SaveFlowIdentity:
			return child
		if child.has_method("get_persistent_id") and child.has_method("get_type_key"):
			return child
	return null


func _collect_entity_payload(entity: Node) -> Dictionary:
	var entity_scope: SaveFlowScope = _resolve_entity_scope(entity)
	if entity_scope != null:
		## A local entity scope takes priority for composite runtime entities.
		## This lets a prefab own its own internal save graph.
		var scope_result: SaveResult = SaveFlow.gather_scope(entity_scope, _current_context)
		if scope_result.ok:
			return {
				"mode": "scope_graph",
				"scope_path": _describe_relative_scope_path(entity, entity_scope),
				"graph": scope_result.data,
			}

	var payload: Dictionary = {}
	var ordered_sources: Array = _get_ordered_entity_sources(entity)
	for source_variant in ordered_sources:
		var source: SaveFlowSource = source_variant
		if not source.can_save_source():
			continue
		source.before_save(_current_context)
		payload[source.get_source_key()] = source.gather_save_data()
	return payload


func _resolve_entity_scope(entity: Node) -> SaveFlowScope:
	if entity == null:
		return null
	for child in entity.get_children():
		if child is SaveFlowScope:
			return child
	return null


func _describe_relative_scope_path(entity: Node, entity_scope: SaveFlowScope) -> String:
	if entity == null or entity_scope == null:
		return ""
	if entity == entity_scope:
		return "."
	if entity.is_ancestor_of(entity_scope):
		return str(entity.get_path_to(entity_scope))
	return ""


func _get_ordered_entity_sources(entity: Node) -> Array:
	var ordered_entries: Array = []
	var index := 0
	for child in entity.get_children():
		if child is SaveFlowSource:
			var source := child as SaveFlowSource
			ordered_entries.append(
				{
					"source": source,
					"phase": source.get_phase(),
					"index": index,
				}
			)
			index += 1

	ordered_entries.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			var phase_a: int = int(a.get("phase", 0))
			var phase_b: int = int(b.get("phase", 0))
			if phase_a == phase_b:
				return int(a.get("index", 0)) < int(b.get("index", 0))
			return phase_a < phase_b
	)

	var ordered_sources: Array = []
	for entry in ordered_entries:
		ordered_sources.append(entry["source"])
	return ordered_sources


func _ensure_entity_factory_registration() -> void:
	if not auto_register_factory:
		return
	var factory := _get_entity_factory()
	if factory == null:
		return
	SaveFlow.register_entity_factory(factory)


func _unregister_entity_factory() -> void:
	if not auto_register_factory:
		return
	var factory := _get_entity_factory()
	if factory != null:
		SaveFlow.unregister_entity_factory(factory)


func _get_entity_factory() -> SaveFlowEntityFactory:
	var factory := entity_factory
	if factory == null and not _entity_factory_ref_path.is_empty():
		var resolved := get_node_or_null(_entity_factory_ref_path)
		if resolved is SaveFlowEntityFactory:
			factory = resolved
	if not is_instance_valid(factory):
		return null
	return factory


func _is_entity_collection_plan_factory_valid(factory: Node, saveflow_autoload_available: bool) -> bool:
	if auto_register_factory:
		return factory != null and saveflow_autoload_available
	return true


func _resolve_plan_reason(target: Node, factory: Node, saveflow_autoload_available: bool) -> String:
	var factory_can_provide_target := _factory_can_provide_target_container(factory)
	if target == null and not factory_can_provide_target:
		return "TARGET_NOT_FOUND"
	if auto_register_factory and factory == null:
		return "ENTITY_FACTORY_NOT_FOUND"
	if auto_register_factory and not saveflow_autoload_available:
		return "SAVEFLOW_AUTOLOAD_MISSING"
	return ""


func _factory_can_provide_target_container(factory: Node) -> bool:
	if factory == null or not factory.has_method("describe_entity_factory_plan"):
		return false
	var plan_variant: Variant = factory.call("describe_entity_factory_plan")
	if not (plan_variant is Dictionary):
		return false
	return bool(Dictionary(plan_variant).get("can_provide_target_container", false))


func _is_saveflow_autoload_available_for_plan() -> bool:
	if SaveFlow != null:
		return true
	if not auto_register_factory:
		return true
	if not Engine.is_editor_hint():
		return false
	return ProjectSettings.has_setting("autoload/SaveFlow")


func _describe_node_name(node: Node) -> String:
	if node == null:
		return ""
	return node.name


func _relative_path_from_target(target: Node, node: Node) -> String:
	if target == null or node == null:
		return ""
	if target == node:
		return "."
	if target.is_ancestor_of(node):
		return str(target.get_path_to(node))
	return node.name


func _describe_node_path(node: Node) -> String:
	if not is_instance_valid(node):
		return "<null>"
	if node.is_inside_tree():
		return str(node.get_path())
	return node.name


func _describe_target_path(node: Node) -> String:
	if node == null:
		return ""
	if node.is_inside_tree():
		return str(node.get_path())
	return node.name


func _append_unique_string(values: PackedStringArray, value: String) -> void:
	if value.is_empty():
		return
	if values.has(value):
		return
	values.append(value)


func _refresh_editor_preview() -> void:
	if not Engine.is_editor_hint():
		return
	_hydrate_target_container_from_ref_path()
	_hydrate_entity_factory_from_ref_path()
	update_configuration_warnings()
	notify_property_list_changed()


func _hydrate_entity_factory_from_ref_path() -> void:
	if is_instance_valid(entity_factory):
		if _entity_factory_ref_path.is_empty():
			_entity_factory_ref_path = _resolve_relative_node_path(entity_factory)
		return
	if _entity_factory_ref_path.is_empty():
		return
	var resolved := get_node_or_null(_entity_factory_ref_path)
	if resolved is SaveFlowEntityFactory:
		entity_factory = resolved


func _hydrate_target_container_from_ref_path() -> void:
	if is_instance_valid(target_container):
		if _target_container_ref_path.is_empty():
			_target_container_ref_path = _resolve_relative_node_path(target_container)
		return
	if _target_container_ref_path.is_empty():
		return
	var resolved := get_node_or_null(_target_container_ref_path)
	if is_instance_valid(resolved):
		target_container = resolved


func _resolve_relative_node_path(node: Node) -> NodePath:
	if node == null:
		return NodePath()
	if not is_inside_tree() or not node.is_inside_tree():
		return NodePath()
	return get_path_to(node)


func _prepare_restore(context: Dictionary) -> void:
	var factory := _get_entity_factory()
	var target := _resolve_target()
	if restore_policy == RestorePolicy.CLEAR_AND_RESTORE:
		_clear_target_entities()
	if factory != null:
		factory.prepare_restore(restore_policy, target, context)


func _clear_target_entities() -> void:
	var target := _resolve_target()
	if target == null:
		return
	for entity_variant in _collect_entities():
		var entity := entity_variant as Node
		if entity == null or not is_instance_valid(entity):
			continue
		entity.free()


func _sanitize_restore_policy(value: Variant) -> int:
	if value == null:
		return RestorePolicy.CREATE_MISSING
	var int_value := int(value)
	if int_value < RestorePolicy.APPLY_EXISTING or int_value > RestorePolicy.CLEAR_AND_RESTORE:
		return RestorePolicy.CREATE_MISSING
	return int_value


func _sanitize_failure_policy(value: Variant) -> int:
	if value == null:
		return FailurePolicy.FAIL_ON_MISSING_OR_INVALID
	var int_value := int(value)
	if int_value < FailurePolicy.REPORT_ONLY or int_value > FailurePolicy.FAIL_ON_MISSING_OR_INVALID:
		return FailurePolicy.FAIL_ON_MISSING_OR_INVALID
	return int_value


func _should_fail_on_restore_error() -> bool:
	return failure_policy == FailurePolicy.FAIL_ON_MISSING_OR_INVALID


func _describe_failure_policy(value: Variant) -> String:
	var normalized_value := _sanitize_failure_policy(value)
	match normalized_value:
		FailurePolicy.REPORT_ONLY:
			return "Report Only"
		_:
			return "Fail On Missing Or Invalid"


func _describe_restore_policy(value: Variant) -> String:
	var normalized_value := _sanitize_restore_policy(value)
	match normalized_value:
		RestorePolicy.APPLY_EXISTING:
			return "Apply Existing"
		RestorePolicy.CLEAR_AND_RESTORE:
			return "Clear And Restore"
		_:
			return "Create Missing"
