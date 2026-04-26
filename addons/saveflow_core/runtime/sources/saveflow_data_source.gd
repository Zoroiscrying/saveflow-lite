## SaveFlowDataSource is the custom-source path for non-object state such as
## world tables, managers, queues, and model-backed runtime systems.
@icon("res://addons/saveflow_lite/icons/components/saveflow_data_source_icon.svg")
@tool
@abstract
class_name SaveFlowDataSource
extends SaveFlowSource

## Lets a source declare its own schema/versioning boundary without forcing that
## concept onto the surrounding scope.
@export var data_version: int = 1:
	set(value):
		data_version = value
		_refresh_editor_warnings()


func _ready() -> void:
	_refresh_editor_warnings()


func describe_source() -> Dictionary:
	var description := super.describe_source()
	description["kind"] = "data"
	description["data_version"] = data_version
	description["plan"] = describe_data_plan()
	return description


## Returns the fixed schema consumed by the data-source inspector preview.
## Keep custom preview content inside `details` so the preview layout stays
## stable across different project-specific data sources.
func describe_data_plan() -> Dictionary:
	return {
		"valid": true,
		"reason": "",
		"source_key": get_source_key(),
		"data_version": data_version,
		"phase": get_phase(),
		"enabled": is_source_enabled(),
		"save_enabled": can_save_source(),
		"load_enabled": can_load_source(),
		"summary": "Custom SaveFlowDataSource",
		"sections": PackedStringArray(),
		## Put source-specific preview data in "details". The preview only renders
		## a fixed top-level schema plus this expandable details section.
		"details": {},
	}


func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray = []
	var plan := describe_data_plan()
	if not bool(plan.get("valid", false)):
		var reason := String(plan.get("reason", "INVALID_DATA_SOURCE_PLAN"))
		warnings.append("SaveFlowDataSource plan is invalid: %s" % reason)
	var summary := String(plan.get("summary", "")).strip_edges()
	if summary.is_empty():
		warnings.append("SaveFlowDataSource preview summary is empty.")
	for warning in get_saveflow_authoring_warnings():
		warnings.append(warning)
	return warnings


func _refresh_editor_warnings() -> void:
	if not Engine.is_editor_hint():
		return
	update_configuration_warnings()


func gather_save_data() -> Variant:
	return gather_data()


func apply_save_data(data: Variant, _context: Dictionary = {}) -> SaveResult:
	if not (data is Dictionary):
		return error_result(
			SaveError.INVALID_FORMAT,
			"INVALID_FORMAT",
			"data source payload must be a dictionary",
			{"source_key": get_source_key()}
		)
	apply_data(data)
	return ok_result()


## Implement custom data gathering here. Prefer a stable dictionary shape so
## future loads and preview summaries stay predictable.
@abstract
func gather_data() -> Dictionary


## Implement custom payload application here. Validate shape inside the source
## when partial or migrated data needs special handling.
@abstract
func apply_data(data: Dictionary) -> void
