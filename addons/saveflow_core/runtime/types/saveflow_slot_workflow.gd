## Lightweight helper for active-slot and save-card workflows.
##
## SaveFlow deliberately does not own "the player's current slot". This resource
## keeps that project-owned state explicit while removing repeated slot-id and
## metadata glue from gameplay code.
@icon("res://addons/saveflow_lite/icons/components/saveflow_slot_metadata_icon.svg")
class_name SaveFlowSlotWorkflow
extends Resource

const SaveFlowSlotMetadataScript := preload("res://addons/saveflow_core/runtime/types/saveflow_slot_metadata.gd")
const SaveFlowSlotCardScript := preload("res://addons/saveflow_core/runtime/types/saveflow_slot_card.gd")

@export var active_slot_index := 0
@export var slot_id_template := "slot_{index}"
@export var empty_display_name_template := "Slot {index}"
@export var metadata_script: Script = SaveFlowSlotMetadataScript
var _slot_id_overrides: Dictionary = {}


func select_slot_index(slot_index: int) -> String:
	active_slot_index = slot_index
	return active_slot_id()


func active_slot_id() -> String:
	return slot_id_for_index(active_slot_index)


func set_slot_id_override(slot_index: int, slot_id: String) -> void:
	if slot_id.strip_edges().is_empty():
		_slot_id_overrides.erase(slot_index)
		return
	_slot_id_overrides[slot_index] = slot_id


func clear_slot_id_overrides() -> void:
	_slot_id_overrides.clear()


func slot_id_for_index(slot_index: int) -> String:
	if _slot_id_overrides.has(slot_index):
		return String(_slot_id_overrides[slot_index])
	return _format_indexed_text(slot_id_template, slot_index, "slot_%d" % slot_index)


func fallback_display_name_for_index(slot_index: int) -> String:
	return _format_indexed_text(empty_display_name_template, slot_index, "Slot %d" % slot_index)


func build_active_slot_metadata(
	display_name: String = "",
	save_type: String = "manual",
	chapter_name: String = "",
	location_name: String = "",
	playtime_seconds: int = 0,
	difficulty: String = "",
	thumbnail_path: String = "",
	slot_role: String = ""
) -> SaveFlowSlotMetadata:
	return build_slot_metadata(
		active_slot_index,
		display_name,
		save_type,
		chapter_name,
		location_name,
		playtime_seconds,
		difficulty,
		thumbnail_path,
		slot_role
	)


func build_slot_metadata(
	slot_index: int,
	display_name: String = "",
	save_type: String = "manual",
	chapter_name: String = "",
	location_name: String = "",
	playtime_seconds: int = 0,
	difficulty: String = "",
	thumbnail_path: String = "",
	slot_role: String = ""
) -> SaveFlowSlotMetadata:
	var metadata := _new_metadata()
	var storage_key := slot_id_for_index(slot_index)
	metadata.slot_id = storage_key
	metadata.display_name = display_name if not display_name.is_empty() else fallback_display_name_for_index(slot_index)
	metadata.save_type = save_type
	metadata.chapter_name = chapter_name
	metadata.location_name = location_name
	metadata.playtime_seconds = playtime_seconds
	metadata.difficulty = difficulty
	metadata.thumbnail_path = thumbnail_path
	_set_metadata_field(metadata, "slot_index", slot_index)
	_set_metadata_field(metadata, "storage_key", storage_key)
	if not slot_role.is_empty():
		_set_metadata_field(metadata, "slot_role", slot_role)
	return metadata


func build_empty_card(slot_index: int) -> Resource:
	return _new_card_from_summary(
		slot_index,
		slot_id_for_index(slot_index),
		fallback_display_name_for_index(slot_index),
		{},
		active_slot_index
	)


func build_card_for_index(slot_index: int, summary: Dictionary = {}) -> Resource:
	return _new_card_from_summary(
		slot_index,
		slot_id_for_index(slot_index),
		fallback_display_name_for_index(slot_index),
		summary,
		active_slot_index
	)


func build_cards_for_indices(slot_indices: PackedInt32Array, summaries: Array = []) -> Array:
	var summaries_by_slot_id: Dictionary = {}
	for summary_variant in summaries:
		if not (summary_variant is Dictionary):
			continue
		var summary: Dictionary = summary_variant
		var summary_slot_id := String(summary.get("slot_id", ""))
		if not summary_slot_id.is_empty():
			summaries_by_slot_id[summary_slot_id] = summary

	var cards: Array = []
	for slot_index in slot_indices:
		var slot_id := slot_id_for_index(slot_index)
		cards.append(build_card_for_index(slot_index, Dictionary(summaries_by_slot_id.get(slot_id, {}))))
	return cards


func _new_card_from_summary(
	slot_index_value: int,
	fallback_slot_id: String,
	fallback_display_name: String,
	summary: Dictionary = {},
	active_slot_index_value: int = -1
) -> Resource:
	var card: Resource = SaveFlowSlotCardScript.new()
	card.set("slot_index", slot_index_value)
	card.set("slot_id", fallback_slot_id)
	card.set("display_name", fallback_display_name)
	card.set("is_active", slot_index_value == active_slot_index_value)
	if not summary.is_empty():
		card.call("apply_summary", summary)
	return card


func _new_metadata() -> SaveFlowSlotMetadata:
	var script_to_use := metadata_script if metadata_script != null else SaveFlowSlotMetadataScript
	var candidate: Variant = script_to_use.new()
	if candidate is SaveFlowSlotMetadata:
		return candidate as SaveFlowSlotMetadata
	push_warning("SaveFlowSlotWorkflow metadata_script must create SaveFlowSlotMetadata. Falling back to SaveFlowSlotMetadata.")
	return SaveFlowSlotMetadataScript.new()


func _set_metadata_field(metadata: SaveFlowSlotMetadata, field_id: String, value: Variant) -> void:
	if _has_storage_property(metadata, field_id):
		metadata.set(field_id, value)
	else:
		metadata.custom_metadata[field_id] = value


func _has_storage_property(target: Object, property_name: String) -> bool:
	for property_info_variant in target.get_property_list():
		if not (property_info_variant is Dictionary):
			continue
		var property_info: Dictionary = property_info_variant
		if String(property_info.get("name", "")) != property_name:
			continue
		var usage := int(property_info.get("usage", 0))
		return (usage & PROPERTY_USAGE_STORAGE) != 0
	return false


func _format_indexed_text(template: String, slot_index: int, fallback: String) -> String:
	var normalized := template.strip_edges()
	if normalized.is_empty():
		return fallback
	return normalized.replace("{index}", str(slot_index)).replace("%d", str(slot_index))
