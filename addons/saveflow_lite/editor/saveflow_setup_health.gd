@tool
extends RefCounted

const AUTOLOAD_NAME := "SaveFlow"
const CORE_ROOT := "res://addons/saveflow_core"
const LITE_ROOT := "res://addons/saveflow_lite"
const AUTOLOAD_PATH := "res://addons/saveflow_core/runtime/core/save_flow.gd"
const PROJECT_SETTINGS_PATH := "res://addons/saveflow_core/runtime/core/saveflow_project_settings.gd"
const LITE_PLUGIN_CONFIG_PATH := "res://addons/saveflow_lite/plugin.cfg"
const CORE_VERSION_PATH := "res://addons/saveflow_core/version.txt"
const NUGET_CONFIG_PATH := "res://nuget.config"
const LEGACY_AUTOLOAD_NAME := "Save"
const PROJECT_SETTINGS_KEY := "saveflow_lite/settings/save_root"
const SceneValidatorScript := preload("res://addons/saveflow_lite/editor/saveflow_scene_validator.gd")


static func inspect_setup(scene_root: Node = null) -> Dictionary:
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

	_append_csharp_checks(checks)
	_append_scene_preflight_checks(checks, scene_root)

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


static func _append_csharp_checks(checks: Array[Dictionary]) -> void:
	var assembly_name := String(ProjectSettings.get_setting("dotnet/project/assembly_name", "")).strip_edges()
	if assembly_name.is_empty():
		_add_warning(
			checks,
			"C# assembly name",
			"No `dotnet/project/assembly_name` is configured. C# demo helpers and project-side C# scripts will stay unavailable until the project is configured for .NET."
		)
		return

	var csproj_path := "res://%s.csproj" % assembly_name
	if FileAccess.file_exists(csproj_path):
		_add_ok(
			checks,
			"C# project file",
			"`%s.csproj` is present for the main Godot C# assembly." % assembly_name
		)
	else:
		_add_error(
			checks,
			"C# project file",
			"`%s.csproj` is missing. The C# workflow demo and any project-owned C# scripts need a main Godot C# project file." % assembly_name
		)

	var nuget_detail := _inspect_nuget_config()
	match String(nuget_detail.get("state", "warning")):
		"ok":
			_add_ok(checks, "C# package source", String(nuget_detail.get("detail", "")))
		"error":
			_add_error(checks, "C# package source", String(nuget_detail.get("detail", "")))
		_:
			_add_warning(checks, "C# package source", String(nuget_detail.get("detail", "")))

	var assembly_output_paths := [
		"res://.godot/mono/temp/bin/Debug/%s.dll" % assembly_name,
		"res://.godot/mono/temp/bin/ExportDebug/%s.dll" % assembly_name,
		"res://.godot/mono/temp/bin/Release/%s.dll" % assembly_name,
		"res://.godot/mono/temp/bin/ExportRelease/%s.dll" % assembly_name,
	]
	var built_assembly_path := ""
	for candidate in assembly_output_paths:
		if FileAccess.file_exists(candidate):
			built_assembly_path = candidate
			break

	if built_assembly_path.is_empty():
		_add_warning(
			checks,
			"C# assembly build",
			"No built `%s.dll` was found under `.godot/mono/temp/bin`. The C# workflow demo stays in guidance-only mode until the project C# assembly is built once." % assembly_name
		)
	else:
		_add_ok(
			checks,
			"C# assembly build",
			"`%s` is available. Project-side C# scripts can be instantiated by the editor/runtime." % built_assembly_path.replace("res://", "")
		)


static func _append_scene_preflight_checks(checks: Array[Dictionary], scene_root: Node = null) -> void:
	var report: Dictionary = SceneValidatorScript.inspect_scene(scene_root)
	if not bool(report.get("has_scene", false)):
		_add_ok(
			checks,
			"Current scene preflight",
			"No edited or current scene is available yet. Open a scene to run SaveFlow authoring checks."
		)
		return

	var source_count := int(report.get("source_count", 0))
	var scope_count := int(report.get("scope_count", 0))
	var factory_count := int(report.get("factory_count", 0))
	var pipeline_signal_count := int(report.get("pipeline_signal_count", 0))
	if source_count == 0 and scope_count == 0 and factory_count == 0 and pipeline_signal_count == 0:
		_add_warning(
			checks,
			"Current scene preflight",
			"`%s` has no SaveFlow components yet. Add a Source or Scope when this scene is meant to participate in save/load." %
			String(report.get("scene_name", "Current Scene")) + _format_next_action_suffix(report)
		)
		return

	_add_ok(
		checks,
		"Current scene preflight",
		"`%s` contains %d source(s), %d scope(s), %d entity factory node(s), and %d pipeline signal node(s). %s%s" % [
			String(report.get("scene_name", "Current Scene")),
			source_count,
			scope_count,
			factory_count,
			pipeline_signal_count,
			_format_scene_component_breakdown(report),
			_format_next_action_suffix(report),
		]
	)
	_append_scene_source_key_checks(checks, report, source_count)
	_append_scene_source_plan_checks(checks, report, source_count)
	_append_scene_scope_plan_checks(checks, report, scope_count)
	_append_scene_factory_plan_checks(checks, report, factory_count)
	_append_scene_pipeline_signal_checks(checks, report, pipeline_signal_count)


static func _append_scene_source_key_checks(checks: Array[Dictionary], report: Dictionary, source_count: int) -> void:
	var issues := _filter_scene_issues(report, "source_key")
	if not issues.is_empty():
		_add_error(
			checks,
			"Current scene source keys",
			_format_scene_issue_details(issues)
		)
		return

	_add_ok(
		checks,
		"Current scene source keys",
		"All %d source key(s) are non-empty and unique in the current scene preflight." % source_count
	)


static func _append_scene_source_plan_checks(checks: Array[Dictionary], report: Dictionary, source_count: int) -> void:
	var invalid_sources := _filter_scene_issues(report, "source_plan", "error")
	var warning_sources := _filter_scene_issues(report, "source_warning", "warning")
	if not invalid_sources.is_empty():
		_add_error(
			checks,
			"Current scene source plans",
			_format_scene_issue_details(invalid_sources)
		)
	elif source_count == 0:
		_add_warning(
			checks,
			"Current scene source plans",
			"No SaveFlow sources were found in this scene."
		)
	else:
		_add_ok(
			checks,
			"Current scene source plans",
			"All source plans that expose diagnostics are currently valid."
		)

	if not warning_sources.is_empty():
		_add_warning(
			checks,
			"Current scene source warnings",
			_format_scene_issue_details(warning_sources)
		)


static func _append_scene_scope_plan_checks(checks: Array[Dictionary], report: Dictionary, scope_count: int) -> void:
	if scope_count == 0:
		return
	var invalid_scopes := _filter_scene_issues(report, "scope_plan", "error")
	var warning_scopes := _filter_scene_issues(report, "scope_plan", "warning")
	if not invalid_scopes.is_empty():
		_add_error(
			checks,
			"Current scene scope plans",
			_format_scene_issue_details(invalid_scopes)
		)
	elif not warning_scopes.is_empty():
		_add_warning(
			checks,
			"Current scene scope plans",
			_format_scene_issue_details(warning_scopes)
		)
	else:
		_add_ok(
			checks,
			"Current scene scope plans",
			"All %d scope plan(s) are currently valid." % scope_count
		)


static func _append_scene_factory_plan_checks(checks: Array[Dictionary], report: Dictionary, factory_count: int) -> void:
	if factory_count == 0:
		return
	var invalid_factories := _filter_scene_issues(report, "entity_factory", "error")
	if not invalid_factories.is_empty():
		_add_error(
			checks,
			"Current scene entity factories",
			_format_scene_issue_details(invalid_factories)
		)
		return

	_add_ok(
		checks,
		"Current scene entity factories",
		"All %d entity factory plan(s) are currently valid." % factory_count
	)


static func _append_scene_pipeline_signal_checks(checks: Array[Dictionary], report: Dictionary, pipeline_signal_count: int) -> void:
	if pipeline_signal_count == 0:
		return
	var signal_warnings := _filter_scene_issues(report, "pipeline_signal", "warning")
	if signal_warnings.is_empty():
		_add_ok(
			checks,
			"Current scene pipeline signals",
			"All %d pipeline signal node(s) target a valid SaveFlow owner or intentionally listen globally." % pipeline_signal_count
		)
	else:
		_add_warning(
			checks,
			"Current scene pipeline signals",
			_format_scene_issue_details(signal_warnings)
		)


static func _format_scene_component_breakdown(report: Dictionary) -> String:
	var breakdown := Dictionary(report.get("source_breakdown", {}))
	var parts := PackedStringArray()
	_append_count_part(parts, int(breakdown.get("node_source_count", 0)), "NodeSource")
	_append_count_part(parts, int(breakdown.get("typed_data_source_count", 0)), "TypedDataSource")
	_append_count_part(parts, int(breakdown.get("data_source_count", 0)), "DataSource")
	_append_count_part(parts, int(breakdown.get("entity_collection_source_count", 0)), "EntityCollection")
	_append_count_part(parts, int(breakdown.get("other_source_count", 0)), "OtherSource")
	_append_count_part(parts, int(report.get("scope_count", 0)), "Scope")
	_append_count_part(parts, int(report.get("factory_count", 0)), "EntityFactory")
	_append_count_part(parts, int(report.get("pipeline_signal_count", 0)), "PipelineSignals")
	if parts.is_empty():
		return "No active component map."
	return "Component map: %s." % ", ".join(parts)


static func _format_next_action_suffix(report: Dictionary) -> String:
	var next_action := String(report.get("next_action", "")).strip_edges()
	if next_action.is_empty():
		return ""
	return "\nNext: %s" % next_action


static func _append_count_part(parts: PackedStringArray, count: int, label: String) -> void:
	if count <= 0:
		return
	parts.append("%d %s" % [count, label])


static func _filter_scene_issues(report: Dictionary, category: String, state: String = "") -> Array[Dictionary]:
	var matches: Array[Dictionary] = []
	for issue_variant in Array(report.get("issues", [])):
		var issue := Dictionary(issue_variant)
		if String(issue.get("category", "")) != category:
			continue
		if not state.is_empty() and String(issue.get("state", "")) != state:
			continue
		matches.append(issue)
	return matches


static func _format_scene_issue_details(issues: Array[Dictionary], max_count: int = 8) -> String:
	if issues.is_empty():
		return ""
	var lines := PackedStringArray()
	var count: int = mini(issues.size(), max_count)
	for index in range(count):
		var issue := issues[index]
		lines.append(String(issue.get("message", "")))
	if issues.size() > max_count:
		lines.append("... and %d more." % (issues.size() - max_count))
	return "\n".join(lines)


static func _inspect_nuget_config() -> Dictionary:
	if not FileAccess.file_exists(NUGET_CONFIG_PATH):
		return {
			"state": "warning",
			"detail": "`nuget.config` is missing. If `dotnet build` cannot resolve `Godot.NET.Sdk`, add a local GodotSharp package source.",
		}

	var file := FileAccess.open(NUGET_CONFIG_PATH, FileAccess.READ)
	if file == null:
		return {
			"state": "warning",
			"detail": "`nuget.config` exists but could not be read. Verify that a local GodotSharp package source is configured.",
		}

	var content := file.get_as_text()
	if content.contains("GodotSharp\\Tools\\nupkgs") or content.contains("GodotSharp/Tools/nupkgs"):
		return {
			"state": "ok",
			"detail": "`nuget.config` includes a local GodotSharp package source for `Godot.NET.Sdk`.",
		}

	return {
		"state": "warning",
		"detail": "`nuget.config` was found, but no local `GodotSharp/Tools/nupkgs` source was detected. `dotnet build` may fail to resolve `Godot.NET.Sdk`.",
	}


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
