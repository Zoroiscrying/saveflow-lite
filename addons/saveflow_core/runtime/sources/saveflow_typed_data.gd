## SaveFlowTypedData is a typed business-data container for data-source payloads.
## Define exported fields here, let SaveFlow convert them to a stable Dictionary.
@icon("res://addons/saveflow_lite/icons/components/saveflow_typed_data_icon.svg")
@tool
class_name SaveFlowTypedData
extends Resource


func to_saveflow_payload() -> Dictionary:
	var payload: Dictionary = {}
	for property_name in get_saveflow_property_names():
		payload[property_name] = _encode_value(get(property_name))
	return payload


func apply_saveflow_payload(payload: Dictionary) -> void:
	for property_name in get_saveflow_property_names():
		if not payload.has(property_name):
			continue
		set(property_name, _coerce_value(payload[property_name], get(property_name)))
	on_saveflow_post_apply(payload.duplicate(true))


func on_saveflow_post_apply(_payload: Dictionary) -> void:
	pass


func get_saveflow_property_names() -> PackedStringArray:
	var names: PackedStringArray = []
	for property_info_variant in get_property_list():
		if not (property_info_variant is Dictionary):
			continue
		var property_info: Dictionary = property_info_variant
		var property_name := String(property_info.get("name", ""))
		var usage := int(property_info.get("usage", 0))
		if property_name.is_empty() or _is_internal_property(property_name):
			continue
		if (usage & PROPERTY_USAGE_STORAGE) == 0:
			continue
		if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		names.append(property_name)
	return names


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


func _is_internal_property(property_name: String) -> bool:
	return [
		"script",
		"resource_local_to_scene",
		"resource_path",
		"resource_name",
		"resource_scene_unique_id",
	].has(property_name)
