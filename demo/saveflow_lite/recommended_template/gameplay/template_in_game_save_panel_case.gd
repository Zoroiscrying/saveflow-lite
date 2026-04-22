extends Control

const SLOT_IDS := ["slot_1", "slot_2", "slot_3"]

var _selected_slot_id := ""
var _pending_action := ""
var _pending_slot_id := ""

var _chapter_name := "Chapter 2"
var _location_name := "Town Gate"
var _playtime_seconds := 960
var _coins := 14

@onready var _state_label: Label = $MarginContainer/PanelContainer/Content/StateLabel
@onready var _slot_list: ItemList = $MarginContainer/PanelContainer/Content/Body/LeftColumn/SlotList
@onready var _summary_output: TextEdit = $MarginContainer/PanelContainer/Content/Body/RightColumn/SummaryOutput
@onready var _status_output: TextEdit = $MarginContainer/PanelContainer/Content/Body/RightColumn/StatusOutput
@onready var _confirm_dialog: ConfirmationDialog = $ConfirmDialog


func _ready() -> void:
	_configure_runtime()
	_bind_buttons()
	_seed_initial_slots()
	_refresh_ui(false)
	_set_status("In-game save panel case ready. This scene demonstrates Continue, Load, Save, Delete, and overwrite confirmation with slot summaries.")


func _configure_runtime() -> void:
	SaveFlow.configure_with(
		"user://recommended_cases/in_game_panel/saves",
		"user://recommended_cases/in_game_panel/slots.index"
	)


func _bind_buttons() -> void:
	$MarginContainer/PanelContainer/Content/Buttons/MutateButton.pressed.connect(_on_mutate_pressed)
	$MarginContainer/PanelContainer/Content/Buttons/ContinueButton.pressed.connect(_on_continue_pressed)
	$MarginContainer/PanelContainer/Content/Buttons/LoadButton.pressed.connect(_on_load_pressed)
	$MarginContainer/PanelContainer/Content/Buttons/SaveButton.pressed.connect(_on_save_pressed)
	$MarginContainer/PanelContainer/Content/Buttons/DeleteButton.pressed.connect(_on_delete_pressed)
	$MarginContainer/PanelContainer/Content/Buttons/RefreshButton.pressed.connect(func() -> void: _refresh_ui(true))
	$MarginContainer/PanelContainer/Content/Buttons/ResetButton.pressed.connect(_on_reset_pressed)
	_slot_list.item_selected.connect(_on_slot_selected)
	_confirm_dialog.confirmed.connect(_on_confirmed)


func _seed_initial_slots() -> void:
	if SaveFlow.slot_exists("slot_1") or SaveFlow.slot_exists("slot_2") or SaveFlow.slot_exists("slot_3"):
		return

	_save_slot_with_payload(
		"slot_1",
		{
			"chapter_name": "Chapter 1",
			"location_name": "Village",
			"playtime_seconds": 420,
			"coins": 5,
		},
		"Village Start",
		"manual"
	)
	_save_slot_with_payload(
		"slot_2",
		{
			"chapter_name": "Chapter 2",
			"location_name": "Forest Gate",
			"playtime_seconds": 1080,
			"coins": 18,
		},
		"Forest Gate",
		"manual"
	)


func _on_mutate_pressed() -> void:
	_chapter_name = "Chapter 3" if _chapter_name == "Chapter 2" else "Chapter 2"
	_location_name = "Boss Gate" if _location_name == "Town Gate" else "Town Gate"
	_playtime_seconds += 75
	_coins += 4
	_refresh_state_label()
	_set_status("Mutated the current gameplay state. Save writes this state into the selected slot.")


func _on_continue_pressed() -> void:
	var summaries_result: SaveResult = SaveFlow.list_slot_summaries()
	if not summaries_result.ok or summaries_result.data.is_empty():
		_set_status("Continue is unavailable because there are no saved slots.")
		return

	var latest_summary: Dictionary = summaries_result.data[0]
	var slot_id := String(latest_summary.get("slot_id", ""))
	if slot_id.is_empty():
		_set_status("Continue is unavailable because the latest slot has no slot_id.")
		return

	_load_slot_into_state(slot_id, "Continue")


func _on_load_pressed() -> void:
	if _selected_slot_id.is_empty():
		_set_status("Select one slot first.")
		return
	_load_slot_into_state(_selected_slot_id, "Load")


func _on_save_pressed() -> void:
	if _selected_slot_id.is_empty():
		_set_status("Select one slot first.")
		return
	if SaveFlow.slot_exists(_selected_slot_id):
		_queue_confirmation(
			"overwrite",
			_selected_slot_id,
			"Overwrite %s?" % _selected_slot_id,
			"This slot already exists. Overwrite it with the current gameplay state?"
		)
		return
	_save_selected_slot()


func _on_delete_pressed() -> void:
	if _selected_slot_id.is_empty():
		_set_status("Select one slot first.")
		return
	if not SaveFlow.slot_exists(_selected_slot_id):
		_set_status("The selected slot does not exist yet.")
		return
	_queue_confirmation(
		"delete",
		_selected_slot_id,
		"Delete %s?" % _selected_slot_id,
		"This removes the slot file and its backup, if one exists."
	)


func _on_reset_pressed() -> void:
	for slot_id in SLOT_IDS:
		if SaveFlow.slot_exists(slot_id):
			SaveFlow.delete_slot(slot_id)
	_chapter_name = "Chapter 2"
	_location_name = "Town Gate"
	_playtime_seconds = 960
	_coins = 14
	_seed_initial_slots()
	_refresh_ui(false)
	_set_status("Reset the in-game panel demo back to its initial slots and gameplay state.")


func _on_slot_selected(index: int) -> void:
	if index < 0 or index >= SLOT_IDS.size():
		return
	_selected_slot_id = SLOT_IDS[index]
	_refresh_slot_summary()


func _on_confirmed() -> void:
	match _pending_action:
		"overwrite":
			_save_selected_slot()
		"delete":
			var delete_result: SaveResult = SaveFlow.delete_slot(_pending_slot_id)
			_set_status(_format_result("Delete", delete_result))
			_refresh_ui(false)
	_pending_action = ""
	_pending_slot_id = ""


func _queue_confirmation(action: String, slot_id: String, title_text: String, body_text: String) -> void:
	_pending_action = action
	_pending_slot_id = slot_id
	_confirm_dialog.title = title_text
	_confirm_dialog.dialog_text = body_text
	_confirm_dialog.popup_centered()


func _save_selected_slot() -> void:
	var save_result := _save_slot_with_payload(
		_selected_slot_id,
		_build_payload(),
		_display_name_for_slot(_selected_slot_id),
		"manual"
	)
	_set_status(_format_result("Save", save_result))
	_refresh_ui(false)


func _save_slot_with_payload(slot_id: String, payload: Dictionary, display_name: String, save_type: String) -> SaveResult:
	var meta := SaveFlow.build_slot_metadata(
		display_name,
		save_type,
		String(payload.get("chapter_name", "")),
		String(payload.get("location_name", "")),
		int(payload.get("playtime_seconds", 0)),
		"normal",
		"",
		{"scene_path": scene_file_path}
	)
	return SaveFlow.save_data(slot_id, payload, meta)


func _load_slot_into_state(slot_id: String, label: String) -> void:
	var load_result: SaveResult = SaveFlow.load_data(slot_id)
	if not load_result.ok:
		_set_status(_format_result(label, load_result))
		return
	var payload := _as_dictionary(load_result.data)
	_apply_payload(payload)
	_refresh_ui(false)
	_set_status("%s OK. The current gameplay state now matches `%s`." % [label, slot_id])


func _build_payload() -> Dictionary:
	return {
		"chapter_name": _chapter_name,
		"location_name": _location_name,
		"playtime_seconds": _playtime_seconds,
		"coins": _coins,
	}


func _apply_payload(payload: Dictionary) -> void:
	_chapter_name = String(payload.get("chapter_name", _chapter_name))
	_location_name = String(payload.get("location_name", _location_name))
	_playtime_seconds = int(payload.get("playtime_seconds", _playtime_seconds))
	_coins = int(payload.get("coins", _coins))


func _refresh_ui(announce: bool) -> void:
	_refresh_state_label()
	_refresh_slot_list()
	_refresh_slot_summary()
	if announce:
		_set_status("Refreshed the in-game save panel from slot summaries.")


func _refresh_state_label() -> void:
	_state_label.text = "Current Gameplay State: chapter=%s | location=%s | playtime=%ds | coins=%d" % [
		_chapter_name,
		_location_name,
		_playtime_seconds,
		_coins,
	]


func _refresh_slot_list() -> void:
	_slot_list.clear()
	for slot_id in SLOT_IDS:
		var row_text := "%s | Empty" % slot_id
		var summary_result: SaveResult = SaveFlow.read_slot_summary(slot_id)
		if summary_result.ok:
			row_text = "%s | %s | %s" % [
				slot_id,
				String(summary_result.data.get("display_name", "")),
				String(summary_result.data.get("location_name", "")),
			]
		_slot_list.add_item(row_text)

	if _selected_slot_id.is_empty():
		_selected_slot_id = SLOT_IDS[0]
	var selected_index := SLOT_IDS.find(_selected_slot_id)
	if selected_index >= 0:
		_slot_list.select(selected_index)


func _refresh_slot_summary() -> void:
	if _selected_slot_id.is_empty():
		_summary_output.text = "Select a slot first."
		return

	var summary_result: SaveResult = SaveFlow.read_slot_summary(_selected_slot_id)
	if not summary_result.ok:
		_summary_output.text = "\n".join(
			[
				"Selected Slot: %s" % _selected_slot_id,
				"State: Empty",
				"Use Save to write the current gameplay state into this slot.",
			]
		)
		return

	var summary: Dictionary = summary_result.data
	var compatibility_report := _as_dictionary(summary.get("compatibility_report", {}))
	_summary_output.text = "\n".join(
		[
			"Selected Slot Summary",
			"Slot: %s" % _selected_slot_id,
			"Display Name: %s" % String(summary.get("display_name", "")),
			"Save Type: %s" % String(summary.get("save_type", "")),
			"Chapter: %s" % String(summary.get("chapter_name", "")),
			"Location: %s" % String(summary.get("location_name", "")),
			"Playtime Seconds: %d" % int(summary.get("playtime_seconds", 0)),
			"Compatibility: %s" % ("OK" if bool(compatibility_report.get("compatible", true)) else "Migration required"),
		]
	)


func _display_name_for_slot(slot_id: String) -> String:
	match slot_id:
		"slot_1":
			return "Save Slot 1"
		"slot_2":
			return "Save Slot 2"
		"slot_3":
			return "Save Slot 3"
		_:
			return slot_id


func _format_result(label: String, result: SaveResult) -> String:
	if result.ok:
		return "%s OK" % label
	return "%s failed: %s (%s)" % [label, result.error_message, result.error_key]


func _set_status(message: String) -> void:
	_status_output.text = message


func _as_dictionary(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}
