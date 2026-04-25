extends Control

const MAIN_SLOT_ID := "project_workflow_main"
const PLAYER_SPEED := 200.0
const INTERACTION_RADIUS := 52.0
const DEMO_SFX_SCRIPT := preload("res://demo/saveflow_lite/recommended_template/gameplay/project_workflow/template_demo_sfx.gd")
const FOREST_ROOM := preload("res://demo/saveflow_lite/recommended_template/scenes/project_workflow/project_room_forest.tscn")
const DUNGEON_ROOM := preload("res://demo/saveflow_lite/recommended_template/scenes/project_workflow/project_room_dungeon.tscn")

@onready var _main_hub: Node2D = $WorldRoot/MainHub
@onready var _subscene_root: Node2D = $WorldRoot/SubsceneRoot
@onready var _hub_player: Node2D = $WorldRoot/MainHub/MainPlayer
@onready var _forest_portal: Node2D = $WorldRoot/MainHub/ForestPortal
@onready var _dungeon_portal: Node2D = $WorldRoot/MainHub/DungeonPortal
@onready var _top_left_label: Label = $HUD/TopLeftPanel/TopLeftLabel
@onready var _top_center_label: Label = $HUD/TopCenterPanel/TopCenterLabel
@onready var _top_right_label: Label = $HUD/TopRightPanel/TopRightLabel
@onready var _bottom_hint_label: Label = $HUD/BottomHintPanel/BottomHintLabel
@onready var _menu_overlay: ColorRect = $HUD/MenuOverlay
@onready var _menu_title_label: Label = $HUD/MenuOverlay/MenuPanel/MenuContent/MenuTitleLabel
@onready var _menu_status_label: Label = $HUD/MenuOverlay/MenuPanel/MenuContent/MenuStatusLabel
@onready var _main_save_button: Button = $HUD/MenuOverlay/MenuPanel/MenuContent/MenuButtons/MainSaveButton
@onready var _main_load_button: Button = $HUD/MenuOverlay/MenuPanel/MenuContent/MenuButtons/MainLoadButton
@onready var _return_hub_button: Button = $HUD/MenuOverlay/MenuPanel/MenuContent/MenuButtons/ReturnHubButton
@onready var _close_menu_button: Button = $HUD/MenuOverlay/MenuPanel/MenuContent/MenuButtons/CloseMenuButton

var _current_room: Node2D
var _location_id := "main"
var _last_status := "Main scene data stores where the player is: hub, forest, or dungeon."
var _room_ui_context: Dictionary = {}
var _menu_open := false
var _sfx: Node
var _move_tick_cooldown := 0.0


func _ready() -> void:
	_install_sfx()
	_hub_player.z_index = 50
	_bind_menu()
	_set_menu_open(false)
	_refresh_ui()


func _process(delta: float) -> void:
	_move_tick_cooldown = maxf(0.0, _move_tick_cooldown - delta)
	if _menu_open or _current_room != null:
		return
	var move_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if move_vector == Vector2.ZERO:
		return
	_hub_player.position += move_vector * PLAYER_SPEED * delta
	_hub_player.position.x = clampf(_hub_player.position.x, 160.0, 1120.0)
	_hub_player.position.y = clampf(_hub_player.position.y, 150.0, 600.0)
	if _move_tick_cooldown == 0.0:
		_play("play_move_tick")
		_move_tick_cooldown = 0.14
	_refresh_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_set_menu_open(not _menu_open)
		_play("play_ui_toggle")
		get_viewport().set_input_as_handled()
		return
	if _menu_open:
		return
	if _current_room != null and _current_room.has_method("handle_input"):
		if bool(_current_room.call("handle_input", event)):
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("ui_accept"):
		var portal := _current_hub_interaction()
		if portal != "":
			enter_subscene(portal)
			get_viewport().set_input_as_handled()


func enter_subscene(room_id: String) -> void:
	if not ["forest", "dungeon"].has(room_id):
		_last_status = "Unknown room '%s'. Staying in MainHub." % room_id
		exit_to_hub()
		return
	_clear_current_room()
	var packed_scene: PackedScene = FOREST_ROOM if room_id == "forest" else DUNGEON_ROOM
	_current_room = packed_scene.instantiate() as Node2D
	_subscene_root.add_child(_current_room)
	_main_hub.visible = false
	_location_id = room_id
	if _current_room.has_method("configure"):
		_current_room.call("configure", Callable(self, "exit_to_hub"), Callable(self, "_apply_room_ui_context"))
	_last_status = "Entered %s. Room save/load happens inside this subscene." % _room_display_name(room_id)
	_refresh_ui()


func exit_to_hub() -> void:
	_clear_current_room()
	_main_hub.visible = true
	_location_id = "main"
	_room_ui_context = {}
	_last_status = "Back in MainHub. Esc saves only the main scene location data."
	_refresh_ui()


func save_main() -> SaveResult:
	var payload := {
		"location_id": _location_id,
		"hub_player_position": {
			"x": _hub_player.position.x,
			"y": _hub_player.position.y,
		},
		"active_room_slot": _active_room_slot_id(),
		"note": "Main scene data chooses which scene to boot. Subscene data is saved inside each room.",
	}
	var result: SaveResult = SaveFlow.save_data(
		MAIN_SLOT_ID,
		payload,
		{
			"display_name": "Project Workflow Main Data",
			"scene_path": scene_file_path,
			"location_id": _location_id,
		},
		"manual",
		"Chapter 1",
		_room_display_name(_location_id)
	)
	_last_status = "Saved main scene data: location=%s." % _location_id if result.ok else _format_result("Main save", result)
	_play("play_manual_save" if result.ok else "play_mutate")
	_refresh_ui()
	return result


func load_main() -> SaveResult:
	var result: SaveResult = SaveFlow.load_data(MAIN_SLOT_ID)
	if not result.ok:
		_last_status = _format_result("Main load", result)
		_play("play_mutate")
		_refresh_ui()
		return result

	var payload: Dictionary = result.data if result.data is Dictionary else {}
	var hub_position: Dictionary = payload.get("hub_player_position", {})
	_hub_player.position = Vector2(float(hub_position.get("x", _hub_player.position.x)), float(hub_position.get("y", _hub_player.position.y)))
	var saved_location := String(payload.get("location_id", "main"))
	if saved_location == "main":
		exit_to_hub()
		_last_status = "Loaded main data: player should be in MainHub."
	else:
		enter_subscene(saved_location)
		if _current_room != null and _current_room.has_method("load_room") and SaveFlow.slot_exists(String(payload.get("active_room_slot", ""))):
			_current_room.call("load_room")
		_last_status = "Loaded main data: booted %s, then let that room load its own data if present." % _room_display_name(saved_location)
	_play("play_load")
	_refresh_ui()
	return result


func _bind_menu() -> void:
	_main_save_button.pressed.connect(func() -> void: save_main())
	_main_load_button.pressed.connect(func() -> void: load_main())
	_return_hub_button.pressed.connect(exit_to_hub)
	_close_menu_button.pressed.connect(func() -> void: _set_menu_open(false))


func _set_menu_open(open: bool) -> void:
	_menu_open = open
	_menu_overlay.visible = open
	if _current_room != null and _current_room.has_method("set_input_active"):
		_current_room.call("set_input_active", not open)
	_refresh_ui()


func _apply_room_ui_context(context: Dictionary) -> void:
	_room_ui_context = context.duplicate(true)
	_refresh_ui()


func _refresh_ui() -> void:
	var title := "Project Workflow Template"
	var area := "MainHub"
	var stats := "main slot: %s" % MAIN_SLOT_ID
	var hint := _current_hub_hint()
	var status := _last_status
	if _current_room != null:
		title = String(_room_ui_context.get("title", _room_display_name(_location_id)))
		area = String(_room_ui_context.get("area", _room_display_name(_location_id)))
		stats = String(_room_ui_context.get("stats", "subscene data"))
		hint = String(_room_ui_context.get("hint", "WASD move | Enter interact | Esc main save menu"))
		status = String(_room_ui_context.get("status", _last_status))
	_top_left_label.text = "%s\nlocation=%s" % [title, _location_id]
	_top_center_label.text = area
	_top_right_label.text = stats
	_bottom_hint_label.text = "%s\n%s" % [hint, status]
	_menu_title_label.text = "Main Scene Save Menu"
	_menu_status_label.text = "Esc menu writes the main scene data only.\nCurrent location: %s\nCurrent room slot: %s\n%s" % [
		_location_id,
		_active_room_slot_id(),
		status,
	]


func _current_hub_interaction() -> String:
	if not _main_hub.visible:
		return ""
	if _hub_player.position.distance_to(_forest_portal.position) <= INTERACTION_RADIUS:
		return "forest"
	if _hub_player.position.distance_to(_dungeon_portal.position) <= INTERACTION_RADIUS:
		return "dungeon"
	return ""


func _current_hub_hint() -> String:
	match _current_hub_interaction():
		"forest":
			return "Enter: travel to Forest Room"
		"dungeon":
			return "Enter: travel to Dungeon Room"
	return "WASD move | stand on a portal and press Enter | Esc main save menu"


func _clear_current_room() -> void:
	if _current_room == null:
		return
	_subscene_root.remove_child(_current_room)
	_current_room.queue_free()
	_current_room = null


func _active_room_slot_id() -> String:
	if _location_id == "main":
		return "<none>"
	return "project_workflow_room_%s" % _location_id


func _room_display_name(room_id: String) -> String:
	match room_id:
		"forest":
			return "Forest Room"
		"dungeon":
			return "Dungeon Room"
	return "MainHub"


func _format_result(label: String, result: SaveResult) -> String:
	if result.ok:
		return "%s OK" % label
	return "%s failed: %s (%s)" % [label, result.error_message, result.error_key]


func _install_sfx() -> void:
	_sfx = DEMO_SFX_SCRIPT.new()
	_sfx.name = "ProjectWorkflowSfx"
	add_child(_sfx)


func _play(method_name: String) -> void:
	if is_instance_valid(_sfx) and _sfx.has_method(method_name):
		_sfx.call(method_name)
