## Renders the fixed `describe_data_plan()` schema for SaveFlowDataSource.
## This preview intentionally ignores arbitrary top-level keys so custom sources
## cannot accidentally redefine the inspector layout.
@tool
extends VBoxContainer

const LABEL_WIDTH := 112
const PADDING := 10
const META_PREVIEW_EXPANDED := "_saveflow_data_source_preview_expanded"
const META_DESIGN_EXPANDED := "_saveflow_data_source_design_expanded"
const META_DETAILS_EXPANDED := "_saveflow_data_source_details_expanded"

var _data_source: SaveFlowDataSource
var _last_signature: String = ""
var _preview_expanded := true
var _design_expanded := false
var _details_expanded := false

var _preview_toggle: Button
var _content_panel: PanelContainer
var _status_chip: PanelContainer
var _status_label: Label
var _source_key_value: Label
var _summary_value: Label
var _flow_value: Label
var _design_toggle: Button
var _design_box: VBoxContainer
var _design_hint_value: Label
var _sections_value: Label
var _details_toggle: Button
var _details_box: VBoxContainer
var _version_value: Label
var _phase_value: Label
var _reason_value: Label
var _details_value: RichTextLabel


func _ready() -> void:
	_build_ui()
	set_process(true)
	_refresh()


func set_data_source(data_source: SaveFlowDataSource) -> void:
	_data_source = data_source
	_restore_foldout_state_from_source()
	_refresh()


func _process(_delta: float) -> void:
	var signature := _compute_signature()
	if signature == _last_signature:
		return
	_last_signature = signature
	_refresh()


func _build_ui() -> void:
	if _content_panel != null:
		return

	add_theme_constant_override("separation", 8)

	var header_panel := PanelContainer.new()
	add_child(header_panel)

	var header_padding := MarginContainer.new()
	header_padding.add_theme_constant_override("margin_left", PADDING)
	header_padding.add_theme_constant_override("margin_top", 8)
	header_padding.add_theme_constant_override("margin_right", PADDING)
	header_padding.add_theme_constant_override("margin_bottom", 8)
	header_panel.add_child(header_padding)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	header_padding.add_child(header_row)

	_preview_toggle = Button.new()
	_preview_toggle.flat = true
	_preview_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_preview_toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_toggle.pressed.connect(_on_preview_toggled)
	header_row.add_child(_preview_toggle)

	_status_chip = PanelContainer.new()
	header_row.add_child(_status_chip)

	var chip_padding := MarginContainer.new()
	chip_padding.add_theme_constant_override("margin_left", 8)
	chip_padding.add_theme_constant_override("margin_top", 3)
	chip_padding.add_theme_constant_override("margin_right", 8)
	chip_padding.add_theme_constant_override("margin_bottom", 3)
	_status_chip.add_child(chip_padding)

	_status_label = Label.new()
	chip_padding.add_child(_status_label)

	_content_panel = PanelContainer.new()
	add_child(_content_panel)

	var content_padding := MarginContainer.new()
	content_padding.add_theme_constant_override("margin_left", PADDING)
	content_padding.add_theme_constant_override("margin_top", PADDING)
	content_padding.add_theme_constant_override("margin_right", PADDING)
	content_padding.add_theme_constant_override("margin_bottom", PADDING)
	_content_panel.add_child(content_padding)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	content_padding.add_child(content)

	_source_key_value = _add_row(content, "Save Key")
	_summary_value = _add_row(content, "Summary")
	_flow_value = _add_row(content, "Flow")

	_design_toggle = Button.new()
	_design_toggle.flat = true
	_design_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_design_toggle.pressed.connect(_on_design_toggled)
	content.add_child(_design_toggle)

	_design_box = VBoxContainer.new()
	_design_box.add_theme_constant_override("separation", 6)
	content.add_child(_design_box)

	_design_hint_value = _add_row(_design_box, "Design Hint")
	_sections_value = _add_row(_design_box, "Sections")

	_details_toggle = Button.new()
	_details_toggle.flat = true
	_details_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_details_toggle.pressed.connect(_on_details_toggled)
	content.add_child(_details_toggle)

	_details_box = VBoxContainer.new()
	_details_box.add_theme_constant_override("separation", 6)
	content.add_child(_details_box)

	_version_value = _add_row(_details_box, "Version")
	_phase_value = _add_row(_details_box, "Phase")
	_reason_value = _add_row(_details_box, "Reason")

	_details_value = RichTextLabel.new()
	_details_value.fit_content = true
	_details_value.scroll_active = false
	_details_value.selection_enabled = true
	_details_box.add_child(_details_value)

	_apply_panel_styles(header_panel, _content_panel)


func _add_row(parent: VBoxContainer, label_text: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var label := Label.new()
	label.custom_minimum_size.x = LABEL_WIDTH
	label.text = label_text
	label.modulate = get_theme_color("font_placeholder_color", "Editor")
	row.add_child(label)

	var value := Label.new()
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value.text = "<none>"
	row.add_child(value)
	return value


func _refresh() -> void:
	if _content_panel == null:
		return

	var plan := _read_plan()
	var valid := bool(plan.get("valid", false))

	_preview_toggle.text = _foldout_text("SaveFlow Data Source", _preview_expanded)
	_status_label.text = "Valid" if valid else "Invalid"
	_apply_status_style(valid)
	_content_panel.visible = _preview_expanded

	_source_key_value.text = String(plan.get("source_key", ""))
	_summary_value.text = String(plan.get("summary", "Custom SaveFlowDataSource"))
	_flow_value.text = _describe_flow(plan)

	_design_toggle.text = _foldout_text("Design", _design_expanded)
	_design_box.visible = _design_expanded
	_design_hint_value.text = _describe_design_hint()
	_sections_value.text = _format_sections(plan.get("sections", PackedStringArray()))

	_details_toggle.text = _foldout_text("Diagnostics", _details_expanded)
	_details_box.visible = _details_expanded
	_version_value.text = str(int(plan.get("data_version", 1)))
	_phase_value.text = str(int(plan.get("phase", 0)))
	_reason_value.text = String(plan.get("reason", ""))
	_details_value.text = _format_details(Dictionary(plan.get("details", {})))


## Read only the fixed `describe_data_plan()` schema. Project-specific preview
## content belongs in `details`, not new top-level keys.
func _read_plan() -> Dictionary:
	if _data_source == null or not is_instance_valid(_data_source):
		return {
			"valid": false,
			"reason": "DATA_SOURCE_NOT_FOUND",
			"source_key": "",
			"data_version": 1,
			"phase": 0,
			"enabled": false,
			"save_enabled": false,
			"load_enabled": false,
			"summary": "",
			"sections": PackedStringArray(),
			"details": {},
		}
	if not _data_source.has_method("describe_data_plan"):
		return {
			"valid": false,
			"reason": "DATA_SOURCE_PLACEHOLDER",
			"source_key": "",
			"data_version": 1,
			"phase": 0,
			"enabled": false,
			"save_enabled": false,
			"load_enabled": false,
			"summary": "",
			"sections": PackedStringArray(),
			"details": {},
		}
	return _data_source.describe_data_plan()


func _compute_signature() -> String:
	if _data_source == null or not is_instance_valid(_data_source):
		return "<null>"
	if not _data_source.has_method("describe_data_plan"):
		return "<placeholder>"
	return JSON.stringify(_data_source.describe_data_plan())


func _format_sections(values: Variant) -> String:
	var items := PackedStringArray(values)
	if items.is_empty():
		return "<none>"
	if items.size() == 1:
		return items[0]
	return ", ".join(items)


func _describe_flow(plan: Dictionary) -> String:
	var enabled := bool(plan.get("enabled", false))
	var save_enabled := bool(plan.get("save_enabled", false))
	var load_enabled := bool(plan.get("load_enabled", false))
	if not enabled:
		return "Disabled"
	if save_enabled and load_enabled:
		return "Save + Load"
	if save_enabled:
		return "Save only"
	if load_enabled:
		return "Load only"
	return "No active flow"


func _format_details(values: Dictionary) -> String:
	if values.is_empty():
		return "<none>"
	var lines: PackedStringArray = []
	for key_variant in values.keys():
		var key := str(key_variant)
		lines.append("%s: %s" % [key, _format_detail_value(values[key_variant])])
	return "\n".join(lines)


func _format_detail_value(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "<null>"
		TYPE_DICTIONARY, TYPE_ARRAY:
			return JSON.stringify(value)
		_:
			return str(value)


func _describe_design_hint() -> String:
	return "Keep one DataSource focused on one system, model, queue, or table. Split gameplay state, machine-local settings, session caches, and debug-only data into separate persistence paths."


func _on_preview_toggled() -> void:
	_preview_expanded = not _preview_expanded
	_persist_foldout_state_to_source()
	_refresh()


func _on_design_toggled() -> void:
	_design_expanded = not _design_expanded
	_persist_foldout_state_to_source()
	_refresh()


func _on_details_toggled() -> void:
	_details_expanded = not _details_expanded
	_persist_foldout_state_to_source()
	_refresh()


func _restore_foldout_state_from_source() -> void:
	if _data_source == null or not is_instance_valid(_data_source):
		return
	_preview_expanded = bool(_data_source.get_meta(META_PREVIEW_EXPANDED, _preview_expanded))
	_design_expanded = bool(_data_source.get_meta(META_DESIGN_EXPANDED, _design_expanded))
	_details_expanded = bool(_data_source.get_meta(META_DETAILS_EXPANDED, _details_expanded))


func _persist_foldout_state_to_source() -> void:
	if _data_source == null or not is_instance_valid(_data_source):
		return
	_data_source.set_meta(META_PREVIEW_EXPANDED, _preview_expanded)
	_data_source.set_meta(META_DESIGN_EXPANDED, _design_expanded)
	_data_source.set_meta(META_DETAILS_EXPANDED, _details_expanded)


func _foldout_text(label_text: String, expanded: bool) -> String:
	return "%s %s" % ["v" if expanded else ">", label_text]


func _apply_status_style(valid: bool) -> void:
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.bg_color = _status_ok_color() if valid else _status_error_color()
	_status_chip.add_theme_stylebox_override("panel", style)
	_status_label.modulate = Color.WHITE


func _apply_panel_styles(header_panel: PanelContainer, content_panel: PanelContainer) -> void:
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = _panel_header_color()
	header_style.corner_radius_top_left = 8
	header_style.corner_radius_top_right = 8
	header_style.corner_radius_bottom_left = 8
	header_style.corner_radius_bottom_right = 8
	header_panel.add_theme_stylebox_override("panel", header_style)

	var content_style := StyleBoxFlat.new()
	content_style.bg_color = _panel_content_color()
	content_style.corner_radius_top_left = 8
	content_style.corner_radius_top_right = 8
	content_style.corner_radius_bottom_left = 8
	content_style.corner_radius_bottom_right = 8
	content_panel.add_theme_stylebox_override("panel", content_style)


func _panel_header_color() -> Color:
	return get_theme_color("dark_color_2", "Editor")


func _panel_content_color() -> Color:
	return get_theme_color("dark_color_1", "Editor")


func _status_ok_color() -> Color:
	return Color(0.22, 0.52, 0.33, 1.0)


func _status_error_color() -> Color:
	return Color(0.65, 0.26, 0.26, 1.0)
