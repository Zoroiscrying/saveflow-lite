## Renders the fixed `describe_scope_plan()` schema for SaveFlowScope.
## The preview stays lightweight on purpose: scope previews explain domain
## boundaries, ordering, and restore strategy, not leaf payload contents.
@tool
extends VBoxContainer

const LABEL_WIDTH := 112
const PADDING := 10

var _scope: SaveFlowScope
var _last_signature: String = ""
var _preview_expanded := true
var _details_expanded := false

var _preview_toggle: Button
var _content_panel: PanelContainer
var _status_chip: PanelContainer
var _status_label: Label
var _scope_key_value: Label
var _namespace_value: Label
var _phase_value: Label
var _restore_policy_value: Label
var _child_scopes_value: Label
var _child_sources_value: Label
var _enabled_checkbox: CheckBox
var _save_enabled_checkbox: CheckBox
var _load_enabled_checkbox: CheckBox
var _details_toggle: Button
var _details_box: VBoxContainer
var _reason_value: Label
var _scope_list_value: RichTextLabel
var _source_list_value: RichTextLabel


func _ready() -> void:
	_build_ui()
	set_process(true)
	_refresh()


func set_scope(scope: SaveFlowScope) -> void:
	_scope = scope
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

	_scope_key_value = _add_row(content, "Scope Key")
	_namespace_value = _add_row(content, "Namespace")
	_phase_value = _add_row(content, "Phase")
	_restore_policy_value = _add_row(content, "Domain Restore")
	_child_scopes_value = _add_row(content, "Child Domains")
	_child_sources_value = _add_row(content, "Leaf Sources")

	_enabled_checkbox = CheckBox.new()
	_enabled_checkbox.text = "Enabled"
	_enabled_checkbox.disabled = true
	content.add_child(_enabled_checkbox)

	_save_enabled_checkbox = CheckBox.new()
	_save_enabled_checkbox.text = "Save enabled"
	_save_enabled_checkbox.disabled = true
	content.add_child(_save_enabled_checkbox)

	_load_enabled_checkbox = CheckBox.new()
	_load_enabled_checkbox.text = "Load enabled"
	_load_enabled_checkbox.disabled = true
	content.add_child(_load_enabled_checkbox)

	_details_toggle = Button.new()
	_details_toggle.flat = true
	_details_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_details_toggle.pressed.connect(_on_details_toggled)
	content.add_child(_details_toggle)

	_details_box = VBoxContainer.new()
	_details_box.add_theme_constant_override("separation", 6)
	content.add_child(_details_box)

	_reason_value = _add_row(_details_box, "Reason")

	var scope_list_title := Label.new()
	scope_list_title.text = "Child Domains"
	_details_box.add_child(scope_list_title)

	_scope_list_value = RichTextLabel.new()
	_scope_list_value.fit_content = true
	_scope_list_value.scroll_active = false
	_scope_list_value.selection_enabled = true
	_details_box.add_child(_scope_list_value)

	var source_list_title := Label.new()
	source_list_title.text = "Leaf Sources"
	_details_box.add_child(source_list_title)

	_source_list_value = RichTextLabel.new()
	_source_list_value.fit_content = true
	_source_list_value.scroll_active = false
	_source_list_value.selection_enabled = true
	_details_box.add_child(_source_list_value)

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

	_preview_toggle.text = _foldout_text("SaveFlow Domain Scope", _preview_expanded)
	_status_label.text = "Valid" if valid else "Invalid"
	_apply_status_style(valid)
	_content_panel.visible = _preview_expanded

	_scope_key_value.text = String(plan.get("scope_key", ""))
	_namespace_value.text = String(plan.get("key_namespace", ""))
	_phase_value.text = str(int(plan.get("phase", 0)))
	_restore_policy_value.text = String(plan.get("restore_policy_name", "Inherit"))
	_child_scopes_value.text = str(int(plan.get("child_scope_count", 0)))
	_child_sources_value.text = str(int(plan.get("child_source_count", 0)))

	_enabled_checkbox.button_pressed = bool(plan.get("enabled", false))
	_save_enabled_checkbox.button_pressed = bool(plan.get("save_enabled", false))
	_load_enabled_checkbox.button_pressed = bool(plan.get("load_enabled", false))

	_details_toggle.text = _foldout_text("Details", _details_expanded)
	_details_box.visible = _details_expanded
	_reason_value.text = String(plan.get("reason", ""))
	_scope_list_value.text = _format_list(plan.get("child_scope_keys", PackedStringArray()))
	_source_list_value.text = _format_list(plan.get("child_source_keys", PackedStringArray()))


## Read only the fixed `describe_scope_plan()` schema. Scope preview content is
## intentionally structural so the inspector remains predictable.
func _read_plan() -> Dictionary:
	if _scope == null or not is_instance_valid(_scope):
		return {
			"valid": false,
			"reason": "SCOPE_NOT_FOUND",
			"scope_key": "",
			"enabled": false,
			"save_enabled": false,
			"load_enabled": false,
			"key_namespace": "",
			"phase": 0,
			"restore_policy_name": "Inherit",
			"child_scope_count": 0,
			"child_source_count": 0,
			"child_scope_keys": PackedStringArray(),
			"child_source_keys": PackedStringArray(),
		}
	if not _scope.has_method("describe_scope_plan"):
		return {
			"valid": false,
			"reason": "SCOPE_PLACEHOLDER",
			"scope_key": "",
			"enabled": false,
			"save_enabled": false,
			"load_enabled": false,
			"key_namespace": "",
			"phase": 0,
			"restore_policy_name": "Inherit",
			"child_scope_count": 0,
			"child_source_count": 0,
			"child_scope_keys": PackedStringArray(),
			"child_source_keys": PackedStringArray(),
		}
	if _scope.get_script() == null:
		return {
			"valid": false,
			"reason": "SCOPE_PLACEHOLDER",
			"scope_key": "",
			"enabled": false,
			"save_enabled": false,
			"load_enabled": false,
			"key_namespace": "",
			"phase": 0,
			"restore_policy_name": "Inherit",
			"child_scope_count": 0,
			"child_source_count": 0,
			"child_scope_keys": PackedStringArray(),
			"child_source_keys": PackedStringArray(),
		}
	return _scope.describe_scope_plan()


func _compute_signature() -> String:
	if _scope == null or not is_instance_valid(_scope):
		return "<null>"
	if not _scope.has_method("describe_scope_plan"):
		return "<placeholder>"
	if _scope.get_script() == null:
		return "<placeholder>"
	return JSON.stringify(_scope.describe_scope_plan())


func _format_list(values: Variant) -> String:
	var items := PackedStringArray(values)
	if items.is_empty():
		return "<none>"
	return "\n".join(items)


func _on_preview_toggled() -> void:
	_preview_expanded = not _preview_expanded
	_refresh()


func _on_details_toggled() -> void:
	_details_expanded = not _details_expanded
	_refresh()


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
