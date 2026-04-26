@tool
extends HBoxContainer

const SceneValidatorScript := preload("res://addons/saveflow_lite/editor/saveflow_scene_validator.gd")
const STATE_OK := "ok"
const STATE_WARNING := "warning"
const STATE_ERROR := "error"
const REFRESH_INTERVAL_SECONDS := 0.75
const POPUP_SIZE := Vector2i(520, 360)
const POPUP_MARGIN := 8

var _button: Button
var _popup: PopupPanel
var _issue_list: VBoxContainer
var _summary_label: Label
var _breakdown_label: Label
var _next_action_label: Label
var _refresh_timer := 0.0
var _last_report: Dictionary = {}


func _ready() -> void:
	_build_ui()
	set_process(true)
	call_deferred("refresh_now")


func _process(delta: float) -> void:
	_refresh_timer += delta
	if _refresh_timer < REFRESH_INTERVAL_SECONDS:
		return
	_refresh_timer = 0.0
	refresh_now()


func refresh_now(scene_root: Node = null) -> void:
	_last_report = SceneValidatorScript.inspect_scene(scene_root)
	_refresh_button()
	if _popup != null and _popup.visible:
		_rebuild_popup_content()


func get_last_report() -> Dictionary:
	return _last_report.duplicate(true)


func _build_ui() -> void:
	if _button != null:
		return

	_button = Button.new()
	_button.text = "SaveFlow"
	_button.tooltip_text = "SaveFlow scene validator"
	_button.custom_minimum_size.x = 104
	_button.pressed.connect(_on_button_pressed)
	add_child(_button)

	_popup = PopupPanel.new()
	_popup.title = "SaveFlow Scene Validator"
	_popup.wrap_controls = false
	_popup.min_size = POPUP_SIZE
	_popup.max_size = POPUP_SIZE
	_popup.size = POPUP_SIZE
	add_child(_popup)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_popup.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	_summary_label = Label.new()
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_summary_label)

	_breakdown_label = Label.new()
	_breakdown_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_breakdown_label)

	_next_action_label = Label.new()
	_next_action_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_next_action_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(POPUP_SIZE.x - 28, POPUP_SIZE.y - 130)
	root.add_child(scroll)

	_issue_list = VBoxContainer.new()
	_issue_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_issue_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_issue_list)


func _refresh_button() -> void:
	if _button == null:
		return
	var has_scene := bool(_last_report.get("has_scene", false))
	var component_count := int(_last_report.get("component_count", 0))
	var error_count := int(_last_report.get("error_count", 0))
	var warning_count := int(_last_report.get("warning_count", 0))

	if not has_scene:
		_button.text = "SaveFlow --"
		_button.tooltip_text = "Open a scene to run SaveFlow validation."
		_button.add_theme_color_override("font_color", _theme_warning_color())
	elif component_count == 0:
		_button.text = "SaveFlow"
		_button.tooltip_text = "No SaveFlow components in the current scene."
		_button.add_theme_color_override("font_color", get_theme_color("font_color", "Button"))
	elif error_count > 0:
		_button.text = "SaveFlow %dE %dW" % [error_count, warning_count]
		_button.tooltip_text = String(_last_report.get("summary", "SaveFlow scene has errors."))
		_button.add_theme_color_override("font_color", _theme_error_color())
	elif warning_count > 0:
		_button.text = "SaveFlow %dW" % warning_count
		_button.tooltip_text = String(_last_report.get("summary", "SaveFlow scene has warnings."))
		_button.add_theme_color_override("font_color", _theme_warning_color())
	else:
		_button.text = "SaveFlow OK"
		_button.tooltip_text = String(_last_report.get("summary", "SaveFlow scene looks valid."))
		_button.add_theme_color_override("font_color", _theme_ok_color())


func _on_button_pressed() -> void:
	refresh_now()
	_rebuild_popup_content()
	var popup_rect := Rect2i(_resolve_popup_position(), POPUP_SIZE)
	_apply_popup_rect(popup_rect)
	_popup.popup(popup_rect)
	call_deferred("_apply_popup_rect", popup_rect)


func _apply_popup_rect(popup_rect: Rect2i) -> void:
	if _popup == null:
		return
	_popup.wrap_controls = false
	_popup.min_size = popup_rect.size
	_popup.max_size = popup_rect.size
	_popup.position = popup_rect.position
	_popup.size = popup_rect.size


func _resolve_popup_position() -> Vector2i:
	if _button == null:
		return Vector2i.ZERO
	var anchor := _button.get_screen_position()
	var anchor_position := Vector2i(roundi(anchor.x), roundi(anchor.y + _button.size.y + POPUP_MARGIN))
	var screen_rect := _resolve_popup_screen_rect(anchor_position)
	var min_x := screen_rect.position.x + POPUP_MARGIN
	var max_x: int = maxi(min_x, screen_rect.position.x + screen_rect.size.x - POPUP_SIZE.x - POPUP_MARGIN)
	var x := clampi(anchor_position.x, min_x, max_x)

	var min_y := screen_rect.position.y + POPUP_MARGIN
	var max_y: int = maxi(min_y, screen_rect.position.y + screen_rect.size.y - POPUP_SIZE.y - POPUP_MARGIN)
	var y := anchor_position.y
	if y > max_y:
		var above_y := roundi(anchor.y - POPUP_SIZE.y - POPUP_MARGIN)
		y = above_y if above_y >= min_y else max_y
	y = clampi(y, min_y, max_y)
	return Vector2i(x, y)


func _resolve_popup_screen_rect(anchor_position: Vector2i) -> Rect2i:
	var screen_index := DisplayServer.get_screen_from_rect(Rect2i(anchor_position, Vector2i.ONE))
	if screen_index >= 0:
		return DisplayServer.screen_get_usable_rect(screen_index)
	var window := get_window()
	if window != null:
		return Rect2i(window.position, window.size)
	return Rect2i(Vector2i.ZERO, DisplayServer.screen_get_size())


func _rebuild_popup_content() -> void:
	if _issue_list == null or _summary_label == null:
		return
	_clear_children(_issue_list)

	_summary_label.text = String(_last_report.get("summary", "Open a scene to run SaveFlow scene validation."))
	_summary_label.modulate = _summary_color()
	if _breakdown_label != null:
		_breakdown_label.text = _build_breakdown_text(_last_report)
		_breakdown_label.modulate = get_theme_color("font_placeholder_color", "Editor")
	if _next_action_label != null:
		_next_action_label.text = "Next: %s" % String(_last_report.get("next_action", "Open a scene to run SaveFlow scene validation."))
		_next_action_label.modulate = _summary_color()

	var issues: Array = Array(_last_report.get("issues", []))
	if issues.is_empty():
		var empty_label := Label.new()
		empty_label.text = _empty_issue_text()
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.modulate = get_theme_color("font_placeholder_color", "Editor")
		_issue_list.add_child(empty_label)
		return

	for issue_variant in issues:
		var issue := Dictionary(issue_variant)
		_issue_list.add_child(_build_issue_row(issue))


func _build_issue_row(issue: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	margin.add_child(row)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	row.add_child(top)

	var state_label := Label.new()
	state_label.text = _state_prefix(String(issue.get("state", STATE_WARNING)))
	state_label.modulate = _state_color(String(issue.get("state", STATE_WARNING)))
	top.add_child(state_label)

	var title := Label.new()
	title.text = "%s  %s" % [
		String(issue.get("title", "Issue")),
		String(issue.get("node_path", "")),
	]
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(title)

	var select_button := Button.new()
	select_button.text = "Select"
	select_button.disabled = not is_instance_valid(issue.get("node", null))
	var issue_copy := issue.duplicate()
	select_button.pressed.connect(func() -> void: _select_issue_node(issue_copy))
	top.add_child(select_button)

	var message := Label.new()
	message.text = String(issue.get("message", ""))
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.modulate = get_theme_color("font_color", "Editor")
	row.add_child(message)

	var hint := String(issue.get("hint", "")).strip_edges()
	if not hint.is_empty():
		var hint_label := Label.new()
		hint_label.text = hint
		hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint_label.modulate = get_theme_color("font_placeholder_color", "Editor")
		row.add_child(hint_label)

	return panel


func _select_issue_node(issue: Dictionary) -> void:
	var node_variant: Variant = issue.get("node", null)
	if not is_instance_valid(node_variant):
		return
	var node := node_variant as Node
	if node == null:
		return
	var selection := EditorInterface.get_selection()
	if selection == null:
		return
	selection.clear()
	selection.add_node(node)
	_popup.hide()


func _empty_issue_text() -> String:
	if not bool(_last_report.get("has_scene", false)):
		return "Open a scene to run SaveFlow validation."
	if int(_last_report.get("component_count", 0)) == 0:
		return "This scene does not contain SaveFlow components. Nothing needs validation here yet."
	return "No SaveFlow scene issues found."


func _build_breakdown_text(report: Dictionary) -> String:
	if not bool(report.get("has_scene", false)):
		return "Component map: no scene loaded."
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
		return "Component map: no SaveFlow components."
	return "Component map: %s." % ", ".join(parts)


func _append_count_part(parts: PackedStringArray, count: int, label: String) -> void:
	if count <= 0:
		return
	parts.append("%d %s" % [count, label])


func _summary_color() -> Color:
	if int(_last_report.get("error_count", 0)) > 0:
		return _theme_error_color()
	if int(_last_report.get("warning_count", 0)) > 0:
		return _theme_warning_color()
	return _theme_ok_color()


func _state_prefix(state: String) -> String:
	if state == STATE_ERROR:
		return "Error"
	if state == STATE_WARNING:
		return "Warn"
	return "OK"


func _state_color(state: String) -> Color:
	if state == STATE_ERROR:
		return _theme_error_color()
	if state == STATE_WARNING:
		return _theme_warning_color()
	return _theme_ok_color()


func _theme_error_color() -> Color:
	return Color(0.96, 0.54, 0.54)


func _theme_warning_color() -> Color:
	return Color(0.95, 0.82, 0.46)


func _theme_ok_color() -> Color:
	return Color(0.60, 0.92, 0.70)


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()
