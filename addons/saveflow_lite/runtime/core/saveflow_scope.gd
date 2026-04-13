## SaveFlowScope is the graph-level domain node. It does not serialize payloads
## itself; it organizes domain boundaries, ordering, and restore strategy for
## child scopes and leaf sources.
@tool
class_name SaveFlowScope
extends Node

enum RestorePolicy {
	INHERIT,
	BEST_EFFORT,
	STRICT,
}

## Leave empty unless the default snake_case node name would be unstable or too vague.
@export var scope_key: String = ""
@export var enabled: bool = true
@export var save_enabled: bool = true
@export var load_enabled: bool = true
## Override this only when child keys need to live under a different public namespace
## than the scope key itself.
@export var key_namespace: String = ""
## Lower phases run first inside the graph. Only set this when restore order
## between sibling domains truly matters.
@export var phase: int = 0
## Controls how this domain should treat restore errors relative to its parent.
## Inherit is the safe default. Use Best Effort only when partial restoration is
## acceptable for this domain; use Strict when this domain must restore cleanly.
@export_enum("Inherit", "Best Effort", "Strict")
var restore_policy: int = RestorePolicy.INHERIT


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

	for child in get_children():
		if child is SaveFlowScope:
			child_scope_count += 1
			child_scope_keys.append((child as SaveFlowScope).get_scope_key())
		elif child is SaveFlowSource:
			child_source_count += 1
			child_source_keys.append((child as SaveFlowSource).get_source_key())

	return {
		"valid": true,
		"reason": "",
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
	}


func _describe_restore_policy(value: int) -> String:
	match value:
		RestorePolicy.BEST_EFFORT:
			return "Best Effort"
		RestorePolicy.STRICT:
			return "Strict"
		_:
			return "Inherit"
