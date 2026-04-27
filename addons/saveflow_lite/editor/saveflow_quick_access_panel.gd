@tool
extends Window

const DEFAULT_POPUP_SIZE := Vector2i(600, 560)
const MIN_POPUP_SIZE := Vector2i(520, 480)
const POPUP_MARGIN := Vector2i(96, 96)
const WINDOW_BACKGROUND := Color("0f1420")
const SURFACE_BACKGROUND := Color("161e2d")
const SURFACE_BACKGROUND_SOFT := Color("1c2536")
const SURFACE_BORDER := Color("31415f")

const PROJECT_WORKFLOW_SCENE := "res://demo/saveflow_lite/recommended_template/scenes/project_workflow/recommended_project_workflow_main.tscn"
const PIPELINE_NOTIFICATION_SCENE := "res://demo/saveflow_lite/recommended_template/scenes/pipeline_notifications/pipeline_notification_demo.tscn"
const CSHARP_WORKFLOW_SCENE := "res://demo/saveflow_lite/recommended_template/scenes/csharp_workflow/csharp_workflow_demo.tscn"

const SaveFlowIcon := preload("res://addons/saveflow_lite/icons/saveflow_icon.svg")
const EntityFactoryIcon := preload("res://addons/saveflow_lite/icons/components/saveflow_entity_factory_icon.svg")
const PipelineSignalsIcon := preload("res://addons/saveflow_lite/icons/components/saveflow_pipeline_signals_icon.svg")
const ScopeIcon := preload("res://addons/saveflow_lite/icons/components/saveflow_scope_icon.svg")

signal open_scene_requested(scene_path: String)
signal focus_settings_requested
signal focus_save_manager_requested
signal open_docs_requested
signal dismissed(suppress_until_current_version: bool)

var _content_built := false
var _plugin_version := ""
var _dismiss_sent := false
var _version_label: Label
var _suppress_check: CheckBox


func _ready() -> void:
	title = "SaveFlow Quick Access"
	min_size = MIN_POPUP_SIZE
	size = DEFAULT_POPUP_SIZE
	visible = false
	transient = true
	unresizable = false
	close_requested.connect(_on_close_requested)
	_build_ui()


func set_plugin_version(plugin_version: String) -> void:
	_plugin_version = plugin_version.strip_edges()
	if _version_label != null:
		_version_label.text = _format_version_text()


func popup_quick_access() -> void:
	_build_ui()
	_dismiss_sent = false
	if _suppress_check != null:
		_suppress_check.button_pressed = true
	var target_size := _compute_popup_size()
	popup_centered_clamped(target_size, 0.85)
	size = target_size
	grab_focus()


func _build_ui() -> void:
	if _content_built:
		return
	_content_built = true

	var background := ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = WINDOW_BACKGROUND
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 10
	root.offset_top = 10
	root.offset_right = -10
	root.offset_bottom = -10
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	root.add_child(_build_header())

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)

	content.add_child(_build_intro_panel())
	content.add_child(_build_section(
		"Start Here",
		[
			{
				"icon": SaveFlowIcon,
				"title": "Open Recommended Template",
				"description": "Open the main project workflow: one hub scene, authored subscenes, scene data, node data, and runtime entity collection data in one playable flow.",
				"action": func() -> void: _emit_scene(PROJECT_WORKFLOW_SCENE),
			},
			{
				"icon": PipelineSignalsIcon,
				"title": "Open Pipeline Signals Demo",
				"description": "Open a small scene-authored pipeline demo: SaveFlowPipelineSignals nodes drive source-level and final Data Saved notifications without subclassing sources.",
				"action": func() -> void: _emit_scene(PIPELINE_NOTIFICATION_SCENE),
			},
			{
				"icon": SaveFlowIcon,
				"title": "Open C# Workflow Demo",
				"description": "Open the C# path: SaveFlowTypedStateSource, SaveFlowSlotWorkflow, SaveFlowSlotCard, and SaveFlowClient.SaveScope in one small scene.",
				"action": func() -> void: _emit_scene(CSHARP_WORKFLOW_SCENE),
			},
		]
	))

	content.add_child(_build_section(
		"Editor Panels",
		[
			{
				"icon": SaveFlowIcon,
				"title": "Open SaveFlow Settings",
				"description": "Jump to project-wide save format, setup health, and defaults.",
				"action": func() -> void:
					_emit_dismissed_preference()
					hide()
					focus_settings_requested.emit(),
			},
			{
				"icon": EntityFactoryIcon,
				"title": "Open DevSaveManager",
				"description": "Jump to runtime save testing, dev saves, and formal slot save inspection.",
				"action": func() -> void:
					_emit_dismissed_preference()
					hide()
					focus_save_manager_requested.emit(),
			},
			{
				"icon": ScopeIcon,
				"title": "Open Lite Docs",
				"description": "Open the plugin docs folder for screenshots, maps, and integration notes.",
				"action": func() -> void:
					_emit_dismissed_preference()
					hide()
					open_docs_requested.emit(),
			},
		]
	))

	root.add_child(_build_footer())


func _build_header() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _build_panel_style(SURFACE_BACKGROUND, 14))

	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 14)
	padding.add_theme_constant_override("margin_top", 14)
	padding.add_theme_constant_override("margin_right", 14)
	padding.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(padding)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	padding.add_child(row)

	var icon := TextureRect.new()
	icon.texture = SaveFlowIcon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(52, 52)
	row.add_child(icon)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 4)
	row.add_child(text_box)

	var title_label := Label.new()
	title_label.text = "SaveFlow Quick Access"
	title_label.add_theme_font_size_override("font_size", 18)
	text_box.add_child(title_label)

	var subtitle_label := Label.new()
	subtitle_label.text = "Start with the recommended project workflow. It keeps the save concepts inside one normal Godot scene flow instead of splitting them into many standalone cases."
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_box.add_child(subtitle_label)

	return panel


func _build_intro_panel() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _build_panel_style(SURFACE_BACKGROUND_SOFT, 12))

	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 12)
	padding.add_theme_constant_override("margin_top", 12)
	padding.add_theme_constant_override("margin_right", 12)
	padding.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(padding)

	var label := Label.new()
	label.text = "Rule of thumb: inspect the project workflow scene tree first. Most template state is saved by ordinary nodes and SaveFlow components, not by extra case managers."
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	padding.add_child(label)
	return panel


func _build_section(section_title: String, actions: Array) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _build_panel_style(SURFACE_BACKGROUND, 12))

	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 12)
	padding.add_theme_constant_override("margin_top", 12)
	padding.add_theme_constant_override("margin_right", 12)
	padding.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(padding)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	padding.add_child(content)

	var header := Label.new()
	header.text = section_title
	header.add_theme_font_size_override("font_size", 15)
	content.add_child(header)

	for action_variant in actions:
		var action: Dictionary = action_variant
		content.add_child(_build_action_row(
			action.get("icon", SaveFlowIcon),
			String(action.get("title", "")),
			String(action.get("description", "")),
			Callable(action.get("action", Callable()))
		))

	return panel


func _build_action_row(icon_texture: Texture2D, action_title: String, description: String, action: Callable) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _build_panel_style(SURFACE_BACKGROUND_SOFT, 10))

	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 10)
	padding.add_theme_constant_override("margin_top", 10)
	padding.add_theme_constant_override("margin_right", 10)
	padding.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(padding)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	padding.add_child(row)

	var icon := TextureRect.new()
	icon.texture = icon_texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(28, 28)
	row.add_child(icon)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 3)
	row.add_child(text_box)

	var title_label := Label.new()
	title_label.text = action_title
	text_box.add_child(title_label)

	var description_label := Label.new()
	description_label.text = description
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_box.add_child(description_label)

	var button := Button.new()
	button.text = "Open"
	button.pressed.connect(action)
	row.add_child(button)
	return panel


func _build_footer() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _build_panel_style(SURFACE_BACKGROUND, 12))

	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 12)
	padding.add_theme_constant_override("margin_top", 10)
	padding.add_theme_constant_override("margin_right", 12)
	padding.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(padding)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	padding.add_child(content)

	_suppress_check = CheckBox.new()
	_suppress_check.text = "Don't open Quick Access again until a newer SaveFlow Lite version is installed"
	_suppress_check.button_pressed = true
	_suppress_check.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_suppress_check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_suppress_check)

	var actions_row := HBoxContainer.new()
	actions_row.alignment = BoxContainer.ALIGNMENT_END
	content.add_child(actions_row)

	_version_label = Label.new()
	_version_label.text = _format_version_text()
	actions_row.add_child(_version_label)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(_on_close_requested)
	actions_row.add_child(close_button)

	return panel


func _emit_scene(scene_path: String) -> void:
	_emit_dismissed_preference()
	hide()
	open_scene_requested.emit(scene_path)


func _emit_dismissed_preference() -> void:
	if _dismiss_sent:
		return
	_dismiss_sent = true
	var suppress_until_current_version := true
	if _suppress_check != null:
		suppress_until_current_version = _suppress_check.button_pressed
	dismissed.emit(suppress_until_current_version)


func _on_close_requested() -> void:
	_emit_dismissed_preference()
	hide()


func _build_panel_style(background: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = SURFACE_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style


func _format_version_text() -> String:
	if _plugin_version.is_empty():
		return "Version: unknown"
	return "Version: v%s" % _plugin_version


func _compute_popup_size() -> Vector2i:
	var viewport := get_viewport()
	if viewport == null:
		return DEFAULT_POPUP_SIZE
	var visible_rect := viewport.get_visible_rect()
	var viewport_size := Vector2i(visible_rect.size)
	if viewport_size.x <= 0 or viewport_size.y <= 0:
		return DEFAULT_POPUP_SIZE

	var max_width := maxi(MIN_POPUP_SIZE.x, viewport_size.x - POPUP_MARGIN.x)
	var max_height := maxi(MIN_POPUP_SIZE.y, viewport_size.y - POPUP_MARGIN.y)
	return Vector2i(
		clampi(DEFAULT_POPUP_SIZE.x, MIN_POPUP_SIZE.x, max_width),
		clampi(DEFAULT_POPUP_SIZE.y, MIN_POPUP_SIZE.y, max_height)
	)
