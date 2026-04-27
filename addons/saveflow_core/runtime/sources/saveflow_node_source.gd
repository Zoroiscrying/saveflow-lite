## SaveFlowNodeSource is the main object-centric source. It gathers one target
## node's exported fields, built-in Godot state, and selected child participants
## into a single payload for "save this object".
@icon("res://addons/saveflow_lite/icons/components/saveflow_node_source_icon.svg")
@tool
class_name SaveFlowNodeSource
extends SaveFlowSource

enum PropertySelectionMode {
	EXPORTED_FIELDS_ONLY,
	EXPORTED_FIELDS_AND_ADDITIONAL_PROPERTIES,
	ADDITIONAL_PROPERTIES_ONLY,
}

enum ParticipantDiscoveryMode {
	DIRECT_CHILDREN_ONLY,
	RECURSIVE,
}

## Optional override for the persisted key. Leave empty to derive a stable key
## from the target node name.
@export var save_key: String = "":
	set(value):
		save_key = value
		source_key = value
		_refresh_editor_preview()
## Leave empty for the common prefab-owned case so the source binds to its
## parent. Only point this at another node when one object intentionally owns
## save logic for a different target.
@export var target: Node:
	set(value):
		target = value
		_has_explicit_target = value != null
		_target_ref_path = _resolve_relative_node_path(value)
		_refresh_editor_preview()
@export_storage var _target_ref_path: NodePath = NodePath()
## Default to "Exported Fields + Additional Properties" for most gameplay
## objects. Switch to stricter modes only when you need to lock persistence down
## to a very small set of fields.
@export_enum("Exported Fields Only", "Exported Fields + Additional Properties", "Additional Properties Only")
var property_selection_mode: int = PropertySelectionMode.EXPORTED_FIELDS_AND_ADDITIONAL_PROPERTIES:
	set(value):
		property_selection_mode = value
		_refresh_editor_preview()
## Use this only for target properties that are not exported but still belong to
## the object's saved state. If this list grows large, the target probably wants
## cleaner exported fields or a custom source instead.
@export var additional_properties: PackedStringArray = []:
	set(value):
		additional_properties = value
		_refresh_editor_preview()
## Ignore properties here when they are exported for editor convenience but
## should not survive save/load. Prefer this over removing them after load.
@export var ignored_properties: PackedStringArray = []:
	set(value):
		ignored_properties = value
		_refresh_editor_preview()
## Built-ins let the source persist engine state like Node2D, Control, or
## AnimationPlayer without requiring a separate source node for the same object.
@export var include_target_built_ins: bool = true:
	set(value):
		include_target_built_ins = value
		_refresh_editor_preview()
## Most users should leave this alone and toggle built-ins through the preview.
## Set explicit ids only when you need to override the automatic built-in set.
@export var included_target_builtin_ids: PackedStringArray = []:
	set(value):
		included_target_builtin_ids = value
		_refresh_editor_preview()
## Advanced override map for target built-ins. Key = serializer id, value =
## PackedStringArray of field ids. Leave empty for the default "save all"
## behavior.
@export var target_builtin_field_overrides: Dictionary = {}:
	set(value):
		target_builtin_field_overrides = value
		_refresh_editor_preview()
## Include child nodes only when they are conceptually part of the same saved
## object, such as an AnimationPlayer under Player. Do not use this to reach
## across to unrelated systems; those should be separate sources or scopes.
@export var included_paths: PackedStringArray = PackedStringArray():
	set(value):
		included_paths = value
		_refresh_editor_preview()
## Exclusions are the escape hatch when auto-discovered children are technically
## reachable but should not travel with this object payload.
@export var excluded_paths: PackedStringArray = PackedStringArray():
	set(value):
		excluded_paths = value
		_refresh_editor_preview()
## Prefer Direct when the prefab shape is simple and intentional. Use Recursive
## only when meaningful child participants live deeper in the node tree.
@export_enum("Direct Children Only", "Recursive")
var participant_discovery_mode: int = ParticipantDiscoveryMode.RECURSIVE:
	set(value):
		participant_discovery_mode = value
		_refresh_editor_preview()
## Keep warnings enabled unless the source is intentionally incomplete during
## authoring. Turning warnings off should be rare.
@export var warn_on_missing_target: bool = true:
	set(value):
		warn_on_missing_target = value
		_refresh_editor_preview()
## Warn when an included child path cannot be resolved. Disabling this should be
## rare outside temporary prefab editing states.
@export var warn_on_missing_participants: bool = true:
	set(value):
		warn_on_missing_participants = value
		_refresh_editor_preview()
## Warn when a selected property no longer exists on the target. Keep this on
## so refactors surface missing fields before saves silently drift.
@export var warn_on_missing_property: bool = true:
	set(value):
		warn_on_missing_property = value
		_refresh_editor_preview()

var _current_context: Dictionary = {}
var _has_explicit_target := false
var _editor_tree_refresh_queued := false


func _ready() -> void:
	_hydrate_target_from_ref_path()
	_connect_editor_tree_signals()
	_refresh_editor_preview()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		_disconnect_editor_tree_signals()


func before_save(context: Dictionary = {}) -> void:
	_current_context = context


func before_load(_payload: Variant, context: Dictionary = {}) -> void:
	_current_context = context


func get_source_key() -> String:
	if not save_key.is_empty():
		return save_key
	var target_node := _resolve_target()
	if target_node != null and not target_node.name.is_empty():
		return target_node.name.to_snake_case()
	return super.get_source_key()


func gather_save_data() -> Variant:
	var target_node := _resolve_target()
	if target_node == null:
		_warn_missing_target()
		return {}

	var payload: Dictionary = {
		"properties": {},
		"built_ins": {},
		"participants": {},
	}
	payload["properties"] = _gather_target_properties(target_node)
	if include_target_built_ins:
		payload["built_ins"] = SaveFlowBuiltInSerializerRegistry.gather_for_node(
			target_node,
			_resolve_active_target_builtin_ids(target_node),
			_resolve_active_target_builtin_field_overrides(target_node)
		)

	for participant_path in included_paths:
		if excluded_paths.has(participant_path):
			continue
		var ownership_conflict := _describe_participant_ownership_conflict(target_node, str(participant_path))
		if not ownership_conflict.is_empty():
			_warn_ownership_conflict(ownership_conflict)
			continue
		var participant := _resolve_included_node(participant_path)
		if participant == null:
			_warn_missing_participant(str(participant_path))
			continue
		if _is_pipeline_helper_node(participant):
			continue
		payload["participants"][_participant_key_for(target_node, participant)] = _gather_participant_payload(participant)

	return payload


## Apply mirrors gather: one object payload restores target fields first, then
## target built-ins, then selected child participants.
func apply_save_data(data: Variant, _context: Dictionary = {}) -> SaveResult:
	if not (data is Dictionary):
		return error_result(
			SaveError.INVALID_FORMAT,
			"INVALID_FORMAT",
			"node source payload must be a dictionary",
			{"source_key": get_source_key()}
		)
	var target_node := _resolve_target()
	if target_node == null:
		_warn_missing_target()
		return error_result(
			SaveError.INVALID_SAVEABLE,
			"TARGET_NOT_FOUND",
			"node source target could not be resolved",
			{"source_key": get_source_key()}
		)

	var payload: Dictionary = data
	if payload.has("properties") and payload["properties"] is Dictionary:
		_apply_target_properties(target_node, payload["properties"])
	if include_target_built_ins and payload.has("built_ins") and payload["built_ins"] is Dictionary:
		SaveFlowBuiltInSerializerRegistry.apply_to_node(
			target_node,
			payload["built_ins"],
			_resolve_active_target_builtin_field_overrides(target_node)
		)

	var participant_payloads: Dictionary = Dictionary(payload.get("participants", {}))
	for participant_path in included_paths:
		var ownership_conflict := _describe_participant_ownership_conflict(target_node, str(participant_path))
		if not ownership_conflict.is_empty():
			_warn_ownership_conflict(ownership_conflict)
			continue
		var participant := _resolve_included_node(participant_path)
		if participant == null:
			_warn_missing_participant(str(participant_path))
			continue
		if _is_pipeline_helper_node(participant):
			continue
		var participant_key: String = _participant_key_for(target_node, participant)
		if not participant_payloads.has(participant_key):
			continue
		_apply_participant_payload(participant, participant_payloads[participant_key])
	return ok_result()


func describe_source() -> Dictionary:
	var description := super.describe_source()
	var plan: Dictionary = describe_node_plan()
	var target_node := _resolve_target()
	var supported_ids: PackedStringArray = PackedStringArray()
	var active_ids: PackedStringArray = PackedStringArray()
	var participant_entries: Array = []
	var missing_paths: PackedStringArray = []

	if target_node != null:
		supported_ids = SaveFlowBuiltInSerializerRegistry.supported_ids_for_node(target_node)
		active_ids = _resolve_active_target_builtin_ids(target_node)

	for participant_path in included_paths:
		if excluded_paths.has(participant_path):
			continue
		var participant := _resolve_included_node(participant_path)
		if participant == null:
			missing_paths.append(str(participant_path))
			continue
		if _is_pipeline_helper_node(participant):
			continue
		participant_entries.append(
			{
				"path": str(participant_path),
				"resolved_name": participant.name,
				"kind": _describe_participant_kind(participant),
				"supported_built_ins": SaveFlowBuiltInSerializerRegistry.supported_ids_for_node(participant),
			}
		)

	description["kind"] = "node_source"
	description["plan"] = plan
	description["target_path"] = _describe_target_path(target_node if is_instance_valid(target_node) else _resolve_target())
	description["save_key"] = get_source_key()
	description["supported_target_built_ins"] = supported_ids
	description["active_target_built_ins"] = active_ids
	description["included_paths"] = included_paths.duplicate()
	description["participants"] = participant_entries
	description["missing_paths"] = missing_paths
	return description


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	var plan: Dictionary = describe_node_plan()
	if not bool(plan.get("valid", false)):
		var reason: String = String(plan.get("reason", "INVALID_NODE_PLAN"))
		warnings.append("SaveFlowNodeSource plan is invalid: %s" % reason)
	for missing_path in PackedStringArray(plan.get("missing_paths", PackedStringArray())):
		warnings.append("Included path could not be resolved: %s" % missing_path)
	for suggestion in PackedStringArray(plan.get("missing_path_suggestions", PackedStringArray())):
		warnings.append(suggestion)
	for conflict_text in PackedStringArray(plan.get("ownership_conflicts", PackedStringArray())):
		warnings.append("Included child crosses another save-owner boundary: %s" % conflict_text)
	if bool(plan.get("target_is_source_helper", false)):
		warnings.append("Target resolves to another SaveFlowSource helper. Move this source under a gameplay object or set target to a real gameplay node.")
	var helper_child_paths: PackedStringArray = PackedStringArray(plan.get("helper_child_paths", PackedStringArray()))
	if not helper_child_paths.is_empty():
		warnings.append("SaveFlowSource helper nodes should not contain gameplay child nodes: %s." % ", ".join(helper_child_paths))
		for suggestion in PackedStringArray(plan.get("helper_child_suggestions", PackedStringArray())):
			warnings.append(suggestion)
	var source_child_paths: PackedStringArray = PackedStringArray(plan.get("source_child_paths", PackedStringArray()))
	if not source_child_paths.is_empty():
		warnings.append("SaveFlowSource helper nodes should not contain child SaveFlowSource nodes: %s." % ", ".join(source_child_paths))
		for suggestion in PackedStringArray(plan.get("source_child_suggestions", PackedStringArray())):
			warnings.append(suggestion)
	var missing_properties: PackedStringArray = PackedStringArray(plan.get("missing_properties", PackedStringArray()))
	if not missing_properties.is_empty():
		warnings.append("Missing target properties: %s" % ", ".join(missing_properties))
	for warning in PackedStringArray(plan.get("built_in_selection_warnings", PackedStringArray())):
		warnings.append(warning)
	for warning in get_saveflow_authoring_warnings():
		warnings.append(warning)
	return warnings


func describe_node_plan() -> Dictionary:
	var target_node := _resolve_target()
	var helper_child_paths: PackedStringArray = _collect_helper_child_paths()
	var source_child_paths: PackedStringArray = _collect_child_source_paths()
	if target_node == null:
		return {
			"valid": false,
			"reason": "TARGET_NOT_FOUND",
			"save_key": get_source_key(),
			"target_name": "",
			"target_path": "",
			"exported_fields": PackedStringArray(),
			"target_properties": PackedStringArray(),
			"supported_target_built_ins": PackedStringArray(),
			"active_target_built_ins": PackedStringArray(),
			"included_paths": included_paths.duplicate(),
			"excluded_paths": excluded_paths.duplicate(),
			"resolved_participants": [],
			"helper_child_paths": helper_child_paths,
			"helper_child_suggestions": _build_helper_child_suggestions(helper_child_paths, null),
			"source_child_paths": source_child_paths,
			"source_child_suggestions": _build_source_child_suggestions(source_child_paths, null),
			"target_is_source_helper": false,
			"built_in_selection_warnings": PackedStringArray(),
			"missing_properties": PackedStringArray(),
			"missing_paths": included_paths.duplicate(),
			"missing_path_suggestions": _build_missing_path_suggestions(included_paths.duplicate(), source_child_paths, null),
		}

	var helper_child_suggestions: PackedStringArray = _build_helper_child_suggestions(helper_child_paths, target_node)
	var source_child_suggestions: PackedStringArray = _build_source_child_suggestions(source_child_paths, target_node)
	var target_is_source_helper := target_node is SaveFlowSource
	var exported_fields: PackedStringArray = _stored_script_properties_for(target_node)
	var target_properties: PackedStringArray = _resolve_target_property_names(target_node)
	var supported_ids: PackedStringArray = SaveFlowBuiltInSerializerRegistry.supported_ids_for_node(target_node)
	var active_ids: PackedStringArray = _resolve_active_target_builtin_ids(target_node)
	var built_in_selection_warnings: PackedStringArray = _collect_target_builtin_selection_warnings(target_node)
	var missing_properties: PackedStringArray = []
	for property_name in target_properties:
		if _is_ignored(property_name):
			continue
		if not _has_property(target_node, property_name):
			_append_unique(missing_properties, property_name)
	var resolved_participants: Array = []
	var missing_paths: PackedStringArray = []
	var ownership_conflicts: PackedStringArray = []
	for path_text in included_paths:
		if excluded_paths.has(path_text):
			continue
		var ownership_conflict := _describe_participant_ownership_conflict(target_node, path_text)
		if not ownership_conflict.is_empty():
			ownership_conflicts.append(ownership_conflict)
			continue
		var participant := _resolve_included_node(path_text)
		if participant == null:
			missing_paths.append(path_text)
			continue
		if _is_pipeline_helper_node(participant):
			continue
		resolved_participants.append(
			{
				"path": path_text,
				"name": participant.name,
				"kind": _describe_participant_kind(participant),
				"supported_built_ins": SaveFlowBuiltInSerializerRegistry.supported_ids_for_node(participant),
			}
		)

	var missing_path_suggestions: PackedStringArray = _build_missing_path_suggestions(missing_paths, source_child_paths, target_node)
	var valid := missing_paths.is_empty() \
		and missing_properties.is_empty() \
		and ownership_conflicts.is_empty() \
		and helper_child_paths.is_empty() \
		and source_child_paths.is_empty() \
		and not target_is_source_helper
	return {
		"valid": valid,
		"reason": _resolve_plan_reason(
			missing_properties,
			missing_paths,
			ownership_conflicts,
			source_child_paths,
			helper_child_paths,
			target_is_source_helper
		),
		"save_key": get_source_key(),
		"target_name": target_node.name,
		"target_path": _describe_target_path(target_node),
		"target_is_source_helper": target_is_source_helper,
		"exported_fields": exported_fields,
		"target_properties": target_properties,
		"supported_target_built_ins": supported_ids,
		"active_target_built_ins": active_ids,
		"included_paths": included_paths.duplicate(),
		"excluded_paths": excluded_paths.duplicate(),
		"participant_discovery_mode": participant_discovery_mode,
		"resolved_participants": resolved_participants,
		"ownership_conflicts": ownership_conflicts,
		"helper_child_paths": helper_child_paths,
		"helper_child_suggestions": helper_child_suggestions,
		"source_child_paths": source_child_paths,
		"source_child_suggestions": source_child_suggestions,
		"built_in_selection_warnings": built_in_selection_warnings,
		"missing_properties": missing_properties,
		"missing_paths": missing_paths,
		"missing_path_suggestions": missing_path_suggestions,
	}


func describe_target_built_in_options() -> Array:
	var target_node := _resolve_target()
	if target_node == null:
		return []
	var active_ids: PackedStringArray = _resolve_active_target_builtin_ids(target_node)
	var field_overrides: Dictionary = _resolve_active_target_builtin_field_overrides(target_node)
	var options: Array = []
	for descriptor_variant in SaveFlowBuiltInSerializerRegistry.supported_descriptors_for_node(target_node):
		var descriptor: Dictionary = descriptor_variant
		var serializer_id: String = String(descriptor.get("id", ""))
		var fields: Array = SaveFlowBuiltInSerializerRegistry.fields_for_node(target_node, serializer_id)
		var selected_field_ids: PackedStringArray = PackedStringArray(field_overrides.get(serializer_id, PackedStringArray()))
		if selected_field_ids.is_empty() and not fields.is_empty():
			for field_variant in fields:
				if not (field_variant is Dictionary):
					continue
				selected_field_ids.append(String(field_variant.get("id", "")))
		options.append(
			{
				"id": serializer_id,
				"display_name": String(descriptor.get("display_name", serializer_id)),
				"selected": include_target_built_ins and active_ids.has(serializer_id),
				"fields": fields,
				"selected_fields": selected_field_ids,
				"recommended_fields": SaveFlowBuiltInSerializerRegistry.recommended_field_ids_for_node(
					target_node,
					serializer_id
				),
			}
		)
	return options


func clear_target_builtin_field_overrides() -> void:
	target_builtin_field_overrides = {}


func use_recommended_target_builtin_fields() -> void:
	var target_node := _resolve_target()
	if target_node == null:
		target_builtin_field_overrides = {}
		return
	var next_overrides: Dictionary = {}
	for serializer_id in _resolve_active_target_builtin_ids(target_node):
		var recommended_fields: PackedStringArray = SaveFlowBuiltInSerializerRegistry.recommended_field_ids_for_node(
			target_node,
			serializer_id
		)
		if recommended_fields.is_empty():
			continue
		next_overrides[serializer_id] = recommended_fields
	target_builtin_field_overrides = next_overrides


func set_target_builtin_field_selection(serializer_id: String, field_ids: PackedStringArray) -> void:
	var next_overrides: Dictionary = target_builtin_field_overrides.duplicate(true)
	if field_ids.is_empty():
		next_overrides.erase(serializer_id)
	else:
		next_overrides[serializer_id] = field_ids
	target_builtin_field_overrides = next_overrides


func discover_participant_candidates() -> Array:
	var target_node := _resolve_target()
	if target_node == null:
		return []

	var candidates: Array = []
	_collect_participant_candidates(target_node, target_node, candidates)
	return candidates


func _gather_target_properties(target_node: Node) -> Dictionary:
	var data: Dictionary = {}
	var plan: Dictionary = describe_node_plan()
	if not bool(plan.get("valid", false)) and String(plan.get("reason", "")) == "TARGET_NOT_FOUND":
		return data
	for property_name in PackedStringArray(plan.get("target_properties", PackedStringArray())):
		var key: String = String(property_name)
		if key.is_empty() or _is_ignored(key):
			continue
		if not _has_property(target_node, key):
			_warn_missing_property(key)
			continue
		data[key] = target_node.get(key)
	return data


func _apply_target_properties(target_node: Node, data: Dictionary) -> void:
	for key in data.keys():
		var property_name: String = str(key)
		if _is_ignored(property_name):
			continue
		if not _has_property(target_node, property_name):
			_warn_missing_property(property_name)
			continue
		target_node.set(property_name, data[key])


func _resolve_target() -> Node:
	if is_instance_valid(target):
		return target
	if not _target_ref_path.is_empty():
		var resolved := get_node_or_null(_target_ref_path)
		if is_instance_valid(resolved):
			return resolved
		return null
	if _has_explicit_target:
		return null
	return get_parent()


func _resolve_target_property_names(target_node: Node) -> PackedStringArray:
	var property_names: PackedStringArray = []
	if property_selection_mode != PropertySelectionMode.ADDITIONAL_PROPERTIES_ONLY:
		for property_name in _stored_script_properties_for(target_node):
			_append_unique(property_names, property_name)
	if property_selection_mode != PropertySelectionMode.EXPORTED_FIELDS_ONLY:
		for property_name in additional_properties:
			_append_unique(property_names, String(property_name))
	return property_names


func _stored_script_properties_for(target_node: Node) -> PackedStringArray:
	var property_names: PackedStringArray = []
	var script: Script = target_node.get_script()
	if script == null:
		return property_names

	for property_info in script.get_script_property_list():
		var usage: int = int(property_info.get("usage", 0))
		if (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		if (usage & PROPERTY_USAGE_STORAGE) == 0:
			continue
		_append_unique(property_names, String(property_info.get("name", "")))
	return property_names


func _has_property(target_object: Object, property_name: String) -> bool:
	for property_info in target_object.get_property_list():
		if String(property_info.get("name", "")) == property_name:
			return true
	return false


func _append_unique(values: PackedStringArray, value: String) -> void:
	if value.is_empty() or values.has(value):
		return
	values.append(value)


func _to_packed_string_array(value: Variant) -> PackedStringArray:
	if value is PackedStringArray:
		return value
	if value is Array:
		var result: PackedStringArray = PackedStringArray()
		for item in value:
			result.append(String(item))
		return result
	if value is String:
		return PackedStringArray([String(value)])
	return PackedStringArray()


func _is_ignored(property_name: String) -> bool:
	return ignored_properties.has(property_name)


func _resolve_included_node(path_text: String) -> Node:
	var target_node := _resolve_target()
	if target_node == null or path_text.is_empty():
		return null
	var ownership_conflict := _describe_participant_ownership_conflict(target_node, path_text)
	if not ownership_conflict.is_empty():
		_warn_ownership_conflict(ownership_conflict)
		return null
	var resolved := target_node.get_node_or_null(NodePath(path_text))
	if _is_pipeline_helper_node(resolved):
		return resolved
	if _is_excluded_participant(resolved):
		return null
	return resolved


func _resolve_active_target_builtin_ids(target_node: Node) -> PackedStringArray:
	if target_node == null:
		return PackedStringArray()
	if included_target_builtin_ids.is_empty():
		return SaveFlowBuiltInSerializerRegistry.supported_ids_for_node(target_node)
	var supported_ids: PackedStringArray = SaveFlowBuiltInSerializerRegistry.supported_ids_for_node(target_node)
	var active_ids: PackedStringArray = []
	for serializer_id in included_target_builtin_ids:
		if supported_ids.has(serializer_id):
			active_ids.append(serializer_id)
	return active_ids


func _resolve_active_target_builtin_field_overrides(target_node: Node) -> Dictionary:
	var active_ids: PackedStringArray = _resolve_active_target_builtin_ids(target_node)
	if active_ids.is_empty():
		return {}
	var overrides: Dictionary = {}
	for serializer_id_variant in target_builtin_field_overrides.keys():
		var serializer_id: String = String(serializer_id_variant)
		if not active_ids.has(serializer_id):
			continue
		var field_ids: PackedStringArray = _to_packed_string_array(target_builtin_field_overrides[serializer_id_variant])
		if field_ids.is_empty():
			continue
		overrides[serializer_id] = field_ids
	return overrides


func _collect_target_builtin_selection_warnings(target_node: Node) -> PackedStringArray:
	var warnings: PackedStringArray = []
	if target_node == null or not include_target_built_ins:
		return warnings

	var supported_ids: PackedStringArray = SaveFlowBuiltInSerializerRegistry.supported_ids_for_node(target_node)
	var active_ids: PackedStringArray = _resolve_active_target_builtin_ids(target_node)
	var target_label := _describe_target_path(target_node)
	var supported_summary := _format_supported_id_list(supported_ids)

	for serializer_id in included_target_builtin_ids:
		if supported_ids.has(serializer_id):
			continue
		warnings.append(
			"Selected target built-in `%s` is not supported by `%s`. Supported target built-ins: %s." %
			[serializer_id, target_label, supported_summary]
		)

	for serializer_id_variant in target_builtin_field_overrides.keys():
		var serializer_id := String(serializer_id_variant)
		if serializer_id.is_empty():
			continue
		if not supported_ids.has(serializer_id):
			warnings.append(
				"Field override for target built-in `%s` is ignored because `%s` does not support that built-in. Supported target built-ins: %s." %
				[serializer_id, target_label, supported_summary]
			)
			continue
		if not active_ids.has(serializer_id):
			warnings.append(
				"Field override for target built-in `%s` is ignored because that built-in is not selected for `%s`." %
				[serializer_id, target_label]
			)
			continue

		var supported_field_ids := _field_ids_for_target_builtin(target_node, serializer_id)
		if supported_field_ids.is_empty():
			continue
		for field_id in _to_packed_string_array(target_builtin_field_overrides[serializer_id_variant]):
			if supported_field_ids.has(field_id):
				continue
			warnings.append(
				"Target built-in `%s` does not expose field `%s` on `%s`. Supported fields: %s." %
				[serializer_id, field_id, target_label, _format_supported_id_list(supported_field_ids)]
			)
	return warnings


func _field_ids_for_target_builtin(target_node: Node, serializer_id: String) -> PackedStringArray:
	var field_ids: PackedStringArray = []
	for field_variant in SaveFlowBuiltInSerializerRegistry.fields_for_node(target_node, serializer_id):
		if not (field_variant is Dictionary):
			continue
		_append_unique(field_ids, String(Dictionary(field_variant).get("id", "")))
	return field_ids


func _format_supported_id_list(ids: PackedStringArray) -> String:
	if ids.is_empty():
		return "<none>"
	return ", ".join(ids)


func _collect_participant_candidates(target_node: Node, current: Node, into: Array) -> void:
	for child in current.get_children():
		var node_child := child as Node
		if node_child == null:
			continue
		if _is_excluded_participant(node_child):
			continue
		var relative_path: String = _relative_path_from_target(target_node, node_child)
		var ownership_conflict := _describe_participant_ownership_conflict(target_node, relative_path)
		var owner_source: SaveFlowSource = _find_participant_owner_source(target_node, node_child) if not ownership_conflict.is_empty() else null
		var recommended_source_path := ""
		var owner_source_name := ""
		var owner_kind := ""
		var owner_source_role := ""
		if owner_source != null:
			recommended_source_path = _relative_path_from_target(target_node, owner_source)
			owner_source_name = owner_source.name
			owner_kind = _describe_participant_kind(owner_source)
			owner_source_role = _describe_owner_source_role(owner_source)
		var kind: String = _describe_participant_kind(node_child)
		var supported_built_ins: PackedStringArray = SaveFlowBuiltInSerializerRegistry.supported_ids_for_node(node_child)
		var include_candidate := kind != "unknown" or not supported_built_ins.is_empty() or not ownership_conflict.is_empty()
		if include_candidate:
			var depth := 0 if relative_path.is_empty() or relative_path == "." else relative_path.count("/")
			var supported_display_names: PackedStringArray = []
			for serializer_id in supported_built_ins:
				supported_display_names.append(SaveFlowBuiltInSerializerRegistry.display_name_for_id(serializer_id))
			into.append(
				{
					"path": relative_path,
					"name": node_child.name,
					"depth": depth,
					"kind": kind,
					"icon_name": _describe_participant_icon_name(node_child),
					"supported_built_ins": supported_built_ins,
					"supported_built_in_names": supported_display_names,
					"included": included_paths.has(relative_path),
					"excluded": excluded_paths.has(relative_path),
					"ownership_conflict": ownership_conflict,
					"owner_kind": owner_kind,
					"owner_source_role": owner_source_role,
					"owner_source_name": owner_source_name,
					"recommended_source_path": recommended_source_path,
				}
			)
		if participant_discovery_mode == ParticipantDiscoveryMode.RECURSIVE:
			_collect_participant_candidates(target_node, node_child, into)


func _is_excluded_participant(candidate: Node) -> bool:
	if candidate == null:
		return false
	if candidate == self:
		return true
	if _is_pipeline_helper_node(candidate):
		return true
	return is_ancestor_of(candidate)


func _gather_participant_payload(participant: Node) -> Dictionary:
	if participant is SaveFlowSource:
		var source := participant as SaveFlowSource
		if not source.can_save_source():
			return {"kind": "source", "disabled": true, "data": null}
		source.before_save(_current_context)
		return {
			"kind": "source",
			"source_key": source.get_source_key(),
			"data": source.gather_save_data(),
		}
	return {
		"kind": "built_in_node",
		"built_ins": SaveFlowBuiltInSerializerRegistry.gather_for_node(participant),
	}


func _apply_participant_payload(participant: Node, payload: Variant) -> void:
	if not (payload is Dictionary):
		return
	var payload_dict: Dictionary = payload
	var kind: String = String(payload_dict.get("kind", ""))
	match kind:
		"source":
			if participant is SaveFlowSource:
				var source := participant as SaveFlowSource
				if not source.can_load_source():
					return
				var source_data: Variant = payload_dict.get("data", null)
				source.before_load(source_data, _current_context)
				source.apply_save_data(source_data)
				source.after_load(source_data, _current_context)
		"built_in_node":
			var built_ins: Variant = payload_dict.get("built_ins", {})
			if built_ins is Dictionary:
				SaveFlowBuiltInSerializerRegistry.apply_to_node(participant, built_ins)


func _participant_key_for(target_node: Node, participant: Node) -> String:
	var relative_path: String = _relative_path_from_target(target_node, participant)
	if relative_path.is_empty() or relative_path == ".":
		return participant.name.to_snake_case()
	return relative_path.replace("/", "__").replace(":", "_").replace(".", "_").to_snake_case()


func _relative_path_from_target(target_node: Node, participant: Node) -> String:
	if target_node == null or participant == null:
		return ""
	if target_node == participant:
		return "."
	if target_node.is_ancestor_of(participant):
		return str(target_node.get_path_to(participant))
	return participant.name


func _describe_participant_kind(participant: Node) -> String:
	if _is_pipeline_helper_node(participant):
		return "pipeline_helper"
	if _is_saveflow_source_node(participant):
		return "source"
	if not SaveFlowBuiltInSerializerRegistry.supported_ids_for_node(participant).is_empty():
		return "built_in_node"
	return "unknown"


func _describe_owner_source_role(source: SaveFlowSource) -> String:
	if source is SaveFlowEntityCollectionSource:
		return "entity_collection"
	if source is SaveFlowNodeSource:
		return "node_source"
	return "source"


func _describe_participant_icon_name(participant: Node) -> String:
	if participant == null:
		return "Node"
	var class_name_text := participant.get_class()
	if class_name_text.is_empty():
		return "Node"
	return class_name_text


func _describe_participant_ownership_conflict(target_node: Node, path_text: String) -> String:
	if target_node == null or not target_node.is_inside_tree() or path_text.is_empty():
		return ""
	var resolved := target_node.get_node_or_null(NodePath(path_text))
	if resolved == null:
		return ""
	if resolved is SaveFlowEntityCollectionSource:
		return "%s is an EntityCollectionSource. Runtime sets should be owned directly by that collection source." % path_text
	if _is_saveflow_source_node(resolved):
		return ""

	var entity_collection_source := _find_entity_collection_source_for_boundary(target_node, resolved)
	if entity_collection_source != null:
		var entity_collection_target: Node = entity_collection_source.call("_resolve_target") if entity_collection_source.has_method("_resolve_target") else null
		var relative_collection_path := str(target_node.get_path_to(entity_collection_target))
		var relative_source_path := _relative_path_from_target(target_node, entity_collection_source)
		return "%s enters runtime entity container `%s`, which is owned by EntityCollectionSource `%s`. Include `%s` instead." % [path_text, relative_collection_path, entity_collection_source.name, relative_source_path]

	if resolved is SaveFlowNodeSource:
		return ""
	var nested_source := _find_nested_node_source_for_boundary(target_node, resolved)
	if nested_source != null:
		var nested_target: Node = nested_source.call("_resolve_target") if nested_source.has_method("_resolve_target") else nested_source.get_parent()
		var relative_target_path := str(target_node.get_path_to(nested_target))
		var relative_source_path := _relative_path_from_target(target_node, nested_source)
		return "%s enters object subtree `%s`, which already has its own NodeSource owner `%s`. Include `%s` instead." % [path_text, relative_target_path, nested_source.name, relative_source_path]
	return ""


func _find_entity_collection_source_for_boundary(target_node: Node, resolved: Node) -> SaveFlowEntityCollectionSource:
	var collections: Array = []
	_collect_entity_collection_sources(target_node, collections)
	for collection_variant in collections:
		var collection := collection_variant as SaveFlowEntityCollectionSource
		if collection == null:
			continue
		var collection_target: Node = collection.call("_resolve_target") if collection.has_method("_resolve_target") else null
		if not is_instance_valid(collection_target):
			continue
		if collection_target == resolved or collection_target.is_ancestor_of(resolved):
			return collection
	return null


func _find_nested_node_source_for_boundary(target_node: Node, resolved: Node) -> SaveFlowNodeSource:
	var nested_sources: Array = []
	_collect_node_sources(target_node, nested_sources)
	for source_variant in nested_sources:
		var nested_source := source_variant as SaveFlowNodeSource
		if nested_source == null or nested_source == self:
			continue
		var nested_target: Node = nested_source.call("_resolve_target") if nested_source.has_method("_resolve_target") else nested_source.get_parent()
		if not is_instance_valid(nested_target):
			continue
		if nested_target == target_node:
			continue
		if nested_target == resolved or nested_target.is_ancestor_of(resolved):
			return nested_source
	return null


func _find_participant_owner_source(target_node: Node, resolved: Node) -> SaveFlowSource:
	if target_node == null or resolved == null:
		return null
	var entity_collection_source := _find_entity_collection_source_for_boundary(target_node, resolved)
	if entity_collection_source != null:
		return entity_collection_source
	var nested_source := _find_nested_node_source_for_boundary(target_node, resolved)
	if nested_source != null:
		return nested_source
	return null


func _collect_entity_collection_sources(current: Node, into: Array) -> void:
	for child_variant in current.get_children():
		var child := child_variant as Node
		if child == null:
			continue
		if child is SaveFlowEntityCollectionSource:
			into.append(child)
		_collect_entity_collection_sources(child, into)


func _collect_node_sources(current: Node, into: Array) -> void:
	for child_variant in current.get_children():
		var child := child_variant as Node
		if child == null:
			continue
		if _is_pipeline_helper_node(child):
			continue
		if child is SaveFlowNodeSource:
			into.append(child)
		_collect_node_sources(child, into)


func _collect_helper_child_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	for child_variant in get_children():
		var child := child_variant as Node
		if child == null or _is_saveflow_source_node(child) or _is_pipeline_helper_node(child):
			continue
		paths.append(String(child.name))
	return paths


func _collect_child_source_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	_collect_child_source_paths_recursive(self, "", paths)
	return paths


func _collect_child_source_paths_recursive(current: Node, prefix: String, into: PackedStringArray) -> void:
	for child_variant in current.get_children():
		var child := child_variant as Node
		if child == null:
			continue
		if _is_pipeline_helper_node(child):
			continue
		var child_path := String(child.name) if prefix.is_empty() else "%s/%s" % [prefix, child.name]
		if _is_saveflow_source_node(child):
			into.append(child_path)
		_collect_child_source_paths_recursive(child, child_path, into)


func _is_pipeline_helper_node(node: Node) -> bool:
	return node is SaveFlowPipelineSignals


func _is_saveflow_source_node(node: Node) -> bool:
	if node == null:
		return false
	if node is SaveFlowSource:
		return true
	return node.has_method("gather_save_data") and node.has_method("apply_save_data")


func _build_helper_child_suggestions(helper_child_paths: PackedStringArray, target_node: Node) -> PackedStringArray:
	var suggestions: PackedStringArray = []
	var target_label := "the target gameplay object"
	if is_instance_valid(target_node) and not String(target_node.name).is_empty():
		target_label = "`%s`" % target_node.name
	for helper_child_path in helper_child_paths:
		var path_text := String(helper_child_path)
		if path_text.is_empty():
			continue
		suggestions.append(
			"Child node `%s` is inside this Source helper. Move `%s` under %s; Source helpers should only configure save logic, not contain gameplay nodes." %
			[path_text, path_text, target_label]
		)
	return suggestions


func _build_source_child_suggestions(source_child_paths: PackedStringArray, target_node: Node) -> PackedStringArray:
	var suggestions: PackedStringArray = []
	var target_label := "the target gameplay object"
	if is_instance_valid(target_node) and not String(target_node.name).is_empty():
		target_label = "`%s`" % target_node.name
	for source_child_path in source_child_paths:
		var path_text := String(source_child_path)
		if path_text.is_empty():
			continue
		var segments := path_text.split("/", false)
		if segments.size() <= 1:
			suggestions.append(
				"Nested source `%s` is inside this Source helper. Move it under the real gameplay object it saves, or delete it if this Source already owns that object." %
				path_text
			)
			continue
		var top_gameplay_node := String(segments[0])
		var top_node := get_node_or_null(NodePath(top_gameplay_node))
		if _is_saveflow_source_node(top_node):
			suggestions.append(
				"Nested source `%s` is inside Source helper `%s`. Move each Source under the real gameplay object it saves, or delete duplicate Sources that try to save the same object." %
				[path_text, top_gameplay_node]
			)
			continue
		suggestions.append(
			"Nested source `%s` is inside this Source helper. Move gameplay subtree `%s` under %s, keep the nested Source inside that subtree, then include `%s` from this Source only if the parent object should compose it." %
			[path_text, top_gameplay_node, target_label, path_text]
		)
	return suggestions


func _build_missing_path_suggestions(missing_paths: PackedStringArray, source_child_paths: PackedStringArray, target_node: Node) -> PackedStringArray:
	var suggestions: PackedStringArray = []
	var target_label := "the target gameplay object"
	if is_instance_valid(target_node) and not String(target_node.name).is_empty():
		target_label = "`%s`" % target_node.name
	for missing_path in missing_paths:
		var path_text := String(missing_path)
		if path_text.is_empty():
			continue
		if source_child_paths.has(path_text) or get_node_or_null(NodePath(path_text)) != null:
			suggestions.append(
				"Included child `%s` exists under this Source helper, but included children are resolved from %s. Move the gameplay subtree under %s, or remove this included path." %
				[path_text, target_label, target_label]
			)
			continue
		suggestions.append(
			"Included child `%s` does not exist under %s. Re-select it from Included Children, or remove the stale included path." %
			[path_text, target_label]
		)
	return suggestions


func _warn_missing_target() -> void:
	if warn_on_missing_target and not Engine.is_editor_hint():
		push_warning("SaveFlowNodeSource target could not be resolved.")


func _warn_missing_participant(path_text: String) -> void:
	if warn_on_missing_participants and not Engine.is_editor_hint():
		push_warning("SaveFlowNodeSource participant could not be resolved: %s" % path_text)


func _warn_missing_property(property_name: String) -> void:
	if not warn_on_missing_property or Engine.is_editor_hint():
		return
	push_warning(
		"SaveFlowNodeSource '%s' could not find property '%s' on target '%s'." %
		[name, property_name, _describe_target_path(_resolve_target())]
	)


func _warn_ownership_conflict(message: String) -> void:
	if not warn_on_missing_participants or Engine.is_editor_hint():
		return
	push_warning("SaveFlowNodeSource '%s' skipped an included child because it crosses another save-owner boundary: %s" % [name, message])


func _resolve_plan_reason(
	missing_properties: PackedStringArray,
	missing_paths: PackedStringArray,
	ownership_conflicts: PackedStringArray = PackedStringArray(),
	source_child_paths: PackedStringArray = PackedStringArray(),
	helper_child_paths: PackedStringArray = PackedStringArray(),
	target_is_source_helper := false
) -> String:
	if target_is_source_helper:
		return "TARGET_IS_SAVEFLOW_SOURCE_HELPER"
	if not source_child_paths.is_empty():
		return "SOURCE_HELPER_HAS_CHILD_SOURCES"
	if not helper_child_paths.is_empty():
		return "SOURCE_HELPER_HAS_CHILD_NODES"
	if not ownership_conflicts.is_empty():
		return "OWNERSHIP_CONFLICTS"
	if missing_properties.is_empty() and missing_paths.is_empty():
		return ""
	if not missing_properties.is_empty() and not missing_paths.is_empty():
		return "MISSING_PROPERTIES_AND_PARTICIPANTS"
	if not missing_properties.is_empty():
		return "MISSING_PROPERTIES"
	return "MISSING_PARTICIPANTS"


func _describe_target_path(target_node: Node) -> String:
	if target_node == null:
		return ""
	if target_node.is_inside_tree():
		return str(target_node.get_path())
	return target_node.name


func _connect_editor_tree_signals() -> void:
	if not Engine.is_editor_hint():
		return
	var tree := get_tree()
	if tree == null:
		return
	_connect_editor_tree_signal(tree, "node_added", _on_editor_tree_node_added)
	_connect_editor_tree_signal(tree, "node_removed", _on_editor_tree_node_removed)
	_connect_editor_tree_signal(tree, "node_renamed", _on_editor_tree_node_renamed)


func _disconnect_editor_tree_signals() -> void:
	if not Engine.is_editor_hint():
		return
	var tree := get_tree()
	if tree == null:
		return
	_disconnect_editor_tree_signal(tree, "node_added", _on_editor_tree_node_added)
	_disconnect_editor_tree_signal(tree, "node_removed", _on_editor_tree_node_removed)
	_disconnect_editor_tree_signal(tree, "node_renamed", _on_editor_tree_node_renamed)


func _connect_editor_tree_signal(tree: SceneTree, signal_name: StringName, handler: Callable) -> void:
	if not tree.has_signal(signal_name):
		return
	if tree.is_connected(signal_name, handler):
		return
	tree.connect(signal_name, handler)


func _disconnect_editor_tree_signal(tree: SceneTree, signal_name: StringName, handler: Callable) -> void:
	if not tree.has_signal(signal_name):
		return
	if not tree.is_connected(signal_name, handler):
		return
	tree.disconnect(signal_name, handler)


func _on_editor_tree_node_added(_node: Node) -> void:
	_queue_editor_tree_refresh()


func _on_editor_tree_node_removed(_node: Node) -> void:
	_queue_editor_tree_refresh()


func _on_editor_tree_node_renamed(_node: Node) -> void:
	_queue_editor_tree_refresh()


func _queue_editor_tree_refresh() -> void:
	if not Engine.is_editor_hint():
		return
	if _editor_tree_refresh_queued:
		return
	_editor_tree_refresh_queued = true
	call_deferred("_flush_editor_tree_refresh")


func _flush_editor_tree_refresh() -> void:
	_editor_tree_refresh_queued = false
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	_refresh_editor_preview()


func _refresh_editor_preview() -> void:
	if not Engine.is_editor_hint():
		return
	update_configuration_warnings()


func _hydrate_target_from_ref_path() -> void:
	if is_instance_valid(target):
		if _target_ref_path.is_empty():
			_target_ref_path = _resolve_relative_node_path(target)
		return
	if _target_ref_path.is_empty():
		return
	var resolved := get_node_or_null(_target_ref_path)
	if is_instance_valid(resolved):
		target = resolved


func _resolve_relative_node_path(node: Node) -> NodePath:
	if node == null:
		return NodePath()
	if not is_inside_tree() or not node.is_inside_tree():
		return NodePath()
	return get_path_to(node)
