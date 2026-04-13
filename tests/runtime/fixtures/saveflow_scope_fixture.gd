@tool
extends SaveFlowScope

@export var scope_label: String = ""


func before_save(context: Dictionary = {}) -> void:
	_push_event(context, "before_save")


func before_load(_payload: Dictionary = {}, context: Dictionary = {}) -> void:
	_push_event(context, "before_load")


func after_load(_payload: Dictionary = {}, context: Dictionary = {}) -> void:
	_push_event(context, "after_load")


func _push_event(context: Dictionary, stage: String) -> void:
	var events: Array = Array(context.get("events", []))
	events.append("%s:%s" % [scope_label, stage])
	context["events"] = events
