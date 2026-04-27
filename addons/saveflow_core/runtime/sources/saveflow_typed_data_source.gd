## SaveFlowTypedDataSource saves one typed payload-provider object.
## The on-disk payload remains a Variant/Dictionary, but gameplay code edits
## typed fields or model state instead of string-key dictionaries.
@icon("res://addons/saveflow_lite/icons/components/saveflow_typed_data_source_icon.svg")
@tool
class_name SaveFlowTypedDataSource
extends SaveFlowDataSource

const _ENCODED_GATHER_METHODS := ["to_saveflow_encoded_payload", "ToSaveFlowEncodedPayload"]
const _ENCODED_APPLY_METHODS := ["apply_saveflow_encoded_payload", "ApplySaveFlowEncodedPayload"]
const _GATHER_METHODS := ["to_saveflow_payload", "ToSaveFlowPayload"]
const _APPLY_METHODS := ["apply_saveflow_payload", "ApplySaveFlowPayload"]
const _FIELD_METHODS := ["get_saveflow_property_names", "GetSaveFlowPropertyNames"]
const _INFO_METHODS := ["get_saveflow_payload_info", "GetSaveFlowPayloadInfo"]

@export var data: Resource:
	set(value):
		data = value
		_refresh_editor_warnings()
@export var target: Node:
	set(value):
		target = value
		_refresh_editor_warnings()
@export var data_property := "":
	set(value):
		data_property = value
		_refresh_editor_warnings()
@export_storage var _target_ref_path: NodePath = NodePath()


func _ready() -> void:
	_hydrate_target_from_ref_path()
	super._ready()


func gather_data() -> Dictionary:
	var provider := _resolve_payload_provider()
	if provider == null:
		return {}
	if not _can_call_payload_provider(provider):
		return {}
	var gather_method := _resolve_gather_method(provider)
	if gather_method.is_empty():
		return {}
	var payload: Variant = provider.call(gather_method)
	if not (payload is Dictionary):
		return {}
	return Dictionary(payload).duplicate(true)


func apply_data(payload: Dictionary) -> void:
	var provider := _resolve_payload_provider()
	if provider == null:
		return
	if not _can_call_payload_provider(provider):
		return
	var apply_method := _resolve_apply_method(provider)
	if apply_method.is_empty():
		return
	provider.call(apply_method, payload.duplicate(true))


func describe_data_plan() -> Dictionary:
	var resolved_target := _resolve_target_node()
	var provider := _resolve_payload_provider()
	var field_names := _describe_payload_field_names(provider)
	var payload_info := _describe_payload_info(provider)
	return {
		"valid": provider != null,
		"reason": "" if provider != null else _resolve_invalid_reason(resolved_target),
		"source_key": get_source_key(),
		"data_version": data_version,
		"phase": get_phase(),
		"enabled": is_source_enabled(),
		"save_enabled": can_save_source(),
		"load_enabled": can_load_source(),
		"summary": "Typed data: %s" % (_describe_provider_type(provider) if provider != null else "<none>"),
		"sections": field_names,
		"details": {
			"target": String(resolved_target.name) if resolved_target != null else "<none>",
			"target_path": str(_target_ref_path),
			"data_property": data_property,
			"provider_method_calls_available": _can_call_payload_provider(provider),
			"editor_method_hint": _resolve_editor_method_hint(provider),
			"field_count": field_names.size(),
			"fields": field_names,
			"payload_info": payload_info,
			"contract": "ToSaveFlowEncodedPayload/ApplySaveFlowEncodedPayload, to_saveflow_payload/apply_saveflow_payload, or PascalCase equivalents",
		},
	}


func _resolve_payload_provider() -> Object:
	if _has_payload_contract(data):
		return data
	var resolved_target := _resolve_target_node()
	if resolved_target == null:
		return null
	if data_property.strip_edges().is_empty():
		return resolved_target if _has_payload_contract(resolved_target) else null
	var value: Variant = resolved_target.get(data_property)
	if _has_payload_contract(value):
		return value
	return null


func _resolve_target_node() -> Node:
	if is_instance_valid(target):
		if _target_ref_path.is_empty():
			_target_ref_path = _resolve_relative_node_path(target)
		return target
	if _target_ref_path.is_empty():
		return null
	var resolved := get_node_or_null(_target_ref_path)
	if is_instance_valid(resolved):
		return resolved
	return null


func _hydrate_target_from_ref_path() -> void:
	var resolved := _resolve_target_node()
	if is_instance_valid(resolved) and target == null:
		target = resolved


func _resolve_relative_node_path(node: Node) -> NodePath:
	if node == null:
		return NodePath()
	if not is_inside_tree() or not node.is_inside_tree():
		return NodePath()
	return get_path_to(node)


func _resolve_invalid_reason(resolved_target: Node) -> String:
	if data != null:
		return "DATA_MISSING_PAYLOAD_CONTRACT"
	if resolved_target == null:
		return "TARGET_NOT_FOUND"
	if data_property.strip_edges().is_empty():
		return "TARGET_MISSING_PAYLOAD_CONTRACT"
	return "DATA_PROPERTY_MISSING_PAYLOAD_CONTRACT"


func _has_payload_contract(value: Variant) -> bool:
	return value is Object \
		and (
			(
				not _resolve_method(value, _ENCODED_GATHER_METHODS).is_empty() \
				and not _resolve_method(value, _ENCODED_APPLY_METHODS).is_empty()
			) \
			or (
				not _resolve_method(value, _GATHER_METHODS).is_empty() \
				and not _resolve_method(value, _APPLY_METHODS).is_empty()
			)
		)


func _describe_payload_field_names(provider: Object) -> PackedStringArray:
	var field_names := PackedStringArray()
	if provider == null:
		return field_names
	if not _can_call_payload_provider(provider):
		return field_names
	var payload_info := _describe_payload_info(provider)
	if not payload_info.is_empty():
		if payload_info.has("sections") and payload_info["sections"] is Array:
			return PackedStringArray(payload_info["sections"])
		var summary_parts := PackedStringArray()
		var encoding := String(payload_info.get("encoding", ""))
		var schema := String(payload_info.get("schema", ""))
		if not encoding.is_empty():
			summary_parts.append("encoding:%s" % encoding)
		if not schema.is_empty():
			summary_parts.append("schema:%s" % schema)
		if not summary_parts.is_empty():
			return summary_parts
	var field_method := _resolve_method(provider, _FIELD_METHODS)
	if not field_method.is_empty():
		var names: Variant = provider.call(field_method)
		if names is PackedStringArray:
			return names
		if names is Array:
			return PackedStringArray(names)
	var gather_method := _resolve_method(provider, _GATHER_METHODS)
	if gather_method.is_empty():
		return field_names
	var payload: Variant = provider.call(gather_method)
	if not (payload is Dictionary):
		return field_names
	for key in Dictionary(payload).keys():
		field_names.append(String(key))
	return field_names


func _describe_payload_info(provider: Object) -> Dictionary:
	if provider == null:
		return {}
	if not _can_call_payload_provider(provider):
		return {}
	var info_method := _resolve_method(provider, _INFO_METHODS)
	if info_method.is_empty():
		return {}
	var info: Variant = provider.call(info_method)
	if info is Dictionary:
		return Dictionary(info).duplicate(true)
	return {}


func _resolve_gather_method(provider: Object) -> String:
	var encoded_method := _resolve_method(provider, _ENCODED_GATHER_METHODS)
	if not encoded_method.is_empty():
		return encoded_method
	return _resolve_method(provider, _GATHER_METHODS)


func _resolve_apply_method(provider: Object) -> String:
	var encoded_method := _resolve_method(provider, _ENCODED_APPLY_METHODS)
	if not encoded_method.is_empty():
		return encoded_method
	return _resolve_method(provider, _APPLY_METHODS)


func _describe_provider_type(provider: Object) -> String:
	var script_resource: Script = provider.get_script()
	if script_resource != null and script_resource.resource_path != "":
		return script_resource.resource_path.get_file().get_basename()
	return provider.get_class()


func _can_call_payload_provider(provider: Object) -> bool:
	if provider == null:
		return false
	if not Engine.is_editor_hint():
		return true
	var script_resource: Script = provider.get_script()
	if script_resource == null:
		return true
	return script_resource.is_tool()


func _resolve_editor_method_hint(provider: Object) -> String:
	if provider == null:
		return ""
	if not Engine.is_editor_hint():
		return ""
	var script_resource: Script = provider.get_script()
	if script_resource == null or script_resource.is_tool():
		return ""
	return "Provider script is not tool-enabled, so SaveFlow only checks its contract in the editor and waits until runtime to call payload methods."


func _resolve_method(value: Variant, method_names: Array) -> String:
	if not (value is Object):
		return ""
	var object := value as Object
	for method_name_variant in method_names:
		var method_name := String(method_name_variant)
		if object.has_method(method_name):
			return method_name
	return ""
