## SaveFlowNodeSource is the main object-centric source. It gathers one target
## node's exported fields, built-in Godot state, and selected child participants
## into a single payload for "save this object".
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


func _ready() -> void:
	_hydrate_target_from_ref_path()
	_refresh_editor_preview()


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
		var participant := _resolve_included_node(participant_path)
		if participant == null:
			_warn_missing_participant(str(participant_path))
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
		var participant := _resolve_included_node(participant_path)
		if participant == null:
			_warn_missing_participant(str(participant_path))
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
	var missing_properties: PackedStringArray = PackedStringArray(plan.get("missing_properties", PackedStringArray()))
	if not missing_properties.is_empty():
		warnings.append("Missing target properties: %s" % ", ".join(missing_properties))
	return warnings


func describe_node_plan() -> Dictionary:
	var target_node := _resolve_target()
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
			"missing_properties": PackedStringArray(),
			"missing_paths": included_paths.duplicate(),
		}

	var exported_fields: PackedStringArray = _stored_script_properties_for(target_node)
	var target_properties: PackedStringArray = _resolve_target_property_names(target_node)
	var supported_ids: PackedStringArray = SaveFlowBuiltInSerializerRegistry.supported_ids_for_node(target_node)
	var active_ids: PackedStringArray = _resolve_active_target_builtin_ids(target_node)
	var missing_properties: PackedStringArray = []
	for property_name in target_properties:
		if _is_ignored(property_name):
			continue
		if not _has_property(target_node, property_name):
			_append_unique(missing_properties, property_name)
	var resolved_participants: Array = []
	var missing_paths: PackedStringArray = []
	for path_text in included_paths:
		if excluded_paths.has(path_text):
			continue
		var participant := _resolve_included_node(path_text)
		if participant == null:
			missing_paths.append(path_text)
			continue
		resolved_participants.append(
			{
				"path": path_text,
				"name": participant.name,
				"kind": _describe_participant_kind(participant),
				"supported_built_ins": SaveFlowBuiltInSerializerRegistry.supported_ids_for_node(participant),
			}
		)

	return {
		"valid": missing_paths.is_empty() and missing_properties.is_empty(),
		"reason": _resolve_plan_reason(missing_properties, missing_paths),
		"save_key": get_source_key(),
		"target_name": target_node.name,
		"target_path": _describe_target_path(target_node),
		"exported_fields": exported_fields,
		"target_properties": target_properties,
		"supported_target_built_ins": supported_ids,
		"active_target_built_ins": active_ids,
		"included_paths": included_paths.duplicate(),
		"excluded_paths": excluded_paths.duplicate(),
		"participant_discovery_mode": participant_discovery_mode,
		"resolved_participants": resolved_participants,
		"missing_properties": missing_properties,
		"missing_paths": missing_paths,
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
	var resolved := target_node.get_node_or_null(NodePath(path_text))
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


func _collect_participant_candidates(target_node: Node, current: Node, into: Array) -> void:
	for child in current.get_children():
		var node_child := child as Node
		if node_child == null:
			continue
		if _is_excluded_participant(node_child):
			continue
		var kind: String = _describe_participant_kind(node_child)
		var supported_built_ins: PackedStringArray = SaveFlowBuiltInSerializerRegistry.supported_ids_for_node(node_child)
		var include_candidate := kind != "unknown" or not supported_built_ins.is_empty()
		if include_candidate:
			var relative_path: String = _relative_path_from_target(target_node, node_child)
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
				}
			)
		if participant_discovery_mode == ParticipantDiscoveryMode.RECURSIVE:
			_collect_participant_candidates(target_node, node_child, into)


func _is_excluded_participant(candidate: Node) -> bool:
	if candidate == null:
		return false
	if candidate == self:
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
	if participant is SaveFlowSource:
		return "source"
	if not SaveFlowBuiltInSerializerRegistry.supported_ids_for_node(participant).is_empty():
		return "built_in_node"
	return "unknown"


func _describe_participant_icon_name(participant: Node) -> String:
	if participant == null:
		return "Node"
	var class_name_text := participant.get_class()
	if class_name_text.is_empty():
		return "Node"
	return class_name_text


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


func _resolve_plan_reason(missing_properties: PackedStringArray, missing_paths: PackedStringArray) -> String:
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
