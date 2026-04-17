extends Node2D

const SLOT_ID := "zelda_like_slot"
const FORMAL_SAVE_ROOT := "user://zelda_like_sandbox/saves"
const FORMAL_SLOT_INDEX := "user://zelda_like_sandbox/slots.index"
const DEV_SAVE_ROOT := "user://zelda_like_sandbox/devSaves"
const DEV_SLOT_INDEX := "user://zelda_like_sandbox/dev-slots.index"
const ROOM_SCENES := {
	"room_hub": preload("res://addons/saveflow_lite/demo/zelda_like/scenes/rooms/room_hub.tscn"),
	"room_east": preload("res://addons/saveflow_lite/demo/zelda_like/scenes/rooms/room_east.tscn"),
	"room_basement": preload("res://addons/saveflow_lite/demo/zelda_like/scenes/rooms/room_basement.tscn"),
}

@onready var _stage: Node2D = $World/RoomStage
@onready var _camera: Camera2D = $World/RoomStage/Camera2D
@onready var _player: CharacterBody2D = $World/RoomStage/Player
@onready var _player_animation: AnimationPlayer = $World/RoomStage/Player/AnimationPlayer
@onready var _room_entities: Node2D = $World/RoomStage/LoadedRoomEntities
@onready var _room_definition_host: Node = $World/RoomDefinitions
@onready var _room_registry: Node = $StateRoot/RoomRegistry
@onready var _entity_factory: Node = $StateRoot/RoomEntityFactory
@onready var _graph_root: SaveFlowScope = $StateRoot/SaveGraphRoot

@onready var _room_label: Label = $CanvasLayer/HUD/TopBar/Margin/HBox/RoomLabel
@onready var _hearts_label: Label = $CanvasLayer/HUD/TopBar/Margin/HBox/HeartsLabel
@onready var _rupees_label: Label = $CanvasLayer/HUD/TopBar/Margin/HBox/RupeesLabel
@onready var _stamina_label: Label = $CanvasLayer/HUD/TopBar/Margin/HBox/StaminaLabel
@onready var _status_label: Label = $CanvasLayer/HUD/BottomBar/Margin/VBox/StatusLabel
@onready var _debug_panel: PanelContainer = $CanvasLayer/HUD/DebugPanel
@onready var _debug_text: RichTextLabel = $CanvasLayer/HUD/DebugPanel/Margin/DebugText
@onready var _debug_button: Button = $CanvasLayer/HUD/BottomBar/Margin/VBox/ButtonRow/DebugButton

var _debug_visible := false
var _status_message := ""
var _room_transition_pending := false
var _current_room_definition: Node = null


func _ready() -> void:
	_ensure_demo_input_actions()
	_configure_runtime()
	_bind_actions()
	get_viewport().gui_release_focus()
	_stage.door_requested.connect(_on_door_requested)
	_reset_all(false)
	_set_status("Walk with arrows or WASD. Press Space to swing. SaveFlow is tracking player, world tables, and runtime entities.")
	_refresh_hud()


func _process(_delta: float) -> void:
	_refresh_hud()


func _physics_process(_delta: float) -> void:
	_apply_contact_damage()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_attempt_player_action()
		elif event.keycode == KEY_TAB:
			_toggle_debug()


func prepare_loaded_room_for_runtime_restore() -> void:
	var room_id: String = String(_player.get("current_room_id"))
	_room_registry.call("set_active_room", room_id)
	_load_room_definition(room_id)
	_stage.call("configure_room", room_id, _build_current_room_layout())
	_focus_camera()
	_clear_loaded_entities()


func _configure_runtime() -> void:
	SaveFlow.configure_with(
		{
			"save_root": FORMAL_SAVE_ROOT,
			"slot_index_file": FORMAL_SLOT_INDEX,
			"storage_format": 0,
			"pretty_json_in_editor": true,
			"use_safe_write": true,
		}
	)


func _bind_actions() -> void:
	$CanvasLayer/HUD/BottomBar/Margin/VBox/ButtonRow/SaveButton.pressed.connect(_on_save_pressed)
	$CanvasLayer/HUD/BottomBar/Margin/VBox/ButtonRow/LoadButton.pressed.connect(_on_load_pressed)
	$CanvasLayer/HUD/BottomBar/Margin/VBox/ButtonRow/ResetButton.pressed.connect(_on_reset_pressed)
	$CanvasLayer/HUD/BottomBar/Margin/VBox/ButtonRow/BreakButton.pressed.connect(_on_break_runtime_pressed)
	_debug_button.pressed.connect(_toggle_debug)


func _ensure_demo_input_actions() -> void:
	_ensure_input_action("sf_move_left", [KEY_A, KEY_LEFT])
	_ensure_input_action("sf_move_right", [KEY_D, KEY_RIGHT])
	_ensure_input_action("sf_move_up", [KEY_W, KEY_UP])
	_ensure_input_action("sf_move_down", [KEY_S, KEY_DOWN])


func _ensure_input_action(action_name: String, keycodes: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for keycode_variant in keycodes:
		var keycode: Key = int(keycode_variant)
		if _action_has_key(action_name, keycode):
			continue
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		InputMap.action_add_event(action_name, event)


func _action_has_key(action_name: String, keycode: Key) -> bool:
	for event_variant in InputMap.action_get_events(action_name):
		if event_variant is InputEventKey:
			var key_event: InputEventKey = event_variant
			if key_event.keycode == keycode or key_event.physical_keycode == keycode:
				return true
	return false


func _on_save_pressed() -> void:
	var result := save_named_entry(SLOT_ID)
	_set_status(_format_result("Save", result))


func _on_load_pressed() -> void:
	var result := load_named_entry(SLOT_ID)
	_set_status(_format_result("Load", result))


func save_named_entry(entry_name: String) -> SaveResult:
	return SaveFlow.save_scope(
		entry_name,
		_graph_root,
		{
			"display_name": entry_name,
			"scene_path": scene_file_path,
			"game_version": "saveflow_zelda_like_demo",
		}
	)


func load_named_entry(entry_name: String) -> SaveResult:
	var result: SaveResult = SaveFlow.load_scope(entry_name, _graph_root, true)
	if result.ok:
		var room_id: String = String(_player.get("current_room_id"))
		_load_room_definition(room_id)
		_stage.call("configure_room", room_id, _build_current_room_layout())
		_focus_camera()
	return result


func build_dev_save_settings() -> Dictionary:
	return {
		"save_root": DEV_SAVE_ROOT,
		"slot_index_file": DEV_SLOT_INDEX,
		"storage_format": 0,
		"pretty_json_in_editor": true,
		"use_safe_write": true,
	}


func save_dev_named_entry(entry_name: String) -> SaveResult:
	return _with_temp_save_settings(
		build_dev_save_settings(),
		func() -> SaveResult:
			return save_named_entry(entry_name)
	)


func load_dev_named_entry(entry_name: String) -> SaveResult:
	return _with_temp_save_settings(
		build_dev_save_settings(),
		func() -> SaveResult:
			return load_named_entry(entry_name)
	)


func _on_reset_pressed() -> void:
	_reset_all(true)


func _on_break_runtime_pressed() -> void:
	var first_entity: Node = _room_entities.get_child(0) if _room_entities.get_child_count() > 0 else null
	if first_entity != null:
		var persistent_id := String(first_entity.call("get_persistent_id"))
		_entity_factory.call("unregister_entity", persistent_id)
		first_entity.queue_free()
	var debug_template := {
		"persistent_id": "debug_ghost",
		"type_key": "enemy",
		"node_name": "DebugGhost",
		"hp": 7,
		"is_open": false,
		"loot_table": ["debug_drop"],
		"tags_set": {"debug": true},
		"patrol_route": PackedStringArray(["glitch"]),
		"touch_damage": 1,
		"rupee_value": 0,
		"position": Vector2(286, 94),
		"pose": "idle",
		"mood": "alert",
		"facing": "left",
		"accent": "embers",
		"ornament_flags": {"glow": true},
	}
	var debug_entity: Area2D = _entity_factory.call(
		"create_entity_from_template",
		debug_template,
		String(_player.get("current_room_id"))
	)
	_room_entities.add_child(debug_entity)
	_entity_factory.call("register_entity", "debug_ghost", debug_entity)
	_set_status("Runtime mutated: removed one tracked entity and inserted an unsaved debug ghost.")


func _on_door_requested(target_room_id: String, spawn_position: Vector2) -> void:
	if target_room_id.is_empty():
		return
	if _room_transition_pending:
		return
	_room_transition_pending = true
	call_deferred("_complete_room_transition", target_room_id, spawn_position)


func _complete_room_transition(target_room_id: String, spawn_position: Vector2) -> void:
	_room_transition_pending = false
	_switch_room(target_room_id, spawn_position)


func _attempt_player_action() -> void:
	if not _player.call("trigger_attack"):
		return
	var targets: Array = _player.call("get_interaction_targets")
	for target in targets:
		if target == null or not target.has_method("apply_player_attack"):
			continue
		var result: Dictionary = target.call("apply_player_attack")
		_handle_entity_interaction(target, result)
		return
	_set_status("Your swing cuts only dust and torch smoke.")


func _handle_entity_interaction(entity: Node, result: Dictionary) -> void:
	var event_key: String = String(result.get("event", ""))
	var room_id: String = String(_player.get("current_room_id"))
	match event_key:
		"enemy_hit":
			_set_status("Enemy staggered. HP now %d." % int(result.get("hp", 0)))
		"enemy_defeated":
			var persistent_id := String(entity.call("get_persistent_id"))
			_room_registry.call("mark_enemy_defeated", room_id, persistent_id)
			_player.call("add_rupees", int(result.get("rupee_value", 0)))
			_entity_factory.call("unregister_entity", persistent_id)
			entity.queue_free()
			_set_status("Enemy defeated. Room state table updated for %s." % persistent_id)
		"chest_opened":
			var chest_id := String(entity.call("get_persistent_id"))
			_room_registry.call("mark_chest_opened", room_id, chest_id)
			_player.call("add_rupees", int(result.get("rupee_value", 0)))
			_apply_loot_to_player(Array(result.get("loot_table", [])))
			_set_status("Chest opened. Loot added to player state and world table.")
		"chest_already_open":
			_set_status("That chest is already empty.")
		_:
			_set_status("The action changed no tracked state.")


func _apply_loot_to_player(loot_table: Array) -> void:
	for loot_variant in loot_table:
		var loot_id := String(loot_variant)
		match loot_id:
			"rupee_green":
				_player.call("add_rupees", 1)
			"rupee_blue":
				_player.call("add_rupees", 5)
			"boss_key":
				_room_registry.call("set_world_flag", "boss_key_found", true)
				_player.call("add_inventory_item", loot_id)
			_:
				_player.call("add_inventory_item", loot_id)


func _apply_contact_damage() -> void:
	for child in _room_entities.get_children():
		if not (child is Area2D):
			continue
		var entity := child as Area2D
		if entity.has_method("can_hurt_player") and entity.call("can_hurt_player") and entity.overlaps_body(_player):
			if _player.call("take_damage", int(entity.call("get_touch_damage"))):
				_set_status("Player took damage from %s." % String(entity.call("get_persistent_id")))
			return


func _switch_room(room_id: String, spawn_position: Vector2, announce := true) -> void:
	_player.call("move_to_room", room_id, spawn_position)
	_room_registry.call("set_active_room", room_id)
	_load_room_definition(room_id)
	_stage.call("configure_room", room_id, _build_current_room_layout())
	_focus_camera()
	_build_loaded_room(room_id)
	if announce:
		_set_status("Entered %s." % _get_current_room_title())


func _reset_all(refresh := true) -> void:
	_player.call("reset_state")
	_room_registry.call("reset_state")
	var room_id := String(_player.get("current_room_id"))
	_load_room_definition(room_id)
	_stage.call("configure_room", room_id, _build_current_room_layout())
	_focus_camera()
	_build_loaded_room(room_id)
	if refresh:
		_set_status("Scene reset to authored baseline. Slot data is unchanged until saved again.")


func _build_loaded_room(room_id: String) -> void:
	_clear_loaded_entities()
	var templates: Array = _build_current_room_templates(room_id)
	for template_variant in templates:
		var template: Dictionary = Dictionary(template_variant).duplicate(true)
		var persistent_id: String = String(template.get("persistent_id", ""))
		var type_key: String = String(template.get("type_key", "enemy"))
		if type_key == "enemy" and _room_registry.call("is_enemy_defeated", room_id, persistent_id):
			continue
		if type_key == "chest" and _room_registry.call("is_chest_opened", room_id, persistent_id):
			template["is_open"] = true
			template["pose"] = "open"
			template["mood"] = "spent"
		var entity: Area2D = _entity_factory.call("create_entity_from_template", template, room_id)
		_room_entities.add_child(entity)
		_entity_factory.call("register_entity", persistent_id, entity)


func _clear_loaded_entities() -> void:
	for child in _room_entities.get_children():
		child.queue_free()
	if _entity_factory != null:
		_entity_factory.call("clear_registry")


func _toggle_debug() -> void:
	_debug_visible = not _debug_visible
	_debug_panel.visible = _debug_visible
	_debug_button.text = "Debug: On" if _debug_visible else "Debug: Off"
	_refresh_hud()


func _refresh_hud() -> void:
	var room_id := String(_player.get("current_room_id"))
	var room_title := _get_current_room_title()
	_room_label.text = "ROOM %s" % room_title.to_upper()
	_hearts_label.text = "HP %s" % _hearts_string(int(_player.get("hearts")))
	_rupees_label.text = "R %03d" % int(_player.get("rupees"))
	_stamina_label.text = "STM %03d" % int(round(float(_player.get("stamina"))))
	_status_label.text = _status_message
	if _debug_visible:
		_debug_text.text = _build_debug_text()


func _focus_camera() -> void:
	if _camera != null and _camera.has_method("focus_room"):
		_camera.call("focus_room", _stage.call("get_room_rect"))


func _build_debug_text() -> String:
	var lines := PackedStringArray()
	lines.append("[b]Player[/b]")
	lines.append(_player.call("to_debug_string"))
	lines.append("")
	lines.append("[b]World[/b]")
	lines.append(_room_registry.call("to_debug_string"))
	lines.append("")
	lines.append("[b]Loaded Runtime[/b]")
	if _room_entities.get_child_count() == 0:
		lines.append("none")
	else:
		for child in _room_entities.get_children():
			if child.has_method("to_debug_string"):
				lines.append(child.call("to_debug_string"))
			else:
				lines.append(child.name)
	return "\n".join(lines)


func _hearts_string(count: int) -> String:
	var parts := PackedStringArray()
	for _index in range(count):
		parts.append("@")
	return " ".join(parts) if not parts.is_empty() else "--"


func _set_status(message: String) -> void:
	_status_message = message
	_refresh_hud()


func _format_result(action: String, result: SaveResult) -> String:
	if result.ok:
		return "%s OK. %s" % [action, JSON.stringify(result.data)]
	return "%s failed: %s (%s)" % [action, result.error_key, result.error_message]


func _with_temp_save_settings(overrides: Dictionary, operation: Callable) -> SaveResult:
	var original_settings := _clone_save_settings(SaveFlow.get_settings())
	var temp_settings := _clone_save_settings(original_settings)
	_apply_settings_overrides(temp_settings, overrides)
	var configure_result: SaveResult = SaveFlow.configure(temp_settings)
	if not configure_result.ok:
		return configure_result

	var operation_result: SaveResult = operation.call()
	SaveFlow.configure(original_settings)
	return operation_result


func _clone_save_settings(source: SaveSettings) -> SaveSettings:
	var clone := SaveSettings.new()
	clone.save_root = source.save_root
	clone.slot_index_file = source.slot_index_file
	clone.storage_format = source.storage_format
	clone.pretty_json_in_editor = source.pretty_json_in_editor
	clone.use_safe_write = source.use_safe_write
	clone.file_extension_json = source.file_extension_json
	clone.file_extension_binary = source.file_extension_binary
	clone.log_level = source.log_level
	clone.include_meta_in_slot_file = source.include_meta_in_slot_file
	clone.auto_create_dirs = source.auto_create_dirs
	clone.project_title = source.project_title
	clone.game_version = source.game_version
	clone.data_version = source.data_version
	clone.save_schema = source.save_schema
	return clone


func _apply_settings_overrides(target: SaveSettings, overrides: Dictionary) -> void:
	for key_variant in overrides.keys():
		var key := String(key_variant)
		if not _has_setting_property(target, key):
			continue
		target.set(key, overrides[key_variant])


func _has_setting_property(target: SaveSettings, property_name: String) -> bool:
	for property_info in target.get_property_list():
		if String(property_info.get("name", "")) == property_name:
			return true
	return false


func _load_room_definition(room_id: String) -> void:
	if _current_room_definition != null and is_instance_valid(_current_room_definition):
		_current_room_definition.queue_free()
		_current_room_definition = null
	var room_scene: PackedScene = ROOM_SCENES.get(room_id, null)
	if room_scene == null:
		return
	_current_room_definition = room_scene.instantiate()
	_room_definition_host.add_child(_current_room_definition)


func _build_current_room_layout() -> Dictionary:
	if _current_room_definition != null and _current_room_definition.has_method("build_layout"):
		return _current_room_definition.call("build_layout")
	return {"title": "Unknown Room", "doors": [], "obstacles": []}


func _build_current_room_templates(room_id: String) -> Array:
	if _current_room_definition != null and _current_room_definition.has_method("build_entity_templates"):
		return _current_room_definition.call("build_entity_templates")
	return []


func _get_current_room_title() -> String:
	if _current_room_definition != null and _current_room_definition.has_method("get_room_title"):
		return String(_current_room_definition.call("get_room_title"))
	return String(_player.get("current_room_id"))
