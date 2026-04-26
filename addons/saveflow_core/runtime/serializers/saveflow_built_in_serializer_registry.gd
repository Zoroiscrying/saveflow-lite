class_name SaveFlowBuiltInSerializerRegistry
extends RefCounted

const _SERIALIZER_AREA_3D := preload("res://addons/saveflow_core/runtime/serializers/saveflow_serializer_area_3d.gd")
const _SERIALIZER_NAVIGATION_AGENT_3D := preload(
	"res://addons/saveflow_core/runtime/serializers/saveflow_serializer_navigation_agent_3d.gd"
)
const _SERIALIZER_RAY_CAST_2D := preload(
	"res://addons/saveflow_core/runtime/serializers/saveflow_serializer_ray_cast_2d.gd"
)
const _SERIALIZER_RAY_CAST_3D := preload(
	"res://addons/saveflow_core/runtime/serializers/saveflow_serializer_ray_cast_3d.gd"
)

static var _serializer_cache: Array = []
static var _display_name_cache: Dictionary = {}


static func all_serializers() -> Array:
	return _serializer_instances().duplicate()


static func _serializer_types() -> Array:
	return [
		SaveFlowSerializerNode2D,
		SaveFlowSerializerNode3D,
		SaveFlowSerializerControl,
		SaveFlowSerializerBaseButton,
		SaveFlowSerializerRange,
		SaveFlowSerializerOptionButton,
		SaveFlowSerializerLineEdit,
		SaveFlowSerializerTextEdit,
		SaveFlowSerializerAnimationPlayer,
		SaveFlowSerializerTimer,
		SaveFlowSerializerAudioStreamPlayer,
		SaveFlowSerializerAudioStreamPlayer2D,
		SaveFlowSerializerAudioStreamPlayer3D,
		SaveFlowSerializerPathFollow2D,
		SaveFlowSerializerPathFollow3D,
		SaveFlowSerializerCamera2D,
		SaveFlowSerializerCamera3D,
		SaveFlowSerializerSprite2D,
		SaveFlowSerializerAnimatedSprite2D,
		SaveFlowSerializerCharacterBody2D,
		SaveFlowSerializerCharacterBody3D,
		SaveFlowSerializerRigidBody2D,
		SaveFlowSerializerRigidBody3D,
		SaveFlowSerializerCollisionObject2D,
		SaveFlowSerializerCollisionObject3D,
		SaveFlowSerializerCollisionShape2D,
		SaveFlowSerializerCollisionShape3D,
		_SERIALIZER_RAY_CAST_2D,
		_SERIALIZER_RAY_CAST_3D,
		SaveFlowSerializerArea2D,
		_SERIALIZER_AREA_3D,
		SaveFlowSerializerNavigationAgent2D,
		_SERIALIZER_NAVIGATION_AGENT_3D,
		SaveFlowSerializerTileMapLayer,
		SaveFlowSerializerTileMap,
	]


static func supported_ids_for_node(node: Node) -> PackedStringArray:
	var ids: PackedStringArray = []
	for serializer_variant in _serializer_instances():
		var serializer: SaveFlowBuiltInSerializer = serializer_variant
		if serializer.supports_node(node):
			ids.append(serializer.get_serializer_id())
	return ids


static func supported_descriptors_for_node(node: Node) -> Array:
	var descriptors: Array = []
	for serializer_variant in _serializer_instances():
		var serializer: SaveFlowBuiltInSerializer = serializer_variant
		if not serializer.supports_node(node):
			continue
		descriptors.append(
			{
				"id": serializer.get_serializer_id(),
				"display_name": serializer.get_display_name(),
			}
		)
	return descriptors


static func display_name_for_id(serializer_id: String) -> String:
	return String(_display_names_by_id().get(serializer_id, serializer_id))


static func resolve_serializers_for_node(node: Node, requested_ids: PackedStringArray = PackedStringArray()) -> Array:
	var serializers: Array = []
	for serializer_variant in _serializer_instances():
		var serializer: SaveFlowBuiltInSerializer = serializer_variant
		if not serializer.supports_node(node):
			continue
		if not requested_ids.is_empty() and not requested_ids.has(serializer.get_serializer_id()):
			continue
		serializers.append(serializer)
	return serializers


static func gather_for_node(
	node: Node,
	requested_ids: PackedStringArray = PackedStringArray(),
	field_filters: Dictionary = {}
) -> Dictionary:
	var payload: Dictionary = {}
	for serializer_variant in resolve_serializers_for_node(node, requested_ids):
		var serializer: SaveFlowBuiltInSerializer = serializer_variant
		var serializer_id: String = serializer.get_serializer_id()
		var serializer_payload: Variant = serializer.gather_from_node(node)
		payload[serializer_id] = _filter_payload(serializer_payload, field_filters.get(serializer_id, null))
	return payload


static func apply_to_node(node: Node, payload: Dictionary, field_filters: Dictionary = {}) -> void:
	for serializer_variant in _serializer_instances():
		var serializer: SaveFlowBuiltInSerializer = serializer_variant
		var serializer_id: String = serializer.get_serializer_id()
		if not serializer.supports_node(node):
			continue
		if not payload.has(serializer_id):
			continue
		var serializer_payload: Variant = _filter_payload(payload[serializer_id], field_filters.get(serializer_id, null))
		serializer.apply_to_node(node, serializer_payload)


static func fields_for_node(node: Node, serializer_id: String) -> Array:
	var serializer := _resolve_serializer_for_node(node, serializer_id)
	if serializer == null:
		return []
	var descriptors: Array = serializer.describe_fields(node)
	if not descriptors.is_empty():
		return descriptors
	var gathered: Variant = serializer.gather_from_node(node)
	if not (gathered is Dictionary):
		return []
	var inferred: Array = []
	var payload: Dictionary = gathered
	for key_variant in payload.keys():
		var key: String = String(key_variant)
		inferred.append(
			{
				"id": key,
				"display_name": key.replace("_", " ").capitalize(),
			}
		)
	return inferred


static func recommended_field_ids_for_node(node: Node, serializer_id: String) -> PackedStringArray:
	var serializer := _resolve_serializer_for_node(node, serializer_id)
	if serializer == null:
		return PackedStringArray()
	return serializer.recommended_field_ids(node)


static func _resolve_serializer_for_node(node: Node, serializer_id: String) -> SaveFlowBuiltInSerializer:
	for serializer_variant in _serializer_instances():
		var serializer: SaveFlowBuiltInSerializer = serializer_variant
		if not serializer.supports_node(node):
			continue
		if serializer.get_serializer_id() != serializer_id:
			continue
		return serializer
	return null


static func _serializer_instances() -> Array:
	if _serializer_cache.is_empty():
		for serializer_type in _serializer_types():
			_serializer_cache.append(serializer_type.new())
	return _serializer_cache


static func _display_names_by_id() -> Dictionary:
	if _display_name_cache.is_empty():
		for serializer_variant in _serializer_instances():
			var serializer: SaveFlowBuiltInSerializer = serializer_variant
			_display_name_cache[serializer.get_serializer_id()] = serializer.get_display_name()
	return _display_name_cache


static func _filter_payload(payload: Variant, allowed_fields: Variant) -> Variant:
	if not (payload is Dictionary):
		return payload
	if allowed_fields == null:
		return payload
	var allowed: PackedStringArray = _to_packed_string_array(allowed_fields)
	if allowed.is_empty():
		return payload
	var source: Dictionary = payload
	var filtered: Dictionary = {}
	for field_id in allowed:
		if source.has(field_id):
			filtered[field_id] = source[field_id]
	return filtered


static func _to_packed_string_array(value: Variant) -> PackedStringArray:
	if value is PackedStringArray:
		return value
	if value is Array:
		var result: PackedStringArray = PackedStringArray()
		for entry in value:
			result.append(String(entry))
		return result
	if value is String:
		return PackedStringArray([String(value)])
	return PackedStringArray()
