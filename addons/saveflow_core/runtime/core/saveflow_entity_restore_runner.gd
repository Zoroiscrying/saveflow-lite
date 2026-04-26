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
	var missing_types: PackedStringArray = []
	var failed_ids: PackedStringArray = []
	var allow_create_missing := bool(options.get("allow_create_missing", true))

	for descriptor_variant in descriptors:
		if not (descriptor_variant is Dictionary) and not (descriptor_variant is SaveFlowEntityDescriptor):
			return _error_result(
				SaveError.INVALID_ARGUMENT,
				"INVALID_ARGUMENT",
				"entity descriptor must be a dictionary or SaveFlowEntityDescriptor"
			)
		var entity_descriptor: SaveFlowEntityDescriptor = SaveFlowEntityDescriptorScript.from_variant(descriptor_variant)
		if not entity_descriptor.is_valid():
			return _error_result(
				SaveError.INVALID_ARGUMENT,
				"INVALID_ARGUMENT",
				entity_descriptor.get_validation_message(),
				{"descriptor": entity_descriptor.to_dictionary()}
			)

		var descriptor: Dictionary = entity_descriptor.to_spawn_dictionary()
		var type_key := entity_descriptor.type_key
		var persistent_id := entity_descriptor.persistent_id
		var factory := find_entity_factory(type_key)
		var node: Node = null
		if factory == null:
			_append_unique_string(missing_types, type_key)
			continue
		node = factory.find_existing_entity(persistent_id, context)
		if node == null and allow_create_missing:
			node = factory.spawn_entity_from_save(descriptor, context)
			if node != null:
				spawned_count += 1
		if node == null:
			_append_unique_string(failed_ids, persistent_id if not persistent_id.is_empty() else type_key)
			continue

		var payload: Variant = entity_descriptor.payload
		var entity_graph_result := try_apply_entity_graph_payload(runtime, node, payload, strict, context)
		if bool(entity_graph_result.get("handled", false)):
			if not bool(entity_graph_result.get("ok", false)):
				_append_unique_string(failed_ids, persistent_id if not persistent_id.is_empty() else type_key)
				continue
		else:
			factory.apply_saved_data(node, payload, context)
		restored_count += 1

	if strict and (not missing_types.is_empty() or not failed_ids.is_empty()):
		return _error_result(
			SaveError.INVALID_SAVEABLE,
			"INVALID_SAVEABLE",
			"failed to restore one or more entity descriptors",
			{
				"missing_types": missing_types,
				"failed_ids": failed_ids,
				"restored_count": restored_count,
				"spawned_count": spawned_count,
			}
		)

	return _ok_result(
		{
			"restored_count": restored_count,
			"spawned_count": spawned_count,
			"missing_types": missing_types,
			"failed_ids": failed_ids,
		}
	)


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
