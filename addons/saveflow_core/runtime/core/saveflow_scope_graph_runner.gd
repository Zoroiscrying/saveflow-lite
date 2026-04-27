extends RefCounted

const SaveFlowPipelineServiceScript := preload("res://addons/saveflow_core/runtime/core/saveflow_pipeline_service.gd")
const _SOURCE_GATHER_METHODS := ["gather_save_data", "GatherSaveData"]
const _SOURCE_APPLY_METHODS := ["apply_save_data", "ApplySaveData"]
const _SOURCE_KEY_METHODS := ["get_source_key", "GetSourceKey"]
const _SOURCE_ENABLED_METHODS := ["is_source_enabled", "IsSourceEnabled"]
const _SOURCE_CAN_SAVE_METHODS := ["can_save_source", "CanSaveSource"]
const _SOURCE_CAN_LOAD_METHODS := ["can_load_source", "CanLoadSource"]
const _SOURCE_BEFORE_SAVE_METHODS := ["before_save", "BeforeSave"]
const _SOURCE_BEFORE_LOAD_METHODS := ["before_load", "BeforeLoad"]
const _SOURCE_AFTER_LOAD_METHODS := ["after_load", "AfterLoad"]
const _SOURCE_DESCRIBE_METHODS := ["describe_source", "DescribeSource"]

var _pipeline_service := SaveFlowPipelineServiceScript.new()


func gather_scope_payload(scope_root: SaveFlowScope, pipeline_control: SaveFlowPipelineControl) -> SaveResult:
	pipeline_control = _pipeline_service.resolve_pipeline_control(pipeline_control)
	var pipeline_context: SaveFlowPipelineContext = pipeline_control.context
	if not scope_root.can_save_scope():
		return _ok_result(
			{
				"scope_key": scope_root.get_scope_key(),
				"entries": [],
			}
		)

	var hook_context := pipeline_context.get_hook_context()
	var before_save_scope_result := _pipeline_service.notify_stage(
		pipeline_control,
		"before_save_scope",
		{
			"scope": scope_root,
			"key": scope_root.get_scope_key(),
			"kind": "scope",
		}
	)
	if not before_save_scope_result.ok:
		return before_save_scope_result
	pipeline_context.record("scope.before_save", scope_root, scope_root.get_scope_key(), "scope")
	scope_root.before_save(hook_context)
	var entries: Array = []
	var seen_keys: PackedStringArray = []
	for child in get_ordered_graph_children(scope_root):
		if child is SaveFlowScope:
			var child_scope: SaveFlowScope = child
			if not child_scope.can_save_scope():
				continue
			var child_scope_key: String = child_scope.get_scope_key()
			if seen_keys.has("scope:%s" % child_scope_key):
				return _error_result(
					SaveError.DUPLICATE_SAVE_KEY,
					"DUPLICATE_SAVE_KEY",
					"duplicate child scope key inside save graph",
					{"scope_key": scope_root.get_scope_key(), "child_scope_key": child_scope_key}
				)
			seen_keys.append("scope:%s" % child_scope_key)
			var child_result: SaveResult = gather_scope_payload(child_scope, pipeline_control)
			if not child_result.ok:
				pipeline_context.record("scope.gather_failed", child_scope, child_scope_key, "scope", false, child_result.error_key)
				return child_result
			entries.append(
				{
					"kind": "scope",
					"key": child_scope_key,
					"data": child_result.data,
				}
			)
		elif is_graph_source_node(child):
			if not can_gather_graph_source(child):
				continue
			var source_key: String = resolve_graph_source_key(child)
			if source_key.is_empty():
				return _error_result(
					SaveError.INVALID_SAVEABLE,
					"INVALID_SAVEABLE",
					"graph source resolved to an empty source key",
					{"scope_key": scope_root.get_scope_key(), "node_path": _describe_node_path(child)}
				)
			if seen_keys.has("source:%s" % source_key):
				return _error_result(
					SaveError.DUPLICATE_SAVE_KEY,
					"DUPLICATE_SAVE_KEY",
					"duplicate source key inside save graph",
					{"scope_key": scope_root.get_scope_key(), "source_key": source_key}
				)
			seen_keys.append("source:%s" % source_key)
			var validate_result: SaveResult = validate_graph_source(child)
			if not validate_result.ok:
				return validate_result
			var source_result: SaveResult = gather_source_payload(child, pipeline_control)
			if not source_result.ok:
				return source_result
			entries.append(
				{
					"kind": "source",
					"key": source_key,
					"data": source_result.data,
				}
			)

	pipeline_context.record("scope.gathered", scope_root, scope_root.get_scope_key(), "scope")
	var scope_payload := {
		"scope_key": scope_root.get_scope_key(),
		"entries": entries,
	}
	var after_save_scope_result := _pipeline_service.notify_stage(
		pipeline_control,
		"after_save_scope",
		{
			"scope": scope_root,
			"key": scope_root.get_scope_key(),
			"kind": "scope",
			"payload": scope_payload,
		}
	)
	if not after_save_scope_result.ok:
		return after_save_scope_result
	return _ok_result(scope_payload)


func apply_scope_payload(
	scope_root: SaveFlowScope,
	scope_payload: Dictionary,
	strict := false,
	pipeline_control: SaveFlowPipelineControl = null
) -> SaveResult:
	pipeline_control = _pipeline_service.resolve_pipeline_control(pipeline_control)
	var pipeline_context: SaveFlowPipelineContext = pipeline_control.context
	var hook_context := pipeline_context.get_hook_context()
	var before_load_scope_result := _pipeline_service.notify_stage(
		pipeline_control,
		"before_load_scope",
		{
			"scope": scope_root,
			"key": scope_root.get_scope_key(),
			"kind": "scope",
			"payload": scope_payload,
		}
	)
	if not before_load_scope_result.ok:
		return before_load_scope_result
	pipeline_context.record("scope.before_load", scope_root, scope_root.get_scope_key(), "scope")
	scope_root.before_load(scope_payload, hook_context)
	var local_strict: bool = resolve_scope_strict(scope_root, strict)
	var payload_entries: Array = Array(scope_payload.get("entries", []))
	var source_payloads: Dictionary = {}
	var scope_payloads: Dictionary = {}
	for entry_variant in payload_entries:
		if not (entry_variant is Dictionary):
			continue
		var entry: Dictionary = entry_variant
		var kind: String = String(entry.get("kind", ""))
		var key: String = String(entry.get("key", ""))
		if kind == "scope":
			scope_payloads[key] = entry.get("data", {})
		elif kind == "source":
			source_payloads[key] = entry.get("data", null)

	var applied_count := 0
	var missing_keys: PackedStringArray = []
	var consumed_scope_keys: PackedStringArray = []
	var consumed_source_keys: PackedStringArray = []
	for child in get_ordered_graph_children(scope_root):
		if child is SaveFlowScope:
			var child_scope: SaveFlowScope = child
			if not child_scope.can_load_scope():
				continue
			var child_scope_key: String = child_scope.get_scope_key()
			if not scope_payloads.has(child_scope_key):
				continue
			consumed_scope_keys.append(child_scope_key)
			var child_result: SaveResult = apply_scope_payload(child_scope, scope_payloads[child_scope_key], local_strict, pipeline_control)
			if not child_result.ok:
				pipeline_context.record("scope.apply_failed", child_scope, child_scope_key, "scope", false, child_result.error_key)
				return child_result
			applied_count += int(child_result.data.get("applied_count", 0))
			for missing in PackedStringArray(child_result.data.get("missing_keys", PackedStringArray())):
				_append_unique_string(missing_keys, missing)
		elif is_graph_source_node(child):
			if not can_apply_graph_source(child):
				continue
			var source_key: String = resolve_graph_source_key(child)
			if not source_payloads.has(source_key):
				continue
			consumed_source_keys.append(source_key)
			var validate_result: SaveResult = validate_graph_source(child)
			if not validate_result.ok:
				_append_unique_string(missing_keys, "source:%s" % source_key)
				continue
			var apply_result: SaveResult = apply_source_payload(child, source_payloads[source_key], pipeline_control)
			if not apply_result.ok:
				pipeline_context.record("source.apply_failed", child, source_key, "source", false, apply_result.error_key)
				return apply_result
			applied_count += 1

	for scope_key in scope_payloads.keys():
		if not consumed_scope_keys.has(String(scope_key)):
			_append_unique_string(missing_keys, "scope:%s" % String(scope_key))
	for source_key in source_payloads.keys():
		if not consumed_source_keys.has(String(source_key)):
			_append_unique_string(missing_keys, "source:%s" % String(source_key))

	pipeline_context.record("scope.after_load", scope_root, scope_root.get_scope_key(), "scope")
	scope_root.after_load(scope_payload, hook_context)
	var after_load_scope_result := _pipeline_service.notify_stage(
		pipeline_control,
		"after_load_scope",
		{
			"scope": scope_root,
			"key": scope_root.get_scope_key(),
			"kind": "scope",
			"payload": scope_payload,
		}
	)
	if not after_load_scope_result.ok:
		return after_load_scope_result
	if local_strict and not missing_keys.is_empty():
		return _error_result(
			SaveError.INVALID_SAVEABLE,
			"INVALID_SAVEABLE",
			"failed to apply one or more graph entries",
			{
				"scope_key": scope_root.get_scope_key(),
				"missing_keys": missing_keys,
				"applied_count": applied_count,
			}
		)

	return _ok_result(
		{
			"applied_count": applied_count,
			"missing_keys": missing_keys,
		}
	)


func inspect_scope_payload(scope_root: SaveFlowScope) -> SaveResult:
	var entries: Array = []
	var duplicate_keys: PackedStringArray = []
	var seen_keys: PackedStringArray = []
	for child in get_ordered_graph_children(scope_root):
		if child is SaveFlowScope:
			var child_scope: SaveFlowScope = child
			if not child_scope.is_scope_enabled():
				continue
			var child_key: String = child_scope.get_scope_key()
			if seen_keys.has("scope:%s" % child_key):
				_append_unique_string(duplicate_keys, "scope:%s" % child_key)
			else:
				seen_keys.append("scope:%s" % child_key)
			var nested_result: SaveResult = inspect_scope_payload(child_scope)
			if not nested_result.ok:
				return nested_result
			entries.append(
				{
					"kind": "scope",
					"key": child_key,
					"valid": bool(nested_result.data.get("valid", true)),
					"scope": child_scope.describe_scope(),
					"data": nested_result.data,
				}
			)
		elif is_graph_source_node(child):
			var source_key: String = resolve_graph_source_key(child)
			if seen_keys.has("source:%s" % source_key):
				_append_unique_string(duplicate_keys, "source:%s" % source_key)
			else:
				seen_keys.append("source:%s" % source_key)
			var entry: Dictionary = {
				"kind": "source",
				"key": source_key,
				"node_path": _describe_node_path(child),
				"valid": true,
			}
			entry["source"] = _describe_graph_source(child)
			if entry["source"] is Dictionary:
				var source_description: Dictionary = entry["source"]
				if source_description.has("plan") and source_description["plan"] is Dictionary:
					var plan: Dictionary = source_description["plan"]
					entry["plan"] = plan
					if not bool(plan.get("valid", true)):
						entry["valid"] = false
			entries.append(entry)

	var valid := duplicate_keys.is_empty()
	for entry in entries:
		if not bool(entry.get("valid", true)):
			valid = false
			break
	return _ok_result(
		{
			"scope_key": scope_root.get_scope_key(),
			"valid": valid,
			"entries": entries,
			"duplicate_keys": duplicate_keys,
		}
	)


func is_graph_source_node(node: Node) -> bool:
	if not is_instance_valid(node):
		return false
	if node is SaveFlowSource:
		return node.is_source_enabled()
	if not _has_graph_source_contract(node):
		return false
	var enabled_method := _resolve_source_method(node, _SOURCE_ENABLED_METHODS)
	if not enabled_method.is_empty() and _can_call_graph_source_methods(node):
		return bool(node.call(enabled_method))
	return true


func resolve_graph_source_key(node: Node) -> String:
	if node is SaveFlowSource:
		return (node as SaveFlowSource).get_source_key()
	if _can_call_graph_source_methods(node):
		var source_key_method := _resolve_source_method(node, _SOURCE_KEY_METHODS)
		if not source_key_method.is_empty():
			return String(node.call(source_key_method))
	var source_key_property := _read_source_key_property(node)
	if not source_key_property.is_empty():
		return source_key_property
	return node.name.to_snake_case()


func gather_source_payload(node: Node, pipeline_control: SaveFlowPipelineControl) -> SaveResult:
	var source_key := resolve_graph_source_key(node)
	var pipeline_context: SaveFlowPipelineContext = pipeline_control.context
	var before_gather_source_result := _pipeline_service.notify_stage(
		pipeline_control,
		"before_gather_source",
		{
			"source": node,
			"node": node,
			"key": source_key,
			"kind": "source",
		}
	)
	if not before_gather_source_result.ok:
		return before_gather_source_result
	pipeline_context.record("source.before_save", node, source_key, "source")
	_call_graph_source_hook(node, _SOURCE_BEFORE_SAVE_METHODS, [pipeline_context.get_hook_context()])
	var gather_method := _resolve_source_method(node, _SOURCE_GATHER_METHODS)
	if gather_method.is_empty() or not _can_call_graph_source_methods(node):
		return _error_result(
			SaveError.INVALID_SAVEABLE,
			"INVALID_SAVEABLE",
			"graph source cannot gather payload",
			{"source_key": source_key, "node_path": _describe_node_path(node)}
		)
	var payload: Variant = node.call(gather_method)
	pipeline_context.record("source.gathered", node, source_key, "source")
	var after_gather_source_result := _pipeline_service.notify_stage(
		pipeline_control,
		"after_gather_source",
		{
			"source": node,
			"node": node,
			"key": source_key,
			"kind": "source",
			"payload": payload,
		}
	)
	if not after_gather_source_result.ok:
		return after_gather_source_result
	return _ok_result(payload)


func apply_source_payload(node: Node, payload: Variant, pipeline_control: SaveFlowPipelineControl) -> SaveResult:
	var source_key := resolve_graph_source_key(node)
	var pipeline_context: SaveFlowPipelineContext = pipeline_control.context
	var hook_context: Dictionary = pipeline_context.get_hook_context()
	var before_apply_source_result := _pipeline_service.notify_stage(
		pipeline_control,
		"before_apply_source",
		{
			"source": node,
			"node": node,
			"key": source_key,
			"kind": "source",
			"payload": payload,
		}
	)
	if not before_apply_source_result.ok:
		return before_apply_source_result
	pipeline_context.record("source.before_load", node, source_key, "source")
	_call_graph_source_hook(node, _SOURCE_BEFORE_LOAD_METHODS, [payload, hook_context])
	pipeline_context.record("source.apply", node, source_key, "source")
	var apply_method := _resolve_source_method(node, _SOURCE_APPLY_METHODS)
	if apply_method.is_empty() or not _can_call_graph_source_methods(node):
		return _error_result(
			SaveError.INVALID_SAVEABLE,
			"INVALID_SAVEABLE",
			"graph source cannot apply payload",
			{"source_key": source_key, "node_path": _describe_node_path(node)}
		)
	var apply_result_variant: Variant = node.call(apply_method, payload, hook_context)
	if apply_result_variant is SaveResult:
		var apply_result: SaveResult = apply_result_variant
		if not apply_result.ok:
			pipeline_context.record("source.apply_failed", node, source_key, "source", false, apply_result.error_key)
			return apply_result
	pipeline_context.record("source.after_load", node, source_key, "source")
	_call_graph_source_hook(node, _SOURCE_AFTER_LOAD_METHODS, [payload, hook_context])
	var after_apply_source_result := _pipeline_service.notify_stage(
		pipeline_control,
		"after_apply_source",
		{
			"source": node,
			"node": node,
			"key": source_key,
			"kind": "source",
			"payload": payload,
		}
	)
	if not after_apply_source_result.ok:
		return after_apply_source_result
	return _ok_result()


func validate_graph_source(node: Node) -> SaveResult:
	if not is_instance_valid(node):
		return _error_result(
			SaveError.INVALID_SAVEABLE,
			"INVALID_SAVEABLE",
			"graph source is not valid",
			{"node_path": "<null>"}
		)

	var describe_method := _resolve_source_method(node, _SOURCE_DESCRIBE_METHODS)
	if not describe_method.is_empty() and _can_call_graph_source_methods(node):
		var description: Variant = node.call(describe_method)
		if description is Dictionary:
			var source_description: Dictionary = description
			if source_description.has("plan") and source_description["plan"] is Dictionary:
				var plan: Dictionary = source_description["plan"]
				if not bool(plan.get("valid", true)):
					return _error_result(
						SaveError.INVALID_SAVEABLE,
						"INVALID_SAVEABLE",
						"graph source has an invalid save plan",
						{
							"node_path": _describe_node_path(node),
							"source_key": resolve_graph_source_key(node),
							"reason": String(plan.get("reason", "INVALID_SAVE_PLAN")),
							"missing_properties": plan.get("missing_properties", PackedStringArray()),
						}
					)
			elif source_description.has("valid") and not bool(source_description.get("valid", true)):
				return _error_result(
					SaveError.INVALID_SAVEABLE,
					"INVALID_SAVEABLE",
					"graph source reported itself as invalid",
					{
						"node_path": _describe_node_path(node),
						"source_key": resolve_graph_source_key(node),
					}
				)

	return _ok_result()


func can_gather_graph_source(node: Node) -> bool:
	if not is_instance_valid(node):
		return false
	if node is SaveFlowSource:
		return node.can_save_source()
	var can_save_method := _resolve_source_method(node, _SOURCE_CAN_SAVE_METHODS)
	if not can_save_method.is_empty() and _can_call_graph_source_methods(node):
		return bool(node.call(can_save_method))
	return true


func can_apply_graph_source(node: Node) -> bool:
	if not is_instance_valid(node):
		return false
	if node is SaveFlowSource:
		return node.can_load_source()
	var can_load_method := _resolve_source_method(node, _SOURCE_CAN_LOAD_METHODS)
	if not can_load_method.is_empty() and _can_call_graph_source_methods(node):
		return bool(node.call(can_load_method))
	return true


func get_ordered_graph_children(scope_root: SaveFlowScope) -> Array:
	var ordered_entries: Array = []
	var index := 0
	for child in scope_root.get_children():
		ordered_entries.append(
			{
				"child": child,
				"phase": resolve_graph_node_phase(child),
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

	var ordered_children: Array = []
	for entry in ordered_entries:
		ordered_children.append(entry["child"])
	return ordered_children


func resolve_graph_node_phase(node: Node) -> int:
	if not is_instance_valid(node):
		return 0
	if node.has_method("get_phase") and _can_call_graph_source_methods(node):
		return int(node.call("get_phase"))
	return 0


func resolve_scope_strict(scope_root: SaveFlowScope, inherited_strict: bool) -> bool:
	match scope_root.get_restore_policy():
		SaveFlowScope.RestorePolicy.BEST_EFFORT:
			return false
		SaveFlowScope.RestorePolicy.STRICT:
			return true
		_:
			return inherited_strict


func _append_unique_string(values: PackedStringArray, value: String) -> void:
	if value.is_empty():
		return
	if values.has(value):
		return
	values.append(value)


func _describe_node_path(node: Node) -> String:
	if not is_instance_valid(node):
		return "<null>"
	if node.is_inside_tree():
		return str(node.get_path())
	return node.name


func _has_graph_source_contract(node: Node) -> bool:
	if not is_instance_valid(node):
		return false
	return not _resolve_source_method(node, _SOURCE_GATHER_METHODS).is_empty() \
		and not _resolve_source_method(node, _SOURCE_APPLY_METHODS).is_empty()


func _resolve_source_method(node: Node, method_names: Array) -> String:
	if not is_instance_valid(node):
		return ""
	for method_name_variant in method_names:
		var method_name := String(method_name_variant)
		if node.has_method(method_name):
			return method_name
	return ""


func _read_source_key_property(node: Node) -> String:
	if not is_instance_valid(node):
		return ""
	for property in node.get_property_list():
		var property_name := String(Dictionary(property).get("name", ""))
		if property_name != "source_key" and property_name != "SourceKey":
			continue
		var value := String(node.get(property_name)).strip_edges()
		if not value.is_empty():
			return value
	return ""


func _can_call_graph_source_methods(node: Node) -> bool:
	if not is_instance_valid(node):
		return false
	if node is SaveFlowSource:
		return true
	if not Engine.is_editor_hint():
		return true
	var script_resource: Script = node.get_script()
	if script_resource == null:
		return true
	return script_resource.is_tool()


func _call_graph_source_hook(node: Node, method_names: Array, args: Array) -> void:
	if not _can_call_graph_source_methods(node):
		return
	var method_name := _resolve_source_method(node, method_names)
	if method_name.is_empty():
		return
	node.callv(method_name, args)


func _describe_graph_source(node: Node) -> Dictionary:
	var describe_method := _resolve_source_method(node, _SOURCE_DESCRIBE_METHODS)
	if not describe_method.is_empty() and _can_call_graph_source_methods(node):
		var description: Variant = node.call(describe_method)
		if description is Dictionary:
			return Dictionary(description)
	return {
		"source_key": resolve_graph_source_key(node),
		"enabled": is_graph_source_node(node),
		"save_enabled": can_gather_graph_source(node),
		"load_enabled": can_apply_graph_source(node),
		"phase": resolve_graph_node_phase(node),
	}


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
