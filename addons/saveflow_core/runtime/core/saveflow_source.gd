## SaveFlowSource is the common contract for every save-graph leaf.
## Every concrete source gathers one payload and applies one payload.
@tool
@abstract
class_name SaveFlowSource
extends Node

var source_key: String = ""
@export var enabled: bool = true
@export var save_enabled: bool = true
@export var load_enabled: bool = true
## Lower phases run first during save/load ordering inside a scope.
@export var phase: int = 0


func get_save_key() -> String:
	return get_source_key()


func get_source_key() -> String:
	if not source_key.is_empty():
		return source_key
	return name.to_snake_case()


func is_source_enabled() -> bool:
	return enabled


func can_save_source() -> bool:
	return enabled and save_enabled


func can_load_source() -> bool:
	return enabled and load_enabled


func get_phase() -> int:
	return phase


func before_save(_context: Dictionary = {}) -> void:
	pass


func before_load(_payload: Variant, _context: Dictionary = {}) -> void:
	pass


func after_load(_payload: Variant, _context: Dictionary = {}) -> void:
	pass


func describe_source() -> Dictionary:
	return {
		"source_key": get_source_key(),
		"enabled": is_source_enabled(),
		"save_enabled": can_save_source(),
		"load_enabled": can_load_source(),
		"phase": get_phase(),
	}


func get_saveflow_authoring_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not is_source_enabled():
		return warnings

	var key := get_source_key().strip_edges()
	if key.is_empty():
		warnings.append("SaveFlowSource has an empty save key. Each source needs a stable key inside its save graph.")
		return warnings

	for warning in _get_duplicate_source_key_warnings(key):
		warnings.append(warning)
	return warnings


func ok_result(data: Variant = null, meta: Dictionary = {}) -> SaveResult:
	var result := SaveResult.new()
	result.ok = true
	result.error_code = SaveError.OK
	result.error_key = "OK"
	result.data = data
	result.meta = meta
	return result


func error_result(error_code: int, error_key: String, error_message: String, meta: Dictionary = {}) -> SaveResult:
	var result := SaveResult.new()
	result.ok = false
	result.error_code = error_code
	result.error_key = error_key
	result.error_message = error_message
	result.meta = meta
	return result


## Gather this source's payload. The result must be fully self-contained because
## SaveFlow stores and replays it without source-specific side channels.
@abstract
func gather_save_data() -> Variant


## Apply one payload previously returned by `gather_save_data()`. Return a
## SaveResult instead of throwing so scopes can aggregate restore failures.
@abstract
func apply_save_data(data: Variant, context: Dictionary = {}) -> SaveResult


func _get_duplicate_source_key_warnings(key: String) -> PackedStringArray:
	var warnings: PackedStringArray = []
	var parent := get_parent()
	if _is_authoring_scope(parent):
		for duplicate_path in _collect_duplicate_source_key_paths(parent, key, false):
			warnings.append(
				"Duplicate SaveFlow source key `%s` inside parent scope `%s`: %s. Direct child source keys must be unique in one SaveFlowScope." % [
					key,
					String(parent.call("get_scope_key")),
					duplicate_path,
				]
			)
		return warnings

	var scene_root := _resolve_authoring_scene_root()
	if scene_root == null:
		return warnings
	for duplicate_path in _collect_duplicate_source_key_paths(scene_root, key, true):
		warnings.append(
			"Another SaveFlowSource in this scene uses key `%s`: %s. This will fail if both sources are collected by the same scene save or custom graph." % [
				key,
				duplicate_path,
			]
		)
	return warnings


func _collect_duplicate_source_key_paths(root: Node, key: String, recursive: bool) -> PackedStringArray:
	return _collect_duplicate_source_key_paths_recursive(root, root, key, recursive)


func _collect_duplicate_source_key_paths_recursive(origin: Node, current: Node, key: String, recursive: bool) -> PackedStringArray:
	var duplicates: PackedStringArray = []
	for child in current.get_children():
		if child is SaveFlowSource:
			var source := child as SaveFlowSource
			if source != self and source.is_source_enabled() and source.get_source_key().strip_edges() == key:
				duplicates.append(_describe_authoring_node_path(origin, source))
		if recursive and child is Node:
			for nested_duplicate in _collect_duplicate_source_key_paths_recursive(origin, child, key, true):
				duplicates.append(nested_duplicate)
	return duplicates


func _resolve_authoring_scene_root() -> Node:
	if is_instance_valid(owner):
		return owner
	var current: Node = self
	var last: Node = self
	while current != null:
		last = current
		current = current.get_parent()
	return last


func _describe_authoring_node_path(root: Node, node: Node) -> String:
	if root == null or node == null:
		return "<unknown>"
	if root == node:
		return "."
	if root.is_ancestor_of(node):
		return str(root.get_path_to(node))
	return str(node.get_path())


func _is_authoring_scope(node: Node) -> bool:
	return node != null and node.has_method("get_scope_key") and node.has_method("describe_scope")
