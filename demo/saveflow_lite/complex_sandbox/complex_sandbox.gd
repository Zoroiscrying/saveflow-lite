extends Control

const SLOT_ID := "complex_slot"
const EnemyStateScript := preload("res://demo/saveflow_lite/complex_sandbox/complex_enemy_state.gd")

@onready var _player_state: Node2D = $StateRoot/PlayerState
@onready var _world_state: Node = $StateRoot/WorldState
@onready var _quest_state: Node = $StateRoot/QuestState
@onready var _settings_state: Node = $StateRoot/SettingsState
@onready var _party_root: Node = $StateRoot/PartyMembers
@onready var _enemy_root: Node = $StateRoot/SpawnedEnemies
@onready var _save_graph_root: SaveFlowScope = $StateRoot/SaveGraphRoot
@onready var _summary_label: Label = $MarginContainer/PanelContainer/Content/SummaryLabel
@onready var _limitation_label: Label = $MarginContainer/PanelContainer/Content/LimitationLabel
@onready var _status_output: TextEdit = $MarginContainer/PanelContainer/Content/StatusOutput

var saveflow


func _ready() -> void:
	saveflow = SaveFlow
	_configure_runtime()
	_bind_actions()
	_reset_all(false)
	_refresh_ui("Complex sandbox ready. Save the baseline, mutate supported state, then break dynamic nodes and load again.")


func _configure_runtime() -> void:
	saveflow.configure_with(
		"user://complex_sandbox/saves",
		"user://complex_sandbox/slots.index"
	)


func _bind_actions() -> void:
	$MarginContainer/PanelContainer/Content/Buttons/SaveButton.pressed.connect(_on_save_pressed)
	$MarginContainer/PanelContainer/Content/Buttons/LoadButton.pressed.connect(_on_load_pressed)
	$MarginContainer/PanelContainer/Content/Buttons/MutateSupportedButton.pressed.connect(_on_mutate_supported_pressed)
	$MarginContainer/PanelContainer/Content/Buttons/BreakDynamicButton.pressed.connect(_on_break_dynamic_pressed)
	$MarginContainer/PanelContainer/Content/Buttons/AnalyzeButton.pressed.connect(_on_analyze_pressed)
	$MarginContainer/PanelContainer/Content/Buttons/ResetButton.pressed.connect(_on_reset_pressed)


func _on_save_pressed() -> void:
	var result: SaveResult = saveflow.save_scope(
		SLOT_ID,
		_save_graph_root,
		{
			"display_name": "Complex Sandbox Slot",
			"scene_path": scene_file_path,
			"game_version": "complex_sandbox",
			"playtime_seconds": 726,
		}
	)
	_refresh_ui(_format_result("Save", result))


func _on_load_pressed() -> void:
	var result: SaveResult = saveflow.load_scope(SLOT_ID, _save_graph_root, true)
	var message := _format_result("Load", result)
	if result.ok and result.data is Dictionary:
		var missing_keys: PackedStringArray = PackedStringArray(result.data.get("missing_keys", PackedStringArray()))
		if not missing_keys.is_empty():
			message += "\nCurrent limitation exposed: missing source targets were reported, but SaveFlow did not reconstruct those runtime entities."
	_refresh_ui(message)


func _on_mutate_supported_pressed() -> void:
	_player_state.call("mutate_supported")
	_world_state.call("mutate_supported")
	_quest_state.call("mutate_supported")
	_settings_state.call("mutate_supported")
	for member in _party_root.get_children():
		member.call("mutate_supported")
	for enemy in _enemy_root.get_children():
		enemy.call("mutate_supported")
	_refresh_ui("Supported state mutated. Exported fields and transforms should come back on load.")


func _on_break_dynamic_pressed() -> void:
	var first_enemy = _enemy_root.get_child(0) if _enemy_root.get_child_count() > 0 else null
	if first_enemy != null:
		first_enemy.free()
	var extra_enemy := _create_enemy("wisp_extra", 48, 0, 904, Vector2(260, 200))
	_enemy_root.add_child(extra_enemy)
	_refresh_ui("Dynamic graph changed after save. One saved enemy is missing; one new enemy was added outside the saved slot.")


func _on_analyze_pressed() -> void:
	var analysis: Dictionary = run_complex_analysis()
	_refresh_ui(JSON.stringify(analysis, "\t"))


func _on_reset_pressed() -> void:
	_reset_all(true)


func _reset_all(refresh := true) -> void:
	_player_state.call("reset_state")
	_world_state.call("reset_state")
	_quest_state.call("reset_state")
	_settings_state.call("reset_state")
	_reset_party_members()
	_rebuild_enemy_roster()
	if refresh:
		_refresh_ui("Complex sandbox reset to its authored baseline. Slot file unchanged until you save or delete it.")


func _reset_party_members() -> void:
	var defaults := [
		{"node_name": "Aria", "member_id": "aria", "level": 6, "affinity": 12, "skill": "healing_song"},
		{"node_name": "Bram", "member_id": "bram", "level": 4, "affinity": 5, "skill": ""},
	]
	for index in range(defaults.size()):
		var member: Node = _party_root.get_child(index)
		var preset: Dictionary = defaults[index]
		member.call(
			"reset_state",
			String(preset["member_id"]),
			int(preset["level"]),
			int(preset["affinity"]),
			String(preset["skill"])
		)


func _rebuild_enemy_roster() -> void:
	for child in _enemy_root.get_children():
		child.free()
	_enemy_root.add_child(_create_enemy("wolf_alpha", 82, 1, 1201, Vector2(180, 180)))
	_enemy_root.add_child(_create_enemy("slime_beta", 46, 0, 882, Vector2(220, 210)))


func _create_enemy(enemy_id: String, hp: int, patrol_index: int, loot_seed: int, start_position: Vector2) -> Node2D:
	var enemy := Node2D.new()
	enemy.name = _to_pascal_node_name(enemy_id)
	enemy.set_script(EnemyStateScript)
	enemy.call("reset_state", enemy_id, hp, patrol_index, loot_seed, start_position)
	return enemy


func _to_pascal_node_name(value: String) -> String:
	var result := ""
	for part in value.split("_", false):
		result += part.capitalize().replace(" ", "")
	return result


func _refresh_ui(message: String) -> void:
	_summary_label.text = _build_summary_text()
	_limitation_label.text = _build_limitation_text()
	_status_output.text = message


func _build_summary_text() -> String:
	var party_lines: PackedStringArray = []
	for member in _party_root.get_children():
		party_lines.append(member.call("to_debug_string"))
	var enemy_lines: PackedStringArray = []
	for enemy in _enemy_root.get_children():
		enemy_lines.append(enemy.call("to_debug_string"))
	return "\n".join(
		[
			"Player: %s" % _player_state.call("to_debug_string"),
			"World: %s" % _world_state.call("to_debug_string"),
			"Quest: %s" % _quest_state.call("to_debug_string"),
			"Settings: %s" % _settings_state.call("to_debug_string"),
			"Party: %s" % " | ".join(party_lines),
			"Enemies: %s" % " | ".join(enemy_lines),
		]
	)


func _build_limitation_text() -> String:
	return "Focus check: this scene uses one explicit SaveGraphRoot. Authored targets restore directly; missing runtime targets need EntityCollectionSource + EntityFactory."


func _format_result(action: String, result: SaveResult) -> String:
	if result.ok:
		return "%s succeeded. %s" % [action, JSON.stringify(result.data)]
	return "%s failed: %s (%s)" % [action, result.error_key, result.error_message]


func run_complex_analysis() -> Dictionary:
	_reset_all(false)
	var baseline_save: SaveResult = saveflow.save_scope(
		SLOT_ID,
		_save_graph_root,
		{
			"display_name": "Complex Sandbox Slot",
			"scene_path": scene_file_path,
			"game_version": "complex_sandbox",
		}
	)

	_on_mutate_supported_pressed()
	var restore_result: SaveResult = saveflow.load_scope(SLOT_ID, _save_graph_root, true)

	_on_break_dynamic_pressed()
	var dynamic_result: SaveResult = saveflow.load_scope(SLOT_ID, _save_graph_root, true)
	var inspect_result: SaveResult = saveflow.inspect_scope(_save_graph_root)

	return {
		"baseline_save_ok": baseline_save.ok,
		"restore_ok": restore_result.ok,
		"restore_error_key": restore_result.error_key,
		"restore_error_message": restore_result.error_message,
		"restore_missing_keys": restore_result.meta.get("missing_keys", []),
		"dynamic_load_ok": dynamic_result.ok,
		"dynamic_error_key": dynamic_result.error_key,
		"dynamic_error_message": dynamic_result.error_message,
		"dynamic_missing_keys": dynamic_result.meta.get("missing_keys", []) if not dynamic_result.ok else dynamic_result.data.get("missing_keys", []),
		"enemy_count_after_dynamic_load": _enemy_root.get_child_count(),
		"inspect_valid": inspect_result.data.get("valid", false) if inspect_result.ok else false,
		"slot_path": saveflow.get_slot_path(SLOT_ID).data,
	}
