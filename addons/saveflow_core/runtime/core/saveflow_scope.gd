## SaveFlowScope is the graph-level domain node. It does not serialize payloads
## itself; it organizes domain boundaries, ordering, and restore strategy for
## child scopes and leaf sources.
@icon("res://addons/saveflow_lite/icons/components/saveflow_scope_icon.svg")
@tool
class_name SaveFlowScope
extends Node

enum RestorePolicy {
	INHERIT,
	BEST_EFFORT,
	STRICT,
}

## Leave empty unless the default snake_case node name would be unstable or too vague.
@export var scope_key: String = "":
	set(value):
		scope_key = value
		_refresh_editor_warnings()
@export var enabled: bool = true:
	set(value):
		enabled = value
		_refresh_editor_warnings()
@export var save_enabled: bool = true:
	set(value):
		save_enabled = value
		_refresh_editor_warnings()
@export var load_enabled: bool = true:
	set(value):
		load_enabled = value
		_refresh_editor_warnings()
## Override this only when child keys need to live under a different public namespace
## than the scope key itself.
@export var key_namespace: String = "":
	set(value):
		key_namespace = value
		_refresh_editor_warnings()
## Lower phases run first inside the graph. Only set this when restore order
## between sibling domains truly matters.
@export var phase: int = 0:
	set(value):
		phase = value
		_refresh_editor_warnings()
## Controls how this domain should treat restore errors relative to its parent.
## Inherit is the safe default. Use Best Effort only when partial restoration is
## acceptable for this domain; use Strict when this domain must restore cleanly.
@export_enum("Inherit", "Best Effort", "Strict")
var restore_policy: int = RestorePolicy.INHERIT:
	set(value):
		restore_policy = value
		_refresh_editor_warnings()


func _ready() -> void:
	_refresh_editor_warnings()


func _notification(what: int) -> void:
	if not Engine.is_editor_hint():
		return
	if what == NOTIFICATION_CHILD_ORDER_CHANGED:
		_refresh_editor_warnings()


func get_scope_key() -> String:
	if not scope_key.is_empty():
		return scope_key
	return name.to_snake_case()


func is_scope_enabled() -> bool:
	return enabled


func can_save_scope() -> bool:
	return enabled and save_enabled


func can_load_scope() -> bool:
	return enabled and load_enabled


func get_key_namespace() -> String:
	if not key_namespace.is_empty():
		return key_namespace
	return get_scope_key()


func get_phase() -> int:
	return phase


func get_restore_policy() -> int:
	return restore_policy


## Hooks let a scope prepare or validate child domains before data gathering.
func before_save(_context: Dictionary = {}) -> void:
	pass


## Runs before child sources/scopes are applied. Use this for ordering-sensitive
## domain prep, not for leaf serialization work.
func before_load(_payload: Dictionary = {}, _context: Dictionary = {}) -> void:
	pass


## Runs after the scope and its children finish load. Use it for fixups that
## depend on sibling data already being restored.
func after_load(_payload: Dictionary = {}, _context: Dictionary = {}) -> void:
	pass


func describe_scope() -> Dictionary:
	return {
		"scope_key": get_scope_key(),
		"enabled": is_scope_enabled(),
		"save_enabled": can_save_scope(),
		"load_enabled": can_load_scope(),
		"key_namespace": get_key_namespace(),
		"phase": get_phase(),
		"restore_policy": get_restore_policy(),
	}


## Returns the fixed schema consumed by the scope inspector preview. The schema
## is structural on purpose: it describes domain shape, not source payload data.
func describe_scope_plan() -> Dictionary:
	var child_scope_count := 0
	var child_source_count := 0
	var child_scope_keys: PackedStringArray = []
	var child_source_keys: PackedStringArray = []
	var duplicate_scope_keys: PackedStringArray = []
	var duplicate_source_keys: PackedStringArray = []
	var seen_scope_keys: Dictionary = {}
	var seen_source_keys: Dictionary = {}

	for child in get_children():
		if child is SaveFlowScope:
			var child_scope_key := (child as SaveFlowScope).get_scope_key()
			child_scope_count += 1
			child_scope_keys.append(child_scope_key)
			if seen_scope_keys.has(child_scope_key):
				_append_unique_string(duplicate_scope_keys, child_scope_key)
			else:
				seen_scope_keys[child_scope_key] = true
		elif _is_source_contract_node(child):
			var child_source_key := _resolve_child_source_key(child)
			child_source_count += 1
			child_source_keys.append(child_source_key)
			if seen_source_keys.has(child_source_key):
				_append_unique_string(duplicate_source_keys, child_source_key)
			else:
				seen_source_keys[child_source_key] = true

	var problems: PackedStringArray = []
	if child_scope_count == 0 and child_source_count == 0:
		problems.append("Scope has no child domains or leaf sources.")
	if not duplicate_scope_keys.is_empty():
		problems.append("Duplicate child domain keys: %s" % ", ".join(duplicate_scope_keys))
	if not duplicate_source_keys.is_empty():
		problems.append("Duplicate leaf source keys: %s" % ", ".join(duplicate_source_keys))

	return {
		"valid": problems.is_empty(),
		"reason": _resolve_scope_plan_reason(problems),
		"scope_key": get_scope_key(),
		"enabled": is_scope_enabled(),
		"save_enabled": can_save_scope(),
		"load_enabled": can_load_scope(),
		"key_namespace": get_key_namespace(),
		"phase": get_phase(),
		"restore_policy": get_restore_policy(),
		"restore_policy_name": _describe_restore_policy(get_restore_policy()),
		"child_scope_count": child_scope_count,
		"child_source_count": child_source_count,
		"child_scope_keys": child_scope_keys,
		"child_source_keys": child_source_keys,
		"problems": problems,
		"duplicate_scope_keys": duplicate_scope_keys,
		"duplicate_source_keys": duplicate_source_keys,
	}


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	var plan := describe_scope_plan()
	var problems: PackedStringArray = PackedStringArray(plan.get("problems", PackedStringArray()))
	for problem in problems:
		warnings.append("SaveFlowScope: %s" % problem)
	return warnings


func _refresh_editor_warnings() -> void:
	if not Engine.is_editor_hint():
		return
	update_configuration_warnings()


func _resolve_scope_plan_reason(problems: PackedStringArray) -> String:
	if problems.is_empty():
		return ""
	if problems.size() == 1 and String(problems[0]).begins_with("Scope has no child"):
		return "EMPTY_SCOPE"
	return "INVALID_SCOPE_PLAN"


func _append_unique_string(values: PackedStringArray, value: String) -> void:
	if value.is_empty():
		return
	if values.has(value):
		return
	values.append(value)


func _is_source_contract_node(node: Node) -> bool:
	if node == null:
		return false
	if node is SaveFlowSource:
		return (node as SaveFlowSource).is_source_enabled()
	return node.has_method("gather_save_data") and node.has_method("apply_save_data")


func _resolve_child_source_key(node: Node) -> String:
	if node is SaveFlowSource:
		return (node as SaveFlowSource).get_source_key()
	if node.has_method("get_source_key") and _can_call_child_source_methods(node):
		return String(node.call("get_source_key"))
	var source_key_property := _read_child_source_key_property(node)
	if not source_key_property.is_empty():
		return source_key_property
	return node.name.to_snake_case()


func _can_call_child_source_methods(node: Node) -> bool:
	if node == null:
		return false
	if node is SaveFlowSource:
		return true
	if not Engine.is_editor_hint():
		return true
	var script_resource: Script = node.get_script()
	if script_resource == null:
		return true
	return script_resource.is_tool()


func _read_child_source_key_property(node: Node) -> String:
	if node == null:
		return ""
	for property in node.get_property_list():
		var property_name := String(Dictionary(property).get("name", ""))
		if property_name != "source_key" and property_name != "SourceKey":
			continue
		var value := String(node.get(property_name)).strip_edges()
		if not value.is_empty():
			return value
	return ""


func _describe_restore_policy(value: int) -> String:
	match value:
		RestorePolicy.BEST_EFFORT:
			return "Best Effort"
		RestorePolicy.STRICT:
			return "Strict"
		_:
			return "Inherit"
