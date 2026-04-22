## Renders the fixed `describe_scope_plan()` schema for SaveFlowScope.
## The preview stays lightweight on purpose: scope previews explain domain
## boundaries, ordering, and restore strategy, not leaf payload contents.
@tool
extends VBoxContainer

const LABEL_WIDTH := 112
const PADDING := 10
const META_PREVIEW_EXPANDED := "_saveflow_scope_preview_expanded"
const META_CONTRACT_EXPANDED := "_saveflow_scope_contract_expanded"
const META_MEMBERS_EXPANDED := "_saveflow_scope_members_expanded"
const META_DETAILS_EXPANDED := "_saveflow_scope_details_expanded"

var _scope: SaveFlowScope
var _last_signature: String = ""
var _preview_expanded := true
var _contract_expanded := false
var _members_expanded := false
var _details_expanded := false

var _preview_toggle: Button
var _content_panel: PanelContainer
var _status_chip: PanelContainer
var _status_label: Label
var _scope_key_value: Label
var _restore_policy_value: Label
var _child_scopes_value: Label
var _child_sources_value: Label
var _contract_toggle: Button
var _contract_box: VBoxContainer
var _restore_contract_value: Label
var _flow_value: Label
var _members_toggle: Button
var _members_box: VBoxContainer
var _scope_list_value: RichTextLabel
var _source_list_value: RichTextLabel
var _details_toggle: Button
var _details_box: VBoxContainer
var _namespace_value: Label
var _phase_value: Label
var _reason_value: Label


func _ready() -> void:
	_build_ui()
	set_process(true)
	_refresh()


func set_scope(scope: SaveFlowScope) -> void:
	_scope = scope
	_restore_foldout_state_from_scope()
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
	_restore_policy_value = _add_row(content, "Domain Restore")
	_child_scopes_value = _add_row(content, "Child Domains")
	_child_sources_value = _add_row(content, "Leaf Sources")

	_contract_toggle = Button.new()
	_contract_toggle.flat = true
	_contract_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_contract_toggle.pressed.connect(_on_contract_toggled)
	content.add_child(_contract_toggle)

	_contract_box = VBoxContainer.new()
	_contract_box.add_theme_constant_override("separation", 6)
	content.add_child(_contract_box)

	_restore_contract_value = _add_row(_contract_box, "Restore Contract")
	_flow_value = _add_row(_contract_box, "Flow")

	_members_toggle = Button.new()
	_members_toggle.flat = true
	_members_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_members_toggle.pressed.connect(_on_members_toggled)
	content.add_child(_members_toggle)

	_members_box = VBoxContainer.new()
	_members_box.add_theme_constant_override("separation", 6)
	content.add_child(_members_box)

	var scope_list_title := Label.new()
	scope_list_title.text = "Child Domains"
	_members_box.add_child(scope_list_title)

	_scope_list_value = RichTextLabel.new()
	_scope_list_value.fit_content = true
	_scope_list_value.scroll_active = false
	_scope_list_value.selection_enabled = true
	_members_box.add_child(_scope_list_value)

	var source_list_title := Label.new()
	source_list_title.text = "Leaf Sources"
	_members_box.add_child(source_list_title)

	_source_list_value = RichTextLabel.new()
	_source_list_value.fit_content = true
	_source_list_value.scroll_active = false
	_source_list_value.selection_enabled = true
	_members_box.add_child(_source_list_value)

	_details_toggle = Button.new()
	_details_toggle.flat = true
	_details_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_details_toggle.pressed.connect(_on_details_toggled)
	content.add_child(_details_toggle)

	_details_box = VBoxContainer.new()
	_details_box.add_theme_constant_override("separation", 6)
	content.add_child(_details_box)

	_namespace_value = _add_row(_details_box, "Namespace")
	_phase_value = _add_row(_details_box, "Phase")
	_reason_value = _add_row(_details_box, "Reason")

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
	_restore_policy_value.text = String(plan.get("restore_policy_name", "Inherit"))
	_child_scopes_value.text = str(int(plan.get("child_scope_count", 0)))
	_child_sources_value.text = str(int(plan.get("child_source_count", 0)))

	_contract_toggle.text = _foldout_text("Contract", _contract_expanded)
	_contract_box.visible = _contract_expanded
	_restore_contract_value.text = _describe_restore_contract(plan)
	_flow_value.text = _describe_flow(plan)

	_members_toggle.text = _foldout_text("Members", _members_expanded)
	_members_box.visible = _members_expanded
	_scope_list_value.text = _format_list(plan.get("child_scope_keys", PackedStringArray()))
	_source_list_value.text = _format_list(plan.get("child_source_keys", PackedStringArray()))

	_details_toggle.text = _foldout_text("Diagnostics", _details_expanded)
	_details_box.visible = _details_expanded
	_namespace_value.text = String(plan.get("key_namespace", ""))
	_phase_value.text = str(int(plan.get("phase", 0)))
	_reason_value.text = _format_reason(plan)


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


func _format_reason(plan: Dictionary) -> String:
	var problems: PackedStringArray = PackedStringArray(plan.get("problems", PackedStringArray()))
	if not problems.is_empty():
		return "; ".join(problems)
	var reason_code: String = String(plan.get("reason", ""))
	if reason_code.is_empty():
		return "<none>"
	return reason_code


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


func _describe_restore_contract(plan: Dictionary) -> String:
	if not bool(plan.get("load_enabled", false)):
		return "Load is disabled for this domain, so it does not currently participate in restore."
	return "Restore this domain on the scope root that owns it. When scene-path verification is enabled, the expected scene must already be active before scope load; disabling that check removes a safety guard, not the need for orchestration."


func _on_preview_toggled() -> void:
	_preview_expanded = not _preview_expanded
	_persist_foldout_state_to_scope()
	_refresh()


func _on_contract_toggled() -> void:
	_contract_expanded = not _contract_expanded
	_persist_foldout_state_to_scope()
	_refresh()


func _on_members_toggled() -> void:
	_members_expanded = not _members_expanded
	_persist_foldout_state_to_scope()
	_refresh()


func _on_details_toggled() -> void:
	_details_expanded = not _details_expanded
	_persist_foldout_state_to_scope()
	_refresh()


func _restore_foldout_state_from_scope() -> void:
	if _scope == null or not is_instance_valid(_scope):
		return
	_preview_expanded = bool(_scope.get_meta(META_PREVIEW_EXPANDED, _preview_expanded))
	_contract_expanded = bool(_scope.get_meta(META_CONTRACT_EXPANDED, _contract_expanded))
	_members_expanded = bool(_scope.get_meta(META_MEMBERS_EXPANDED, _members_expanded))
	_details_expanded = bool(_scope.get_meta(META_DETAILS_EXPANDED, _details_expanded))


func _persist_foldout_state_to_scope() -> void:
	if _scope == null or not is_instance_valid(_scope):
		return
	_scope.set_meta(META_PREVIEW_EXPANDED, _preview_expanded)
	_scope.set_meta(META_CONTRACT_EXPANDED, _contract_expanded)
	_scope.set_meta(META_MEMBERS_EXPANDED, _members_expanded)
	_scope.set_meta(META_DETAILS_EXPANDED, _details_expanded)


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
