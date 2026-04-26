## Typed helper for SaveFlow's built-in slot metadata fields.
##
## Save files still store dictionaries on disk for compatibility. This resource
## gives game code a typed authoring surface for the default fields, then converts
## to a dictionary at the API boundary.
@icon("res://addons/saveflow_lite/icons/components/saveflow_slot_metadata_icon.svg")
class_name SaveFlowSlotMetadata
extends Resource

const BUSINESS_FIELD_IDS := [
	"display_name",
	"save_type",
	"chapter_name",
	"location_name",
	"playtime_seconds",
	"difficulty",
	"thumbnail_path",
]

const CORE_FIELD_IDS := [
	"slot_id",
	"created_at_unix",
	"created_at_iso",
	"saved_at_unix",
	"saved_at_iso",
	"scene_path",
	"project_title",
	"game_version",
	"data_version",
	"save_schema",
]

const MAX_RECOMMENDED_CUSTOM_METADATA_FIELDS := 12
const MAX_METADATA_WARNING_DEPTH := 12

@export var slot_id := ""
@export var display_name := ""
@export var save_type := "manual"
@export var chapter_name := ""
@export var location_name := ""
@export var playtime_seconds := 0
@export var difficulty := ""
@export var thumbnail_path := ""
@export var created_at_unix := 0
@export var created_at_iso := ""
@export var saved_at_unix := 0
@export var saved_at_iso := ""
@export var scene_path := ""
@export var project_title := ""
@export var game_version := ""
@export var data_version := 0
@export var save_schema := ""
var custom_metadata: Dictionary = {}


static func from_values(
	display_name_value: String = "",
	save_type_value: String = "manual",
	chapter_name_value: String = "",
	location_name_value: String = "",
	playtime_seconds_value: int = 0,
	difficulty_value: String = "",
	thumbnail_path_value: String = "",
	extra: Dictionary = {}
) -> SaveFlowSlotMetadata:
	var metadata := SaveFlowSlotMetadata.new()
	metadata.display_name = display_name_value
	metadata.save_type = save_type_value
	metadata.chapter_name = chapter_name_value
	metadata.location_name = location_name_value
	metadata.playtime_seconds = playtime_seconds_value
	metadata.difficulty = difficulty_value
	metadata.thumbnail_path = thumbnail_path_value
	metadata.apply_extra(extra)
	return metadata


static func from_dictionary(source: Dictionary) -> SaveFlowSlotMetadata:
	var metadata := SaveFlowSlotMetadata.new()
	metadata.apply_patch(source)
	return metadata


static func known_field_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for field_id in BUSINESS_FIELD_IDS:
		ids.append(field_id)
	for field_id in CORE_FIELD_IDS:
		ids.append(field_id)
	return ids


func apply_extra(extra: Dictionary) -> void:
	var extra_field_names := get_extra_field_names()
	for key in extra.keys():
		var field_id := String(key)
		if _is_known_field(field_id):
			set_field(field_id, extra[key])
		elif extra_field_names.has(field_id):
			set(field_id, _coerce_value(extra[key], get(field_id)))
		else:
			custom_metadata[field_id] = extra[key]


func apply_patch(meta_patch: Dictionary) -> void:
	var extra_field_names := get_extra_field_names()
	for key in meta_patch.keys():
		var field_id := String(key)
		if _is_known_field(field_id):
			set_field(field_id, meta_patch[key])
		elif extra_field_names.has(field_id):
			set(field_id, _coerce_value(meta_patch[key], get(field_id)))
		else:
			custom_metadata[field_id] = meta_patch[key]
	on_metadata_post_apply(meta_patch.duplicate(true))


func on_metadata_post_apply(_meta_patch: Dictionary) -> void:
	pass


func get_saveflow_authoring_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var custom_field_count := 0
	for key in custom_metadata.keys():
		var field_id := String(key)
		if _is_known_field(field_id):
			continue
		custom_field_count += 1
		_collect_metadata_value_warnings(custom_metadata[key], "custom_metadata.%s" % field_id, warnings)

	for field_id in get_extra_field_names():
		if _is_known_field(field_id):
			continue
		custom_field_count += 1
		_collect_metadata_value_warnings(get(field_id), field_id, warnings)

	if custom_field_count > MAX_RECOMMENDED_CUSTOM_METADATA_FIELDS:
		warnings.append(
			"SaveFlowSlotMetadata has %d custom fields. Keep metadata small for save-list UI; move full gameplay state to save payloads, SaveFlow sources, or SaveFlowTypedDataSource." % custom_field_count
		)
	return warnings


func push_saveflow_authoring_warnings() -> void:
	for warning in get_saveflow_authoring_warnings():
		push_warning(warning)


func get_extra_field_names() -> PackedStringArray:
	var names := PackedStringArray()
	for property_info_variant in get_property_list():
		if not (property_info_variant is Dictionary):
			continue
		var property_info: Dictionary = property_info_variant
		var property_name := String(property_info.get("name", ""))
		var usage := int(property_info.get("usage", 0))
		if property_name.is_empty() or _is_known_field(property_name) or _is_internal_property(property_name):
			continue
		if (usage & PROPERTY_USAGE_STORAGE) == 0:
			continue
		if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		names.append(property_name)
	return names


func set_field(field_id: String, value: Variant) -> void:
	match field_id:
		"slot_id":
			slot_id = String(value)
		"display_name":
			display_name = String(value)
		"save_type":
			save_type = String(value)
		"chapter_name":
			chapter_name = String(value)
		"location_name":
			location_name = String(value)
		"playtime_seconds":
			playtime_seconds = int(value)
		"difficulty":
			difficulty = String(value)
		"thumbnail_path":
			thumbnail_path = String(value)
		"created_at_unix":
			created_at_unix = int(value)
		"created_at_iso":
			created_at_iso = String(value)
		"saved_at_unix":
			saved_at_unix = int(value)
		"saved_at_iso":
			saved_at_iso = String(value)
		"scene_path":
			scene_path = String(value)
		"project_title":
			project_title = String(value)
		"game_version":
			game_version = String(value)
		"data_version":
			data_version = int(value)
		"save_schema":
			save_schema = String(value)


func to_dictionary() -> Dictionary:
	push_saveflow_authoring_warnings()
	var meta := {
		"slot_id": slot_id,
		"display_name": display_name,
		"save_type": save_type,
		"chapter_name": chapter_name,
		"location_name": location_name,
		"playtime_seconds": playtime_seconds,
		"difficulty": difficulty,
		"thumbnail_path": thumbnail_path,
		"created_at_unix": created_at_unix,
		"created_at_iso": created_at_iso,
		"saved_at_unix": saved_at_unix,
		"saved_at_iso": saved_at_iso,
		"scene_path": scene_path,
		"project_title": project_title,
		"game_version": game_version,
		"data_version": data_version,
		"save_schema": save_schema,
	}
	for key in custom_metadata.keys():
		var field_id := String(key)
		if not _is_known_field(field_id):
			meta[field_id] = custom_metadata[key]
	_add_extra_fields(meta)
	return meta


func to_patch_dictionary() -> Dictionary:
	push_saveflow_authoring_warnings()
	var meta := {
		"display_name": display_name,
		"save_type": save_type,
		"chapter_name": chapter_name,
		"location_name": location_name,
		"playtime_seconds": playtime_seconds,
		"difficulty": difficulty,
		"thumbnail_path": thumbnail_path,
	}
	_add_if_not_empty(meta, "slot_id", slot_id)
	_add_if_not_zero(meta, "created_at_unix", created_at_unix)
	_add_if_not_empty(meta, "created_at_iso", created_at_iso)
	_add_if_not_zero(meta, "saved_at_unix", saved_at_unix)
	_add_if_not_empty(meta, "saved_at_iso", saved_at_iso)
	_add_if_not_empty(meta, "scene_path", scene_path)
	_add_if_not_empty(meta, "project_title", project_title)
	_add_if_not_empty(meta, "game_version", game_version)
	_add_if_not_zero(meta, "data_version", data_version)
	_add_if_not_empty(meta, "save_schema", save_schema)
	for key in custom_metadata.keys():
		var field_id := String(key)
		if not _is_known_field(field_id):
			meta[field_id] = custom_metadata[key]
	_add_extra_fields(meta)
	return meta


static func _is_known_field(field_id: String) -> bool:
	return BUSINESS_FIELD_IDS.has(field_id) or CORE_FIELD_IDS.has(field_id)


static func _add_if_not_empty(target: Dictionary, field_id: String, value: String) -> void:
	if not value.is_empty():
		target[field_id] = value


static func _add_if_not_zero(target: Dictionary, field_id: String, value: int) -> void:
	if value != 0:
		target[field_id] = value


func _add_extra_fields(target: Dictionary) -> void:
	for field_id in get_extra_field_names():
		if not _is_known_field(field_id):
			target[field_id] = _encode_value(get(field_id))


func _encode_value(value: Variant) -> Variant:
	if value is SaveFlowTypedData:
		return {
			"__saveflow_typed_data": true,
			"data": (value as SaveFlowTypedData).to_saveflow_payload(),
		}
	if value is Array:
		var encoded_array: Array = []
		for item in value:
			encoded_array.append(_encode_value(item))
		return encoded_array
	if value is Dictionary:
		var encoded_dictionary: Dictionary = {}
		for key in value.keys():
			encoded_dictionary[key] = _encode_value(value[key])
		return encoded_dictionary
	return value


func _coerce_value(value: Variant, current_value: Variant) -> Variant:
	if current_value is SaveFlowTypedData and value is Dictionary:
		var typed_data := current_value as SaveFlowTypedData
		var payload: Dictionary = value
		if bool(payload.get("__saveflow_typed_data", false)) and payload.get("data") is Dictionary:
			payload = payload["data"]
		typed_data.apply_saveflow_payload(payload)
		return typed_data

	if current_value is PackedStringArray and value is Array:
		return PackedStringArray(value)
	if current_value is PackedInt32Array and value is Array:
		return PackedInt32Array(value)
	if current_value is PackedInt64Array and value is Array:
		return PackedInt64Array(value)
	if current_value is PackedFloat32Array and value is Array:
		return PackedFloat32Array(value)
	if current_value is PackedFloat64Array and value is Array:
		return PackedFloat64Array(value)
	if current_value is PackedByteArray and value is Array:
		return PackedByteArray(value)
	if current_value is PackedVector2Array and value is Array:
		return PackedVector2Array(value)
	if current_value is PackedVector3Array and value is Array:
		return PackedVector3Array(value)
	if current_value is PackedColorArray and value is Array:
		return PackedColorArray(value)
	return value


func _collect_metadata_value_warnings(
	value: Variant,
	value_path: String,
	warnings: PackedStringArray,
	depth: int = 0
) -> void:
	if depth > MAX_METADATA_WARNING_DEPTH:
		warnings.append(
			"SaveFlowSlotMetadata field '%s' is deeply nested. Keep metadata shallow for save-list UI and move complex state into the save payload." % value_path
		)
		return

	if value == null or _is_basic_metadata_value(value):
		return

	if value is SaveFlowTypedData:
		_collect_metadata_value_warnings(
			(value as SaveFlowTypedData).to_saveflow_payload(),
			"%s(SaveFlowTypedData)" % value_path,
			warnings,
			depth + 1
		)
		return

	if value is Array:
		var array_value: Array = value
		for index in range(array_value.size()):
			_collect_metadata_value_warnings(
				array_value[index],
				"%s[%d]" % [value_path, index],
				warnings,
				depth + 1
			)
		return

	if value is Dictionary:
		var dictionary_value: Dictionary = value
		for key in dictionary_value.keys():
			if not _is_basic_metadata_value(key):
				warnings.append(
					"SaveFlowSlotMetadata field '%s' uses a non-basic Dictionary key of type %s. Metadata dictionaries should use basic keys and values." % [
						value_path,
						_describe_value_type(key),
					]
				)
			_collect_metadata_value_warnings(
				dictionary_value[key],
				"%s.%s" % [value_path, String(key)],
				warnings,
				depth + 1
			)
		return

	warnings.append(
		"SaveFlowSlotMetadata field '%s' stores %s. Metadata should stay small: use basic values, basic Array/Dictionary values, or SaveFlowTypedData; move gameplay state to save payloads or SaveFlow sources." % [
			value_path,
			_describe_value_type(value),
		]
	)


static func _is_basic_metadata_value(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH:
			return true
		TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY:
			return true
		TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY:
			return true
		_:
			return false


static func _describe_value_type(value: Variant) -> String:
	if value is Object:
		var object := value as Object
		return object.get_class()
	return type_string(typeof(value))


static func _is_internal_property(property_name: String) -> bool:
	return [
		"script",
		"resource_local_to_scene",
		"resource_path",
		"resource_name",
		"resource_scene_unique_id",
		"custom_metadata",
	].has(property_name)
