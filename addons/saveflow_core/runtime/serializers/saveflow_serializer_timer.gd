class_name SaveFlowSerializerTimer
extends SaveFlowBuiltInSerializer


func get_serializer_id() -> String:
	return "timer_state"


func get_display_name() -> String:
	return "Timer State"


func supports_node(node: Node) -> bool:
	return node is Timer


func gather_from_node(node: Node) -> Variant:
	var target := node as Timer
	if target == null:
		return {}
	var process_callback: Variant = target.get("process_callback")
	if process_callback == null:
		process_callback = target.get("timer_process_callback")
	return {
		"wait_time": target.wait_time,
		"one_shot": target.one_shot,
		"autostart": target.autostart,
		"paused": target.paused,
		"ignore_time_scale": target.ignore_time_scale,
		"process_callback": process_callback,
		"is_running": not target.is_stopped(),
		"time_left": target.time_left,
	}


func apply_to_node(node: Node, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var target := node as Timer
	if target == null:
		return
	var payload: Dictionary = data
	var configured_wait_time: float = max(0.0, float(payload.get("wait_time", target.wait_time)))
	if payload.has("wait_time"):
		target.wait_time = configured_wait_time
	if payload.has("one_shot"):
		target.one_shot = bool(payload["one_shot"])
	if payload.has("autostart"):
		target.autostart = bool(payload["autostart"])
	if payload.has("ignore_time_scale"):
		target.ignore_time_scale = bool(payload["ignore_time_scale"])
	if payload.has("process_callback"):
		var process_callback: int = int(payload["process_callback"])
		if _has_property(target, "process_callback"):
			target.set("process_callback", process_callback)
		elif _has_property(target, "timer_process_callback"):
			target.set("timer_process_callback", process_callback)

	var should_run := bool(payload.get("is_running", false))
	var time_left := float(payload.get("time_left", target.wait_time))
	if should_run:
		var resumed_time_left: float = max(0.0, time_left)
		if resumed_time_left > 0.0 and resumed_time_left < configured_wait_time:
			target.start(resumed_time_left)
			target.wait_time = configured_wait_time
		else:
			target.start()
	else:
		target.stop()
	target.paused = bool(payload.get("paused", false))


static func _has_property(target: Object, property_name: String) -> bool:
	for property_info_variant in target.get_property_list():
		if not (property_info_variant is Dictionary):
			continue
		var property_info: Dictionary = property_info_variant
		if String(property_info.get("name", "")) == property_name:
			return true
	return false
