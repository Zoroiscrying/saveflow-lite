@tool
## SaveFlowSaveManagerBus stores editor/runtime save-manager requests in
## project-local files so the editor dock and the running game can coordinate
## without direct process coupling.
class_name SaveFlowSaveManagerBus
extends RefCounted

const ROOT_DIR := "user://saveflow_manager"
const REQUESTS_PATH := ROOT_DIR + "/requests.json"
const STATUS_PATH := ROOT_DIR + "/status.json"
const VERSION := 1


static func list_pending_requests() -> Array:
	var data := _read_json(REQUESTS_PATH, {"version": VERSION, "requests": []})
	var pending: Array = []
	for request_variant in Array(data.get("requests", [])):
		if request_variant is Dictionary and String(request_variant.get("status", "pending")) == "pending":
			pending.append(request_variant)
	return pending


static func append_request(action: String, entry_name: String, metadata: Dictionary = {}) -> Dictionary:
	var data := _read_json(REQUESTS_PATH, {"version": VERSION, "requests": []})
	var requests: Array = Array(data.get("requests", []))
	var timestamp := Time.get_unix_time_from_system()
	var request := {
		"id": _build_request_id(),
		"action": action,
		"name": entry_name,
		"status": "pending",
		"created_at_unix": timestamp,
		"updated_at_unix": timestamp,
		"message": "",
	}
	for key in metadata.keys():
		request[key] = metadata[key]
	requests.append(request)
	data["version"] = VERSION
	data["requests"] = requests
	_write_json(REQUESTS_PATH, data)
	return request


static func complete_request(request_id: String, ok: bool, message: String = "", metadata: Dictionary = {}) -> void:
	var data := _read_json(REQUESTS_PATH, {"version": VERSION, "requests": []})
	var requests: Array = Array(data.get("requests", []))
	var updated: Array = []
	for request_variant in requests:
		if not (request_variant is Dictionary):
			continue
		var request: Dictionary = request_variant
		if String(request.get("id", "")) == request_id:
			request["status"] = "completed" if ok else "failed"
			request["updated_at_unix"] = Time.get_unix_time_from_system()
			request["message"] = message
			for key in metadata.keys():
				request[key] = metadata[key]
		updated.append(request)
	data["version"] = VERSION
	data["requests"] = updated
	_write_json(REQUESTS_PATH, data)


static func read_requests() -> Dictionary:
	return _read_json(REQUESTS_PATH, {"version": VERSION, "requests": []})


static func write_status(status: Dictionary) -> void:
	var previous := read_status()
	var payload := status.duplicate(true)
	payload["version"] = VERSION
	payload["updated_at_unix"] = Time.get_unix_time_from_system()
	_apply_last_runtime_profile(payload, previous)
	_write_json(STATUS_PATH, payload)


static func read_status() -> Dictionary:
	return _read_json(
		STATUS_PATH,
		{
			"version": VERSION,
			"runtime_available": false,
			"bridge_name": "",
			"updated_at_unix": 0,
		}
	)


static func _apply_last_runtime_profile(payload: Dictionary, previous: Dictionary) -> void:
	if bool(payload.get("runtime_available", false)):
		_store_last_runtime_profile(payload, payload, true)
		return
	_store_last_runtime_profile(payload, previous, false)


static func _store_last_runtime_profile(payload: Dictionary, source: Dictionary, overwrite_existing: bool) -> void:
	if overwrite_existing or Dictionary(payload.get("last_settings", {})).is_empty():
		var settings := Dictionary(source.get("settings", {}))
		if settings.is_empty():
			settings = Dictionary(source.get("last_settings", {}))
		if not settings.is_empty():
			payload["last_settings"] = settings.duplicate(true)

	if overwrite_existing or Dictionary(payload.get("last_dev_settings", {})).is_empty():
		var dev_settings := Dictionary(source.get("dev_settings", {}))
		if dev_settings.is_empty():
			dev_settings = Dictionary(source.get("last_dev_settings", {}))
		if not dev_settings.is_empty():
			payload["last_dev_settings"] = dev_settings.duplicate(true)

	if overwrite_existing or String(payload.get("last_bridge_name", "")).is_empty():
		var bridge_name := String(source.get("bridge_name", ""))
		if bridge_name.is_empty():
			bridge_name = String(source.get("last_bridge_name", ""))
		if not bridge_name.is_empty():
			payload["last_bridge_name"] = bridge_name

	if overwrite_existing or float(payload.get("last_runtime_updated_at_unix", 0.0)) <= 0.0:
		var updated_at := float(source.get("updated_at_unix", 0.0))
		if updated_at <= 0.0:
			updated_at = float(source.get("last_runtime_updated_at_unix", 0.0))
		if updated_at > 0.0:
			payload["last_runtime_updated_at_unix"] = updated_at


static func _build_request_id() -> String:
	return "%s_%s" % [str(Time.get_unix_time_from_system()), str(Time.get_ticks_usec())]


static func _read_json(path: String, default_value: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(path):
		return default_value.duplicate(true)

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return default_value.duplicate(true)

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return default_value.duplicate(true)
	if not (json.data is Dictionary):
		return default_value.duplicate(true)
	return Dictionary(json.data)


static func _write_json(path: String, value: Dictionary) -> void:
	_ensure_root_dir()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(value, "\t"))


static func _ensure_root_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ROOT_DIR)
