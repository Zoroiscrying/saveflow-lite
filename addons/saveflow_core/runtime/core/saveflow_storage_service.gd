extends RefCounted

const FORMAT_AUTO := 0
const FORMAT_JSON := 1
const FORMAT_BINARY := 2
const INDEX_VERSION := 1
const INDEX_SLOTS_KEY := "slots"
const TEMP_FILE_SUFFIX := ".tmp"
const BACKUP_FILE_SUFFIX := ".bak"

var _settings: SaveSettings = SaveSettings.new()


func configure(settings: SaveSettings) -> void:
	_settings = settings if settings != null else SaveSettings.new()


func resolve_storage_format() -> int:
	if _settings.storage_format != FORMAT_AUTO:
		return _settings.storage_format
	if Engine.is_editor_hint():
		return FORMAT_JSON
	return FORMAT_BINARY


func save_payload(slot_id: String, payload: Dictionary, format: int) -> SaveResult:
	if not is_valid_payload(payload):
		return _error_result(
			SaveError.INVALID_FORMAT,
			"INVALID_FORMAT",
			"payload must contain meta and data",
			{"slot_id": slot_id}
		)

	var path: String = build_slot_path(slot_id, format)
	var ensure_result: SaveResult = ensure_parent_dir(path)
	if not ensure_result.ok:
		return ensure_result

	var previous_result: SaveResult = locate_slot(slot_id, false)
	var previous_path: String = ""
	if previous_result.ok:
		previous_path = String(previous_result.data["path"])
		var previous_entry: Dictionary = Dictionary(previous_result.data.get("entry", {}))
		if previous_entry.has("meta") and previous_entry["meta"] is Dictionary:
			var previous_meta: Dictionary = previous_entry["meta"]
			if previous_meta.has("created_at_unix") and not payload["meta"].has("created_at_unix"):
				payload["meta"]["created_at_unix"] = previous_meta["created_at_unix"]
			if previous_meta.has("created_at_iso") and not payload["meta"].has("created_at_iso"):
				payload["meta"]["created_at_iso"] = previous_meta["created_at_iso"]

	var write_result: SaveResult = write_payload_file(path, payload, format)
	if not write_result.ok:
		return write_result

	if previous_path != "" and previous_path != path and FileAccess.file_exists(previous_path):
		DirAccess.remove_absolute(previous_path)

	var index_result: SaveResult = upsert_index_entry(slot_id, path, format, payload["meta"])
	if not index_result.ok:
		return index_result

	return _ok_result(payload, {"slot_id": slot_id, "path": path, "format": format})


func locate_slot(slot_id: String, use_fallback := true) -> SaveResult:
	if slot_id.is_empty():
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"slot_id cannot be empty"
		)

	var index_result: SaveResult = read_index_data()
	if index_result.ok:
		var slots_map: Dictionary = index_result.data[INDEX_SLOTS_KEY]
		if slots_map.has(slot_id):
			var entry: Dictionary = slots_map[slot_id]
			var indexed_path: String = String(entry.get("path", ""))
			if indexed_path != "" and FileAccess.file_exists(indexed_path):
				return _ok_result(
					{
						"path": indexed_path,
						"format": int(entry.get("format", resolve_storage_format())),
						"entry": entry,
					},
					{"slot_id": slot_id, "source": "index"}
				)

	if use_fallback:
		for candidate in build_candidate_paths(slot_id):
			var candidate_path: String = String(candidate["path"])
			if FileAccess.file_exists(candidate_path):
				return _ok_result(
					{
						"path": candidate_path,
						"format": int(candidate["format"]),
						"entry": {},
					},
					{"slot_id": slot_id, "source": "fallback"}
				)

	return _error_result(
		SaveError.SLOT_NOT_FOUND,
		"SLOT_NOT_FOUND",
		"slot was not found",
		{"slot_id": slot_id}
	)


func build_candidate_paths(slot_id: String) -> Array:
	var resolved_format: int = resolve_storage_format()
	var formats: Array = [resolved_format]
	if resolved_format != FORMAT_JSON:
		formats.append(FORMAT_JSON)
	if resolved_format != FORMAT_BINARY:
		formats.append(FORMAT_BINARY)

	var candidates: Array = []
	for format in formats:
		candidates.append({"path": build_slot_path(slot_id, int(format)), "format": int(format)})
	return candidates


func build_slot_path(slot_id: String, format: int) -> String:
	var extension: String = _settings.file_extension_json
	if format == FORMAT_BINARY:
		extension = _settings.file_extension_binary
	return "%s/%s.%s" % [_settings.save_root, sanitize_slot_id(slot_id), extension]


func sanitize_slot_id(slot_id: String) -> String:
	var sanitized: String = slot_id.strip_edges()
	sanitized = sanitized.replace("/", "_")
	sanitized = sanitized.replace("\\", "_")
	sanitized = sanitized.replace(":", "_")
	sanitized = sanitized.replace("*", "_")
	sanitized = sanitized.replace("?", "_")
	sanitized = sanitized.replace("\"", "_")
	sanitized = sanitized.replace("<", "_")
	sanitized = sanitized.replace(">", "_")
	sanitized = sanitized.replace("|", "_")
	if sanitized.is_empty():
		sanitized = "slot"
	return sanitized


func get_index_path() -> String:
	return _settings.slot_index_file


func read_payload_file(path: String, format: int) -> SaveResult:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		var open_error_result := _error_result(
			SaveError.READ_FAILED,
			"READ_FAILED",
			"failed to open save file for reading",
			{"path": path, "open_error": FileAccess.get_open_error()}
		)
		var backup_open_result := try_read_slot_backup(path, format)
		if backup_open_result.ok:
			return _ok_result(backup_open_result.data, backup_open_result.meta)
		return open_error_result

	if format == FORMAT_JSON:
		var text: String = file.get_as_text()
		var json := JSON.new()
		var parse_error: int = json.parse(text)
		if parse_error != OK:
			var parse_error_result := _error_result(
				SaveError.INVALID_FORMAT,
				"INVALID_FORMAT",
				"failed to parse json save file",
				{"path": path, "json_error": parse_error}
			)
			var backup_parse_result := try_read_slot_backup(path, format)
			if backup_parse_result.ok:
				return _ok_result(backup_parse_result.data, backup_parse_result.meta)
			return parse_error_result
		var native_payload: Variant = JSON.to_native(json.data, true)
		return _ok_result(native_payload, {"path": path, "format": format})

	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	var payload: Variant = bytes_to_var(bytes)
	return _ok_result(payload, {"path": path, "format": format})


func probe_payload_file(path: String, format: int) -> Dictionary:
	var report := {
		"path": path,
		"format": format,
		"exists": FileAccess.file_exists(path),
		"valid_payload": false,
		"error_key": "",
	}
	if not bool(report["exists"]):
		report["error_key"] = "FILE_NOT_FOUND"
		return report

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		report["error_key"] = "READ_FAILED"
		return report

	var payload: Variant = null
	if format == FORMAT_JSON:
		var text: String = file.get_as_text()
		var json := JSON.new()
		var parse_error: int = json.parse(text)
		if parse_error != OK:
			report["error_key"] = "INVALID_FORMAT"
			return report
		payload = json.data
	else:
		var bytes: PackedByteArray = file.get_buffer(file.get_length())
		payload = bytes_to_var(bytes)

	if not (payload is Dictionary) or not is_valid_payload(payload):
		report["error_key"] = "INVALID_PAYLOAD"
		return report

	report["valid_payload"] = true
	return report


func write_payload_file(path: String, payload: Dictionary, format: int) -> SaveResult:
	if _settings.use_safe_write:
		return write_payload_file_safe(path, payload, format)
	return write_payload_file_direct(path, payload, format)


func write_payload_file_safe(path: String, payload: Dictionary, format: int) -> SaveResult:
	var temp_path: String = "%s%s" % [path, TEMP_FILE_SUFFIX]
	if FileAccess.file_exists(temp_path):
		DirAccess.remove_absolute(temp_path)

	var write_result: SaveResult = write_payload_file_direct(temp_path, payload, format, false)
	if not write_result.ok:
		return write_result

	if FileAccess.file_exists(path):
		var backup_result: SaveResult = write_slot_backup(path)
		if not backup_result.ok:
			DirAccess.remove_absolute(temp_path)
			return backup_result
		var remove_error: int = DirAccess.remove_absolute(path)
		if remove_error != OK:
			DirAccess.remove_absolute(temp_path)
			return _error_result(
				SaveError.WRITE_FAILED,
				"WRITE_FAILED",
				"failed to replace existing slot file",
				{"path": path, "dir_error": remove_error}
			)

	var rename_error: int = DirAccess.rename_absolute(temp_path, path)
	if rename_error != OK:
		DirAccess.remove_absolute(temp_path)
		return _error_result(
			SaveError.WRITE_FAILED,
			"WRITE_FAILED",
			"failed to move temp file into final location",
			{"path": path, "temp_path": temp_path, "dir_error": rename_error}
		)

	return _ok_result({"path": path, "format": format})


func write_payload_file_direct(path: String, payload: Dictionary, format: int, create_backup := true) -> SaveResult:
	var ensure_result: SaveResult = ensure_parent_dir(path)
	if not ensure_result.ok:
		return ensure_result
	if create_backup:
		var backup_result: SaveResult = write_slot_backup(path)
		if not backup_result.ok:
			return backup_result

	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _error_result(
			SaveError.WRITE_FAILED,
			"WRITE_FAILED",
			"failed to open save file for writing",
			{"path": path, "open_error": FileAccess.get_open_error()}
		)

	if format == FORMAT_JSON:
		var indent: String = ""
		if _settings.pretty_json_in_editor and Engine.is_editor_hint():
			indent = "\t"
		var json_payload: Variant = JSON.from_native(payload, true)
		var text: String = JSON.stringify(json_payload, indent)
		file.store_string(text)
		file = null
		return _ok_result({"path": path, "format": format})

	var bytes: PackedByteArray = var_to_bytes(payload)
	file.store_buffer(bytes)
	file = null
	return _ok_result({"path": path, "format": format})


func read_index_data() -> SaveResult:
	var path: String = get_index_path()
	if not FileAccess.file_exists(path):
		return _ok_result(default_index_data(), {"path": path, "created_default": true})

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _error_result(
			SaveError.INDEX_READ_FAILED,
			"INDEX_READ_FAILED",
			"failed to open slot index",
			{"path": path, "open_error": FileAccess.get_open_error()}
		)

	var text: String = file.get_as_text()
	var json := JSON.new()
	var parse_error: int = json.parse(text)
	if parse_error != OK or not (json.data is Dictionary):
		return _error_result(
			SaveError.INDEX_READ_FAILED,
			"INDEX_READ_FAILED",
			"failed to parse slot index",
			{"path": path, "json_error": parse_error}
		)

	var index_data: Dictionary = json.data
	if not index_data.has(INDEX_SLOTS_KEY) or not (index_data[INDEX_SLOTS_KEY] is Dictionary):
		index_data[INDEX_SLOTS_KEY] = {}
	if not index_data.has("version"):
		index_data["version"] = INDEX_VERSION
	return _ok_result(index_data, {"path": path})


func write_index_data(index_data: Dictionary) -> SaveResult:
	var path: String = get_index_path()
	var ensure_result: SaveResult = ensure_parent_dir(path)
	if not ensure_result.ok:
		return ensure_result

	index_data["version"] = INDEX_VERSION
	if not index_data.has(INDEX_SLOTS_KEY) or not (index_data[INDEX_SLOTS_KEY] is Dictionary):
		index_data[INDEX_SLOTS_KEY] = {}

	var text: String = JSON.stringify(index_data, "\t")
	if _settings.use_safe_write:
		var temp_path: String = "%s%s" % [path, TEMP_FILE_SUFFIX]
		if FileAccess.file_exists(temp_path):
			DirAccess.remove_absolute(temp_path)
		var temp_file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
		if temp_file == null:
			return _error_result(
				SaveError.INDEX_WRITE_FAILED,
				"INDEX_WRITE_FAILED",
				"failed to open temp index file",
				{"path": temp_path, "open_error": FileAccess.get_open_error()}
			)
		temp_file.store_string(text)
		temp_file = null
		if FileAccess.file_exists(path):
			var remove_error: int = DirAccess.remove_absolute(path)
			if remove_error != OK:
				return _error_result(
					SaveError.INDEX_WRITE_FAILED,
					"INDEX_WRITE_FAILED",
					"failed to replace existing index file",
					{"path": path, "dir_error": remove_error}
				)
		var rename_error: int = DirAccess.rename_absolute(temp_path, path)
		if rename_error != OK:
			return _error_result(
				SaveError.INDEX_WRITE_FAILED,
				"INDEX_WRITE_FAILED",
				"failed to move temp index file into final location",
				{"path": path, "temp_path": temp_path, "dir_error": rename_error}
			)
		return _ok_result(index_data, {"path": path})

	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _error_result(
			SaveError.INDEX_WRITE_FAILED,
			"INDEX_WRITE_FAILED",
			"failed to open index file for writing",
			{"path": path, "open_error": FileAccess.get_open_error()}
		)
	file.store_string(text)
	file = null
	return _ok_result(index_data, {"path": path})


func upsert_index_entry(slot_id: String, path: String, format: int, meta: Dictionary) -> SaveResult:
	var index_result: SaveResult = read_index_data()
	if not index_result.ok:
		return index_result

	var index_data: Dictionary = index_result.data
	var slots_map: Dictionary = index_data[INDEX_SLOTS_KEY]
	slots_map[slot_id] = {
		"slot_id": slot_id,
		"path": path,
		"format": format,
		"meta": meta.duplicate(true),
	}
	index_data[INDEX_SLOTS_KEY] = slots_map
	return write_index_data(index_data)


func remove_index_entry(slot_id: String) -> SaveResult:
	var index_result: SaveResult = read_index_data()
	if not index_result.ok:
		return index_result

	var index_data: Dictionary = index_result.data
	var slots_map: Dictionary = index_data[INDEX_SLOTS_KEY]
	if slots_map.has(slot_id):
		slots_map.erase(slot_id)
	index_data[INDEX_SLOTS_KEY] = slots_map
	return write_index_data(index_data)


func build_backup_path(path: String) -> String:
	return "%s%s" % [path, BACKUP_FILE_SUFFIX]


func write_slot_backup(path: String) -> SaveResult:
	if not _settings.keep_last_backup or not FileAccess.file_exists(path):
		return _ok_result()

	var backup_path := build_backup_path(path)
	var ensure_result: SaveResult = ensure_parent_dir(backup_path)
	if not ensure_result.ok:
		return ensure_result

	var source := FileAccess.open(path, FileAccess.READ)
	if source == null:
		return _error_result(
			SaveError.BACKUP_RESTORE_FAILED,
			"BACKUP_READ_FAILED",
			"failed to open slot file while creating backup",
			{"path": path, "backup_path": backup_path, "open_error": FileAccess.get_open_error()}
		)
	var bytes := source.get_buffer(source.get_length())
	source = null

	var backup := FileAccess.open(backup_path, FileAccess.WRITE)
	if backup == null:
		return _error_result(
			SaveError.BACKUP_RESTORE_FAILED,
			"BACKUP_WRITE_FAILED",
			"failed to write slot backup file",
			{"path": path, "backup_path": backup_path, "open_error": FileAccess.get_open_error()}
		)
	backup.store_buffer(bytes)
	backup = null
	return _ok_result({"backup_path": backup_path})


func try_read_slot_backup(path: String, format: int) -> SaveResult:
	var backup_path := build_backup_path(path)
	if not FileAccess.file_exists(backup_path):
		return _error_result(
			SaveError.BACKUP_RESTORE_FAILED,
			"BACKUP_NOT_FOUND",
			"no slot backup file is available",
			{"path": path, "backup_path": backup_path}
		)

	var read_result := read_payload_file(backup_path, format)
	if not read_result.ok:
		return read_result
	if not is_valid_payload(read_result.data):
		return _error_result(
			SaveError.BACKUP_RESTORE_FAILED,
			"BACKUP_INVALID_FORMAT",
			"slot backup exists but does not contain a valid save payload",
			{"path": path, "backup_path": backup_path}
		)
	return _ok_result(read_result.data, {"backup_path": backup_path, "used_backup": true})


func ensure_parent_dir(path: String) -> SaveResult:
	if not _settings.auto_create_dirs:
		return _ok_result(path)

	var base_dir: String = path.get_base_dir()
	var make_error: int = DirAccess.make_dir_recursive_absolute(base_dir)
	if make_error != OK:
		return _error_result(
			SaveError.DIR_CREATE_FAILED,
			"DIR_CREATE_FAILED",
			"failed to create parent directory",
			{"path": path, "base_dir": base_dir, "dir_error": make_error}
		)
	return _ok_result(base_dir)


func default_index_data() -> Dictionary:
	return {
		"version": INDEX_VERSION,
		INDEX_SLOTS_KEY: {},
	}


func is_valid_payload(payload: Variant) -> bool:
	return payload is Dictionary and payload.has("meta") and payload.has("data") and payload["meta"] is Dictionary


func is_valid_format(mode: int) -> bool:
	return mode == FORMAT_AUTO or mode == FORMAT_JSON or mode == FORMAT_BINARY


func _ok_result(data: Variant = null, meta: Dictionary = {}) -> SaveResult:
	var result := SaveResult.new()
	result.ok = true
	result.error_code = SaveError.OK
	result.error_key = "OK"
	result.error_message = ""
	result.data = data
	result.meta = meta
	return result


func _error_result(error_code: int, error_key: String, error_message: String, meta: Dictionary = {}) -> SaveResult:
	var result := SaveResult.new()
	result.ok = false
	result.error_code = error_code
	result.error_key = error_key
	result.error_message = error_message
	result.data = null
	result.meta = meta
	return result
