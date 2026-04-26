## Typed event passed to SaveFlow pipeline callbacks.
##
## Events are runtime-only. They describe where the current save/load pipeline is
## and let callbacks cancel the operation without encoding control flow into
## payload dictionaries.
class_name SaveFlowPipelineEvent
extends RefCounted

var stage: String = ""
var slot_id: String = ""
var key: String = ""
var kind: String = ""
var node: Node = null
var scope: Node = null
var source: Node = null
var payload: Variant = null
var result: SaveResult = null
var context: SaveFlowPipelineContext = null
var message: String = ""
var meta: Dictionary = {}
var cancelled := false


static func from_values(stage_name: String, pipeline_context: SaveFlowPipelineContext, options: Dictionary = {}) -> SaveFlowPipelineEvent:
	var event := SaveFlowPipelineEvent.new()
	event.stage = stage_name
	event.context = pipeline_context
	event.slot_id = String(options.get("slot_id", ""))
	event.key = String(options.get("key", ""))
	event.kind = String(options.get("kind", ""))
	event.message = String(options.get("message", ""))
	event.meta = Dictionary(options.get("meta", {}))
	event.payload = options.get("payload", null)

	var node_value: Variant = options.get("node", null)
	if node_value is Node:
		event.node = node_value

	var scope_value: Variant = options.get("scope", null)
	if scope_value is Node:
		event.scope = scope_value
		if event.node == null:
			event.node = scope_value

	var source_value: Variant = options.get("source", null)
	if source_value is Node:
		event.source = source_value
		if event.node == null:
			event.node = source_value

	var result_value: Variant = options.get("result", null)
	if result_value is SaveResult:
		event.result = result_value

	return event


func cancel(cancel_message: String = "pipeline callback cancelled the operation") -> void:
	cancelled = true
	message = cancel_message


func is_cancelled() -> bool:
	return cancelled


func values() -> Dictionary:
	if context == null:
		return {}
	return context.values


func describe() -> Dictionary:
	return {
		"stage": stage,
		"slot_id": slot_id,
		"key": key,
		"kind": kind,
		"node_path": _describe_node_path(node),
		"message": message,
		"cancelled": cancelled,
		"meta": meta,
	}


func _describe_node_path(target: Node) -> String:
	if not is_instance_valid(target):
		return ""
	if target.is_inside_tree():
		return str(target.get_path())
	return String(target.name)
