@tool
extends RefCounted

const STATE_OK := "ok"
const STATE_WARNING := "warning"
const STATE_ERROR := "error"


static func inspect_scene(scene_root: Node = null) -> Dictionary:
	var root := _resolve_scene_root(scene_root)
	var issues: Array[Dictionary] = []
	var sources: Array = []
	var scopes: Array = []
	var factories: Array = []

	if root == null:
		return _build_report(null, issues, sources, scopes, factories)

	_collect_scene_nodes(root, sources, scopes, factories)
	_append_source_key_issues(root, sources, issues)
	_append_source_plan_issues(root, sources, issues)
	_append_scope_plan_issues(root, scopes, issues)
	_append_factory_plan_issues(root, factories, issues)
	return _build_report(root, issues, sources, scopes, factories)


static func _build_report(root: Node, issues: Array[Dictionary], sources: Array, scopes: Array, factories: Array) -> Dictionary:
	var error_count := 0
	var warning_count := 0
	for issue in issues:
		match String(issue.get("state", "")):
			STATE_ERROR:
				error_count += 1
			STATE_WARNING:
				warning_count += 1

	var summary := ""
	if root == null:
		summary = "Open a scene to run SaveFlow scene validation."
	elif sources.is_empty() and scopes.is_empty() and factories.is_empty():
		summary = "`%s` has no SaveFlow components." % root.name
	elif error_count == 0 and warning_count == 0:
		summary = "`%s` has %d source(s), %d scope(s), and %d entity factory node(s), with no validator issues." % [
			root.name,
			sources.size(),
			scopes.size(),
			factories.size(),
		]
	else:
		summary = "`%s` has %d error(s) and %d warning(s)." % [root.name, error_count, warning_count]

	return {
		"has_scene": root != null,
		"scene_name": String(root.name) if root != null else "",
		"scene_path": String(root.scene_file_path) if root != null else "",
		"source_count": sources.size(),
		"scope_count": scopes.size(),
		"factory_count": factories.size(),
		"component_count": sources.size() + scopes.size() + factories.size(),
		"healthy": error_count == 0,
		"error_count": error_count,
		"warning_count": warning_count,
		"summary": summary,
		"issues": issues,
	}


static func _resolve_scene_root(scene_root: Node = null) -> Node:
	if is_instance_valid(scene_root):
		return scene_root
	if Engine.is_editor_hint():
		var edited_scene := EditorInterface.get_edited_scene_root()
		if is_instance_valid(edited_scene):
			return edited_scene
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		return (main_loop as SceneTree).current_scene
	return null


static func _collect_scene_nodes(current: Node, sources: Array, scopes: Array, factories: Array) -> void:
	if current == null:
		return
	if _is_validator_source(current):
		sources.append(current)
	if _is_validator_scope(current):
		scopes.append(current)
	if current.has_method("describe_entity_factory_plan"):
		factories.append(current)
	for child_variant in current.get_children():
		var child := child_variant as Node
		if child != null:
			_collect_scene_nodes(child, sources, scopes, factories)


static func _is_validator_source(node: Node) -> bool:
	return node is SaveFlowSource and (node as SaveFlowSource).is_source_enabled()


static func _is_validator_scope(node: Node) -> bool:
	return node is SaveFlowScope and (node as SaveFlowScope).is_scope_enabled()


static func _append_source_key_issues(root: Node, sources: Array, issues: Array[Dictionary]) -> void:
	var seen: Dictionary = {}
	for source_variant in sources:
		var source := source_variant as Node
		if source == null:
			continue
		var key := _safe_source_key(source)
		var path := _describe_node_path(root, source)
		if key.is_empty():
			_add_issue(
				issues,
				STATE_ERROR,
				"source_key",
				"EMPTY_SOURCE_KEY",
				"Empty source key",
				"`%s` has an empty save key." % path,
				source,
				root,
				"Give this Source a stable key. Empty keys cannot be collected safely."
			)
			continue
		if seen.has(key):
			var first_source := seen[key] as Node
			var first_path := _describe_node_path(root, first_source)
			_add_issue(
				issues,
				STATE_ERROR,
				"source_key",
				"DUPLICATE_SOURCE_KEY",
				"Duplicate source key",
				"Duplicate source key `%s`: `%s` and `%s`. Scene save/load requires unique Source keys under one collected scene graph." % [
					key,
					first_path,
					path,
				],
				source,
				root,
				"Rename one Source key, or split the objects into separate SaveFlowScope boundaries when they are not saved together."
			)
		else:
			seen[key] = source


static func _append_source_plan_issues(root: Node, sources: Array, issues: Array[Dictionary]) -> void:
	for source_variant in sources:
		var source := source_variant as Node
		if source == null:
			continue
		var path := _describe_node_path(root, source)
		var plan := _describe_source_plan(source)
		if not plan.is_empty() and not bool(plan.get("valid", true)):
			var reason := String(plan.get("reason", "INVALID_SOURCE_PLAN"))
			_add_issue(
				issues,
				STATE_ERROR,
				"source_plan",
				"INVALID_SOURCE_PLAN",
				"Invalid source plan",
				"`%s`: %s" % [path, reason],
				source,
				root,
				"Open this Source in the Inspector and fix the highlighted target, participant, or property plan."
			)

		for warning in _read_configuration_warnings(source):
			var warning_text := String(warning)
			if _should_skip_source_configuration_warning(warning_text):
				continue
			_add_issue(
				issues,
				STATE_WARNING,
				"source_warning",
				"SOURCE_CONFIGURATION_WARNING",
				"Source warning",
				"`%s`: %s" % [path, warning_text],
				source,
				root,
				"Select the Source to inspect the full preview and suggested fix."
			)


static func _append_scope_plan_issues(root: Node, scopes: Array, issues: Array[Dictionary]) -> void:
	for scope_variant in scopes:
		var scope := scope_variant as Node
		if scope == null or not scope.has_method("describe_scope_plan"):
			continue
		var plan_variant: Variant = scope.call("describe_scope_plan")
		if not (plan_variant is Dictionary):
			continue
		var plan := Dictionary(plan_variant)
		if bool(plan.get("valid", true)):
			continue
		var reason := String(plan.get("reason", "INVALID_SCOPE_PLAN"))
		var state := STATE_WARNING if reason == "EMPTY_SCOPE" else STATE_ERROR
		var problems := PackedStringArray(plan.get("problems", PackedStringArray()))
		var detail := reason if problems.is_empty() else "; ".join(problems)
		_add_issue(
			issues,
			state,
			"scope_plan",
			reason,
			"Scope plan needs attention",
			"`%s`: %s" % [_describe_node_path(root, scope), detail],
			scope,
			root,
			"SaveFlowScope should contain direct child Sources and/or child Scopes with unique local keys."
		)


static func _append_factory_plan_issues(root: Node, factories: Array, issues: Array[Dictionary]) -> void:
	for factory_variant in factories:
		var factory := factory_variant as Node
		if factory == null or not factory.has_method("describe_entity_factory_plan"):
			continue
		var plan_variant: Variant = factory.call("describe_entity_factory_plan")
		if not (plan_variant is Dictionary):
			continue
		var plan := Dictionary(plan_variant)
		if bool(plan.get("valid", true)):
			continue
		var reason := String(plan.get("reason", "INVALID_ENTITY_FACTORY_PLAN"))
		var problems := PackedStringArray(plan.get("problems", PackedStringArray()))
		var detail := reason if problems.is_empty() else "; ".join(problems)
		_add_issue(
			issues,
			STATE_ERROR,
			"entity_factory",
			"INVALID_ENTITY_FACTORY_PLAN",
			"Invalid entity factory",
			"`%s`: %s" % [_describe_node_path(root, factory), detail],
			factory,
			root,
			"Implement the required entity factory methods or use a concrete prefab factory."
		)


static func _add_issue(
	issues: Array[Dictionary],
	state: String,
	category: String,
	code: String,
	title: String,
	message: String,
	node: Node,
	root: Node,
	hint: String
) -> void:
	var node_path := _describe_node_path(root, node)
	var issue := {
		"state": state,
		"category": category,
		"code": code,
		"title": title,
		"message": message,
		"hint": hint,
		"node_path": node_path,
	}
	if is_instance_valid(node):
		issue["node"] = node
	issues.append(issue)


static func _safe_source_key(source: Node) -> String:
	if source == null or not source.has_method("get_source_key"):
		return ""
	var key_variant: Variant = source.call("get_source_key")
	return String(key_variant).strip_edges()


static func _describe_source_plan(source: Node) -> Dictionary:
	if source == null:
		return {}
	for method_name in [
		"describe_node_plan",
		"describe_entity_collection_plan",
		"describe_data_plan",
	]:
		if source.has_method(method_name):
			var plan_variant: Variant = source.call(method_name)
			if plan_variant is Dictionary:
				return Dictionary(plan_variant)
	return {}


static func _read_configuration_warnings(node: Node) -> PackedStringArray:
	if node == null or not node.has_method("_get_configuration_warnings"):
		return PackedStringArray()
	var warnings_variant: Variant = node.call("_get_configuration_warnings")
	if warnings_variant is PackedStringArray:
		return PackedStringArray(warnings_variant)
	if warnings_variant is Array:
		return PackedStringArray(warnings_variant)
	return PackedStringArray()


static func _should_skip_source_configuration_warning(warning: String) -> bool:
	if warning.contains("plan is invalid:"):
		return true
	if warning.contains("Another SaveFlowSource in this scene uses key"):
		return true
	if warning.contains("Duplicate SaveFlow source key"):
		return true
	if warning.contains("SaveFlowSource has an empty save key"):
		return true
	return false


static func _describe_node_path(root: Node, node: Node) -> String:
	if root == null or node == null:
		return "<unknown>"
	if root == node:
		return "."
	if root.is_ancestor_of(node):
		return str(root.get_path_to(node))
	return str(node.get_path())
