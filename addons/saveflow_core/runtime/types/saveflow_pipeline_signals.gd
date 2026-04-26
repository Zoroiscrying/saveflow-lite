## Scene-authored signal bridge for SaveFlow pipeline events.
##
## Add this as a child of a SaveFlowScope or SaveFlowSource, then connect only
## the signals your gameplay code needs in Godot's Node > Signals panel.
@icon("res://addons/saveflow_lite/icons/components/saveflow_pipeline_signals_icon.svg")
@tool
class_name SaveFlowPipelineSignals
extends Node

enum ListenMode {
	OWNER_ONLY,
	OWNER_AND_DESCENDANTS,
	ALL_PIPELINE_EVENTS,
}

signal pipeline_event(event: SaveFlowPipelineEvent)
signal before_save(event: SaveFlowPipelineEvent)
signal after_gather(event: SaveFlowPipelineEvent)
signal before_write(event: SaveFlowPipelineEvent)
signal after_write(event: SaveFlowPipelineEvent)
signal before_load(event: SaveFlowPipelineEvent)
signal after_read(event: SaveFlowPipelineEvent)
signal before_apply(event: SaveFlowPipelineEvent)
signal after_load(event: SaveFlowPipelineEvent)
signal before_save_scope(event: SaveFlowPipelineEvent)
signal after_save_scope(event: SaveFlowPipelineEvent)
signal before_load_scope(event: SaveFlowPipelineEvent)
signal after_load_scope(event: SaveFlowPipelineEvent)
signal before_gather_source(event: SaveFlowPipelineEvent)
signal after_gather_source(event: SaveFlowPipelineEvent)
signal before_apply_source(event: SaveFlowPipelineEvent)
signal after_apply_source(event: SaveFlowPipelineEvent)
signal pipeline_error(event: SaveFlowPipelineEvent)

@export var enabled := true:
	set(value):
		enabled = value
		_refresh_editor_warnings()
@export_enum("Owner Only", "Owner And Descendants", "All Pipeline Events")
var listen_mode: int = ListenMode.OWNER_ONLY:
	set(value):
		listen_mode = value
		_refresh_editor_warnings()
## Optional. Leave empty to use this node's parent as the event owner.
@export var target: NodePath:
	set(value):
		target = value
		_refresh_editor_warnings()


func _ready() -> void:
	_refresh_editor_warnings()


func emit_pipeline_event(event: SaveFlowPipelineEvent) -> void:
	if not handles_pipeline_event(event):
		return

	pipeline_event.emit(event)
	match event.stage:
		"before_save":
			before_save.emit(event)
		"after_gather":
			after_gather.emit(event)
		"before_write":
			before_write.emit(event)
		"after_write":
			after_write.emit(event)
		"before_load":
			before_load.emit(event)
		"after_read":
			after_read.emit(event)
		"before_apply":
			before_apply.emit(event)
		"after_load":
			after_load.emit(event)
		"before_save_scope":
			before_save_scope.emit(event)
		"after_save_scope":
			after_save_scope.emit(event)
		"before_load_scope":
			before_load_scope.emit(event)
		"after_load_scope":
			after_load_scope.emit(event)
		"before_gather_source":
			before_gather_source.emit(event)
		"after_gather_source":
			after_gather_source.emit(event)
		"before_apply_source":
			before_apply_source.emit(event)
		"after_apply_source":
			after_apply_source.emit(event)
		"on_error":
			pipeline_error.emit(event)


func handles_pipeline_event(event: SaveFlowPipelineEvent) -> bool:
	if not enabled or event == null:
		return false
	if listen_mode == ListenMode.ALL_PIPELINE_EVENTS:
		return true

	var event_owner := resolve_event_owner()
	if not is_instance_valid(event_owner):
		return false

	var event_node := _resolve_event_node(event)
	if not is_instance_valid(event_node):
		return false
	if event_owner == event_node:
		return true
	return listen_mode == ListenMode.OWNER_AND_DESCENDANTS and event_owner.is_ancestor_of(event_node)


func resolve_event_owner() -> Node:
	if not target.is_empty():
		var target_node := get_node_or_null(target)
		if target_node != null:
			return target_node
	return get_parent()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	if not enabled:
		return warnings

	var event_owner := resolve_event_owner()
	if not is_instance_valid(event_owner):
		warnings.append("SaveFlowPipelineSignals needs a parent or target node.")
		return warnings

	if listen_mode != ListenMode.ALL_PIPELINE_EVENTS and not _looks_like_pipeline_owner(event_owner):
		warnings.append(
			"SaveFlowPipelineSignals should target a SaveFlowScope or SaveFlowSource unless it listens to all pipeline events."
		)
	return warnings


func _resolve_event_node(event: SaveFlowPipelineEvent) -> Node:
	if event.node != null:
		return event.node
	if event.source != null:
		return event.source
	if event.scope != null:
		return event.scope
	return null


func _looks_like_pipeline_owner(node: Node) -> bool:
	return (
		node is SaveFlowScope
		or node is SaveFlowSource
		or node.has_method("get_scope_key")
		or node.has_method("get_source_key")
	)


func _refresh_editor_warnings() -> void:
	if Engine.is_editor_hint():
		update_configuration_warnings()
