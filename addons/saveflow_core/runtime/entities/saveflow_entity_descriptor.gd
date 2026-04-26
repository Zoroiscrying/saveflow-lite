## Typed helper for one runtime-entity save descriptor.
## SaveFlow still stores descriptors as dictionaries on disk, but custom
## factories should read them through this helper instead of string keys.
@tool
class_name SaveFlowEntityDescriptor
extends RefCounted

const PERSISTENT_ID_KEY := "persistent_id"
const TYPE_KEY_KEY := "type_key"
const PAYLOAD_KEY := "payload"
const BUILT_IN_KEYS := [
	PERSISTENT_ID_KEY,
	TYPE_KEY_KEY,
	PAYLOAD_KEY,
]

var persistent_id := ""
var type_key := ""
var payload: Variant = {}
var extra: Dictionary = {}


static func from_values(
	next_persistent_id: String,
	next_type_key: String,
	next_payload: Variant = {},
	next_extra: Dictionary = {}
) -> SaveFlowEntityDescriptor:
	var descriptor := SaveFlowEntityDescriptor.new()
	descriptor.persistent_id = next_persistent_id.strip_edges()
	descriptor.type_key = next_type_key.strip_edges()
	descriptor.payload = _copy_value(next_payload)
	descriptor.extra = next_extra.duplicate(true)
	return descriptor


static func from_variant(value: Variant) -> SaveFlowEntityDescriptor:
	if value is SaveFlowEntityDescriptor:
		return (value as SaveFlowEntityDescriptor).copy()
	if value is Dictionary:
		return from_dictionary(value)
	return SaveFlowEntityDescriptor.new()


static func from_dictionary(data: Dictionary) -> SaveFlowEntityDescriptor:
	var descriptor := SaveFlowEntityDescriptor.new()
	descriptor.apply_dictionary(data)
	return descriptor


func apply_dictionary(data: Dictionary) -> void:
	persistent_id = String(data.get(PERSISTENT_ID_KEY, persistent_id)).strip_edges()
	type_key = String(data.get(TYPE_KEY_KEY, type_key)).strip_edges()
	payload = _copy_value(data.get(PAYLOAD_KEY, payload))
	extra.clear()
	for key in data.keys():
		if BUILT_IN_KEYS.has(String(key)):
			continue
		extra[key] = _copy_value(data[key])


func to_dictionary() -> Dictionary:
	var data := extra.duplicate(true)
	data[PERSISTENT_ID_KEY] = persistent_id
	data[TYPE_KEY_KEY] = type_key
	data[PAYLOAD_KEY] = _copy_value(payload)
	return data


func to_spawn_dictionary() -> Dictionary:
	return to_dictionary()


func copy() -> SaveFlowEntityDescriptor:
	return from_values(persistent_id, type_key, payload, extra)


func is_valid() -> bool:
	return not type_key.strip_edges().is_empty()


func get_validation_message() -> String:
	if type_key.strip_edges().is_empty():
		return "entity descriptor must contain type_key"
	return ""


func get_payload_dictionary(default_value: Dictionary = {}) -> Dictionary:
	if payload is Dictionary:
		return Dictionary(payload).duplicate(true)
	return default_value.duplicate(true)


func has_scope_graph_payload() -> bool:
	if not (payload is Dictionary):
		return false
	return String(Dictionary(payload).get("mode", "")) == "scope_graph"


func get_scope_path(default_value := "") -> String:
	if not (payload is Dictionary):
		return default_value
	return String(Dictionary(payload).get("scope_path", default_value))


func get_scope_graph() -> Dictionary:
	if not (payload is Dictionary):
		return {}
	var graph: Variant = Dictionary(payload).get("graph", {})
	if graph is Dictionary:
		return Dictionary(graph).duplicate(true)
	return {}


func get_extra_value(key: Variant, default_value: Variant = null) -> Variant:
	return extra.get(key, default_value)


func set_extra_value(key: Variant, value: Variant) -> void:
	extra[key] = _copy_value(value)


static func _copy_value(value: Variant) -> Variant:
	if value is Dictionary:
		return Dictionary(value).duplicate(true)
	if value is Array:
		return Array(value).duplicate(true)
	return value
