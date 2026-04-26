## SaveFlowEntityFactory is the project-owned runtime adapter for one class of
## entities. Collection sources decide "which descriptors", factories decide
## "how to find, spawn, and hydrate those entities".
@icon("res://addons/saveflow_lite/icons/components/saveflow_entity_factory_icon.svg")
@tool
@abstract
class_name SaveFlowEntityFactory
extends Node

const SaveFlowEntityDescriptorScript := preload("res://addons/saveflow_core/runtime/entities/saveflow_entity_descriptor.gd")


func _ready() -> void:
	_refresh_editor_warnings()


## Required. Return true when this factory owns the descriptor type_key.
@abstract
func can_handle_type(type_key: String) -> bool


## Optional. Override when authored or pooled entities may already exist and
## should be reused instead of recreated during restore.
func find_existing_entity(_persistent_id: String, _context: Dictionary = {}) -> Node:
	return null


## Required. Create or materialize an entity shell for one descriptor. SaveFlow
## applies payload state after this returns. Use `resolve_entity_descriptor()`
## inside custom factories instead of reading string keys from the dictionary.
@abstract
func spawn_entity_from_save(descriptor: Dictionary, context: Dictionary = {}) -> Node


## Required. Apply the descriptor payload to an entity returned by find/spawn.
@abstract
func apply_saved_data(node: Node, payload: Variant, context: Dictionary = {}) -> void


## Optional. Called before a collection restore begins. Factories can use this
## to clear caches or prepare a target container for policies like Clear And Restore.
func prepare_restore(_restore_policy: int, _target_container: Node, _context: Dictionary = {}) -> void:
	pass


## Optional. Return supported type keys when the factory can describe them
## statically. This improves inspector readability but is not required for restore.
func get_supported_entity_types() -> PackedStringArray:
	return PackedStringArray()


## Optional. Return the runtime container this factory typically writes into.
## This is used for preview and authoring clarity, not for restore dispatch.
func get_target_container() -> Node:
	return null


## Converts the wire-format descriptor into a typed helper for factory code.
## The public restore contract stays dictionary-based for compatibility, but
## project factories should use this helper to avoid hand-managed string keys.
func resolve_entity_descriptor(descriptor: Variant) -> SaveFlowEntityDescriptor:
	return SaveFlowEntityDescriptorScript.from_variant(descriptor)


## Returns the fixed schema consumed by the entity-factory inspector preview.
## The preview uses this to explain which parts of the contract are implemented.
func describe_entity_factory_plan() -> Dictionary:
	var target_container := get_target_container()
	var implements_find_existing := _implements_method("find_existing_entity")
	var implements_spawn := _implements_method("spawn_entity_from_save")
	var implements_apply := _implements_method("apply_saved_data")
	var implements_prepare_restore := _implements_method("prepare_restore")
	var problems: PackedStringArray = PackedStringArray()
	if not implements_spawn:
		problems.append("spawn_entity_from_save is not implemented")
	if not implements_apply:
		problems.append("apply_saved_data is not implemented")
	return {
		"valid": problems.is_empty(),
		"reason": _resolve_plan_reason(problems),
		"problems": problems,
		"factory_name": name,
		"factory_path": _describe_node_path(self),
		"target_container_name": _describe_node_name(target_container),
		"target_container_path": _describe_node_path(target_container),
		"supported_entity_types": get_supported_entity_types(),
		"implements_find_existing": implements_find_existing,
		"implements_spawn": implements_spawn,
		"implements_apply": implements_apply,
		"implements_prepare_restore": implements_prepare_restore,
		"required_contract": PackedStringArray([
			"can_handle_type",
			"spawn_entity_from_save",
			"apply_saved_data",
		]),
		"optional_hooks": PackedStringArray([
			"find_existing_entity",
			"prepare_restore",
			"get_supported_entity_types",
			"get_target_container",
		]),
	}


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	var plan := describe_entity_factory_plan()
	var problems: PackedStringArray = PackedStringArray(plan.get("problems", PackedStringArray()))
	for problem in problems:
		warnings.append("SaveFlowEntityFactory: %s" % problem)
	return warnings


func _refresh_editor_warnings() -> void:
	if not Engine.is_editor_hint():
		return
	update_configuration_warnings()


func _resolve_plan_reason(problems: PackedStringArray) -> String:
	if problems.is_empty():
		return ""
	if problems.size() == 1:
		return "MISSING_REQUIRED_METHOD"
	return "MISSING_REQUIRED_METHODS"


func _implements_method(method_name: String) -> bool:
	return has_method(method_name)


func _describe_node_name(node: Node) -> String:
	if node == null:
		return ""
	return node.name


func _describe_node_path(node: Node) -> String:
	if not is_instance_valid(node):
		return "<none>"
	if node.is_inside_tree():
		return str(node.get_path())
	return node.name
