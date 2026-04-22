@tool
extends VBoxContainer

const LABEL_WIDTH := 112
const PADDING := 10
const META_PREVIEW_EXPANDED := "_saveflow_node_source_preview_expanded"
const META_DETAILS_EXPANDED := "_saveflow_node_source_details_expanded"
const META_ADVANCED_EXPANDED := "_saveflow_node_source_advanced_expanded"
const META_BUILT_INS_EXPANDED := "_saveflow_node_source_built_ins_expanded"
const META_PARTICIPANTS_EXPANDED := "_saveflow_node_source_participants_expanded"
const META_PATHS_EXPANDED := "_saveflow_node_source_paths_expanded"
const META_DIAGNOSTICS_EXPANDED := "_saveflow_node_source_diagnostics_expanded"

var _node_source: SaveFlowNodeSource
var _last_signature: String = ""
var _preview_expanded := true
var _details_expanded := false
var _built_ins_expanded := false
var _participants_expanded := false
var _paths_expanded := false
var _diagnostics_expanded := false

var _preview_toggle: Button
var _content_panel: PanelContainer
var _status_chip: PanelContainer
var _status_label: Label
var _target_value: Label
var _save_key_value: Label
var _ownership_value: Label
var _children_value: Label
var _target_fields_value: Label
var _built_ins_toggle: Button
var _built_ins_box: VBoxContainer
var _include_target_checkbox: CheckBox
var _target_built_ins_box: VBoxContainer
var _built_in_advanced_toggle: Button
var _built_in_advanced_box: VBoxContainer
var _participants_toggle: Button
var _participants_box: VBoxContainer
var _participant_candidates_box: VBoxContainer
var _missing_title: Label
var _missing_value: RichTextLabel
var _discovery_mode_option: OptionButton
var _details_toggle: Button
var _details_box: VBoxContainer
var _details_restore_contract_value: Label
var _details_design_hint_value: Label
var _paths_toggle: Button
var _paths_box: VBoxContainer
var _saved_fields_detail_value: Label
var _included_paths_value: Label
var _excluded_paths_value: Label
var _target_path_value: Label
var _diagnostics_toggle: Button
var _diagnostics_box: VBoxContainer
var _supported_value: Label

var _built_in_advanced_expanded := false


func _ready() -> void:
	_build_ui()
	set_process(true)
	_refresh()


func set_node_source(node_source: SaveFlowNodeSource) -> void:
	_node_source = node_source
	_restore_foldout_state_from_source()
	_refresh()


func _process(_delta: float) -> void:
	var signature: String = _compute_signature()
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

	_target_value = _add_row(content, "Target")
	_save_key_value = _add_row(content, "Save Key")
	_ownership_value = _add_row(content, "Owns")
	_children_value = _add_row(content, "Children")
	_target_fields_value = _add_row(content, "Saved Fields")

	_built_ins_toggle = Button.new()
	_built_ins_toggle.flat = true
	_built_ins_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_built_ins_toggle.pressed.connect(_on_built_ins_toggled)
	content.add_child(_built_ins_toggle)

	_built_ins_box = VBoxContainer.new()
	_built_ins_box.add_theme_constant_override("separation", 6)
	content.add_child(_built_ins_box)

	var built_in_title := Label.new()
	built_in_title.text = "Built-In State"
	_built_ins_box.add_child(built_in_title)

	_include_target_checkbox = CheckBox.new()
	_include_target_checkbox.text = "Include target built-ins"
	_include_target_checkbox.toggled.connect(_on_include_target_toggled)
	_built_ins_box.add_child(_include_target_checkbox)

	_target_built_ins_box = VBoxContainer.new()
	_target_built_ins_box.add_theme_constant_override("separation", 4)
	_built_ins_box.add_child(_target_built_ins_box)

	_built_in_advanced_toggle = Button.new()
	_built_in_advanced_toggle.flat = true
	_built_in_advanced_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_built_in_advanced_toggle.pressed.connect(_on_built_in_advanced_toggled)
	_built_ins_box.add_child(_built_in_advanced_toggle)

	_built_in_advanced_box = VBoxContainer.new()
	_built_in_advanced_box.add_theme_constant_override("separation", 6)
	_built_ins_box.add_child(_built_in_advanced_box)

	_participants_toggle = Button.new()
	_participants_toggle.flat = true
	_participants_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_participants_toggle.pressed.connect(_on_participants_toggled)
	content.add_child(_participants_toggle)

	_participants_box = VBoxContainer.new()
	_participants_box.add_theme_constant_override("separation", 6)
	content.add_child(_participants_box)

	var participant_title := Label.new()
	participant_title.text = "Included Children"
	_participants_box.add_child(participant_title)

	var discovery_row := HBoxContainer.new()
	discovery_row.add_theme_constant_override("separation", 10)
	_participants_box.add_child(discovery_row)

	var discovery_label := Label.new()
	discovery_label.custom_minimum_size.x = LABEL_WIDTH
	discovery_label.text = "Scan"
	discovery_label.modulate = get_theme_color("font_placeholder_color", "Editor")
	discovery_row.add_child(discovery_label)

	_discovery_mode_option = OptionButton.new()
	_discovery_mode_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_discovery_mode_option.add_item("Direct", 0)
	_discovery_mode_option.add_item("Recursive", 1)
	_discovery_mode_option.item_selected.connect(_on_participant_discovery_mode_selected)
	discovery_row.add_child(_discovery_mode_option)

	_participant_candidates_box = VBoxContainer.new()
	_participant_candidates_box.add_theme_constant_override("separation", 4)
	_participants_box.add_child(_participant_candidates_box)

	_missing_title = Label.new()
	_missing_title.text = "Missing Children"
	_participants_box.add_child(_missing_title)

	_missing_value = RichTextLabel.new()
	_missing_value.fit_content = true
	_missing_value.scroll_active = false
	_missing_value.selection_enabled = true
	_participants_box.add_child(_missing_value)

	_details_toggle = Button.new()
	_details_toggle.flat = true
	_details_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_details_toggle.pressed.connect(_on_details_toggled)
	content.add_child(_details_toggle)

	_details_box = VBoxContainer.new()
	_details_box.add_theme_constant_override("separation", 6)
	content.add_child(_details_box)

	_details_restore_contract_value = _add_row(_details_box, "Restore Contract")
	_details_design_hint_value = _add_row(_details_box, "Design Hint")

	_paths_toggle = Button.new()
	_paths_toggle.flat = true
	_paths_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_paths_toggle.pressed.connect(_on_paths_toggled)
	content.add_child(_paths_toggle)

	_paths_box = VBoxContainer.new()
	_paths_box.add_theme_constant_override("separation", 6)
	content.add_child(_paths_box)

	_target_path_value = _add_row(_paths_box, "Object Path")
	_saved_fields_detail_value = _add_row(_paths_box, "Saved Fields")
	_included_paths_value = _add_row(_paths_box, "Included Children")
	_excluded_paths_value = _add_row(_paths_box, "Excluded Children")

	_diagnostics_toggle = Button.new()
	_diagnostics_toggle.flat = true
	_diagnostics_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_diagnostics_toggle.pressed.connect(_on_diagnostics_toggled)
	content.add_child(_diagnostics_toggle)

	_diagnostics_box = VBoxContainer.new()
	_diagnostics_box.add_theme_constant_override("separation", 6)
	content.add_child(_diagnostics_box)

	_supported_value = _add_row(_diagnostics_box, "Available Built-Ins")

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

	var plan: Dictionary = _read_plan()
	var valid := bool(plan.get("valid", false))
	var missing_paths: PackedStringArray = PackedStringArray(plan.get("missing_paths", PackedStringArray()))
	var target_options: Array = _read_target_built_in_options()
	var participant_candidates: Array = _read_participant_candidates()

	_preview_toggle.text = _foldout_text("SaveFlow Object Source", _preview_expanded)
	_status_label.text = "Valid" if valid else "Invalid"
	_apply_status_style(valid)
	_content_panel.visible = _preview_expanded

	_target_value.text = _format_target_display(plan)
	_save_key_value.text = String(plan.get("save_key", ""))
	_ownership_value.text = _describe_ownership_summary(plan)
	_children_value.text = _describe_children_summary(plan)
	_target_fields_value.text = _format_field_summary(PackedStringArray(plan.get("target_properties", PackedStringArray())))
	_built_ins_toggle.text = _foldout_text("Built-In State", _built_ins_expanded)
	_built_ins_box.visible = _built_ins_expanded
	_include_target_checkbox.set_block_signals(true)
	_include_target_checkbox.button_pressed = bool(_node_source != null and _node_source.include_target_built_ins)
	_include_target_checkbox.set_block_signals(false)
	_discovery_mode_option.set_block_signals(true)
	_discovery_mode_option.select(int(plan.get("participant_discovery_mode", 1)))
	_discovery_mode_option.set_block_signals(false)

	_rebuild_target_built_in_controls(target_options)
	_built_in_advanced_toggle.text = _foldout_text("Advanced Built-Ins", _built_in_advanced_expanded)
	_built_in_advanced_box.visible = _built_in_advanced_expanded
	_rebuild_built_in_advanced_controls(target_options)
	_participants_toggle.text = _foldout_text("Included Children", _participants_expanded)
	_participants_box.visible = _participants_expanded
	_rebuild_participant_controls(participant_candidates)

	_missing_value.text = _format_list(missing_paths)
	_missing_value.modulate = _warning_color()
	_missing_title.visible = not missing_paths.is_empty()
	_missing_value.visible = not missing_paths.is_empty()

	_details_toggle.text = _foldout_text("Contract", _details_expanded)
	_details_box.visible = _details_expanded
	_details_restore_contract_value.text = _describe_restore_contract(plan)
	_details_design_hint_value.text = _describe_design_hint(plan)
	_details_design_hint_value.modulate = _warning_color() if not PackedStringArray(plan.get("ownership_conflicts", PackedStringArray())).is_empty() else Color(1, 1, 1, 1)
	_paths_toggle.text = _foldout_text("Paths", _paths_expanded)
	_paths_box.visible = _paths_expanded
	_target_path_value.text = String(plan.get("target_path", ""))
	_saved_fields_detail_value.text = _format_list(plan.get("target_properties", PackedStringArray()))
	_included_paths_value.text = _format_list(plan.get("included_paths", PackedStringArray()))
	_excluded_paths_value.text = _format_list(plan.get("excluded_paths", PackedStringArray()))
	_diagnostics_toggle.text = _foldout_text("Diagnostics", _diagnostics_expanded)
	_diagnostics_box.visible = _diagnostics_expanded
	_supported_value.text = _format_display_name_list(target_options)


func _read_plan() -> Dictionary:
	if _node_source == null or not is_instance_valid(_node_source):
		return {
			"valid": false,
			"reason": "NODE_SOURCE_NOT_FOUND",
			"save_key": "",
			"target_name": "",
			"target_path": "",
			"active_target_built_ins": PackedStringArray(),
			"supported_target_built_ins": PackedStringArray(),
			"included_paths": PackedStringArray(),
			"excluded_paths": PackedStringArray(),
			"participant_discovery_mode": 1,
			"resolved_participants": [],
			"missing_paths": PackedStringArray(),
		}
	if not _node_source.has_method("describe_node_plan"):
		return {
			"valid": false,
			"reason": "NODE_SOURCE_PLACEHOLDER",
			"save_key": "",
			"target_name": "",
			"target_path": "",
			"active_target_built_ins": PackedStringArray(),
			"supported_target_built_ins": PackedStringArray(),
			"included_paths": PackedStringArray(),
			"excluded_paths": PackedStringArray(),
			"participant_discovery_mode": 1,
			"resolved_participants": [],
			"missing_paths": PackedStringArray(),
		}
	return _node_source.describe_node_plan()


func _read_target_built_in_options() -> Array:
	if _node_source == null or not is_instance_valid(_node_source):
		return []
	if not _node_source.has_method("describe_target_built_in_options"):
		return []
	return _node_source.describe_target_built_in_options()


func _read_participant_candidates() -> Array:
	if _node_source == null or not is_instance_valid(_node_source):
		return []
	if not _node_source.has_method("discover_participant_candidates"):
		return []
	return _node_source.discover_participant_candidates()


func _compute_signature() -> String:
	if _node_source == null or not is_instance_valid(_node_source):
		return "<null>"
	if not _node_source.has_method("describe_node_plan"):
		return "<placeholder>"
	return JSON.stringify(
		{
			"plan": _node_source.describe_node_plan(),
			"target_options": _node_source.describe_target_built_in_options(),
			"participant_candidates": _node_source.discover_participant_candidates(),
		}
	)


func _rebuild_target_built_in_controls(options: Array) -> void:
	_clear_children(_target_built_ins_box)
	if options.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No built-in serializers available for the target."
		empty_label.modulate = get_theme_color("font_placeholder_color", "Editor")
		_target_built_ins_box.add_child(empty_label)
		return

	for option_variant in options:
		var option: Dictionary = option_variant
		var serializer_id: String = String(option.get("id", ""))
		var checkbox := CheckBox.new()
		checkbox.text = String(option.get("display_name", serializer_id))
		checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		checkbox.disabled = not _include_target_checkbox.button_pressed
		checkbox.button_pressed = bool(option.get("selected", false))
		checkbox.toggled.connect(
			func(pressed: bool) -> void:
				_on_target_built_in_toggled(serializer_id, pressed)
		)
		_target_built_ins_box.add_child(checkbox)


func _rebuild_built_in_advanced_controls(options: Array) -> void:
	_clear_children(_built_in_advanced_box)
	if options.is_empty():
		return

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	_built_in_advanced_box.add_child(action_row)

	var recommended_button := Button.new()
	recommended_button.text = "Use Recommended"
	recommended_button.disabled = not _include_target_checkbox.button_pressed
	recommended_button.pressed.connect(_on_use_recommended_fields_pressed)
	action_row.add_child(recommended_button)

	var save_all_button := Button.new()
	save_all_button.text = "Save All Fields"
	save_all_button.disabled = not _include_target_checkbox.button_pressed
	save_all_button.pressed.connect(_on_save_all_fields_pressed)
	action_row.add_child(save_all_button)

	for option_variant in options:
		var option: Dictionary = option_variant
		var serializer_id: String = String(option.get("id", ""))
		var fields: Array = Array(option.get("fields", []))
		if fields.is_empty():
			continue
		var selected_fields: PackedStringArray = PackedStringArray(option.get("selected_fields", PackedStringArray()))
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		_built_in_advanced_box.add_child(box)

		var title := Label.new()
		title.text = String(option.get("display_name", serializer_id))
		title.modulate = get_theme_color("font_placeholder_color", "Editor")
		box.add_child(title)

		for field_variant in fields:
			if not (field_variant is Dictionary):
				continue
			var field: Dictionary = field_variant
			var field_id: String = String(field.get("id", ""))
			if field_id.is_empty():
				continue
			var field_checkbox := CheckBox.new()
			field_checkbox.text = String(field.get("display_name", field_id))
			field_checkbox.button_pressed = selected_fields.has(field_id)
			field_checkbox.disabled = not _include_target_checkbox.button_pressed or not bool(option.get("selected", false))
			field_checkbox.toggled.connect(
				func(pressed: bool) -> void:
					_on_target_built_in_field_toggled(serializer_id, field_id, pressed)
			)
			box.add_child(field_checkbox)


func _rebuild_participant_controls(candidates: Array) -> void:
	_clear_children(_participant_candidates_box)
	if candidates.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No child nodes with SaveFlow behavior or built-in state were discovered."
		empty_label.modulate = get_theme_color("font_placeholder_color", "Editor")
		_participant_candidates_box.add_child(empty_label)
		return

	for candidate_variant in candidates:
		var candidate: Dictionary = candidate_variant
		var path_text: String = String(candidate.get("path", ""))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_participant_candidates_box.add_child(row)

		var indent := Control.new()
		indent.custom_minimum_size.x = float(int(candidate.get("depth", 0)) * 14)
		row.add_child(indent)

		var include_checkbox := CheckBox.new()
		include_checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		include_checkbox.text = _format_candidate_label(candidate)
		include_checkbox.icon = _resolve_candidate_icon(candidate)
		include_checkbox.button_pressed = bool(candidate.get("included", false))
		include_checkbox.disabled = bool(candidate.get("excluded", false))
		include_checkbox.toggled.connect(
			func(pressed: bool) -> void:
				_on_participant_toggled(path_text, pressed)
		)
		row.add_child(include_checkbox)

		var exclude_checkbox := CheckBox.new()
		exclude_checkbox.text = "Exclude"
		exclude_checkbox.button_pressed = bool(candidate.get("excluded", false))
		exclude_checkbox.toggled.connect(
			func(pressed: bool) -> void:
				_on_participant_excluded_toggled(path_text, pressed)
		)
		row.add_child(exclude_checkbox)


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _format_list(values: Variant) -> String:
	var items: PackedStringArray = PackedStringArray(values)
	if items.is_empty():
		return "<none>"
	return ", ".join(items)


func _format_field_summary(values: PackedStringArray) -> String:
	if values.is_empty():
		return "<none>"
	if values.size() == 1:
		return values[0]
	return "%d fields" % values.size()


func _format_target_display(plan: Dictionary) -> String:
	var target_name: String = String(plan.get("target_name", ""))
	if not target_name.is_empty():
		return target_name
	var raw_path: String = String(plan.get("target_path", ""))
	if raw_path.is_empty():
		return "<none>"
	return raw_path


func _format_display_name_list(options: Array) -> String:
	if options.is_empty():
		return "<none>"
	var items: PackedStringArray = []
	for option_variant in options:
		var option: Dictionary = option_variant
		items.append(String(option.get("display_name", option.get("id", ""))))
	return ", ".join(items)


func _describe_restore_contract(plan: Dictionary) -> String:
	if not bool(plan.get("valid", false)):
		return "Restore cannot apply until the target node resolves."
	return "Apply saved object state onto an already-resolved target node. SaveFlowNodeSource does not load scenes, create the target, or orchestrate restore order; the owning object must already exist."


func _describe_ownership_summary(plan: Dictionary) -> String:
	var conflict_count := PackedStringArray(plan.get("ownership_conflicts", PackedStringArray())).size()
	if conflict_count > 0:
		return "One object owner, with %d ownership conflict%s to fix." % [conflict_count, "" if conflict_count == 1 else "s"]
	return "One authored or prefab-owned object."


func _describe_children_summary(plan: Dictionary) -> String:
	var participant_count := Array(plan.get("resolved_participants", [])).size()
	var missing_count := PackedStringArray(plan.get("missing_paths", PackedStringArray())).size()
	if participant_count == 0 and missing_count == 0:
		return "No included child participants."
	if missing_count == 0:
		return "%d included child participant%s." % [participant_count, "" if participant_count == 1 else "s"]
	return "%d included, %d missing." % [participant_count, missing_count]


func _describe_design_hint(plan: Dictionary) -> String:
	var conflicts: PackedStringArray = PackedStringArray(plan.get("ownership_conflicts", PackedStringArray()))
	if not conflicts.is_empty():
		return "One included child crosses another save-owner boundary. Compose explicit child sources if needed, but do not directly own a runtime set or a subtree that already has its own NodeSource."
	return "Use NodeSource for one authored or prefab-owned object. Move managers, tables, caches, or changing runtime sets into DataSource or EntityCollectionSource."


func _format_candidate_label(candidate: Dictionary) -> String:
	var name: String = String(candidate.get("name", ""))
	return name


func _resolve_candidate_icon(candidate: Dictionary) -> Texture2D:
	var icon_name: String = String(candidate.get("icon_name", "Node"))
	if has_theme_icon(icon_name, "EditorIcons"):
		return get_theme_icon(icon_name, "EditorIcons")
	return get_theme_icon("Node", "EditorIcons")


func _on_preview_toggled() -> void:
	_preview_expanded = not _preview_expanded
	_persist_foldout_state_to_source()
	_refresh()


func _on_details_toggled() -> void:
	_details_expanded = not _details_expanded
	_persist_foldout_state_to_source()
	_refresh()


func _on_built_ins_toggled() -> void:
	_built_ins_expanded = not _built_ins_expanded
	_persist_foldout_state_to_source()
	_refresh()


func _on_participants_toggled() -> void:
	_participants_expanded = not _participants_expanded
	_persist_foldout_state_to_source()
	_refresh()


func _on_paths_toggled() -> void:
	_paths_expanded = not _paths_expanded
	_persist_foldout_state_to_source()
	_refresh()


func _on_diagnostics_toggled() -> void:
	_diagnostics_expanded = not _diagnostics_expanded
	_persist_foldout_state_to_source()
	_refresh()


func _on_built_in_advanced_toggled() -> void:
	_built_in_advanced_expanded = not _built_in_advanced_expanded
	_persist_foldout_state_to_source()
	_refresh()


func _on_include_target_toggled(pressed: bool) -> void:
	if _node_source == null or not is_instance_valid(_node_source):
		return
	_node_source.include_target_built_ins = pressed
	_mark_source_dirty()
	_refresh()


func _on_target_built_in_toggled(serializer_id: String, pressed: bool) -> void:
	if _node_source == null or not is_instance_valid(_node_source):
		return
	var next_ids: PackedStringArray = _node_source.included_target_builtin_ids.duplicate()
	if pressed:
		if not next_ids.has(serializer_id):
			next_ids.append(serializer_id)
	else:
		var index := next_ids.find(serializer_id)
		if index >= 0:
			next_ids.remove_at(index)
	_node_source.included_target_builtin_ids = next_ids
	_mark_source_dirty()
	_refresh()


func _on_use_recommended_fields_pressed() -> void:
	if _node_source == null or not is_instance_valid(_node_source):
		return
	if _node_source.has_method("use_recommended_target_builtin_fields"):
		_node_source.use_recommended_target_builtin_fields()
	_mark_source_dirty()
	_refresh()


func _on_save_all_fields_pressed() -> void:
	if _node_source == null or not is_instance_valid(_node_source):
		return
	if _node_source.has_method("clear_target_builtin_field_overrides"):
		_node_source.clear_target_builtin_field_overrides()
	_mark_source_dirty()
	_refresh()


func _on_target_built_in_field_toggled(serializer_id: String, field_id: String, pressed: bool) -> void:
	if _node_source == null or not is_instance_valid(_node_source):
		return
	var options: Array = _read_target_built_in_options()
	var fields: PackedStringArray = PackedStringArray()
	for option_variant in options:
		if not (option_variant is Dictionary):
			continue
		var option: Dictionary = option_variant
		if String(option.get("id", "")) != serializer_id:
			continue
		fields = PackedStringArray(option.get("selected_fields", PackedStringArray()))
		break
	if pressed:
		if not fields.has(field_id):
			fields.append(field_id)
	else:
		var index := fields.find(field_id)
		if index >= 0:
			fields.remove_at(index)
	if _node_source.has_method("set_target_builtin_field_selection"):
		_node_source.set_target_builtin_field_selection(serializer_id, fields)
	_mark_source_dirty()
	_refresh()


func _on_participant_toggled(path_text: String, pressed: bool) -> void:
	if _node_source == null or not is_instance_valid(_node_source):
		return
	var next_paths: PackedStringArray = _node_source.included_paths.duplicate()
	if pressed:
		if not next_paths.has(path_text):
			next_paths.append(path_text)
	else:
		var index := next_paths.find(path_text)
		if index >= 0:
			next_paths.remove_at(index)
	_node_source.included_paths = next_paths
	_mark_source_dirty()
	_refresh()


func _on_participant_excluded_toggled(path_text: String, pressed: bool) -> void:
	if _node_source == null or not is_instance_valid(_node_source):
		return
	var next_paths: PackedStringArray = _node_source.excluded_paths.duplicate()
	if pressed:
		if not next_paths.has(path_text):
			next_paths.append(path_text)
	else:
		var index := next_paths.find(path_text)
		if index >= 0:
			next_paths.remove_at(index)
	if pressed:
		var included_paths := _node_source.included_paths.duplicate()
		var included_index := included_paths.find(path_text)
		if included_index >= 0:
			included_paths.remove_at(included_index)
		_node_source.included_paths = included_paths
	_node_source.excluded_paths = next_paths
	_mark_source_dirty()
	_refresh()


func _on_participant_discovery_mode_selected(index: int) -> void:
	if _node_source == null or not is_instance_valid(_node_source):
		return
	_node_source.participant_discovery_mode = _discovery_mode_option.get_item_id(index)
	_mark_source_dirty()
	_refresh()


func _mark_source_dirty() -> void:
	if _node_source == null or not is_instance_valid(_node_source):
		return
	_node_source.notify_property_list_changed()


func _restore_foldout_state_from_source() -> void:
	if _node_source == null or not is_instance_valid(_node_source):
		return
	_preview_expanded = bool(_node_source.get_meta(META_PREVIEW_EXPANDED, _preview_expanded))
	_details_expanded = bool(_node_source.get_meta(META_DETAILS_EXPANDED, _details_expanded))
	_built_in_advanced_expanded = bool(_node_source.get_meta(META_ADVANCED_EXPANDED, _built_in_advanced_expanded))
	_built_ins_expanded = bool(_node_source.get_meta(META_BUILT_INS_EXPANDED, _built_ins_expanded))
	_participants_expanded = bool(_node_source.get_meta(META_PARTICIPANTS_EXPANDED, _participants_expanded))
	_paths_expanded = bool(_node_source.get_meta(META_PATHS_EXPANDED, _paths_expanded))
	_diagnostics_expanded = bool(_node_source.get_meta(META_DIAGNOSTICS_EXPANDED, _diagnostics_expanded))


func _persist_foldout_state_to_source() -> void:
	if _node_source == null or not is_instance_valid(_node_source):
		return
	_node_source.set_meta(META_PREVIEW_EXPANDED, _preview_expanded)
	_node_source.set_meta(META_DETAILS_EXPANDED, _details_expanded)
	_node_source.set_meta(META_ADVANCED_EXPANDED, _built_in_advanced_expanded)
	_node_source.set_meta(META_BUILT_INS_EXPANDED, _built_ins_expanded)
	_node_source.set_meta(META_PARTICIPANTS_EXPANDED, _participants_expanded)
	_node_source.set_meta(META_PATHS_EXPANDED, _paths_expanded)
	_node_source.set_meta(META_DIAGNOSTICS_EXPANDED, _diagnostics_expanded)


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
