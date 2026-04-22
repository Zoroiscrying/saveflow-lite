extends Control

const CSHARP_DRIVER_SCRIPT := "res://demo/saveflow_lite/recommended_template/gameplay/TemplateCSharpCase.cs"

var _driver: Node = null

@onready var _state_label: Label = $MarginContainer/PanelContainer/Content/StateLabel
@onready var _status_output: TextEdit = $MarginContainer/PanelContainer/Content/StatusOutput


func _ready() -> void:
	_bind_buttons()
	_create_driver()
	if _driver == null:
		_state_label.text = "C# State: unavailable"
		_status_output.text = "\n".join(
			[
				"C# case is not active yet.",
				"Reason: this project has not loaded a working C# assembly for the demo helper.",
				"",
				"To use Case 4:",
				"1. Open the project with the Godot .NET editor.",
				"2. Build the C# solution for the project.",
				"3. Reopen this case.",
			]
		)
		return

	_refresh_from_driver()
	_status_output.text = "C# case ready. This scene uses a C# helper node that calls SaveFlow.DotNet.SaveFlowClient."


func _bind_buttons() -> void:
	$MarginContainer/PanelContainer/Content/Buttons/SaveButton.pressed.connect(_on_save_pressed)
	$MarginContainer/PanelContainer/Content/Buttons/LoadButton.pressed.connect(_on_load_pressed)
	$MarginContainer/PanelContainer/Content/Buttons/MutateButton.pressed.connect(_on_mutate_pressed)
	$MarginContainer/PanelContainer/Content/Buttons/ResetButton.pressed.connect(_on_reset_pressed)


func _create_driver() -> void:
	if not _is_csharp_driver_available():
		return
	var script_resource := load(CSHARP_DRIVER_SCRIPT)
	if not (script_resource is Script):
		return
	var script := script_resource as Script
	if script == null:
		return
	var instance = script.new()
	if instance == null or not (instance is Node):
		return
	_driver = instance
	_driver.name = "CSharpDriver"
	add_child(_driver)


func _is_csharp_driver_available() -> bool:
	var assembly_name := String(ProjectSettings.get_setting("dotnet/project/assembly_name", "")).strip_edges()
	if assembly_name.is_empty():
		return false

	var candidate_dll_paths := [
		"res://.godot/mono/temp/bin/Debug/%s.dll" % assembly_name,
		"res://.godot/mono/temp/bin/ExportDebug/%s.dll" % assembly_name,
		"res://.godot/mono/temp/bin/Release/%s.dll" % assembly_name,
		"res://.godot/mono/temp/bin/ExportRelease/%s.dll" % assembly_name,
	]
	for dll_path in candidate_dll_paths:
		if FileAccess.file_exists(dll_path):
			return true

	return false


func _on_save_pressed() -> void:
	if _driver == null:
		return
	var result = _driver.call("SaveCase")
	_set_result_status("Save", result)


func _on_load_pressed() -> void:
	if _driver == null:
		return
	var result = _driver.call("LoadCase")
	_set_result_status("Load", result)


func _on_mutate_pressed() -> void:
	if _driver == null:
		return
	_driver.call("MutateCase")
	_refresh_from_driver()
	_status_output.text = "Mutated C# local state. SaveData stores this dictionary payload."


func _on_reset_pressed() -> void:
	if _driver == null:
		return
	_driver.call("ResetCase")
	_refresh_from_driver()
	_status_output.text = "Reset C# local state."


func _set_result_status(label: String, result) -> void:
	if result == null:
		_status_output.text = "%s failed: no C# result was returned." % label
		return
	if bool(result.get("ok", false)):
		var summary := String(result.get("summary", ""))
		_status_output.text = "%s OK%s" % [label, ("\n%s" % summary) if not summary.is_empty() else ""]
	else:
		_status_output.text = "%s failed: %s (%s)" % [
			label,
			String(result.get("error_message", "unknown error")),
			String(result.get("error_key", "UNKNOWN")),
		]
	_refresh_from_driver()


func _refresh_from_driver() -> void:
	if _driver == null:
		return
	var state = _driver.call("GetStateSnapshot")
	if state is Dictionary:
		_state_label.text = "C# State: coins=%d, room=%s" % [
			int(state.get("coins", 0)),
			String(state.get("room", "")),
		]
