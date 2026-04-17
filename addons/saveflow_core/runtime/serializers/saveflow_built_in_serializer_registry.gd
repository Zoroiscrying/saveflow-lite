class_name SaveFlowBuiltInSerializerRegistry
extends RefCounted

static func all_serializers() -> Array:
	var serializers: Array = []
	for serializer_type in _serializer_types():
		serializers.append(serializer_type.new())
	return serializers


static func _serializer_types() -> Array:
	return [
		SaveFlowSerializerNode2D,
		SaveFlowSerializerNode3D,
		SaveFlowSerializerControl,
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
	]


static func supported_ids_for_node(node: Node) -> PackedStringArray:
	var ids: PackedStringArray = []
	for serializer_variant in all_serializers():
		var serializer: SaveFlowBuiltInSerializer = serializer_variant
		if serializer.supports_node(node):
			ids.append(serializer.get_serializer_id())
	return ids


static func supported_descriptors_for_node(node: Node) -> Array:
	var descriptors: Array = []
	for serializer_variant in all_serializers():
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
	for serializer_variant in all_serializers():
		var serializer: SaveFlowBuiltInSerializer = serializer_variant
		if serializer.get_serializer_id() == serializer_id:
			return serializer.get_display_name()
	return serializer_id


static func resolve_serializers_for_node(node: Node, requested_ids: PackedStringArray = PackedStringArray()) -> Array:
	var serializers: Array = []
	for serializer_variant in all_serializers():
		var serializer: SaveFlowBuiltInSerializer = serializer_variant
		if not serializer.supports_node(node):
			continue
		if not requested_ids.is_empty() and not requested_ids.has(serializer.get_serializer_id()):
			continue
		serializers.append(serializer)
	return serializers


static func gather_for_node(node: Node, requested_ids: PackedStringArray = PackedStringArray()) -> Dictionary:
	var payload: Dictionary = {}
	for serializer_variant in resolve_serializers_for_node(node, requested_ids):
		var serializer: SaveFlowBuiltInSerializer = serializer_variant
		payload[serializer.get_serializer_id()] = serializer.gather_from_node(node)
	return payload


static func apply_to_node(node: Node, payload: Dictionary) -> void:
	for serializer_variant in all_serializers():
		var serializer: SaveFlowBuiltInSerializer = serializer_variant
		var serializer_id: String = serializer.get_serializer_id()
		if not serializer.supports_node(node):
			continue
		if not payload.has(serializer_id):
			continue
		serializer.apply_to_node(node, payload[serializer_id])
