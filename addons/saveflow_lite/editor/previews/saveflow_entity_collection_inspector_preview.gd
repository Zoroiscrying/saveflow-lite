@tool
extends VBoxContainer

const LABEL_WIDTH := 112
const PADDING := 10

var _entity_collection_source: SaveFlowEntityCollectionSource
var _last_signature: String = ""
var _preview_expanded := true
var _details_expanded := false

var _preview_toggle: Button
var _content_panel: PanelContainer
var _status_chip: PanelContainer
var _status_label: Label
var _target_value: Label
var _factory_value: Label
var _source_key_value: Label
var _restore_policy_value: Label
var _failure_policy_value: Label
var _container_strategy_value: Label
var _factory_types_value: Label
var _factory_spawn_value: Label
var _entity_count_value: Label
var _auto_register_checkbox: CheckBox
var _direct_children_checkbox: CheckBox
var _missing_value: RichTextLabel
var _entities_value: RichTextLabel
var _details_toggle: Button
var _details_box: VBoxContainer
var _target_path_value: Label
var _factory_path_value: Label
func _ready() -> void:
	_build_ui()
	set_process(true)
	_refresh()


func set_entity_collection_source(entity_collection_source: SaveFlowEntityCollectionSource) -> void:
	_entity_collection_source = entity_collection_source
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

	_target_value = _add_row(content, "Container")
	_factory_value = _add_row(content, "Entity Factory")
	_source_key_value = _add_row(content, "Save Key")
	_restore_policy_value = _add_row(content, "Restore")
	_failure_policy_value = _add_row(content, "Failure")
	_container_strategy_value = _add_row(content, "Container Mode")
	_factory_types_value = _add_row(content, "Factory Types")
	_factory_spawn_value = _add_row(content, "Spawn Path")
	_entity_count_value = _add_row(content, "Entities")

	_auto_register_checkbox = CheckBox.new()
	_auto_register_checkbox.text = "Auto-register this entity factory"
	_auto_register_checkbox.toggled.connect(_on_auto_register_toggled)
	content.add_child(_auto_register_checkbox)

	_direct_children_checkbox = CheckBox.new()
	_direct_children_checkbox.text = "Scan direct children only"
	_direct_children_checkbox.toggled.connect(_on_direct_children_toggled)
	content.add_child(_direct_children_checkbox)

	var missing_title := Label.new()
	missing_title.text = "Missing Identity"
	content.add_child(missing_title)

	_missing_value = RichTextLabel.new()
	_missing_value.fit_content = true
	_missing_value.scroll_active = false
	_missing_value.selection_enabled = true
	content.add_child(_missing_value)

	var entities_title := Label.new()
	entities_title.text = "Entity Members"
	content.add_child(entities_title)

	_entities_value = RichTextLabel.new()
	_entities_value.fit_content = true
	_entities_value.scroll_active = false
	_entities_value.selection_enabled = true
	content.add_child(_entities_value)

	_details_toggle = Button.new()
	_details_toggle.flat = true
	_details_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_details_toggle.pressed.connect(_on_details_toggled)
	content.add_child(_details_toggle)

	_details_box = VBoxContainer.new()
	_details_box.add_theme_constant_override("separation", 6)
	content.add_child(_details_box)

	_target_path_value = _add_row(_details_box, "Container Path")
	_factory_path_value = _add_row(_details_box, "Factory Path")
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
	var missing_identities: PackedStringArray = PackedStringArray(plan.get("missing_identity_nodes", PackedStringArray()))
	var entity_candidates: Array = Array(plan.get("entity_candidates", []))

	_preview_toggle.text = _foldout_text("SaveFlow Entity Collection", _preview_expanded)
	_status_label.text = "Valid" if valid else "Invalid"
	_apply_status_style(valid)
	_content_panel.visible = _preview_expanded

	_target_value.text = _best_name(String(plan.get("target_name", "")), String(plan.get("target_path", "")))
	_factory_value.text = _best_name(String(plan.get("entity_factory_name", "")), String(plan.get("entity_factory_path", "")))
	_source_key_value.text = String(plan.get("source_key", ""))
	_restore_policy_value.text = String(plan.get("restore_policy_name", "Create Missing"))
	_failure_policy_value.text = String(plan.get("failure_policy_name", "Fail On Missing Or Invalid"))
	_container_strategy_value.text = String(plan.get("target_resolution", "<none>"))
	_factory_types_value.text = _format_list(plan.get("factory_supported_entity_types", PackedStringArray()))
	_factory_spawn_value.text = String(plan.get("factory_spawn_summary", ""))
	_entity_count_value.text = str(int(plan.get("entity_count", 0)))

	_auto_register_checkbox.set_block_signals(true)
	_auto_register_checkbox.button_pressed = bool(plan.get("auto_register_factory", false))
	_auto_register_checkbox.set_block_signals(false)

	_direct_children_checkbox.set_block_signals(true)
	_direct_children_checkbox.button_pressed = bool(plan.get("include_direct_children_only", false))
	_direct_children_checkbox.set_block_signals(false)

	_missing_value.text = _format_list(missing_identities)
	_missing_value.modulate = _warning_color()
	_entities_value.text = _format_entity_candidates(entity_candidates)

	_details_toggle.text = _foldout_text("Details", _details_expanded)
	_details_box.visible = _details_expanded
	_target_path_value.text = String(plan.get("target_path", ""))
	_factory_path_value.text = String(plan.get("entity_factory_path", ""))

func _read_plan() -> Dictionary:
	if _entity_collection_source == null or not is_instance_valid(_entity_collection_source):
		return {
			"valid": false,
			"reason": "RUNTIME_COLLECTION_NOT_FOUND",
			"source_key": "",
			"target_name": "",
			"target_path": "",
			"entity_factory_name": "",
			"entity_factory_path": "",
			"missing_identity_nodes": PackedStringArray(),
			"entity_candidates": [],
		}
	if not _entity_collection_source.has_method("describe_entity_collection_plan"):
		return {
			"valid": false,
			"reason": "RUNTIME_COLLECTION_PLACEHOLDER",
			"source_key": "",
			"target_name": "",
			"target_path": "",
			"entity_factory_name": "",
			"entity_factory_path": "",
			"missing_identity_nodes": PackedStringArray(),
			"entity_candidates": [],
		}
	return _entity_collection_source.describe_entity_collection_plan()


func _compute_signature() -> String:
	if _entity_collection_source == null or not is_instance_valid(_entity_collection_source):
		return "<null>"
	if not _entity_collection_source.has_method("describe_entity_collection_plan"):
		return "<placeholder>"
	return JSON.stringify(_entity_collection_source.describe_entity_collection_plan())


func _best_name(name_text: String, path_text: String) -> String:
	if not name_text.is_empty():
		return name_text
	if path_text.is_empty():
		return "<none>"
	return path_text


func _format_list(values: Variant) -> String:
	var items: PackedStringArray = PackedStringArray(values)
	if items.is_empty():
		return "<none>"
	return ", ".join(items)


func _format_entity_candidates(candidates: Array) -> String:
	if candidates.is_empty():
		return "<none>"
	var lines: PackedStringArray = []
	for candidate_variant in candidates:
		var candidate: Dictionary = candidate_variant
		var path_text: String = String(candidate.get("path", ""))
		var persistent_id: String = String(candidate.get("persistent_id", ""))
		var type_key: String = String(candidate.get("type_key", ""))
		var suffix_parts: PackedStringArray = []
		if not persistent_id.is_empty():
			suffix_parts.append("id=%s" % persistent_id)
		else:
			suffix_parts.append("missing identity")
		if not type_key.is_empty():
			suffix_parts.append("type=%s" % type_key)
		if bool(candidate.get("has_local_scope", false)):
			suffix_parts.append("local scope")
		lines.append("%s [%s]" % [path_text, ", ".join(suffix_parts)])
	return "\n".join(lines)


func _on_preview_toggled() -> void:
	_preview_expanded = not _preview_expanded
	_refresh()


func _on_details_toggled() -> void:
	_details_expanded = not _details_expanded
	_refresh()


func _on_auto_register_toggled(pressed: bool) -> void:
	if _entity_collection_source == null or not is_instance_valid(_entity_collection_source):
		return
	_entity_collection_source.auto_register_factory = pressed
	_mark_collection_dirty()
	_refresh()


func _on_direct_children_toggled(pressed: bool) -> void:
	if _entity_collection_source == null or not is_instance_valid(_entity_collection_source):
		return
	_entity_collection_source.include_direct_children_only = pressed
	_mark_collection_dirty()
	_refresh()


func _mark_collection_dirty() -> void:
	if _entity_collection_source == null or not is_instance_valid(_entity_collection_source):
		return
	_entity_collection_source.notify_property_list_changed()


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
