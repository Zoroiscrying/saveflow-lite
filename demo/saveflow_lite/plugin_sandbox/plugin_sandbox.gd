extends Control

signal smoke_test_completed(result: Dictionary)

const SLOT_ID := "sandbox_slot"

@onready var _player_state: Node = $StateRoot/PlayerState
@onready var _settings_state: Node = $StateRoot/SettingsState
@onready var _player_label: Label = $MarginContainer/PanelContainer/Content/StateCard/StateList/PlayerLabel
@onready var _settings_label: Label = $MarginContainer/PanelContainer/Content/StateCard/StateList/SettingsLabel
@onready var _slots_label: Label = $MarginContainer/PanelContainer/Content/StateCard/StateList/SlotsLabel
@onready var _status_output: TextEdit = $MarginContainer/PanelContainer/Content/StatusOutput

var saveflow


func _ready() -> void:
	saveflow = SaveFlow
	_configure_runtime()
	_bind_actions()
	_reset_state(false)
	_refresh_ui("Sandbox ready. Click Mutate, Save, then Load to see state recovery.")


func _configure_runtime() -> void:
	saveflow.configure_with(
		"user://plugin_sandbox/saves",
		"user://plugin_sandbox/slots.index"
	)


func _bind_actions() -> void:
	$MarginContainer/PanelContainer/Content/Buttons/SaveButton.pressed.connect(_on_save_pressed)
	$MarginContainer/PanelContainer/Content/Buttons/LoadButton.pressed.connect(_on_load_pressed)
	$MarginContainer/PanelContainer/Content/Buttons/MutateButton.pressed.connect(_on_mutate_pressed)
	$MarginContainer/PanelContainer/Content/Buttons/ListButton.pressed.connect(_on_list_pressed)
	$MarginContainer/PanelContainer/Content/Buttons/DeleteButton.pressed.connect(_on_delete_pressed)
	$MarginContainer/PanelContainer/Content/Buttons/ResetButton.pressed.connect(_on_reset_pressed)


func _on_save_pressed() -> void:
	var result: SaveResult = saveflow.save_scene(
		SLOT_ID,
		$StateRoot,
		{
			"display_name": "Sandbox Slot",
			"scene_path": scene_file_path,
			"game_version": "sandbox",
		}
	)
	_refresh_ui(_format_result("Save", result))


func _on_load_pressed() -> void:
	var result: SaveResult = saveflow.load_scene(SLOT_ID, $StateRoot)
	_refresh_ui(_format_result("Load", result))


func _on_mutate_pressed() -> void:
	_player_state.call("mutate")
	_settings_state.call("mutate")
	_refresh_ui("Local state mutated. Save to persist it, or Load to restore the slot.")


func _on_list_pressed() -> void:
	var result: SaveResult = saveflow.list_slots()
	_refresh_ui(_format_result("List", result))


func _on_delete_pressed() -> void:
	var result: SaveResult = saveflow.delete_slot(SLOT_ID)
	_refresh_ui(_format_result("Delete", result))


func _on_reset_pressed() -> void:
	_reset_state(true)


func _reset_state(refresh := true) -> void:
	_player_state.call("reset_state")
	_settings_state.call("reset_state")
	if refresh:
		_refresh_ui("Local state reset to defaults. Slot file is untouched until you save or delete it.")


func _refresh_ui(message: String) -> void:
	_player_label.text = "Player: %s" % _player_state.call("to_debug_string")
	_settings_label.text = "Settings: %s" % _settings_state.call("to_debug_string")
	_slots_label.text = _build_slots_summary()
	_status_output.text = message


func _build_slots_summary() -> String:
	var result: SaveResult = saveflow.list_slots()
	if not result.ok:
		return "Slots: failed to read index (%s)" % result.error_key

	var slot_names: PackedStringArray = []
	for entry in result.data:
		if entry is Dictionary:
			slot_names.append(str(entry.get("slot_id", "?")))
	if slot_names.is_empty():
		return "Slots: none"
	return "Slots: %s" % ", ".join(slot_names)


func _format_result(action: String, result: SaveResult) -> String:
	if result.ok:
		return "%s succeeded. %s" % [action, JSON.stringify(result.data)]
	return "%s failed: %s (%s)" % [action, result.error_key, result.error_message]


func run_smoke_test() -> Dictionary:
	_reset_state(false)
	var save_result: SaveResult = saveflow.save_scene(
		SLOT_ID,
		$StateRoot,
		{
			"display_name": "Sandbox Slot",
			"scene_path": scene_file_path,
			"game_version": "sandbox",
		}
	)
	_on_mutate_pressed()
	var load_result: SaveResult = saveflow.load_scene(SLOT_ID, $StateRoot)
	var inspect_result: SaveResult = saveflow.inspect_scene($StateRoot)
	var collect_result: SaveResult = saveflow.collect_nodes($StateRoot)
	var result := {
		"save_ok": save_result.ok,
		"load_ok": load_result.ok,
		"inspect_ok": inspect_result.ok,
		"collected": collect_result.data if collect_result.ok else {},
		"slot_path": saveflow.get_slot_path(SLOT_ID).data,
	}
	_refresh_ui(_format_result("SmokeTest", load_result))
	smoke_test_completed.emit(result)
	return result
