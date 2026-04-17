## SaveFlow Lite's project settings dock. This panel is for project-wide save
## defaults such as format, slot metadata, and write behavior, not per-source
## overrides.
@tool
extends VBoxContainer

const PANEL_PADDING := 12
const LABEL_WIDTH := 132
const SaveFlowProjectSettingsScript := preload("res://addons/saveflow_core/runtime/core/saveflow_project_settings.gd")

signal open_save_manager_requested

var _format_option: OptionButton
var _save_root_edit: LineEdit
var _slot_index_edit: LineEdit
var _json_extension_edit: LineEdit
var _binary_extension_edit: LineEdit
var _project_title_edit: LineEdit
var _game_version_edit: LineEdit
var _save_schema_edit: LineEdit
var _data_version_spin: SpinBox
var _pretty_json_check: CheckBox
var _safe_write_check: CheckBox
var _auto_create_dirs_check: CheckBox
var _include_meta_check: CheckBox
var _log_level_option: OptionButton
var _status_label: Label


func _ready() -> void:
	_build_ui()
	reload_from_project_settings()


## Reload the current project defaults from ProjectSettings into the dock UI.
func reload_from_project_settings() -> void:
	var settings := SaveFlowProjectSettingsScript.load_settings()
	_apply_settings_to_fields(settings)
	_set_status("Loaded project defaults.")


## Persist the dock values back into ProjectSettings and immediately reconfigure
## the editor runtime singleton if it exists.
func save_to_project_settings() -> void:
	var settings := _build_settings_from_fields()
	SaveFlowProjectSettingsScript.save_settings(settings)
	_apply_runtime_settings(settings)
	_set_status("Saved project defaults.")


## Reset the project-wide SaveFlow Lite defaults to the shipped baseline.
func reset_to_defaults() -> void:
	var settings := SaveFlowProjectSettingsScript.reset_to_defaults()
	_apply_settings_to_fields(settings)
	_apply_runtime_settings(settings)
	_set_status("Reset to defaults.")


func _build_ui() -> void:
	if _status_label != null:
		return

	add_theme_constant_override("separation", 10)

	var header := Label.new()
	header.text = "SaveFlow Lite Settings"
	header.add_theme_font_size_override("font_size", 18)
	add_child(header)

	var description := Label.new()
	description.text = "Manage project-wide save format, metadata defaults, and slot behavior in one place."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.modulate = get_theme_color("font_placeholder_color", "Editor")
	add_child(description)

	var open_manager_button := Button.new()
	open_manager_button.text = "Open DevSaveManager"
	open_manager_button.pressed.connect(_on_open_save_manager_pressed)
	add_child(open_manager_button)

	add_child(_build_section("Storage", _build_storage_section()))
	add_child(_build_section("Metadata", _build_metadata_section()))
	add_child(_build_section("Behavior", _build_behavior_section()))

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	add_child(actions)

	var save_button := Button.new()
	save_button.text = "Save"
	save_button.pressed.connect(save_to_project_settings)
	actions.add_child(save_button)

	var reload_button := Button.new()
	reload_button.text = "Reload"
	reload_button.pressed.connect(reload_from_project_settings)
	actions.add_child(reload_button)

	var reset_button := Button.new()
	reset_button.text = "Reset Defaults"
	reset_button.pressed.connect(reset_to_defaults)
	actions.add_child(reset_button)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.modulate = get_theme_color("font_placeholder_color", "Editor")
	add_child(_status_label)


func _build_storage_section() -> VBoxContainer:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)

	_format_option = OptionButton.new()
	_format_option.add_item("Auto", 0)
	_format_option.add_item("JSON", 1)
	_format_option.add_item("Binary", 2)
	_add_labeled_control(content, "Save format", _format_option)

	_save_root_edit = LineEdit.new()
	_add_labeled_control(content, "Save root", _save_root_edit)

	_slot_index_edit = LineEdit.new()
	_add_labeled_control(content, "Slot index", _slot_index_edit)

	_json_extension_edit = LineEdit.new()
	_add_labeled_control(content, "JSON ext", _json_extension_edit)

	_binary_extension_edit = LineEdit.new()
	_add_labeled_control(content, "Binary ext", _binary_extension_edit)
	return content


func _build_metadata_section() -> VBoxContainer:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)

	_project_title_edit = LineEdit.new()
	_add_labeled_control(content, "Project title", _project_title_edit)

	_game_version_edit = LineEdit.new()
	_add_labeled_control(content, "Game version", _game_version_edit)

	_save_schema_edit = LineEdit.new()
	_add_labeled_control(content, "Save schema", _save_schema_edit)

	_data_version_spin = SpinBox.new()
	_data_version_spin.min_value = 1
	_data_version_spin.max_value = 1000
	_data_version_spin.step = 1
	_data_version_spin.rounded = true
	_add_labeled_control(content, "Data version", _data_version_spin)
	return content


func _build_behavior_section() -> VBoxContainer:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)

	_pretty_json_check = CheckBox.new()
	_pretty_json_check.text = "Pretty JSON in editor"
	content.add_child(_pretty_json_check)

	_safe_write_check = CheckBox.new()
	_safe_write_check.text = "Use safe write"
	content.add_child(_safe_write_check)

	_auto_create_dirs_check = CheckBox.new()
	_auto_create_dirs_check.text = "Auto-create directories"
	content.add_child(_auto_create_dirs_check)

	_include_meta_check = CheckBox.new()
	_include_meta_check.text = "Include meta in slot index"
	content.add_child(_include_meta_check)

	_log_level_option = OptionButton.new()
	_log_level_option.add_item("Quiet", 0)
	_log_level_option.add_item("Error", 1)
	_log_level_option.add_item("Info", 2)
	_log_level_option.add_item("Verbose", 3)
	_add_labeled_control(content, "Log level", _log_level_option)
	return content


func _build_section(title: String, content: Control) -> Control:
	var panel := PanelContainer.new()

	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", PANEL_PADDING)
	padding.add_theme_constant_override("margin_top", PANEL_PADDING)
	padding.add_theme_constant_override("margin_right", PANEL_PADDING)
	padding.add_theme_constant_override("margin_bottom", PANEL_PADDING)
	panel.add_child(padding)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	padding.add_child(box)

	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 15)
	box.add_child(label)
	box.add_child(content)
	return panel


func _add_labeled_control(parent: VBoxContainer, label_text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = LABEL_WIDTH
	label.modulate = get_theme_color("font_placeholder_color", "Editor")
	row.add_child(label)

	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)


func _apply_settings_to_fields(settings: SaveSettings) -> void:
	_select_option_by_id(_format_option, settings.storage_format)
	_save_root_edit.text = settings.save_root
	_slot_index_edit.text = settings.slot_index_file
	_json_extension_edit.text = settings.file_extension_json
	_binary_extension_edit.text = settings.file_extension_binary

	_project_title_edit.text = settings.project_title
	_game_version_edit.text = settings.game_version
	_save_schema_edit.text = settings.save_schema
	_data_version_spin.value = settings.data_version

	_pretty_json_check.button_pressed = settings.pretty_json_in_editor
	_safe_write_check.button_pressed = settings.use_safe_write
	_auto_create_dirs_check.button_pressed = settings.auto_create_dirs
	_include_meta_check.button_pressed = settings.include_meta_in_slot_file
	_select_option_by_id(_log_level_option, settings.log_level)


func _build_settings_from_fields() -> SaveSettings:
	var settings := SaveSettings.new()
	settings.storage_format = _selected_id(_format_option)
	settings.save_root = _save_root_edit.text.strip_edges()
	settings.slot_index_file = _slot_index_edit.text.strip_edges()
	settings.file_extension_json = _json_extension_edit.text.strip_edges()
	settings.file_extension_binary = _binary_extension_edit.text.strip_edges()
	settings.project_title = _project_title_edit.text.strip_edges()
	settings.game_version = _game_version_edit.text.strip_edges()
	settings.save_schema = _save_schema_edit.text.strip_edges()
	settings.data_version = int(_data_version_spin.value)
	settings.pretty_json_in_editor = _pretty_json_check.button_pressed
	settings.use_safe_write = _safe_write_check.button_pressed
	settings.auto_create_dirs = _auto_create_dirs_check.button_pressed
	settings.include_meta_in_slot_file = _include_meta_check.button_pressed
	settings.log_level = _selected_id(_log_level_option)
	return settings


func _apply_runtime_settings(settings: SaveSettings) -> void:
	var main_loop := Engine.get_main_loop()
	if not (main_loop is SceneTree):
		return
	var runtime := (main_loop as SceneTree).root.get_node_or_null("/root/SaveFlow")
	if runtime != null and runtime.has_method("configure"):
		runtime.configure(settings)


func _select_option_by_id(option: OptionButton, value: int) -> void:
	for index in range(option.item_count):
		if option.get_item_id(index) == value:
			option.select(index)
			return
	option.select(0)


func _selected_id(option: OptionButton) -> int:
	var index := option.get_selected()
	if index < 0:
		return 0
	return option.get_item_id(index)


func _set_status(message: String) -> void:
	if _status_label == null:
		return
	_status_label.text = message


func _on_open_save_manager_pressed() -> void:
	open_save_manager_requested.emit()
