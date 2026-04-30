## SaveFlowEntityCollectionSource owns one changing set of runtime entities.
## It gathers entity descriptors from a container and delegates restore to
## SaveFlow + the configured entity factory.
@icon("res://addons/saveflow_lite/icons/components/saveflow_entity_collection_icon.svg")
@tool
class_name SaveFlowEntityCollectionSource
extends SaveFlowSource

const SaveFlowEntityDescriptorScript := preload("res://addons/saveflow_core/runtime/entities/saveflow_entity_descriptor.gd")
const _ENTITY_DESCRIPTOR_EXTRA_METHODS := [
	"get_saveflow_entity_descriptor_extra",
	"get_saveflow_entity_extra",
]

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


func get_last_restore_report() -> Dictionary:
	return _last_report.duplicate(true)


func gather_save_data() -> Variant:
	var descriptors: Array = []
	var missing_identity_nodes: PackedStringArray = []
	for entity in _collect_entities():
		var identity: Node = _find_identity(entity)
		if identity == null:
			_append_unique_string(missing_identity_nodes, _describe_node_path(entity))
			continue

		var payload: Dictionary = _collect_entity_payload(entity)
		var descriptor: SaveFlowEntityDescriptor = SaveFlowEntityDescriptorScript.from_values(
			identity.get_persistent_id(),
			identity.get_type_key(),
			payload,
			_collect_entity_descriptor_extra(entity, identity)
		)
		descriptors.append(descriptor.to_dictionary())

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
	var factory_plan := _describe_entity_factory_plan(factory)
	var saveflow_autoload_available := _is_saveflow_autoload_available_for_plan()
	var entity_candidates: Array = discover_entity_candidates()
	var missing_identity_nodes: PackedStringArray = []

	for candidate_variant in entity_candidates:
		var candidate: Dictionary = candidate_variant
		if not bool(candidate.get("has_identity", false)):
			missing_identity_nodes.append(String(candidate.get("path", "")))

	var duplicate_persistent_id_conflicts := _detect_duplicate_persistent_id_conflicts(entity_candidates)
	var default_identity_persistent_id_nodes := _detect_default_identity_persistent_id_nodes(entity_candidates)
	var default_identity_type_key_nodes := _detect_default_identity_type_key_nodes(entity_candidates)
	var unsupported_entity_type_nodes := _detect_unsupported_entity_type_nodes(entity_candidates, factory)
	var double_collection_conflicts := _detect_ancestor_node_source_conflicts(target)
	var recommended_next_actions := _build_recommended_next_actions(
		target,
		factory,
		missing_identity_nodes,
		duplicate_persistent_id_conflicts,
		default_identity_persistent_id_nodes,
		default_identity_type_key_nodes,
		unsupported_entity_type_nodes,
		double_collection_conflicts,
		saveflow_autoload_available
	)
	return {
		"valid": target != null and _is_entity_collection_plan_factory_valid(factory, saveflow_autoload_available),
		"reason": _resolve_plan_reason(target, factory, saveflow_autoload_available),
		"recommended_next_actions": recommended_next_actions,
		"source_key": get_source_key(),
		"entity_container_name": _describe_node_name(target),
		"entity_container_path": _describe_node_path(target),
		"target_name": _describe_node_name(target),
		"target_path": _describe_node_path(target),
		"target_resolution": _describe_target_resolution(target, factory, factory_plan),
		"double_collection_conflicts": double_collection_conflicts,
		"entity_factory_name": _describe_node_name(factory),
		"entity_factory_path": _describe_node_path(factory),
		"entity_factory_plan": factory_plan,
		"saveflow_autoload_available": saveflow_autoload_available,
		"failure_policy": failure_policy,
		"failure_policy_name": _describe_failure_policy(failure_policy),
		"restore_policy": restore_policy,
		"restore_policy_name": _describe_restore_policy(restore_policy),
		"factory_supported_entity_types": PackedStringArray(factory_plan.get("supported_entity_types", PackedStringArray())),
		"factory_spawn_summary": _describe_factory_spawn_summary(factory_plan),
		"include_direct_children_only": include_direct_children_only,
		"auto_register_factory": auto_register_factory,
		"entity_count": entity_candidates.size(),
		"missing_identity_nodes": missing_identity_nodes,
		"duplicate_persistent_id_conflicts": duplicate_persistent_id_conflicts,
		"default_identity_persistent_id_nodes": default_identity_persistent_id_nodes,
		"default_identity_type_key_nodes": default_identity_type_key_nodes,
		"unsupported_entity_type_nodes": unsupported_entity_type_nodes,
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
		var descriptor_extra := _collect_entity_descriptor_extra(entity, identity)
		var identity_path := _relative_path_from_target(target, identity) if identity != null else ""
		entities.append(
			{
				"name": entity.name,
				"path": _relative_path_from_target(target, entity),
				"has_identity": identity != null,
				"identity_path": identity_path,
				"persistent_id": identity.get_persistent_id() if identity != null else "",
				"type_key": identity.get_type_key() if identity != null else "",
				"uses_default_identity_name_id": _uses_default_identity_name_id(identity),
				"uses_default_identity_type_key": _uses_default_identity_type_key(identity),
				"descriptor_extra_keys": PackedStringArray(_dictionary_key_names(descriptor_extra)),
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
	for conflict_text in PackedStringArray(plan.get("duplicate_persistent_id_conflicts", PackedStringArray())):
		warnings.append("Duplicate runtime entity persistent_id: %s" % conflict_text)
	for path_text in PackedStringArray(plan.get("default_identity_persistent_id_nodes", PackedStringArray())):
		warnings.append("SaveFlowIdentity is using its helper node name as persistent_id: %s. Set a stable persistent_id on the Identity node." % path_text)
	for path_text in PackedStringArray(plan.get("default_identity_type_key_nodes", PackedStringArray())):
		warnings.append("SaveFlowIdentity is using its parent node name as type_key: %s. Set an explicit type_key that matches an entity factory route." % path_text)
	for warning_text in PackedStringArray(plan.get("unsupported_entity_type_nodes", PackedStringArray())):
		warnings.append(warning_text)
	for conflict_text in PackedStringArray(plan.get("double_collection_conflicts", PackedStringArray())):
		warnings.append("Runtime set may be double-collected by parent object save logic: %s" % conflict_text)
	for warning in get_saveflow_authoring_warnings():
		warnings.append(warning)
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


func _uses_default_identity_name_id(identity: Node) -> bool:
	if not (identity is SaveFlowIdentity):
		return false
	if not String(identity.get("persistent_id")).is_empty():
		return false
	return String(identity.name).to_snake_case() == String(identity.call("get_persistent_id"))


func _uses_default_identity_type_key(identity: Node) -> bool:
	if not (identity is SaveFlowIdentity):
		return false
	if not String(identity.get("type_key")).is_empty():
		return false
	var parent := identity.get_parent()
	if parent == null:
		return false
	return String(parent.name).to_snake_case() == String(identity.call("get_type_key"))


func _collect_entity_payload(entity: Node) -> Dictionary:
	var entity_scope: SaveFlowScope = _resolve_entity_scope(entity)
	if entity_scope != null:
		## A local entity scope takes priority for composite runtime entities.
		## This lets a prefab own its own internal save graph.
		var pipeline_control := SaveFlowPipelineControl.new()
		pipeline_control.context.values = _current_context
		var scope_result: SaveResult = SaveFlow.gather_scope(entity_scope, pipeline_control)
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


func _collect_entity_descriptor_extra(entity: Node, identity: Node) -> Dictionary:
	var extra: Dictionary = {}
	_merge_entity_descriptor_extra(extra, identity)
	_merge_entity_descriptor_extra(extra, entity)
	return extra


func _merge_entity_descriptor_extra(target: Dictionary, provider: Node) -> void:
	if provider == null:
		return
	for method_name in _ENTITY_DESCRIPTOR_EXTRA_METHODS:
		if not provider.has_method(method_name):
			continue
		var value: Variant = provider.call(method_name)
		if not (value is Dictionary):
			continue
		var extra: Dictionary = Dictionary(value)
		for key in extra.keys():
			target[key] = extra[key]
		return


func _dictionary_key_names(data: Dictionary) -> Array:
	var names: Array = []
	for key in data.keys():
		names.append(String(key))
	names.sort()
	return names


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
	var factory_plan := _describe_entity_factory_plan(factory)
	if factory_plan.is_empty():
		return false
	return bool(factory_plan.get("can_provide_target_container", false))


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


func _describe_entity_factory_plan(factory: Node) -> Dictionary:
	if factory == null or not factory.has_method("describe_entity_factory_plan"):
		return {}
	var plan_variant: Variant = factory.call("describe_entity_factory_plan")
	if not (plan_variant is Dictionary):
		return {}
	return Dictionary(plan_variant)


func _describe_target_resolution(target: Node, factory: Node, factory_plan: Dictionary) -> String:
	if is_instance_valid(target_container):
		return "Use collection target container."
	if not _target_container_ref_path.is_empty():
		return "Use collection target container path."
	if not factory_plan.is_empty():
		var can_provide_target_container := bool(factory_plan.get("can_provide_target_container", false))
		var auto_create_container := bool(factory_plan.get("auto_create_container", false))
		var container_name := String(factory_plan.get("container_name", "RuntimeEntities")).strip_edges()
		if can_provide_target_container and auto_create_container:
			return "Use or create factory container `%s` at runtime." % _fallback_container_name(container_name)
		if can_provide_target_container and factory != null:
			return "Use entity factory target container."
	if _has_explicit_target_container:
		return "Collection target container is expected but not resolved."
	if target == get_parent():
		return "Use collection parent node."
	return "Container resolution is pending."


func _describe_factory_spawn_summary(factory_plan: Dictionary) -> String:
	if factory_plan.is_empty():
		return "No entity factory is configured yet."
	var supported_entity_types := PackedStringArray(factory_plan.get("supported_entity_types", PackedStringArray()))
	var uses_prefab_scene := bool(factory_plan.get("uses_prefab_scene", false))
	var uses_inferred_type_key := bool(factory_plan.get("uses_inferred_type_key", false))
	var inferred_type_key := String(factory_plan.get("inferred_type_key", "")).strip_edges()
	var auto_create_container := bool(factory_plan.get("auto_create_container", false))
	var container_name := _fallback_container_name(String(factory_plan.get("container_name", "RuntimeEntities")))
	var type_summary := "<none>"
	if not supported_entity_types.is_empty():
		type_summary = ", ".join(supported_entity_types)
	if uses_prefab_scene:
		if uses_inferred_type_key and not inferred_type_key.is_empty():
			return "Spawn prefab entities for `%s` (inferred from scene).%s" % [type_summary, _describe_spawn_container_suffix(auto_create_container, container_name)]
		return "Spawn prefab entities for `%s`.%s" % [type_summary, _describe_spawn_container_suffix(auto_create_container, container_name)]
	if not supported_entity_types.is_empty():
		return "Factory handles `%s`.%s" % [type_summary, _describe_spawn_container_suffix(auto_create_container, container_name)]
	return "Custom entity factory flow.%s" % _describe_spawn_container_suffix(auto_create_container, container_name)


func _detect_duplicate_persistent_id_conflicts(entity_candidates: Array) -> PackedStringArray:
	var paths_by_id: Dictionary = {}
	for candidate_variant in entity_candidates:
		var candidate := Dictionary(candidate_variant)
		if not bool(candidate.get("has_identity", false)):
			continue
		var persistent_id := String(candidate.get("persistent_id", "")).strip_edges()
		if persistent_id.is_empty():
			continue
		var paths := PackedStringArray(paths_by_id.get(persistent_id, PackedStringArray()))
		paths.append(String(candidate.get("path", "")))
		paths_by_id[persistent_id] = paths

	var conflicts: PackedStringArray = []
	for persistent_id_variant in paths_by_id.keys():
		var persistent_id := String(persistent_id_variant)
		var paths := PackedStringArray(paths_by_id[persistent_id_variant])
		if paths.size() <= 1:
			continue
		conflicts.append("`%s` appears on %s" % [persistent_id, ", ".join(paths)])
	return conflicts


func _detect_default_identity_persistent_id_nodes(entity_candidates: Array) -> PackedStringArray:
	var paths: PackedStringArray = []
	for candidate_variant in entity_candidates:
		var candidate := Dictionary(candidate_variant)
		if not bool(candidate.get("uses_default_identity_name_id", false)):
			continue
		_append_unique_string(paths, String(candidate.get("identity_path", "")))
	return paths


func _detect_default_identity_type_key_nodes(entity_candidates: Array) -> PackedStringArray:
	var paths: PackedStringArray = []
	for candidate_variant in entity_candidates:
		var candidate := Dictionary(candidate_variant)
		if not bool(candidate.get("uses_default_identity_type_key", false)):
			continue
		_append_unique_string(paths, String(candidate.get("identity_path", "")))
	return paths


func _detect_unsupported_entity_type_nodes(entity_candidates: Array, factory: Node) -> PackedStringArray:
	var warnings: PackedStringArray = []
	if factory == null or not factory.has_method("can_handle_type"):
		return warnings
	for candidate_variant in entity_candidates:
		var candidate := Dictionary(candidate_variant)
		if not bool(candidate.get("has_identity", false)):
			continue
		var type_key := String(candidate.get("type_key", "")).strip_edges()
		if type_key.is_empty():
			continue
		var can_handle: bool = factory.call("can_handle_type", type_key)
		if can_handle:
			continue
		warnings.append(
			"Runtime entity `%s` uses type_key `%s`, but factory `%s` does not handle that type." %
			[String(candidate.get("path", "")), type_key, _describe_node_name(factory)]
		)
	return warnings


func _build_recommended_next_actions(
	target: Node,
	factory: Node,
	missing_identity_nodes: PackedStringArray,
	duplicate_persistent_id_conflicts: PackedStringArray,
	default_identity_persistent_id_nodes: PackedStringArray,
	default_identity_type_key_nodes: PackedStringArray,
	unsupported_entity_type_nodes: PackedStringArray,
	double_collection_conflicts: PackedStringArray,
	saveflow_autoload_available: bool
) -> PackedStringArray:
	var actions: PackedStringArray = []
	if target == null:
		actions.append("Assign target_container, place this source under the runtime container, or use a factory that can provide a target container.")
	if auto_register_factory and factory == null:
		actions.append("Assign entity_factory, or disable auto_register_factory only when project code registers the factory manually.")
	if auto_register_factory and not saveflow_autoload_available:
		actions.append("Enable the SaveFlow autoload before relying on automatic entity factory registration.")
	if not missing_identity_nodes.is_empty():
		actions.append("Add SaveFlowIdentity to every runtime entity prefab or authored runtime entity.")
	if not duplicate_persistent_id_conflicts.is_empty():
		actions.append("Give each runtime entity a unique explicit persistent_id.")
	if not default_identity_persistent_id_nodes.is_empty():
		actions.append("Replace default persistent_id values with stable explicit ids that survive node renames and duplicated prefabs.")
	if not default_identity_type_key_nodes.is_empty():
		actions.append("Set explicit type_key values that match entity factory routes.")
	if not unsupported_entity_type_nodes.is_empty():
		actions.append("Update the entity factory routes or fix the entity type_key values so every saved type can be restored.")
	if not double_collection_conflicts.is_empty():
		actions.append("Remove the runtime container from parent NodeSource subtree saves and let this EntityCollectionSource own it.")
	if actions.is_empty():
		var target_name := _describe_node_name(target)
		var factory_name := _describe_node_name(factory)
		if target_name.is_empty():
			target_name = "the resolved runtime container"
		if factory_name.is_empty():
			factory_name = "the registered entity factory"
		actions.append("Ready: gather descriptors from `%s` and restore them through `%s`." % [target_name, factory_name])
	return actions


func _detect_ancestor_node_source_conflicts(target: Node) -> PackedStringArray:
	var conflicts: PackedStringArray = []
	if target == null or not target.is_inside_tree():
		return conflicts
	var scene_root := target.get_tree().current_scene
	if scene_root == null:
		return conflicts
	var node_sources: Array = []
	_collect_node_sources(scene_root, node_sources)
	for source_variant in node_sources:
		var node_source := source_variant as SaveFlowNodeSource
		if node_source == null:
			continue
		var source_target: Node = node_source.call("_resolve_target") if node_source.has_method("_resolve_target") else node_source.get_parent()
		if not is_instance_valid(source_target):
			continue
		if not source_target.is_ancestor_of(target):
			continue
		var relative_target_path := str(source_target.get_path_to(target))
		if _node_source_collects_runtime_container(node_source, relative_target_path):
			_append_unique_string(conflicts, "%s -> %s" % [_describe_node_path(node_source), relative_target_path])
	return conflicts


func _collect_node_sources(current: Node, into: Array) -> void:
	for child_variant in current.get_children():
		var child := child_variant as Node
		if child == null:
			continue
		if child is SaveFlowNodeSource:
			into.append(child)
		_collect_node_sources(child, into)


func _node_source_collects_runtime_container(node_source: SaveFlowNodeSource, relative_target_path: String) -> bool:
	if relative_target_path.is_empty():
		return false
	for included_path_variant in node_source.included_paths:
		var included_path := String(included_path_variant)
		if included_path == relative_target_path:
			return true
		if relative_target_path.begins_with(included_path + "/"):
			return true
	return false


func _describe_spawn_container_suffix(auto_create_container: bool, container_name: String) -> String:
	if not auto_create_container:
		return ""
	return " Container `%s` will be created on demand if it does not exist." % container_name


func _fallback_container_name(value: String) -> String:
	return value if not value.is_empty() else "RuntimeEntities"
