@tool
extends EditorPlugin

const AUTOLOAD_NAME := "SaveFlow"
const LEGACY_AUTOLOAD_NAME := "Save"
const AUTOLOAD_PATH := "res://addons/saveflow_core/runtime/core/save_flow.gd"
const InspectorPluginScript := preload("res://addons/saveflow_lite/editor/saveflow_inspector_plugin.gd")
const SettingsPanelScript := preload("res://addons/saveflow_lite/editor/saveflow_settings_panel.gd")
const DevSaveManagerPanelScript := preload("res://addons/saveflow_lite/editor/saveflow_save_manager_panel.gd")
const SaveFlowProjectSettingsScript := preload("res://addons/saveflow_core/runtime/core/saveflow_project_settings.gd")

var _inspector_plugin: EditorInspectorPlugin
var _settings_panel: Control
var _save_manager_panel: Control


func _enter_tree() -> void:
	SaveFlowProjectSettingsScript.register_project_settings()
	_remove_legacy_autoload_if_present()
	_ensure_autoload()
	_ensure_inspector_plugin()
	_ensure_settings_panel()
	_ensure_save_manager_panel()
	_apply_project_settings_to_runtime()


func _exit_tree() -> void:
	_remove_save_manager_panel_if_present()
	_remove_settings_panel_if_present()
	_remove_inspector_plugin_if_present()
	_remove_autoload_if_present()


func _ensure_autoload() -> void:
	if ProjectSettings.has_setting("autoload/%s" % AUTOLOAD_NAME):
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
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _settings_panel)


func _ensure_save_manager_panel() -> void:
	if _save_manager_panel != null:
		return
	_save_manager_panel = DevSaveManagerPanelScript.new()
	_save_manager_panel.name = "SaveFlow DevSaveManager"
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, _save_manager_panel)


func _apply_project_settings_to_runtime() -> void:
	var runtime := get_tree().root.get_node_or_null("/root/%s" % AUTOLOAD_NAME)
	if runtime == null or not runtime.has_method("configure"):
		return
	runtime.configure(SaveFlowProjectSettingsScript.load_settings())


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


func _focus_save_manager_panel() -> void:
	if _save_manager_panel == null:
		return
	_save_manager_panel.show()
	_focus_control_tab(_save_manager_panel)
	_save_manager_panel.grab_focus()
	if _save_manager_panel.has_method("refresh_now"):
		_save_manager_panel.call("refresh_now")


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
