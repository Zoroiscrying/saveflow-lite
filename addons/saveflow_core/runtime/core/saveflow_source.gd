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
