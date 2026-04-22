extends Control

const SLOT_ID := "recommended_node_source_case"

@onready var _player: Node2D = $StateRoot/Player
@onready var _player_animation: AnimationPlayer = $StateRoot/Player/AnimationPlayer
@onready var _player_label: Label = $MarginContainer/PanelContainer/Content/PlayerLabel
@onready var _status_output: TextEdit = $MarginContainer/PanelContainer/Content/StatusOutput


func _ready() -> void:
	_configure_runtime()
	_bind_buttons()
	_setup_player_animations()
	_reset_state(false)
	_set_status("NodeSource case ready. This scene stores one authored object and one included child node.")


func _configure_runtime() -> void:
	SaveFlow.configure_with(
		"user://recommended_cases/node_source/saves",
		"user://recommended_cases/node_source/slots.index"
	)


func _bind_buttons() -> void:
	$MarginContainer/PanelContainer/Content/Buttons/SaveButton.pressed.connect(_on_save_pressed)
	$MarginContainer/PanelContainer/Content/Buttons/LoadButton.pressed.connect(_on_load_pressed)
	$MarginContainer/PanelContainer/Content/Buttons/MutateButton.pressed.connect(_on_mutate_pressed)
	$MarginContainer/PanelContainer/Content/Buttons/ResetButton.pressed.connect(_on_reset_pressed)


func _setup_player_animations() -> void:
	if _player_animation.has_animation("idle") and _player_animation.has_animation("attack"):
		return
	var library := AnimationLibrary.new()
	var idle := Animation.new()
	idle.length = 1.0
	library.add_animation("idle", idle)
	var attack := Animation.new()
	attack.length = 0.4
	library.add_animation("attack", attack)
	_player_animation.add_animation_library("", library)


func _on_save_pressed() -> void:
	var result: SaveResult = SaveFlow.save_scene(
		SLOT_ID,
		$StateRoot,
		{
			"display_name": "NodeSource Case",
			"scene_path": scene_file_path,
		}
	)
	_set_status(_format_result("Save", result))


func _on_load_pressed() -> void:
	var result: SaveResult = SaveFlow.load_scene(SLOT_ID, $StateRoot, true)
	_set_status(_format_result("Load", result))


func _on_mutate_pressed() -> void:
	_player.position += Vector2(24, 12)
	_player.set("hearts", int(_player.get("hearts")) - 1)
	_player.set("rupees", int(_player.get("rupees")) + 7)
	_player_animation.play("attack")
	_player_animation.seek(0.2, true)
	_set_status("Mutated one authored object. NodeSource now has different node fields and child-node state to store.")


func _on_reset_pressed() -> void:
	_reset_state(true)


func _reset_state(announce: bool) -> void:
	_player.call("reset_state")
	_player_animation.play("idle")
	_player_animation.seek(0.0, true)
	_refresh_labels()
	if announce:
		_set_status("Reset the authored object back to its default state.")


func _refresh_labels() -> void:
	_player_label.text = "Player: %s | animation=%s @ %.2f" % [
		_player.call("describe_state"),
		_player_animation.current_animation,
		_player_animation.current_animation_position,
	]


func _format_result(label: String, result: SaveResult) -> String:
	if result.ok:
		return "%s OK" % label
	return "%s failed: %s (%s)" % [label, result.error_message, result.error_key]


func _set_status(message: String) -> void:
	_status_output.text = message
	_refresh_labels()
