extends RefCounted

const SaveFlowSlotMetadataScript := preload("res://addons/saveflow_core/runtime/types/saveflow_slot_metadata.gd")

var _settings: SaveSettings = SaveSettings.new()


func configure(settings: SaveSettings) -> void:
	_settings = settings if settings != null else SaveSettings.new()


func build_slot_metadata_patch(
	meta_patch_or_display_name: Variant = {},
	save_type: String = "manual",
	chapter_name: String = "",
	location_name: String = "",
	playtime_seconds: int = 0,
	difficulty: String = "",
	thumbnail_path: String = "",
	extra: Dictionary = {}
) -> Dictionary:
	if meta_patch_or_display_name is SaveFlowSlotMetadata:
		return (meta_patch_or_display_name as SaveFlowSlotMetadata).to_patch_dictionary()
	if meta_patch_or_display_name is Dictionary:
		var metadata := SaveFlowSlotMetadataScript.from_dictionary(meta_patch_or_display_name)
		return metadata.to_patch_dictionary()
	return build_slot_metadata(
		String(meta_patch_or_display_name),
		save_type,
		chapter_name,
		location_name,
		playtime_seconds,
		difficulty,
		thumbnail_path,
		extra
	).to_patch_dictionary()


func build_slot_metadata(
	display_name: String = "",
	save_type: String = "manual",
	chapter_name: String = "",
	location_name: String = "",
	playtime_seconds: int = 0,
	difficulty: String = "",
	thumbnail_path: String = "",
	extra: Dictionary = {}
) -> SaveFlowSlotMetadata:
	return SaveFlowSlotMetadataScript.from_values(
		display_name,
		save_type,
		chapter_name,
		location_name,
		playtime_seconds,
		difficulty,
		thumbnail_path,
		extra
	)


func resolve_slot_meta_patch(
	meta_or_display_name: Variant = {},
	save_type: String = "manual",
	chapter_name: String = "",
	location_name: String = "",
	playtime_seconds: int = 0,
	difficulty: String = "",
	thumbnail_path: String = "",
	extra_meta: Dictionary = {}
) -> Dictionary:
	var meta_patch := build_slot_metadata_patch(
		meta_or_display_name,
		save_type,
		chapter_name,
		location_name,
		playtime_seconds,
		difficulty,
		thumbnail_path,
		extra_meta
	)
	return meta_patch.duplicate(true)


func build_meta(slot_id: String, meta_patch: Dictionary = {}) -> Dictionary:
	var metadata := SaveFlowSlotMetadataScript.from_dictionary(build_slot_metadata_patch(meta_patch))
	metadata.slot_id = slot_id
	var now_unix := int(Time.get_unix_time_from_system())
	var now_iso := Time.get_datetime_string_from_system(true, true)
	if metadata.created_at_unix == 0:
		metadata.created_at_unix = now_unix
	if metadata.created_at_iso.is_empty():
		metadata.created_at_iso = now_iso
	metadata.saved_at_unix = now_unix
	metadata.saved_at_iso = now_iso
	if metadata.display_name.is_empty():
		metadata.display_name = slot_id
	if metadata.project_title.is_empty():
		metadata.project_title = _settings.project_title
	if metadata.game_version.is_empty():
		metadata.game_version = _settings.game_version
	if metadata.data_version == 0:
		metadata.data_version = _settings.data_version
	if metadata.save_schema.is_empty():
		metadata.save_schema = _settings.save_schema
	return metadata.to_dictionary()


func apply_slot_metadata(slot_meta: Dictionary, target_metadata: SaveFlowSlotMetadata = null) -> SaveFlowSlotMetadata:
	var metadata: SaveFlowSlotMetadata = target_metadata if target_metadata != null else SaveFlowSlotMetadataScript.new()
	metadata.apply_patch(slot_meta)
	return metadata


func build_slot_summary(slot_id: String, slot_meta: Dictionary) -> Dictionary:
	var metadata := SaveFlowSlotMetadataScript.from_dictionary(slot_meta)

	return {
		"slot_id": metadata.slot_id if not metadata.slot_id.is_empty() else slot_id,
		"display_name": metadata.display_name if not metadata.display_name.is_empty() else slot_id,
		"save_type": metadata.save_type,
		"chapter_name": metadata.chapter_name,
		"location_name": metadata.location_name,
		"playtime_seconds": metadata.playtime_seconds,
		"difficulty": metadata.difficulty,
		"thumbnail_path": metadata.thumbnail_path,
		"created_at_unix": metadata.created_at_unix,
		"created_at_iso": metadata.created_at_iso,
		"saved_at_unix": metadata.saved_at_unix,
		"saved_at_iso": metadata.saved_at_iso,
		"scene_path": metadata.scene_path,
		"project_title": metadata.project_title,
		"game_version": metadata.game_version,
		"data_version": metadata.data_version,
		"save_schema": metadata.save_schema,
		"compatibility_report": build_compatibility_report(slot_meta),
		"custom_metadata": metadata.custom_metadata.duplicate(true),
	}


func build_compatibility_report(slot_meta: Dictionary) -> Dictionary:
	var report := {
		"slot_game_version": String(slot_meta.get("game_version", "")),
		"project_game_version": _settings.game_version,
		"slot_data_version": int(slot_meta.get("data_version", 0)),
		"project_data_version": _settings.data_version,
		"slot_save_schema": String(slot_meta.get("save_schema", "")),
		"project_save_schema": _settings.save_schema,
		"schema_matches": true,
		"data_version_matches": true,
		"game_version_matches": true,
		"compatible": true,
		"reasons": PackedStringArray(),
	}

	var reasons: PackedStringArray = report["reasons"]
	var slot_schema := String(report["slot_save_schema"])
	var project_schema := String(report["project_save_schema"])
	var schema_mismatch := not slot_schema.is_empty() and not project_schema.is_empty() and slot_schema != project_schema
	report["schema_matches"] = not schema_mismatch
	if schema_mismatch and _settings.enforce_save_schema_match:
		report["schema_matches"] = false
		report["compatible"] = false
		reasons.append("SAVE_SCHEMA_MISMATCH")

	var slot_data_version := int(report["slot_data_version"])
	var project_data_version := int(report["project_data_version"])
	var data_version_mismatch := slot_data_version > 0 and project_data_version > 0 and slot_data_version != project_data_version
	report["data_version_matches"] = not data_version_mismatch
	if data_version_mismatch and _settings.enforce_data_version_match:
		report["data_version_matches"] = false
		report["compatible"] = false
		reasons.append("DATA_VERSION_MISMATCH")

	var slot_game_version := String(report["slot_game_version"])
	var project_game_version := String(report["project_game_version"])
	if not slot_game_version.is_empty() and not project_game_version.is_empty() and slot_game_version != project_game_version:
		report["game_version_matches"] = false
		reasons.append("GAME_VERSION_DIFFERS")

	report["reasons"] = reasons
	return report


func build_compatibility_error_message(report: Dictionary) -> String:
	var reasons := PackedStringArray(report.get("reasons", PackedStringArray()))
	if reasons.has("SAVE_SCHEMA_MISMATCH"):
		return "slot save_schema does not match the current project schema; migration is required before load"
	if reasons.has("DATA_VERSION_MISMATCH"):
		return "slot data_version does not match the current project data version; migration is required before load"
	return "slot metadata is not compatible with the current SaveFlow project settings"
