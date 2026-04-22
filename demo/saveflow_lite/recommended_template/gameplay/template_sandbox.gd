extends Control

const SLOT_ID := "recommended_template_slot"

@onready var _player: Node2D = $StateRoot/Player
@onready var _player_animation: AnimationPlayer = $StateRoot/Player/AnimationPlayer
@onready var _world_registry: Node = $StateRoot/WorldRegistry
@onready var _runtime_actors: Node = $StateRoot/RuntimeActors
@onready var _entity_factory: Node = $StateRoot/RuntimeActorFactory

@onready var _player_label: Label = $MarginContainer/PanelContainer/Content/PlayerLabel
@onready var _world_label: Label = $MarginContainer/PanelContainer/Content/WorldLabel
@onready var _actors_label: Label = $MarginContainer/PanelContainer/Content/ActorsLabel
@onready var _status_output: TextEdit = $MarginContainer/PanelContainer/Content/StatusOutput


func _ready() -> void:
	_configure_runtime()
	_bind_buttons()
	_setup_player_animations()
	_reset_all(false)
	_set_status("Recommended template ready. This scene shows node, system, and entity collection saves together.")


func _configure_runtime() -> void:
	SaveFlow.configure_with(
		"user://recommended_template/saves",
		"user://recommended_template/slots.index"
	)


func _bind_buttons() -> void:
	$MarginContainer/PanelContainer/Content/Buttons/SaveButton.pressed.connect(_on_save_pressed)
	$MarginContainer/PanelContainer/Content/Buttons/LoadButton.pressed.connect(_on_load_pressed)
	$MarginContainer/PanelContainer/Content/Buttons/MutateButton.pressed.connect(_on_mutate_pressed)
	$MarginContainer/PanelContainer/Content/Buttons/SpawnButton.pressed.connect(_on_spawn_pressed)
	$MarginContainer/PanelContainer/Content/Buttons/BreakButton.pressed.connect(_on_break_pressed)
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
			"display_name": "Recommended Template",
			"scene_path": scene_file_path,
			"game_version": "saveflow_template_v1",
		}
	)
	_set_status(_format_result("Save", result))


func _on_load_pressed() -> void:
	var result: SaveResult = SaveFlow.load_scene(SLOT_ID, $StateRoot, true)
	_set_status(_format_result("Load", result))


func _on_mutate_pressed() -> void:
	_player.position += Vector2(28, 16)
	_player.set("hearts", int(_player.get("hearts")) - 1)
	_player.set("rupees", int(_player.get("rupees")) + 5)
	_player_animation.play("attack")
	_player_animation.seek(0.2, true)

	var system_state: Dictionary = _as_dictionary(_world_registry.get("system_state")).duplicate(true)
	var opened_doors: Dictionary = _as_dictionary(system_state.get("opened_doors", {}))
	opened_doors["moss_gate"] = true
	system_state["opened_doors"] = opened_doors
	system_state["pending_mail"] = ["starter_letter", "supply_drop"]
	_world_registry.set("system_state", system_state)

	if _runtime_actors.get_child_count() > 0:
		var actor: Node = _runtime_actors.get_child(0)
		actor.set("hp", int(actor.get("hp")) - 3)
		actor.set("is_alerted", true)
		actor.position += Vector2(12, -8)

	_set_status("Mutated player fields, world registry, animation playback, and one runtime actor.")
	_refresh_labels()


func _on_spawn_pressed() -> void:
	var next_id := "runtime_%d" % (_runtime_actors.get_child_count() + 1)
	_entity_factory.call(
		"spawn_template_actor",
		next_id,
		"bat",
		Vector2(180 + 18 * _runtime_actors.get_child_count(), 140),
		8,
		PackedStringArray(["flying", "cave"]),
		["wing", "dust"]
	)
	_set_status("Spawned a new runtime actor through the project-owned entity factory.")
	_refresh_labels()


func _on_break_pressed() -> void:
	if _runtime_actors.get_child_count() == 0:
		_set_status("No runtime actor is available to break.")
		return
	var actor := _runtime_actors.get_child(0)
	var actor_id := actor.name
	_entity_factory.call("unregister_actor", actor_id)
	actor.queue_free()
	_entity_factory.call(
		"spawn_template_actor",
		"unsaved_debug_actor",
		"slime",
		Vector2(244, 112),
		3,
		PackedStringArray(["debug"]),
		["glitch_drop"]
	)
	_set_status("Removed one tracked actor and inserted an unsaved debug actor.")
	_refresh_labels()


func _on_reset_pressed() -> void:
	_reset_all(true)


func _reset_all(announce: bool) -> void:
	_player.call("reset_state")
	_player_animation.play("idle")
	_player_animation.seek(0.0, true)
	_world_registry.call("reset_state")
	_entity_factory.call("clear_runtime")
	_entity_factory.call(
		"spawn_template_actor",
		"slime_alpha",
		"slime",
		Vector2(184, 108),
		12,
		PackedStringArray(["ground", "starter"]),
		["gel"]
	)
	_entity_factory.call(
		"spawn_template_actor",
		"bat_beta",
		"bat",
		Vector2(246, 84),
		8,
		PackedStringArray(["flying"]),
		["wing"]
	)
	_refresh_labels()
	if announce:
		_set_status("Reset local state and rebuilt the default runtime set.")


func _refresh_labels() -> void:
	_player_label.text = "Player: %s" % _player.call("describe_state")
	_world_label.text = "World Registry: %s" % _world_registry.call("describe_state")
	var actor_lines: Array = []
	for child in _runtime_actors.get_children():
		if child.has_method("describe_state"):
			actor_lines.append(String(child.name) + " -> " + String(child.call("describe_state")))
	_actors_label.text = "Runtime Actors:\n%s" % ("\n".join(actor_lines) if not actor_lines.is_empty() else "(none)")


func _format_result(label: String, result: SaveResult) -> String:
	if result.ok:
		return "%s OK" % label
	return "%s failed: %s (%s)" % [label, result.error_message, result.error_key]


func _set_status(message: String) -> void:
	_status_output.text = message
	_refresh_labels()


func _as_dictionary(value: Variant) -> Dictionary:
	return value.duplicate(true) if value is Dictionary else {}
