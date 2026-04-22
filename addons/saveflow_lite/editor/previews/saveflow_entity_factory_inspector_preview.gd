@tool
extends VBoxContainer

const LABEL_WIDTH := 112
const PADDING := 10
const META_PREVIEW_EXPANDED := "_saveflow_entity_factory_preview_expanded"
const META_CONTRACT_EXPANDED := "_saveflow_entity_factory_contract_expanded"
const META_DESIGN_EXPANDED := "_saveflow_entity_factory_design_expanded"
const META_DETAILS_EXPANDED := "_saveflow_entity_factory_details_expanded"

var _entity_factory: SaveFlowEntityFactory
var _last_signature: String = ""
var _preview_expanded := true
var _contract_expanded := false
var _design_expanded := false
var _details_expanded := false

var _preview_toggle: Button
var _content_panel: PanelContainer
var _status_chip: PanelContainer
var _status_label: Label
var _factory_value: Label
var _container_value: Label
var _types_value: Label
var _routing_value: Label
var _contract_toggle: Button
var _contract_box: VBoxContainer
var _type_mode_value: Label
var _required_value: Label
var _optional_value: Label
var _capabilities_value: Label
var _design_toggle: Button
var _design_box: VBoxContainer
var _design_hint_value: Label
var _details_toggle: Button
var _details_box: VBoxContainer
var _reason_value: Label
var _factory_path_value: Label
var _container_path_value: Label


func _ready() -> void:
	_build_ui()
	set_process(true)
	_refresh()


func set_entity_factory(entity_factory: SaveFlowEntityFactory) -> void:
	_entity_factory = entity_factory
	_restore_foldout_state_from_factory()
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

	_factory_value = _add_row(content, "Factory")
	_container_value = _add_row(content, "Container")
	_types_value = _add_row(content, "Entity Types")
	_routing_value = _add_row(content, "Routing")

	_contract_toggle = Button.new()
	_contract_toggle.flat = true
	_contract_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_contract_toggle.pressed.connect(_on_contract_toggled)
	content.add_child(_contract_toggle)

	_contract_box = VBoxContainer.new()
	_contract_box.add_theme_constant_override("separation", 6)
	content.add_child(_contract_box)

	_type_mode_value = _add_row(_contract_box, "Type Mode")
	_required_value = _add_row(_contract_box, "Required")
	_optional_value = _add_row(_contract_box, "Optional")
	_capabilities_value = _add_row(_contract_box, "Implemented")

	_design_toggle = Button.new()
	_design_toggle.flat = true
	_design_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_design_toggle.pressed.connect(_on_design_toggled)
	content.add_child(_design_toggle)

	_design_box = VBoxContainer.new()
	_design_box.add_theme_constant_override("separation", 6)
	content.add_child(_design_box)

	_design_hint_value = _add_row(_design_box, "Design Hint")

	_details_toggle = Button.new()
	_details_toggle.flat = true
	_details_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_details_toggle.pressed.connect(_on_details_toggled)
	content.add_child(_details_toggle)

	_details_box = VBoxContainer.new()
	_details_box.add_theme_constant_override("separation", 6)
	content.add_child(_details_box)

	_reason_value = _add_row(_details_box, "Reason")
	_factory_path_value = _add_row(_details_box, "Factory Path")
	_container_path_value = _add_row(_details_box, "Container Path")

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
	_preview_toggle.text = _foldout_text("SaveFlow Entity Factory", _preview_expanded)
	_status_label.text = "Valid" if valid else "Invalid"
	_apply_status_style(valid)
	_content_panel.visible = _preview_expanded

	_factory_value.text = _best_name(String(plan.get("factory_name", "")), String(plan.get("factory_path", "")))
	_container_value.text = _best_name(String(plan.get("target_container_name", "")), String(plan.get("target_container_path", "")))
	_types_value.text = _format_types(PackedStringArray(plan.get("supported_entity_types", PackedStringArray())))
	_routing_value.text = String(plan.get("routing_summary", "<custom>"))

	_contract_toggle.text = _foldout_text("Contract", _contract_expanded)
	_contract_box.visible = _contract_expanded
	_type_mode_value.text = String(plan.get("type_key_mode", "<custom>"))
	_required_value.text = _format_list_inline(PackedStringArray(plan.get("required_contract", PackedStringArray())))
	_optional_value.text = _format_list_inline(PackedStringArray(plan.get("optional_hooks", PackedStringArray())))
	_capabilities_value.text = _format_capabilities(plan)

	_design_toggle.text = _foldout_text("Design", _design_expanded)
	_design_box.visible = _design_expanded
	_design_hint_value.text = _describe_design_hint(plan)

	_details_toggle.text = _foldout_text("Diagnostics", _details_expanded)
	_details_box.visible = _details_expanded
	_reason_value.text = _format_reason(plan)
	_reason_value.modulate = _warning_color() if not valid else Color(1, 1, 1, 1)
	_factory_path_value.text = String(plan.get("factory_path", ""))
	_container_path_value.text = String(plan.get("target_container_path", ""))


func _read_plan() -> Dictionary:
	if _entity_factory == null or not is_instance_valid(_entity_factory):
		return {
			"valid": false,
			"reason": "ENTITY_FACTORY_NOT_FOUND",
			"problems": PackedStringArray(["EntityFactory node instance is missing."]),
			"factory_name": "",
			"factory_path": "",
			"target_container_name": "",
			"target_container_path": "",
			"supported_entity_types": PackedStringArray(),
			"required_contract": PackedStringArray(),
			"optional_hooks": PackedStringArray(),
			"implements_find_existing": false,
			"implements_spawn": false,
			"implements_apply": false,
			"implements_prepare_restore": false,
		}
	if not _can_inspect_factory_instance(_entity_factory):
		return {
			"valid": false,
			"reason": "FACTORY_SCRIPT_PLACEHOLDER",
			"problems": PackedStringArray([
				"Factory script is currently a placeholder in editor. Ensure script compiles and is @tool before preview inspection.",
			]),
			"factory_name": _entity_factory.name,
			"factory_path": "",
			"target_container_name": "",
			"target_container_path": "",
			"supported_entity_types": PackedStringArray(),
			"required_contract": PackedStringArray(),
			"optional_hooks": PackedStringArray(),
			"implements_find_existing": false,
			"implements_spawn": false,
			"implements_apply": false,
			"implements_prepare_restore": false,
		}
	if not _entity_factory.has_method("describe_entity_factory_plan"):
		return {
			"valid": false,
			"reason": "DESCRIBE_PLAN_NOT_AVAILABLE",
			"problems": PackedStringArray([
				"Factory script could not be inspected in editor (placeholder instance or script not in tool mode).",
			]),
			"factory_name": "",
			"factory_path": "",
			"target_container_name": "",
			"target_container_path": "",
			"supported_entity_types": PackedStringArray(),
			"required_contract": PackedStringArray(),
			"optional_hooks": PackedStringArray(),
			"implements_find_existing": false,
			"implements_spawn": false,
			"implements_apply": false,
			"implements_prepare_restore": false,
		}
	if not _is_script_tool_enabled(_entity_factory):
		return {
			"valid": false,
			"reason": "FACTORY_SCRIPT_NOT_TOOL",
			"problems": PackedStringArray([
				"Factory script is not running in tool mode, so preview cannot inspect it in editor.",
			]),
			"factory_name": _entity_factory.name,
			"factory_path": "",
			"target_container_name": "",
			"target_container_path": "",
			"supported_entity_types": PackedStringArray(),
			"required_contract": PackedStringArray(),
			"optional_hooks": PackedStringArray(),
			"implements_find_existing": false,
			"implements_spawn": false,
			"implements_apply": false,
			"implements_prepare_restore": false,
		}
	var plan_variant: Variant = _entity_factory.call("describe_entity_factory_plan")
	if plan_variant is Dictionary:
		return Dictionary(plan_variant)
	return {
		"valid": false,
		"reason": "DESCRIBE_PLAN_INVALID_RESULT",
		"problems": PackedStringArray([
			"describe_entity_factory_plan() must return a Dictionary for inspector preview.",
		]),
		"factory_name": _entity_factory.name,
		"factory_path": "",
		"target_container_name": "",
		"target_container_path": "",
		"supported_entity_types": PackedStringArray(),
		"required_contract": PackedStringArray(),
		"optional_hooks": PackedStringArray(),
		"implements_find_existing": false,
		"implements_spawn": false,
		"implements_apply": false,
		"implements_prepare_restore": false,
	}


func _compute_signature() -> String:
	if _entity_factory == null or not is_instance_valid(_entity_factory):
		return "<null>"
	if not _can_inspect_factory_instance(_entity_factory):
		return "<placeholder>"
	if not _entity_factory.has_method("describe_entity_factory_plan"):
		return "<placeholder>"
	if not _is_script_tool_enabled(_entity_factory):
		return "<not_tool>"
	var plan_variant: Variant = _entity_factory.call("describe_entity_factory_plan")
	if plan_variant is Dictionary:
		return JSON.stringify(plan_variant)
	return "<invalid_plan_result>"


func _can_inspect_factory_instance(target: Object) -> bool:
	var script_ref := target.get_script() as Script
	if script_ref == null:
		return true
	return script_ref.can_instantiate()


func _is_script_tool_enabled(target: Object) -> bool:
	var script_ref := target.get_script() as Script
	if script_ref == null:
		return true
	return script_ref.is_tool()


func _best_name(name_text: String, path_text: String) -> String:
	if not name_text.is_empty():
		return name_text
	if path_text.is_empty():
		return "<none>"
	return path_text


func _format_types(type_keys: PackedStringArray) -> String:
	if type_keys.is_empty():
		return "<custom>"
	return ", ".join(type_keys)


func _format_capabilities(plan: Dictionary) -> String:
	var parts: PackedStringArray = []
	if bool(plan.get("implements_find_existing", false)):
		parts.append("find existing")
	if bool(plan.get("implements_spawn", false)):
		parts.append("spawn")
	if bool(plan.get("implements_apply", false)):
		parts.append("apply")
	if bool(plan.get("implements_prepare_restore", false)):
		parts.append("prepare restore")
	if parts.is_empty():
		return "<none>"
	return ", ".join(parts)


func _format_list_inline(values: PackedStringArray) -> String:
	if values.is_empty():
		return "<none>"
	return ", ".join(values)


func _format_reason(plan: Dictionary) -> String:
	var problems: PackedStringArray = PackedStringArray(plan.get("problems", PackedStringArray()))
	if not problems.is_empty():
		return "; ".join(problems)
	var reason_code: String = String(plan.get("reason", ""))
	if reason_code.is_empty():
		return "<none>"
	return reason_code


func _describe_design_hint(plan: Dictionary) -> String:
	if bool(plan.get("uses_prefab_scene", false)):
		return "PrefabEntityFactory is for one prefab path and one container path. Use multiple factories when routes are simple but separate; write a custom EntityFactory when lookup or spawn routing becomes project-specific."
	return "Use multiple factories for a few distinct prefab routes. Switch to a custom EntityFactory when routing depends on pooling, spawn points, registries, or other project-owned runtime systems."


func _on_preview_toggled() -> void:
	_preview_expanded = not _preview_expanded
	_persist_foldout_state_to_factory()
	_refresh()


func _on_contract_toggled() -> void:
	_contract_expanded = not _contract_expanded
	_persist_foldout_state_to_factory()
	_refresh()


func _on_design_toggled() -> void:
	_design_expanded = not _design_expanded
	_persist_foldout_state_to_factory()
	_refresh()


func _on_details_toggled() -> void:
	_details_expanded = not _details_expanded
	_persist_foldout_state_to_factory()
	_refresh()


func _restore_foldout_state_from_factory() -> void:
	if _entity_factory == null or not is_instance_valid(_entity_factory):
		return
	_preview_expanded = bool(_entity_factory.get_meta(META_PREVIEW_EXPANDED, _preview_expanded))
	_contract_expanded = bool(_entity_factory.get_meta(META_CONTRACT_EXPANDED, _contract_expanded))
	_design_expanded = bool(_entity_factory.get_meta(META_DESIGN_EXPANDED, _design_expanded))
	_details_expanded = bool(_entity_factory.get_meta(META_DETAILS_EXPANDED, _details_expanded))


func _persist_foldout_state_to_factory() -> void:
	if _entity_factory == null or not is_instance_valid(_entity_factory):
		return
	_entity_factory.set_meta(META_PREVIEW_EXPANDED, _preview_expanded)
	_entity_factory.set_meta(META_CONTRACT_EXPANDED, _contract_expanded)
	_entity_factory.set_meta(META_DESIGN_EXPANDED, _design_expanded)
	_entity_factory.set_meta(META_DETAILS_EXPANDED, _details_expanded)


func _foldout_text(label_text: String, expanded: bool) -> String:
	return "%s %s" % ["v" if expanded else ">", label_text]


func _apply_status_style(valid: bool) -> void:
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.bg_color = _ok_color() if valid else _warning_color()
	_status_chip.add_theme_stylebox_override("panel", style)
	_status_label.modulate = Color(0.08, 0.08, 0.08)


func _apply_panel_styles(header_panel: PanelContainer, content_panel: PanelContainer) -> void:
	var header_style := StyleBoxFlat.new()
	header_style.bg_color = Color(0.31, 0.35, 0.42)
	header_style.corner_radius_top_left = 8
	header_style.corner_radius_top_right = 8
	header_style.corner_radius_bottom_left = 8
	header_style.corner_radius_bottom_right = 8
	header_style.border_width_left = 1
	header_style.border_width_top = 1
	header_style.border_width_right = 1
	header_style.border_width_bottom = 1
	header_style.border_color = Color(0.52, 0.57, 0.66)
	header_panel.add_theme_stylebox_override("panel", header_style)

	var content_style := StyleBoxFlat.new()
	content_style.bg_color = Color(0.15, 0.17, 0.21)
	content_style.corner_radius_top_left = 8
	content_style.corner_radius_top_right = 8
	content_style.corner_radius_bottom_left = 8
	content_style.corner_radius_bottom_right = 8
	content_style.border_width_left = 1
	content_style.border_width_top = 1
	content_style.border_width_right = 1
	content_style.border_width_bottom = 1
	content_style.border_color = Color(0.27, 0.30, 0.36)
	content_panel.add_theme_stylebox_override("panel", content_style)


func _ok_color() -> Color:
	return Color(0.47, 0.78, 0.56)


func _warning_color() -> Color:
	return Color(0.96, 0.67, 0.35)
