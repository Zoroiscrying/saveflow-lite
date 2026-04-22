extends Control

const SUMMARY_SAVE_ROOT := "user://recommended_cases/slot_summary/saves"
const SUMMARY_SLOT_INDEX := "user://recommended_cases/slot_summary/slots.index"

var _slot_ids: Array[String] = []

@onready var _summary_list: ItemList = $MarginContainer/PanelContainer/Content/Body/SummaryList
@onready var _summary_output: TextEdit = $MarginContainer/PanelContainer/Content/Body/DetailColumn/SummaryOutput
@onready var _status_output: TextEdit = $MarginContainer/PanelContainer/Content/Body/DetailColumn/StatusOutput


func _ready() -> void:
	_configure_runtime()
	_bind_buttons()
	_refresh_summaries(false)
	_set_status("Slot Summary case ready. Seed a few saves, then use list_slot_summaries() to drive the UI without loading full payloads.")


func _configure_runtime() -> void:
	SaveFlow.configure_with(SUMMARY_SAVE_ROOT, SUMMARY_SLOT_INDEX)


func _bind_buttons() -> void:
	$MarginContainer/PanelContainer/Content/Buttons/SeedButton.pressed.connect(_on_seed_pressed)
	$MarginContainer/PanelContainer/Content/Buttons/RefreshButton.pressed.connect(func() -> void: _refresh_summaries(true))
	$MarginContainer/PanelContainer/Content/Buttons/LoadPayloadButton.pressed.connect(_on_load_payload_pressed)
	$MarginContainer/PanelContainer/Content/Buttons/ResetButton.pressed.connect(_on_reset_pressed)
	_summary_list.item_selected.connect(_on_summary_selected)


func _on_seed_pressed() -> void:
	var definitions := [
		{
			"slot_id": "manual_forest_gate",
			"payload": {
				"player": {"hp": 8, "coins": 17},
				"room": "forest_gate",
			},
			"meta": SaveFlow.build_slot_metadata(
				"Forest Gate",
				"manual",
				"Chapter 2",
				"Forest Gate",
				1320,
				"normal",
				"",
				{"scene_path": scene_file_path}
			),
		},
		{
			"slot_id": "autosave_cave_entrance",
			"payload": {
				"player": {"hp": 6, "coins": 25},
				"room": "cave_entrance",
			},
			"meta": SaveFlow.build_slot_metadata(
				"Cave Entrance",
				"autosave",
				"Chapter 2",
				"Cave Entrance",
				1480,
				"normal",
				"",
				{"scene_path": scene_file_path}
			),
		},
		{
			"slot_id": "checkpoint_boss_gate",
			"payload": {
				"player": {"hp": 5, "coins": 33},
				"room": "boss_gate",
			},
			"meta": SaveFlow.build_slot_metadata(
				"Boss Gate",
				"checkpoint",
				"Chapter 3",
				"Boss Gate",
				2015,
				"hard",
				"",
				{"scene_path": scene_file_path}
			),
		},
	]

	for definition_variant in definitions:
		var definition: Dictionary = definition_variant
		var save_result: SaveResult = SaveFlow.save_data(
			String(definition["slot_id"]),
			definition["payload"],
			definition["meta"]
		)
		if not save_result.ok:
			_set_status("Seed failed: %s (%s)" % [save_result.error_message, save_result.error_key])
			return

	_refresh_summaries(false)
	_set_status("Seeded 3 sample slots. The list is built from slot summaries, not from full gameplay payload loads.")


func _on_load_payload_pressed() -> void:
	var slot_id := _get_selected_slot_id()
	if slot_id.is_empty():
		_set_status("Select one slot first. Summary reads and full payload loads are separate steps.")
		return

	var load_result: SaveResult = SaveFlow.load_data(slot_id)
	if not load_result.ok:
		_set_status("Load payload failed: %s (%s)" % [load_result.error_message, load_result.error_key])
		return

	var payload_text := JSON.stringify(load_result.data, "\t")
	_summary_output.text += "\n\nLoaded Payload:\n%s" % payload_text
	_set_status("Loaded full payload for `%s`. Use this only when the player actually enters the slot, not to draw the save list." % slot_id)


func _on_reset_pressed() -> void:
	var list_result: SaveResult = SaveFlow.list_slot_summaries()
	if not list_result.ok:
		_refresh_summaries(false)
		_set_status("Reset skipped. No summary list was available.")
		return

	for summary_variant in list_result.data:
		var summary: Dictionary = summary_variant
		var slot_id := String(summary.get("slot_id", ""))
		if slot_id.is_empty():
			continue
		SaveFlow.delete_slot(slot_id)

	_refresh_summaries(false)
	_set_status("Removed all demo slots from the slot-summary case.")


func _on_summary_selected(index: int) -> void:
	if index < 0 or index >= _slot_ids.size():
		return
	_show_summary(_slot_ids[index])


func _refresh_summaries(announce: bool) -> void:
	_slot_ids.clear()
	_summary_list.clear()
	_summary_output.text = ""

	var list_result: SaveResult = SaveFlow.list_slot_summaries()
	if not list_result.ok:
		if announce:
			_set_status("Summary refresh failed: %s (%s)" % [list_result.error_message, list_result.error_key])
		return

	for summary_variant in list_result.data:
		var summary: Dictionary = summary_variant
		var slot_id := String(summary.get("slot_id", ""))
		if slot_id.is_empty():
			continue
		_slot_ids.append(slot_id)
		_summary_list.add_item(_format_summary_row(summary))

	if not _slot_ids.is_empty():
		_summary_list.select(0)
		_show_summary(_slot_ids[0])

	if announce:
		_set_status("Refreshed %d slot summaries. These rows come from metadata, not from full restore payloads." % _slot_ids.size())


func _show_summary(slot_id: String) -> void:
	var summary_result: SaveResult = SaveFlow.read_slot_summary(slot_id)
	if not summary_result.ok:
		_summary_output.text = "Summary read failed: %s (%s)" % [summary_result.error_message, summary_result.error_key]
		return

	var summary: Dictionary = summary_result.data
	var compatibility_report := _as_dictionary(summary.get("compatibility_report", {}))
	var custom_metadata := _as_dictionary(summary.get("custom_metadata", {}))

	_summary_output.text = "\n".join(
		[
			"Selected Slot Summary",
			"Slot: %s" % String(summary.get("slot_id", "")),
			"Display Name: %s" % String(summary.get("display_name", "")),
			"Save Type: %s" % String(summary.get("save_type", "")),
			"Chapter: %s" % String(summary.get("chapter_name", "")),
			"Location: %s" % String(summary.get("location_name", "")),
			"Playtime Seconds: %d" % int(summary.get("playtime_seconds", 0)),
			"Difficulty: %s" % String(summary.get("difficulty", "")),
			"Scene Path: %s" % String(summary.get("scene_path", "")),
			"Compatibility: %s" % ("OK" if bool(compatibility_report.get("compatible", true)) else "Migration required"),
			"Custom Metadata: %s" % (JSON.stringify(custom_metadata) if not custom_metadata.is_empty() else "{}"),
		]
	)


func _get_selected_slot_id() -> String:
	var selected := _summary_list.get_selected_items()
	if selected.is_empty():
		return ""
	var index := int(selected[0])
	if index < 0 or index >= _slot_ids.size():
		return ""
	return _slot_ids[index]


func _format_summary_row(summary: Dictionary) -> String:
	return "%s | %s | %s | %s" % [
		String(summary.get("display_name", "")),
		String(summary.get("save_type", "")),
		String(summary.get("chapter_name", "")),
		String(summary.get("location_name", "")),
	]


func _set_status(message: String) -> void:
	_status_output.text = message


func _as_dictionary(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}
