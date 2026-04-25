extends Node2D

const PLAYER_SPEED := 190.0
const INTERACTION_RADIUS := 44.0
const COIN_RADIUS := 28.0
const DEMO_SFX_SCRIPT := preload("res://demo/saveflow_lite/recommended_template/gameplay/project_workflow/template_demo_sfx.gd")
const RuntimeCoinScene := preload("res://demo/saveflow_lite/recommended_template/scenes/prefabs/template_runtime_coin.tscn")
const TemplateRoomSaveDataScript := preload("res://demo/saveflow_lite/recommended_template/gameplay/project_workflow/template_room_save_data.gd")

@export var room_id := "forest"
@export var display_name := "Forest Room"
@export var room_bounds := Rect2(120, 130, 1040, 540)
@export var spawn_position := Vector2(315, 500)
@export var room_data: TemplateRoomSaveData = TemplateRoomSaveDataScript.new()

@onready var _save_graph: Node = $SaveGraph
@onready var _player: Node2D = $RoomPlayer
@onready var _animation_player: AnimationPlayer = $RoomPlayer/AnimationPlayer
@onready var _body: Polygon2D = $RoomPlayer/Body
@onready var _left_foot: Polygon2D = $RoomPlayer/LeftFoot
@onready var _right_foot: Polygon2D = $RoomPlayer/RightFoot
@onready var _authored_coins_root: Node2D = $AuthoredCoins
@onready var _runtime_coins_root: Node2D = $RuntimeCoins
@onready var _door: Polygon2D = $Door
@onready var _save_pad: Node2D = $InteractionPads/SavePad
@onready var _load_pad: Node2D = $InteractionPads/LoadPad
@onready var _mutate_pad: Node2D = $InteractionPads/MutatePad
@onready var _exit_pad: Node2D = $InteractionPads/ExitPad

var _exit_callback: Callable
var _ui_callback: Callable
var _last_status := "Room data is owned by this subscene."
var _sfx: Node
var _move_tick_cooldown := 0.0
var _input_active := true
var _player_step_index := 0


func _ready() -> void:
	_install_sfx()
	_ensure_room_data()
	_ensure_player_animation_library()
	if room_data.room_id.is_empty():
		_reset_room_data()
	_player.z_index = 50
	_apply_state_to_nodes()
	_notify_ui()


func configure(exit_callback: Callable, ui_callback: Callable) -> void:
	_exit_callback = exit_callback
	_ui_callback = ui_callback
	_notify_ui()


func set_input_active(active: bool) -> void:
	_input_active = active


func _process(delta: float) -> void:
	if not _input_active:
		return
	_move_tick_cooldown = maxf(0.0, _move_tick_cooldown - delta)
	_handle_movement(delta)
	_collect_nearby_coins()
	_notify_ui()


func handle_input(event: InputEvent) -> bool:
	if not _input_active:
		return false
	if event.is_action_pressed("ui_accept"):
		var interaction := _current_interaction()
		if not interaction.is_empty():
			_run_interaction(interaction)
			return true

	if not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return false

	match key_event.keycode:
		KEY_S:
			save_room()
			return true
		KEY_L:
			load_room()
			return true
		KEY_M:
			mutate_room()
			return true
		KEY_R:
			reset_room()
			return true
		KEY_E:
			_exit_room()
			return true
	return false


func save_room() -> SaveResult:
	var result: SaveResult = SaveFlow.save_scene(
		_slot_id(),
		_save_graph,
		{
			"display_name": "%s Subscene Data" % display_name,
			"room_scene_path": scene_file_path,
			"room_id": room_id,
		},
		"saveflow",
		"manual",
		"Chapter 1",
		display_name
	)
	_last_status = "Saved %s subscene data." % display_name if result.ok else _format_result("Save", result)
	_play("play_save" if result.ok else "play_mutate")
	_notify_ui()
	return result


func load_room() -> SaveResult:
	var result: SaveResult = SaveFlow.load_scene(_slot_id(), _save_graph, true)
	if result.ok:
		_apply_state_to_nodes()
		_last_status = "Loaded %s subscene data." % display_name
	else:
		_last_status = _format_result("Load", result)
	_play("play_load" if result.ok else "play_mutate")
	_notify_ui()
	return result


func mutate_room() -> void:
	room_data.door_open = true
	room_data.switch_on = true
	var event_count := room_data.event_count
	room_data.event_count = event_count + 1
	_spawn_runtime_coin(
		Vector2(520.0 + float((event_count % 5) * 74), 420.0 + float((event_count % 2) * 54)),
		"runtime_coin_%d" % event_count
	)
	_apply_state_to_nodes()
	_last_status = "Mutated room: TypedDataSource opened the door; EntityCollectionSource owns the runtime coin."
	_play("play_event")
	_notify_ui()


func reset_room() -> void:
	_reset_room_data()
	_clear_runtime_coins()
	_reset_player_visuals()
	_apply_state_to_nodes()
	_last_status = "Reset this subscene to its authored default state."
	_play("play_reset")
	_notify_ui()


func get_ui_context() -> Dictionary:
	var runtime_count := _runtime_coins_root.get_child_count()
	var animation_name := String(_animation_player.current_animation)
	return {
		"mode": "subscene",
		"title": display_name,
		"area": "%s subscene" % display_name,
		"slot": _slot_id(),
		"stats": "TypedData coins=%d | EntityCollection runtime=%d | NodeSource anim=%s | door %s" % [
			room_data.collected_coins.size(),
			runtime_count,
			animation_name if not animation_name.is_empty() else "idle",
			"open" if room_data.door_open else "closed",
		],
		"hint": _current_interaction_hint(),
		"status": _last_status,
	}


func _handle_movement(delta: float) -> void:
	var move_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if move_vector == Vector2.ZERO:
		return
	_player.position += move_vector * PLAYER_SPEED * delta
	_player.position.x = clampf(_player.position.x, room_bounds.position.x, room_bounds.end.x)
	_player.position.y = clampf(_player.position.y, room_bounds.position.y, room_bounds.end.y)
	if _move_tick_cooldown == 0.0:
		_mark_player_walk_step()
		_play("play_move_tick")
		_move_tick_cooldown = 0.14


func _mark_player_walk_step() -> void:
	_player_step_index += 1
	var animation_name := "step_left" if _player_step_index % 2 == 0 else "step_right"
	_animation_player.play(animation_name)
	_animation_player.seek(0.04, true)


func _collect_nearby_coins() -> void:
	var collected_authored := _collect_nearby_authored_coins()
	var collected_runtime := _collect_nearby_runtime_coins()
	if collected_authored or collected_runtime:
		_play("play_pickup")


func _collect_nearby_authored_coins() -> bool:
	var collected := PackedStringArray(room_data.collected_coins)
	var changed := false
	for coin in _authored_coins_root.get_children():
		if not (coin is Node2D) or not coin.visible:
			continue
		var coin_node := coin as Node2D
		if coin_node.position.distance_to(_player.position) > COIN_RADIUS:
			continue
		var coin_id := String(coin_node.get_meta("coin_id", coin_node.name.to_snake_case()))
		if not collected.has(coin_id):
			collected.append(coin_id)
			changed = true
		coin_node.visible = false
	if not changed:
		return false
	room_data.collected_coins = collected
	_last_status = "Collected an authored room coin. TypedDataSource stores that coin id as collected."
	return true


func _collect_nearby_runtime_coins() -> bool:
	for coin in _runtime_coins_root.get_children():
		if not (coin is Node2D):
			continue
		var coin_node := coin as Node2D
		if coin_node.position.distance_to(_player.position) > COIN_RADIUS:
			continue
		coin_node.free()
		_last_status = "Collected a runtime coin. EntityCollectionSource will save the remaining runtime set."
		return true
	return false


func _current_interaction() -> String:
	var candidates := {
		"save": _save_pad,
		"load": _load_pad,
		"mutate": _mutate_pad,
		"exit": _exit_pad,
	}
	for key in candidates.keys():
		var marker := candidates[key] as Node2D
		if marker != null and marker.position.distance_to(_player.position) <= INTERACTION_RADIUS:
			return String(key)
	return ""


func _current_interaction_hint() -> String:
	match _current_interaction():
		"save":
			return "Enter: save this room slot"
		"load":
			return "Enter: load this room slot"
		"mutate":
			return "Enter: spawn coin and open door"
		"exit":
			return "Enter: return to main scene"
	return "WASD move | Enter interact | S/L/M/R room hotkeys | Esc main save menu"


func _run_interaction(interaction: String) -> void:
	match interaction:
		"save":
			save_room()
		"load":
			load_room()
		"mutate":
			mutate_room()
		"exit":
			_exit_room()


func _exit_room() -> void:
	_last_status = "Returned to main scene. Room data is still separate until saved."
	_play("play_ui_toggle")
	if _exit_callback.is_valid():
		_exit_callback.call()


func _apply_state_to_nodes() -> void:
	_door.color = Color(0.38, 0.78, 0.56, 0.75) if room_data.door_open else Color(0.8, 0.36, 0.34, 0.85)
	_refresh_authored_coin_visibility()


func _reset_room_data() -> void:
	room_data.reset_for_room(room_id, display_name)


func _reset_player_visuals() -> void:
	_player.position = spawn_position
	_player.scale = Vector2.ONE
	_player.rotation = 0.0
	_player_step_index = 0
	_animation_player.stop()
	_body.color = Color(0.55, 0.82, 1.0, 1.0)
	_body.scale = Vector2.ONE
	_left_foot.scale = Vector2.ONE
	_right_foot.scale = Vector2.ONE


func _spawn_runtime_coin(spawn_at: Vector2, persistent_id: String) -> void:
	var coin := RuntimeCoinScene.instantiate() as Node2D
	coin.name = persistent_id.to_pascal_case()
	var identity := coin.get_node_or_null("Identity")
	if identity != null:
		identity.set("persistent_id", persistent_id)
		identity.set("type_key", "runtime_coin")
	_runtime_coins_root.add_child(coin)
	if coin.has_method("reset_state"):
		coin.call("reset_state", {
			"coin_value": 5,
			"position": spawn_at,
		})


func _clear_runtime_coins() -> void:
	for child in _runtime_coins_root.get_children():
		child.free()


func _refresh_authored_coin_visibility() -> void:
	var collected := room_data.collected_coins
	for child in _authored_coins_root.get_children():
		if not (child is Node2D):
			continue
		var coin_id := String(child.get_meta("coin_id", child.name.to_snake_case()))
		child.visible = not collected.has(coin_id)


func _ensure_player_animation_library() -> void:
	if _animation_player.has_animation("step_left") and _animation_player.has_animation("step_right"):
		return
	_animation_player.root_node = NodePath("..")
	var library := AnimationLibrary.new()
	library.add_animation("step_left", _build_step_animation(true))
	library.add_animation("step_right", _build_step_animation(false))
	_animation_player.add_animation_library("", library)


func _build_step_animation(left_step: bool) -> Animation:
	var animation := Animation.new()
	animation.length = 0.18
	_insert_track_keys(animation, NodePath("Body:scale"), [Vector2.ONE, Vector2(1.16, 0.9), Vector2.ONE])
	_insert_track_keys(
		animation,
		NodePath("Body:color"),
		[
			Color(0.55, 0.82, 1.0, 1.0),
			Color(0.62, 0.94, 0.72, 1.0) if left_step else Color(0.95, 0.78, 0.45, 1.0),
			Color(0.55, 0.82, 1.0, 1.0),
		]
	)
	_insert_track_keys(animation, NodePath("LeftFoot:scale"), [Vector2.ONE, Vector2(1.45, 1.0) if left_step else Vector2(0.72, 0.72), Vector2.ONE])
	_insert_track_keys(animation, NodePath("RightFoot:scale"), [Vector2.ONE, Vector2(0.72, 0.72) if left_step else Vector2(1.45, 1.0), Vector2.ONE])
	return animation


func _insert_track_keys(animation: Animation, path: NodePath, values: Array) -> void:
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, path)
	animation.track_insert_key(track, 0.0, values[0])
	animation.track_insert_key(track, 0.08, values[1])
	animation.track_insert_key(track, 0.18, values[2])


func _slot_id() -> String:
	return "project_workflow_room_%s" % room_id


func _format_result(label: String, result: SaveResult) -> String:
	if result.ok:
		return "%s OK" % label
	return "%s failed: %s (%s)" % [label, result.error_message, result.error_key]


func _notify_ui() -> void:
	if _ui_callback.is_valid():
		_ui_callback.call(get_ui_context())


func _install_sfx() -> void:
	_sfx = DEMO_SFX_SCRIPT.new()
	_sfx.name = "ProjectRoomSfx"
	add_child(_sfx)


func _ensure_room_data() -> void:
	if room_data == null:
		room_data = TemplateRoomSaveDataScript.new()
	room_data.resource_local_to_scene = true


func _play(method_name: String) -> void:
	if is_instance_valid(_sfx) and _sfx.has_method(method_name):
		_sfx.call(method_name)
