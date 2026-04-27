extends RefCounted

const SaveFlowScopeGraphRunnerScript := preload("res://addons/saveflow_core/runtime/core/saveflow_scope_graph_runner.gd")

var _scope_graph_runner := SaveFlowScopeGraphRunnerScript.new()


func inspect_scene(root: Node, group_name := "saveflow") -> SaveResult:
	if not is_instance_valid(root):
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"root cannot be null"
		)

	var entries: Array = []
	var seen_keys: Dictionary = {}
	var duplicate_keys: PackedStringArray = []
	for node in collect_saveable_nodes(root, group_name):
		var describe_result: SaveResult = describe_saveable_node(root, node)
		if not describe_result.ok:
			return describe_result
		var entry: Dictionary = describe_result.data
		var key: String = String(entry.get("save_key", ""))
		if key.is_empty():
			entry["valid"] = false
			entry["issues"] = PackedStringArray(["EMPTY_SAVE_KEY"])
		elif seen_keys.has(key):
			_append_unique_string(duplicate_keys, key)
			var issues: PackedStringArray = PackedStringArray(entry.get("issues", PackedStringArray()))
			_append_unique_string(issues, "DUPLICATE_SAVE_KEY")
			entry["issues"] = issues
			entry["valid"] = false
		else:
			seen_keys[key] = true
		entries.append(entry)

	var valid := duplicate_keys.is_empty()
	for entry in entries:
		if not bool(entry.get("valid", true)):
			valid = false
			break

	return _ok_result(
		{
			"valid": valid,
			"entries": entries,
			"duplicate_keys": duplicate_keys,
		},
		{
			"root_path": describe_root(root),
			"group_name": group_name,
			"saveable_count": entries.size(),
		}
	)


func collect_nodes(root: Node, group_name := "saveflow") -> SaveResult:
	if not is_instance_valid(root):
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"root cannot be null"
		)

	var saveables: Dictionary = {}
	var visited_count := 0
	for node in collect_saveable_nodes(root, group_name):
		visited_count += 1
		var entry_result: SaveResult = collect_saveable_entry(root, node)
		if not entry_result.ok:
			return entry_result
		var entry: Dictionary = entry_result.data
		var key: String = String(entry["save_key"])
		var data: Variant = entry["data"]
		if saveables.has(key):
			return _error_result(
				SaveError.DUPLICATE_SAVE_KEY,
				"DUPLICATE_SAVE_KEY",
				"multiple saveables resolved to the same save key",
				{
					"root_path": describe_root(root),
					"save_key": key,
				}
			)
		saveables[key] = data

	return _ok_result(
		saveables,
		{
			"root_path": describe_root(root),
			"group_name": group_name,
			"saveable_count": saveables.size(),
			"visited_count": visited_count,
		}
	)


func apply_nodes(root: Node, saveables_data: Dictionary, strict := false, group_name := "saveflow") -> SaveResult:
	if not is_instance_valid(root):
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"root cannot be null"
		)

	var lookup_result: SaveResult = build_saveable_lookup(root, group_name)
	if not lookup_result.ok:
		return lookup_result
	var node_lookup: Dictionary = lookup_result.data

	var applied_count := 0
	var missing_keys: Array = []
	for key in saveables_data.keys():
		var key_string: String = str(key)
		if not node_lookup.has(key_string):
			missing_keys.append(key_string)
			continue

		var target: Node = node_lookup[key_string]
		if not target.has_method("apply_save_data"):
			missing_keys.append(key_string)
			continue

		target.call("apply_save_data", saveables_data[key])
		applied_count += 1

	if strict and not missing_keys.is_empty():
		return _error_result(
			SaveError.INVALID_FORMAT,
			"INVALID_FORMAT",
			"failed to apply some saveable entries",
			{
				"root_path": describe_root(root),
				"missing_keys": missing_keys,
				"applied_count": applied_count,
			}
		)

	return _ok_result(
		{
			"applied_count": applied_count,
			"missing_keys": missing_keys,
		},
		{
			"root_path": describe_root(root),
			"group_name": group_name,
		}
	)


func collect_saveable_nodes(root: Node, group_name: String) -> Array:
	var results: Array = []
	_collect_saveable_nodes_recursive(root, root, results, group_name)
	return results


func build_saveable_lookup(root: Node, group_name: String) -> SaveResult:
	var node_lookup: Dictionary = {}
	for node in collect_saveable_nodes(root, group_name):
		var key: String = resolve_saveable_key(root, node)
		if key.is_empty():
			return _error_result(
				SaveError.INVALID_SAVEABLE,
				"INVALID_SAVEABLE",
				"saveable resolved to an empty save key",
				{"root_path": describe_root(root), "node_path": describe_node_path(node)}
			)
		if node_lookup.has(key):
			return _error_result(
				SaveError.DUPLICATE_SAVE_KEY,
				"DUPLICATE_SAVE_KEY",
				"multiple saveables resolved to the same save key",
				{"root_path": describe_root(root), "save_key": key}
			)
		node_lookup[key] = node
	return _ok_result(node_lookup)


func collect_saveable_entry(root: Node, node: Node) -> SaveResult:
	var describe_result: SaveResult = describe_saveable_node(root, node)
	if not describe_result.ok:
		return describe_result
	var report: Dictionary = describe_result.data
	if not bool(report.get("valid", true)):
		return _error_result(
			SaveError.INVALID_SAVEABLE,
			"INVALID_SAVEABLE",
			"saveable is not ready to be collected",
			{
				"root_path": describe_root(root),
				"node_path": String(report.get("node_path", "")),
				"save_key": String(report.get("save_key", "")),
				"issues": report.get("issues", PackedStringArray()),
			}
		)

	var key: String = String(report.get("save_key", ""))
	if key.is_empty():
		return _error_result(
			SaveError.INVALID_SAVEABLE,
			"INVALID_SAVEABLE",
			"saveable resolved to an empty save key",
			{"root_path": describe_root(root), "node_path": String(report.get("node_path", ""))}
		)

	var pipeline_control := SaveFlowPipelineControl.new()
	var source_result: SaveResult = _scope_graph_runner.gather_source_payload(node, pipeline_control)
	if not source_result.ok:
		return source_result
	return _ok_result(
		{
			"save_key": key,
			"data": source_result.data,
			"report": report,
		},
		{"pipeline_trace": pipeline_control.context.to_trace_array()}
	)


func describe_saveable_node(root: Node, node: Node) -> SaveResult:
	var save_key: String = resolve_saveable_key(root, node)
	var issues: PackedStringArray = []
	var entry: Dictionary = {
		"node_path": describe_node_path(node),
		"save_key": save_key,
		"kind": describe_saveable_kind(node),
		"valid": true,
		"issues": issues,
	}

	if save_key.is_empty():
		entry["valid"] = false
		issues.append("EMPTY_SAVE_KEY")

	if _scope_graph_runner.is_graph_source_node(node) and node.has_method("describe_source") and _can_call_saveable_methods(node):
		var description_variant: Variant = node.call("describe_source")
		if not (description_variant is Dictionary):
			return _ok_result(entry)
		var description: Dictionary = description_variant
		if description.has("plan") and description["plan"] is Dictionary:
			var plan: Dictionary = description["plan"]
			entry["plan"] = plan
			entry["properties"] = plan.get("properties", PackedStringArray())
			entry["missing_properties"] = plan.get("missing_properties", PackedStringArray())
			if not bool(plan.get("valid", true)):
				entry["valid"] = false
				_append_unique_string(issues, String(plan.get("reason", "INVALID_SAVE_PLAN")))

	return _ok_result(entry)


func resolve_saveable_key(root: Node, node: Node) -> String:
	if _scope_graph_runner.is_graph_source_node(node):
		return _scope_graph_runner.resolve_graph_source_key(node)
	return str(root.get_path_to(node))


func describe_saveable_kind(node: Node) -> String:
	if node is SaveFlowDataSource:
		return "data_source"
	if node is SaveFlowSource:
		return "source"
	return "source"


func describe_root(root: Node) -> String:
	if not is_instance_valid(root):
		return "<null>"
	if root.is_inside_tree():
		return str(root.get_path())
	if not root.name.is_empty():
		return root.name
	return "<detached>"


func describe_node_path(node: Node) -> String:
	if not is_instance_valid(node):
		return "<null>"
	if node.is_inside_tree():
		return str(node.get_path())
	return node.name


func _collect_saveable_nodes_recursive(root: Node, current: Node, results: Array, group_name: String) -> void:
	if current != root and _is_saveable_node(current, group_name):
		results.append(current)

	for child in current.get_children():
		if child is Node:
			_collect_saveable_nodes_recursive(root, child, results, group_name)


func _is_saveable_node(node: Node, _group_name: String) -> bool:
	if not is_instance_valid(node):
		return false
	return _scope_graph_runner.is_graph_source_node(node)


func _can_call_saveable_methods(node: Node) -> bool:
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
