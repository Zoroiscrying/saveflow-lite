## Callback control object for one SaveFlow save/load pipeline.
##
## Pass this to SaveFlow scope APIs when gameplay code needs local lifecycle
## callbacks. The callbacks get a SaveFlowPipelineEvent, while `context.values`
## is passed to existing SaveFlowScope/SaveFlowSource hooks.
class_name SaveFlowPipelineControl
extends RefCounted

const SaveFlowPipelineContextScript := preload("res://addons/saveflow_core/runtime/types/saveflow_pipeline_context.gd")
const SaveFlowPipelineEventScript := preload("res://addons/saveflow_core/runtime/types/saveflow_pipeline_event.gd")

var context: SaveFlowPipelineContext = SaveFlowPipelineContextScript.new()

var before_save: Callable = Callable()
var after_gather: Callable = Callable()
var before_write: Callable = Callable()
var after_write: Callable = Callable()
var before_load: Callable = Callable()
var after_read: Callable = Callable()
var before_apply: Callable = Callable()
var before_save_scope: Callable = Callable()
var after_save_scope: Callable = Callable()
var before_load_scope: Callable = Callable()
var after_load_scope: Callable = Callable()
var before_gather_source: Callable = Callable()
var after_gather_source: Callable = Callable()
var before_apply_source: Callable = Callable()
var after_apply_source: Callable = Callable()
var after_load: Callable = Callable()
var on_error: Callable = Callable()
var signal_bridges: Array = []


func add_signal_bridge(bridge: Node) -> void:
	if bridge == null or signal_bridges.has(bridge):
		return
	if bridge.has_method("emit_pipeline_event"):
		signal_bridges.append(bridge)


func add_signal_bridges(bridges: Array) -> void:
	for bridge_variant in bridges:
		if bridge_variant is Node:
			add_signal_bridge(bridge_variant)


func clear_signal_bridges() -> void:
	signal_bridges.clear()


func notify(stage: String, options: Dictionary = {}) -> SaveResult:
	var event: SaveFlowPipelineEvent = SaveFlowPipelineEventScript.from_values(stage, context, options)
	var callback := _resolve_callback(stage)
	var callback_result: Variant = null
	if callback.is_valid():
		callback_result = callback.call(event)

	_emit_signal_bridges(event)
	var result := _resolve_callback_result(event, callback_result)
	context.record(stage, event.node, event.key, event.kind, result.ok, _resolve_result_message(event, result))
	if not result.ok:
		notify_error(result, event)
	return result


func notify_error(result: SaveResult, event_or_options: Variant = {}) -> void:
	if result == null or bool(result.meta.get("pipeline_error_notified", false)):
		return
	result.meta["pipeline_error_notified"] = true

	var event: SaveFlowPipelineEvent
	if event_or_options is SaveFlowPipelineEvent:
		event = event_or_options
		event.stage = "on_error"
		event.result = result
	elif event_or_options is Dictionary:
		var options: Dictionary = event_or_options
		options["result"] = result
		event = SaveFlowPipelineEventScript.from_values("on_error", context, options)
	else:
		event = SaveFlowPipelineEventScript.from_values("on_error", context, {"result": result})

	_emit_signal_bridges(event)
	if not on_error.is_valid():
		return
	on_error.call(event)


func get_hook_context() -> Dictionary:
	return context.get_hook_context()


func _resolve_callback(stage: String) -> Callable:
	match stage:
		"before_save":
			return before_save
		"after_gather":
			return after_gather
		"before_write":
			return before_write
		"after_write":
			return after_write
		"before_load":
			return before_load
		"after_read":
			return after_read
		"before_apply":
			return before_apply
		"before_save_scope":
			return before_save_scope
		"after_save_scope":
			return after_save_scope
		"before_load_scope":
			return before_load_scope
		"after_load_scope":
			return after_load_scope
		"before_gather_source":
			return before_gather_source
		"after_gather_source":
			return after_gather_source
		"before_apply_source":
			return before_apply_source
		"after_apply_source":
			return after_apply_source
		"after_load":
			return after_load
		"on_error":
			return on_error
		_:
			return Callable()


func _resolve_callback_result(event: SaveFlowPipelineEvent, callback_result: Variant) -> SaveResult:
	if callback_result is SaveResult:
		var save_result: SaveResult = callback_result
		if save_result.ok:
			return _ok_result(event, save_result.meta)
		return save_result

	if callback_result is bool and not bool(callback_result):
		event.cancel("pipeline callback returned false")

	if event.is_cancelled():
		return _error_result(
			SaveError.PIPELINE_CANCELLED,
			"PIPELINE_CANCELLED",
			event.message,
			{"event": event.describe()}
		)

	return _ok_result(event)


func _resolve_result_message(event: SaveFlowPipelineEvent, result: SaveResult) -> String:
	if result == null:
		return event.message
	if result.ok:
		return event.message
	return result.error_key


func _ok_result(data: Variant = null, meta: Dictionary = {}) -> SaveResult:
	var result := SaveResult.new()
	result.ok = true
	result.error_code = SaveError.OK
	result.error_key = "OK"
	result.data = data
	result.meta = meta
	return result


func _emit_signal_bridges(event: SaveFlowPipelineEvent) -> void:
	for bridge_variant in signal_bridges:
		if not is_instance_valid(bridge_variant):
			continue
		var bridge := bridge_variant as Node
		if bridge.has_method("emit_pipeline_event"):
			bridge.call("emit_pipeline_event", event)


func _error_result(error_code: int, error_key: String, error_message: String, meta: Dictionary = {}) -> SaveResult:
	var result := SaveResult.new()
	result.ok = false
	result.error_code = error_code
	result.error_key = error_key
	result.error_message = error_message
	result.meta = meta
	return result
