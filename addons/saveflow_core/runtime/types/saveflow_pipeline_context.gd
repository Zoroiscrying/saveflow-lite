## Runtime support state for one SaveFlow pipeline control.
## Users normally create a SaveFlowPipelineControl, then use `control.context`
## for temporary shared values and diagnostics.
class_name SaveFlowPipelineContext
extends RefCounted

var values: Dictionary = {}
var trace: Array = []
var trace_enabled := true


func get_hook_context() -> Dictionary:
	return values


func record(
	stage: String,
	node: Node = null,
	key: String = "",
	kind: String = "",
	ok := true,
	message := ""
) -> void:
	if not trace_enabled:
		return
	trace.append(
		{
			"stage": stage,
			"kind": kind,
			"key": key,
			"node_path": _describe_node_path(node),
			"ok": ok,
			"message": message,
		}
	)


func to_trace_array() -> Array:
	return trace.duplicate(true)


func clear_trace() -> void:
	trace.clear()


func _describe_node_path(node: Node) -> String:
	if not is_instance_valid(node):
		return ""
	if node.is_inside_tree():
		return str(node.get_path())
	return String(node.name)
