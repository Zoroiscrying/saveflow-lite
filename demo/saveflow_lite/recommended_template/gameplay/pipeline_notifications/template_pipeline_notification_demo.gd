extends Control

const SLOT_ID := "pipeline_notification_demo"
const SOURCE_LABELS := {
	"profile_data": "Profile",
	"inventory_data": "Inventory",
	"quest_data": "Quest",
}

@onready var _save_graph: SaveFlowScope = $SaveGraph
@onready var _profile_source: SaveFlowTypedDataSource = $SaveGraph/ProfileSource
@onready var _inventory_source: SaveFlowTypedDataSource = $SaveGraph/InventorySource
@onready var _quest_source: SaveFlowTypedDataSource = $SaveGraph/QuestSource
@onready var _status_label: Label = $Screen/MainLayout/LeftColumn/StatusPanel/StatusLabel
@onready var _profile_label: Label = $Screen/MainLayout/LeftColumn/DataCards/ProfileCard/ProfileLabel
@onready var _inventory_label: Label = $Screen/MainLayout/LeftColumn/DataCards/InventoryCard/InventoryLabel
@onready var _quest_label: Label = $Screen/MainLayout/LeftColumn/DataCards/QuestCard/QuestLabel
@onready var _message_stack: VBoxContainer = $Screen/MainLayout/RightColumn/MessagePanel/MessageMargin/MessageStack

var _mutation_tick := 0


func _ready() -> void:
	_refresh_data_labels()
	_push_message("Pipeline notification demo ready.", Color(0.55, 0.72, 0.92))


func save_demo() -> SaveResult:
	_clear_messages()
	_status_label.text = "Save requested. Watch each Source signal report its own data."
	var result: SaveResult = SaveFlow.save_scope(SLOT_ID, _save_graph, _build_metadata())
	if not result.ok:
		_push_message("Save failed: %s" % result.error_message, Color(1.0, 0.42, 0.38))
		_status_label.text = "Save failed: %s" % result.error_key
	return result


func load_demo() -> SaveResult:
	_clear_messages()
	var result: SaveResult = SaveFlow.load_scope(SLOT_ID, _save_graph, true)
	if result.ok:
		_push_message("Data Loaded!", Color(0.48, 0.9, 0.58))
		_status_label.text = "Loaded slot `%s`." % SLOT_ID
		_refresh_data_labels()
	else:
		_push_message("Load failed: %s" % result.error_message, Color(1.0, 0.42, 0.38))
		_status_label.text = "Load failed: %s" % result.error_key
	return result


func mutate_demo_data() -> void:
	_mutation_tick += 1
	(_profile_source.data as TemplatePipelineDemoData).mutate("Profile", _mutation_tick)
	(_inventory_source.data as TemplatePipelineDemoData).mutate("Inventory", _mutation_tick)
	(_quest_source.data as TemplatePipelineDemoData).mutate("Quest", _mutation_tick)
	_status_label.text = "Mutated all typed data resources. Save again to see source-level pipeline signals."
	_refresh_data_labels()
	_push_message("Demo data mutated.", Color(0.92, 0.74, 0.36))


func clear_notifications() -> void:
	_clear_messages()
	_push_message("Notification sidebar cleared.", Color(0.55, 0.72, 0.92))


func _on_source_saved(event: SaveFlowPipelineEvent) -> void:
	var label := String(SOURCE_LABELS.get(event.key, event.key.to_pascal_case()))
	_push_message("%s Data Saved" % label, Color(0.64, 0.86, 1.0))


func _on_source_loaded(event: SaveFlowPipelineEvent) -> void:
	var label := String(SOURCE_LABELS.get(event.key, event.key.to_pascal_case()))
	_push_message("%s Data Loaded" % label, Color(0.64, 1.0, 0.72))


func _on_graph_saved(_event: SaveFlowPipelineEvent) -> void:
	_push_message("Data Saved!", Color(0.46, 1.0, 0.62))
	_status_label.text = "Saved slot `%s`. Source signals fired before the final slot-write signal." % SLOT_ID


func _on_pipeline_error(event: SaveFlowPipelineEvent) -> void:
	if event.result == null:
		return
	_push_message("Pipeline error: %s" % event.result.error_message, Color(1.0, 0.42, 0.38))


func _build_metadata() -> SaveFlowSlotMetadata:
	var meta := SaveFlowSlotMetadata.new()
	meta.display_name = "Pipeline Notification Demo"
	meta.save_type = "manual"
	meta.chapter_name = "Lite Examples"
	meta.location_name = "Pipeline Signals"
	meta.scene_path = scene_file_path
	meta.custom_metadata["slot_index"] = 20
	meta.custom_metadata["storage_key"] = SLOT_ID
	meta.custom_metadata["slot_role"] = "pipeline_signal_demo"
	return meta


func _refresh_data_labels() -> void:
	_profile_label.text = _format_data_card("Profile", _profile_source.data)
	_inventory_label.text = _format_data_card("Inventory", _inventory_source.data)
	_quest_label.text = _format_data_card("Quest", _quest_source.data)


func _format_data_card(title: String, data: Resource) -> String:
	var typed_data := data as TemplatePipelineDemoData
	if typed_data == null:
		return "%s\n<missing typed data>" % title
	return "%s\nsummary=%s\ncounter=%d | flag=%s\ntags=%s" % [
		title,
		typed_data.summary,
		typed_data.counter,
		"on" if typed_data.enabled_flag else "off",
		", ".join(Array(typed_data.tags)),
	]


func _push_message(text: String, accent: Color) -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.12, 0.94)
	style.border_color = accent
	style.border_width_left = 4
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0, 1.0))
	panel.add_child(label)
	_message_stack.add_child(panel)

	while _message_stack.get_child_count() > 8:
		var stale_message := _message_stack.get_child(0)
		_message_stack.remove_child(stale_message)
		stale_message.queue_free()


func _clear_messages() -> void:
	for child in _message_stack.get_children():
		_message_stack.remove_child(child)
		child.queue_free()
