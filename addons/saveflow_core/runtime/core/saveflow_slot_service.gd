extends RefCounted

const INDEX_SLOTS_KEY := "slots"

var _storage_service = null
var _slot_metadata_service = null


func configure(storage_service: Variant, slot_metadata_service: Variant) -> void:
	_storage_service = storage_service
	_slot_metadata_service = slot_metadata_service


func save_slot(
	slot_id: String,
	data: Variant,
	meta_or_display_name: Variant = {},
	save_type: String = "manual",
	chapter_name: String = "",
	location_name: String = "",
	playtime_seconds: int = 0,
	difficulty: String = "",
	thumbnail_path: String = "",
	extra_meta: Dictionary = {}
) -> SaveResult:
	if slot_id.is_empty():
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"slot_id cannot be empty"
		)

	var meta_patch: Dictionary = _slot_metadata_service.resolve_slot_meta_patch(
		meta_or_display_name,
		save_type,
		chapter_name,
		location_name,
		playtime_seconds,
		difficulty,
		thumbnail_path,
		extra_meta
	)
	var payload: Dictionary = {
		"meta": _slot_metadata_service.build_meta(slot_id, meta_patch),
		"data": data,
	}
	return save_payload(slot_id, payload, _storage_service.resolve_storage_format())


func save_record(
	slot_id: String,
	record_key: String,
	data: Variant,
	meta_or_display_name: Variant = {},
	record_kind: String = "custom",
	extra_meta: Dictionary = {}
) -> SaveResult:
	if slot_id.is_empty():
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"slot_id cannot be empty"
		)
	if record_key.strip_edges().is_empty():
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"record_key cannot be empty",
			{"slot_id": slot_id}
		)

	var meta_patch: Dictionary = _slot_metadata_service.resolve_slot_meta_patch(
		meta_or_display_name,
		"manual",
		"",
		"",
		0,
		"",
		"",
		extra_meta
	)
	for key in extra_meta.keys():
		meta_patch[key] = extra_meta[key]
	meta_patch["record_key"] = record_key
	meta_patch["record_kind"] = record_kind
	var conflict_result := _validate_record_kind_conflict(slot_id, record_key, String(meta_patch.get("record_kind", "")))
	if not conflict_result.ok:
		return conflict_result
	var payload: Dictionary = {
		"meta": _slot_metadata_service.build_meta(slot_id, meta_patch),
		"data": data,
	}
	return _storage_service.save_record_payload(slot_id, record_key, payload, _storage_service.resolve_storage_format())


func load_slot(slot_id: String) -> SaveResult:
	return load_record(slot_id, "main")


func load_record(slot_id: String, record_key: String) -> SaveResult:
	var locate_result: SaveResult = _storage_service.locate_record(slot_id, record_key)
	if not locate_result.ok:
		return locate_result

	var path: String = String(locate_result.data["path"])
	var format: int = int(locate_result.data["format"])
	var read_result: SaveResult = _storage_service.read_payload_file(path, format)
	if not read_result.ok:
		return read_result

	var payload: Variant = read_result.data
	if not _storage_service.is_valid_payload(payload):
		var backup_result: SaveResult = _storage_service.try_read_slot_backup(path, format)
		if backup_result.ok:
			payload = backup_result.data
		if not _storage_service.is_valid_payload(payload):
			return _error_result(
				SaveError.INVALID_FORMAT,
				"INVALID_FORMAT",
				"save payload must contain meta and data",
				{"slot_id": slot_id, "record_key": record_key, "path": path}
			)

	var payload_dict := Dictionary(payload)
	var slot_meta := Dictionary(payload_dict.get("meta", {}))
	if String(slot_meta.get("slot_id", "")).is_empty():
		slot_meta["slot_id"] = slot_id
	if String(slot_meta.get("record_key", "")).is_empty():
		slot_meta["record_key"] = record_key
	if String(slot_meta.get("record_kind", "")).is_empty():
		slot_meta["record_kind"] = "main" if record_key == "main" else "custom"
	payload_dict["meta"] = slot_meta
	var compatibility_report: Dictionary = _slot_metadata_service.build_compatibility_report(slot_meta)
	if not bool(compatibility_report.get("compatible", true)):
		return _error_result(
			SaveError.MIGRATION_REQUIRED,
			"MIGRATION_REQUIRED",
			_slot_metadata_service.build_compatibility_error_message(compatibility_report),
			{
				"slot_id": slot_id,
				"record_key": record_key,
				"path": path,
				"format": format,
				"compatibility_report": compatibility_report,
			}
		)

	return _ok_result(
		payload_dict,
		{
			"slot_id": slot_id,
			"record_key": record_key,
			"path": path,
			"format": format,
			"compatibility_report": compatibility_report,
		}
	)


func load_slot_data(slot_id: String) -> SaveResult:
	var result: SaveResult = load_slot(slot_id)
	if not result.ok:
		return result
	return _ok_result(result.data["data"], result.meta)


func load_record_data(slot_id: String, record_key: String) -> SaveResult:
	var result: SaveResult = load_record(slot_id, record_key)
	if not result.ok:
		return result
	return _ok_result(result.data["data"], result.meta)


func load_slot_or_default(slot_id: String, default_data: Variant) -> SaveResult:
	var result: SaveResult = load_slot(slot_id)
	if result.ok:
		return result
	return _ok_result(default_data, {"slot_id": slot_id, "used_default": true})


func delete_slot(slot_id: String) -> SaveResult:
	var locate_result: SaveResult = _storage_service.locate_slot(slot_id)
	if not locate_result.ok:
		return locate_result

	var path: String = String(locate_result.data["path"])
	var backup_path: String = _storage_service.build_backup_path(path)
	var remove_error: int = DirAccess.remove_absolute(path)
	if remove_error != OK:
		return _error_result(
			SaveError.DELETE_FAILED,
			"DELETE_FAILED",
			"failed to delete slot file",
			{"slot_id": slot_id, "path": path, "dir_error": remove_error}
		)

	var index_result: SaveResult = _storage_service.remove_index_entry(slot_id)
	if not index_result.ok:
		return index_result

	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)

	return _ok_result({"slot_id": slot_id, "path": path})


func copy_slot(from_slot: String, to_slot: String, overwrite := false) -> SaveResult:
	if from_slot.is_empty() or to_slot.is_empty():
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"from_slot and to_slot cannot be empty"
		)
	if from_slot == to_slot:
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"from_slot and to_slot must be different"
		)

	if slot_exists(to_slot) and not overwrite:
		return _error_result(
			SaveError.SLOT_ALREADY_EXISTS,
			"SLOT_ALREADY_EXISTS",
			"target slot already exists",
			{"slot_id": to_slot}
		)

	var source_result: SaveResult = load_slot(from_slot)
	if not source_result.ok:
		return source_result

	var payload: Dictionary = source_result.data.duplicate(true)
	var meta: Dictionary = payload["meta"]
	meta["slot_id"] = to_slot
	meta["saved_at_unix"] = Time.get_unix_time_from_system()
	if String(meta.get("display_name", "")).is_empty() or String(meta.get("display_name", "")) == from_slot:
		meta["display_name"] = to_slot
	payload["meta"] = meta

	var source_format: int = int(source_result.meta.get("format", _storage_service.resolve_storage_format()))
	return save_payload(to_slot, payload, source_format)


func rename_slot(old_id: String, new_id: String, overwrite := false) -> SaveResult:
	if old_id.is_empty() or new_id.is_empty():
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"old_id and new_id cannot be empty"
		)
	if old_id == new_id:
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"old_id and new_id must be different"
		)

	if slot_exists(new_id) and not overwrite:
		return _error_result(
			SaveError.SLOT_ALREADY_EXISTS,
			"SLOT_ALREADY_EXISTS",
			"target slot already exists",
			{"slot_id": new_id}
		)

	var source_result: SaveResult = load_slot(old_id)
	if not source_result.ok:
		return source_result

	var payload: Dictionary = source_result.data.duplicate(true)
	var meta: Dictionary = payload["meta"]
	meta["slot_id"] = new_id
	if String(meta.get("display_name", "")) == old_id:
		meta["display_name"] = new_id
	payload["meta"] = meta

	var source_format: int = int(source_result.meta.get("format", _storage_service.resolve_storage_format()))
	var save_result: SaveResult = save_payload(new_id, payload, source_format)
	if not save_result.ok:
		return save_result

	var delete_result: SaveResult = delete_slot(old_id)
	if not delete_result.ok:
		return delete_result

	return save_result


func slot_exists(slot_id: String) -> bool:
	var locate_result: SaveResult = _storage_service.locate_slot(slot_id)
	return locate_result.ok


func record_exists(slot_id: String, record_key: String) -> bool:
	var locate_result: SaveResult = _storage_service.locate_record(slot_id, record_key)
	return locate_result.ok


func list_slot_records(slot_id: String) -> SaveResult:
	if slot_id.is_empty():
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"slot_id cannot be empty"
		)
	return _ok_result(_storage_service.list_record_entries(slot_id), {"slot_id": slot_id})


func list_slots() -> SaveResult:
	var index_result: SaveResult = _storage_service.read_index_data()
	if not index_result.ok:
		return index_result

	var slots_map: Dictionary = index_result.data[INDEX_SLOTS_KEY]
	var slot_infos: Array = []
	for slot_id in slots_map.keys():
		var entry: Dictionary = slots_map[slot_id]
		if entry.has("meta"):
			slot_infos.append(entry["meta"].duplicate(true))
	return _ok_result(slot_infos)


func read_slot_summary(slot_id: String) -> SaveResult:
	if slot_id.is_empty():
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"slot_id cannot be empty"
		)

	var meta_result: SaveResult = read_slot_meta_for_summary(slot_id)
	if not meta_result.ok:
		return meta_result

	return _ok_result(
		_slot_metadata_service.build_slot_summary(slot_id, meta_result.data),
		meta_result.meta
	)


func read_slot_metadata(slot_id: String, target_metadata: SaveFlowSlotMetadata = null) -> SaveResult:
	if slot_id.is_empty():
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"slot_id cannot be empty"
		)

	var meta_result: SaveResult = read_slot_meta_for_summary(slot_id)
	if not meta_result.ok:
		return meta_result

	var metadata: SaveFlowSlotMetadata = _slot_metadata_service.apply_slot_metadata(Dictionary(meta_result.data), target_metadata)
	return _ok_result(metadata, meta_result.meta)


func list_slot_summaries() -> SaveResult:
	var index_result: SaveResult = _storage_service.read_index_data()
	if not index_result.ok:
		return index_result

	var slots_map: Dictionary = index_result.data[INDEX_SLOTS_KEY]
	var summaries: Array = []
	for slot_id_variant in slots_map.keys():
		var slot_id := String(slot_id_variant)
		var entry := Dictionary(slots_map.get(slot_id_variant, {}))
		var meta := Dictionary(entry.get("meta", {}))
		if meta.is_empty():
			var meta_result: SaveResult = read_slot_meta_for_summary(slot_id)
			if not meta_result.ok:
				continue
			meta = meta_result.data
		summaries.append(_slot_metadata_service.build_slot_summary(slot_id, meta))

	summaries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("saved_at_unix", 0)) > int(b.get("saved_at_unix", 0))
	)

	return _ok_result(
		summaries,
		{
			"slot_count": summaries.size(),
		}
	)


func read_meta(slot_id: String) -> SaveResult:
	var load_result: SaveResult = load_slot(slot_id)
	if not load_result.ok:
		return load_result
	return _ok_result(load_result.data["meta"].duplicate(true), load_result.meta)


func inspect_slot_storage(slot_id: String) -> SaveResult:
	if slot_id.is_empty():
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"slot_id cannot be empty"
		)

	var locate_result: SaveResult = _storage_service.locate_slot(slot_id, false)
	var path := ""
	var format: int = _storage_service.resolve_storage_format()
	if locate_result.ok:
		path = String(locate_result.data["path"])
		format = int(locate_result.data["format"])
	else:
		path = _storage_service.build_slot_path(slot_id, format)

	var backup_path: String = _storage_service.build_backup_path(path)
	var primary_probe: Dictionary = _storage_service.probe_payload_file(path, format)
	var backup_probe: Dictionary = _storage_service.probe_payload_file(backup_path, format)
	return _ok_result(
		{
			"slot_path": path,
			"backup_path": backup_path,
			"primary_exists": bool(primary_probe.get("exists", false)),
			"primary_valid_payload": bool(primary_probe.get("valid_payload", false)),
			"primary_probe_error": String(primary_probe.get("error_key", "")),
			"backup_exists": bool(backup_probe.get("exists", false)),
			"backup_valid_payload": bool(backup_probe.get("valid_payload", false)),
			"backup_probe_error": String(backup_probe.get("error_key", "")),
			"recovery_possible": not bool(primary_probe.get("valid_payload", false)) and bool(backup_probe.get("valid_payload", false)),
		},
		{
			"slot_id": slot_id,
			"path": path,
			"format": format,
		}
	)


func write_meta(slot_id: String, meta_patch: Dictionary) -> SaveResult:
	var load_result: SaveResult = load_slot(slot_id)
	if not load_result.ok:
		return load_result

	var payload: Dictionary = load_result.data.duplicate(true)
	var meta: Dictionary = payload["meta"]
	for key in meta_patch.keys():
		meta[key] = meta_patch[key]
	payload["meta"] = meta

	var format: int = int(load_result.meta.get("format", _storage_service.resolve_storage_format()))
	return save_payload(slot_id, payload, format)


func inspect_slot_compatibility(slot_id: String) -> SaveResult:
	var locate_result: SaveResult = _storage_service.locate_slot(slot_id)
	if not locate_result.ok:
		return locate_result

	var path: String = String(locate_result.data["path"])
	var format: int = int(locate_result.data["format"])
	var read_result: SaveResult = _storage_service.read_payload_file(path, format)
	if not read_result.ok:
		return read_result
	if not _storage_service.is_valid_payload(read_result.data):
		return _error_result(
			SaveError.INVALID_FORMAT,
			"INVALID_FORMAT",
			"save payload must contain meta and data",
			{"slot_id": slot_id, "path": path}
		)

	var payload: Dictionary = read_result.data
	var compatibility_report: Dictionary = _slot_metadata_service.build_compatibility_report(Dictionary(payload.get("meta", {})))
	return _ok_result(
		compatibility_report,
		{
			"slot_id": slot_id,
			"path": path,
			"format": format,
		}
	)


func validate_slot(slot_id: String) -> SaveResult:
	var load_result: SaveResult = load_slot(slot_id)
	if not load_result.ok:
		return load_result
	return _ok_result(
		{
			"slot_id": slot_id,
			"valid": true,
			"format": load_result.meta.get("format", _storage_service.resolve_storage_format()),
			"path": load_result.meta.get("path", "")
		},
		load_result.meta
	)


func get_slot_path(slot_id: String) -> SaveResult:
	if slot_id.is_empty():
		return _error_result(
			SaveError.INVALID_ARGUMENT,
			"INVALID_ARGUMENT",
			"slot_id cannot be empty"
		)

	var locate_result: SaveResult = _storage_service.locate_slot(slot_id)
	if locate_result.ok:
		return _ok_result(String(locate_result.data["path"]), locate_result.meta)

	var path: String = _storage_service.build_slot_path(slot_id, _storage_service.resolve_storage_format())
	return _ok_result(path, {"slot_id": slot_id, "resolved": false})


func get_index_path() -> String:
	return _storage_service.get_index_path()


func _validate_record_kind_conflict(slot_id: String, record_key: String, new_kind: String) -> SaveResult:
	if not _uses_strict_record_conflicts():
		return _ok_result()

	var locate_result: SaveResult = _storage_service.locate_record(slot_id, record_key, false)
	if not locate_result.ok:
		return _ok_result()

	var existing_kind := _resolve_existing_record_kind(locate_result)
	if existing_kind.is_empty() or existing_kind == new_kind:
		return _ok_result()

	return _error_result(
		SaveError.INVALID_ARGUMENT,
		"RECORD_CONFLICT",
		"record key `%s` is already used for `%s` data and cannot be overwritten as `%s`" % [
			record_key,
			existing_kind,
			new_kind,
		],
		{
			"slot_id": slot_id,
			"record_key": record_key,
			"existing_record_kind": existing_kind,
			"new_record_kind": new_kind,
		}
	)


func _resolve_existing_record_kind(locate_result: SaveResult) -> String:
	var locate_data := Dictionary(locate_result.data)
	var entry := Dictionary(locate_data.get("entry", {}))
	var top_level_kind := String(entry.get("record_kind", "")).strip_edges()
	if not top_level_kind.is_empty():
		return top_level_kind

	var entry_meta := Dictionary(entry.get("meta", {}))
	var entry_kind := String(entry_meta.get("record_kind", "")).strip_edges()
	if not entry_kind.is_empty():
		return entry_kind

	var path := String(locate_data.get("path", ""))
	if path.is_empty():
		return ""
	var format := int(locate_data.get("format", _storage_service.resolve_storage_format()))
	var read_result: SaveResult = _storage_service.read_payload_file(path, format)
	if not read_result.ok or not _storage_service.is_valid_payload(read_result.data):
		return ""

	var payload := Dictionary(read_result.data)
	var payload_meta := Dictionary(payload.get("meta", {}))
	return String(payload_meta.get("record_kind", "")).strip_edges()


func _uses_strict_record_conflicts() -> bool:
	return Engine.is_editor_hint() or OS.has_feature("debug") or OS.has_feature("editor")


func save_payload(slot_id: String, payload: Dictionary, format: int) -> SaveResult:
	return _storage_service.save_payload(slot_id, payload, format)


func read_slot_meta_for_summary(slot_id: String) -> SaveResult:
	var index_result: SaveResult = _storage_service.read_index_data()
	if index_result.ok:
		var slots_map: Dictionary = index_result.data[INDEX_SLOTS_KEY]
		if slots_map.has(slot_id):
			var entry := Dictionary(slots_map[slot_id])
			var indexed_meta := Dictionary(entry.get("meta", {}))
			if not indexed_meta.is_empty():
				return _ok_result(
					indexed_meta.duplicate(true),
					{
						"slot_id": slot_id,
						"from_index": true,
					}
				)

	var locate_result: SaveResult = _storage_service.locate_slot(slot_id)
	if not locate_result.ok:
		return locate_result

	var path: String = String(locate_result.data["path"])
	var format: int = int(locate_result.data["format"])
	var read_result: SaveResult = _storage_service.read_payload_file(path, format)
	if not read_result.ok:
		return read_result
	if not _storage_service.is_valid_payload(read_result.data):
		return _error_result(
			SaveError.INVALID_FORMAT,
			"INVALID_FORMAT",
			"save payload must contain meta and data",
			{"slot_id": slot_id, "path": path}
		)

	return _ok_result(
		Dictionary(read_result.data.get("meta", {})).duplicate(true),
		{
			"slot_id": slot_id,
			"path": path,
			"format": format,
			"from_index": false,
		}
	)


func _ok_result(data: Variant = null, meta: Dictionary = {}) -> SaveResult:
	var result := SaveResult.new()
	result.ok = true
	result.error_code = SaveError.OK
	result.error_key = "OK"
	result.data = data
	result.meta = meta
	return result


func _error_result(error_code: int, error_key: String, error_message: String, meta: Dictionary = {}) -> SaveResult:
	var result := SaveResult.new()
	result.ok = false
	result.error_code = error_code
	result.error_key = error_key
	result.error_message = error_message
	result.meta = meta
	return result
