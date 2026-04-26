extends RefCounted

const SaveFlowPipelineControlScript := preload("res://addons/saveflow_core/runtime/types/saveflow_pipeline_control.gd")


func notify_stage(
	pipeline_control: SaveFlowPipelineControl,
	stage: String,
	options: Dictionary = {}
) -> SaveResult:
	pipeline_control = resolve_pipeline_control(pipeline_control)
	return pipeline_control.notify(stage, options)


func finish_error(
	pipeline_control: SaveFlowPipelineControl,
	result: SaveResult,
	options: Dictionary = {}
) -> SaveResult:
	if pipeline_control != null:
		pipeline_control.notify_error(result, options)
		return attach_trace(result, pipeline_control.context)
	return result


func resolve_pipeline_control(pipeline_control: SaveFlowPipelineControl = null) -> SaveFlowPipelineControl:
	if pipeline_control != null:
		return pipeline_control
	return SaveFlowPipelineControlScript.new()


func register_signal_bridges(pipeline_control: SaveFlowPipelineControl, root: Node) -> void:
	if pipeline_control == null or not is_instance_valid(root):
		return
	for bridge in collect_signal_bridges(root):
		pipeline_control.add_signal_bridge(bridge)


func collect_signal_bridges(root: Node) -> Array:
	var bridges: Array = []
	if not is_instance_valid(root):
		return bridges
	_collect_signal_bridges_recursive(root, bridges)
	return bridges


func attach_trace(result: SaveResult, pipeline_context: SaveFlowPipelineContext) -> SaveResult:
	if result == null or pipeline_context == null:
		return result
	result.meta["pipeline_trace"] = pipeline_context.to_trace_array()
	return result


func _collect_signal_bridges_recursive(node: Node, bridges: Array) -> void:
	if node is SaveFlowPipelineSignals:
		bridges.append(node)
	for child in node.get_children():
		if child is Node:
			_collect_signal_bridges_recursive(child, bridges)
