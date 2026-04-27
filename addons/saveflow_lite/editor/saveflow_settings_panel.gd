## SaveFlow Lite's project settings dock. This panel is for project-wide save
## defaults such as format, slot metadata, and write behavior, not per-source
## overrides.
@tool
extends VBoxContainer

const PANEL_PADDING := 12
const LABEL_WIDTH := 108
const PROJECT_SETTINGS_SCRIPT_PATH := "res://addons/saveflow_core/runtime/core/saveflow_project_settings.gd"
const SetupHealthScript := preload("res://addons/saveflow_lite/editor/saveflow_setup_health.gd")

signal open_save_manager_requested
signal open_quick_access_requested
signal repair_setup_requested
signal open_addons_folder_requested
signal open_lite_docs_requested

var _content_scroll: ScrollContainer
var _content_root: VBoxContainer
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
var _keep_last_backup_check: CheckBox
var _auto_create_dirs_check: CheckBox
var _include_meta_check: CheckBox
var _enforce_schema_match_check: CheckBox
var _enforce_data_version_match_check: CheckBox
var _verify_scene_path_check: CheckBox
var _log_level_option: OptionButton
var _compatibility_summary_label: Label
var _compatibility_details_label: Label
var _status_label: Label
var _health_summary_label: Label
var _health_hint_label: Label
var _health_details: RichTextLabel
var _health_section_content: Control
var _health_section_toggle_button: Button
var _save_button: Button
var _reload_button: Button
var _reset_button: Button


func _ready() -> void:
	_build_ui()
	reload_from_project_settings()
	refresh_setup_health()


## Reload the current project defaults from ProjectSettings into the dock UI.
func reload_from_project_settings() -> void:
	var project_settings_script := _get_project_settings_script()
	if project_settings_script == null:
		_set_status("SaveFlow core is missing. Cannot load project defaults.")
		refresh_setup_health()
		return
	var settings: SaveSettings = project_settings_script.load_settings()
	_apply_settings_to_fields(settings)
	_set_status("Loaded project defaults.")
	refresh_setup_health()


## Persist the dock values back into ProjectSettings and immediately reconfigure
## the editor runtime singleton if it exists.
func save_to_project_settings() -> void:
	var project_settings_script := _get_project_settings_script()
	if project_settings_script == null:
		_set_status("SaveFlow core is missing. Cannot save project defaults.")
		refresh_setup_health()
		return
	var settings := _build_settings_from_fields()
	project_settings_script.save_settings(settings)
	_apply_runtime_settings(settings)
	_set_status("Saved project defaults.")
	refresh_setup_health()


## Reset the project-wide SaveFlow Lite defaults to the shipped baseline.
func reset_to_defaults() -> void:
	var project_settings_script := _get_project_settings_script()
	if project_settings_script == null:
		_set_status("SaveFlow core is missing. Cannot reset project defaults.")
		refresh_setup_health()
		return
	var settings: SaveSettings = project_settings_script.reset_to_defaults()
	_apply_settings_to_fields(settings)
	_apply_runtime_settings(settings)
	_set_status("Reset to defaults.")
	refresh_setup_health()


## Re-run the lightweight setup diagnostics shown in the Settings dock.
func refresh_setup_health() -> void:
	var report := SetupHealthScript.inspect_setup()
	if _health_summary_label != null:
		_health_summary_label.text = String(report.get("summary", ""))
		var warning_count := int(report.get("warning_count", 0))
		if bool(report.get("healthy", false)) and warning_count == 0:
			_health_summary_label.modulate = Color(0.60, 0.92, 0.70)
		elif bool(report.get("healthy", false)):
			_health_summary_label.modulate = Color(0.95, 0.82, 0.46)
		else:
			_health_summary_label.modulate = Color(0.96, 0.54, 0.54)

	if _health_hint_label != null:
		_health_hint_label.text = _build_setup_hint_text(report)
		_health_hint_label.modulate = get_theme_color("font_placeholder_color", "Editor")

	if _health_details != null:
		_health_details.clear()
		for check in report.get("checks", []):
			var state := String(check.get("state", "warning"))
			var title := String(check.get("title", "Check"))
			var detail := String(check.get("detail", ""))
			var prefix := "[OK]"
			var color := "#93d4a5"
			if state == "warning":
				prefix = "[Warn]"
				color = "#f0c96a"
			elif state == "error":
				prefix = "[Error]"
				color = "#f08b8b"
			_health_details.append_text("%s %s\n" % [prefix, title])
			_health_details.push_color(Color.from_string(color, Color.WHITE))
			_health_details.append_text("    %s\n\n" % detail)
			_health_details.pop()

	var can_edit_project_settings := _get_project_settings_script() != null
	if _save_button != null:
		_save_button.disabled = not can_edit_project_settings
	if _reload_button != null:
		_reload_button.disabled = not can_edit_project_settings
	if _reset_button != null:
		_reset_button.disabled = not can_edit_project_settings


## Show a status message from the plugin when a quick action finishes.
func show_status_message(message: String) -> void:
	_set_status(message)


func focus_primary_input() -> void:
	if _save_root_edit == null or not is_instance_valid(_save_root_edit):
		return
	_save_root_edit.grab_focus()


func _build_ui() -> void:
	if _status_label != null:
		return

	add_theme_constant_override("separation", 10)
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	_content_scroll = ScrollContainer.new()
	_content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_content_scroll)

	_content_root = VBoxContainer.new()
	_content_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_root.add_theme_constant_override("separation", 10)
	_content_scroll.add_child(_content_root)

	var header := Label.new()
	header.text = "SaveFlow Lite Settings"
	header.add_theme_font_size_override("font_size", 18)
	_content_root.add_child(header)

	var description := Label.new()
	description.text = "Manage project-wide save format, metadata defaults, and slot behavior in one place."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.modulate = get_theme_color("font_placeholder_color", "Editor")
	_content_root.add_child(description)

	var launcher_buttons := HBoxContainer.new()
	launcher_buttons.add_theme_constant_override("separation", 8)
	_content_root.add_child(launcher_buttons)

	var open_quick_access_button := Button.new()
	open_quick_access_button.text = "Open Quick Access"
	open_quick_access_button.pressed.connect(_on_open_quick_access_pressed)
	launcher_buttons.add_child(open_quick_access_button)

	var open_manager_button := Button.new()
	open_manager_button.text = "Open DevSaveManager"
	open_manager_button.pressed.connect(_on_open_save_manager_pressed)
	launcher_buttons.add_child(open_manager_button)

	_content_root.add_child(_build_collapsible_section("Setup Health", _build_setup_health_section(), false))
	_content_root.add_child(_build_section("Storage", _build_storage_section()))
	_content_root.add_child(_build_section("Metadata", _build_metadata_section()))
	_content_root.add_child(_build_section("Behavior", _build_behavior_section()))
	_content_root.add_child(_build_section("Compatibility", _build_compatibility_section()))

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	_content_root.add_child(actions)

	_save_button = Button.new()
	_save_button.text = "Save"
	_save_button.pressed.connect(save_to_project_settings)
	actions.add_child(_save_button)

	_reload_button = Button.new()
	_reload_button.text = "Reload"
	_reload_button.pressed.connect(reload_from_project_settings)
	actions.add_child(_reload_button)

	_reset_button = Button.new()
	_reset_button.text = "Reset Defaults"
	_reset_button.pressed.connect(reset_to_defaults)
	actions.add_child(_reset_button)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.modulate = get_theme_color("font_placeholder_color", "Editor")
	_content_root.add_child(_status_label)


func _build_setup_health_section() -> VBoxContainer:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	_health_section_content = content

	_health_summary_label = Label.new()
	_health_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_health_summary_label)

	_health_hint_label = Label.new()
	_health_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_health_hint_label)

	_health_details = RichTextLabel.new()
	_health_details.fit_content = false
	_health_details.bbcode_enabled = false
	_health_details.scroll_active = true
	_health_details.selection_enabled = true
	_health_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_health_details.custom_minimum_size.y = 220
	content.add_child(_health_details)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	content.add_child(actions)

	var repair_button := Button.new()
	repair_button.text = "Repair SaveFlow Setup"
	repair_button.pressed.connect(_on_repair_setup_pressed)
	actions.add_child(repair_button)

	var open_addons_button := Button.new()
	open_addons_button.text = "Open addons Folder"
	open_addons_button.pressed.connect(_on_open_addons_folder_pressed)
	actions.add_child(open_addons_button)

	var open_docs_button := Button.new()
	open_docs_button.text = "Open Lite Docs"
	open_docs_button.pressed.connect(_on_open_lite_docs_pressed)
	actions.add_child(open_docs_button)

	var recheck_button := Button.new()
	recheck_button.text = "Recheck Setup"
	recheck_button.pressed.connect(refresh_setup_health)
	actions.add_child(recheck_button)

	return content


func _build_collapsible_section(title: String, content: Control, expanded: bool) -> Control:
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

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	box.add_child(header)

	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 15)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)

	_health_section_toggle_button = Button.new()
	_health_section_toggle_button.toggle_mode = true
	_health_section_toggle_button.button_pressed = expanded
	_health_section_toggle_button.toggled.connect(_on_health_section_toggled)
	header.add_child(_health_section_toggle_button)

	box.add_child(content)
	_on_health_section_toggled(expanded)
	return panel


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
	_game_version_edit.text_changed.connect(func(_value: String) -> void: _refresh_compatibility_summary())
	_add_labeled_control(content, "Game version", _game_version_edit)

	_save_schema_edit = LineEdit.new()
	_save_schema_edit.text_changed.connect(func(_value: String) -> void: _refresh_compatibility_summary())
	_add_labeled_control(content, "Save schema", _save_schema_edit)

	_data_version_spin = SpinBox.new()
	_data_version_spin.min_value = 1
	_data_version_spin.max_value = 1000
	_data_version_spin.step = 1
	_data_version_spin.rounded = true
	_data_version_spin.value_changed.connect(func(_value: float) -> void: _refresh_compatibility_summary())
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

	_keep_last_backup_check = CheckBox.new()
	_keep_last_backup_check.text = "Keep last backup"
	content.add_child(_keep_last_backup_check)

	_auto_create_dirs_check = CheckBox.new()
	_auto_create_dirs_check.text = "Auto-create directories"
	content.add_child(_auto_create_dirs_check)

	_include_meta_check = CheckBox.new()
	_include_meta_check.text = "Include meta in slot index"
	content.add_child(_include_meta_check)

	_enforce_schema_match_check = CheckBox.new()
	_enforce_schema_match_check.text = "Enforce save schema match on load"
	_enforce_schema_match_check.toggled.connect(func(_pressed: bool) -> void: _refresh_compatibility_summary())
	content.add_child(_enforce_schema_match_check)

	_enforce_data_version_match_check = CheckBox.new()
	_enforce_data_version_match_check.text = "Enforce data version match on load"
	_enforce_data_version_match_check.toggled.connect(func(_pressed: bool) -> void: _refresh_compatibility_summary())
	content.add_child(_enforce_data_version_match_check)

	_verify_scene_path_check = CheckBox.new()
	_verify_scene_path_check.text = "Verify scene path on scene/scope load"
	_verify_scene_path_check.toggled.connect(func(_pressed: bool) -> void: _refresh_compatibility_summary())
	content.add_child(_verify_scene_path_check)

	_log_level_option = OptionButton.new()
	_log_level_option.add_item("Quiet", 0)
	_log_level_option.add_item("Error", 1)
	_log_level_option.add_item("Info", 2)
	_log_level_option.add_item("Verbose", 3)
	_add_labeled_control(content, "Log level", _log_level_option)
	return content


func _build_compatibility_section() -> VBoxContainer:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)

	_compatibility_summary_label = Label.new()
	_compatibility_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_compatibility_summary_label)

	_compatibility_details_label = Label.new()
	_compatibility_details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_compatibility_details_label.modulate = get_theme_color("font_placeholder_color", "Editor")
	content.add_child(_compatibility_details_label)

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
	_keep_last_backup_check.button_pressed = settings.keep_last_backup
	_auto_create_dirs_check.button_pressed = settings.auto_create_dirs
	_include_meta_check.button_pressed = settings.include_meta_in_slot_file
	_enforce_schema_match_check.button_pressed = settings.enforce_save_schema_match
	_enforce_data_version_match_check.button_pressed = settings.enforce_data_version_match
	_verify_scene_path_check.button_pressed = settings.verify_scene_path_on_load
	_select_option_by_id(_log_level_option, settings.log_level)
	_refresh_compatibility_summary()


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
	settings.keep_last_backup = _keep_last_backup_check.button_pressed
	settings.auto_create_dirs = _auto_create_dirs_check.button_pressed
	settings.include_meta_in_slot_file = _include_meta_check.button_pressed
	settings.enforce_save_schema_match = _enforce_schema_match_check.button_pressed
	settings.enforce_data_version_match = _enforce_data_version_match_check.button_pressed
	settings.verify_scene_path_on_load = _verify_scene_path_check.button_pressed
	settings.log_level = _selected_id(_log_level_option)
	return settings


func _refresh_compatibility_summary() -> void:
	if _compatibility_summary_label == null or _compatibility_details_label == null:
		return

	var enforced_checks: PackedStringArray = []
	var advisory_checks: PackedStringArray = []
	if _enforce_schema_match_check != null and _enforce_schema_match_check.button_pressed:
		enforced_checks.append("save schema")
	else:
		advisory_checks.append("save schema")
	if _enforce_data_version_match_check != null and _enforce_data_version_match_check.button_pressed:
		enforced_checks.append("data version")
	else:
		advisory_checks.append("data version")

	var summary := "Loads currently block when "
	if enforced_checks.is_empty():
		summary = "Loads do not currently block on schema or data version mismatch by policy alone."
		_compatibility_summary_label.modulate = Color(0.95, 0.82, 0.46)
	else:
		summary += "%s do not match project defaults." % _join_human_list(enforced_checks)
		_compatibility_summary_label.modulate = Color(0.60, 0.92, 0.70)
	_compatibility_summary_label.text = summary

	var details: PackedStringArray = []
	details.append("Current project defaults: schema `%s`, data version %d." % [
		_save_schema_edit.text.strip_edges(),
		int(_data_version_spin.value),
	])
	if _verify_scene_path_check != null and _verify_scene_path_check.button_pressed:
		details.append("Scene and scope loads also require the saved scene path to match the current restore target.")
	else:
		details.append("Scene path verification is currently disabled for scene/scope loads.")
		details.append("With this off, SaveFlow skips the scene-context precheck and continues restore against whatever save graph, source keys, and runtime identities resolve under the current target.")
	if not advisory_checks.is_empty():
		details.append("Unchecked metadata still appears in compatibility reports, but does not block load by itself.")
	details.append("Use DevSaveManager to inspect individual slot compatibility before loading older saves.")
	_compatibility_details_label.text = "\n".join(details)


func _join_human_list(values: PackedStringArray) -> String:
	if values.is_empty():
		return "no metadata checks"
	if values.size() == 1:
		return values[0]
	if values.size() == 2:
		return "%s and %s" % [values[0], values[1]]
	var all_but_last := PackedStringArray()
	for index in range(values.size() - 1):
		all_but_last.append(values[index])
	return "%s, and %s" % [", ".join(all_but_last), values[values.size() - 1]]


func _apply_runtime_settings(settings: SaveSettings) -> void:
	var main_loop := Engine.get_main_loop()
	if not (main_loop is SceneTree):
		return
	var runtime := (main_loop as SceneTree).root.get_node_or_null("/root/SaveFlow")
	if runtime != null and runtime.has_method("configure"):
		runtime.configure(settings)


func _get_project_settings_script() -> Script:
	if not ResourceLoader.exists(PROJECT_SETTINGS_SCRIPT_PATH):
		return null
	return load(PROJECT_SETTINGS_SCRIPT_PATH)


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


func _build_setup_hint_text(report: Dictionary) -> String:
	var lines: PackedStringArray = []
	if _report_has_state(report, "Core addon", "error"):
		lines.append("Next step: copy both `addons/saveflow_core` and `addons/saveflow_lite` into this project's `addons/` folder.")
	elif _report_has_state(report, "Lite addon", "error"):
		lines.append("Next step: reinstall SaveFlow Lite so `addons/saveflow_lite` is complete.")

	if _report_has_state(report, "Project settings bridge", "error"):
		lines.append("Until the core addon is restored, this panel can only run diagnostics and cannot save project defaults.")

	if _report_has_state(report, "Lite plugin enabled", "error"):
		lines.append("Enable `SaveFlow Lite` from Project Settings > Plugins before using editor tooling.")

	if _report_has_state(report, "Project settings registration", "warning"):
		lines.append("Use `Repair SaveFlow Setup` to register the project-wide SaveFlow settings keys.")

	if _report_has_state(report, "Addon version match", "error"):
		lines.append("Reinstall the matching `saveflow_core` and `saveflow_lite` package pair. Mixed versions are not supported.")

	if _report_has_state(report, "Autoload registration", "error") or _report_has_state(report, "Autoload registration", "warning"):
		lines.append("Use `Repair SaveFlow Setup` to re-register the `SaveFlow` autoload with the expected runtime entry.")

	if _report_has_state(report, "Legacy autoload cleanup", "warning"):
		lines.append("Use `Repair SaveFlow Setup` to remove the old `Save` autoload entry.")

	if _report_has_state(report, "Runtime singleton", "warning") and not _report_has_state(report, "Autoload registration", "error"):
		lines.append("If the plugin was just enabled, reload the project once so the editor runtime can see `/root/SaveFlow`.")

	if _report_has_state(report, "C# project file", "error"):
		lines.append("If you want to use the C# workflow demo or project-side C# scripts, add the main `%s.csproj` file for this Godot project." % String(ProjectSettings.get_setting("dotnet/project/assembly_name", "YourProject")).strip_edges())

	if _report_has_state(report, "C# package source", "warning"):
		lines.append("If `dotnet build` cannot resolve `Godot.NET.Sdk`, add a local GodotSharp package source in `nuget.config`.")

	if _report_has_state(report, "C# assembly build", "warning"):
		lines.append("Build the project C# assembly once so the C# workflow demo can instantiate its C# helpers instead of showing setup guidance.")

	if lines.is_empty():
		lines.append("No action needed right now. This project looks ready for SaveFlow Lite.")
	return "\n".join(lines)


func _report_has_state(report: Dictionary, title: String, state: String) -> bool:
	for check in report.get("checks", []):
		if String(check.get("title", "")) == title and String(check.get("state", "")) == state:
			return true
	return false


func _on_health_section_toggled(expanded: bool) -> void:
	if _health_section_content != null:
		_health_section_content.visible = expanded
	if _health_section_toggle_button != null:
		_health_section_toggle_button.text = "Hide" if expanded else "Show"


func _on_repair_setup_pressed() -> void:
	repair_setup_requested.emit()


func _on_open_addons_folder_pressed() -> void:
	open_addons_folder_requested.emit()


func _on_open_lite_docs_pressed() -> void:
	open_lite_docs_requested.emit()


func _on_open_save_manager_pressed() -> void:
	open_save_manager_requested.emit()


func _on_open_quick_access_pressed() -> void:
	open_quick_access_requested.emit()
