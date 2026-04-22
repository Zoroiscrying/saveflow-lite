extends Control

const NODE_SOURCE_CASE_SCENE := "res://demo/saveflow_lite/recommended_template/scenes/cases/recommended_node_source_case.tscn"
const DATA_SOURCE_CASE_SCENE := "res://demo/saveflow_lite/recommended_template/scenes/cases/recommended_data_source_case.tscn"
const ENTITY_COLLECTION_CASE_SCENE := "res://demo/saveflow_lite/recommended_template/scenes/cases/recommended_entity_collection_case.tscn"
const CSHARP_CASE_SCENE := "res://demo/saveflow_lite/recommended_template/scenes/cases/recommended_csharp_case.tscn"
const SLOT_SUMMARY_CASE_SCENE := "res://demo/saveflow_lite/recommended_template/scenes/cases/recommended_slot_summary_case.tscn"
const AUTOSAVE_CASE_SCENE := "res://demo/saveflow_lite/recommended_template/scenes/cases/recommended_autosave_case.tscn"
const IN_GAME_SAVE_PANEL_CASE_SCENE := "res://demo/saveflow_lite/recommended_template/scenes/cases/recommended_in_game_save_panel_case.tscn"
const OVERVIEW_SCENE := "res://demo/saveflow_lite/recommended_template/scenes/recommended_template_overview.tscn"

@onready var _status_output: TextEdit = $MarginContainer/PanelContainer/Content/StatusOutput


func _ready() -> void:
	_bind_buttons()
	_status_output.text = "Choose one case by ownership model first. Open the combined overview only after the single-path scenes feel clear."


func _bind_buttons() -> void:
	$MarginContainer/PanelContainer/Content/NodeSourceButton.pressed.connect(func() -> void: _open_case(NODE_SOURCE_CASE_SCENE))
	$MarginContainer/PanelContainer/Content/DataSourceButton.pressed.connect(func() -> void: _open_case(DATA_SOURCE_CASE_SCENE))
	$MarginContainer/PanelContainer/Content/EntityCollectionButton.pressed.connect(func() -> void: _open_case(ENTITY_COLLECTION_CASE_SCENE))
	$MarginContainer/PanelContainer/Content/CSharpButton.pressed.connect(func() -> void: _open_case(CSHARP_CASE_SCENE))
	$MarginContainer/PanelContainer/Content/SlotSummaryButton.pressed.connect(func() -> void: _open_case(SLOT_SUMMARY_CASE_SCENE))
	$MarginContainer/PanelContainer/Content/AutosaveButton.pressed.connect(func() -> void: _open_case(AUTOSAVE_CASE_SCENE))
	$MarginContainer/PanelContainer/Content/InGamePanelButton.pressed.connect(func() -> void: _open_case(IN_GAME_SAVE_PANEL_CASE_SCENE))
	$MarginContainer/PanelContainer/Content/OverviewButton.pressed.connect(func() -> void: _open_case(OVERVIEW_SCENE))


func _open_case(scene_path: String) -> void:
	_status_output.text = "Opening %s" % scene_path.get_file()
	get_tree().change_scene_to_file(scene_path)
