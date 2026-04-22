extends Control

const SLOT_ID := "recommended_data_source_case"

@onready var _world_registry: Node = $StateRoot/WorldRegistry
@onready var _world_label: Label = $MarginContainer/PanelContainer/Content/WorldLabel
@onready var _status_output: TextEdit = $MarginContainer/PanelContainer/Content/StatusOutput


func _ready() -> void:
	_configure_runtime()
	_bind_buttons()
	_reset_state(false)
	_ensure_seed_slot()
	_set_status("DataSource case ready. This scene stores one system-owned dictionary through a custom SaveFlowDataSource.")


func _configure_runtime() -> void:
	SaveFlow.configure_with(
		"user://recommended_cases/data_source/saves",
		"user://recommended_cases/data_source/slots.index"
	)


func _bind_buttons() -> void:
	$MarginContainer/PanelContainer/Content/Buttons/SaveButton.pressed.connect(_on_save_pressed)
	$MarginContainer/PanelContainer/Content/Buttons/LoadButton.pressed.connect(_on_load_pressed)
	$MarginContainer/PanelContainer/Content/Buttons/MutateButton.pressed.connect(_on_mutate_pressed)
	$MarginContainer/PanelContainer/Content/Buttons/ResetButton.pressed.connect(_on_reset_pressed)


func _on_save_pressed() -> void:
	var result: SaveResult = SaveFlow.save_scene(
		SLOT_ID,
		$StateRoot,
		{
			"display_name": "DataSource Case",
			"scene_path": scene_file_path,
		}
	)
	_set_status(_format_result("Save", result))


func _on_load_pressed() -> void:
	var result: SaveResult = SaveFlow.load_scene(SLOT_ID, $StateRoot, true)
	_set_status(_format_result("Load", result))


func _on_mutate_pressed() -> void:
	var system_state: Dictionary = _as_dictionary(_world_registry.get("system_state")).duplicate(true)
	var opened_doors: Dictionary = _as_dictionary(system_state.get("opened_doors", {})).duplicate(true)
	opened_doors["cellar_gate"] = true
	system_state["opened_doors"] = opened_doors

	var quest_flags: Dictionary = _as_dictionary(system_state.get("quest_flags", {})).duplicate(true)
	quest_flags["found_map"] = true
	system_state["quest_flags"] = quest_flags
	system_state["pending_mail"] = ["starter_letter", "merchant_note", "boss_warning"]
	_world_registry.set("system_state", system_state)
	_set_status("Mutated one system-owned dictionary. DataSource is the right path because this state does not belong to one authored node.")


func _on_reset_pressed() -> void:
	_reset_state(true)


func _reset_state(announce: bool) -> void:
	_world_registry.call("reset_state")
	_refresh_labels()
	if announce:
		_set_status("Reset the system-owned world registry back to its default state.")


func _refresh_labels() -> void:
	_world_label.text = "World Registry: %s" % _world_registry.call("describe_state")


func _format_result(label: String, result: SaveResult) -> String:
	if result.ok:
		return "%s OK" % label
	return "%s failed: %s (%s)" % [label, result.error_message, result.error_key]


func _set_status(message: String) -> void:
	_status_output.text = message
	_refresh_labels()


func _ensure_seed_slot() -> void:
	if SaveFlow.slot_exists(SLOT_ID):
		return
	SaveFlow.save_scene(
		SLOT_ID,
		$StateRoot,
		{
			"display_name": "DataSource Case",
			"scene_path": scene_file_path,
		}
	)


func _as_dictionary(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}
