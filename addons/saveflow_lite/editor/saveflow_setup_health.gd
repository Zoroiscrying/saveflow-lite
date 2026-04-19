@tool
extends RefCounted

const AUTOLOAD_NAME := "SaveFlow"
const CORE_ROOT := "res://addons/saveflow_core"
const LITE_ROOT := "res://addons/saveflow_lite"
const AUTOLOAD_PATH := "res://addons/saveflow_core/runtime/core/save_flow.gd"
const PROJECT_SETTINGS_PATH := "res://addons/saveflow_core/runtime/core/saveflow_project_settings.gd"
const LITE_PLUGIN_CONFIG_PATH := "res://addons/saveflow_lite/plugin.cfg"
const CORE_VERSION_PATH := "res://addons/saveflow_core/version.txt"
const LEGACY_AUTOLOAD_NAME := "Save"
const PROJECT_SETTINGS_KEY := "saveflow_lite/settings/save_root"


static func inspect_setup() -> Dictionary:
	var checks: Array[Dictionary] = []

	_add_check(
		checks,
		_dir_exists(CORE_ROOT),
		"Core addon",
		"`addons/saveflow_core` is present.",
		"`addons/saveflow_core` is missing. Copy both `saveflow_core` and `saveflow_lite` into your project's `addons/` folder."
	)
	_add_check(
		checks,
		_dir_exists(LITE_ROOT),
		"Lite addon",
		"`addons/saveflow_lite` is present.",
		"`addons/saveflow_lite` is missing. Reinstall the plugin package."
	)
	_add_check(
		checks,
		FileAccess.file_exists(LITE_PLUGIN_CONFIG_PATH),
		"Lite plugin config",
		"`addons/saveflow_lite/plugin.cfg` is available.",
		"`addons/saveflow_lite/plugin.cfg` is missing. The Lite addon folder looks incomplete."
	)
	_add_check(
		checks,
		ResourceLoader.exists(AUTOLOAD_PATH),
		"Runtime entry",
		"`save_flow.gd` is available for the `SaveFlow` autoload.",
		"`save_flow.gd` is missing. The core runtime is incomplete, so save/load entrypoints cannot work."
	)
	_add_check(
		checks,
		ResourceLoader.exists(PROJECT_SETTINGS_PATH),
		"Project settings bridge",
		"`saveflow_project_settings.gd` is available.",
		"`saveflow_project_settings.gd` is missing. The Settings dock cannot read or write project defaults."
	)
	_add_check(
		checks,
		_is_lite_plugin_enabled(),
		"Lite plugin enabled",
		"`SaveFlow Lite` is enabled in the editor plugin list.",
		"`SaveFlow Lite` is disabled. Enable `res://addons/saveflow_lite/plugin.cfg` in Project Settings > Plugins."
	)

	if ProjectSettings.has_setting(PROJECT_SETTINGS_KEY):
		_add_ok(
			checks,
			"Project settings registration",
			"SaveFlow Lite project settings keys are registered."
		)
	else:
		_add_warning(
			checks,
			"Project settings registration",
			"SaveFlow Lite project settings are not registered yet. Use `Repair SaveFlow Setup` to register them."
		)

	var lite_version := _read_lite_plugin_version()
	var core_version := _read_core_version()
	if lite_version.is_empty() or core_version.is_empty():
		_add_warning(
			checks,
			"Addon version match",
			"Could not read both addon versions. Reinstall the matching `saveflow_core` and `saveflow_lite` package if setup behaves unexpectedly."
		)
	elif lite_version == core_version:
		_add_ok(
			checks,
			"Addon version match",
			"`saveflow_core` and `saveflow_lite` are both on version %s." % lite_version
		)
	else:
		_add_error(
			checks,
			"Addon version match",
			"`saveflow_core` is on %s but `saveflow_lite` is on %s. Reinstall the matching package pair before continuing." % [core_version, lite_version]
		)

	var autoload_path := ""
	if ProjectSettings.has_setting("autoload/%s" % AUTOLOAD_NAME):
		autoload_path = String(ProjectSettings.get_setting("autoload/%s" % AUTOLOAD_NAME, ""))
	if autoload_path.is_empty():
		_add_warning(
			checks,
			"Autoload registration",
			"The `SaveFlow` autoload is not registered yet. Enable the plugin to let SaveFlow install it automatically."
		)
	elif autoload_path.trim_prefix("*") != AUTOLOAD_PATH:
		_add_error(
			checks,
			"Autoload registration",
			"The `SaveFlow` autoload points to `%s`, but SaveFlow Lite expects `%s`." % [autoload_path.trim_prefix("*"), AUTOLOAD_PATH]
		)
	else:
		_add_ok(
			checks,
			"Autoload registration",
			"The `SaveFlow` autoload points at the expected runtime entry."
		)

	if ProjectSettings.has_setting("autoload/%s" % LEGACY_AUTOLOAD_NAME):
		_add_warning(
			checks,
			"Legacy autoload cleanup",
			"A legacy `Save` autoload is still registered. Use `Repair SaveFlow Setup` to remove it."
		)
	else:
		_add_ok(
			checks,
			"Legacy autoload cleanup",
			"No legacy `Save` autoload was found."
		)

	var runtime_ok := false
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		var runtime := (main_loop as SceneTree).root.get_node_or_null(AUTOLOAD_NAME)
		runtime_ok = runtime != null
	if runtime_ok:
		_add_ok(checks, "Runtime singleton", "The editor runtime can see `/root/SaveFlow`.")
	else:
		_add_warning(
			checks,
			"Runtime singleton",
			"The `SaveFlow` singleton is not visible yet. If the plugin was just enabled, reload the project once."
		)

	return _build_report(checks)


static func _build_report(checks: Array[Dictionary]) -> Dictionary:
	var error_count := 0
	var warning_count := 0
	for check in checks:
		match String(check.get("state", "")):
			"error":
				error_count += 1
			"warning":
				warning_count += 1

	var healthy := error_count == 0
	var summary := ""
	if healthy and warning_count == 0:
		summary = "Setup looks healthy. SaveFlow Lite should be ready to use."
	elif healthy:
		summary = "Setup is usable, but there are %d warning(s) worth checking." % warning_count
	else:
		summary = "Setup has %d blocking issue(s) and %d warning(s)." % [error_count, warning_count]

	return {
		"healthy": healthy,
		"error_count": error_count,
		"warning_count": warning_count,
		"summary": summary,
		"checks": checks,
	}


static func _dir_exists(path: String) -> bool:
	return DirAccess.open(path) != null


static func _is_lite_plugin_enabled() -> bool:
	var enabled_plugins_variant: Variant = ProjectSettings.get_setting("editor_plugins/enabled", PackedStringArray())
	if enabled_plugins_variant is PackedStringArray:
		return PackedStringArray(enabled_plugins_variant).has(LITE_PLUGIN_CONFIG_PATH)
	if enabled_plugins_variant is Array:
		return Array(enabled_plugins_variant).has(LITE_PLUGIN_CONFIG_PATH)
	return false


static func _read_lite_plugin_version() -> String:
	if not FileAccess.file_exists(LITE_PLUGIN_CONFIG_PATH):
		return ""
	var config := ConfigFile.new()
	var error := config.load(LITE_PLUGIN_CONFIG_PATH)
	if error != OK:
		return ""
	return String(config.get_value("plugin", "version", "")).strip_edges()


static func _read_core_version() -> String:
	if not FileAccess.file_exists(CORE_VERSION_PATH):
		return ""
	var file := FileAccess.open(CORE_VERSION_PATH, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text().strip_edges()


static func _add_check(checks: Array[Dictionary], condition: bool, title: String, ok_detail: String, error_detail: String) -> void:
	if condition:
		_add_ok(checks, title, ok_detail)
	else:
		_add_error(checks, title, error_detail)


static func _add_ok(checks: Array[Dictionary], title: String, detail: String) -> void:
	checks.append({
		"state": "ok",
		"title": title,
		"detail": detail,
	})


static func _add_warning(checks: Array[Dictionary], title: String, detail: String) -> void:
	checks.append({
		"state": "warning",
		"title": title,
		"detail": detail,
	})


static func _add_error(checks: Array[Dictionary], title: String, detail: String) -> void:
	checks.append({
		"state": "error",
		"title": title,
		"detail": detail,
	})
