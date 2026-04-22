@tool
extends VBoxContainer

const LABEL_WIDTH := 112
const PADDING := 10
const META_PREVIEW_EXPANDED := "_saveflow_entity_collection_preview_expanded"
const META_OPTIONS_EXPANDED := "_saveflow_entity_collection_options_expanded"
const META_MEMBERS_EXPANDED := "_saveflow_entity_collection_members_expanded"
const META_CONTRACT_EXPANDED := "_saveflow_entity_collection_contract_expanded"
const META_DETAILS_EXPANDED := "_saveflow_entity_collection_details_expanded"

var _entity_collection_source: SaveFlowEntityCollectionSource
var _last_signature: String = ""
var _preview_expanded := true
var _options_expanded := false
var _members_expanded := false
var _contract_expanded := false
var _details_expanded := false

var _preview_toggle: Button
var _content_panel: PanelContainer
var _status_chip: PanelContainer
var _status_label: Label
var _target_value: Label
var _factory_value: Label
var _restore_policy_value: Label
var _entity_count_value: Label
var _options_toggle: Button
var _options_box: VBoxContainer
var _auto_register_checkbox: CheckBox
var _direct_children_checkbox: CheckBox
var _members_toggle: Button
var _members_box: VBoxContainer
var _missing_title: Label
var _missing_value: RichTextLabel
var _entities_title: Label
var _entities_value: RichTextLabel
var _details_toggle: Button
var _details_box: VBoxContainer
var _contract_toggle: Button
var _contract_box: VBoxContainer
var _source_key_value: Label
var _ownership_value: Label
var _restore_contract_value: Label
var _failure_policy_value: Label
var _container_strategy_value: Label
var _factory_types_value: Label
var _factory_spawn_value: Label
var _target_path_value: Label
var _factory_path_value: Label
func _ready() -> void:
	_build_ui()
	set_process(true)
	_refresh()


func set_entity_collection_source(entity_collection_source: SaveFlowEntityCollectionSource) -> void:
	_entity_collection_source = entity_collection_source
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

	_target_value = _add_row(content, "Entity Container")
	_factory_value = _add_row(content, "Entity Factory")
	_restore_policy_value = _add_row(content, "Restore")
	_entity_count_value = _add_row(content, "Entities")

	_options_toggle = Button.new()
	_options_toggle.flat = true
	_options_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_options_toggle.pressed.connect(_on_options_toggled)
	content.add_child(_options_toggle)

	_options_box = VBoxContainer.new()
	_options_box.add_theme_constant_override("separation", 6)
	content.add_child(_options_box)

	_auto_register_checkbox = CheckBox.new()
	_auto_register_checkbox.text = "Auto-register this entity factory"
	_auto_register_checkbox.toggled.connect(_on_auto_register_toggled)
	_options_box.add_child(_auto_register_checkbox)

	_direct_children_checkbox = CheckBox.new()
	_direct_children_checkbox.text = "Scan direct children only"
	_direct_children_checkbox.toggled.connect(_on_direct_children_toggled)
	_options_box.add_child(_direct_children_checkbox)

	_members_toggle = Button.new()
	_members_toggle.flat = true
	_members_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_members_toggle.pressed.connect(_on_members_toggled)
	content.add_child(_members_toggle)

	_members_box = VBoxContainer.new()
	_members_box.add_theme_constant_override("separation", 6)
	content.add_child(_members_box)

	_missing_title = Label.new()
	_missing_title.text = "Missing Identity"
	_members_box.add_child(_missing_title)

	_missing_value = RichTextLabel.new()
	_missing_value.fit_content = true
	_missing_value.scroll_active = false
	_missing_value.selection_enabled = true
	_members_box.add_child(_missing_value)

	_entities_title = Label.new()
	_entities_title.text = "Entity Members"
	_members_box.add_child(_entities_title)

	_entities_value = RichTextLabel.new()
	_entities_value.fit_content = true
	_entities_value.scroll_active = false
	_entities_value.selection_enabled = true
	_members_box.add_child(_entities_value)

	_contract_toggle = Button.new()
	_contract_toggle.flat = true
	_contract_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_contract_toggle.pressed.connect(_on_contract_toggled)
	content.add_child(_contract_toggle)

	_contract_box = VBoxContainer.new()
	_contract_box.add_theme_constant_override("separation", 6)
	content.add_child(_contract_box)

	_restore_contract_value = _add_row(_contract_box, "Restore Contract")
	_ownership_value = _add_row(_contract_box, "Ownership")

	_details_toggle = Button.new()
	_details_toggle.flat = true
	_details_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_details_toggle.pressed.connect(_on_details_toggled)
	content.add_child(_details_toggle)

	_details_box = VBoxContainer.new()
	_details_box.add_theme_constant_override("separation", 6)
	content.add_child(_details_box)

	_source_key_value = _add_row(_details_box, "Save Key")
	_failure_policy_value = _add_row(_details_box, "Failure")
	_container_strategy_value = _add_row(_details_box, "Container Mode")
	_factory_types_value = _add_row(_details_box, "Factory Types")
	_factory_spawn_value = _add_row(_details_box, "Spawn Path")
	_target_path_value = _add_row(_details_box, "Entity Container Path")
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
	_restore_policy_value.text = String(plan.get("restore_policy_name", "Create Missing"))
	_entity_count_value.text = _describe_entity_count(plan)

	_options_toggle.text = _foldout_text("Options", _options_expanded)
	_options_box.visible = _options_expanded
	_auto_register_checkbox.set_block_signals(true)
	_auto_register_checkbox.button_pressed = bool(plan.get("auto_register_factory", false))
	_auto_register_checkbox.set_block_signals(false)

	_direct_children_checkbox.set_block_signals(true)
	_direct_children_checkbox.button_pressed = bool(plan.get("include_direct_children_only", false))
	_direct_children_checkbox.set_block_signals(false)

	_members_toggle.text = _foldout_text("Members", _members_expanded)
	_members_box.visible = _members_expanded
	_missing_value.text = _format_list(missing_identities)
	_missing_value.modulate = _warning_color()
	_entities_value.text = _format_entity_candidates(entity_candidates)
	_missing_title.visible = not missing_identities.is_empty()
	_missing_value.visible = not missing_identities.is_empty()
	_entities_title.visible = not entity_candidates.is_empty()
	_entities_value.visible = not entity_candidates.is_empty()

	_contract_toggle.text = _foldout_text("Contract", _contract_expanded)
	_contract_box.visible = _contract_expanded
	_restore_contract_value.text = _describe_restore_contract(plan)
	_ownership_value.text = _describe_ownership(plan)

	_details_toggle.text = _foldout_text("Diagnostics", _details_expanded)
	_details_box.visible = _details_expanded
	_source_key_value.text = String(plan.get("source_key", ""))
	var guardrails_text := _format_guardrails(plan)
	_failure_policy_value.text = String(plan.get("failure_policy_name", "Fail On Missing Or Invalid"))
	if not guardrails_text.is_empty():
		_failure_policy_value.text = "%s | %s" % [_failure_policy_value.text, guardrails_text]
	_container_strategy_value.text = String(plan.get("target_resolution", "<none>"))
	_factory_types_value.text = _format_list(plan.get("factory_supported_entity_types", PackedStringArray()))
	_factory_spawn_value.text = String(plan.get("factory_spawn_summary", ""))
	_target_path_value.text = String(plan.get("entity_container_path", plan.get("target_path", "")))
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


func _describe_entity_count(plan: Dictionary) -> String:
	var entity_count := int(plan.get("entity_count", 0))
	var missing_count := PackedStringArray(plan.get("missing_identity_nodes", PackedStringArray())).size()
	if missing_count == 0:
		return str(entity_count)
	return "%d (%d missing identity)" % [entity_count, missing_count]


func _describe_restore_contract(plan: Dictionary) -> String:
	if not bool(plan.get("valid", false)):
		return "Restore cannot proceed until the container and entity factory resolve."
	return "Restore runs against an existing runtime container. SaveFlow does not load the owning scene for this collection or orchestrate scene transitions; the correct scene or scope must already be active before load."


func _describe_ownership(plan: Dictionary) -> String:
	var container_name := _best_name(String(plan.get("entity_container_name", "")), String(plan.get("entity_container_path", "")))
	if container_name == "<none>":
		return "This collection should own one runtime entity container."
	return "This source owns the runtime set inside `%s`. Do not also save that same set through a parent object source or broad scene traversal." % container_name


func _format_guardrails(plan: Dictionary) -> String:
	var lines: PackedStringArray = []
	var conflicts: PackedStringArray = PackedStringArray(plan.get("double_collection_conflicts", PackedStringArray()))
	if not conflicts.is_empty():
		lines.append("Possible overlap with parent object save logic: %s" % ", ".join(conflicts))
	return "\n".join(lines)


func _on_preview_toggled() -> void:
	_preview_expanded = not _preview_expanded
	_persist_foldout_state_to_source()
	_refresh()


func _on_options_toggled() -> void:
	_options_expanded = not _options_expanded
	_persist_foldout_state_to_source()
	_refresh()


func _on_members_toggled() -> void:
	_members_expanded = not _members_expanded
	_persist_foldout_state_to_source()
	_refresh()


func _on_contract_toggled() -> void:
	_contract_expanded = not _contract_expanded
	_persist_foldout_state_to_source()
	_refresh()


func _on_details_toggled() -> void:
	_details_expanded = not _details_expanded
	_persist_foldout_state_to_source()
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


func _restore_foldout_state_from_source() -> void:
	if _entity_collection_source == null or not is_instance_valid(_entity_collection_source):
		return
	_preview_expanded = bool(_entity_collection_source.get_meta(META_PREVIEW_EXPANDED, _preview_expanded))
	_options_expanded = bool(_entity_collection_source.get_meta(META_OPTIONS_EXPANDED, _options_expanded))
	_members_expanded = bool(_entity_collection_source.get_meta(META_MEMBERS_EXPANDED, _members_expanded))
	_contract_expanded = bool(_entity_collection_source.get_meta(META_CONTRACT_EXPANDED, _contract_expanded))
	_details_expanded = bool(_entity_collection_source.get_meta(META_DETAILS_EXPANDED, _details_expanded))


func _persist_foldout_state_to_source() -> void:
	if _entity_collection_source == null or not is_instance_valid(_entity_collection_source):
		return
	_entity_collection_source.set_meta(META_PREVIEW_EXPANDED, _preview_expanded)
	_entity_collection_source.set_meta(META_OPTIONS_EXPANDED, _options_expanded)
	_entity_collection_source.set_meta(META_MEMBERS_EXPANDED, _members_expanded)
	_entity_collection_source.set_meta(META_CONTRACT_EXPANDED, _contract_expanded)
	_entity_collection_source.set_meta(META_DETAILS_EXPANDED, _details_expanded)


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
