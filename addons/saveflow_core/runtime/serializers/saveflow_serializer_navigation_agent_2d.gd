class_name SaveFlowSerializerNavigationAgent2D
extends SaveFlowBuiltInSerializer


const _PROPERTY_NAMES: PackedStringArray = [
	"navigation_layers",
	"path_desired_distance",
	"target_desired_distance",
	"path_max_distance",
	"path_postprocessing",
	"avoidance_enabled",
	"neighbor_distance",
	"max_neighbors",
	"time_horizon_agents",
	"time_horizon_obstacles",
	"max_speed",
	"radius",
	"target_position",
	"velocity",
]


func get_serializer_id() -> String:
	return "navigation_agent_2d"


func get_display_name() -> String:
	return "NavigationAgent2D"


func supports_node(node: Node) -> bool:
	return node is NavigationAgent2D


func gather_from_node(node: Node) -> Variant:
	var target := node as NavigationAgent2D
	if target == null:
		return {}
	var payload: Dictionary = {}
	for property_name in _PROPERTY_NAMES:
		if _has_property(target, property_name):
			payload[property_name] = target.get(property_name)
	return payload


func apply_to_node(node: Node, data: Variant) -> void:
	if not (data is Dictionary):
		return
	var target := node as NavigationAgent2D
	if target == null:
		return
	var payload: Dictionary = data
	for property_name in _PROPERTY_NAMES:
		if not payload.has(property_name):
			continue
		if not _has_property(target, property_name):
			continue
		target.set(property_name, payload[property_name])


static func _has_property(target: Object, property_name: String) -> bool:
	for property_info_variant in target.get_property_list():
		if not (property_info_variant is Dictionary):
			continue
		var property_info: Dictionary = property_info_variant
		if String(property_info.get("name", "")) == property_name:
			return true
	return false


func describe_fields(node: Node) -> Array:
	var agent := node as NavigationAgent2D
	if agent == null:
		return []
	var descriptors: Array = []
	for property_name in _PROPERTY_NAMES:
		if not _has_property(agent, property_name):
			continue
		descriptors.append(
			{
				"id": property_name,
				"display_name": property_name.replace("_", " ").capitalize(),
			}
		)
	return descriptors


func recommended_field_ids(node: Node) -> PackedStringArray:
	var agent := node as NavigationAgent2D
	if agent == null:
		return PackedStringArray()
	var recommended := PackedStringArray()
	if _has_property(agent, "target_position"):
		recommended.append("target_position")
	if _has_property(agent, "max_speed"):
		recommended.append("max_speed")
	return recommended
