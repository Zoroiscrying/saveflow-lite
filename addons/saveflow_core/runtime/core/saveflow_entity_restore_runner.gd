extends RefCounted

const SaveFlowEntityDescriptorScript := preload("res://addons/saveflow_core/runtime/entities/saveflow_entity_descriptor.gd")

var _entity_factories: Array = []


func register_entity_factory(factory: SaveFlowEntityFactory) -> SaveResult:
	if factory == null:
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"entity factory cannot be null"
		)
	if _entity_factories.has(factory):
		return _ok_result({"factory_count": _entity_factories.size()}, {"already_registered": true})
	_entity_factories.append(factory)
	return _ok_result({"factory_count": _entity_factories.size()})


func unregister_entity_factory(factory: SaveFlowEntityFactory) -> SaveResult:
	if factory == null:
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"entity factory cannot be null"
		)
	_entity_factories.erase(factory)
	return _ok_result({"factory_count": _entity_factories.size()})


func clear_entity_factories() -> SaveResult:
	_entity_factories.clear()
	return _ok_result()


## Runtime entity restore is split on purpose:
## - collection sources decide which descriptors belong to a runtime set
## - factories decide how entities are found, spawned, and hydrated
## - this runner only coordinates descriptor dispatch and aggregate result
func restore_entities(
	runtime: Node,
	descriptors: Array,
	context: Dictionary = {},
	strict := false,
	options: Dictionary = {}
) -> SaveResult:
	var restored_count := 0
	var spawned_count := 0
	var reused_count := 0
	var missing_types: PackedStringArray = []
	var failed_ids: PackedStringArray = []
	var entity_restore_issues: Array[Dictionary] = []
	var allow_create_missing := bool(options.get("allow_create_missing", true))

	for descriptor_index in descriptors.size():
		var descriptor_variant: Variant = descriptors[descriptor_index]
		if not (descriptor_variant is Dictionary) and not (descriptor_variant is SaveFlowEntityDescriptor):
			_append_issue(
				entity_restore_issues,
				descriptor_index,
				"INVALID_DESCRIPTOR",
				"entity descriptor must be a dictionary or SaveFlowEntityDescriptor",
				"",
				"",
				{}
			)
			_append_unique_string(failed_ids, "descriptor_%d" % descriptor_index)
			continue
		var entity_descriptor: SaveFlowEntityDescriptor = SaveFlowEntityDescriptorScript.from_variant(descriptor_variant)
		if not entity_descriptor.is_valid():
			_append_issue(
				entity_restore_issues,
				descriptor_index,
				"MISSING_TYPE_KEY",
				entity_descriptor.get_validation_message(),
				entity_descriptor.persistent_id,
				entity_descriptor.type_key,
				{"descriptor": entity_descriptor.to_dictionary()}
			)
			_append_unique_string(failed_ids, _descriptor_debug_id(entity_descriptor, descriptor_index))
			continue

		var descriptor: Dictionary = entity_descriptor.to_spawn_dictionary()
		var type_key := entity_descriptor.type_key
		var persistent_id := entity_descriptor.persistent_id
		if persistent_id.is_empty():
			_append_issue(
				entity_restore_issues,
				descriptor_index,
				"MISSING_PERSISTENT_ID",
				"entity descriptor must contain persistent_id so restore can find or track the entity",
				persistent_id,
				type_key,
				{"descriptor": entity_descriptor.to_dictionary()}
			)
			_append_unique_string(failed_ids, _descriptor_debug_id(entity_descriptor, descriptor_index))
			continue

		var factory := find_entity_factory(type_key)
		var node: Node = null
		if factory == null:
			_append_unique_string(missing_types, type_key)
			_append_unique_string(failed_ids, persistent_id)
			_append_issue(
				entity_restore_issues,
				descriptor_index,
				"FACTORY_NOT_FOUND",
				"no registered entity factory can handle type_key `%s`" % type_key,
				persistent_id,
				type_key,
				{"descriptor": entity_descriptor.to_dictionary()}
			)
			continue
		node = factory.find_existing_entity(persistent_id, context)
		var reused_existing := node != null
		if node == null and not allow_create_missing:
			_append_issue(
				entity_restore_issues,
				descriptor_index,
				"EXISTING_ENTITY_NOT_FOUND",
				"entity `%s` was not found and creation is disabled for this restore policy" % persistent_id,
				persistent_id,
				type_key,
				{"factory": _describe_node_path(factory)}
			)
		elif node == null and allow_create_missing:
			node = factory.spawn_entity_from_save(descriptor, context)
			if node != null:
				spawned_count += 1
			else:
				_append_issue(
					entity_restore_issues,
					descriptor_index,
					"SPAWN_RETURNED_NULL",
					"factory `%s` returned null while spawning entity `%s` of type `%s`" % [
						_describe_node_name(factory),
						persistent_id,
						type_key,
					],
					persistent_id,
					type_key,
					{"factory": _describe_node_path(factory)}
				)
		if node == null:
			_append_unique_string(failed_ids, persistent_id if not persistent_id.is_empty() else type_key)
			continue
		if reused_existing:
			reused_count += 1

		var payload: Variant = entity_descriptor.payload
		var entity_graph_result := try_apply_entity_graph_payload(runtime, node, payload, strict, context)
		if bool(entity_graph_result.get("handled", false)):
			if not bool(entity_graph_result.get("ok", false)):
				_append_unique_string(failed_ids, persistent_id if not persistent_id.is_empty() else type_key)
				_append_issue(
					entity_restore_issues,
					descriptor_index,
					"ENTITY_GRAPH_APPLY_FAILED",
					_describe_entity_graph_failure(entity_graph_result),
					persistent_id,
					type_key,
					{
						"factory": _describe_node_path(factory),
						"node": _describe_node_path(node),
					}
				)
				continue
		else:
			factory.apply_saved_data(node, payload, context)
		restored_count += 1

	var report := {
		"restored_count": restored_count,
		"spawned_count": spawned_count,
		"created_count": spawned_count,
		"reused_count": reused_count,
		"skipped_count": entity_restore_issues.size(),
		"missing_types": missing_types,
		"failed_ids": failed_ids,
		"entity_restore_issues": entity_restore_issues,
		"first_issue": entity_restore_issues[0] if not entity_restore_issues.is_empty() else {},
	}

	if strict and not entity_restore_issues.is_empty():
		return _error_result(
			SaveError.INVALID_SAVEABLE,
			"INVALID_SAVEABLE",
			"failed to restore one or more entity descriptors",
			report
		)

	return _ok_result(report)


func find_entity_factory(type_key: String) -> SaveFlowEntityFactory:
	for factory_variant in _entity_factories:
		var factory: SaveFlowEntityFactory = factory_variant
		if factory == null:
			continue
		if factory.can_handle_type(type_key):
			return factory
	return null


func try_apply_entity_graph_payload(
	runtime: Node,
	node: Node,
	payload: Variant,
	strict := false,
	context: Dictionary = {}
) -> Dictionary:
	if not (payload is Dictionary):
		return {"handled": false, "ok": false}

	var payload_dict: Dictionary = payload
	var mode: String = String(payload_dict.get("mode", ""))
	if mode != "scope_graph":
		return {"handled": false, "ok": false}

	var scope_payload: Variant = payload_dict.get("graph", null)
	if not (scope_payload is Dictionary):
		return {"handled": true, "ok": false}

	var entity_scope := resolve_entity_scope_from_payload(node, payload_dict)
	if entity_scope == null:
		return {"handled": true, "ok": false}

	if runtime == null or not runtime.has_method("apply_scope"):
		return {"handled": true, "ok": false}
	var entity_control := SaveFlowPipelineControl.new()
	entity_control.context.values = context
	var apply_result := runtime.call("apply_scope", entity_scope, scope_payload, strict, entity_control) as SaveResult
	return {
		"handled": true,
		"ok": apply_result != null and apply_result.ok,
		"result": apply_result,
	}


func resolve_entity_scope_from_payload(node: Node, payload: Dictionary) -> SaveFlowScope:
	if not is_instance_valid(node):
		return null

	var scope_path: String = String(payload.get("scope_path", ""))
	if scope_path == "." and node is SaveFlowScope:
		return node
	if not scope_path.is_empty() and scope_path != ".":
		return node.get_node_or_null(NodePath(scope_path)) as SaveFlowScope

	for child in node.get_children():
		if child is SaveFlowScope:
			return child
	return null


func _append_unique_string(values: PackedStringArray, value: String) -> void:
	if value.is_empty():
		return
	if values.has(value):
		return
	values.append(value)


func _append_issue(
	issues: Array[Dictionary],
	descriptor_index: int,
	code: String,
	message: String,
	persistent_id: String,
	type_key: String,
	details: Dictionary = {}
) -> void:
	var issue := {
		"descriptor_index": descriptor_index,
		"code": code,
		"message": message,
		"persistent_id": persistent_id,
		"type_key": type_key,
	}
	if not details.is_empty():
		issue["details"] = details.duplicate(true)
	issues.append(issue)


func _descriptor_debug_id(entity_descriptor: SaveFlowEntityDescriptor, descriptor_index: int) -> String:
	if not entity_descriptor.persistent_id.is_empty():
		return entity_descriptor.persistent_id
	if not entity_descriptor.type_key.is_empty():
		return entity_descriptor.type_key
	return "descriptor_%d" % descriptor_index


func _describe_entity_graph_failure(entity_graph_result: Dictionary) -> String:
	var result_variant: Variant = entity_graph_result.get("result", null)
	if result_variant is SaveResult:
		var result := result_variant as SaveResult
		if not result.error_message.is_empty():
			return result.error_message
		if not result.error_key.is_empty():
			return "entity scope graph apply failed: %s" % result.error_key
	return "entity scope graph payload could not be applied"


func _describe_node_name(node: Node) -> String:
	if not is_instance_valid(node):
		return "<none>"
	return node.name


func _describe_node_path(node: Node) -> String:
	if not is_instance_valid(node):
		return "<none>"
	if node.is_inside_tree():
		return str(node.get_path())
	return node.name


func _ok_result(data: Variant = null, meta: Dictionary = {}) -> SaveResult:
	var result := SaveResult.new()
	result.ok = true
	result.error_code = SaveError.OK
	result.error_key = "OK"
	result.data = data
	result.meta = meta
	return result


func _error_result(error_code: int, error_key: String, error_message: String, meta: Dictionary = {}) -> SaveResult:
	var result := SaveResult.new()
	result.ok = false
	result.error_code = error_code
	result.error_key = error_key
	result.error_message = error_message
	result.meta = meta
	return result
