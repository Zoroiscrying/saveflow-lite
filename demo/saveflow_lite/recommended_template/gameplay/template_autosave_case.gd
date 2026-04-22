extends Control

const MANUAL_SLOT_ID := "manual_save"
const AUTOSAVE_SLOT_ID := "autosave_latest"
const CHECKPOINT_SLOT_ID := "checkpoint_latest"

var _chapter_name := "Chapter 2"
var _location_name := "Town Gate"
var _playtime_seconds := 900
var _coins := 12
var _saving_blocked := false

@onready var _state_label: Label = $MarginContainer/PanelContainer/Content/StateLabel
@onready var _summary_list: ItemList = $MarginContainer/PanelContainer/Content/Body/SummaryList
@onready var _summary_output: TextEdit = $MarginContainer/PanelContainer/Content/Body/DetailColumn/SummaryOutput
@onready var _status_output: TextEdit = $MarginContainer/PanelContainer/Content/Body/DetailColumn/StatusOutput
@onready var _toggle_busy_button: Button = $MarginContainer/PanelContainer/Content/Buttons/ToggleBusyButton


func _ready() -> void:
	_configure_runtime()
	_bind_buttons()
	_refresh_ui(false)
	_set_status("Autosave case ready. Trigger gameplay events to write autosave, checkpoint, and manual-save slots.")


func _configure_runtime() -> void:
	SaveFlow.configure_with(
		"user://recommended_cases/autosave/saves",
		"user://recommended_cases/autosave/slots.index"
	)


func _bind_buttons() -> void:
	$MarginContainer/PanelContainer/Content/Buttons/DoorTransitionButton.pressed.connect(_on_door_transition_pressed)
	$MarginContainer/PanelContainer/Content/Buttons/ShrineButton.pressed.connect(_on_shrine_pressed)
	$MarginContainer/PanelContainer/Content/Buttons/ManualSaveButton.pressed.connect(_on_manual_save_pressed)
	$MarginContainer/PanelContainer/Content/Buttons/ToggleBusyButton.pressed.connect(_on_toggle_busy_pressed)
	$MarginContainer/PanelContainer/Content/Buttons/RefreshButton.pressed.connect(func() -> void: _refresh_ui(true))
	$MarginContainer/PanelContainer/Content/Buttons/ResetButton.pressed.connect(_on_reset_pressed)
	_summary_list.item_selected.connect(_on_summary_selected)


func _on_door_transition_pressed() -> void:
	_location_name = "Forest Gate" if _location_name == "Town Gate" else "Town Gate"
	_playtime_seconds += 45
	_coins += 2
	if not _can_save_now("autosave after a room transition"):
		_refresh_ui(false)
		return
	var result := _save_business_slot(
		AUTOSAVE_SLOT_ID,
		"autosave",
		"Door transition autosave",
		{
			"trigger": "door_transition",
		}
	)
	_set_status(_format_result("Autosave", result))
	_refresh_ui(false)


func _on_shrine_pressed() -> void:
	_chapter_name = "Chapter 3" if _chapter_name == "Chapter 2" else "Chapter 2"
	_location_name = "Shrine"
	_playtime_seconds += 90
	_coins += 5
	if not _can_save_now("checkpoint save at a shrine"):
		_refresh_ui(false)
		return
	var result := _save_business_slot(
		CHECKPOINT_SLOT_ID,
		"checkpoint",
		"Shrine checkpoint",
		{
			"trigger": "shrine_checkpoint",
		}
	)
	_set_status(_format_result("Checkpoint", result))
	_refresh_ui(false)


func _on_manual_save_pressed() -> void:
	_playtime_seconds += 15
	if not _can_save_now("manual save from a pause menu"):
		_refresh_ui(false)
		return
	var result := _save_business_slot(
		MANUAL_SLOT_ID,
		"manual",
		"Manual save",
		{
			"trigger": "pause_menu",
		}
	)
	_set_status(_format_result("Manual Save", result))
	_refresh_ui(false)


func _on_toggle_busy_pressed() -> void:
	_saving_blocked = not _saving_blocked
	_set_status(
		"Saving is now %s. This demonstrates project-owned gating before SaveFlow entry points are called." %
		("blocked" if _saving_blocked else "allowed")
	)
	_refresh_ui(false)


func _on_reset_pressed() -> void:
	for slot_id in [MANUAL_SLOT_ID, AUTOSAVE_SLOT_ID, CHECKPOINT_SLOT_ID]:
		if SaveFlow.slot_exists(slot_id):
			SaveFlow.delete_slot(slot_id)
	_chapter_name = "Chapter 2"
	_location_name = "Town Gate"
	_playtime_seconds = 900
	_coins = 12
	_saving_blocked = false
	_refresh_ui(false)
	_set_status("Reset autosave/checkpoint demo slots and restored the local gameplay state.")


func _on_summary_selected(index: int) -> void:
	var summaries_result: SaveResult = SaveFlow.list_slot_summaries()
	if not summaries_result.ok:
		return
	if index < 0 or index >= summaries_result.data.size():
		return
	var summary: Dictionary = summaries_result.data[index]
	_render_summary(summary)


func _can_save_now(reason: String) -> bool:
	if not _saving_blocked:
		return true
	_set_status("Skipped %s because gameplay marked the scene as unstable for saving." % reason)
	return false


func _save_business_slot(slot_id: String, save_type: String, display_name: String, custom_metadata: Dictionary) -> SaveResult:
	var meta := SaveFlow.build_slot_metadata(
		display_name,
		save_type,
		_chapter_name,
		_location_name,
		_playtime_seconds,
		"normal",
		"",
		{"scene_path": scene_file_path}
	)
	for key in custom_metadata.keys():
		meta[key] = custom_metadata[key]
	return SaveFlow.save_data(slot_id, _build_payload(), meta)


func _build_payload() -> Dictionary:
	return {
		"chapter_name": _chapter_name,
		"location_name": _location_name,
		"playtime_seconds": _playtime_seconds,
		"coins": _coins,
	}


func _refresh_ui(announce: bool) -> void:
	_refresh_state_label()
	_toggle_busy_button.text = "Saving: %s" % ("Blocked" if _saving_blocked else "Allowed")
	_summary_list.clear()
	_summary_output.text = ""

	var summaries_result: SaveResult = SaveFlow.list_slot_summaries()
	if not summaries_result.ok:
		if announce:
			_set_status("Summary refresh failed: %s (%s)" % [summaries_result.error_message, summaries_result.error_key])
		return

	for summary_variant in summaries_result.data:
		var summary: Dictionary = summary_variant
		_summary_list.add_item(
			"%s | %s | %s" % [
				String(summary.get("display_name", "")),
				String(summary.get("save_type", "")),
				String(summary.get("location_name", "")),
			]
		)

	if not summaries_result.data.is_empty():
		_summary_list.select(0)
		_render_summary(summaries_result.data[0])

	if announce:
		_set_status("Refreshed the autosave/checkpoint slot list from slot summaries.")


func _render_summary(summary: Dictionary) -> void:
	var compatibility_report := _as_dictionary(summary.get("compatibility_report", {}))
	var custom_metadata := _as_dictionary(summary.get("custom_metadata", {}))
	_summary_output.text = "\n".join(
		[
			"Selected Save Summary",
			"Slot: %s" % String(summary.get("slot_id", "")),
			"Display Name: %s" % String(summary.get("display_name", "")),
			"Save Type: %s" % String(summary.get("save_type", "")),
			"Chapter: %s" % String(summary.get("chapter_name", "")),
			"Location: %s" % String(summary.get("location_name", "")),
			"Playtime Seconds: %d" % int(summary.get("playtime_seconds", 0)),
			"Compatibility: %s" % ("OK" if bool(compatibility_report.get("compatible", true)) else "Migration required"),
			"Custom Metadata: %s" % (JSON.stringify(custom_metadata) if not custom_metadata.is_empty() else "{}"),
		]
	)


func _refresh_state_label() -> void:
	_state_label.text = "Gameplay State: chapter=%s | location=%s | playtime=%ds | coins=%d | saving=%s" % [
		_chapter_name,
		_location_name,
		_playtime_seconds,
		_coins,
		"blocked" if _saving_blocked else "allowed",
	]


func _format_result(label: String, result: SaveResult) -> String:
	if result.ok:
		return "%s OK" % label
	return "%s failed: %s (%s)" % [label, result.error_message, result.error_key]


func _set_status(message: String) -> void:
	_status_output.text = message


func _as_dictionary(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}
