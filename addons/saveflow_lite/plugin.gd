@tool
extends EditorPlugin

const AUTOLOAD_NAME := "SaveFlow"
const LEGACY_AUTOLOAD_NAME := "Save"
const AUTOLOAD_PATH := "res://addons/saveflow_core/runtime/core/save_flow.gd"
const PROJECT_SETTINGS_SCRIPT_PATH := "res://addons/saveflow_core/runtime/core/saveflow_project_settings.gd"
const PLUGIN_CONFIG_PATH := "res://addons/saveflow_lite/plugin.cfg"
const QUICK_ACCESS_METADATA_SECTION := "saveflow_lite"
const QUICK_ACCESS_METADATA_KEY := "quick_access_dismissed_version"
const InspectorPluginScript := preload("res://addons/saveflow_lite/editor/saveflow_inspector_plugin.gd")
const SettingsPanelScript := preload("res://addons/saveflow_lite/editor/saveflow_settings_panel.gd")
const DevSaveManagerPanelScript := preload("res://addons/saveflow_lite/editor/saveflow_save_manager_panel.gd")
const QuickAccessPanelScript := preload("res://addons/saveflow_lite/editor/saveflow_quick_access_panel.gd")
const SetupHealthScript := preload("res://addons/saveflow_lite/editor/saveflow_setup_health.gd")
const SceneValidatorBadgeScript := preload("res://addons/saveflow_lite/editor/saveflow_scene_validator_badge.gd")

var _inspector_plugin: EditorInspectorPlugin
var _settings_panel: Control
var _save_manager_panel: Control
var _quick_access_panel: Window
var _scene_validator_badge_2d: Control
var _scene_validator_badge_3d: Control
var _missing_project_settings_script_reported := false


func _enter_tree() -> void:
	var project_settings_script := _get_project_settings_script()
	if project_settings_script != null:
		project_settings_script.register_project_settings()
	_remove_legacy_autoload_if_present()
	_ensure_autoload()
	_ensure_inspector_plugin()
	_ensure_settings_panel()
	_ensure_save_manager_panel()
	_ensure_quick_access_panel()
	_ensure_scene_validator_badges()
	add_tool_menu_item("SaveFlow Quick Access", Callable(self, "_show_quick_access_panel"))
	_apply_project_settings_to_runtime()
	_report_setup_health()
	if _should_auto_show_quick_access():
		call_deferred("_queue_quick_access_panel_show")


func _exit_tree() -> void:
	remove_tool_menu_item("SaveFlow Quick Access")
	_remove_scene_validator_badges_if_present()
	_remove_quick_access_panel_if_present()
	_remove_save_manager_panel_if_present()
	_remove_settings_panel_if_present()
	_remove_inspector_plugin_if_present()
	_remove_autoload_if_present()


func _ensure_autoload() -> void:
	if ProjectSettings.has_setting("autoload/%s" % AUTOLOAD_NAME):
		return
	if not ResourceLoader.exists(AUTOLOAD_PATH):
		push_warning("SaveFlow Lite could not register the SaveFlow autoload because `%s` is missing. Check the Setup Health section in SaveFlow Settings." % AUTOLOAD_PATH)
		return
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)


func _remove_autoload_if_present() -> void:
	if not ProjectSettings.has_setting("autoload/%s" % AUTOLOAD_NAME):
		return
	remove_autoload_singleton(AUTOLOAD_NAME)


func _remove_legacy_autoload_if_present() -> void:
	if not ProjectSettings.has_setting("autoload/%s" % LEGACY_AUTOLOAD_NAME):
		return
	remove_autoload_singleton(LEGACY_AUTOLOAD_NAME)


func _ensure_inspector_plugin() -> void:
	if _inspector_plugin != null:
		return
	_inspector_plugin = InspectorPluginScript.new()
	add_inspector_plugin(_inspector_plugin)


func _ensure_settings_panel() -> void:
	if _settings_panel != null:
		return
	_settings_panel = SettingsPanelScript.new()
	_settings_panel.name = "SaveFlow Settings"
	if _settings_panel.has_signal("open_save_manager_requested"):
		_settings_panel.connect("open_save_manager_requested", Callable(self, "_focus_save_manager_panel"))
	if _settings_panel.has_signal("open_quick_access_requested"):
		_settings_panel.connect("open_quick_access_requested", Callable(self, "_show_quick_access_panel"))
	if _settings_panel.has_signal("repair_setup_requested"):
		_settings_panel.connect("repair_setup_requested", Callable(self, "_repair_setup"))
	if _settings_panel.has_signal("open_addons_folder_requested"):
		_settings_panel.connect("open_addons_folder_requested", Callable(self, "_open_addons_folder"))
	if _settings_panel.has_signal("open_lite_docs_requested"):
		_settings_panel.connect("open_lite_docs_requested", Callable(self, "_open_lite_docs"))
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _settings_panel)


func _ensure_save_manager_panel() -> void:
	if _save_manager_panel != null:
		return
	_save_manager_panel = DevSaveManagerPanelScript.new()
	_save_manager_panel.name = "SaveFlow DevSaveManager"
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, _save_manager_panel)


func _ensure_quick_access_panel() -> void:
	if _quick_access_panel != null:
		return
	_quick_access_panel = QuickAccessPanelScript.new()
	if _quick_access_panel.has_method("set_plugin_version"):
		_quick_access_panel.call("set_plugin_version", _get_plugin_version())
	if _quick_access_panel.has_signal("open_scene_requested"):
		_quick_access_panel.connect("open_scene_requested", Callable(self, "_open_scene_in_editor"))
	if _quick_access_panel.has_signal("focus_settings_requested"):
		_quick_access_panel.connect("focus_settings_requested", Callable(self, "_focus_settings_panel"))
	if _quick_access_panel.has_signal("focus_save_manager_requested"):
		_quick_access_panel.connect("focus_save_manager_requested", Callable(self, "_focus_save_manager_panel"))
	if _quick_access_panel.has_signal("open_docs_requested"):
		_quick_access_panel.connect("open_docs_requested", Callable(self, "_open_lite_docs"))
	if _quick_access_panel.has_signal("dismissed"):
		_quick_access_panel.connect("dismissed", Callable(self, "_on_quick_access_dismissed"))
	get_editor_interface().get_base_control().add_child(_quick_access_panel)


func _ensure_scene_validator_badges() -> void:
	if _scene_validator_badge_2d == null:
		_scene_validator_badge_2d = SceneValidatorBadgeScript.new()
		_scene_validator_badge_2d.name = "SaveFlow Scene Validator"
		add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU, _scene_validator_badge_2d)
	if _scene_validator_badge_3d == null:
		_scene_validator_badge_3d = SceneValidatorBadgeScript.new()
		_scene_validator_badge_3d.name = "SaveFlow Scene Validator"
		add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, _scene_validator_badge_3d)


func _apply_project_settings_to_runtime() -> void:
	var project_settings_script := _get_project_settings_script()
	if project_settings_script == null:
		return
	var runtime := get_tree().root.get_node_or_null("/root/%s" % AUTOLOAD_NAME)
	if runtime == null or not runtime.has_method("configure"):
		return
	runtime.configure(project_settings_script.load_settings())


func _report_setup_health() -> void:
	var report := SetupHealthScript.inspect_setup()
	if int(report.get("error_count", 0)) == 0:
		return
	push_warning("SaveFlow Lite setup check: %s" % String(report.get("summary", "Setup needs attention.")))


func _get_project_settings_script() -> Script:
	if not ResourceLoader.exists(PROJECT_SETTINGS_SCRIPT_PATH):
		if not _missing_project_settings_script_reported:
			push_warning("SaveFlow Lite could not find `%s`. The Settings dock will stay in diagnostics-only mode." % PROJECT_SETTINGS_SCRIPT_PATH)
			_missing_project_settings_script_reported = true
		return null
	return load(PROJECT_SETTINGS_SCRIPT_PATH)


func _remove_inspector_plugin_if_present() -> void:
	if _inspector_plugin == null:
		return
	remove_inspector_plugin(_inspector_plugin)
	_inspector_plugin = null


func _remove_settings_panel_if_present() -> void:
	if _settings_panel == null:
		return
	remove_control_from_docks(_settings_panel)
	_settings_panel.queue_free()
	_settings_panel = null


func _remove_save_manager_panel_if_present() -> void:
	if _save_manager_panel == null:
		return
	remove_control_from_docks(_save_manager_panel)
	_save_manager_panel.queue_free()
	_save_manager_panel = null


func _remove_quick_access_panel_if_present() -> void:
	if _quick_access_panel == null:
		return
	_quick_access_panel.queue_free()
	_quick_access_panel = null


func _remove_scene_validator_badges_if_present() -> void:
	if _scene_validator_badge_2d != null:
		remove_control_from_container(CONTAINER_CANVAS_EDITOR_MENU, _scene_validator_badge_2d)
		_scene_validator_badge_2d.queue_free()
		_scene_validator_badge_2d = null
	if _scene_validator_badge_3d != null:
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, _scene_validator_badge_3d)
		_scene_validator_badge_3d.queue_free()
		_scene_validator_badge_3d = null


func _show_quick_access_panel() -> void:
	if _quick_access_panel == null:
		return
	if _quick_access_panel.has_method("popup_quick_access"):
		_quick_access_panel.call("popup_quick_access")


func _queue_quick_access_panel_show() -> void:
	call_deferred("_show_quick_access_panel")


func _focus_save_manager_panel() -> void:
	if _save_manager_panel == null:
		return
	_make_host_dock_visible(_save_manager_panel)
	_save_manager_panel.show()
	_focus_control_tab(_save_manager_panel)
	_focus_panel_primary_control(_save_manager_panel)
	if _save_manager_panel.has_method("refresh_now"):
		_save_manager_panel.call("refresh_now")


func _focus_settings_panel() -> void:
	if _settings_panel == null:
		return
	_make_host_dock_visible(_settings_panel)
	_settings_panel.show()
	_focus_control_tab(_settings_panel)
	_focus_panel_primary_control(_settings_panel)


func _repair_setup() -> void:
	_remove_legacy_autoload_if_present()
	_reinstall_autoload_if_needed()

	var project_settings_script := _get_project_settings_script()
	if project_settings_script != null:
		project_settings_script.register_project_settings()
	_apply_project_settings_to_runtime()
	_refresh_settings_panel_health()

	var report := SetupHealthScript.inspect_setup()
	if int(report.get("error_count", 0)) > 0:
		_set_settings_panel_status("Repair finished, but setup still has blocking issues. Check Setup Health for the remaining fixes.")
	elif int(report.get("warning_count", 0)) > 0:
		_set_settings_panel_status("Repair finished. Setup is usable, but there are still warnings to review.")
	else:
		_set_settings_panel_status("Repair finished. SaveFlow Lite setup looks healthy.")


func _reinstall_autoload_if_needed() -> void:
	var setting_key := "autoload/%s" % AUTOLOAD_NAME
	if ProjectSettings.has_setting(setting_key):
		var current_path := String(ProjectSettings.get_setting(setting_key, "")).trim_prefix("*")
		if current_path != AUTOLOAD_PATH:
			remove_autoload_singleton(AUTOLOAD_NAME)
	_ensure_autoload()


func _refresh_settings_panel_health() -> void:
	if _settings_panel == null:
		return
	if _settings_panel.has_method("refresh_setup_health"):
		_settings_panel.call("refresh_setup_health")


func _set_settings_panel_status(message: String) -> void:
	if _settings_panel == null:
		return
	if _settings_panel.has_method("show_status_message"):
		_settings_panel.call("show_status_message", message)


func _open_addons_folder() -> void:
	OS.shell_open(ProjectSettings.globalize_path("res://addons"))
	_set_settings_panel_status("Opened the project's addons folder.")


func _open_lite_docs() -> void:
	OS.shell_open(ProjectSettings.globalize_path("res://addons/saveflow_lite/docs"))
	_set_settings_panel_status("Opened the SaveFlow Lite docs folder.")


func _open_scene_in_editor(scene_path: String) -> void:
	if scene_path.is_empty():
		return
	get_editor_interface().open_scene_from_path(scene_path)


func _get_plugin_version() -> String:
	if not FileAccess.file_exists(PLUGIN_CONFIG_PATH):
		return ""
	var config := ConfigFile.new()
	var error := config.load(PLUGIN_CONFIG_PATH)
	if error != OK:
		return ""
	return String(config.get_value("plugin", "version", "")).strip_edges()


func _should_auto_show_quick_access() -> bool:
	var editor_settings := get_editor_interface().get_editor_settings()
	if editor_settings == null:
		return true
	var dismissed_version := String(editor_settings.get_project_metadata(
		QUICK_ACCESS_METADATA_SECTION,
		QUICK_ACCESS_METADATA_KEY,
		""
	)).strip_edges()
	var plugin_version := _get_plugin_version()
	if plugin_version.is_empty():
		return true
	return dismissed_version != plugin_version


func _on_quick_access_dismissed(suppress_until_current_version: bool) -> void:
	var editor_settings := get_editor_interface().get_editor_settings()
	if editor_settings == null:
		return
	var plugin_version := _get_plugin_version()
	var dismissed_version := plugin_version if suppress_until_current_version else ""
	editor_settings.set_project_metadata(
		QUICK_ACCESS_METADATA_SECTION,
		QUICK_ACCESS_METADATA_KEY,
		dismissed_version
	)


func _focus_control_tab(control: Control) -> void:
	if control == null:
		return
	var parent := control.get_parent()
	while parent != null:
		if parent is TabContainer:
			var tab := parent as TabContainer
			var tab_index := tab.get_children().find(control)
			if tab_index >= 0:
				tab.current_tab = tab_index
			return
		control = parent as Control
		parent = parent.get_parent()


func _focus_panel_primary_control(panel: Control) -> void:
	if panel == null:
		return
	if panel.has_method("focus_primary_input"):
		panel.call_deferred("focus_primary_input")


func _make_host_dock_visible(control: Control) -> void:
	if control == null:
		return
	var node: Node = control
	while node != null:
		if node is EditorDock:
			node.make_visible()
			return
		node = node.get_parent()
