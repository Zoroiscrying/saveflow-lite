@tool
extends EditorPlugin

const AUTOLOAD_NAME := "SaveFlow"
const LEGACY_AUTOLOAD_NAME := "Save"
const AUTOLOAD_PATH := "res://addons/saveflow_lite/runtime/core/save_flow.gd"
const InspectorPluginScript := preload("res://addons/saveflow_lite/editor/saveflow_inspector_plugin.gd")

var _inspector_plugin: EditorInspectorPlugin


func _enter_tree() -> void:
	_remove_legacy_autoload_if_present()
	_ensure_autoload()
	_ensure_inspector_plugin()


func _exit_tree() -> void:
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


func _remove_inspector_plugin_if_present() -> void:
	if _inspector_plugin == null:
		return
	remove_inspector_plugin(_inspector_plugin)
	_inspector_plugin = null
